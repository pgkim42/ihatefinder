import AppKit
import XCTest
import IHateFinderCore
@testable import IHateFinder

final class OperationHistoryIntegrationTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: root)
    }

    @MainActor
    private func loaded(_ test: TestBrowser) async {
        for pane in [test.browser.left, test.browser.right] {
            _ = pane.view
            await awaitPaneLoad(pane) { pane.session.reload() }
        }
    }

    @MainActor
    private func performOperation(_ browser: BrowserWindowController, action: () -> Void) async throws -> FileOperationRecord {
        let completed = expectation(description: "New history record finished")
        let history = browser.operationHistory
        let previous = history.onChange
        let existing = Set(history.records.map(\.id))
        var finished: FileOperationRecord?
        history.onChange = {
            previous?()
            if finished == nil, let record = history.records.first(where: { !existing.contains($0.id) && $0.finishedAt != nil }) {
                finished = record
                completed.fulfill()
            }
        }
        defer { history.onChange = previous }
        action()
        await fulfillment(of: [completed], timeout: 5)
        if let window = browser.window, let sheet = window.attachedSheet { window.endSheet(sheet) }
        return try XCTUnwrap(finished)
    }

    private func write(_ name: String, in directory: URL, contents: String = "payload") throws -> URL {
        let url = directory.appendingPathComponent(name)
        try Data(contents.utf8).write(to: url)
        return url
    }

    @MainActor
    func testKeepBothAndReplacementRecordActualDestinationAndRecovery() async throws {
        let test = try makeTestBrowser(root: root)
        defer { test.browser.close() }
        await loaded(test)
        let source = try write("a.txt", in: test.left)
        let occupied = try write("a.txt", in: test.right, contents: "old")
        test.browser.conflictResolver = { _ in .keepBoth }
        let kept = try await performOperation(test.browser) { test.browser.drop([source], onto: test.right, moving: false) }
        XCTAssertEqual(kept.kind, .copy)
        XCTAssertEqual(kept.status, .completed)
        let destination = try XCTUnwrap(kept.items.first?.destination)
        XCTAssertNotEqual(destination, occupied)
        XCTAssertEqual(try String(contentsOf: destination, encoding: .utf8), "payload")
        XCTAssertEqual(test.browser.undoJournal.peek?.operationID, kept.id)

        test.browser.conflictResolver = { _ in .replace }
        let replaced = try await performOperation(test.browser) { test.browser.drop([source], onto: test.right, moving: false) }
        XCTAssertEqual(replaced.items.first?.destination, occupied)
        let recovery = try XCTUnwrap(replaced.items.first?.recoveryLocations.first)
        XCTAssertEqual(try String(contentsOf: recovery, encoding: .utf8), "old")
    }

    @MainActor
    func testTransferFailureKeepsCompletedFailedAndUnprocessedItems() async throws {
        let test = try makeTestBrowser(root: root)
        defer { test.browser.close() }
        await loaded(test)
        let first = try write("first.txt", in: test.left)
        let missing = test.left.appendingPathComponent("missing.txt")
        let last = try write("last.txt", in: test.left)
        let record = try await performOperation(test.browser) { test.browser.drop([first, missing, last], onto: test.right, moving: false) }
        XCTAssertEqual(record.status, .partial)
        XCTAssertEqual(record.items.map(\.source), [first, missing, last])
        XCTAssertEqual(record.items.map(\.status), [.completed, .failed, .unprocessed])
        XCTAssertNotNil(record.items[1].message)
        XCTAssertFalse(FileManager.default.fileExists(atPath: test.right.appendingPathComponent("last.txt").path))
    }

    @MainActor
    func testUndoRetryLinksToOriginalAndDoesNotRepeatCompletedItems() async throws {
        let test = try makeTestBrowser(root: root)
        defer { test.browser.close() }
        await loaded(test)
        let blocked = try write("blocked.txt", in: test.left)
        let other = try write("other.txt", in: test.left)
        let move = try await performOperation(test.browser) { test.browser.drop([blocked, other], onto: test.right, moving: true) }
        _ = try write("blocked.txt", in: test.left, contents: "obstruction")
        let attempt = try await performOperation(test.browser) { test.browser.undoFileOperation() }
        XCTAssertEqual(attempt.kind, .undo)
        XCTAssertEqual(attempt.parentID, move.id)
        XCTAssertEqual(attempt.status, .partial)
        XCTAssertEqual(attempt.items.map(\.status), [.completed, .skipped])
        XCTAssertEqual(test.browser.undoJournal.peek?.operationID, move.id)
        try FileManager.default.removeItem(at: blocked)
        let retry = try await performOperation(test.browser) { test.browser.undoFileOperation() }
        XCTAssertEqual(retry.parentID, move.id)
        XCTAssertEqual(retry.items.count, 1)
        XCTAssertEqual(retry.items[0].destination, blocked)
        XCTAssertEqual(retry.status, .completed)
        XCTAssertEqual(try String(contentsOf: other, encoding: .utf8), "payload")
        XCTAssertEqual(test.browser.operationHistory.records.count, 3)
    }

    @MainActor
    func testCreateKindsAndUndoExposeActualTrashLocation() async throws {
        let test = try makeTestBrowser(root: root)
        defer { test.browser.close() }
        await loaded(test)
        let folder = try await performOperation(test.browser) { test.browser.left.makeFolder() }
        XCTAssertEqual(folder.kind, .createFolder)
        XCTAssertEqual(folder.items[0].destination?.deletingLastPathComponent(), test.left)
        test.browser.window?.makeFirstResponder(test.browser.left.table)
        let file = try await performOperation(test.browser) { test.browser.left.makeTextFile() }
        XCTAssertEqual(file.kind, .createFile)
        let undo = try await performOperation(test.browser) { test.browser.undoFileOperation() }
        XCTAssertEqual(undo.parentID, file.id)
        let trash = try XCTUnwrap(undo.items[0].recoveryLocations.first)
        XCTAssertTrue(FileManager.default.fileExists(atPath: trash.path))
        XCTAssertEqual(undo.items[0].destination, trash)
        XCTAssertFalse(FileManager.default.fileExists(atPath: try XCTUnwrap(file.items[0].destination).path))
    }

    @MainActor
    func testCreateFailureIsRecordedInsteadOfRemainingRunning() async throws {
        let test = try makeTestBrowser(root: root)
        defer { test.browser.close() }
        await loaded(test)
        try FileManager.default.removeItem(at: test.left)
        let record = try await performOperation(test.browser) { test.browser.left.makeFolder() }
        XCTAssertEqual(record.kind, .createFolder)
        XCTAssertEqual(record.status, .failed)
        XCTAssertNotNil(record.items[0].message)
        XCTAssertEqual(record.items[0].destination, test.left)
        XCTAssertEqual(test.browser.undoJournal.count, 0)
    }

    @MainActor
    func testTrashPartialFailurePreservesEachResultAndTrashPath() async throws {
        let test = try makeTestBrowser(root: root)
        defer { test.browser.close() }
        let first = try write("a.txt", in: test.left)
        let missing = test.left.appendingPathComponent("b.txt")
        let last = try write("c.txt", in: test.left)
        await loaded(test)
        _ = try write("b.txt", in: test.left)
        await awaitPaneLoad(test.browser.left) { test.browser.left.session.reload() }
        test.browser.left.table.selectRowIndexes(IndexSet(integersIn: 0..<3), byExtendingSelection: false)
        // Inject only the user-trash failure; the filesystem and history pipeline stay real.
        let binTrash = testBinTrash(into: test.bin)
        test.browser.left.session.ops.moveToTrash = { url in
            if url == missing { throw FileOpError("denied") }
            return try binTrash(url)
        }
        let record = try await performOperation(test.browser) { test.browser.left.trashSelection() }
        XCTAssertEqual(record.kind, .trash)
        XCTAssertEqual(record.status, .partial)
        XCTAssertEqual(record.items.map(\.source), [first, missing, last])
        XCTAssertEqual(record.items.map(\.status), [.completed, .failed, .unprocessed])
        let trash = try XCTUnwrap(record.items[0].destination)
        XCTAssertEqual(record.items[0].recoveryLocations, [trash])
        XCTAssertTrue(FileManager.default.fileExists(atPath: trash.path))
    }

    @MainActor
    func testCompressionSuccessAndFailureAreRecorded() async throws {
        let test = try makeTestBrowser(root: root)
        defer { test.browser.close() }
        await loaded(test)
        let source = try write("compress.txt", in: test.left)
        let compressed = try await performOperation(test.browser) { test.browser.compress(source) }
        XCTAssertEqual(compressed.kind, .compress)
        XCTAssertEqual(compressed.status, .completed)
        let zip = try XCTUnwrap(compressed.items[0].destination)
        XCTAssertTrue(FileManager.default.fileExists(atPath: zip.path))
        XCTAssertEqual(test.browser.undoJournal.peek?.operationID, compressed.id)
        test.browser.compressRunner = { _, _ in throw FileOpError("runner failed") }
        let failure = try await performOperation(test.browser) { test.browser.compress(source) }
        XCTAssertEqual(failure.status, .failed)
        XCTAssertEqual(failure.items[0].source, source)
        XCTAssertNotNil(failure.items[0].message)
    }

    @MainActor
    func testRenameRecordsKeepBothDestinationAndInvalidNameFailure() async throws {
        let test = try makeTestBrowser(root: root)
        defer { test.browser.close() }
        let source = try write("a.txt", in: test.left)
        let occupied = try write("b.txt", in: test.left, contents: "old")
        await loaded(test)
        let pane = test.browser.left
        test.browser.conflictResolver = { _ in .keepBoth }
        pane.table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        pane.beginRename()
        let cell = try XCTUnwrap(pane.table.view(atColumn: 0, row: 0, makeIfNecessary: true) as? NSTableCellView)
        let field = try XCTUnwrap(cell.textField)
        field.stringValue = "b.txt"
        let record = try await performOperation(test.browser) {
            pane.controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification, object: field))
        }
        XCTAssertEqual(record.kind, .rename)
        XCTAssertEqual(record.status, .completed)
        XCTAssertEqual(record.items[0].source, source)
        let destination = try XCTUnwrap(record.items[0].destination)
        XCTAssertNotEqual(destination, occupied)
        XCTAssertEqual(try String(contentsOf: destination, encoding: .utf8), "payload")
        test.browser.window?.makeFirstResponder(nil)
        await awaitPaneLoad(pane) { pane.session.reload() }
        let row = try XCTUnwrap(pane.session.entries.firstIndex { $0.url == destination })
        pane.table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        pane.beginRename()
        let renamedCell = try XCTUnwrap(pane.table.view(atColumn: 0, row: row, makeIfNecessary: true) as? NSTableCellView)
        let renamedField = try XCTUnwrap(renamedCell.textField)
        renamedField.stringValue = "invalid/name"
        let failure = try await performOperation(test.browser) {
            pane.controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification, object: renamedField))
        }
        XCTAssertEqual(failure.status, .failed)
        XCTAssertEqual(failure.items[0].source, destination)
        XCTAssertNotNil(failure.items[0].message)
        test.browser.window?.makeFirstResponder(nil)
    }

    @MainActor
    func testCompressionCancellationIsRecordedWithoutPublishingArchive() async throws {
        let test = try makeTestBrowser(root: root)
        defer { test.browser.close() }
        await loaded(test)
        let source = try write("cancel.txt", in: test.left)
        test.browser.operationHistory.onChange = {
            if test.browser.operationHistory.records.first?.finishedAt == nil {
                test.browser.perform(NSSelectorFromString("cancelTransfer"))
            }
        }
        let record = try await performOperation(test.browser) { test.browser.compress(source) }
        XCTAssertEqual(record.kind, .compress)
        XCTAssertEqual(record.status, .cancelled)
        XCTAssertNil(record.items[0].destination)
        XCTAssertEqual(test.browser.undoJournal.count, 0)
        test.browser.operationHistory.onChange = nil
    }

    @MainActor
    func testTransferCancellationUsesExactStartSignalAndRecordsUnprocessedItems() async throws {
        let test = try makeTestBrowser(root: root)
        defer { test.browser.close() }
        await loaded(test)
        let first = try write("a.txt", in: test.left)
        let second = try write("b.txt", in: test.left)
        test.browser.operationHistory.onChange = {
            if test.browser.operationHistory.records.first?.finishedAt == nil {
                test.browser.perform(NSSelectorFromString("cancelTransfer"))
            }
        }
        let record = try await performOperation(test.browser) { test.browser.drop([first, second], onto: test.right, moving: false) }
        XCTAssertEqual(record.status, .cancelled)
        XCTAssertEqual(record.items.map(\.status), [.cancelled, .unprocessed])
        XCTAssertEqual(test.browser.undoJournal.count, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: test.right.appendingPathComponent("a.txt").path))
        test.browser.operationHistory.onChange = nil
    }

    @MainActor
    func testAppSharesHistoryUpdatesVisibleWindowAndKeepsClosedWindowRecords() async throws {
        let first = try makeTestBrowser(root: root.appendingPathComponent("first"))
        let second = try makeTestBrowser(root: root.appendingPathComponent("second"))
        var pending = [first.browser, second.browser]
        let delegate = AppDelegate(pasteboard: NSPasteboard(name: .init(UUID().uuidString)), makeBrowser: { _ in pending.removeFirst() })
        let browserA = delegate.createBrowser()
        let browserB = delegate.createBrowser()
        defer { delegate.historyWindowController?.close(); browserA.close(); browserB.close() }
        await loaded(first)
        await loaded(second)
        XCTAssertTrue(browserA.operationHistory === browserB.operationHistory)
        let a = try write("a.txt", in: first.left)
        let recordA = try await performOperation(browserA) { browserA.drop([a], onto: first.right, moving: false) }
        delegate.showOperationHistory(nil)
        let controller = try XCTUnwrap(delegate.historyWindowController)
        controller.table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        let b = try write("b.txt", in: second.left)
        let recordB = try await performOperation(browserB) { browserB.drop([b], onto: second.right, moving: true) }
        XCTAssertEqual(controller.displayedRecords.map(\.id), [recordB.id, recordA.id])
        XCTAssertEqual(controller.selectedRecordID, recordA.id)
        XCTAssertNotEqual(recordA.windowID, recordB.windowID)
        XCTAssertNotEqual(recordA.windowTitle, recordB.windowTitle)
        browserA.close()
        XCTAssertEqual(delegate.operationHistory.records.count, 2)
        XCTAssertEqual(delegate.browsers.count, 1)
        delegate.buildMenu()
        let actions = NSApp.mainMenu?.items.flatMap { $0.submenu?.items ?? [] } ?? []
        XCTAssertTrue(actions.contains { $0.action == #selector(AppDelegate.showOperationHistory(_:)) && $0.target === delegate })
        controller.close()
        delegate.showOperationHistory(nil)
        XCTAssertTrue(delegate.historyWindowController === controller)
        XCTAssertEqual(controller.table.numberOfRows, 2)
        browserB.close()
        XCTAssertFalse(controller.window?.isVisible ?? true)
    }
}
