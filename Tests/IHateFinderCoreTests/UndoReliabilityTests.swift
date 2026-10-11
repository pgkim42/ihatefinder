import XCTest
@testable import IHateFinderCore

final class UndoReliabilityTests: XCTestCase {
    private var root: URL!
    private var source: URL!
    private var destination: URL!
    private var bin: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("undo-reliability-\(UUID())", isDirectory: true)
        source = root.appendingPathComponent("source", isDirectory: true)
        destination = root.appendingPathComponent("destination", isDirectory: true)
        bin = root.appendingPathComponent("bin", isDirectory: true)
        for directory in [source!, destination!, bin!] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: root)
    }

    private func ops(sameVolume: Bool = false) -> FileOps {
        let bin = self.bin!
        return FileOps(sameVolume: { _, _ in sameVolume }, moveToTrash: { url in
            let holder = bin.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: holder, withIntermediateDirectories: true)
            let target = holder.appendingPathComponent(url.lastPathComponent)
            try FileManager.default.moveItem(at: url, to: target)
            return target
        })
    }

    @discardableResult
    private func write(_ name: String, _ body: String, in directory: URL? = nil) throws -> URL {
        let url = (directory ?? source).appendingPathComponent(name)
        try Data(body.utf8).write(to: url)
        return url
    }

    private func editInPlace(_ url: URL, _ body: String) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.truncate(atOffset: 0)
        try handle.write(contentsOf: Data(body.utf8))
    }

    private func text(_ url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    private func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    private func move(_ urls: [URL], using ops: FileOps) throws -> (FileTransferReport, UndoRecord) {
        let report = ops.transfer(urls: urls, to: destination, moving: true, resolve: { _ in .replace })
        XCTAssertEqual(report.items.map(\.status), urls.map { _ in .completed })
        return (report, try XCTUnwrap(ops.undoRecord(transfer: report, moving: true)))
    }

    func testReportInitializerDefaultsToNoRetry() {
        XCTAssertNil(FileUndoReport(title: "옮기기", items: []).retryRecord)
    }

    func testUnchangedCrossVolumeUndoKeepsOldSourceSnapshot() throws {
        let ops = ops()
        let original = try write("item", "original")
        let (transfer, record) = try move([original], using: ops)
        let snapshot = try XCTUnwrap(transfer.items[0].sourceTrashURL)
        let snapshotID = FileID.read(at: snapshot)

        let report = ops.undo(record)

        XCTAssertEqual(report.items.map(\.status), [.undone])
        XCTAssertEqual(try text(original), "original")
        XCTAssertEqual(try text(snapshot), "original")
        XCTAssertEqual(FileID.read(at: snapshot), snapshotID)
        XCTAssertFalse(exists(destination.appendingPathComponent("item")))
        XCTAssertNil(report.retryRecord)
    }

    func testCrossVolumeUndoCopiesLatestInPlaceEditAndRestoresReplacedItem() throws {
        let ops = ops()
        let original = try write("item", "before move")
        let target = try write("item", "replaced", in: destination)
        let (transfer, record) = try move([original], using: ops)
        let snapshot = try XCTUnwrap(transfer.items[0].sourceTrashURL)
        let targetID = FileID.read(at: target)
        try editInPlace(target, "edited after move")
        XCTAssertEqual(FileID.read(at: target), targetID)

        let report = ops.undo(record)

        XCTAssertEqual(report.items.map(\.status), [.undone])
        XCTAssertEqual(try text(original), "edited after move")
        XCTAssertEqual(try text(target), "replaced")
        XCTAssertEqual(try text(snapshot), "before move")
        XCTAssertEqual(Set(report.restoredURLs), Set([original, target]))
        XCTAssertNil(report.retryRecord)
    }

    func testCrossVolumeFolderUndoPreservesEditedAddedAndRemovedChildren() throws {
        let ops = ops()
        let original = source.appendingPathComponent("tree", isDirectory: true)
        try FileManager.default.createDirectory(at: original, withIntermediateDirectories: true)
        try write("edited", "before", in: original)
        try write("removed", "obsolete", in: original)
        let (transfer, record) = try move([original], using: ops)
        let snapshot = try XCTUnwrap(transfer.items[0].sourceTrashURL)
        let target = destination.appendingPathComponent("tree", isDirectory: true)
        try editInPlace(target.appendingPathComponent("edited"), "after")
        try write("added", "new", in: target)
        try FileManager.default.removeItem(at: target.appendingPathComponent("removed"))

        let report = ops.undo(record)

        XCTAssertEqual(report.items.map(\.status), [.undone])
        XCTAssertEqual(try text(original.appendingPathComponent("edited")), "after")
        XCTAssertEqual(try text(original.appendingPathComponent("added")), "new")
        XCTAssertFalse(exists(original.appendingPathComponent("removed")))
        XCTAssertEqual(try text(snapshot.appendingPathComponent("edited")), "before")
        XCTAssertEqual(try text(snapshot.appendingPathComponent("removed")), "obsolete")
        XCTAssertFalse(exists(target))
        XCTAssertNil(report.retryRecord)
    }

    func testRetryAfterCollisionRemovalKeepsOriginalOrderAndDoesNotReplaySuccess() throws {
        let ops = ops()
        let first = try write("first", "1")
        let completed = try write("completed", "2")
        let last = try write("last", "3")
        let (_, record) = try move([first, completed, last], using: ops)
        try write("first", "collision 1")
        try write("last", "collision 3")

        let report = ops.undo(record)
        let retry = try XCTUnwrap(report.retryRecord)

        XCTAssertEqual(report.items.map(\.status), [.occupied, .undone, .occupied])
        XCTAssertEqual(retry.title, record.title)
        XCTAssertEqual(retry.items, [record.items[0], record.items[2]])
        XCTAssertEqual(try text(first), "collision 1")
        XCTAssertEqual(try text(last), "collision 3")
        try FileManager.default.removeItem(at: first)
        try FileManager.default.removeItem(at: last)
        try editInPlace(completed, "edited after successful undo")

        let retried = ops.undo(retry)

        XCTAssertEqual(retried.items.map(\.status), [.undone, .undone])
        XCTAssertEqual(retried.items.map(\.url), [last, first])
        XCTAssertEqual(try text(first), "1")
        XCTAssertEqual(try text(last), "3")
        XCTAssertEqual(try text(completed), "edited after successful undo")
        XCTAssertNil(retried.retryRecord)
    }

    func testMissingOriginalParentCanRetryMoveAfterParentIsRestored() throws {
        let ops = ops()
        let original = try write("item", "payload")
        let (_, record) = try move([original], using: ops)
        try FileManager.default.removeItem(at: source)

        let report = ops.undo(record)

        XCTAssertEqual(report.items.map(\.status), [.missing])
        XCTAssertEqual(report.retryRecord, record)
        XCTAssertEqual(try text(destination.appendingPathComponent("item")), "payload")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        let retry = ops.undo(try XCTUnwrap(report.retryRecord))
        XCTAssertEqual(retry.items.map(\.status), [.undone])
        XCTAssertEqual(try text(original), "payload")
        XCTAssertNil(retry.retryRecord)
    }

    func testMissingOriginalParentCanRetryTrashRestore() throws {
        let ops = ops()
        let original = try write("item", "payload")
        let record = try XCTUnwrap(ops.undoRecord(trash: ops.trash(urls: [original])))
        try FileManager.default.removeItem(at: source)

        let report = ops.undo(record)

        XCTAssertEqual(report.items.map(\.status), [.missing])
        XCTAssertEqual(report.retryRecord, record)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        XCTAssertEqual(ops.undo(try XCTUnwrap(report.retryRecord)).items.map(\.status), [.undone])
        XCTAssertEqual(try text(original), "payload")
    }

    func testFailedCopyBeforePublishIsRetryableAndCleansItsStage() throws {
        let ops = ops()
        let original = try write("item", "before")
        let (transfer, record) = try move([original], using: ops)
        let snapshot = try XCTUnwrap(transfer.items[0].sourceTrashURL)
        let target = destination.appendingPathComponent("item")
        try editInPlace(target, "latest")
        var failing = ops
        failing.copy = { _, incoming, _, _ in
            try Data("partial".utf8).write(to: incoming)
            throw FileOpError("copy failed")
        }

        let report = failing.undo(record)

        guard case .failed = report.items[0].status else { return XCTFail("expected failed copy") }
        XCTAssertEqual(report.retryRecord, record)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: source.path), [])
        XCTAssertEqual(try text(target), "latest")
        XCTAssertEqual(try text(snapshot), "before")
        XCTAssertEqual(ops.undo(try XCTUnwrap(report.retryRecord)).items.map(\.status), [.undone])
        XCTAssertEqual(try text(original), "latest")
    }

    func testTransientTrashFailureBeforeMutationCanRetry() throws {
        let ops = ops()
        let created = try write("item", "payload")
        let record = try XCTUnwrap(ops.undoRecord(created: created))
        var failing = ops
        failing.moveToTrash = { _ in throw FileOpError("temporary refusal") }

        let report = failing.undo(record)

        guard case .failed = report.items[0].status else { return XCTFail("expected failed trash") }
        XCTAssertEqual(report.retryRecord, record)
        XCTAssertEqual(try text(created), "payload")
        XCTAssertEqual(ops.undo(try XCTUnwrap(report.retryRecord)).items.map(\.status), [.undone])
        XCTAssertFalse(exists(created))
    }

    func testPartialCopyBackNeverRetriesAndKeepsBothCurrentContentAndSnapshot() throws {
        let ops = ops()
        let original = try write("item", "before")
        try write("item", "replaced", in: destination)
        let (transfer, record) = try move([original], using: ops)
        let snapshot = try XCTUnwrap(transfer.items[0].sourceTrashURL)
        let replaced = try XCTUnwrap(transfer.items[0].replacedTrashURL)
        let target = destination.appendingPathComponent("item")
        try editInPlace(target, "latest")
        var failing = ops
        failing.moveToTrash = { _ in throw FileOpError("temporary refusal") }

        let report = failing.undo(record)

        XCTAssertEqual(report.items.map(\.status), [.partiallyUndone])
        XCTAssertEqual(report.restoredURLs, [original])
        XCTAssertEqual(try text(original), "latest")
        XCTAssertEqual(try text(target), "latest")
        XCTAssertEqual(try text(snapshot), "before")
        XCTAssertEqual(try text(replaced), "replaced")
        XCTAssertNil(report.retryRecord)
    }

    func testStaleMissingAndUnverifiableItemsAreDroppedInsteadOfRetried() throws {
        let ops = ops()
        let stale = try write("stale", "before")
        let missing = try write("missing", "before")
        let blind = try write("blind", "before")
        let record = UndoRecord(title: "새로 만들기", items: [
            .created(stale, id: FileID.read(at: stale)),
            .created(missing, id: FileID.read(at: missing)),
            .created(blind, id: nil),
        ])
        // Keep the original inode alive so identity cannot be recycled for the replacement.
        try FileManager.default.moveItem(at: stale, to: bin.appendingPathComponent("stale"))
        try write("stale", "unrelated")
        try FileManager.default.removeItem(at: missing)

        let report = ops.undo(record)

        XCTAssertEqual(report.items.map(\.status), [.unverifiable, .missing, .stale])
        XCTAssertEqual(try text(stale), "unrelated")
        XCTAssertEqual(try text(blind), "before")
        XCTAssertNil(report.retryRecord)
    }

    func testReplacedDestinationDuringCopyBackIsNotTrashedOrRetried() throws {
        let ops = ops()
        let original = try write("item", "payload")
        let (_, record) = try move([original], using: ops)
        let target = destination.appendingPathComponent("item")
        let saved = destination.appendingPathComponent("saved")
        var racing = ops
        racing.copy = { current, incoming, _, _ in
            try FileManager.default.copyItem(at: current, to: incoming)
            try FileManager.default.moveItem(at: current, to: saved)
            try Data("unrelated".utf8).write(to: current)
        }

        let report = racing.undo(record)

        XCTAssertEqual(report.items.map(\.status), [.partiallyUndone])
        XCTAssertEqual(try text(original), "payload")
        XCTAssertEqual(try text(saved), "payload")
        XCTAssertEqual(try text(target), "unrelated")
        XCTAssertNil(report.retryRecord)
    }

    func testMixedBatchRetriesOnlyUntouchedItemAndNeverReplaysPartialCopyBack() throws {
        let ops = ops()
        let blocked = try write("blocked", "blocked payload")
        let partial = try write("partial", "partial payload")
        let (_, record) = try move([blocked, partial], using: ops)
        try write("blocked", "collision")
        var failing = ops
        failing.moveToTrash = { _ in throw FileOpError("temporary refusal") }

        let report = failing.undo(record)
        let retry = try XCTUnwrap(report.retryRecord)

        XCTAssertEqual(report.items.map(\.status), [.partiallyUndone, .occupied])
        XCTAssertEqual(retry.items, [record.items[0]])
        try FileManager.default.removeItem(at: blocked)
        try editInPlace(partial, "edited restored copy")
        let retried = ops.undo(retry)
        XCTAssertEqual(retried.items.map(\.status), [.undone])
        XCTAssertEqual(try text(blocked), "blocked payload")
        XCTAssertEqual(try text(partial), "edited restored copy")
        XCTAssertEqual(try text(destination.appendingPathComponent("partial")), "partial payload")
        XCTAssertNil(retried.retryRecord)
    }

    func testMissingTrashSourceIsNotMistakenForRetryableMissingParent() throws {
        let ops = ops()
        let original = try write("item", "payload")
        let transfer = ops.trash(urls: [original])
        let record = try XCTUnwrap(ops.undoRecord(trash: transfer))
        try FileManager.default.removeItem(at: try XCTUnwrap(transfer.items[0].trashedURL))

        let report = ops.undo(record)

        XCTAssertEqual(report.items.map(\.status), [.missing])
        XCTAssertNil(report.retryRecord)
        XCTAssertFalse(exists(original))
    }
}
