import XCTest
@testable import IHateFinderCore

final class FileUndoSafetyTests: XCTestCase {
    private var root: URL!
    private var bin: URL!
    private var folder: URL!
    private var other: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("undo-safety-\(UUID())", isDirectory: true)
        bin = root.appendingPathComponent("bin", isDirectory: true)
        folder = root.appendingPathComponent("folder", isDirectory: true)
        other = root.appendingPathComponent("other", isDirectory: true)
        for directory in [bin!, folder!, other!] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: root)
    }

    // MARK: Helpers

    private func binTrash(in bin: URL) -> (URL) throws -> URL? {
        { url in
            let holder = bin.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: holder, withIntermediateDirectories: true)
            let moved = holder.appendingPathComponent(url.lastPathComponent)
            try FileManager.default.moveItem(at: url, to: moved)
            return moved
        }
    }

    private func ops(sameVolume: @escaping (URL, URL) -> Bool = { _, _ in true }) -> FileOps {
        FileOps(sameVolume: sameVolume, moveToTrash: binTrash(in: bin))
    }

    @discardableResult
    private func write(_ name: String, _ body: String, in directory: URL? = nil) throws -> URL {
        let url = (directory ?? folder).appendingPathComponent(name)
        try Data(body.utf8).write(to: url)
        return url
    }

    private func text(_ url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    private func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    private func statuses(_ report: FileUndoReport) -> [FileUndoItemResult.Status] {
        report.items.map(\.status)
    }

    // MARK: 1. Volumes without persistent IDs

    func testFileIDReadReturnsNilWhenVolumeHasNoPersistentIDs() throws {
        let file = try write("id.txt", "x")
        XCTAssertNotNil(FileID.read(at: file, supportsPersistentIDs: { _ in true }))
        XCTAssertNil(FileID.read(at: file, supportsPersistentIDs: { _ in false }))
    }

    func testRealTempVolumeReportsPersistentIDSupportConsistentWithTheFlag() throws {
        let file = try write("id.txt", "x")
        let flag = try file.resourceValues(forKeys: [.volumeSupportsPersistentIDsKey]).volumeSupportsPersistentIDs
        XCTAssertEqual(FileID.volumeSupportsPersistentIDs(file), flag ?? false)
        XCTAssertEqual(FileID.read(at: file) != nil, flag ?? false)
    }

    func testNonPersistentIDVolumeMakesRecordsUnverifiableAndNothingMoves() throws {
        var blind = ops()
        blind.fileIdentity = { FileID.read(at: $0, supportsPersistentIDs: { _ in false }) }
        let created = try write("created.txt", "c")
        let trashed = try write("trashed.txt", "t")
        let moved = try write("moved.txt", "m")

        let createdRecord = try XCTUnwrap(blind.undoRecord(created: created))
        let trashReport = blind.trash(urls: [trashed])
        let trashRecord = try XCTUnwrap(blind.undoRecord(trash: trashReport))
        let moveReport = blind.transfer(urls: [moved], to: other, moving: true, resolve: { _ in .replace })
        let moveRecord = try XCTUnwrap(blind.undoRecord(transfer: moveReport, moving: true))

        XCTAssertEqual(statuses(blind.undo(createdRecord)), [.unverifiable])
        XCTAssertEqual(statuses(blind.undo(trashRecord)), [.unverifiable])
        XCTAssertEqual(statuses(blind.undo(moveRecord)), [.unverifiable])
        XCTAssertEqual(try text(created), "c")
        XCTAssertFalse(exists(trashed))
        XCTAssertEqual(try text(try XCTUnwrap(trashReport.items[0].trashedURL)), "t")
        XCTAssertEqual(try text(other.appendingPathComponent("moved.txt")), "m")
        XCTAssertFalse(exists(moved))
    }

    func testIdentityRecordedNormallyButUndoRunsOnNonPersistentVolumeIsUnverifiable() throws {
        let normal = ops()
        let created = try write("created.txt", "c")
        let record = try XCTUnwrap(normal.undoRecord(created: created))
        var blind = ops()
        blind.fileIdentity = { _ in nil }

        XCTAssertEqual(statuses(blind.undo(record)), [.unverifiable])
        XCTAssertEqual(try text(created), "c")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: bin.path), [])
    }

    // MARK: 2. Identity captured when each result is produced

    func testTwoSameNamedSourcesInOneBatchKeepTheirOwnIdentitiesAndUndoRestoresBoth() throws {
        let first = root.appendingPathComponent("s1", isDirectory: true)
        let second = root.appendingPathComponent("s2", isDirectory: true)
        let dest = root.appendingPathComponent("D", isDirectory: true)
        for directory in [first, second, dest] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let a1 = try write("a", "one", in: first)
        let a2 = try write("a", "two", in: second)
        let ops = ops()

        let report = ops.transfer(urls: [a1, a2], to: dest, moving: true, resolve: { _ in .replace })

        XCTAssertEqual(report.items.map(\.status), [.completed, .completed])
        XCTAssertNotNil(report.items[0].destinationID)
        XCTAssertNotEqual(report.items[0].destinationID, report.items[1].destinationID,
                          "The first result must not carry the second item's identity")
        XCTAssertTrue(report.items[1].replacedExisting)
        let record = try XCTUnwrap(ops.undoRecord(transfer: report, moving: true))
        XCTAssertEqual(try text(dest.appendingPathComponent("a")), "two")

        let undo = ops.undo(record)

        XCTAssertEqual(statuses(undo), [.undone, .undone])
        XCTAssertEqual(try text(a1), "one")
        XCTAssertEqual(try text(a2), "two")
        XCTAssertFalse(exists(dest.appendingPathComponent("a")))
    }

    func testTwoSameNamedCopiesInOneBatchUndoTrashesTheRightItems() throws {
        let first = root.appendingPathComponent("s1", isDirectory: true)
        let second = root.appendingPathComponent("s2", isDirectory: true)
        let dest = root.appendingPathComponent("D", isDirectory: true)
        for directory in [first, second, dest] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let a1 = try write("a", "one", in: first)
        let a2 = try write("a", "two", in: second)
        let ops = ops()
        let report = ops.transfer(urls: [a1, a2], to: dest, moving: false, resolve: { _ in .replace })
        let record = try XCTUnwrap(ops.undoRecord(transfer: report, moving: false))

        let undo = ops.undo(record)

        XCTAssertEqual(statuses(undo), [.undone, .undone])
        XCTAssertFalse(exists(dest.appendingPathComponent("a")), "Both copies are gone; the original slot was empty")
        XCTAssertEqual(try text(a1), "one")
        XCTAssertEqual(try text(a2), "two")
    }

    // MARK: 3. movedInPlace comes from write(), not from parent folders

    func testRecordUsesTheItemLevelSameVolumeDecisionNotTheParentFolders() throws {
        // Answers true for the item (a file), false for folders: old parent-derived logic disagreed.
        let itemOnly: (URL, URL) -> Bool = { source, _ in source.pathExtension == "txt" }
        let ops = ops(sameVolume: itemOnly)
        let file = try write("m.txt", "m")
        XCTAssertFalse(itemOnly(folder, other))

        let report = ops.transfer(urls: [file], to: other, moving: true, resolve: { _ in .replace })
        let record = try XCTUnwrap(ops.undoRecord(transfer: report, moving: true))

        XCTAssertTrue(report.items[0].movedInPlace)
        guard case .moved(_, _, _, let same, let sourceTrash, _) = record.items[0] else { return XCTFail("expected .moved") }
        XCTAssertTrue(same)
        XCTAssertNil(sourceTrash)
        XCTAssertEqual(statuses(ops.undo(record)), [.undone])
        XCTAssertEqual(try text(file), "m")
    }

    func testRecordForCrossVolumeItemKeepsSourceTrashEvenWhenParentFoldersLookSameVolume() throws {
        let itemDiffers: (URL, URL) -> Bool = { source, _ in source.pathExtension != "bin" }
        let ops = ops(sameVolume: itemDiffers)
        let file = try write("big.bin", "payload")

        let report = ops.transfer(urls: [file], to: other, moving: true, resolve: { _ in .replace })
        let record = try XCTUnwrap(ops.undoRecord(transfer: report, moving: true))

        XCTAssertFalse(report.items[0].movedInPlace)
        guard case .moved(_, _, _, let same, let sourceTrash, _) = record.items[0] else { return XCTFail("expected .moved") }
        XCTAssertFalse(same)
        XCTAssertNotNil(sourceTrash)
        XCTAssertEqual(statuses(ops.undo(record)), [.undone])
        XCTAssertEqual(try text(file), "payload")
        XCTAssertFalse(exists(other.appendingPathComponent("big.bin")))
    }

    func testCopiesAndSameVolumeStagedReplaceReportMovedInPlaceCorrectly() throws {
        let ops = ops()
        let copy = try write("c.txt", "c")
        let copied = ops.transfer(urls: [copy], to: other, moving: false, resolve: { _ in .replace })
        XCTAssertFalse(copied.items[0].movedInPlace)

        let file = try write("r.txt", "new")
        try write("r.txt", "old", in: other)
        let replaced = ops.transfer(urls: [file], to: other, moving: true, resolve: { _ in .replace })
        XCTAssertTrue(replaced.items[0].movedInPlace)
        XCTAssertTrue(replaced.items[0].replacedExisting)
    }

    // MARK: 4. Partial undo reporting

    func testCrossVolumeUndoThatCannotTrashTheCopyIsPartialAndNamesWhereTheCopyStays() throws {
        let ops = ops(sameVolume: { _, _ in false })
        let file = try write("x.txt", "payload")
        let report = ops.transfer(urls: [file], to: other, moving: true, resolve: { _ in .replace })
        let record = try XCTUnwrap(ops.undoRecord(transfer: report, moving: true))
        var failing = ops
        failing.moveToTrash = { _ in throw FileOpError("휴지통 거부") }

        let undo = failing.undo(record)

        XCTAssertEqual(statuses(undo), [.partiallyUndone])
        XCTAssertEqual(try text(file), "payload")
        let copy = other.appendingPathComponent("x.txt")
        XCTAssertEqual(try text(copy), "payload")
        let item = undo.items[0]
        XCTAssertEqual(item.restored, [file])
        XCTAssertTrue(try XCTUnwrap(item.message).contains(copy.path))
        XCTAssertEqual(undo.undone.count, 0)
        XCTAssertEqual(undo.partial.count, 1)
        XCTAssertEqual(undo.skipped.count, 0)
    }

    func testCrossVolumeMoveThatReplacedAnItemUndoRestoresAllThree() throws {
        let ops = ops(sameVolume: { _, _ in false })
        let file = try write("x.txt", "new")
        let target = try write("x.txt", "old", in: other)
        let report = ops.transfer(urls: [file], to: other, moving: true, resolve: { _ in .replace })
        XCTAssertTrue(report.items[0].replacedExisting)
        XCTAssertNotNil(report.items[0].sourceTrashURL)
        XCTAssertNotNil(report.items[0].replacedTrashURL)
        let record = try XCTUnwrap(ops.undoRecord(transfer: report, moving: true))

        let undo = ops.undo(record)

        XCTAssertEqual(statuses(undo), [.undone])
        XCTAssertEqual(try text(file), "new")
        XCTAssertEqual(try text(target), "old")
        XCTAssertEqual(Set(undo.restoredURLs), [file, target])
    }

    func testCrossVolumeReplaceUndoWithUntrashableCopyMentionsTheOldItemStaysInTheBin() throws {
        let ops = ops(sameVolume: { _, _ in false })
        let file = try write("x.txt", "new")
        try write("x.txt", "old", in: other)
        let report = ops.transfer(urls: [file], to: other, moving: true, resolve: { _ in .replace })
        let replacedTrash = try XCTUnwrap(report.items[0].replacedTrashURL)
        let record = try XCTUnwrap(ops.undoRecord(transfer: report, moving: true))
        var failing = ops
        failing.moveToTrash = { _ in throw FileOpError("휴지통 거부") }

        let undo = failing.undo(record)

        XCTAssertEqual(statuses(undo), [.partiallyUndone])
        let message = try XCTUnwrap(undo.items[0].message)
        XCTAssertTrue(message.contains(replacedTrash.path), message)
        XCTAssertEqual(try text(replacedTrash), "old", "The old item stays in the bin")
        XCTAssertEqual(try text(other.appendingPathComponent("x.txt")), "new")
    }

    func testReplaceCopyUndoWhoseOldSlotGetsTakenIsPartialAndNamesTheBinPath() throws {
        let ops = ops()
        let file = try write("r.txt", "new")
        let target = try write("r.txt", "old", in: other)
        let report = ops.transfer(urls: [file], to: other, moving: false, resolve: { _ in .replace })
        let replacedTrash = try XCTUnwrap(report.items[0].replacedTrashURL)
        let record = try XCTUnwrap(ops.undoRecord(transfer: report, moving: false))
        let trash = binTrash(in: bin)
        var racing = ops
        // Someone re-creates the slot right after the new item is trashed.
        racing.moveToTrash = { url in
            let moved = try trash(url)
            try Data("squatter".utf8).write(to: url)
            return moved
        }

        let undo = racing.undo(record)

        XCTAssertEqual(statuses(undo), [.partiallyUndone])
        XCTAssertEqual(try text(target), "squatter")
        XCTAssertEqual(try text(replacedTrash), "old")
        XCTAssertTrue(try XCTUnwrap(undo.items[0].message).contains(replacedTrash.path))
    }

    func testReplaceCopyUndoWhoseBinItemCannotBeMovedIsPartialAndNamesTheBinPath() throws {
        let ops = ops()
        let file = try write("r.txt", "new")
        let target = try write("r.txt", "old", in: other)
        let report = ops.transfer(urls: [file], to: other, moving: false, resolve: { _ in .replace })
        let replacedTrash = try XCTUnwrap(report.items[0].replacedTrashURL)
        let record = try XCTUnwrap(ops.undoRecord(transfer: report, moving: false))
        let trash = binTrash(in: bin)
        var vanishing = ops
        // The old item disappears from the bin while the new one is being trashed.
        vanishing.moveToTrash = { url in
            let moved = try trash(url)
            try FileManager.default.removeItem(at: replacedTrash)
            return moved
        }

        let undo = vanishing.undo(record)

        XCTAssertEqual(statuses(undo), [.partiallyUndone])
        XCTAssertFalse(exists(target))
        XCTAssertTrue(try XCTUnwrap(undo.items[0].message).contains(replacedTrash.path))
    }

    // MARK: Case-sensitive volume

    func testCaseOnlyRenameUndoOnACaseSensitiveVolume() throws {
        let image = root.appendingPathComponent("cs.sparseimage")
        let mount = root.appendingPathComponent("cs-mount", isDirectory: true)
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
        try runTool("/usr/bin/hdiutil", ["create", "-size", "8m", "-fs", "Case-sensitive APFS",
                                          "-volname", "IHFCS", "-type", "SPARSE", image.path])
        do {
            try runTool("/usr/bin/hdiutil", ["attach", image.path, "-mountpoint", mount.path, "-nobrowse"])
        } catch {
            throw XCTSkip("Cannot attach a case-sensitive test volume: \(error)")
        }
        defer { _ = try? runTool("/usr/bin/hdiutil", ["detach", mount.path, "-force"]) }
        let ops = ops()
        let note = try write("Note.txt", "n", in: mount)
        try write("note.txt.keep", "other", in: mount)
        let outcome = try ops.rename(url: note, to: "note.txt", resolve: { _ in .replace })
        let record = try XCTUnwrap(ops.undoRecord(rename: outcome, from: note))
        XCTAssertTrue(exists(mount.appendingPathComponent("note.txt")))
        XCTAssertFalse(exists(note), "On a case-sensitive volume the old name really is gone")

        let undo = ops.undo(record)

        XCTAssertEqual(statuses(undo), [.undone])
        XCTAssertEqual(try text(note), "n")
        XCTAssertFalse(exists(mount.appendingPathComponent("note.txt")))
    }

    @discardableResult
    private func runTool(_ path: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(decoding: data, as: UTF8.self)
        guard process.terminationStatus == 0 else { throw FileOpError("\(path) failed: \(output)") }
        return output
    }
}
