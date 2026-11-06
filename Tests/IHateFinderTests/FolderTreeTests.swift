import AppKit
import XCTest
@testable import IHateFinder

@MainActor
final class FolderTreeTests: XCTestCase {
    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FolderTreeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }

    private func folder(_ name: String, in parent: URL) throws -> URL {
        let url = parent.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeTree(
        _ roots: [FolderTreeRoot], includeHidden: Bool = false,
        loader: FolderTreeController.Loader? = nil
    ) -> (FolderTreeController, navigated: () -> [URL]) {
        _ = NSApplication.shared
        let tree = loader.map { FolderTreeController(includeHidden: includeHidden, loader: $0) }
            ?? FolderTreeController(includeHidden: includeHidden)
        var navigated: [URL] = []
        tree.onNavigate = { navigated.append($0) }
        tree.view.frame = NSRect(x: 0, y: 0, width: 240, height: 400)
        tree.setSections([FolderTreeSection(title: "위치", roots: roots)])
        return (tree, { navigated })
    }

    private func titles(_ tree: FolderTreeController) -> [String] {
        (0..<tree.outlineView.numberOfRows).map { (tree.outlineView.item(atRow: $0) as! FolderTreeNode).title }
    }

    private func node(_ tree: FolderTreeController, row: Int) -> FolderTreeNode {
        tree.outlineView.item(atRow: row) as! FolderTreeNode
    }

    /// Subscribes before `action`, then waits for `count` load replies and returns whether each applied.
    private func awaitLoads(_ tree: FolderTreeController, count: Int = 1, action: () -> Void) async -> [Bool] {
        let done = XCTestExpectation(description: "Folder loads finished")
        done.expectedFulfillmentCount = count
        var outcomes: [Bool] = []
        tree.onLoadFinished = { _, applied in
            outcomes.append(applied)
            done.fulfill()
        }
        action()
        let result = await XCTWaiter.fulfillment(of: [done], timeout: 5)
        XCTAssertEqual(result, .completed)
        tree.onLoadFinished = nil
        return outcomes
    }

    private func expandRoot(_ tree: FolderTreeController, row: Int = 1) async {
        _ = await awaitLoads(tree) { tree.outlineView.expandItem(node(tree, row: row)) }
    }

    func testExpansionIsLazyAndDoesNotNavigate() async throws {
        let root = try makeRoot()
        _ = try folder("b", in: root)
        var loads = 0
        let (tree, navigated) = makeTree(
            [FolderTreeRoot(title: "Root", url: root, symbol: "folder")],
            loader: { url, hidden in
                DispatchQueue.main.sync { loads += 1 }
                return try FolderTreeController.listFolders(url, includeHidden: hidden)
            }
        )
        XCTAssertEqual(titles(tree), ["위치", "Root"])
        XCTAssertEqual(loads, 0)
        await expandRoot(tree)
        XCTAssertEqual(loads, 1)
        XCTAssertEqual(titles(tree), ["위치", "Root", "b"])
        XCTAssertTrue(navigated().isEmpty)
        tree.syncHighlight(to: root.appendingPathComponent("b"))
        XCTAssertEqual(tree.outlineView.selectedRow, 2)
        XCTAssertTrue(navigated().isEmpty)
    }

    func testFoldersOnlyNaturalOrderAndHidden() async throws {
        let root = try makeRoot()
        for name in ["item10", "item2", "Item1", ".secret", "Tool.app"] { _ = try folder(name, in: root) }
        try Data().write(to: root.appendingPathComponent("file.txt"))
        let (tree, _) = makeTree([FolderTreeRoot(title: "Root", url: root, symbol: "folder")])
        await expandRoot(tree)
        XCTAssertEqual(titles(tree), ["위치", "Root", "Item1", "item2", "item10"])

        _ = await awaitLoads(tree) { tree.setIncludeHidden(true) }
        XCTAssertEqual(titles(tree), ["위치", "Root", ".secret", "Item1", "item2", "item10"])
    }

    func testCollapsedTreeUsesNewHiddenSettingAndEmptyFolderCanGainChildren() async throws {
        let root = try makeRoot()
        let (tree, _) = makeTree([FolderTreeRoot(title: "Root", url: root, symbol: "folder")])
        await expandRoot(tree)
        XCTAssertEqual(titles(tree), ["위치", "Root"])
        _ = try folder("new", in: root)
        _ = await awaitLoads(tree) { tree.refresh() }
        XCTAssertEqual(titles(tree), ["위치", "Root", "new"])
        tree.outlineView.collapseItem(node(tree, row: 1))
        _ = try folder(".secret", in: root)
        tree.setIncludeHidden(true)
        await expandRoot(tree)
        XCTAssertEqual(titles(tree), ["위치", "Root", ".secret", "new"])
    }

    func testPackagesAreNotListedAndSymlinksStayLeaves() throws {
        let root = try makeRoot()
        let real = try folder("real", in: root)
        let package = try folder("Tool.app", in: root)
        // A directory is a package when LaunchServices says so; a bundle extension with Info.plist qualifies.
        try Data("<plist version=\"1.0\"><dict/></plist>".utf8).write(to: package.appendingPathComponent("Info.plist"))
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("loop"), withDestinationURL: root)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("link"), withDestinationURL: real)
        let entries = try FolderTreeController.listFolders(root, includeHidden: false)
        let byName = Dictionary(uniqueKeysWithValues: entries.map { ($0.url.lastPathComponent, $0) })
        XCTAssertEqual(byName["real"]?.isExpandable, true)
        XCTAssertEqual(byName["link"]?.isExpandable, false)
        XCTAssertEqual(byName["loop"]?.isExpandable, false)
        XCTAssertNil(byName["Tool.app"])
    }

    func testErrorIsVisibleAndRefreshRetries() async throws {
        let root = try makeRoot()
        let missing = root.appendingPathComponent("gone")
        let (tree, _) = makeTree([FolderTreeRoot(title: "Gone", url: missing, symbol: "folder")])
        await expandRoot(tree)
        let rows = titles(tree)
        XCTAssertEqual(rows.count, 3)
        XCTAssertTrue(rows[2].hasPrefix(missing.path + ":"), rows[2])
        XCTAssertEqual(node(tree, row: 2).kind, .error)

        _ = try folder("gone", in: root)
        _ = try folder("child", in: missing)
        _ = await awaitLoads(tree) { tree.refresh() }
        XCTAssertEqual(titles(tree), ["위치", "Gone", "child"])
    }

    func testStaleReplyAfterRefreshIsDropped() async throws {
        let root = try makeRoot()
        let gate = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var calls = 0
        let started = XCTestExpectation(description: "Original request started")
        defer { gate.signal() }
        let (tree, _) = makeTree(
            [FolderTreeRoot(title: "Root", url: root, symbol: "folder")],
            loader: { url, _ in
                lock.lock(); calls += 1; let call = calls; lock.unlock()
                if call == 1 {
                    started.fulfill()
                    gate.wait()
                    return [FolderTreeEntry(url: url.appendingPathComponent("old"), isExpandable: true)]
                }
                return [FolderTreeEntry(url: url.appendingPathComponent("new"), isExpandable: true)]
            }
        )
        var outcomes: [Bool] = []
        let fresh = XCTestExpectation(description: "Refresh applied")
        tree.onLoadFinished = { _, applied in
            outcomes.append(applied)
            if applied { fresh.fulfill() }
        }
        tree.outlineView.expandItem(node(tree, row: 1))
        await fulfillment(of: [started], timeout: 5)
        tree.refresh()
        await fulfillment(of: [fresh], timeout: 5)
        XCTAssertEqual(titles(tree), ["위치", "Root", "new"])

        let dropped = XCTestExpectation(description: "Stale reply dropped")
        tree.onLoadFinished = { _, applied in
            outcomes.append(applied)
            dropped.fulfill()
        }
        gate.signal()
        await fulfillment(of: [dropped], timeout: 5)
        XCTAssertEqual(outcomes, [true, false])
        XCTAssertEqual(titles(tree), ["위치", "Root", "new"])
    }

    func testStaleReplyAfterRootReplacementIsDropped() async throws {
        let root = try makeRoot()
        let other = try folder("other", in: root)
        _ = try folder("inside", in: other)
        let gate = DispatchSemaphore(value: 0)
        let (tree, navigated) = makeTree(
            [FolderTreeRoot(title: "Root", url: root, symbol: "folder")],
            loader: { url, hidden in
                if url == root { gate.wait() }
                return try FolderTreeController.listFolders(url, includeHidden: hidden)
            }
        )
        tree.outlineView.expandItem(node(tree, row: 1))
        tree.setSections([FolderTreeSection(title: "위치", roots: [FolderTreeRoot(title: "Other", url: other, symbol: "folder")])])
        let outcomes = await awaitLoads(tree) { gate.signal() }
        XCTAssertEqual(outcomes, [false])
        XCTAssertEqual(titles(tree), ["위치", "Other"])
        XCTAssertTrue(navigated().isEmpty)
    }

    func testHiddenSettingChangeDropsOlderReply() async throws {
        let root = try makeRoot()
        _ = try folder("shown", in: root)
        _ = try folder(".dot", in: root)
        let gate = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var calls = 0
        let started = XCTestExpectation(description: "Original hidden request started")
        defer { gate.signal() }
        let (tree, _) = makeTree(
            [FolderTreeRoot(title: "Root", url: root, symbol: "folder")],
            loader: { url, hidden in
                lock.lock(); calls += 1; let call = calls; lock.unlock()
                if call == 1 { started.fulfill(); gate.wait() }
                return try FolderTreeController.listFolders(url, includeHidden: hidden)
            }
        )
        tree.outlineView.expandItem(node(tree, row: 1))
        await fulfillment(of: [started], timeout: 5)
        let applied = await awaitLoads(tree) { tree.setIncludeHidden(true) }
        XCTAssertEqual(applied, [true])
        XCTAssertEqual(titles(tree), ["위치", "Root", ".dot", "shown"])
        let stale = await awaitLoads(tree) { gate.signal() }
        XCTAssertEqual(stale, [false])
        XCTAssertEqual(titles(tree), ["위치", "Root", ".dot", "shown"])
    }

    func testExpansionSurvivesRootReplacementAndRefresh() async throws {
        let root = try makeRoot()
        let child = try folder("child", in: root)
        _ = try folder("grand", in: child)
        let favorite = FolderTreeRoot(title: "Root", url: root, symbol: "folder", isFavorite: true)
        let (tree, _) = makeTree([favorite])
        await expandRoot(tree)
        await expandRoot(tree, row: 2)
        XCTAssertEqual(titles(tree), ["위치", "Root", "child", "grand"])

        // Replacement re-expands the same path; loads cascade one level at a time.
        _ = await awaitLoads(tree, count: 2) {
            tree.setSections([FolderTreeSection(title: "위치", roots: [favorite])])
        }
        XCTAssertEqual(titles(tree), ["위치", "Root", "child", "grand"])
        _ = await awaitLoads(tree, count: 2) { tree.refresh() }
        XCTAssertEqual(titles(tree), ["위치", "Root", "child", "grand"])
    }

    func testClickNavigatesAndFavoriteIdentity() async throws {
        let root = try makeRoot()
        let favoriteURL = try folder("fav", in: root)
        let plain = try folder("plain", in: root)
        let (tree, navigated) = makeTree([
            FolderTreeRoot(title: "fav", url: favoriteURL, symbol: "folder", isFavorite: true),
            FolderTreeRoot(title: "plain", url: plain, symbol: "folder"),
        ])
        XCTAssertEqual(titles(tree), ["위치", "fav", "plain"])
        XCTAssertFalse(node(tree, row: 0).isFolder)
        XCTAssertTrue(node(tree, row: 1).isFavorite)

        tree.outlineView.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false)
        XCTAssertEqual(tree.contextFavoriteURL, favoriteURL)
        XCTAssertEqual(tree.contextFolderURL, favoriteURL)
        tree.outlineView.selectRowIndexes(IndexSet(integer: 2), byExtendingSelection: false)
        XCTAssertNil(tree.contextFavoriteURL)
        XCTAssertEqual(tree.contextFolderURL, plain)

        tree.syncHighlight(to: favoriteURL)
        XCTAssertEqual(tree.outlineView.selectedRow, 1)
        tree.syncHighlight(to: root)
        XCTAssertEqual(tree.outlineView.selectedRow, -1)
        XCTAssertTrue(navigated().isEmpty)

        tree.activate(row: 0)
        XCTAssertTrue(navigated().isEmpty)
        tree.activate(row: 2)
        XCTAssertEqual(navigated(), [plain])
    }
}
