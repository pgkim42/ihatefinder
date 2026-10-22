import AppKit
import XCTest
import IHateFinderCore
@testable import IHateFinder

final class PaneFeatureTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("pane-features-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }

    @MainActor
    private func pane() async -> (FilePaneController, NSWindow) {
        _ = NSApplication.shared
        let pane = FilePaneController(session: BrowserSession(url: root))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 740, height: 440),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentViewController = pane
        _ = pane.view
        window.setContentSize(NSSize(width: 740, height: 440))
        pane.view.layoutSubtreeIfNeeded()
        await awaitPaneLoad(pane) { pane.session.reload() }
        return (pane, window)
    }

    private func directory(_ path: String) throws -> URL {
        let url = root.appendingPathComponent(path, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func file(_ path: String) throws -> URL {
        let url = root.appendingPathComponent(path)
        try Data(path.utf8).write(to: url)
        return url
    }

    @MainActor
    private func filter(_ text: String, in pane: FilePaneController) {
        pane.showFilter()
        pane.filterField.stringValue = text
        pane.filterField.sendAction(pane.filterField.action, to: pane.filterField.target)
        pane.view.layoutSubtreeIfNeeded()
    }

    @MainActor
    private func search(_ text: String, in pane: FilePaneController) async {
        let done = expectation(description: "Recursive query completed")
        pane.onSearchChange = { if !pane.searchIsRunning { done.fulfill() } }
        pane.recursiveSearchField.stringValue = text
        pane.recursiveSearchChanged()
        await fulfillment(of: [done], timeout: 5)
        pane.onSearchChange = nil
    }

    @MainActor
    func testExternalNavigationBackForwardRestoreSelectionScrollAndFilterAndUpRevealsOrigin() async throws {
        let child = try directory("child")
        for index in 0..<80 { _ = try file(String(format: "item-%02d.txt", index)) }
        let childFile = try file("child/inside.txt")
        let (pane, window) = await pane()
        defer { window.close() }
        filter("item", in: pane)
        pane.table.selectRowIndexes(IndexSet([40, 41]), byExtendingSelection: false)
        pane.table.scrollRowToVisible(55)
        let clip = try XCTUnwrap(pane.table.enclosingScrollView?.contentView)
        let offset = clip.bounds.origin.y
        XCTAssertGreaterThan(offset, 0)
        let survivor = root.appendingPathComponent("item-40.txt")
        await awaitPaneLoad(pane, expectedURL: child) { pane.session.navigate(to: child) }
        XCTAssertFalse(pane.filterIsVisible)
        filter("inside", in: pane)
        pane.table.selectAll(nil)
        try FileManager.default.removeItem(at: root.appendingPathComponent("item-41.txt"))

        await awaitPaneLoad(pane, expectedURL: root) { pane.goBack() }
        XCTAssertEqual(pane.selectedURLs(), [survivor])
        XCTAssertTrue(pane.filterIsVisible)
        XCTAssertEqual(pane.filterField.stringValue, "item")
        XCTAssertEqual(clip.bounds.origin.y, offset, accuracy: 1)

        await awaitPaneLoad(pane, expectedURL: child) { pane.goForward() }
        XCTAssertEqual(pane.selectedURLs(), [childFile])
        XCTAssertEqual(pane.filterField.stringValue, "inside")
        XCTAssertTrue(pane.filterIsVisible)
        await awaitPaneLoad(pane, expectedURL: root) { pane.goUp() }
        XCTAssertEqual(pane.selectedURLs(), [child])
        XCTAssertFalse(pane.filterIsActive)
        XCTAssertNil(pane.pendingReveal)
    }

    @MainActor
    func testNewDirectoryShowsItsFirstRowBelowTheHeader() async throws {
        let child = try directory("child")
        for index in 0..<80 { _ = try file(String(format: "child/item-%02d.txt", index)) }
        let (pane, window) = await pane()
        defer { window.close() }
        await awaitPaneLoad(pane, expectedURL: child) { pane.session.navigate(to: child) }
        pane.view.layoutSubtreeIfNeeded()
        let firstRow = pane.table.rect(ofRow: 0)
        let clip = try XCTUnwrap(pane.table.enclosingScrollView?.contentView)
        let viewport = pane.table.convert(clip.bounds, from: clip)
        XCTAssertGreaterThan(viewport.height, 0)
        XCTAssertLessThanOrEqual(viewport.minY, firstRow.minY)
        XCTAssertGreaterThanOrEqual(viewport.maxY, firstRow.maxY)
    }

    @MainActor
    func testDirectoryCompletionUsesFilesystemAndKeyboardWithoutNavigatingOnTab() async throws {
        let alpha = try directory("alpha")
        let alpine = try directory("alpine")
        _ = try directory("other")
        _ = try file("alphabet.txt")
        let (pane, window) = await pane()
        defer { window.close() }
        let ready = expectation(description: "Directory candidates arrived")
        pane.onCompletionChange = { ready.fulfill() }
        pane.pathField.stringValue = root.appendingPathComponent("al").path
        pane.updatePathCompletions()
        await fulfillment(of: [ready], timeout: 5)
        pane.onCompletionChange = nil
        XCTAssertEqual(pane.completionCandidates.map(\.standardizedFileURL), [alpha, alpine])
        XCTAssertFalse(try XCTUnwrap(pane.completionTable.enclosingScrollView).isHidden)
        let editor = NSTextView()
        XCTAssertTrue(pane.control(pane.pathField, textView: editor, doCommandBy: #selector(NSResponder.moveDown(_:))))
        XCTAssertEqual(pane.completionTable.selectedRow, 0)
        XCTAssertTrue(pane.control(pane.pathField, textView: editor, doCommandBy: #selector(NSResponder.moveDown(_:))))
        XCTAssertEqual(pane.completionTable.selectedRow, 1)
        XCTAssertTrue(pane.control(pane.pathField, textView: editor, doCommandBy: #selector(NSResponder.moveUp(_:))))
        XCTAssertTrue(pane.control(pane.pathField, textView: editor, doCommandBy: #selector(NSResponder.insertTab(_:))))
        XCTAssertEqual(pane.pathField.stringValue, alpha.path + "/")
        XCTAssertEqual(pane.session.url, root)
        XCTAssertTrue(pane.completionCandidates.isEmpty)
        await awaitPaneLoad(pane, expectedURL: alpha) {
            XCTAssertTrue(pane.control(pane.pathField, textView: editor, doCommandBy: #selector(NSResponder.insertNewline(_:))))
        }
    }

    @MainActor
    func testReturnUsesTypedDirectoryUnlessACandidateWasExplicitlySelected() async throws {
        let child = try directory("child")
        let (pane, window) = await pane()
        defer { window.close() }
        let ready = expectation(description: "Typed directory candidates arrived")
        pane.onCompletionChange = { ready.fulfill() }
        pane.pathField.stringValue = root.path + "/"
        pane.updatePathCompletions()
        await fulfillment(of: [ready], timeout: 5)
        pane.onCompletionChange = nil
        XCTAssertEqual(pane.completionCandidates, [child])
        XCTAssertEqual(pane.completionTable.selectedRow, -1)
        await awaitPaneLoad(pane, expectedURL: root) {
            XCTAssertTrue(pane.control(pane.pathField, textView: NSTextView(), doCommandBy: #selector(NSResponder.insertNewline(_:))))
        }
        XCTAssertEqual(pane.session.url, root, "Return must not silently enter the first child of a typed directory")

        let next = expectation(description: "Candidate for explicit selection arrived")
        pane.onCompletionChange = { next.fulfill() }
        pane.pathField.stringValue = root.appendingPathComponent("chi").path
        pane.updatePathCompletions()
        await fulfillment(of: [next], timeout: 5)
        pane.onCompletionChange = nil
        XCTAssertTrue(pane.control(pane.pathField, textView: NSTextView(), doCommandBy: #selector(NSResponder.moveDown(_:))))
        await awaitPaneLoad(pane, expectedURL: child) {
            XCTAssertTrue(pane.control(pane.pathField, textView: NSTextView(), doCommandBy: #selector(NSResponder.insertNewline(_:))))
        }
    }

    @MainActor
    func testCompletionExpandsTildeAndEscapeRejectsLateCandidates() async throws {
        let folder = try directory("tilde-folder")
        let (pane, window) = await pane()
        defer { window.close() }
        let homeDepth = FileManager.default.homeDirectoryForCurrentUser.pathComponents.count - 1
        let typed = "~/" + String(repeating: "../", count: homeDepth) + String(root.path.dropFirst()) + "/tilde"
        let ready = expectation(description: "Tilde completion finished")
        pane.onCompletionChange = { ready.fulfill() }
        pane.pathField.stringValue = typed
        pane.updatePathCompletions()
        await fulfillment(of: [ready], timeout: 5)
        pane.onCompletionChange = nil
        XCTAssertEqual(pane.completionCandidates.map(\.standardizedFileURL), [folder])
        XCTAssertTrue(pane.control(pane.pathField, textView: NSTextView(), doCommandBy: #selector(NSResponder.cancelOperation(_:))))
        XCTAssertTrue(pane.completionCandidates.isEmpty)

        var completions: [(Result<[URL], Error>) -> Void] = []
        var cancelled = 0
        pane.completeDirectories = { _, _, _, completion in
            completions.append(completion)
            return { cancelled += 1 }
        }
        pane.pathField.stringValue = "old"
        pane.updatePathCompletions()
        pane.pathField.stringValue = "new"
        pane.updatePathCompletions()
        completions[1](.success([folder]))
        completions[0](.success([self.root]))
        XCTAssertEqual(pane.completionCandidates, [folder])
        XCTAssertGreaterThanOrEqual(cancelled, 1)
        pane.pathField.stringValue = "pending"
        pane.updatePathCompletions()
        _ = pane.control(pane.pathField, textView: NSTextView(), doCommandBy: #selector(NSResponder.cancelOperation(_:)))
        completions[2](.success([folder]))
        XCTAssertTrue(pane.completionCandidates.isEmpty)
    }

    @MainActor
    func testRecursiveSearchIncludesDescendantsHonorsHiddenAndDoesNotFollowSymlinks() async throws {
        _ = try directory("sub/deep")
        _ = try directory(".hidden-dir")
        let direct = try file("match-root.txt")
        let nested = try file("sub/deep/match-nested.txt")
        let hidden = try file(".match-hidden.txt")
        let hiddenChild = try file(".hidden-dir/match-secret.txt")
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("loop"), withDestinationURL: root)
        let (pane, window) = await pane()
        defer { window.close() }
        pane.showRecursiveSearch()
        await search("match", in: pane)
        pane.table.selectAll(nil)
        XCTAssertEqual(Set(pane.selectedURLs()), Set([direct, nested]))
        let location = try XCTUnwrap(pane.table.tableColumn(withIdentifier: .init("location")))
        let rendered = try XCTUnwrap(pane.tableView(pane.table, viewFor: location, row: 0) as? NSTableCellView)
        XCTAssertFalse(rendered.textField?.stringValue.isEmpty ?? true)
        pane.session.includeHidden = true
        await search("match", in: pane)
        pane.table.selectAll(nil)
        XCTAssertEqual(Set(pane.selectedURLs()), Set([direct, nested, hidden, hiddenChild]))
        pane.showFilter()
        XCTAssertFalse(pane.recursiveSearchVisible)
        XCTAssertNil(pane.table.tableColumn(withIdentifier: .init("location")))
        filter("nested", in: pane)
        XCTAssertEqual(pane.table.numberOfRows, 0, "The ordinary filter must not search descendants")
    }

    @MainActor
    func testRecursiveResultsOpenOriginalURLAndRevealItsFolder() async throws {
        let sub = try directory("sub")
        let nested = try file("sub/needle.txt")
        let (pane, window) = await pane()
        defer { window.close() }
        pane.showRecursiveSearch()
        await search("needle", in: pane)
        pane.table.selectAll(nil)
        var opened: [URL] = []
        var terminal: URL?
        pane.openFiles = { urls, done in opened = urls; done(.success(())) }
        pane.openInTerminal = { url, done in terminal = url; done(.success(())) }
        pane.openSelection()
        pane.openInTerminalAction()
        XCTAssertEqual(opened, [nested])
        XCTAssertEqual(terminal, sub)
        let menu = try XCTUnwrap(pane.table.menu)
        pane.refreshMenu(menu)
        let reveal = try XCTUnwrap(menu.items.first { $0.action == #selector(FilePaneController.revealOriginalFolder) })
        XCTAssertTrue(reveal.isEnabled)
        XCTAssertFalse(reveal.isHidden)
        await awaitPaneLoad(pane, expectedURL: sub) { pane.revealOriginalFolder() }
        XCTAssertEqual(pane.selectedURLs(), [nested])
        XCTAssertFalse(pane.recursiveSearchVisible)
    }

    @MainActor
    func testRecursiveQueryGenerationAndEscapeCancelStaleResults() async throws {
        let first = try file("first.txt")
        let second = try file("second.txt")
        let (pane, window) = await pane()
        defer { window.close() }
        var callbacks: [(Result<[FileEntry], Error>) -> Void] = []
        var cancellations = 0
        pane.searchFiles = { _, _, _, done in callbacks.append(done); return { cancellations += 1 } }
        pane.showRecursiveSearch()
        pane.recursiveSearchField.stringValue = "first"
        pane.recursiveSearchChanged()
        pane.recursiveSearchField.stringValue = "second"
        pane.recursiveSearchChanged()
        let secondEntry = try XCTUnwrap(pane.session.entries.first { $0.url == second })
        let firstEntry = try XCTUnwrap(pane.session.entries.first { $0.url == first })
        let sorted = expectation(description: "Search result sorted on worker")
        pane.onSearchChange = { if !pane.searchIsRunning { sorted.fulfill() } }
        callbacks[1](.success([secondEntry]))
        await fulfillment(of: [sorted], timeout: 5)
        pane.onSearchChange = nil
        callbacks[0](.success([firstEntry]))
        pane.table.selectAll(nil)
        XCTAssertEqual(pane.selectedURLs(), [second])
        XCTAssertEqual(cancellations, 1)
        pane.recursiveSearchField.stringValue = "again"
        pane.recursiveSearchChanged()
        XCTAssertTrue(pane.clearRecursiveSearch())
        callbacks[2](.success([secondEntry]))
        XCTAssertFalse(pane.recursiveSearchVisible)
        XCTAssertEqual(pane.table.numberOfRows, 2)
        XCTAssertFalse(pane.searchIsRunning)
        XCTAssertEqual(cancellations, 2)
    }

    @MainActor
    func testClosingPaneCancelsBothQueriesAndRejectsTheirLateCompletions() async throws {
        let folder = try directory("folder")
        _ = try file("file.txt")
        let (pane, window) = await pane()
        defer { window.close() }
        var completionResult: ((Result<[URL], Error>) -> Void)?
        var searchResult: ((Result<[FileEntry], Error>) -> Void)?
        var cancelled = 0
        pane.completeDirectories = { _, _, _, done in completionResult = done; return { cancelled += 1 } }
        pane.searchFiles = { _, _, _, done in searchResult = done; return { cancelled += 1 } }
        pane.pathField.stringValue = "folder"
        pane.updatePathCompletions()
        pane.showRecursiveSearch()
        pane.recursiveSearchField.stringValue = "file"
        pane.recursiveSearchChanged()
        pane.cancelBackgroundWork()
        XCTAssertEqual(cancelled, 2)
        completionResult?(.success([folder]))
        searchResult?(.success(pane.session.entries))
        XCTAssertTrue(pane.completionCandidates.isEmpty)
        XCTAssertFalse(pane.recursiveSearchVisible)
        XCTAssertFalse(pane.searchIsRunning)
    }

    @MainActor
    func testLaunchFailuresAreReportedForEveryActionAndSuccessDoesNotAlert() async throws {
        let url = try file("open.txt")
        let (pane, window) = await pane()
        defer { window.close() }
        pane.table.selectAll(nil)
        let failure = FileOpError("launch failure")
        var alerts: [String] = []
        var outcomes = 0
        pane.presentLaunchError = { alerts.append($0) }
        pane.onLaunchOutcome = { _ in outcomes += 1 }
        pane.openFiles = { _, done in done(.failure(failure)) }
        pane.openWithApp = { _, _, done in done(.failure(failure)) }
        pane.openInTerminal = { _, done in done(.failure(failure)) }
        pane.openSelection()
        let item = NSMenuItem()
        item.representedObject = URL(fileURLWithPath: "/missing.app")
        pane.openWithChosen(item)
        pane.openInTerminalAction()
        XCTAssertEqual(alerts.count, 3)
        XCTAssertTrue(alerts[0].contains(url.path))
        XCTAssertEqual(outcomes, 3)
        pane.openFiles = { _, done in done(.success(())) }
        pane.openSelection()
        XCTAssertEqual(alerts.count, 3)
        XCTAssertEqual(outcomes, 4)
    }

    @MainActor
    func testThumbnailModeKeepsDetailsAndRejectsReusedCellAndRefreshedListingCallbacks() async throws {
        let original = try file("a.png")
        let other = try file("b.pdf")
        let (pane, window) = await pane()
        defer { window.close() }
        var callbacks: [URL: (NSImage?) -> Void] = [:]
        pane.thumbnails.generate = { url, done in callbacks[url] = done; return {} }
        pane.toggleThumbnails()
        XCTAssertEqual(pane.table.rowHeight, 88)
        XCTAssertEqual(pane.table.tableColumns.count, 4)
        let column = try XCTUnwrap(pane.table.tableColumns.first)
        let cell = try XCTUnwrap(pane.tableView(pane.table, viewFor: column, row: 0) as? PaneNameCell)
        let oldImage = cell.imageView?.image
        let oldCallback = try XCTUnwrap(callbacks[original])
        cell.representedURL = other
        let generated = NSImage(size: NSSize(width: 10, height: 10))
        oldCallback(generated)
        XCTAssertTrue(cell.imageView?.image === oldImage)
        await awaitPaneLoad(pane) { pane.session.reload() }
        let refreshed = try XCTUnwrap(pane.tableView(pane.table, viewFor: column, row: 0) as? PaneNameCell)
        let refreshedIcon = refreshed.imageView?.image
        oldCallback(generated)
        XCTAssertTrue(refreshed.imageView?.image === refreshedIcon)
        let currentCallback = try XCTUnwrap(callbacks[original])
        currentCallback(generated)
        XCTAssertTrue(refreshed.imageView?.image === generated)
        pane.table.selectAll(nil)
        XCTAssertEqual(pane.numberOfPreviewItems(in: nil), 2)
        pane.toggleThumbnails()
        XCTAssertEqual(pane.table.rowHeight, 32)
        XCTAssertFalse(pane.thumbnailsEnabled)
    }
}
