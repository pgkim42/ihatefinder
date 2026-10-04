import Darwin
import XCTest
@testable import IHateFinderCore

final class CloneCopyTests: XCTestCase {
    private var base: URL!
    private var source: URL!
    private var destination: URL!
    private var bin: URL!

    override func setUpWithError() throws {
        base = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("clone-copy-\(UUID())")
        source = base.appendingPathComponent("source")
        destination = base.appendingPathComponent("destination")
        bin = base.appendingPathComponent("bin")
        for directory in [source!, destination!, bin!] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: base)
    }

    // MARK: Contract 1: moveToTrash seam

    func testLegacyTrashClosureStillWorksAndYieldsNilTrashURLs() throws {
        var trashed: [String] = []
        let ops = FileOps(sameVolume: { _, _ in true }, trash: { trashed.append($0.lastPathComponent) })
        XCTAssertNil(try ops.moveToTrash(try makeFile("probe.txt", "p")))
        XCTAssertEqual(trashed, ["probe.txt"])

        let file = try makeFile("a.txt", "new")
        let target = destination.appendingPathComponent("a.txt")
        try Data("old".utf8).write(to: target)
        let report = ops.transfer(urls: [file], to: destination, moving: false, resolve: { _ in .replace })

        let item = try XCTUnwrap(report.items.first)
        XCTAssertEqual(item.status, .completed)
        XCTAssertTrue(item.replacedExisting)
        XCTAssertNil(item.replacedTrashURL)
        XCTAssertNil(item.sourceTrashURL)
        XCTAssertEqual(trashed.count, 2)
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "new")
    }

    func testMoveToTrashInitUsesTheSeamAndDefaultsCloneOff() {
        let ops = FileOps(sameVolume: { _, _ in true }, moveToTrash: { $0 })
        XCTAssertFalse(ops.cloneOnSameVolume)
        XCTAssertFalse(FileOps().cloneOnSameVolume)
        XCTAssertTrue(FileOps(cloneOnSameVolume: true).cloneOnSameVolume)
    }

    // MARK: Contract 2: result fields

    func testPlainCopyAndMoveReportNoReplacementFields() throws {
        let ops = injectedOps(sameVolume: true)
        let copied = ops.transfer(
            urls: [try makeFile("c.txt", "c")], to: destination, moving: false, resolve: { _ in .replace }
        )
        let moved = ops.transfer(
            urls: [try makeFile("m.txt", "m")], to: destination, moving: true, resolve: { _ in .replace }
        )
        for item in copied.items + moved.items {
            XCTAssertEqual(item.status, .completed)
            XCTAssertFalse(item.replacedExisting)
            XCTAssertNil(item.replacedTrashURL)
            XCTAssertNil(item.sourceTrashURL)
        }
    }

    func testReplaceReportsReplacedExistingAndTrashURL() throws {
        let file = try makeFile("r.txt", "new")
        let target = destination.appendingPathComponent("r.txt")
        try Data("old".utf8).write(to: target)
        let ops = injectedOps(sameVolume: true)

        let report = ops.transfer(urls: [file], to: destination, moving: true, resolve: { _ in .replace })

        let item = try XCTUnwrap(report.items.first)
        XCTAssertEqual(item.status, .completed)
        XCTAssertTrue(item.replacedExisting)
        let replacedURL = try XCTUnwrap(item.replacedTrashURL)
        XCTAssertEqual(replacedURL.deletingLastPathComponent().deletingLastPathComponent().path, bin.path)
        XCTAssertEqual(try String(contentsOf: replacedURL, encoding: .utf8), "old")
        XCTAssertNil(item.sourceTrashURL, "A same-volume move renames; it never trashes the source")
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "new")
    }

    func testKeepBothAndSkipDoNotReportReplacement() throws {
        let file = try makeFile("k.txt", "new")
        try Data("old".utf8).write(to: destination.appendingPathComponent("k.txt"))
        let ops = injectedOps(sameVolume: true)

        let kept = ops.transfer(urls: [file], to: destination, moving: false, resolve: { _ in .keepBoth })
        let skipped = ops.transfer(urls: [file], to: destination, moving: false, resolve: { _ in .skip })

        XCTAssertEqual(kept.items.first?.status, .completed)
        XCTAssertEqual(kept.items.first?.replacedExisting, false)
        XCTAssertEqual(skipped.items.first?.status, .skipped)
        XCTAssertEqual(skipped.items.first?.replacedExisting, false)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: bin.path), [])
    }

    func testCrossVolumeMoveReportsSourceTrashURL() throws {
        let file = try makeFile("x.txt", "payload")
        let ops = injectedOps(sameVolume: false)

        let report = ops.transfer(urls: [file], to: destination, moving: true, resolve: { _ in .replace })

        let item = try XCTUnwrap(report.items.first)
        XCTAssertEqual(item.status, .completed)
        XCTAssertFalse(item.replacedExisting)
        XCTAssertNil(item.replacedTrashURL)
        let trashURL = try XCTUnwrap(item.sourceTrashURL)
        XCTAssertEqual(try String(contentsOf: trashURL, encoding: .utf8), "payload")
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertEqual(try String(contentsOf: destination.appendingPathComponent("x.txt"), encoding: .utf8), "payload")
    }

    func testCrossVolumeMoveWithReplaceReportsBothTrashURLs() throws {
        let file = try makeFile("b.txt", "new")
        try Data("old".utf8).write(to: destination.appendingPathComponent("b.txt"))
        let ops = injectedOps(sameVolume: false)

        let report = ops.transfer(urls: [file], to: destination, moving: true, resolve: { _ in .replace })

        let item = try XCTUnwrap(report.items.first)
        XCTAssertEqual(item.status, .completed)
        XCTAssertTrue(item.replacedExisting)
        XCTAssertEqual(try String(contentsOf: try XCTUnwrap(item.replacedTrashURL), encoding: .utf8), "old")
        XCTAssertEqual(try String(contentsOf: try XCTUnwrap(item.sourceTrashURL), encoding: .utf8), "new")
    }

    func testFailedTrashLeavesTrashURLFieldsNilButKeepsReplacementFlag() throws {
        let file = try makeFile("f.txt", "new")
        let target = destination.appendingPathComponent("f.txt")
        try Data("old".utf8).write(to: target)
        let ops = FileOps(sameVolume: { _, _ in true }, moveToTrash: { _ in throw FileOpError("no trash") })

        let report = ops.transfer(urls: [file], to: destination, moving: false, resolve: { _ in .replace })

        let item = try XCTUnwrap(report.items.first)
        XCTAssertTrue(item.replacedExisting)
        XCTAssertNil(item.replacedTrashURL)
        XCTAssertEqual(item.recovery?.status, .manualRecoveryRequired)
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "new")
    }

    // MARK: Clone selection

    func testCloneSeamIsUsedOnlyWhenEnabledAndOnSameVolume() throws {
        let file = try makeFile("s.txt", "s")
        var calls: [String] = []

        func run(clone: Bool, same: Bool) throws {
            for url in try FileManager.default.contentsOfDirectory(at: destination, includingPropertiesForKeys: nil) {
                try FileManager.default.removeItem(at: url)
            }
            var ops = injectedOps(sameVolume: same, clone: clone)
            ops.copy = { s, d, c, _ in calls.append("copy"); try FileManager.default.copyItem(at: s, to: d) }
            ops.cloneCopy = { s, d, c, _ in calls.append("clone"); try FileManager.default.copyItem(at: s, to: d) }
            let report = ops.transfer(urls: [file], to: destination, moving: false, resolve: { _ in .replace })
            XCTAssertEqual(report.items.first?.status, .completed)
        }

        try run(clone: true, same: true)
        try run(clone: true, same: false)
        try run(clone: false, same: true)
        try run(clone: false, same: false)

        XCTAssertEqual(calls, ["clone", "copy", "copy", "copy"])
    }

    func testCloneEnabledAcrossVolumesStillReportsIntermediateByteSamples() throws {
        let file = try makeLargeFile()
        let ops = injectedOps(sameVolume: false, clone: true)
        var intermediate = false

        let report = ops.transfer(
            urls: [file], to: destination, moving: false, resolve: { _ in .replace }, progressInterval: 0
        ) { sample in
            if sample.phase == .copying, let total = sample.totalBytes,
               sample.bytesCopied > 0, sample.bytesCopied < total { intermediate = true }
        }

        XCTAssertEqual(report.items.first?.status, .completed)
        XCTAssertTrue(intermediate, "Cross-volume copies keep the data path with byte progress")
    }

    func testSameVolumeCloneCopiesLargeFileWithMetadataAndWithoutByteProgress() throws {
        try requireCloneSupport()
        let file = try makeLargeFile()
        let date = Date(timeIntervalSince1970: 1_600_000_000)
        try FileManager.default.setAttributes([.posixPermissions: 0o640, .modificationDate: date], ofItemAtPath: file.path)
        let attribute = Array("metadata".utf8)
        XCTAssertEqual(setxattr(file.path, "com.ihatefinder.test", attribute, attribute.count, 0, 0), 0)
        let before = try availableCapacity()
        var intermediate = false
        let ops = injectedOps(sameVolume: true, clone: true, realVolumeCheck: true)

        let report = ops.transfer(
            urls: [file], to: destination, moving: false, resolve: { _ in .replace }, progressInterval: 0
        ) { sample in
            if sample.phase == .copying, let total = sample.totalBytes,
               sample.bytesCopied > 0, sample.bytesCopied < total { intermediate = true }
        }

        let copy = destination.appendingPathComponent(file.lastPathComponent)
        XCTAssertEqual(report.items.first?.status, .completed)
        XCTAssertFalse(intermediate, "A clone is one step with no intermediate byte samples")
        XCTAssertEqual(try Data(contentsOf: copy), try Data(contentsOf: file))
        let attributes = try FileManager.default.attributesOfItem(atPath: copy.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o640)
        XCTAssertEqual((attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0, date.timeIntervalSince1970, accuracy: 1)
        var value = [UInt8](repeating: 0, count: 16)
        let length = getxattr(copy.path, "com.ihatefinder.test", &value, value.count, 0, 0)
        XCTAssertEqual(Array(value.prefix(max(0, length))), attribute)
        if let before, let after = try availableCapacity() {
            // Best effort: other processes write too, so only a clear 16 MiB drop counts.
            XCTAssertLessThan(before - after, 16 * 1024 * 1024, "A clone must not duplicate the file's blocks")
        }
    }

    func testSameVolumeCloneKeepsNestedFilesAndDanglingSymlink() throws {
        try requireCloneSupport()
        let folder = source.appendingPathComponent("tree")
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("inner"), withIntermediateDirectories: true)
        try Data("nested".utf8).write(to: folder.appendingPathComponent("inner/file.txt"))
        try FileManager.default.createSymbolicLink(atPath: folder.appendingPathComponent("dangling").path, withDestinationPath: "missing-target")
        let ops = injectedOps(sameVolume: true, clone: true, realVolumeCheck: true)

        let report = ops.transfer(urls: [folder], to: destination, moving: false, resolve: { _ in .replace })

        let copy = destination.appendingPathComponent("tree")
        XCTAssertEqual(report.items.first?.status, .completed)
        XCTAssertEqual(try String(contentsOf: copy.appendingPathComponent("inner/file.txt"), encoding: .utf8), "nested")
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: copy.appendingPathComponent("dangling").path), "missing-target")
        XCTAssertEqual(try String(contentsOf: folder.appendingPathComponent("inner/file.txt"), encoding: .utf8), "nested")
    }

    func testCloneReplaceStagesCopyAndSendsOldTargetThroughMoveToTrash() throws {
        try requireCloneSupport()
        let file = try makeFile("rep.txt", "new")
        let target = destination.appendingPathComponent("rep.txt")
        try Data("old".utf8).write(to: target)
        var trashed: [(url: URL, contents: String)] = []
        let ops = FileOps(
            sameVolume: FileOps.volumesMatch,
            moveToTrash: { url in
                let contents = try String(contentsOf: url, encoding: .utf8)
                let moved = self.bin.appendingPathComponent("replaced-rep.txt")
                try FileManager.default.moveItem(at: url, to: moved)
                trashed.append((url, contents))
                return moved
            },
            cloneOnSameVolume: true
        )

        let report = ops.transfer(urls: [file], to: destination, moving: false, resolve: { _ in .replace })

        let item = try XCTUnwrap(report.items.first)
        XCTAssertEqual(item.status, .completed)
        XCTAssertTrue(item.replacedExisting)
        XCTAssertEqual(item.replacedTrashURL, bin.appendingPathComponent("replaced-rep.txt"))
        XCTAssertEqual(trashed.map(\.contents), ["old"])
        XCTAssertTrue(trashed[0].url.path.contains(".ihatefinder-transfer-"), "The old target is trashed from the stage")
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "new")
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "new")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: destination.path), ["rep.txt"])
    }

    // MARK: Cancellation

    func testCancellationBeforeStartPublishesNothingAndLeavesNoStage() throws {
        let file = try makeFile("pre.txt", "pre")
        var cloneCalls = 0
        var ops = injectedOps(sameVolume: true, clone: true)
        ops.cloneCopy = { _, _, _, _ in cloneCalls += 1 }
        let cancellation = FileTransferCancellation()
        cancellation.cancel()

        let report = ops.transfer(
            urls: [file], to: destination, moving: false, resolve: { _ in .replace }, cancellation: cancellation
        )

        XCTAssertEqual(report.items.map(\.status), [.cancelled])
        XCTAssertEqual(cloneCalls, 0)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: destination.path), [])
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "pre")
    }

    func testNativeCloneCopyChecksCancellationBeforeStarting() throws {
        let file = try makeFile("native.txt", "n")
        let target = destination.appendingPathComponent("native.txt")
        let cancellation = FileTransferCancellation()
        cancellation.cancel()

        XCTAssertThrowsError(try NativeFileCopy.cloneCopy(file, target, cancellation) { _ in }) {
            XCTAssertTrue($0 is TransferCancelled)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
    }

    func testCancellationAfterCloneButBeforeCommitKeepsOldTargetAndCleansStage() throws {
        try requireCloneSupport()
        let file = try makeFile("late.txt", "new")
        let target = destination.appendingPathComponent("late.txt")
        try Data("old".utf8).write(to: target)
        let cancellation = FileTransferCancellation()
        var trashCalls = 0
        var ops = FileOps(
            sameVolume: FileOps.volumesMatch,
            moveToTrash: { _ in trashCalls += 1; return nil },
            cloneOnSameVolume: true
        )
        // A clone cannot be interrupted: the request lands after it finished.
        ops.cloneCopy = { source, destination, token, progress in
            try NativeFileCopy.cloneCopy(source, destination, token, progress)
            token?.cancel()
        }

        let report = ops.transfer(
            urls: [file], to: destination, moving: false, resolve: { _ in .replace }, cancellation: cancellation
        )

        let item = try XCTUnwrap(report.items.first)
        XCTAssertEqual(item.status, .cancelled)
        XCTAssertFalse(item.replacedExisting)
        XCTAssertEqual(report.completedSources, [])
        XCTAssertEqual(trashCalls, 0)
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "old")
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "new")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: destination.path), ["late.txt"])
    }

    // MARK: Helpers

    private func injectedOps(sameVolume: Bool, clone: Bool = false, realVolumeCheck: Bool = false) -> FileOps {
        let bin = self.bin!
        return FileOps(
            sameVolume: realVolumeCheck ? FileOps.volumesMatch : { _, _ in sameVolume },
            moveToTrash: { url in
                let holder = bin.appendingPathComponent(UUID().uuidString, isDirectory: true)
                try FileManager.default.createDirectory(at: holder, withIntermediateDirectories: true)
                let moved = holder.appendingPathComponent(url.lastPathComponent)
                try FileManager.default.moveItem(at: url, to: moved)
                return moved
            },
            cloneOnSameVolume: clone
        )
    }

    private func requireCloneSupport() throws {
        let supported = try base.resourceValues(forKeys: [.volumeSupportsFileCloningKey]).volumeSupportsFileCloning
        try XCTSkipUnless(supported == true, "The temporary volume does not support file cloning")
    }

    private func availableCapacity() throws -> Int64? {
        try base.resourceValues(forKeys: [.volumeAvailableCapacityKey]).volumeAvailableCapacity.map(Int64.init)
    }

    private func makeFile(_ name: String, _ body: String) throws -> URL {
        let url = source.appendingPathComponent(name)
        try Data(body.utf8).write(to: url)
        return url
    }

    private func makeLargeFile() throws -> URL {
        let url = source.appendingPathComponent("large.bin")
        try Data(repeating: 0x5a, count: 32 * 1024 * 1024).write(to: url)
        return url
    }
}
