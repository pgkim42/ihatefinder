import AppKit
import XCTest
import IHateFinderCore
@testable import IHateFinder

final class PaneDailyTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("pane-daily-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: root)
    }


    @MainActor
    private func makePane(at url: URL) async throws -> (FilePaneController, BrowserSession, NSWindow) {
        _ = NSApplication.shared
        let session = BrowserSession(url: url)
        let pane = FilePaneController(session: session)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.contentViewController = pane
        _ = pane.view
        await awaitPaneLoad(pane) { session.reload() }
        return (pane, session, window)
    }

    @MainActor
    func testGoUpSelectsTheFolderYouCameFrom() async throws {
        let child = root.appendingPathComponent("child", isDirectory: true)
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: root.appendingPathComponent("a-file.txt"))
        try FileManager.default.createDirectory(at: root.appendingPathComponent("z-other", isDirectory: true), withIntermediateDirectories: true)
        let (pane, _, window) = try await makePane(at: child)
        _ = window

        await awaitPaneLoad(pane, expectedURL: root) { pane.goUp() }
        XCTAssertEqual(pane.selectedURLs().map(\.lastPathComponent), ["child"])

        XCTAssertNil(pane.pendingReveal)
    }

    @MainActor
    func testPathJumpSelectsImmediateChildAndBackRestoresSelection() async throws {
        let child = root.appendingPathComponent("한글 space #", isDirectory: true)
        let deep = child.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: deep, withIntermediateDirectories: true)
        let file = deep.appendingPathComponent("keep.txt")
        try Data("x".utf8).write(to: file)
        let (pane, session, window) = try await makePane(at: deep)
        _ = window
        pane.table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)

        pane.showFilter()
        pane.filterField.stringValue = "keep"
        pane.filterField.sendAction(pane.filterField.action, to: pane)
        await awaitPaneLoad(pane, expectedURL: root) { pane.navigatePathComponent(to: root) }
        XCTAssertTrue(pane.filterField.isHidden)
        XCTAssertEqual(pane.selectedURLs().map(\.standardizedFileURL), [child.standardizedFileURL])
        XCTAssertEqual(pane.pathControl.url?.standardizedFileURL, root.standardizedFileURL)
        XCTAssertNil(pane.pendingReveal)
        await awaitPaneLoad(pane, expectedURL: deep) { pane.goBack() }
        XCTAssertEqual(pane.selectedURLs().map(\.standardizedFileURL), [file.standardizedFileURL])
        XCTAssertEqual(pane.pathControl.url?.standardizedFileURL, deep.standardizedFileURL)
        XCTAssertTrue(session.canGoForward)
        XCTAssertFalse(pane.filterField.isHidden)
        XCTAssertEqual(pane.filterField.stringValue, "keep")
    }

    @MainActor
    func testFailedPathJumpKeepsCommittedPathAndSelection() async throws {
        try Data("x".utf8).write(to: root.appendingPathComponent("keep.txt"))
        let (pane, session, window) = try await makePane(at: root)
        _ = window
        pane.table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        let failed = expectation(description: "Navigation failed")
        let previous = session.onChange
        session.onChange = {
            previous?()
            if case .failed = session.loadState { failed.fulfill() }
        }
        defer { session.onChange = previous }
        pane.navigatePathComponent(to: root.appendingPathComponent("missing"))
        await fulfillment(of: [failed], timeout: 5)
        XCTAssertEqual(session.url.standardizedFileURL, root.standardizedFileURL)
        XCTAssertEqual(pane.pathControl.url?.standardizedFileURL, root.standardizedFileURL)
        XCTAssertEqual(pane.selectedURLs().map(\.lastPathComponent), ["keep.txt"])
        XCTAssertFalse(session.canGoBack)
    }

    @MainActor
    func testCurrentPathClickPreservesSelectionAndHistory() async throws {
        try Data("x".utf8).write(to: root.appendingPathComponent("keep.txt"))
        let (pane, session, window) = try await makePane(at: root)
        _ = window
        pane.table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        let revision = session.revision
        pane.navigatePathComponent(to: root)
        XCTAssertEqual(pane.selectedURLs().map(\.lastPathComponent), ["keep.txt"])
        XCTAssertEqual(session.revision, revision)
        XCTAssertFalse(session.isLoading)
        XCTAssertFalse(session.canGoBack)
        XCTAssertTrue(window.firstResponder === pane.table)
    }

    @MainActor
    func testPathClickClaimsTheRightPaneWithoutMovingTheLeft() async throws {
        let test = try makeTestBrowser(root: root)
        let pane = test.browser.right
        _ = pane.view
        await awaitPaneLoad(pane) { pane.session.reload() }
        test.browser.focus(test.browser.left)
        await awaitPaneLoad(pane, expectedURL: root) { pane.navigatePathComponent(to: root) }
        test.browser.findInFolder()
        XCTAssertFalse(pane.filterField.isHidden)
        XCTAssertTrue(test.browser.left.filterField.isHidden)
        XCTAssertEqual(test.browser.left.session.url.standardizedFileURL, test.left.standardizedFileURL)
        XCTAssertEqual(pane.selectedURLs().map(\.standardizedFileURL), [test.right.standardizedFileURL])
    }

    @MainActor
    func testRevealAfterReloadSelectsAFileCreatedExternallyAfterTheCall() async throws {
        try Data("x".utf8).write(to: root.appendingPathComponent("existing.txt"))
        let (pane, session, window) = try await makePane(at: root)
        _ = window
        let later = root.appendingPathComponent("later.txt")

        pane.revealAfterReload(later, rename: false)
        XCTAssertEqual(pane.selectedURLs(), [])
        try Data("y".utf8).write(to: later)
        await awaitPaneLoad(pane) { session.reload() }
        XCTAssertEqual(pane.selectedURLs().map(\.lastPathComponent), ["later.txt"])
        XCTAssertNil(pane.pendingReveal)
    }

    @MainActor
    func testNavigatingElsewhereClearsPendingReveal() async throws {
        let elsewhere = root.appendingPathComponent("elsewhere", isDirectory: true)
        try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
        let (pane, session, window) = try await makePane(at: root)
        _ = window

        pane.revealAfterReload(root.appendingPathComponent("never-created.txt"), rename: true)
        XCTAssertNotNil(pane.pendingReveal)
        await awaitPaneLoad(pane, expectedURL: elsewhere) { session.navigate(to: elsewhere) }

        XCTAssertNil(pane.pendingReveal)
        XCTAssertEqual(pane.selectedURLs(), [])
    }

    @MainActor
    func testMakeFolderInBrowserSelectsTheNewFolderAndStartsRename() async throws {
        let test = try makeTestBrowser(root: root)
        let pane = test.browser.left
        test.browser.window?.setContentSize(NSSize(width: 1000, height: 600))
        test.browser.window?.contentView?.layoutSubtreeIfNeeded()
        _ = pane.view
        await awaitPaneLoad(pane) { pane.session.reload() }
        let renameBegan = expectation(description: "New folder rename editor began")
        pane.onRenameStart = { renameBegan.fulfill() }
        defer { pane.onRenameStart = nil }

        pane.makeFolder()
        try await test.browser.waitIdle()

        let created = test.left.appendingPathComponent("새 폴더").standardizedFileURL
        test.browser.window?.contentView?.layoutSubtreeIfNeeded()
        await fulfillment(of: [renameBegan], timeout: 5)
        XCTAssertEqual(pane.selectedURLs().map(\.standardizedFileURL), [created])
        XCTAssertTrue(FileManager.default.fileExists(atPath: created.path))
        XCTAssertEqual(test.browser.undoJournal.peek?.title, "새로 만들기")
        let editor = try XCTUnwrap(test.browser.window?.firstResponder as? NSTextView)
        let field = try XCTUnwrap(editor.delegate as? NSTextField)
        XCTAssertEqual(pane.table.row(for: field), 0)
        XCTAssertEqual(field.stringValue, "새 폴더")
    }
}
