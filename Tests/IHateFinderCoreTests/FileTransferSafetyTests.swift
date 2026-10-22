import XCTest
@testable import IHateFinderCore

final class FileTransferSafetyTests: XCTestCase {
    private let fm = FileManager.default
    private var root: URL!
    private var source: URL!
    private var destination: URL!
    private var bin: URL!

    override func setUpWithError() throws {
        root = fm.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("transfer-safety-\(UUID())", isDirectory: true)
        source = root.appendingPathComponent("source", isDirectory: true)
        destination = root.appendingPathComponent("destination", isDirectory: true)
        bin = root.appendingPathComponent("bin", isDirectory: true)
        for directory in [source!, destination!, bin!] {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    override func tearDownWithError() throws {
        try fm.removeItem(at: root)
    }

    func testAtomicSaveAfterCopyPreservesNewOriginalAndStopsBatch() throws {
        let file = try write("note.txt", "before")
        let next = try write("next.txt", "next")
        let report = move([file, next]) {
            try Data("latest".utf8).write(to: file, options: .atomic)
        }

        try assertPreserved(report, source: file)
        XCTAssertEqual(report.items.map(\.status), [.failed, .unprocessed])
        XCTAssertEqual(try text(file), "latest")
        XCTAssertEqual(try text(destination.appendingPathComponent("note.txt")), "before")
        XCTAssertEqual(try text(next), "next")
        XCTAssertFalse(fm.fileExists(atPath: destination.appendingPathComponent("next.txt").path))
    }

    func testInPlaceSameSizeChangeWithRestoredMtimeStillPreservesSource() throws {
        let file = try write("note.txt", "before")
        let oldDate = Date(timeIntervalSince1970: 1_600_000_000)
        try fm.setAttributes([.modificationDate: oldDate], ofItemAtPath: file.path)
        let identity = FileID.read(at: file)
        let report = move([file]) {
            let handle = try FileHandle(forWritingTo: file)
            defer { try? handle.close() }
            try handle.write(contentsOf: Data("latest".utf8))
            try self.fm.setAttributes([.modificationDate: oldDate], ofItemAtPath: file.path)
        }

        try assertPreserved(report, source: file)
        XCTAssertEqual(FileID.read(at: file), identity, "The test must edit the same inode")
        XCTAssertEqual(try text(file), "latest")
        XCTAssertEqual(try text(destination.appendingPathComponent("note.txt")), "before")
    }

    func testSourceChangedInsideCopyIsComparedWithSnapshotFromBeforeCopy() throws {
        let file = try write("note.txt", "before")
        var operations = ops()
        operations.copy = { source, target, cancellation, progress in
            try NativeFileCopy.copy(source, target, cancellation, progress)
            try Data("latest".utf8).write(to: source, options: .atomic)
        }
        let report = operations.transfer(
            urls: [file], to: destination, moving: true, resolve: { _ in .replace }
        )

        try assertPreserved(report, source: file)
        XCTAssertEqual(try text(file), "latest")
        XCTAssertEqual(try text(destination.appendingPathComponent("note.txt")), "before")
    }

    func testDeepDescendantContentChangePreservesWholeFolder() throws {
        let folder = try tree()
        let leaf = folder.appendingPathComponent("inner/deeper/note.txt")
        let rootDate = try fm.attributesOfItem(atPath: folder.path)[.modificationDate] as? Date
        let report = move([folder]) {
            try Data("new descendant".utf8).write(to: leaf)
        }

        try assertPreserved(report, source: folder)
        XCTAssertEqual(try fm.attributesOfItem(atPath: folder.path)[.modificationDate] as? Date, rootDate)
        XCTAssertEqual(try text(leaf), "new descendant")
        XCTAssertEqual(try text(destination.appendingPathComponent("tree/inner/deeper/note.txt")), "before")
    }

    func testDeepDescendantAdditionPreservesWholeFolder() throws {
        let folder = try tree()
        let added = folder.appendingPathComponent("inner/deeper/new.txt")
        let report = move([folder]) { try Data("new".utf8).write(to: added) }

        try assertPreserved(report, source: folder)
        XCTAssertEqual(try text(added), "new")
        XCTAssertFalse(fm.fileExists(atPath: destination.appendingPathComponent("tree/inner/deeper/new.txt").path))
    }

    func testDeepDescendantRemovalPreservesRemainingFolder() throws {
        let folder = try tree()
        let removed = folder.appendingPathComponent("inner/deeper/note.txt")
        let report = move([folder]) { try self.fm.removeItem(at: removed) }

        try assertPreserved(report, source: folder)
        XCTAssertFalse(fm.fileExists(atPath: removed.path))
        XCTAssertEqual(try text(destination.appendingPathComponent("tree/inner/deeper/note.txt")), "before")
    }

    func testChangeDuringPublishIsCheckedBeforeSourceTrash() throws {
        let file = try write("note.txt", "before")
        let manager = SafetyFileManager()
        let target = destination.appendingPathComponent("note.txt")
        manager.afterMove = { _, to in
            if to == target { try Data("latest".utf8).write(to: file, options: .atomic) }
        }

        let report = ops(fileManager: manager).transfer(
            urls: [file], to: destination, moving: true, resolve: { _ in .replace }
        )

        try assertPreserved(report, source: file)
        XCTAssertEqual(try text(file), "latest")
        XCTAssertEqual(try text(target), "before")
    }

    func testFailedInitialInventoryPreservesSourceWithoutStartingCopy() throws {
        let folder = try tree()
        let manager = SafetyFileManager()
        manager.failEnumeration = true

        let report = ops(fileManager: manager).transfer(
            urls: [folder], to: destination, moving: true, resolve: { _ in .replace }
        )

        XCTAssertEqual(report.items.first?.status, .failed)
        XCTAssertEqual(report.items.first?.recovery?.status, .preserved)
        XCTAssertTrue(report.items.first?.recovery?.locations.contains(folder) == true)
        XCTAssertEqual(try text(folder.appendingPathComponent("inner/deeper/note.txt")), "before")
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: destination.path), [])
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: bin.path), [])
    }

    func testFailedFinalInventoryPreservesBothCopies() throws {
        let folder = try tree()
        let manager = SafetyFileManager()
        let report = move([folder], fileManager: manager) { manager.failEnumeration = true }

        try assertPreserved(report, source: folder)
        XCTAssertEqual(try text(folder.appendingPathComponent("inner/deeper/note.txt")), "before")
        XCTAssertEqual(try text(destination.appendingPathComponent("tree/inner/deeper/note.txt")), "before")
    }

    func testUnchangedCrossVolumeFolderMovesAndPreservesDanglingLink() throws {
        let folder = try tree()
        try fm.createSymbolicLink(atPath: folder.appendingPathComponent("dangling").path,
                                  withDestinationPath: "missing")
        let report = move([folder]) {}

        XCTAssertEqual(report.items.first?.status, .completed)
        XCTAssertEqual(report.completedSources, [folder])
        XCTAssertNil(report.items.first?.message)
        XCTAssertFalse(fm.fileExists(atPath: folder.path))
        let trash = try XCTUnwrap(report.items.first?.sourceTrashURL)
        XCTAssertEqual(try text(trash.appendingPathComponent("inner/deeper/note.txt")), "before")
        XCTAssertEqual(try text(destination.appendingPathComponent("tree/inner/deeper/note.txt")), "before")
        XCTAssertEqual(try fm.destinationOfSymbolicLink(atPath: destination.appendingPathComponent("tree/dangling").path), "missing")
    }

    func testChangedCrossVolumeReplacementKeepsNewSourceAndReportsOldTargetTrash() throws {
        let file = try write("note.txt", "before")
        let target = destination.appendingPathComponent("note.txt")
        try Data("previous destination".utf8).write(to: target)
        let report = move([file]) { try Data("latest".utf8).write(to: file, options: .atomic) }

        let item = try XCTUnwrap(report.items.first)
        XCTAssertEqual(item.status, .failed)
        XCTAssertEqual(item.recovery?.status, .preserved)
        XCTAssertNil(item.sourceTrashURL)
        XCTAssertTrue(item.replacedExisting)
        XCTAssertEqual(try text(try XCTUnwrap(item.replacedTrashURL)), "previous destination")
        XCTAssertEqual(try text(file), "latest")
        XCTAssertEqual(try text(target), "before")
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: destination.path), ["note.txt"])
    }

    func testSymlinkDestinationInsideSourceIsRejectedBeforeStagingForCopyAndMove() throws {
        let folder = try tree()
        let inside = folder.appendingPathComponent("inner")
        let alias = root.appendingPathComponent("shortcut")
        try fm.createSymbolicLink(at: alias, withDestinationURL: inside)
        let before = try fm.contentsOfDirectory(atPath: inside.path)

        for moving in [false, true] {
            let cancellation = FileTransferCancellation()
            var copied = false
            let report = ops().transfer(
                urls: [folder], to: alias, moving: moving, resolve: { _ in .replace },
                cancellation: cancellation, progressInterval: 0
            ) { progress in
                if progress.phase == .copying {
                    copied = true
                    cancellation.cancel() // Bound the regression on the old implementation.
                }
            }

            XCTAssertEqual(report.items.first?.status, .failed)
            XCTAssertFalse(copied)
            XCTAssertEqual(try fm.contentsOfDirectory(atPath: inside.path), before)
            XCTAssertEqual(try text(folder.appendingPathComponent("inner/deeper/note.txt")), "before")
        }
    }

    func testSourceParentAliasStillRejectsRealDescendantDestination() throws {
        let folder = try tree()
        let parentAlias = root.appendingPathComponent("source-alias")
        try fm.createSymbolicLink(at: parentAlias, withDestinationURL: source)
        let report = ops().transfer(
            urls: [parentAlias.appendingPathComponent("tree")], to: folder.appendingPathComponent("inner"),
            moving: false, resolve: { _ in .replace }
        )

        XCTAssertEqual(report.items.first?.status, .failed)
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: folder.appendingPathComponent("inner").path), ["deeper"])
    }

    func testCaseInsensitiveSourceAliasStillRejectsDescendantDestination() throws {
        let folder = try tree()
        let alias = source.appendingPathComponent("TREE")
        try XCTSkipUnless(fm.fileExists(atPath: alias.path), "Requires a case-insensitive volume")

        let report = ops().transfer(
            urls: [alias], to: folder.appendingPathComponent("inner"), moving: false, resolve: { _ in .replace }
        )

        XCTAssertEqual(report.items.first?.status, .failed)
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: folder.appendingPathComponent("inner").path), ["deeper"])
    }

    func testDestinationRetargetedByResolverIsRecheckedBeforeStaging() throws {
        let folder = try tree()
        try fm.createDirectory(at: destination.appendingPathComponent("tree"), withIntermediateDirectories: false)
        let alias = root.appendingPathComponent("shortcut")
        try fm.createSymbolicLink(at: alias, withDestinationURL: destination)
        let inside = folder.appendingPathComponent("inner")

        let report = ops().transfer(urls: [folder], to: alias, moving: false) { _ in
            try self.fm.removeItem(at: alias)
            try self.fm.createSymbolicLink(at: alias, withDestinationURL: inside)
            return .replace
        }

        XCTAssertEqual(report.items.first?.status, .failed)
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: inside.path), ["deeper"])
    }

    func testSourceSymlinkCanBeCopiedIntoItsReferentWithoutRecursion() throws {
        let folder = try tree()
        let link = source.appendingPathComponent("link")
        try fm.createSymbolicLink(at: link, withDestinationURL: folder)
        let report = ops().transfer(
            urls: [link], to: link.appendingPathComponent("inner"), moving: false, resolve: { _ in .replace }
        )

        XCTAssertEqual(report.items.first?.status, .completed)
        XCTAssertEqual(try fm.destinationOfSymbolicLink(atPath: folder.appendingPathComponent("inner/link").path), folder.path)
        XCTAssertEqual(try text(folder.appendingPathComponent("inner/deeper/note.txt")), "before")
    }

    func testCrossVolumeSymlinkMoveDoesNotTreatReferentChangesAsLinkChanges() throws {
        let file = try write("referent.txt", "before")
        let link = source.appendingPathComponent("link")
        try fm.createSymbolicLink(at: link, withDestinationURL: file)
        let report = move([link]) { try Data("latest".utf8).write(to: file) }

        XCTAssertEqual(report.items.first?.status, .completed)
        XCTAssertEqual(try fm.destinationOfSymbolicLink(atPath: destination.appendingPathComponent("link").path), file.path)
        XCTAssertEqual(try text(file), "latest")
        XCTAssertThrowsError(try fm.destinationOfSymbolicLink(atPath: link.path))
    }

    func testSymlinkRenameMovesLinkAndPreservesReferent() throws {
        let folder = try tree()
        let link = source.appendingPathComponent("link")
        try fm.createSymbolicLink(at: link, withDestinationURL: folder)

        let outcome = try ops(sameVolume: true).rename(url: link, to: "renamed-link", resolve: { _ in .replace })

        guard case .renamed(let item) = outcome else { return XCTFail("Expected a renamed link") }
        XCTAssertEqual(item.status, .completed)
        XCTAssertEqual(try fm.destinationOfSymbolicLink(atPath: source.appendingPathComponent("renamed-link").path), folder.path)
        XCTAssertEqual(try text(folder.appendingPathComponent("inner/deeper/note.txt")), "before")
    }

    func testFolderCopyThroughUnrelatedDestinationLinkStillWorks() throws {
        let folder = try tree()
        let alias = root.appendingPathComponent("shortcut")
        try fm.createSymbolicLink(at: alias, withDestinationURL: destination)
        let report = ops().transfer(urls: [folder], to: alias, moving: false, resolve: { _ in .replace })

        XCTAssertEqual(report.items.first?.status, .completed)
        XCTAssertEqual(try text(destination.appendingPathComponent("tree/inner/deeper/note.txt")), "before")
        XCTAssertEqual(try text(folder.appendingPathComponent("inner/deeper/note.txt")), "before")
    }

    private func assertPreserved(_ report: FileTransferReport, source: URL,
                                 file: StaticString = #filePath, line: UInt = #line) throws {
        let item = try XCTUnwrap(report.items.first, file: file, line: line)
        XCTAssertEqual(item.status, .failed, file: file, line: line)
        XCTAssertEqual(item.recovery?.status, .preserved, file: file, line: line)
        XCTAssertEqual(Set(item.recovery?.locations ?? []), [source, item.destination], file: file, line: line)
        XCTAssertNotNil(item.message, file: file, line: line)
        XCTAssertNil(item.sourceTrashURL, file: file, line: line)
        XCTAssertEqual(report.completedSources, [], file: file, line: line)
        XCTAssertTrue(fm.fileExists(atPath: source.path), file: file, line: line)
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: bin.path), [], file: file, line: line)
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: destination.path), [source.lastPathComponent], file: file, line: line)
    }

    private func move(_ urls: [URL], fileManager: FileManager = .default,
                      onCommit: @escaping () throws -> Void) -> FileTransferReport {
        var changed = false
        return ops(fileManager: fileManager).transfer(
            urls: urls, to: destination, moving: true, resolve: { _ in .replace }, progressInterval: 0
        ) { progress in
            if progress.phase == .committing && !changed {
                changed = true
                do { try onCommit() } catch { XCTFail("Mutation failed: \(error)") }
            }
        }
    }

    private func ops(fileManager: FileManager = .default, sameVolume: Bool = false) -> FileOps {
        FileOps(fileManager: fileManager, sameVolume: { _, _ in sameVolume }, moveToTrash: { url in
            let target = self.bin.appendingPathComponent(UUID().uuidString)
            try self.fm.moveItem(at: url, to: target)
            return target
        })
    }

    private func write(_ name: String, _ body: String) throws -> URL {
        let file = source.appendingPathComponent(name)
        try Data(body.utf8).write(to: file)
        return file
    }

    private func tree() throws -> URL {
        let folder = source.appendingPathComponent("tree")
        try fm.createDirectory(at: folder.appendingPathComponent("inner/deeper"), withIntermediateDirectories: true)
        try Data("before".utf8).write(to: folder.appendingPathComponent("inner/deeper/note.txt"))
        return folder
    }

    private func text(_ url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }
}

private final class SafetyFileManager: FileManager, @unchecked Sendable {
    var failEnumeration = false
    var afterMove: ((URL, URL) throws -> Void)?

    override func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?,
                                     options mask: FileManager.DirectoryEnumerationOptions = []) throws -> [URL] {
        if failEnumeration { throw FileOpError("Injected inventory failure") }
        return try super.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: mask)
    }

    override func moveItem(at srcURL: URL, to dstURL: URL) throws {
        try super.moveItem(at: srcURL, to: dstURL)
        try afterMove?(srcURL, dstURL)
    }
}
