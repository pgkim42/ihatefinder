import AppKit
import XCTest
import IHateFinderCore
@testable import IHateFinder

/// While an inline rename editor is open, Cmd+Z / Ctrl+Z must undo typing, never the file journal.
final class RenameUndoRoutingTests: XCTestCase {
    @MainActor
    private func setUp(_ t: TestBrowser) async throws -> (FilePaneController, NSWindow) {
        let pane = t.browser.left
        let window = try XCTUnwrap(t.browser.window)
        _ = pane.view
        window.contentView?.layoutSubtreeIfNeeded()
        let deadline = Date().addingTimeInterval(5)
        while pane.session.isLoading || pane.session.entries.isEmpty, Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        window.makeFirstResponder(pane.table)
        return (pane, window)
    }

    /// First responder in the chain (from `start`) that answers `selector`, as AppKit resolves actions.
    private func resolve(_ selector: Selector, from start: NSResponder?) -> NSResponder? {
        var responder = start
        while let current = responder {
            if current.responds(to: selector) { return current }
            responder = current.nextResponder
        }
        return nil
    }

    @MainActor
    func testUndoWhileRenamingDoesNotReachTheTableOrTheJournal() async throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let t = try makeTestBrowser(root: root)
        try Data("x".utf8).write(to: t.left.appendingPathComponent("a.txt"))
        let (pane, window) = try await setUp(t)

        // A created folder is on the journal, as after Cmd+Shift+N.
        let folder = t.left.appendingPathComponent("새 폴더", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        t.browser.recordUndo(FileOps().undoRecord(created: folder))
        XCTAssertEqual(t.browser.undoJournal.count, 1)

        pane.table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        pane.beginRename()
        let editor = try XCTUnwrap(window.firstResponder as? NSTextView)
        XCTAssertTrue(resolve(#selector(NSResponder.cancelOperation(_:)), from: editor) != nil)

        XCTAssertFalse(pane.table.responds(to: #selector(FileTableView.undo(_:))))
        XCTAssertFalse(pane.table.responds(to: #selector(FileTableView.redo(_:))))
        // The editor sits inside the table, so the table must be in its chain for this test to mean anything.
        var chain: [NSResponder] = []
        var link: NSResponder? = editor
        while let current = link { chain.append(current); link = current.nextResponder }
        XCTAssertTrue(chain.contains { $0 === pane.table })
        XCTAssertFalse(resolve(#selector(FileTableView.undo(_:)), from: editor) is FileTableView)
        XCTAssertFalse(resolve(#selector(FileTableView.redo(_:)), from: editor) is FileTableView)

        let item = NSMenuItem(title: "실행 취소", action: #selector(FileTableView.undo(_:)), keyEquivalent: "z")
        XCTAssertFalse(pane.table.validateMenuItem(item))

        _ = editor.tryToPerform(#selector(FileTableView.undo(_:)), with: nil)
        _ = editor.tryToPerform(#selector(FileTableView.redo(_:)), with: nil)

        XCTAssertEqual(t.browser.undoJournal.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.path))
        XCTAssertFalse(t.browser.isFileOperationRunning)
        window.makeFirstResponder(nil)
    }

    @MainActor
    func testUndoOnTheListStillReachesTheTableAndPopsTheJournal() async throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let t = try makeTestBrowser(root: root)
        let folder = t.left.appendingPathComponent("새 폴더", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let (pane, window) = try await setUp(t)
        t.browser.recordUndo(FileOps().undoRecord(created: folder))
        XCTAssertTrue(window.firstResponder === pane.table)

        XCTAssertTrue(pane.table.responds(to: #selector(FileTableView.undo(_:))))
        XCTAssertTrue(resolve(#selector(FileTableView.undo(_:)), from: pane.table) === pane.table)
        let item = NSMenuItem(title: "실행 취소", action: #selector(FileTableView.undo(_:)), keyEquivalent: "z")
        XCTAssertTrue(pane.table.validateMenuItem(item))

        XCTAssertTrue(pane.table.tryToPerform(#selector(FileTableView.undo(_:)), with: nil))
        try await t.browser.waitIdle()

        XCTAssertEqual(t.browser.undoJournal.count, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
    }
}
