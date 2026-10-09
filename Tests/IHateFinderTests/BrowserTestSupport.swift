import AppKit
import XCTest
import IHateFinderCore
@testable import IHateFinder

/// Builds a browser whose panes, pasteboard, and Trash all live under `root`.
/// App tests must use this instead of the default `makeOps`, and must never
/// start in the home folder or touch the real Trash.
struct TestBrowser {
    let browser: BrowserWindowController
    let left: URL
    let right: URL
    /// Stands in for the Trash: every trashed item lands in its own folder here.
    let bin: URL
}

@MainActor
func makeTestBrowser(root: URL, favoriteStore: FavoritePlacesStore? = nil) throws -> TestBrowser {
    _ = NSApplication.shared
    let fm = FileManager.default
    let left = root.appendingPathComponent("left", isDirectory: true)
    let right = root.appendingPathComponent("right", isDirectory: true)
    let bin = root.appendingPathComponent("bin", isDirectory: true)
    for directory in [left, right, bin] {
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    let browser = BrowserWindowController(
        workspaceStore: nil,
        favoriteStore: favoriteStore,
        pasteboard: NSPasteboard(name: .init("IHateFinder.test.\(UUID().uuidString)")),
        makeOps: { FileOps(sameVolume: FileOps.volumesMatch, moveToTrash: testBinTrash(into: bin), cloneOnSameVolume: false) },
        initialURLs: (left: left, right: right)
    )
    return TestBrowser(browser: browser, left: left, right: right, bin: bin)
}

/// A temp-folder replacement for the Trash seam. Returns the URL the item moved to.
func testBinTrash(into bin: URL) -> (URL) throws -> URL? {
    { url in
        let holder = bin.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: holder, withIntermediateDirectories: true)
        let moved = holder.appendingPathComponent(url.lastPathComponent)
        try FileManager.default.moveItem(at: url, to: moved)
        return moved
    }
}

extension BrowserWindowController {
    /// Subscribes to the exact operation state before checking whether it already settled.
    @MainActor
    func waitIdle(timeout: TimeInterval = 5) async throws {
        let completed = XCTestExpectation(description: "File operation finished")
        let previous = onFileOperationStateChange
        var fulfilled = false
        let finish = { [weak self] in
            guard let self, !self.isFileOperationRunning, !fulfilled else { return }
            fulfilled = true
            completed.fulfill()
        }
        onFileOperationStateChange = { previous?(); finish() }
        defer { onFileOperationStateChange = previous }
        finish()
        let result = await XCTWaiter.fulfillment(of: [completed], timeout: timeout)
        XCTAssertEqual(result, .completed)
        XCTAssertFalse(isFileOperationRunning, "File operation did not finish")
    }
}

/// Installs the committed-list signal before triggering a reload or navigation.
@MainActor
func awaitPaneLoad(_ pane: FilePaneController, expectedURL: URL? = nil, action: () -> Void) async {
    let completed = XCTestExpectation(description: "Pane committed requested list")
    let previous = pane.session.onChange
    let revision = pane.session.revision
    let target = (expectedURL ?? pane.session.url).standardizedFileURL
    var fulfilled = false
    pane.session.onChange = {
        previous?()
        guard !pane.session.isLoading, pane.session.url == target,
              pane.session.revision > revision, !fulfilled else { return }
        fulfilled = true
        completed.fulfill()
    }
    defer { pane.session.onChange = previous }
    action()
    let result = await XCTWaiter.fulfillment(of: [completed], timeout: 5)
    XCTAssertEqual(result, .completed)
    XCTAssertEqual(pane.session.loadState, .idle)
}
