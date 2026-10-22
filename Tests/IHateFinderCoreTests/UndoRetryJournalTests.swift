import XCTest
@testable import IHateFinderCore

final class UndoRetryJournalTests: XCTestCase {
    private func record(_ title: String) -> UndoRecord {
        UndoRecord(title: title, items: [.created(URL(fileURLWithPath: "/tmp/\(title)"), id: nil)])
    }

    func testRetrySelectsMostRecentBlockedOperationWithoutPoppingRepairs() {
        let journal = FileUndoJournal()
        let first = record("first"), second = record("second"), repair = record("repair")
        journal.pushRetry(first)
        journal.pushRetry(second)
        journal.push(repair)
        XCTAssertEqual(journal.popRetry(), second)
        XCTAssertEqual(journal.peek, repair)
        XCTAssertEqual(journal.popRetry(), first)
        XCTAssertNil(journal.peekRetry)
        XCTAssertEqual(journal.popLast(), repair)
        XCTAssertEqual(journal.count, 0)
    }

    func testNormalUndoAndEvictionRemoveRetryMarkers() {
        let journal = FileUndoJournal()
        let blocked = record("blocked")
        journal.pushRetry(blocked)
        XCTAssertEqual(journal.popLast(), blocked)
        XCTAssertNil(journal.peekRetry)
        journal.pushRetry(blocked)
        for index in 0..<FileUndoJournal.limit { journal.push(record("\(index)")) }
        XCTAssertEqual(journal.count, FileUndoJournal.limit)
        XCTAssertNil(journal.popRetry())
        journal.pushRetry(blocked)
        journal.clear()
        XCTAssertNil(journal.peekRetry)
        XCTAssertEqual(journal.count, 0)
    }
}
