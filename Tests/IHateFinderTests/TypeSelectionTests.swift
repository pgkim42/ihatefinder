import AppKit
import XCTest
import IHateFinderCore
@testable import IHateFinder

final class TypeSelectionTests: XCTestCase {
    private struct Fixture {
        var root: URL
        var window: NSWindow
        var pane: FilePaneController
    }

    @MainActor
    private func makeFixture(files: [String]) async throws -> Fixture {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for path in files {
            let url = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(path.utf8).write(to: url)
        }
        let session = BrowserSession(url: root)
        let pane = FilePaneController(session: session)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .resizable], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentViewController = pane
        _ = pane.view
        window.contentView?.layoutSubtreeIfNeeded()
        await awaitPaneLoad(pane) { session.reload() }
        XCTAssertTrue(window.makeFirstResponder(pane.table))
        return Fixture(root: root, window: window, pane: pane)
    }

    @MainActor
    private func press(_ characters: String, in fixture: Fixture) throws {
        for character in characters {
            let text = String(character)
            let event = try XCTUnwrap(NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: fixture.window.windowNumber, context: nil, characters: text,
                charactersIgnoringModifiers: text, isARepeat: false, keyCode: 0
            ))
            fixture.pane.table.keyDown(with: event)
        }
    }

    @MainActor
    func testTypingNameSelectsMatchingRowOnShownTable() async throws {
        let fixture = try await makeFixture(files: ["alpha.txt", "beta.txt", "zeta.txt"])
        defer { fixture.window.close(); try? FileManager.default.removeItem(at: fixture.root) }
        try press("z", in: fixture)
        XCTAssertEqual(fixture.pane.selectedURLs().map(\.lastPathComponent), ["zeta.txt"])
    }

    @MainActor
    func testTimedPrefixRefinesSelection() async throws {
        let fixture = try await makeFixture(files: ["beta.txt", "berry.txt", "bone.txt"])
        defer { fixture.window.close(); try? FileManager.default.removeItem(at: fixture.root) }
        try press("bo", in: fixture)
        XCTAssertEqual(fixture.pane.selectedURLs().map(\.lastPathComponent), ["bone.txt"])
    }

    @MainActor
    func testTypeSelectionOnlySeesFilteredRows() async throws {
        let fixture = try await makeFixture(files: ["alpha.txt", "beta.txt", "zeta.txt"])
        defer { fixture.window.close(); try? FileManager.default.removeItem(at: fixture.root) }
        fixture.pane.showFilter()
        fixture.pane.filterField.stringValue = "eta"
        fixture.pane.filterField.sendAction(fixture.pane.filterField.action, to: fixture.pane.filterField.target)
        XCTAssertTrue(fixture.window.makeFirstResponder(fixture.pane.table))
        try press("z", in: fixture)
        XCTAssertEqual(fixture.pane.selectedURLs(), [fixture.root.appendingPathComponent("zeta.txt")])
    }

    @MainActor
    func testTypeSelectionUsesRecursiveSearchRows() async throws {
        let fixture = try await makeFixture(files: ["x-apple.txt", "sub/x-banana.txt", "sub/y-other.txt"])
        defer { fixture.window.close(); try? FileManager.default.removeItem(at: fixture.root) }
        let pane = fixture.pane
        let done = expectation(description: "Recursive query completed")
        pane.showRecursiveSearch()
        var fulfilled = false
        pane.onSearchChange = {
            if !pane.searchIsRunning && !fulfilled {
                fulfilled = true
                done.fulfill()
            }
        }
        pane.recursiveSearchField.stringValue = "x-"
        pane.recursiveSearchChanged()
        await fulfillment(of: [done], timeout: 5)
        pane.onSearchChange = nil
        XCTAssertTrue(pane.recursiveSearchVisible)
        XCTAssertTrue(fixture.window.makeFirstResponder(pane.table))
        try press("x-b", in: fixture)
        XCTAssertEqual(pane.selectedURLs(), [fixture.root.appendingPathComponent("sub/x-banana.txt")])
    }

}
