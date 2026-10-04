import AppKit
import Quartz
import XCTest
import IHateFinderCore
@testable import IHateFinder

final class PreviewAndFilterTests: XCTestCase {
    private struct Fixture {
        var root: URL
        var window: NSWindow
        var pane: FilePaneController
        var session: BrowserSession
    }

    @MainActor
    private func makeFixture(files: [String], folders: [String] = []) async throws -> Fixture {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for name in files { try Data(name.utf8).write(to: root.appendingPathComponent(name)) }
        for name in folders {
            try FileManager.default.createDirectory(at: root.appendingPathComponent(name, isDirectory: true), withIntermediateDirectories: true)
        }
        let session = BrowserSession(url: root)
        let pane = FilePaneController(session: session)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.contentViewController = pane
        _ = pane.view
        window.contentView?.layoutSubtreeIfNeeded()
        try await waitUntil("initial load") { !session.isLoading && session.entries.count == files.count + folders.count }
        return Fixture(root: root, window: window, pane: pane, session: session)
    }

    @MainActor
    private func waitUntil(_ what: String, _ predicate: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(5)
        while !predicate(), Date() < deadline { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertTrue(predicate(), "Timed out: \(what)")
    }

    private func key(_ keyCode: UInt16, _ characters: String, _ flags: NSEvent.ModifierFlags = []) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0,
            context: nil, characters: characters, charactersIgnoringModifiers: characters,
            isARepeat: false, keyCode: keyCode
        ))
    }

    private func type(_ query: String, into pane: FilePaneController) {
        pane.filterField.stringValue = query
        pane.filterField.sendAction(pane.filterField.action, to: pane.filterField.target)
    }

    // MARK: Quick Look keys and data source

    func testQuickLookKeyDetection() {
        XCTAssertTrue(FileTableView.isQuickLookKey(keyCode: 49, flags: []))
        XCTAssertFalse(FileTableView.isQuickLookKey(keyCode: 49, flags: .shift))
        XCTAssertFalse(FileTableView.isQuickLookKey(keyCode: 49, flags: .command))
        XCTAssertTrue(FileTableView.isQuickLookKey(keyCode: 16, flags: .command))
        XCTAssertFalse(FileTableView.isQuickLookKey(keyCode: 16, flags: []))
        XCTAssertFalse(FileTableView.isQuickLookKey(keyCode: 0, flags: []))
    }

    @MainActor
    func testPreviewDataSourceIsSelectionInRowOrder() async throws {
        let f = try await makeFixture(files: ["a.txt", "b.txt", "c.txt"])
        defer { try? FileManager.default.removeItem(at: f.root) }
        f.pane.table.selectRowIndexes(IndexSet([2, 0]), byExtendingSelection: false)
        XCTAssertEqual(f.pane.numberOfPreviewItems(in: nil), 2)
        let first = f.pane.previewPanel(nil, previewItemAt: 0) as? NSURL
        let second = f.pane.previewPanel(nil, previewItemAt: 1) as? NSURL
        XCTAssertEqual(first?.lastPathComponent, "a.txt")
        XCTAssertEqual(second?.lastPathComponent, "c.txt")
        XCTAssertNil(f.pane.previewPanel(nil, previewItemAt: 2))
    }

    @MainActor
    func testPanelEscapeIsNotHandledAndArrowMovesListSelection() async throws {
        let f = try await makeFixture(files: ["a.txt", "b.txt", "c.txt"])
        defer { try? FileManager.default.removeItem(at: f.root) }
        f.window.makeFirstResponder(f.pane.table)
        f.pane.table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)

        XCTAssertFalse(f.pane.previewPanel(nil, handle: try key(53, "\u{1b}")))
        XCTAssertEqual(f.pane.table.selectedRow, 0)

        let down = String(UnicodeScalar(NSDownArrowFunctionKey)!)
        XCTAssertTrue(f.pane.previewPanel(nil, handle: try key(125, down)))
        XCTAssertEqual(f.pane.table.selectedRow, 1)
    }

    @MainActor
    func testSpaceInRenameEditorIsATypedCharacterNotPreview() async throws {
        let f = try await makeFixture(files: ["photo.jpg"])
        defer { try? FileManager.default.removeItem(at: f.root) }
        f.pane.table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        f.window.makeFirstResponder(f.pane.table)
        f.pane.beginRename()
        let editor = try XCTUnwrap(f.window.firstResponder as? NSTextView)
        editor.keyDown(with: try key(49, " "))
        XCTAssertTrue(editor.string.contains(" "))
        XCTAssertFalse(QLPreviewPanel.sharedPreviewPanelExists() && QLPreviewPanel.shared().isVisible)
        f.window.makeFirstResponder(nil)
    }

    // MARK: Multi-open

    @MainActor
    func testEnterOpensEveryFileAndSkipsFoldersInMixedSelection() async throws {
        let f = try await makeFixture(files: ["a.txt", "b.txt"], folders: ["dir"])
        defer { try? FileManager.default.removeItem(at: f.root) }
        var opened: [URL] = []
        f.pane.openFiles = { opened = $0 }
        f.pane.table.selectRowIndexes(IndexSet(integersIn: 0..<3), byExtendingSelection: false)
        f.pane.openSelection()
        XCTAssertEqual(opened.map(\.lastPathComponent).sorted(), ["a.txt", "b.txt"])
        XCTAssertEqual(f.session.url, f.root)
    }

    @MainActor
    func testEnterOnSingleFolderNavigatesAndMultipleFoldersOpenNothing() async throws {
        let f = try await makeFixture(files: [], folders: ["one", "two"])
        defer { try? FileManager.default.removeItem(at: f.root) }
        var opened: [URL] = []
        f.pane.openFiles = { opened = $0 }
        f.pane.table.selectRowIndexes(IndexSet(integersIn: 0..<2), byExtendingSelection: false)
        f.pane.openSelection()
        XCTAssertTrue(opened.isEmpty)
        XCTAssertEqual(f.session.url, f.root)

        f.pane.table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        f.pane.openSelection()
        try await waitUntil("navigate") { !f.session.isLoading && f.session.url.lastPathComponent == "one" }
    }

    @MainActor
    func testMoreThanTwentyFilesAskFirst() async throws {
        let names = (0..<21).map { String(format: "f%02d.txt", $0) }
        let f = try await makeFixture(files: names)
        defer { try? FileManager.default.removeItem(at: f.root) }
        var opened: [URL] = []
        var asked = 0
        f.pane.openFiles = { opened = $0 }
        f.pane.table.selectAll(nil)

        f.pane.confirmOpen = { count in asked = count; return false }
        f.pane.openSelection()
        XCTAssertEqual(asked, 21)
        XCTAssertTrue(opened.isEmpty)

        f.pane.confirmOpen = { _ in true }
        f.pane.openSelection()
        XCTAssertEqual(opened.count, 21)
    }

    // MARK: Filter

    @MainActor
    func testFilterHidesNonMatchingRowsAndDropsHiddenSelection() async throws {
        let f = try await makeFixture(files: ["apple.txt", "banana.txt", "cherry.txt"])
        defer { try? FileManager.default.removeItem(at: f.root) }
        f.pane.table.selectRowIndexes(IndexSet(integersIn: 0..<2), byExtendingSelection: false)
        f.pane.showFilter()
        XCTAssertTrue(f.pane.filterIsVisible)

        type("BAN", into: f.pane)

        XCTAssertEqual(f.pane.table.numberOfRows, 1)
        XCTAssertEqual(f.pane.selectedURLs().map(\.lastPathComponent), ["banana.txt"])
        XCTAssertTrue(f.pane.summary().contains("3개 중 1개 표시"))
    }

    @MainActor
    func testEscapeClearsAndHidesFilterAndRestoresRows() async throws {
        let f = try await makeFixture(files: ["apple.txt", "banana.txt"])
        defer { try? FileManager.default.removeItem(at: f.root) }
        f.pane.showFilter()
        type("apple", into: f.pane)
        XCTAssertEqual(f.pane.table.numberOfRows, 1)

        XCTAssertTrue(f.pane.clearActiveFilter())

        XCTAssertFalse(f.pane.filterIsVisible)
        XCTAssertEqual(f.pane.table.numberOfRows, 2)
        XCTAssertFalse(f.pane.clearActiveFilter())
    }

    @MainActor
    func testNavigationClearsFilter() async throws {
        let f = try await makeFixture(files: ["apple.txt"], folders: ["sub"])
        defer { try? FileManager.default.removeItem(at: f.root) }
        f.pane.showFilter()
        type("sub", into: f.pane)
        XCTAssertEqual(f.pane.table.numberOfRows, 1)

        f.session.navigate(to: f.root.appendingPathComponent("sub"))
        try await waitUntil("navigate") { !f.session.isLoading && f.session.url.lastPathComponent == "sub" }

        XCTAssertFalse(f.pane.filterIsVisible)
        XCTAssertFalse(f.pane.filterIsActive)
    }

    @MainActor
    func testExternalReloadKeepsFilterAndSelectionByURL() async throws {
        let f = try await makeFixture(files: ["apple.txt", "banana.txt"])
        defer { try? FileManager.default.removeItem(at: f.root) }
        f.pane.showFilter()
        type("an", into: f.pane)
        f.pane.table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)

        try Data("x".utf8).write(to: f.root.appendingPathComponent("aaa-new.txt"))
        try Data("x".utf8).write(to: f.root.appendingPathComponent("mango.txt"))
        f.session.reload()
        try await waitUntil("reload") { !f.session.isLoading && f.session.entries.count == 4 }

        XCTAssertTrue(f.pane.filterIsActive)
        XCTAssertEqual(f.pane.table.numberOfRows, 2)   // banana.txt, mango.txt
        XCTAssertEqual(f.pane.selectedURLs().map(\.lastPathComponent), ["banana.txt"])
    }

    @MainActor
    func testPendingRevealOfHiddenNewItemClearsFilter() async throws {
        let f = try await makeFixture(files: ["apple.txt"])
        defer { try? FileManager.default.removeItem(at: f.root) }
        f.pane.showFilter()
        type("apple", into: f.pane)
        let created = f.root.appendingPathComponent("zzz-new.txt")
        try Data("x".utf8).write(to: created)

        f.pane.revealAfterReload(created, rename: false)
        f.session.reload()
        try await waitUntil("reveal") {
            !f.session.isLoading && f.pane.selectedURLs().map(\.lastPathComponent) == ["zzz-new.txt"]
        }

        XCTAssertFalse(f.pane.filterIsActive)
        XCTAssertFalse(f.pane.filterIsVisible)
        XCTAssertEqual(f.pane.table.numberOfRows, 2)
    }
}
