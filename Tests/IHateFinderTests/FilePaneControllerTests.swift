import AppKit
import XCTest
import IHateFinderCore
@testable import IHateFinder

final class FilePaneControllerTests: XCTestCase {
    @MainActor
    func testRefreshPreservesSelectedFileWhenRowsShiftAndClearsDeletedSelection() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let selected = root.appendingPathComponent("middle.txt")
        try Data("selected".utf8).write(to: selected)
        try Data("last".utf8).write(to: root.appendingPathComponent("z-last.txt"))
        let session = BrowserSession(url: root)
        let pane = FilePaneController(session: session)
        _ = pane.view
        try await waitUntil { !session.isLoading && session.entries.count == 2 }
        let selectedURL = try XCTUnwrap(session.entries.first?.url)
        pane.table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        try Data("first".utf8).write(to: root.appendingPathComponent("a-first.txt"))
        session.reload()
        try await waitUntil { !session.isLoading && session.entries.count == 3 }
        XCTAssertEqual(pane.selectedURLs(), [selectedURL])
        XCTAssertEqual(pane.table.selectedRow, 1)
        try FileManager.default.removeItem(at: selected)
        session.reload()
        try await waitUntil { !session.isLoading && !session.entries.contains { $0.url == selectedURL } }
        XCTAssertEqual(pane.selectedURLs(), [])
        XCTAssertEqual(pane.table.selectedRow, -1)
    }

    @MainActor
    func testNavigationDoesNotCarryRowSelectionToDifferentFile() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString, isDirectory: true)
        let other = root.appendingPathComponent("other", isDirectory: true)
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("source".utf8).write(to: root.appendingPathComponent("same.txt"))
        try Data("different".utf8).write(to: other.appendingPathComponent("same.txt"))
        let session = BrowserSession(url: root)
        let pane = FilePaneController(session: session)
        _ = pane.view
        try await waitUntil { !session.isLoading && session.entries.count == 2 }
        pane.table.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false)
        session.navigate(to: other)
        try await waitUntil { !session.isLoading && session.url == other }
        XCTAssertEqual(pane.selectedURLs(), [])
        XCTAssertEqual(pane.table.selectedRow, -1)
    }

    @MainActor
    private func waitUntil(_ predicate: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(5)
        while !predicate(), Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(predicate(), "Directory update did not complete")
    }
}
