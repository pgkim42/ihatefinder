import AppKit
import XCTest
@testable import IHateFinder

final class OpenHandlingTests: XCTestCase {
    @MainActor
    func testRevealNavigatesToParentAndSelectsFileWithoutChangingFiles() async throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let t = try makeTestBrowser(root: root)
        let sub = t.right.appendingPathComponent("sub", isDirectory: true)
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try Data("1".utf8).write(to: sub.appendingPathComponent("a.txt"))
        try Data("2".utf8).write(to: sub.appendingPathComponent("b.txt"))
        let pane = t.browser.left
        _ = pane.view

        t.browser.handleOpen(.reveal(parent: sub, select: sub.appendingPathComponent("b.txt")))
        let deadline = Date().addingTimeInterval(5)
        while !(pane.session.url.lastPathComponent == "sub" && pane.selectedURLs().map(\.lastPathComponent) == ["b.txt"]), Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertEqual(pane.session.url.lastPathComponent, "sub")
        XCTAssertEqual(pane.selectedURLs().map(\.lastPathComponent), ["b.txt"])
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: sub.path).sorted(), ["a.txt", "b.txt"])
    }

    @MainActor
    func testShowFolderNavigatesFocusedPane() async throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let t = try makeTestBrowser(root: root)
        let pane = t.browser.left
        _ = pane.view

        t.browser.handleOpen(.showFolder(t.right))
        let deadline = Date().addingTimeInterval(5)
        while pane.session.url.lastPathComponent != "right", Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(pane.session.url.lastPathComponent, "right")
    }
}
