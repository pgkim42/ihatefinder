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
func makeTestBrowser(root: URL) throws -> TestBrowser {
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
    /// Polls until no file operation is running.
    @MainActor
    func waitIdle(timeout: TimeInterval = 5) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while isFileOperationRunning, Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertFalse(isFileOperationRunning, "File operation did not finish")
    }
}
