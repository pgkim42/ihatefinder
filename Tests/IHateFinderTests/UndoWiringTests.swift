import AppKit
import XCTest
import IHateFinderCore
@testable import IHateFinder

final class UndoWiringTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("undo-wiring-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: root)
    }

    @MainActor
    private func waitUntil(_ message: String, _ predicate: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(5)
        while !predicate(), Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(predicate(), message)
    }

    @MainActor
    private func loaded(_ test: TestBrowser) async throws {
        for pane in [test.browser.left, test.browser.right] {
            _ = pane.view
            try await waitUntil("pane load") { !pane.session.isLoading && pane.session.revision > 0 }
        }
    }

    private func entry(_ name: String, in directory: URL) -> URL {
        directory.appendingPathComponent(name)
    }

    @MainActor
    func testCreateFolderThenUndoMovesItToBinAndEmptiesJournal() async throws {
        let test = try makeTestBrowser(root: root)
        try await loaded(test)
        test.browser.left.makeFolder()
        try await test.browser.waitIdle()
        let created = entry("새 폴더", in: test.left)
        XCTAssertTrue(FileManager.default.fileExists(atPath: created.path))
        XCTAssertEqual(test.browser.undoJournal.count, 1)

        test.browser.undoFileOperation()
        try await test.browser.waitIdle()

        XCTAssertFalse(FileManager.default.fileExists(atPath: created.path))
        XCTAssertEqual(test.browser.undoJournal.count, 0)
        let report = try XCTUnwrap(test.browser.lastUndoReport)
        XCTAssertEqual(report.undone.count, 1)
        XCTAssertEqual(report.skipped.count, 0)
        let binned = try FileManager.default.subpathsOfDirectory(atPath: test.bin.path)
        XCTAssertTrue(binned.contains { $0.hasSuffix("새 폴더") }, "The folder is in the test bin: \(binned)")
    }

    @MainActor
    func testPartialTrashKeepsReportAndRecordsOnlyTheFirstFileThenUndoRestoresIt() async throws {
        let bin = root.appendingPathComponent("partial-bin", isDirectory: true)
        let left = root.appendingPathComponent("left", isDirectory: true)
        let right = root.appendingPathComponent("right", isDirectory: true)
        for directory in [bin, left, right] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        for name in ["a.txt", "b.txt", "c.txt"] { try Data(name.utf8).write(to: left.appendingPathComponent(name)) }
        let inner = testBinTrash(into: bin)
        let browser = BrowserWindowController(
            workspaceStore: nil,
            pasteboard: NSPasteboard(name: .init("IHateFinder.test.\(UUID().uuidString)")),
            makeOps: {
                FileOps(sameVolume: FileOps.volumesMatch, moveToTrash: { url in
                    if url.lastPathComponent == "b.txt" { throw FileOpError("거부됨") }
                    return try inner(url)
                })
            },
            initialURLs: (left: left, right: right)
        )
        let pane = browser.left
        _ = pane.view
        try await waitUntil("load") { !pane.session.isLoading && pane.session.entries.count == 3 }
        pane.table.selectRowIndexes(IndexSet(integersIn: 0..<3), byExtendingSelection: false)

        pane.trashSelection()
        try await browser.waitIdle()

        let report = try XCTUnwrap(browser.lastTrashReport)
        XCTAssertEqual(report.items.map(\.original.lastPathComponent), ["a.txt", "b.txt", "c.txt"])
        XCTAssertEqual(report.items[0].status, .trashed)
        guard case .failed = report.items[1].status else { return XCTFail("b.txt should have failed") }
        XCTAssertEqual(report.items[2].status, .unprocessed)
        XCTAssertEqual(browser.undoJournal.count, 1)
        let record = try XCTUnwrap(browser.undoJournal.peek)
        XCTAssertEqual(record.items.count, 1)
        guard case .trashed(let original, _) = record.items[0] else { return XCTFail("expected .trashed") }
        XCTAssertEqual(original.lastPathComponent, "a.txt")
        XCTAssertFalse(FileManager.default.fileExists(atPath: left.appendingPathComponent("a.txt").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: left.appendingPathComponent("b.txt").path))

        browser.undoFileOperation()
        try await browser.waitIdle()

        let undo = try XCTUnwrap(browser.lastUndoReport)
        XCTAssertEqual(undo.undone.map(\.url.lastPathComponent), ["a.txt"])
        XCTAssertEqual(undo.skipped.count, 0)
        XCTAssertEqual(try String(contentsOf: left.appendingPathComponent("a.txt"), encoding: .utf8), "a.txt")
        XCTAssertEqual(browser.undoJournal.count, 0)
    }

    @MainActor
    func testUndoIsRefusedWhileBusyAndDoesNotPop() async throws {
        let test = try makeTestBrowser(root: root)
        try await loaded(test)
        test.browser.left.makeFolder()
        try await test.browser.waitIdle()
        XCTAssertEqual(test.browser.undoJournal.count, 1)
        let before = test.browser.lastUndoReport

        test.browser.busy = true
        test.browser.undoFileOperation()

        XCTAssertEqual(test.browser.undoJournal.count, 1)
        XCTAssertEqual(test.browser.lastUndoReport, before)
        XCTAssertNil(test.browser.lastUndoReport)
        XCTAssertTrue(FileManager.default.fileExists(atPath: entry("새 폴더", in: test.left).path))
        test.browser.busy = false
    }

    @MainActor
    func testValidateMenuItemForUndoAndRedo() async throws {
        let test = try makeTestBrowser(root: root)
        try await loaded(test)
        let table = test.browser.left.table
        let undo = NSMenuItem(title: "실행 취소", action: #selector(FileTableView.undo(_:)), keyEquivalent: "z")
        let redo = NSMenuItem(title: "다시 실행", action: #selector(FileTableView.redo(_:)), keyEquivalent: "z")

        XCTAssertFalse(table.validateMenuItem(undo), "Disabled while the journal is empty")
        test.browser.left.makeFolder()
        try await test.browser.waitIdle()
        // makeFolder starts a rename; while the editor is open the item is (correctly) disabled.
        test.browser.window?.makeFirstResponder(table)
        XCTAssertTrue(table.validateMenuItem(undo))
        XCTAssertTrue(undo.title.contains("새로 만들기"), undo.title)
        test.browser.busy = true
        XCTAssertFalse(table.validateMenuItem(undo), "Disabled while a file operation runs")
        test.browser.busy = false
        XCTAssertFalse(table.validateMenuItem(redo))
        XCTAssertEqual(redo.title, "다시 실행")
    }

    @MainActor
    func testCutAndPasteIntoTheSameFolderPushesNoRecord() async throws {
        let test = try makeTestBrowser(root: root)
        try await loaded(test)
        let file = test.left.appendingPathComponent("stay.txt")
        try Data("x".utf8).write(to: file)
        test.browser.left.session.reload()
        try await waitUntil("listed") { test.browser.left.session.entries.count == 1 && !test.browser.left.session.isLoading }
        test.browser.left.table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)

        test.browser.cut(nil)
        test.browser.paste(nil)
        try await test.browser.waitIdle()

        XCTAssertEqual(test.browser.undoJournal.count, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }

    @MainActor
    func testDropMovePushesARecordAndUndoMovesItBack() async throws {
        let test = try makeTestBrowser(root: root)
        try await loaded(test)
        let file = test.left.appendingPathComponent("drag.txt")
        try Data("d".utf8).write(to: file)

        test.browser.drop([file], onto: test.right, moving: true)
        try await test.browser.waitIdle()
        XCTAssertEqual(test.browser.undoJournal.peek?.title, "옮기기")
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))

        test.browser.undoFileOperation()
        try await test.browser.waitIdle()

        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "d")
        XCTAssertFalse(FileManager.default.fileExists(atPath: test.right.appendingPathComponent("drag.txt").path))
        XCTAssertEqual(test.browser.lastUndoReport?.undone.count, 1)
    }

    @MainActor
    func testUndoSkipsAndReportsAnItemChangedInBetween() async throws {
        let test = try makeTestBrowser(root: root)
        try await loaded(test)
        let file = test.left.appendingPathComponent("copy-me.txt")
        try Data("c".utf8).write(to: file)
        test.browser.drop([file], onto: test.right, moving: false)
        try await test.browser.waitIdle()
        let copy = test.right.appendingPathComponent("copy-me.txt")
        try FileManager.default.removeItem(at: copy)
        try Data("different".utf8).write(to: copy)

        test.browser.undoFileOperation()
        try await test.browser.waitIdle()

        let report = try XCTUnwrap(test.browser.lastUndoReport)
        XCTAssertEqual(report.items.map(\.status), [.stale])
        XCTAssertEqual(try String(contentsOf: copy, encoding: .utf8), "different")
        XCTAssertEqual(test.browser.undoJournal.count, 0, "A refused item is not re-pushed")
    }
}
