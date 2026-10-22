import AppKit
import XCTest
import IHateFinderCore
@testable import IHateFinder

final class ConflictAndRetryTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("conflict-retry-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }

    private func write(_ name: String, in folder: URL, text: String) throws -> URL {
        let url = folder.appendingPathComponent(name)
        try Data(text.utf8).write(to: url)
        return url
    }

    @MainActor
    private func perform(_ browser: BrowserWindowController, _ action: () -> Void) async throws -> FileOperationRecord {
        let done = expectation(description: "Operation recorded")
        let before = Set(browser.operationHistory.records.map(\.id))
        let previous = browser.operationHistory.onChange
        var result: FileOperationRecord?
        browser.operationHistory.onChange = {
            previous?()
            if result == nil, let record = browser.operationHistory.records.first(where: {
                !before.contains($0.id) && $0.finishedAt != nil
            }) {
                result = record
                done.fulfill()
            }
        }
        defer { browser.operationHistory.onChange = previous }
        action()
        await fulfillment(of: [done], timeout: 5)
        if let window = browser.window, let sheet = window.attachedSheet { window.endSheet(sheet) }
        return try XCTUnwrap(result)
    }

    @MainActor
    func testConflictCancelKeepsCompletedItemAndLeavesConflictAndRemainingUntouched() async throws {
        let test = try makeTestBrowser(root: root)
        defer { test.browser.close() }
        let done = try write("done.txt", in: test.left, text: "done")
        let conflict = try write("conflict.txt", in: test.left, text: "incoming")
        let remaining = try write("remaining.txt", in: test.left, text: "remaining")
        let occupied = try write("conflict.txt", in: test.right, text: "existing")
        var seen: FileConflictContext?
        test.browser.conflictDecision = { context in seen = context; return .cancel }

        let record = try await perform(test.browser) {
            test.browser.drop([done, conflict, remaining], onto: test.right, moving: false)
        }
        XCTAssertEqual(record.items.map(\.status), [.completed, .cancelled, .unprocessed])
        XCTAssertEqual(seen?.source.url, conflict)
        XCTAssertEqual(seen?.destination.url, occupied)
        XCTAssertEqual(seen?.source.size, 8)
        XCTAssertNotNil(seen?.source.modified)
        XCTAssertEqual(try String(contentsOf: occupied, encoding: .utf8), "existing")
        XCTAssertTrue(FileManager.default.fileExists(atPath: test.right.appendingPathComponent("done.txt").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: test.right.appendingPathComponent("remaining.txt").path))
        XCTAssertEqual(test.browser.undoJournal.peek?.items.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: conflict.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: remaining.path))
    }

    @MainActor
    func testConflictContextDistinguishesSameNamedSourcesAndWarnsAboutWholeFolderReplacement() async throws {
        let test = try makeTestBrowser(root: root)
        defer { test.browser.close() }
        let other = root.appendingPathComponent("other", isDirectory: true)
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        let first = try write("same.txt", in: test.left, text: "first")
        let second = try write("same.txt", in: other, text: "second")
        var seen: [URL] = []
        test.browser.conflictDecision = { context in seen.append(context.source.url); return .skip }
        _ = try await perform(test.browser) { test.browser.drop([first, second], onto: test.right, moving: false) }
        XCTAssertEqual(seen, [second])

        let context = FileConflictContext(source: test.left, destination: test.right)
        XCTAssertTrue(context.details.contains(test.left.path))
        XCTAssertTrue(context.details.contains(test.right.path))
        XCTAssertTrue(context.details.contains("대상 폴더 전체를 교체"))
        XCTAssertTrue(context.details.contains("내용을 합치지 않습니다"))
        let alert = context.makeAlert(canCancelTransfer: true)
        XCTAssertEqual(alert.buttons.last?.title, "전체 작업 취소")
        XCTAssertEqual(alert.buttons.last?.keyEquivalent, "\u{1b}")
    }

    @MainActor
    func testRetryTargetsBlockedMoveAfterRepairRenameAndPreservesNormalUndo() async throws {
        let test = try makeTestBrowser(root: root)
        defer { test.browser.close() }
        let source = try write("item.txt", in: test.left, text: "original")
        let original = try await perform(test.browser) { test.browser.drop([source], onto: test.right, moving: true) }
        _ = try write("item.txt", in: test.left, text: "obstruction")
        _ = try await perform(test.browser) { test.browser.undoFileOperation() }
        XCTAssertNotNil(test.browser.undoJournal.peekRetry)

        let ops = test.browser.left.session.ops
        _ = try await perform(test.browser) {
            test.browser.runReporting("이름 변경 실패", operation: .rename, work: {
                let result = try ops.rename(url: source, to: "obstruction-backup.txt", resolve: { _ in .skip })
                return ops.undoRecord(rename: result, from: source)
            }, completion: { record, id in
                test.browser.recordUndo(record, operationID: id)
                test.browser.finishOperation(id, items: [])
            })
        }
        let repair = try XCTUnwrap(test.browser.undoJournal.peek)
        XCTAssertEqual(repair.title, "이름 바꾸기")
        let menu = NSMenuItem(title: "", action: #selector(BrowserWindowController.retryBlockedUndo), keyEquivalent: "")
        XCTAssertTrue(test.browser.validateMenuItem(menu))
        test.browser.busy = true
        test.browser.retryBlockedUndo()
        XCTAssertNotNil(test.browser.undoJournal.peekRetry)
        XCTAssertFalse(test.browser.validateMenuItem(menu))
        test.browser.busy = false

        let retry = try await perform(test.browser) { test.browser.retryBlockedUndo() }
        XCTAssertEqual(retry.parentID, original.id)
        XCTAssertEqual(try String(contentsOf: source, encoding: .utf8), "original")
        XCTAssertEqual(try String(contentsOf: test.left.appendingPathComponent("obstruction-backup.txt"), encoding: .utf8), "obstruction")
        XCTAssertEqual(test.browser.undoJournal.peek, repair)
        XCTAssertNil(test.browser.undoJournal.peekRetry)
        XCTAssertFalse(test.browser.validateMenuItem(menu))
        XCTAssertFalse(FileManager.default.fileExists(atPath: test.right.appendingPathComponent("item.txt").path))
    }
}
