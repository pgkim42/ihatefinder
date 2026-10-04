import XCTest
@testable import IHateFinderCore

final class FileUndoTests: XCTestCase {
    private var root: URL!
    private var bin: URL!
    private var folder: URL!
    private var other: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("undo-\(UUID())", isDirectory: true)
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

    private func ops(sameVolume: Bool = true, noTrashURL: Bool = false) -> FileOps {
        let bin = self.bin!
        return FileOps(sameVolume: { _, _ in sameVolume }, moveToTrash: { url in
            let holder = bin.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: holder, withIntermediateDirectories: true)
            let moved = holder.appendingPathComponent(url.lastPathComponent)
            try FileManager.default.moveItem(at: url, to: moved)
            return noTrashURL ? nil : moved
        })
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

    private func transferRecord(_ ops: FileOps, urls: [URL], to dest: URL, moving: Bool,
                                resolve: NameConflict = .replace) throws -> UndoRecord {
        let report = ops.transfer(urls: urls, to: dest, moving: moving, resolve: { _ in resolve })
        return try XCTUnwrap(ops.undoRecord(transfer: report, moving: moving))
    }

    private func statuses(_ report: FileUndoReport) -> [FileUndoItemResult.Status] {
        report.items.map(\.status)
    }

    /// Swaps the Trash item at `url` for a different file with the same name.
    private func swapForDifferentFile(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
        try Data("impostor".utf8).write(to: url)
    }

    // MARK: Records

    func testRecordsExcludeSkippedFailedCancelledAndUnprocessedItems() throws {
        let ops = ops()
        let ok = try write("ok.txt", "ok")
        let skip = try write("skip.txt", "skip")
        try write("skip.txt", "existing", in: other)
        let missing = folder.appendingPathComponent("missing.txt")
        let never = try write("never.txt", "never")

        // Skip keeps the pre-existing target; the missing source fails and stops the rest.
        let report = ops.transfer(
            urls: [ok, skip, missing, never], to: other, moving: false,
            resolve: { _ in .skip }
        )
        XCTAssertEqual(report.items.map(\.status), [.completed, .skipped, .failed, .unprocessed])
        let record = try XCTUnwrap(ops.undoRecord(transfer: report, moving: false))

        XCTAssertEqual(record.items.count, 1)
        guard case .copied(let dest, _, _) = record.items[0] else { return XCTFail("expected .copied") }
        XCTAssertEqual(dest, other.appendingPathComponent("ok.txt"))

        let cancellation = FileTransferCancellation()
        cancellation.cancel()
        let cancelled = ops.transfer(urls: [ok], to: other, moving: false, resolve: { _ in .replace }, cancellation: cancellation)
        XCTAssertEqual(cancelled.items.map(\.status), [.cancelled])
        XCTAssertNil(ops.undoRecord(transfer: cancelled, moving: false))
    }

    func testSameFolderMoveIsANoOpWithoutRecord() throws {
        let ops = ops()
        let file = try write("stay.txt", "x")
        let report = ops.transfer(urls: [file], to: folder, moving: true, resolve: { _ in .replace })
        XCTAssertEqual(report.items.map(\.status), [.completed])
        XCTAssertNil(ops.undoRecord(transfer: report, moving: true))
    }

    func testRenameRecordIsNilForSkipUnchangedAndTitlesReflectOperation() throws {
        let ops = ops()
        let a = try write("a.txt", "a")
        XCTAssertNil(ops.undoRecord(rename: .skipped, from: a))
        XCTAssertNil(ops.undoRecord(rename: .unchanged, from: a))
        XCTAssertEqual(ops.undoRecord(created: a)?.title, "새로 만들기")
        let moved = try transferRecord(ops, urls: [a], to: other, moving: true)
        XCTAssertEqual(moved.title, "옮기기")
    }

    func testPartialTrashReportRecordsOnlyTrashedItems() throws {
        let one = try write("one.txt", "1")
        let two = try write("two.txt", "2")
        let bin = self.bin!
        let ops = FileOps(sameVolume: { _, _ in true }, moveToTrash: { url in
            if url.lastPathComponent == "two.txt" { throw FileOpError("거부됨") }
            let moved = bin.appendingPathComponent(url.lastPathComponent)
            try FileManager.default.moveItem(at: url, to: moved)
            return moved
        })

        let report = ops.trash(urls: [one, two])
        let record = try XCTUnwrap(ops.undoRecord(trash: report))

        XCTAssertEqual(record.items.count, 1)
        guard case .trashed(let original, _) = record.items[0] else { return XCTFail("expected .trashed") }
        XCTAssertEqual(original, one)
    }

    func testTrashRecordIsNilWhenNothingWasTrashedOrTrashURLUnknown() throws {
        let one = try write("one.txt", "1")
        let failing = FileOps(sameVolume: { _, _ in true }, moveToTrash: { _ in throw FileOpError("거부됨") })
        XCTAssertNil(failing.undoRecord(trash: failing.trash(urls: [one])))
        let legacy = FileOps(sameVolume: { _, _ in true }, trash: { _ in })
        XCTAssertNil(legacy.undoRecord(trash: legacy.trash(urls: [one])))
    }

    // MARK: Rename

    func testKeepBothRenameUndoMovesNewNameBackAndLeavesExistingItem() throws {
        let ops = ops()
        let a = try write("a.txt", "a")
        let b = try write("b.txt", "pre-existing")
        let outcome = try ops.rename(url: a, to: "b.txt", resolve: { _ in .keepBoth })
        let record = try XCTUnwrap(ops.undoRecord(rename: outcome, from: a))

        let report = ops.undo(record)

        XCTAssertEqual(statuses(report), [.undone])
        XCTAssertEqual(try text(a), "a")
        XCTAssertEqual(try text(b), "pre-existing")
        XCTAssertFalse(exists(folder.appendingPathComponent("b (1).txt")))
        XCTAssertEqual(report.restoredURLs, [a])
    }

    func testRenameUndoWithOldNameTakenIsOccupiedAndNothingMoves() throws {
        let ops = ops()
        let a = try write("a.txt", "a")
        let outcome = try ops.rename(url: a, to: "c.txt", resolve: { _ in .replace })
        let record = try XCTUnwrap(ops.undoRecord(rename: outcome, from: a))
        try write("a.txt", "newcomer")

        let report = ops.undo(record)

        XCTAssertEqual(statuses(report), [.occupied])
        XCTAssertEqual(try text(a), "newcomer")
        XCTAssertEqual(try text(folder.appendingPathComponent("c.txt")), "a")
    }

    func testCaseOnlyRenameUndoRestoresOriginalCase() throws {
        let ops = ops()
        let a = try write("Note.txt", "n")
        let outcome = try ops.rename(url: a, to: "note.txt", resolve: { _ in .replace })
        let record = try XCTUnwrap(ops.undoRecord(rename: outcome, from: a))

        let report = ops.undo(record)

        XCTAssertEqual(statuses(report), [.undone])
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        XCTAssertEqual(names, ["Note.txt"])
    }

    func testRenameReplaceUndoRestoresTheReplacedItemFromTheBin() throws {
        let ops = ops()
        let a = try write("a.txt", "new")
        let b = try write("b.txt", "old")
        let outcome = try ops.rename(url: a, to: "b.txt", resolve: { _ in .replace })
        let record = try XCTUnwrap(ops.undoRecord(rename: outcome, from: a))

        let report = ops.undo(record)

        XCTAssertEqual(statuses(report), [.undone])
        XCTAssertEqual(try text(a), "new")
        XCTAssertEqual(try text(b), "old")
    }

    // MARK: Trash

    func testTrashUndoRestoresTheItem() throws {
        let ops = ops()
        let one = try write("one.txt", "1")
        let record = try XCTUnwrap(ops.undoRecord(trash: ops.trash(urls: [one])))
        XCTAssertFalse(exists(one))

        let report = ops.undo(record)

        XCTAssertEqual(statuses(report), [.undone])
        XCTAssertEqual(try text(one), "1")
        XCTAssertEqual(report.restoredURLs, [one])
    }

    func testTrashUndoWithOriginalPathReoccupiedIsOccupiedAndBothItemsIntact() throws {
        let ops = ops()
        let one = try write("one.txt", "1")
        let report = ops.trash(urls: [one])
        let record = try XCTUnwrap(ops.undoRecord(trash: report))
        try write("one.txt", "newcomer")

        let result = ops.undo(record)

        XCTAssertEqual(statuses(result), [.occupied])
        XCTAssertEqual(try text(one), "newcomer")
        XCTAssertEqual(try text(try XCTUnwrap(report.items[0].trashedURL)), "1")
    }

    func testTrashUndoWithMissingParentIsMissing() throws {
        let ops = ops()
        let nested = folder.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let one = try write("one.txt", "1", in: nested)
        let record = try XCTUnwrap(ops.undoRecord(trash: ops.trash(urls: [one])))
        try FileManager.default.removeItem(at: nested)

        XCTAssertEqual(statuses(ops.undo(record)), [.missing])
    }

    func testTrashUndoRestoresMultipleItemsAndSkipsOnlyTheBlockedOne() throws {
        let ops = ops()
        let one = try write("one.txt", "1")
        let two = try write("two.txt", "2")
        let record = try XCTUnwrap(ops.undoRecord(trash: ops.trash(urls: [one, two])))
        try write("one.txt", "newcomer")

        let report = ops.undo(record)

        // Reverse order: two first, then one.
        XCTAssertEqual(statuses(report), [.undone, .occupied])
        XCTAssertEqual(try text(two), "2")
        XCTAssertEqual(try text(one), "newcomer")
    }

    // MARK: Created

    func testCreateUndoTrashesTheItem() throws {
        let ops = ops()
        let created = try ops.createFolder(in: folder)
        let record = try XCTUnwrap(ops.undoRecord(created: created))

        let report = ops.undo(record)

        XCTAssertEqual(statuses(report), [.undone])
        XCTAssertFalse(exists(created))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: bin.path).count, 1)
    }

    func testCreateUndoAfterReplacementByDifferentFileIsStaleAndTrashesNothing() throws {
        let ops = ops()
        let created = try ops.createTextFile(in: folder)
        let record = try XCTUnwrap(ops.undoRecord(created: created))
        try FileManager.default.removeItem(at: created)
        try Data("someone else".utf8).write(to: created)

        let report = ops.undo(record)

        XCTAssertEqual(statuses(report), [.stale])
        XCTAssertEqual(try text(created), "someone else")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: bin.path), [])
    }

    func testCreateUndoOfMissingItemIsMissing() throws {
        let ops = ops()
        let created = try ops.createTextFile(in: folder)
        let record = try XCTUnwrap(ops.undoRecord(created: created))
        try FileManager.default.removeItem(at: created)
        XCTAssertEqual(statuses(ops.undo(record)), [.missing])
    }

    func testNilIdentityIsUnverifiableAndNothingMoves() throws {
        let ops = ops()
        let file = try write("blind.txt", "x")
        let record = UndoRecord(title: "새로 만들기", items: [.created(file, id: nil)])

        XCTAssertEqual(statuses(ops.undo(record)), [.unverifiable])
        XCTAssertEqual(try text(file), "x")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: bin.path), [])
    }

    // MARK: Moves

    func testSameVolumeMoveUndoMovesItBack() throws {
        let ops = ops()
        let file = try write("m.txt", "m")
        let record = try transferRecord(ops, urls: [file], to: other, moving: true)
        XCTAssertFalse(exists(file))

        let report = ops.undo(record)

        XCTAssertEqual(statuses(report), [.undone])
        XCTAssertEqual(try text(file), "m")
        XCTAssertFalse(exists(other.appendingPathComponent("m.txt")))
    }

    func testSameVolumeMoveUndoIsOccupiedWhenOriginalSpotIsTaken() throws {
        let ops = ops()
        let file = try write("m.txt", "m")
        let record = try transferRecord(ops, urls: [file], to: other, moving: true)
        try write("m.txt", "newcomer")

        let report = ops.undo(record)

        XCTAssertEqual(statuses(report), [.occupied])
        XCTAssertEqual(try text(file), "newcomer")
        XCTAssertEqual(try text(other.appendingPathComponent("m.txt")), "m")
    }

    func testCrossVolumeMoveUndoRestoresOriginalFromBinAndTrashesTheCopy() throws {
        let ops = ops(sameVolume: false)
        let file = try write("x.txt", "payload")
        let record = try transferRecord(ops, urls: [file], to: other, moving: true)
        XCTAssertFalse(exists(file))

        let report = ops.undo(record)

        XCTAssertEqual(statuses(report), [.undone])
        XCTAssertEqual(try text(file), "payload")
        XCTAssertFalse(exists(other.appendingPathComponent("x.txt")))
        XCTAssertEqual(report.restoredURLs, [file])
    }

    func testCrossVolumeMoveUndoWithoutSourceTrashURLIsNotRestorableAndChangesNothing() throws {
        let ops = ops(sameVolume: false, noTrashURL: true)
        let file = try write("x.txt", "payload")
        let record = try transferRecord(ops, urls: [file], to: other, moving: true)

        let report = ops.undo(record)

        XCTAssertEqual(statuses(report), [.notRestorable])
        XCTAssertEqual(try text(other.appendingPathComponent("x.txt")), "payload")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: bin.path).count, 1,
                       "No duplicate may be added to the bin")
    }

    // MARK: Copies and replacement

    func testCopyUndoTrashesTheCopyAndKeepsTheSource() throws {
        let ops = ops()
        let file = try write("c.txt", "c")
        let record = try transferRecord(ops, urls: [file], to: other, moving: false)

        let report = ops.undo(record)

        XCTAssertEqual(statuses(report), [.undone])
        XCTAssertFalse(exists(other.appendingPathComponent("c.txt")))
        XCTAssertEqual(try text(file), "c")
    }

    func testReplaceCopyUndoTrashesNewItemAndRestoresOldOneFromBin() throws {
        let ops = ops()
        let file = try write("r.txt", "new")
        let target = try write("r.txt", "old", in: other)
        let record = try transferRecord(ops, urls: [file], to: other, moving: false)
        XCTAssertEqual(try text(target), "new")

        let report = ops.undo(record)

        XCTAssertEqual(statuses(report), [.undone])
        XCTAssertEqual(try text(target), "old")
        XCTAssertEqual(report.restoredURLs, [target])
        XCTAssertEqual(try text(file), "new")
    }

    func testReplaceCopyUndoWithNilReplacedTrashURLIsNotRestorableAndKeepsNewItem() throws {
        let ops = ops(noTrashURL: true)
        let file = try write("r.txt", "new")
        let target = try write("r.txt", "old", in: other)
        let record = try transferRecord(ops, urls: [file], to: other, moving: false)

        let report = ops.undo(record)

        XCTAssertEqual(statuses(report), [.notRestorable])
        XCTAssertEqual(try text(target), "new")
    }

    func testReplaceMoveUndoMovesBackAndRestoresOldItem() throws {
        let ops = ops()
        let file = try write("r.txt", "new")
        let target = try write("r.txt", "old", in: other)
        let record = try transferRecord(ops, urls: [file], to: other, moving: true)

        let report = ops.undo(record)

        XCTAssertEqual(statuses(report), [.undone])
        XCTAssertEqual(try text(file), "new")
        XCTAssertEqual(try text(target), "old")
    }

    // MARK: Trash identity mismatch (ARC2-03 / CR2-03)

    func testTrashedItemWhoseBinFileWasSwappedIsStaleAndNotMoved() throws {
        let ops = ops()
        let one = try write("one.txt", "1")
        let report = ops.trash(urls: [one])
        let record = try XCTUnwrap(ops.undoRecord(trash: report))
        let binFile = try XCTUnwrap(report.items[0].trashedURL)
        try swapForDifferentFile(binFile)

        let result = ops.undo(record)

        XCTAssertEqual(statuses(result), [.stale])
        XCTAssertFalse(exists(one))
        XCTAssertEqual(try text(binFile), "impostor")
    }

    func testReplacedTrashSwappedMakesReplaceCopyUndoStaleAndLeavesNewItem() throws {
        let ops = ops()
        let file = try write("r.txt", "new")
        let target = try write("r.txt", "old", in: other)
        let report = ops.transfer(urls: [file], to: other, moving: false, resolve: { _ in .replace })
        let record = try XCTUnwrap(ops.undoRecord(transfer: report, moving: false))
        let binFile = try XCTUnwrap(report.items[0].replacedTrashURL)
        try swapForDifferentFile(binFile)

        let result = ops.undo(record)

        XCTAssertEqual(statuses(result), [.stale])
        XCTAssertEqual(try text(target), "new", "The new item stays in place")
        XCTAssertEqual(try text(binFile), "impostor")
    }

    func testSourceTrashSwappedMakesCrossVolumeMoveUndoStaleAndMovesNothing() throws {
        let ops = ops(sameVolume: false)
        let file = try write("x.txt", "payload")
        let report = ops.transfer(urls: [file], to: other, moving: true, resolve: { _ in .replace })
        let record = try XCTUnwrap(ops.undoRecord(transfer: report, moving: true))
        let binFile = try XCTUnwrap(report.items[0].sourceTrashURL)
        try swapForDifferentFile(binFile)

        let result = ops.undo(record)

        XCTAssertEqual(statuses(result), [.stale])
        XCTAssertFalse(exists(file))
        XCTAssertEqual(try text(other.appendingPathComponent("x.txt")), "payload")
        XCTAssertEqual(try text(binFile), "impostor")
    }

    func testBinItemRemovedBeforeUndoIsMissing() throws {
        let ops = ops()
        let one = try write("one.txt", "1")
        let report = ops.trash(urls: [one])
        let record = try XCTUnwrap(ops.undoRecord(trash: report))
        try FileManager.default.removeItem(at: try XCTUnwrap(report.items[0].trashedURL))

        XCTAssertEqual(statuses(ops.undo(record)), [.missing])
        XCTAssertFalse(exists(one))
    }

    // MARK: Journal

    func testJournalIsLifoAndKeepsAtMostFiftyRecords() {
        let journal = FileUndoJournal()
        XCTAssertNil(journal.peek)
        XCTAssertNil(journal.popLast())
        for number in 0..<(FileUndoJournal.limit + 5) {
            journal.push(UndoRecord(title: "r\(number)", items: []))
        }

        XCTAssertEqual(journal.count, 50)
        XCTAssertEqual(journal.peek?.title, "r54")
        XCTAssertEqual(journal.popLast()?.title, "r54")
        XCTAssertEqual(journal.popLast()?.title, "r53")
        XCTAssertEqual(journal.count, 48)
        while journal.popLast() != nil {}
        XCTAssertEqual(journal.count, 0)
        journal.push(UndoRecord(title: "again", items: []))
        journal.clear()
        XCTAssertNil(journal.peek)
    }
}
