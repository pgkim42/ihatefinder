import AppKit
import XCTest
import IHateFinderCore
@testable import IHateFinder

final class FileTableViewTests: XCTestCase {
    private struct Fixture {
        var root: URL
        var window: NSWindow
        var pane: FilePaneController
        var session: BrowserSession
    }

    @MainActor
    private func makeFixture(names: [String], folders: [String] = []) async throws -> Fixture {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for name in names { try Data(name.utf8).write(to: root.appendingPathComponent(name)) }
        for name in folders {
            try FileManager.default.createDirectory(at: root.appendingPathComponent(name, isDirectory: true), withIntermediateDirectories: true)
        }
        let session = BrowserSession(url: root)
        session.includeHidden = true
        let pane = FilePaneController(session: session)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .resizable], backing: .buffered, defer: false
        )
        window.contentViewController = pane
        _ = pane.view
        window.contentView?.layoutSubtreeIfNeeded()
        let deadline = Date().addingTimeInterval(5)
        while !(!session.isLoading && session.entries.count == names.count + folders.count), Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(session.entries.count, names.count + folders.count)
        return Fixture(root: root, window: window, pane: pane, session: session)
    }

    @MainActor
    private func click(_ fixture: Fixture, row: Int, flags: NSEvent.ModifierFlags, type: NSEvent.EventType = .leftMouseDown) throws -> NSEvent {
        let table = fixture.pane.table
        let rect = table.rect(ofRow: row)
        let point = table.convert(NSPoint(x: rect.midX, y: rect.midY), to: nil)
        return try XCTUnwrap(NSEvent.mouseEvent(
            with: type, location: point, modifierFlags: flags, timestamp: 0,
            windowNumber: fixture.window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
        ))
    }

    @MainActor
    func testControlLeftClickDoesNotOpenContextMenu() async throws {
        let fixture = try await makeFixture(names: ["a.txt", "b.txt"])
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let table = fixture.pane.table
        XCTAssertNotNil(table.menu)
        XCTAssertNil(table.menu(for: try click(fixture, row: 0, flags: .control)))
    }

    @MainActor
    func testPlainLeftClickAndSecondaryClickKeepContextMenu() async throws {
        let fixture = try await makeFixture(names: ["a.txt", "b.txt"])
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let table = fixture.pane.table
        XCTAssertNotNil(table.menu(for: try click(fixture, row: 0, flags: [])))
        XCTAssertNotNil(table.menu(for: try click(fixture, row: 0, flags: [], type: .rightMouseDown)))
        XCTAssertNotNil(table.menu(for: try click(fixture, row: 0, flags: .control, type: .rightMouseDown)))
        XCTAssertNotNil(table.menu(for: try click(fixture, row: 0, flags: [.control, .command])))
    }

    @MainActor
    func testControlClickTogglesRowAndKeepsOtherSelection() async throws {
        let fixture = try await makeFixture(names: ["a.txt", "b.txt", "c.txt"])
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let table = fixture.pane.table
        table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)

        table.mouseDown(with: try click(fixture, row: 2, flags: .control))
        XCTAssertEqual(table.selectedRowIndexes, IndexSet([0, 2]))

        table.mouseDown(with: try click(fixture, row: 0, flags: .control))
        XCTAssertEqual(table.selectedRowIndexes, IndexSet(integer: 2))
    }

    @MainActor
    func testToggleSelectionIgnoresOutOfRangeRow() async throws {
        let fixture = try await makeFixture(names: ["a.txt"])
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let table = fixture.pane.table
        table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        table.toggleSelection(atRow: -1)
        table.toggleSelection(atRow: 5)
        XCTAssertEqual(table.selectedRowIndexes, IndexSet(integer: 0))
    }

    @MainActor
    func testRenameSelectsStemOfFileInRealFieldEditor() async throws {
        let fixture = try await makeFixture(names: ["photo.jpg"])
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        fixture.pane.table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        fixture.window.makeFirstResponder(fixture.pane.table)
        fixture.pane.beginRename()
        let editor = try XCTUnwrap(fixture.window.firstResponder as? NSTextView)
        XCTAssertEqual(editor.selectedRange(), NSRange(location: 0, length: 5))
        fixture.window.makeFirstResponder(nil)
    }

    @MainActor
    func testRenameSelectsWholeNameOfFolderAndDotfile() async throws {
        let fixture = try await makeFixture(names: [".bashrc"], folders: ["dir.d"])
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let entries = fixture.session.entries
        for (index, entry) in entries.enumerated() {
            fixture.pane.table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
            fixture.window.makeFirstResponder(fixture.pane.table)
            fixture.pane.beginRename()
            let editor = try XCTUnwrap(fixture.window.firstResponder as? NSTextView)
            XCTAssertEqual(editor.selectedRange(), NSRange(location: 0, length: (entry.name as NSString).length), entry.name)
            fixture.window.makeFirstResponder(nil)
        }
    }
}
