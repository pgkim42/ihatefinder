import XCTest
@testable import IHateFinderCore

final class FileOperationHistoryTests: XCTestCase {
    private func record(_ statuses: [FileOperationStatus], finished: Bool = true) -> FileOperationRecord {
        FileOperationRecord(kind: .copy, windowID: UUID(), windowTitle: "Browser",
                            startedAt: Date(timeIntervalSince1970: 100),
                            finishedAt: finished ? Date(timeIntervalSince1970: 101) : nil,
                            items: statuses.map { FileOperationItem(status: $0) })
    }

    func testBeginAndFinishNotifySynchronouslyAfterUpdatingState() throws {
        let history = FileOperationHistory()
        let windowID = UUID()
        let initial = [FileOperationItem(status: .running)]
        var snapshots: [[FileOperationRecord]] = []
        history.onChange = { [weak history] in
            snapshots.append(history?.records ?? [])
        }

        let beforeBegin = Date()
        let id = history.begin(kind: .move, windowID: windowID, windowTitle: "Downloads", items: initial)
        let afterBegin = Date()
        XCTAssertEqual(snapshots.count, 1)
        let started = try XCTUnwrap(snapshots.first?.first)
        XCTAssertEqual(started.id, id)
        XCTAssertEqual(started.kind, .move)
        XCTAssertEqual(started.windowID, windowID)
        XCTAssertEqual(started.windowTitle, "Downloads")
        XCTAssertEqual(started.items, initial)
        XCTAssertEqual(started.status, .running)
        XCTAssertNil(started.finishedAt)
        XCTAssertNil(started.parentID)
        XCTAssertGreaterThanOrEqual(started.startedAt, beforeBegin)
        XCTAssertLessThanOrEqual(started.startedAt, afterBegin)

        let results = [FileOperationItem(status: .completed)]
        let beforeFinish = Date()
        history.finish(id, items: results)
        let afterFinish = Date()
        XCTAssertEqual(snapshots.count, 2)
        let finished = try XCTUnwrap(snapshots.last?.first)
        XCTAssertEqual(history.records, snapshots.last)
        XCTAssertEqual(finished.id, started.id)
        XCTAssertEqual(finished.kind, started.kind)
        XCTAssertEqual(finished.windowID, started.windowID)
        XCTAssertEqual(finished.windowTitle, started.windowTitle)
        XCTAssertEqual(finished.startedAt, started.startedAt)
        XCTAssertEqual(finished.items, results)
        XCTAssertEqual(finished.status, .completed)
        let finishedAt = try XCTUnwrap(finished.finishedAt)
        XCTAssertGreaterThanOrEqual(finishedAt, beforeFinish)
        XCTAssertLessThanOrEqual(finishedAt, afterFinish)
    }

    func testItemsKeepExactPathsMessagesAndRecoveryLocations() throws {
        let history = FileOperationHistory()
        let source = URL(fileURLWithPath: "/source/../source/원본.txt")
        let destination = URL(fileURLWithPath: "/target/nested/result.txt")
        let recovery = [URL(fileURLWithPath: "/trash/replaced.txt"), URL(fileURLWithPath: "/trash/source.txt")]
        let item = FileOperationItem(source: source, destination: destination, status: .partial,
                                     message: "Target copied; original remains.", recoveryLocations: recovery)
        let id = history.begin(kind: .move, windowID: UUID(), windowTitle: "Files", items: [item])
        XCTAssertEqual(history.records.first?.items, [item])
        history.finish(id, items: [item])

        let retained = try XCTUnwrap(history.records.first?.items.first)
        XCTAssertEqual(retained, item)
        XCTAssertEqual(retained.source?.absoluteString, source.absoluteString)
        XCTAssertEqual(retained.destination?.absoluteString, destination.absoluteString)
        XCTAssertEqual(retained.message, item.message)
        XCTAssertEqual(retained.recoveryLocations, recovery)
        XCTAssertEqual(history.records.first?.status, .partial)

        let defaults = FileOperationItem(status: .skipped)
        XCTAssertNil(defaults.source)
        XCTAssertNil(defaults.destination)
        XCTAssertNil(defaults.message)
        XCTAssertTrue(defaults.recoveryLocations.isEmpty)
    }

    func testAggregateStatusDistinguishesCompletionFailureCancellationAndMixedOutcomes() {
        let cases: [([FileOperationStatus], FileOperationStatus)] = [
            ([.completed, .completed], .completed),
            ([.skipped, .skipped], .skipped),
            ([.failed, .failed], .failed),
            ([.cancelled, .cancelled], .cancelled),
            ([.unprocessed, .unprocessed], .unprocessed),
            ([.partial], .partial),
            ([.completed, .failed], .partial),
            ([.completed, .cancelled, .unprocessed], .partial),
            ([.completed, .skipped], .partial),
            ([.completed, .unprocessed], .partial),
            ([.partial, .failed], .partial),
            ([.failed, .skipped, .unprocessed], .failed),
            ([.failed, .cancelled], .failed),
            ([.cancelled, .skipped, .unprocessed], .cancelled),
            ([.skipped, .unprocessed], .partial),
            ([.running, .completed], .running),
            ([], .unprocessed),
        ]
        for (statuses, expected) in cases {
            XCTAssertEqual(record(statuses).status, expected, "\(statuses)")
        }
        XCTAssertEqual(record([.completed], finished: false).status, .running)
        XCTAssertEqual(record([], finished: false).status, .running)
    }

    func testSummaryIncludesPerStatusCountsFromItems() {
        let statuses: [FileOperationStatus] = [.running, .completed, .skipped, .failed, .cancelled, .unprocessed, .partial]
        let items = statuses.enumerated().flatMap { index, status in
            Array(repeating: FileOperationItem(status: status), count: index + 1)
        }
        let record = FileOperationRecord(kind: .copy, windowID: UUID(), windowTitle: "Browser",
                                         startedAt: Date(timeIntervalSince1970: 100), items: items)
        let counts = record.summary.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        XCTAssertEqual(counts, Array(1...7))

        let sparse = self.record([.completed, .failed, .completed])
        let sparseCounts = sparse.summary.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        XCTAssertEqual(sparseCounts, [2, 1])
        XCTAssertTrue(self.record([]).summary.isEmpty)
    }

    func testUndoLinksToParentWithoutChangingOriginalRecord() throws {
        let history = FileOperationHistory()
        let windowID = UUID()
        let parentID = history.begin(kind: .rename, windowID: windowID, windowTitle: "Files",
                                     items: [FileOperationItem(status: .running)])
        history.finish(parentID, items: [FileOperationItem(status: .completed)])
        let parent = try XCTUnwrap(history.records.first)
        let undoID = history.begin(kind: .undo, windowID: windowID, windowTitle: "Files",
                                   items: [FileOperationItem(status: .running)], parentID: parentID)
        history.finish(undoID, items: [FileOperationItem(status: .skipped)])

        XCTAssertEqual(history.records.map(\.id), [undoID, parentID])
        XCTAssertEqual(history.records.first?.parentID, parentID)
        XCTAssertEqual(history.records.first?.kind, .undo)
        XCTAssertEqual(history.records.last, parent)
    }

    func testRetentionKeepsNewestFinishedRecordsAndEveryRunningRecord() throws {
        let history = FileOperationHistory(limit: 2)
        let windowID = UUID()
        let oldestRunning = history.begin(kind: .compress, windowID: windowID, windowTitle: "Files", items: [])
        let first = history.begin(kind: .copy, windowID: windowID, windowTitle: "Files", items: [])
        history.finish(first, items: [FileOperationItem(status: .failed)])
        let second = history.begin(kind: .trash, windowID: windowID, windowTitle: "Files", items: [])
        history.finish(second, items: [FileOperationItem(status: .cancelled)])
        let newestRunning = history.begin(kind: .move, windowID: windowID, windowTitle: "Files", items: [])
        let third = history.begin(kind: .createFile, windowID: windowID, windowTitle: "Files", items: [])
        var observedIDs: [UUID] = []
        history.onChange = { [weak history] in observedIDs = history?.records.map(\.id) ?? [] }
        history.finish(third, items: [FileOperationItem(status: .skipped)])

        XCTAssertEqual(history.records.map(\.id), [third, newestRunning, second, oldestRunning])
        XCTAssertEqual(observedIDs, history.records.map(\.id))
        XCTAssertEqual(history.records.filter { $0.finishedAt != nil }.count, 2)
        XCTAssertEqual(history.records.filter { $0.finishedAt == nil }.map(\.id), [newestRunning, oldestRunning])

        // Finishing an older in-flight entry does not reorder records or evict newer history.
        history.finish(oldestRunning, items: [FileOperationItem(status: .completed)])
        XCTAssertEqual(history.records.map(\.id), [third, newestRunning, second])
        history.finish(newestRunning, items: [FileOperationItem(status: .completed)])
        XCTAssertEqual(history.records.map(\.id), [third, newestRunning])
    }

    func testZeroRetentionKeepsOnlyInFlightRecords() {
        let history = FileOperationHistory(limit: 0)
        let first = history.begin(kind: .createFolder, windowID: UUID(), windowTitle: "Files", items: [])
        let second = history.begin(kind: .createFile, windowID: UUID(), windowTitle: "Files", items: [])
        XCTAssertEqual(history.records.map(\.id), [second, first])
        history.finish(first, items: [FileOperationItem(status: .completed)])
        XCTAssertEqual(history.records.map(\.id), [second])
        history.finish(second, items: [FileOperationItem(status: .failed)])
        XCTAssertTrue(history.records.isEmpty)
    }

    func testDefaultRetentionLimitIsOneThousandFinishedRecords() {
        let history = FileOperationHistory()
        let windowID = UUID()
        let running = history.begin(kind: .compress, windowID: windowID, windowTitle: "Files", items: [])
        var finishedIDs: [UUID] = []
        for _ in 0..<1001 {
            let id = history.begin(kind: .copy, windowID: windowID, windowTitle: "Files", items: [])
            finishedIDs.append(id)
            history.finish(id, items: [FileOperationItem(status: .completed)])
        }
        XCTAssertEqual(history.records.count, 1001)
        XCTAssertEqual(history.records.filter { $0.finishedAt != nil }.map(\.id), Array(finishedIDs.suffix(1000).reversed()))
        XCTAssertEqual(history.records.last?.id, running)
        XCTAssertNil(history.records.last?.finishedAt)
    }

    func testUnknownAndAlreadyFinishedIDsDoNotChangeHistoryOrNotify() {
        let history = FileOperationHistory()
        var changes = 0
        history.onChange = { changes += 1 }
        history.finish(UUID(), items: [FileOperationItem(status: .failed)])
        XCTAssertEqual(changes, 0)
        XCTAssertTrue(history.records.isEmpty)

        let id = history.begin(kind: .copy, windowID: UUID(), windowTitle: "Files", items: [])
        history.finish(id, items: [FileOperationItem(status: .completed)])
        let original = history.records
        history.finish(id, items: [FileOperationItem(status: .failed)])
        XCTAssertEqual(changes, 2)
        XCTAssertEqual(history.records, original)
    }
}
