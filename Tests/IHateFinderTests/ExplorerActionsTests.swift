import AppKit
import XCTest
import IHateFinderCore
@testable import IHateFinder

final class ExplorerActionsTests: XCTestCase {
    @MainActor
    func testToolbarCutPasteUsesFocusedPaneAndCanBeUndone() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let t = try makeTestBrowser(root: root)
        defer { t.browser.close() }
        let source = t.left.appendingPathComponent("report.txt")
        let destination = t.right.appendingPathComponent("report.txt")
        try Data("report content".utf8).write(to: source)
        await awaitPaneLoad(t.browser.left) { t.browser.left.session.reload() }
        await awaitPaneLoad(t.browser.right) { t.browser.right.session.reload() }
        let cut = try button(#selector(BrowserWindowController.cut(_:)), in: t.browser)
        let paste = try button(#selector(BrowserWindowController.paste(_:)), in: t.browser)
        XCTAssertFalse(cut.isEnabled)
        XCTAssertFalse(paste.isEnabled)
        t.browser.left.table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        XCTAssertTrue(cut.isEnabled)
        cut.performClick(nil)
        XCTAssertTrue(t.browser.isCut(source))
        t.browser.toggleDual()
        t.browser.window?.makeFirstResponder(t.browser.right.table)
        XCTAssertTrue(paste.isEnabled)
        paste.performClick(nil)
        try await t.browser.waitIdle()
        XCTAssertEqual(try Data(contentsOf: destination), Data("report content".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        t.browser.undoFileOperation()
        try await t.browser.waitIdle()
        XCTAssertEqual(try Data(contentsOf: source), Data("report content".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    @MainActor
    func testToolbarDisablesMutationDuringRenameBusyAndSearch() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let t = try makeTestBrowser(root: root)
        defer { t.browser.close() }
        try Data("keep".utf8).write(to: t.left.appendingPathComponent("report.txt"))
        await awaitPaneLoad(t.browser.left) { t.browser.left.session.reload() }
        t.browser.left.table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        let rename = try button(#selector(BrowserWindowController.beginRename), in: t.browser)
        let trash = try button(#selector(BrowserWindowController.trashSelection), in: t.browser)
        let create = try button(#selector(BrowserWindowController.makeFolder), in: t.browser)
        let paste = try button(#selector(BrowserWindowController.paste(_:)), in: t.browser)
        let copy = try button(#selector(BrowserWindowController.copy(_:)), in: t.browser)
        copy.performClick(nil)
        XCTAssertEqual(t.browser.left.selectedURLs(), [t.left.appendingPathComponent("report.txt")],
                       "Copy must preserve the file selection for the next action")
        XCTAssertTrue(paste.isEnabled)
        t.browser.busy = true
        XCTAssertFalse(rename.isEnabled)
        XCTAssertFalse(trash.isEnabled)
        XCTAssertFalse(create.isEnabled)
        XCTAssertFalse(paste.isEnabled)
        t.browser.busy = false
        t.browser.window?.contentView?.layoutSubtreeIfNeeded()
        XCTAssertTrue(t.browser.window?.makeFirstResponder(t.browser.left.table) == true)
        XCTAssertTrue(rename.isEnabled)
        rename.performClick(nil)
        XCTAssertTrue(t.browser.window?.firstResponder is NSTextView)
        XCTAssertFalse(trash.isEnabled)
        XCTAssertFalse(create.isEnabled)
        (t.browser.window?.firstResponder as? NSTextView)?.doCommand(by: #selector(NSResponder.cancelOperation(_:)))
        t.browser.left.showRecursiveSearch()
        XCTAssertFalse(create.isEnabled)
        XCTAssertFalse(paste.isEnabled)
    }

    @MainActor
    private func button(_ action: Selector, in browser: BrowserWindowController) throws -> NSButton {
        func find(_ view: NSView) -> NSButton? {
            if let button = view as? NSButton, button.action == action { return button }
            return view.subviews.lazy.compactMap(find).first
        }
        return try XCTUnwrap(find(try XCTUnwrap(browser.window?.contentView)))
    }
}
