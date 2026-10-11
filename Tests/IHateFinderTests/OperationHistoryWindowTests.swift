import AppKit
import XCTest
import IHateFinderCore
@testable import IHateFinder

final class OperationHistoryWindowTests: XCTestCase {
    @MainActor
    func testEmptyWindowHasReadOnlyScrollableDetails() throws {
        _ = NSApplication.shared
        let history = FileOperationHistory()
        let controller = FileOperationHistoryWindowController(history: history)
        let window = try XCTUnwrap(controller.window)
        defer { window.close() }
        window.contentView?.layoutSubtreeIfNeeded()

        XCTAssertEqual(controller.table.numberOfRows, 0)
        XCTAssertFalse(controller.emptyStateLabel.isHidden)
        XCTAssertEqual(controller.table.selectedRow, -1)
        XCTAssertNil(controller.selectedRecordID)
        XCTAssertEqual(controller.detailView.string, "")
        XCTAssertFalse(controller.detailView.isEditable)
        XCTAssertTrue(controller.detailView.isSelectable)
        XCTAssertFalse(controller.detailView.allowsUndo)
        XCTAssertTrue(controller.table.tableColumns.allSatisfy { !$0.isEditable })
        XCTAssertTrue(window.styleMask.contains(.resizable))
        XCTAssertFalse(window.isReleasedWhenClosed)
        XCTAssertNotNil(controller.table.enclosingScrollView)
        XCTAssertNotNil(controller.detailView.enclosingScrollView)
        XCTAssertGreaterThan(controller.table.enclosingScrollView?.frame.height ?? 0, 0)
        XCTAssertGreaterThan(controller.detailView.enclosingScrollView?.frame.height ?? 0, 0)
        XCTAssertNil(history.onChange)
    }

    @MainActor
    func testSelectionSurvivesInsertionAndCompletionReload() throws {
        _ = NSApplication.shared
        let history = FileOperationHistory()
        let windowID = UUID()
        let source = URL(fileURLWithPath: "/source/file.txt")
        let requested = URL(fileURLWithPath: "/target/file.txt")
        let actual = URL(fileURLWithPath: "/target/file 2.txt")
        let firstID = history.begin(kind: .copy, windowID: windowID, windowTitle: "A", items: [
            FileOperationItem(source: source, destination: requested, status: .running),
        ])
        let controller = FileOperationHistoryWindowController(history: history)
        defer { controller.window?.close() }
        history.onChange = { controller.reloadHistory() }
        controller.table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        XCTAssertEqual(controller.selectedRecordID, firstID)
        XCTAssertTrue(controller.detailView.string.contains(requested.path))
        XCTAssertNil(controller.displayedRecords[0].finishedAt)

        let secondID = history.begin(kind: .createFolder, windowID: windowID, windowTitle: "B", items: [
            FileOperationItem(destination: URL(fileURLWithPath: "/target/new"), status: .running),
        ])
        XCTAssertEqual(controller.table.numberOfRows, 2)
        XCTAssertEqual(controller.displayedRecords.map(\.id), [secondID, firstID])
        XCTAssertEqual(controller.table.selectedRow, 1)
        XCTAssertEqual(controller.selectedRecordID, firstID)
        XCTAssertTrue(controller.emptyStateLabel.isHidden)

        history.finish(firstID, items: [FileOperationItem(source: source, destination: actual, status: .completed)])
        XCTAssertEqual(controller.selectedRecordID, firstID)
        XCTAssertEqual(controller.table.selectedRow, 1)
        XCTAssertEqual(controller.displayedRecords[1].status, .completed)
        XCTAssertNotNil(controller.displayedRecords[1].finishedAt)
        XCTAssertTrue(controller.detailView.string.contains(actual.path))
        XCTAssertFalse(controller.detailView.string.contains(requested.path))
        let column = try XCTUnwrap(controller.table.tableColumns.first { $0.identifier.rawValue == "result" })
        let cell = try XCTUnwrap(controller.tableView(controller.table, viewFor: column, row: 1) as? NSTableCellView)
        XCTAssertTrue(try XCTUnwrap(cell.textField).stringValue.contains(FileOperationStatus.completed.title))
    }

    @MainActor
    func testPrunedSelectionClearsStaleDetails() {
        _ = NSApplication.shared
        let history = FileOperationHistory(limit: 1)
        let firstID = history.begin(kind: .move, windowID: UUID(), windowTitle: "A", items: [
            FileOperationItem(source: URL(fileURLWithPath: "/old/source"), status: .running),
        ])
        history.finish(firstID, items: [FileOperationItem(status: .completed)])
        let controller = FileOperationHistoryWindowController(history: history)
        defer { controller.window?.close() }
        history.onChange = { controller.reloadHistory() }
        controller.table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        XCTAssertEqual(controller.selectedRecordID, firstID)
        let secondID = history.begin(kind: .trash, windowID: UUID(), windowTitle: "B", items: [
            FileOperationItem(status: .running),
        ])
        history.finish(secondID, items: [FileOperationItem(status: .completed)])

        XCTAssertEqual(controller.displayedRecords.map(\.id), [secondID])
        XCTAssertEqual(controller.table.numberOfRows, 1)
        XCTAssertEqual(controller.table.selectedRow, -1)
        XCTAssertNil(controller.selectedRecordID)
        XCTAssertEqual(controller.detailView.string, "")
    }

    @MainActor
    func testUndoDetailsShowActualPathsRecoveryAndOriginalID() throws {
        _ = NSApplication.shared
        let history = FileOperationHistory()
        let parentID = UUID()
        let source = URL(fileURLWithPath: "/target/file.txt")
        let destination = URL(fileURLWithPath: "/source/file restored.txt")
        let recovery = URL(fileURLWithPath: "/recovery/file.txt")
        let message = "test failure reason"
        let id = history.begin(kind: .undo, windowID: UUID(), windowTitle: "C", items: [
            FileOperationItem(source: source, destination: destination, status: .running),
        ], parentID: parentID)
        history.finish(id, items: [
            FileOperationItem(source: source, destination: destination, status: .failed,
                              message: message, recoveryLocations: [recovery]),
            FileOperationItem(source: URL(fileURLWithPath: "/target/other.txt"), status: .unprocessed),
        ])
        let controller = FileOperationHistoryWindowController(history: history)
        defer { controller.window?.close() }
        controller.table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)

        XCTAssertEqual(controller.selectedRecordID, id)
        for value in [id.uuidString, parentID.uuidString, source.path, destination.path, recovery.path, message, "/target/other.txt"] {
            XCTAssertTrue(controller.detailView.string.contains(value), value)
        }
        XCTAssertFalse(controller.detailView.isEditable)
        XCTAssertTrue(controller.detailView.isSelectable)
        let column = try XCTUnwrap(controller.table.tableColumns.first { $0.identifier.rawValue == "window" })
        let cell = try XCTUnwrap(controller.tableView(controller.table, viewFor: column, row: 0) as? NSTableCellView)
        XCTAssertTrue(try XCTUnwrap(cell.textField).stringValue.contains("C"))
        XCTAssertFalse(try XCTUnwrap(cell.textField).isEditable)
        XCTAssertNil(controller.table.menu)
    }
}
