import AppKit
import XCTest
import IHateFinderCore
@testable import IHateFinder

final class PlacesAndActionsTests: XCTestCase {
    @MainActor
    func testOppositeMenuActionsCopyMoveAndRespectSelectionDualAndBusy() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let t = try makeTestBrowser(root: root)
        defer { t.browser.close() }
        try Data("copied content".utf8).write(to: t.left.appendingPathComponent("copy.txt"))
        try Data("moved content".utf8).write(to: t.left.appendingPathComponent("move.txt"))
        _ = t.browser.left.view
        _ = t.browser.right.view
        await awaitPaneLoad(t.browser.left) { t.browser.left.session.reload() }
        await awaitPaneLoad(t.browser.right) { t.browser.right.session.reload() }
        let pane = t.browser.left
        let menu = try XCTUnwrap(pane.table.menu)
        let copy = try menuItem(menu, #selector(BrowserWindowController.copyToOther))
        let move = try menuItem(menu, #selector(BrowserWindowController.moveToOther))
        let preview = try menuItem(menu, #selector(BrowserWindowController.previewSelection))
        pane.refreshMenu(menu)
        XCTAssertFalse(copy.isEnabled)
        XCTAssertFalse(preview.isEnabled)
        try select("copy.txt", in: pane)
        pane.refreshMenu(menu)
        XCTAssertFalse(copy.isEnabled)
        XCTAssertTrue(preview.isEnabled)
        t.browser.toggleDual()
        pane.refreshMenu(menu)
        XCTAssertTrue(copy.isEnabled)
        XCTAssertTrue(move.isEnabled)
        XCTAssertEqual(copy.toolTip, t.right.path)
        t.browser.busy = true
        pane.refreshMenu(menu)
        XCTAssertFalse(copy.isEnabled)
        XCTAssertFalse(move.isEnabled)
        t.browser.busy = false
        pane.refreshMenu(menu)
        XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(copy.action), to: t.browser, from: copy))
        try await t.browser.waitIdle()
        XCTAssertEqual(try Data(contentsOf: t.right.appendingPathComponent("copy.txt")), Data("copied content".utf8))
        XCTAssertTrue(FileManager.default.fileExists(atPath: t.left.appendingPathComponent("copy.txt").path))
        await awaitPaneLoad(pane) { pane.session.reload() }
        try select("move.txt", in: pane)
        pane.refreshMenu(menu)
        XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(move.action), to: t.browser, from: move))
        try await t.browser.waitIdle()
        XCTAssertEqual(try Data(contentsOf: t.right.appendingPathComponent("move.txt")), Data("moved content".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: t.left.appendingPathComponent("move.txt").path))
    }

    @MainActor
    func testFavoritesPersistOrderNavigateFocusedPaneAndRemoveOnlyShortcut() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let suite = "PlacesAndActionsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = FavoritePlacesStore(defaults: defaults)
        let t = try makeTestBrowser(root: root, favoriteStore: store)
        defer { t.browser.close() }
        _ = t.browser.left.view
        _ = t.browser.right.view
        await awaitPaneLoad(t.browser.left) { t.browser.left.session.reload() }
        await awaitPaneLoad(t.browser.right) { t.browser.right.session.reload() }
        let menu = try XCTUnwrap(t.browser.left.table.menu)
        let add = try menuItem(menu, #selector(BrowserWindowController.addCurrentFolderToFavorites))
        t.browser.left.refreshMenu(menu)
        XCTAssertTrue(add.isEnabled)
        XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(add.action), to: t.browser, from: add))
        t.browser.addCurrentFolderToFavorites()
        XCTAssertEqual(t.browser.favoritePlaces, [t.left])
        t.browser.left.refreshMenu(menu)
        XCTAssertFalse(add.isEnabled)
        t.browser.focus(t.browser.right)
        t.browser.addCurrentFolderToFavorites()
        XCTAssertEqual(t.browser.favoritePlaces, [t.left, t.right])
        let sidebarMenu = try XCTUnwrap(t.browser.sidebar.menu)
        t.browser.sidebar.selectRowIndexes(IndexSet(integer: 2), byExtendingSelection: false)
        t.browser.menuNeedsUpdate(sidebarMenu)
        let up = try menuItem(sidebarMenu, #selector(BrowserWindowController.moveFavoriteUp(_:)))
        XCTAssertTrue(up.isEnabled)
        XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(up.action), to: t.browser, from: up))
        XCTAssertEqual(store.load(), [t.right, t.left])
        let restored = try makeTestBrowser(root: root, favoriteStore: FavoritePlacesStore(defaults: try XCTUnwrap(UserDefaults(suiteName: suite))))
        defer { restored.browser.close() }
        XCTAssertEqual(restored.browser.favoritePlaces, [t.right, t.left])
        _ = restored.browser.right.view
        restored.browser.toggleDual()
        await awaitPaneLoad(restored.browser.left) { restored.browser.left.session.reload() }
        await awaitPaneLoad(restored.browser.right) { restored.browser.right.session.reload() }
        XCTAssertTrue(try XCTUnwrap(restored.browser.window).makeFirstResponder(restored.browser.right.table))
        await awaitPaneLoad(restored.browser.right, expectedURL: t.left) {
            restored.browser.sidebar.selectRowIndexes(IndexSet(integer: 2), byExtendingSelection: false)
            restored.browser.openPlace()
        }
        XCTAssertEqual(restored.browser.right.session.url, t.left)
        XCTAssertEqual(restored.browser.left.session.url, t.left)
        let restoredMenu = try XCTUnwrap(restored.browser.sidebar.menu)
        restored.browser.sidebar.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false)
        restored.browser.menuNeedsUpdate(restoredMenu)
        let open = try menuItem(restoredMenu, #selector(BrowserWindowController.openFavorite(_:)))
        XCTAssertTrue(open.isEnabled)
        XCTAssertEqual(open.representedObject as? URL, t.right)
        await awaitPaneLoad(restored.browser.right, expectedURL: t.right) {
            XCTAssertTrue(NSApp.sendAction(open.action!, to: restored.browser, from: open))
        }
        XCTAssertEqual(restored.browser.right.session.url, t.right)
        restored.browser.sidebar.selectRowIndexes(IndexSet(integer: 2), byExtendingSelection: false)
        restored.browser.menuNeedsUpdate(try XCTUnwrap(restored.browser.sidebar.menu))
        let remove = try menuItem(try XCTUnwrap(restored.browser.sidebar.menu), #selector(BrowserWindowController.removeFavorite(_:)))
        XCTAssertTrue(remove.isEnabled)
        XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(remove.action), to: restored.browser, from: remove))
        XCTAssertEqual(store.load(), [t.right])
        XCTAssertTrue(FileManager.default.fileExists(atPath: t.left.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: t.right.path))
        restored.browser.sidebar.selectRowIndexes(IndexSet(integer: 2), byExtendingSelection: false)
        restored.browser.menuNeedsUpdate(try XCTUnwrap(restored.browser.sidebar.menu))
        XCTAssertFalse(remove.isEnabled)
    }

    @MainActor
    func testWorkspaceVolumeNotificationsRefreshActualSidebarOnlyOnWorkspaceCenter() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let t = try makeTestBrowser(root: root)
        defer { t.browser.close() }
        let before = t.browser.placesRevision
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didMountNotification, object: NSWorkspace.shared)
        XCTAssertEqual(t.browser.placesRevision, before + 1)
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didUnmountNotification, object: NSWorkspace.shared)
        XCTAssertEqual(t.browser.placesRevision, before + 2)
        NotificationCenter.default.post(name: NSWorkspace.didMountNotification, object: NSWorkspace.shared)
        XCTAssertEqual(t.browser.placesRevision, before + 2)
        XCTAssertGreaterThan(t.browser.sidebar.numberOfRows, 0)
    }

    @MainActor
    private func menuItem(_ menu: NSMenu, _ action: Selector) throws -> NSMenuItem {
        try XCTUnwrap(menu.items.first { $0.action == action })
    }

    @MainActor
    private func select(_ name: String, in pane: FilePaneController) throws {
        let index = try XCTUnwrap(pane.session.entries.firstIndex { $0.name == name })
        pane.table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
