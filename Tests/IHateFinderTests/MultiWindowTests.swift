import AppKit
import XCTest
import IHateFinderCore
@testable import IHateFinder

final class MultiWindowTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("multi-window-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: root)
    }

    @MainActor
    private func makeDelegate(workspaceStore: WorkspaceStore? = nil, pasteboard: NSPasteboard? = nil) throws -> AppDelegate {
        _ = NSApplication.shared
        var folders: [(left: URL, right: URL, bin: URL)] = []
        for index in 0..<3 {
            let base = root.appendingPathComponent("window-\(index)", isDirectory: true)
            let left = base.appendingPathComponent("left", isDirectory: true)
            let right = base.appendingPathComponent("right", isDirectory: true)
            let bin = base.appendingPathComponent("bin", isDirectory: true)
            for directory in [left, right, bin] {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            folders.append((left, right, bin))
        }
        var index = 0
        return AppDelegate(pasteboard: pasteboard ?? NSPasteboard(name: .init("IHateFinder.windows.\(UUID())"))) { clipboard in
            let paths = folders[index]
            index += 1
            return BrowserWindowController(
                workspaceStore: workspaceStore,
                clipboard: clipboard,
                makeOps: { FileOps(moveToTrash: testBinTrash(into: paths.bin), cloneOnSameVolume: false) },
                initialURLs: (left: paths.left, right: paths.right)
            )
        }
    }

    @MainActor
    private func loaded(_ browser: BrowserWindowController) async {
        for pane in [browser.left, browser.right] {
            await awaitPaneLoad(pane) { pane.session.reload() }
        }
    }

    @MainActor
    private func activate(_ browser: BrowserWindowController) async throws {
        let window = try XCTUnwrap(browser.window)
        // XCTest is a Non UI process. Drive AppKit's native key-transition event
        // without depending on WindowServer activating the test runner.
        let keyed = expectation(description: "Requested browser delivered its key transition")
        let token = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main
        ) { _ in keyed.fulfill() }
        defer { NotificationCenter.default.removeObserver(token) }
        window.becomeKey()
        await fulfillment(of: [keyed], timeout: 5)
    }

    @MainActor
    private func performOperation(_ browser: BrowserWindowController, action: () -> Void) async {
        let completed = expectation(description: "Window file operation completed")
        let previous = browser.onFileOperationStateChange
        var started = false
        browser.onFileOperationStateChange = {
            previous?()
            if browser.isFileOperationRunning {
                started = true
            } else if started {
                completed.fulfill()
            }
        }
        defer { browser.onFileOperationStateChange = previous }
        action()
        await fulfillment(of: [completed], timeout: 5)
    }

    @MainActor
    private func closeAll(_ delegate: AppDelegate) {
        for browser in delegate.browsers {
            if let window = browser.window, let sheet = window.attachedSheet { window.endSheet(sheet) }
            browser.close()
        }
    }

    @MainActor
    func testNewWindowMenuCreatesIndependentSessionsAndFeatureCommands() throws {
        let delegate = try makeDelegate()
        let oldMenu = NSApp.mainMenu
        defer { closeAll(delegate); NSApp.mainMenu = oldMenu }
        delegate.buildMenu()
        let items = try XCTUnwrap(NSApp.mainMenu).items.flatMap { $0.submenu?.items ?? [] }
        let newWindow = try XCTUnwrap(items.first { $0.action == #selector(AppDelegate.newWindow(_:)) })
        XCTAssertEqual(newWindow.keyEquivalent, "n")
        XCTAssertEqual(newWindow.keyEquivalentModifierMask, .command)
        XCTAssertTrue(newWindow.target === delegate)
        XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(newWindow.action), to: newWindow.target, from: newWindow))
        XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(newWindow.action), to: newWindow.target, from: newWindow))
        XCTAssertEqual(delegate.browsers.count, 2)
        let first = delegate.browsers[0]
        let second = delegate.browsers[1]
        XCTAssertFalse(first.window === second.window)
        XCTAssertFalse(first.left.session === second.left.session)
        XCTAssertFalse(first.right.session === second.right.session)
        XCTAssertNotEqual(first.left.session.url, second.left.session.url)
        first.toggleDual()
        XCTAssertTrue(first.dual)
        XCTAssertFalse(second.dual)
        first.left.session.includeHidden = true
        XCTAssertFalse(second.left.session.includeHidden)
        XCTAssertEqual(first.undoJournal.count, 0)
        XCTAssertEqual(second.undoJournal.count, 0)

        let search = try XCTUnwrap(items.first { $0.action == #selector(BrowserWindowController.showRecursiveSearch) })
        XCTAssertEqual(search.keyEquivalent, "f")
        XCTAssertEqual(search.keyEquivalentModifierMask, [.command, .shift])
        XCTAssertNil(search.target)
        XCTAssertNotNil(items.first { $0.action == #selector(BrowserWindowController.toggleThumbnails) })
    }

    @MainActor
    func testResponderCommandsAndOpenRequestsFollowTheActiveBrowserAndFocusedSession() async throws {
        let delegate = try makeDelegate()
        defer { closeAll(delegate) }
        let first = delegate.createBrowser()
        let second = delegate.createBrowser()
        await loaded(first)
        await loaded(second)
        let originalSecond = second.left.session.url
        let destination = first.right.session.url
        try await activate(first)
        first.window?.makeFirstResponder(first.left.table)
        XCTAssertTrue(delegate.activeBrowser === first)
        XCTAssertTrue(try XCTUnwrap(first.window).tryToPerform(#selector(BrowserWindowController.toggleDual), with: nil))
        XCTAssertTrue(first.dual)
        XCTAssertFalse(second.dual)
        await awaitPaneLoad(first.left, expectedURL: destination) { delegate.route(.showFolder(destination)) }
        XCTAssertEqual(second.left.session.url, originalSecond)

        try await activate(second)
        second.toggleDual()
        second.window?.makeFirstResponder(second.right.table)
        XCTAssertTrue(delegate.activeBrowser === second)
        await awaitPaneLoad(second.right, expectedURL: destination) { delegate.route(.showFolder(destination)) }
        XCTAssertEqual(second.left.session.url, originalSecond)
        XCTAssertEqual(first.left.session.url, destination)
        XCTAssertTrue(delegate.pendingOpens.isEmpty)
    }

    @MainActor
    func testClosingOneWindowKeepsTheOtherRegisteredAndReceivingRequests() async throws {
        let delegate = try makeDelegate()
        defer { closeAll(delegate) }
        let first = delegate.createBrowser()
        let second = delegate.createBrowser()
        await loaded(first)
        await loaded(second)
        second.close()
        XCTAssertEqual(delegate.browsers.count, 1)
        XCTAssertTrue(delegate.browsers.first === first)
        XCTAssertTrue(first.window?.isVisible == true)
        let destination = first.right.session.url
        await awaitPaneLoad(first.left, expectedURL: destination) { delegate.route(.showFolder(destination)) }
        XCTAssertTrue(delegate.pendingOpens.isEmpty)
        first.close()
        XCTAssertTrue(delegate.browsers.isEmpty)
    }

    @MainActor
    func testQuitChecksBusyWindowsEvenWhenAnotherWindowIsActive() async throws {
        let delegate = try makeDelegate()
        defer { closeAll(delegate) }
        let first = delegate.createBrowser()
        let second = delegate.createBrowser()
        second.busy = true
        defer { second.busy = false }
        try await activate(first)
        XCTAssertTrue(delegate.activeBrowser === first)
        XCTAssertEqual(delegate.applicationShouldTerminate(NSApp), .terminateCancel)
        XCTAssertEqual(delegate.browsers.count, 2)
        if let window = second.window, let sheet = window.attachedSheet { window.endSheet(sheet) }
        XCTAssertFalse(second.windowShouldClose(try XCTUnwrap(second.window)))
        XCTAssertEqual(delegate.browsers.count, 2)
        if let window = second.window, let sheet = window.attachedSheet { window.endSheet(sheet) }
        second.busy = false
        XCTAssertEqual(delegate.applicationShouldTerminate(NSApp), .terminateNow)
    }

    @MainActor
    func testCutOwnershipSurvivesSourceWindowCloseAndUndoBelongsToDestinationWindow() async throws {
        let delegate = try makeDelegate()
        defer { closeAll(delegate) }
        let first = delegate.createBrowser()
        let second = delegate.createBrowser()
        await loaded(first)
        await loaded(second)
        let source = first.left.session.url.appendingPathComponent("cut.txt")
        let destination = second.left.session.url.appendingPathComponent("cut.txt")
        try Data("move, not copy".utf8).write(to: source)
        await awaitPaneLoad(first.left) { first.left.session.reload() }
        first.left.table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        first.cut(nil)
        XCTAssertTrue(first.isCut(source))
        XCTAssertTrue(second.isCut(source))
        first.close()

        await performOperation(second) { second.paste(nil) }

        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertEqual(try String(contentsOf: destination, encoding: .utf8), "move, not copy")
        XCTAssertFalse(second.isCut(source))
        XCTAssertEqual(first.undoJournal.count, 0)
        XCTAssertEqual(second.undoJournal.count, 1)
        await performOperation(second) { second.undoFileOperation() }
        XCTAssertEqual(try String(contentsOf: source, encoding: .utf8), "move, not copy")
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertEqual(second.undoJournal.count, 0)
    }

    @MainActor
    func testExternalClipboardReplacementClearsSharedCutInsteadOfMoving() async throws {
        let pasteboard = NSPasteboard(name: .init("IHateFinder.windows.external.\(UUID())"))
        let delegate = try makeDelegate(pasteboard: pasteboard)
        defer { closeAll(delegate) }
        let first = delegate.createBrowser()
        let second = delegate.createBrowser()
        await loaded(first)
        await loaded(second)
        let source = first.left.session.url.appendingPathComponent("copy.txt")
        let destination = second.left.session.url.appendingPathComponent("copy.txt")
        try Data("copy".utf8).write(to: source)
        await awaitPaneLoad(first.left) { first.left.session.reload() }
        first.left.table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        first.cut(nil)
        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.writeObjects([source as NSURL]))

        await performOperation(second) { second.paste(nil) }

        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        XCTAssertEqual(try Data(contentsOf: destination), Data("copy".utf8))
        XCTAssertFalse(first.isCut(source))
        XCTAssertFalse(second.isCut(source))
        XCTAssertEqual(first.undoJournal.count, 0)
        XCTAssertEqual(second.undoJournal.count, 1)
    }

    @MainActor
    func testActiveWorkspaceWinsAndLastClosedStateCannotBeOverwritten() async throws {
        let suite = "IHateFinder.windows.workspace.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = WorkspaceStore(defaults: defaults, homeDirectory: root)
        let delegate = try makeDelegate(workspaceStore: store)
        defer { closeAll(delegate) }
        let first = delegate.createBrowser()
        let second = delegate.createBrowser()
        await loaded(first)
        await loaded(second)
        try await activate(first)
        first.saveWorkspace()
        XCTAssertEqual(store.load().left.url, first.left.session.url)
        second.toggleDual()
        second.saveWorkspace()
        XCTAssertEqual(store.load().left.url, first.left.session.url)
        XCTAssertFalse(store.load().dual)

        try await activate(second)
        second.saveWorkspace()
        XCTAssertEqual(store.load().left.url, second.left.session.url)
        XCTAssertTrue(store.load().dual)
        try await activate(first)
        first.saveWorkspace()
        XCTAssertEqual(store.load().left.url, first.left.session.url)
        XCTAssertFalse(store.load().dual)

        second.close()
        XCTAssertEqual(store.load().left.url, first.left.session.url)
        first.close()
        XCTAssertEqual(store.load().left.url, first.left.session.url)
        second.updateStatus()
        second.saveWorkspace()
        XCTAssertEqual(store.load().left.url, first.left.session.url)
        XCTAssertTrue(delegate.browsers.isEmpty)
    }
}
