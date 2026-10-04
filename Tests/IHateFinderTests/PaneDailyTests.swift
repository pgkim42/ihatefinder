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
    private func waitUntil(_ message: String, _ predicate: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(5)
        while !predicate(), Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(predicate(), message)
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
        try await waitUntil("initial load") { !session.isLoading && session.revision > 0 }
        return (pane, session, window)
    }

    @MainActor
    func testGoUpSelectsTheFolderYouCameFrom() async throws {
        let child = root.appendingPathComponent("child", isDirectory: true)
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: root.appendingPathComponent("a-file.txt"))
        try FileManager.default.createDirectory(at: root.appendingPathComponent("z-other", isDirectory: true), withIntermediateDirectories: true)
        let (pane, session, window) = try await makePane(at: child)
        _ = window

        pane.goUp()
        try await waitUntil("went up") { !session.isLoading && session.url.path == self.root.path }
        try await waitUntil("origin selected") { pane.selectedURLs().map(\.lastPathComponent) == ["child"] }

        XCTAssertNil(pane.pendingReveal)
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
        session.reload()

        try await waitUntil("later.txt selected") { pane.selectedURLs().map(\.lastPathComponent) == ["later.txt"] }
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
        session.navigate(to: elsewhere)
        try await waitUntil("navigated") { !session.isLoading && session.url.path == elsewhere.path }

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
        try await waitUntil("initial load") { !pane.session.isLoading && pane.session.revision > 0 }

        pane.makeFolder()
        try await test.browser.waitIdle()

        let created = test.left.appendingPathComponent("새 폴더").standardizedFileURL
        test.browser.window?.contentView?.layoutSubtreeIfNeeded()
        try await waitUntil("new folder selected") { pane.selectedURLs().map(\.standardizedFileURL) == [created] }
        XCTAssertTrue(FileManager.default.fileExists(atPath: created.path))
        XCTAssertEqual(test.browser.undoJournal.peek?.title, "새로 만들기")
        try await waitUntil("rename editor active on the new folder row") {
            guard let editor = test.browser.window?.firstResponder as? NSTextView,
                  let field = editor.delegate as? NSTextField else { return false }
            return pane.table.row(for: field) == 0 && field.stringValue == "새 폴더"
        }
    }
}
