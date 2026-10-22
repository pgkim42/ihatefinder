import AppKit
import XCTest
@testable import IHateFinderCore
@testable import IHateFinder

final class SearchStateTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("search-state-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }

    private func folder(_ name: String) throws -> URL {
        let url = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func files(in folder: URL, count: Int = 80) throws -> [URL] {
        try (0..<count).map { index in
            let url = folder.appendingPathComponent(String(format: "needle-item-%02d.txt", index))
            try Data(repeating: UInt8(index), count: index + 1).write(to: url)
            return url
        }
    }

    @MainActor
    private func pane() async -> (FilePaneController, NSWindow) {
        _ = NSApplication.shared
        let session = BrowserSession(url: root, listing: nil, observesChanges: false)
        let pane = FilePaneController(session: session)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 740, height: 440),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentViewController = pane
        _ = pane.view
        window.setContentSize(NSSize(width: 740, height: 440))
        pane.view.layoutSubtreeIfNeeded()
        await awaitPaneLoad(pane) { session.reload() }
        return (pane, window)
    }

    @MainActor
    private func completedSearch(_ pane: FilePaneController, action: () -> Void) async {
        let done = expectation(description: "Search completes")
        var fulfilled = false
        pane.onSearchChange = {
            if !pane.searchIsRunning && !fulfilled { fulfilled = true; done.fulfill() }
        }
        action()
        await fulfillment(of: [done], timeout: 5)
        pane.onSearchChange = nil
    }

    @MainActor
    private func search(_ text: String, in pane: FilePaneController) async {
        if !pane.recursiveSearchVisible { pane.showRecursiveSearch() }
        await completedSearch(pane) {
            pane.recursiveSearchField.stringValue = text
            pane.recursiveSearchChanged()
        }
    }

    @MainActor
    private func assertFirstRowsFullyVisible(_ pane: FilePaneController, count: Int,
                                            file: StaticString = #filePath, line: UInt = #line) throws {
        pane.view.layoutSubtreeIfNeeded()
        let scroll = try XCTUnwrap(pane.table.enclosingScrollView)
        let clip = scroll.contentView
        let header = try XCTUnwrap(pane.table.headerView)
        let viewport = pane.table.convert(clip.bounds, from: clip)
        let headerRect = pane.table.convert(header.bounds, from: header)
        let exposedTop = max(viewport.minY, headerRect.maxY)
        let geometry = "clip=\(clip.bounds), document=\(clip.documentRect), clipInsets=\(clip.contentInsets), scrollInsets=\(scroll.contentInsets), header=\(headerRect)"
        for row in 0..<count {
            let rect = pane.table.rect(ofRow: row)
            XCTAssertGreaterThanOrEqual(rect.minY, exposedTop, geometry, file: file, line: line)
            XCTAssertLessThanOrEqual(rect.maxY, viewport.maxY, geometry, file: file, line: line)
        }
        XCTAssertEqual(clip.bounds.minY, clip.constrainBoundsRect(clip.bounds).minY,
                       accuracy: 0.5, geometry, file: file, line: line)
    }

    @MainActor
    func testNewQueryStartsAboveFirstRowEvenWhenResultsFillViewport() async throws {
        _ = try files(in: root)
        let (pane, window) = await pane()
        defer { pane.cancelBackgroundWork(); window.close() }
        pane.table.scrollRowToVisible(60)
        await search("needle", in: pane)
        try assertFirstRowsFullyVisible(pane, count: 2)
    }

    @MainActor
    func testShortSearchResultsStayBelowHeaderAcrossRevealBackSortAndPartialReload() async throws {
        let child = try folder("child")
        let urls = try files(in: child, count: 2)
        let (pane, window) = await pane()
        defer { pane.cancelBackgroundWork(); window.close() }
        await search("needle", in: pane)
        try assertFirstRowsFullyVisible(pane, count: 2)
        pane.table.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false)
        await awaitPaneLoad(pane, expectedURL: child) { pane.revealOriginalFolder() }
        await completedSearch(pane) { pane.goBack() }
        XCTAssertEqual(pane.selectedURLs(), [urls[1]])
        try assertFirstRowsFullyVisible(pane, count: 2)
        await completedSearch(pane) {
            pane.table.sortDescriptors = [NSSortDescriptor(key: SortColumn.size.rawValue, ascending: false)]
        }
        XCTAssertEqual(pane.selectedURLs(), [urls[1]])
        try assertFirstRowsFullyVisible(pane, count: 2)
        let restricted = try folder("restricted")
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: restricted.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: restricted.path) }
        await completedSearch(pane) { pane.session.reload() }
        XCTAssertEqual(pane.table.numberOfRows, 2)
        XCTAssertEqual(pane.selectedURLs(), [urls[1]])
        XCTAssertTrue(pane.summary().contains("부분 검색"))
        try assertFirstRowsFullyVisible(pane, count: 2)
    }

    @MainActor
    func testReloadClampsSavedScrollWhenResultListShrinks() async throws {
        let urls = try files(in: root)
        let (pane, window) = await pane()
        defer { pane.cancelBackgroundWork(); window.close() }
        let entries = pane.session.entries
        var results = entries
        pane.searchFiles = { _, _, _, done in done(.success(results)); return {} }
        await search("needle", in: pane)
        pane.table.selectRowIndexes(IndexSet(integer: 79), byExtendingSelection: false)
        pane.table.scrollRowToVisible(79)
        let clip = try XCTUnwrap(pane.table.enclosingScrollView?.contentView)
        XCTAssertGreaterThan(clip.bounds.minY, 1000)
        // A smaller result still exceeds the viewport: retain the offset up to the new bottom.
        results = Array(entries.suffix(20))
        await completedSearch(pane) { pane.session.reload() }
        XCTAssertEqual(pane.selectedURLs(), [urls[79]])
        var bottom = clip.bounds
        bottom.origin.y = pane.table.bounds.maxY
        XCTAssertEqual(clip.bounds.minY, clip.constrainBoundsRect(bottom).minY, accuracy: 0.5)
        XCTAssertGreaterThan(clip.bounds.minY, 0)
        // Once all results fit, the only valid position leaves both rows below the header.
        results = Array(entries.suffix(2))
        await completedSearch(pane) { pane.session.reload() }
        XCTAssertEqual(pane.selectedURLs(), [urls[79]])
        XCTAssertEqual(pane.table.numberOfRows, 2)
        try assertFirstRowsFullyVisible(pane, count: 2)
    }

    @MainActor
    func testBackAndForwardRestoreIndependentSearchScopesQueriesSelectionAndScroll() async throws {
        let child = try folder("child")
        let urls = try files(in: child)
        let hidden = child.appendingPathComponent(".needle-item-hidden.txt")
        try Data().write(to: hidden)
        let (pane, window) = await pane()
        defer { pane.cancelBackgroundWork(); window.close() }
        pane.session.includeHidden = true
        await search("needle", in: pane)
        let clip = try XCTUnwrap(pane.table.enclosingScrollView?.contentView)
        pane.table.selectAll(nil)
        let matches = pane.selectedURLs()
        XCTAssertTrue(matches.contains(hidden))
        let selected = IndexSet(matches.indices.filter { [urls[40], urls[41]].contains(matches[$0]) })
        pane.table.selectRowIndexes(selected, byExtendingSelection: false)
        pane.table.scrollRowToVisible(60)
        let rootOffset = clip.bounds.origin.y
        XCTAssertGreaterThan(rootOffset, 0)

        await awaitPaneLoad(pane, expectedURL: child) { pane.revealOriginalFolder() }
        XCTAssertFalse(pane.recursiveSearchVisible)
        XCTAssertEqual(pane.selectedURLs(), [urls[40]])
        try FileManager.default.removeItem(at: urls[41])
        pane.session.includeHidden = false
        await search("item", in: pane)
        pane.table.selectRowIndexes(IndexSet(integer: 50), byExtendingSelection: false)
        let childSelection = pane.selectedURLs()
        pane.table.scrollRowToVisible(68)
        let childOffset = clip.bounds.origin.y

        await completedSearch(pane) { pane.goBack() }
        XCTAssertEqual(pane.session.url, root)
        XCTAssertEqual(pane.recursiveSearchField.stringValue, "needle")
        XCTAssertTrue(pane.session.includeHidden)
        XCTAssertTrue(pane.recursiveSearchVisible)
        XCTAssertEqual(pane.selectedURLs(), [urls[40]], "Deleted search hits must not be restored")
        XCTAssertEqual(clip.bounds.origin.y, rootOffset, accuracy: 1)
        XCTAssertEqual(pane.table.numberOfRows, 80)

        await completedSearch(pane) { pane.goForward() }
        XCTAssertEqual(pane.session.url, child)
        XCTAssertEqual(pane.recursiveSearchField.stringValue, "item")
        XCTAssertFalse(pane.session.includeHidden)
        XCTAssertEqual(pane.selectedURLs(), childSelection)
        XCTAssertEqual(clip.bounds.origin.y, childOffset, accuracy: 1)
        XCTAssertEqual(pane.table.numberOfRows, 79)
    }

    @MainActor
    func testRevealDirectResultCreatesHistoryEvenWhenOriginalFolderIsSearchRoot() async throws {
        let urls = try files(in: root, count: 2)
        let (pane, window) = await pane()
        defer { pane.cancelBackgroundWork(); window.close() }
        await search("needle", in: pane)
        pane.table.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false)
        await awaitPaneLoad(pane) { pane.revealOriginalFolder() }
        XCTAssertFalse(pane.recursiveSearchVisible)
        XCTAssertEqual(pane.selectedURLs(), [urls[1]])
        XCTAssertTrue(pane.session.canGoBack)
        await completedSearch(pane) { pane.goBack() }
        XCTAssertTrue(pane.recursiveSearchVisible)
        XCTAssertEqual(pane.recursiveSearchField.stringValue, "needle")
        XCTAssertEqual(pane.selectedURLs(), [urls[1]])
        await awaitPaneLoad(pane) { pane.goForward() }
        XCTAssertFalse(pane.recursiveSearchVisible)
        XCTAssertEqual(pane.selectedURLs(), [urls[1]])
    }

    @MainActor
    func testOpeningResultFolderRestoresSearchAndRejectsLateRestorationAfterAnotherNavigation() async throws {
        let child = try folder("needle-folder")
        let other = try folder("other")
        let (pane, window) = await pane()
        defer { pane.cancelBackgroundWork(); window.close() }
        let hit = try XCTUnwrap(pane.session.entries.first { $0.url == child })
        var callbacks: [(Result<[FileEntry], Error>) -> Void] = []
        var cancelled = 0
        pane.searchFiles = { _, _, _, done in callbacks.append(done); return { cancelled += 1 } }
        pane.showRecursiveSearch()
        pane.recursiveSearchField.stringValue = "needle"
        pane.recursiveSearchChanged()
        await completedSearch(pane) { callbacks[0](.success([hit])) }
        pane.table.selectAll(nil)
        await awaitPaneLoad(pane, expectedURL: child) { pane.openSelection() }
        XCTAssertFalse(pane.recursiveSearchVisible)
        await awaitPaneLoad(pane, expectedURL: root) { pane.goBack() }
        XCTAssertTrue(pane.searchIsRunning)
        XCTAssertEqual(pane.recursiveSearchField.stringValue, "needle")
        await completedSearch(pane) { callbacks[1](.success([hit])) }
        XCTAssertEqual(pane.selectedURLs(), [child])

        await awaitPaneLoad(pane, expectedURL: child) { pane.goForward() }
        await awaitPaneLoad(pane, expectedURL: root) { pane.goBack() }
        XCTAssertEqual(callbacks.count, 3)
        await awaitPaneLoad(pane, expectedURL: other) { pane.session.navigate(to: other) }
        callbacks[2](.success([hit]))
        XCTAssertFalse(pane.recursiveSearchVisible)
        XCTAssertEqual(pane.table.numberOfRows, 0)
        XCTAssertTrue(pane.selectedURLs().isEmpty)
        XCTAssertEqual(cancelled, 1)
    }

    @MainActor
    func testSortReordersExistingResultsWithoutFilesystemReadOrLosingSelectionAndScroll() async throws {
        let urls = try files(in: root)
        let (pane, window) = await pane()
        defer { pane.cancelBackgroundWork(); window.close() }
        let entries = pane.session.entries
        var requests = 0
        pane.searchFiles = { _, _, _, done in requests += 1; done(.success(entries)); return {} }
        pane.sortSearchEntries = {
            XCTAssertFalse(Thread.isMainThread)
            return FileOps.sorted($0, by: $1, ascending: $2)
        }
        await search("needle", in: pane)
        pane.table.selectRowIndexes(IndexSet([40, 41]), byExtendingSelection: false)
        pane.table.scrollRowToVisible(60)
        let clip = try XCTUnwrap(pane.table.enclosingScrollView?.contentView)
        let offset = clip.bounds.origin.y
        let revision = pane.session.revision
        await completedSearch(pane) {
            pane.table.sortDescriptors = [NSSortDescriptor(key: SortColumn.size.rawValue, ascending: false)]
        }
        XCTAssertEqual(requests, 1)
        XCTAssertFalse(pane.searchIsRunning)
        XCTAssertFalse(pane.session.isLoading)
        XCTAssertEqual(pane.session.revision, revision)
        XCTAssertEqual(Set(pane.selectedURLs()), Set([urls[40], urls[41]]))
        XCTAssertEqual(clip.bounds.origin.y, offset, accuracy: 1)
        pane.table.selectAll(nil)
        XCTAssertEqual(pane.selectedURLs(), urls.reversed())
    }

    @MainActor
    func testReloadKeepsResultsWhileSearchingAndPreservesSurvivingSelectionAndScroll() async throws {
        let urls = try files(in: root)
        let (pane, window) = await pane()
        defer { pane.cancelBackgroundWork(); window.close() }
        let entries = pane.session.entries
        var callbacks: [(Result<[FileEntry], Error>) -> Void] = []
        pane.searchFiles = { _, _, _, done in callbacks.append(done); return {} }
        pane.showRecursiveSearch()
        pane.recursiveSearchField.stringValue = "needle"
        pane.recursiveSearchChanged()
        // Sorting an in-flight search must not issue a second recursive query either.
        pane.table.sortDescriptors = [NSSortDescriptor(key: SortColumn.size.rawValue, ascending: false)]
        XCTAssertEqual(callbacks.count, 1)
        await completedSearch(pane) { callbacks[0](.success(entries)) }
        pane.table.selectRowIndexes(IndexSet([40, 41]), byExtendingSelection: false)
        let selection = pane.selectedURLs()
        let deleted = try XCTUnwrap(selection.first)
        pane.table.scrollRowToVisible(60)
        let clip = try XCTUnwrap(pane.table.enclosingScrollView?.contentView)
        let offset = clip.bounds.origin.y
        await awaitPaneLoad(pane) { pane.session.reload() }
        XCTAssertEqual(callbacks.count, 2)
        XCTAssertEqual(pane.table.numberOfRows, urls.count)
        XCTAssertEqual(pane.selectedURLs(), selection)
        XCTAssertTrue(pane.searchIsRunning)
        await completedSearch(pane) { callbacks[1](.success(entries.filter { $0.url != deleted })) }
        XCTAssertEqual(pane.selectedURLs(), selection.filter { $0 != deleted })
        XCTAssertEqual(clip.bounds.origin.y, offset, accuracy: 1)
        pane.table.selectAll(nil)
        XCTAssertEqual(pane.selectedURLs(), urls.reversed().filter { $0 != deleted })
    }

    @MainActor
    func testRestorationSurvivesReloadAndNewQueryDiscardsItsPendingSelection() async throws {
        let child = try folder("child")
        let urls = try files(in: root, count: 2)
        let (pane, window) = await pane()
        defer { pane.cancelBackgroundWork(); window.close() }
        let entries = pane.session.entries.filter { !$0.isDirectory }
        var callbacks: [(Result<[FileEntry], Error>) -> Void] = []
        pane.searchFiles = { _, _, _, done in callbacks.append(done); return {} }
        pane.showRecursiveSearch()
        pane.recursiveSearchField.stringValue = "needle"
        pane.recursiveSearchChanged()
        await completedSearch(pane) { callbacks[0](.success(entries)) }
        pane.table.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false)
        await awaitPaneLoad(pane, expectedURL: child) { pane.session.navigate(to: child) }
        await awaitPaneLoad(pane, expectedURL: root) { pane.goBack() }
        await awaitPaneLoad(pane) { pane.session.reload() }
        XCTAssertEqual(callbacks.count, 3)
        callbacks[1](.success([]))
        XCTAssertTrue(pane.searchIsRunning, "Superseded history query must not settle the refreshed query")
        await completedSearch(pane) { callbacks[2](.success(entries)) }
        XCTAssertEqual(pane.selectedURLs(), [urls[1]])

        await awaitPaneLoad(pane, expectedURL: child) { pane.goForward() }
        await awaitPaneLoad(pane, expectedURL: root) { pane.goBack() }
        pane.recursiveSearchField.stringValue = "item"
        pane.recursiveSearchChanged()
        callbacks[3](.success(entries))
        XCTAssertTrue(pane.searchIsRunning)
        await completedSearch(pane) { callbacks[4](.success(entries)) }
        XCTAssertEqual(pane.recursiveSearchField.stringValue, "item")
        XCTAssertTrue(pane.selectedURLs().isEmpty, "A different query must not inherit the pending history selection")
    }

    @MainActor
    func testDelayedSearchSortCannotOverwriteNavigation() async throws {
        try await supersededSearchSort(by: .navigation)
    }

    @MainActor
    func testDelayedSearchSortCannotOverwriteReloadedResults() async throws {
        try await supersededSearchSort(by: .reload)
    }

    @MainActor
    func testDelayedSearchSortCannotOverwriteNewSort() async throws {
        try await supersededSearchSort(by: .sort)
    }

    @MainActor
    func testDelayedSearchSortCannotOverwriteNewQuery() async throws {
        try await supersededSearchSort(by: .query)
    }

    private enum SearchSortReplacement { case navigation, reload, sort, query }

    @MainActor
    private func supersededSearchSort(by next: SearchSortReplacement) async throws {
        let child = try folder("child")
        let urls = try files(in: root, count: 3)
        let (pane, window) = await pane()
        defer { pane.cancelBackgroundWork(); window.close() }
        let entries = pane.session.entries.filter { !$0.isDirectory }
        var callbacks: [(Result<[FileEntry], Error>) -> Void] = []
        pane.searchFiles = { _, _, _, done in callbacks.append(done); return {} }
        pane.showRecursiveSearch()
        pane.recursiveSearchField.stringValue = "needle"
        pane.recursiveSearchChanged()
        await completedSearch(pane) { callbacks[0](.success(entries)) }
        pane.table.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false)
        let started = expectation(description: "Search snapshot sort started off main")
        let returned = expectation(description: "Superseded search sort returned")
        let release = DispatchSemaphore(value: 0)
        defer { release.signal() }
        pane.sortSearchEntries = { entries, column, ascending in
            XCTAssertFalse(Thread.isMainThread)
            if column == .size && entries.count == 3 {
                started.fulfill()
                release.wait()
                returned.fulfill()
            }
            return FileOps.sorted(entries, by: column, ascending: ascending)
        }
        pane.table.sortDescriptors = [NSSortDescriptor(key: SortColumn.size.rawValue, ascending: false)]
        await fulfillment(of: [started], timeout: 5)
        XCTAssertEqual(pane.selectedURLs(), [urls[1]])
        XCTAssertEqual(pane.table.numberOfRows, 3)
        XCTAssertEqual(callbacks.count, 1)
        switch next {
        case .navigation:
            await awaitPaneLoad(pane, expectedURL: child) { pane.session.navigate(to: child) }
        case .reload:
            await awaitPaneLoad(pane) { pane.session.reload() }
            await completedSearch(pane) { callbacks[1](.success(Array(entries.suffix(2)))) }
        case .sort:
            await completedSearch(pane) {
                pane.table.sortDescriptors = [NSSortDescriptor(key: SortColumn.name.rawValue, ascending: false)]
            }
        case .query:
            pane.recursiveSearchField.stringValue = "item-02"
            pane.recursiveSearchChanged()
            await completedSearch(pane) { callbacks[1](.success([entries[2]])) }
        }
        XCTAssertEqual(callbacks.count, next == .navigation || next == .sort ? 1 : 2)
        let selection = pane.selectedURLs()
        let count = pane.table.numberOfRows
        let stale = expectation(description: "Superseded search sort must not publish")
        stale.isInverted = true
        pane.onSearchChange = { stale.fulfill() }
        release.signal()
        await fulfillment(of: [returned, stale], timeout: 0.25)
        pane.onSearchChange = nil
        XCTAssertEqual(pane.selectedURLs(), selection)
        XCTAssertEqual(pane.table.numberOfRows, count)
        XCTAssertFalse(pane.searchIsRunning)
        pane.table.selectAll(nil)
        switch next {
        case .navigation:
            XCTAssertEqual(pane.session.url, child)
            XCTAssertFalse(pane.recursiveSearchVisible)
            XCTAssertTrue(pane.selectedURLs().isEmpty)
        case .reload: XCTAssertEqual(pane.selectedURLs(), [urls[2], urls[1]])
        case .sort: XCTAssertEqual(pane.selectedURLs(), Array(urls.reversed()))
        case .query: XCTAssertEqual(pane.selectedURLs(), [urls[2]])
        }
    }

    @MainActor
    func testSortChangeDuringInitialResultSortingPublishesLatestOrderWithoutAnotherQuery() async throws {
        let urls = try files(in: root, count: 3)
        let (pane, window) = await pane()
        defer { pane.cancelBackgroundWork(); window.close() }
        let entries = pane.session.entries
        let started = expectation(description: "Initial search results sorting")
        let returned = expectation(description: "Old initial sort returned")
        let release = DispatchSemaphore(value: 0)
        defer { release.signal() }
        pane.sortSearchEntries = { entries, column, ascending in
            XCTAssertFalse(Thread.isMainThread)
            if column == .name && ascending {
                started.fulfill()
                release.wait()
                returned.fulfill()
            }
            return FileOps.sorted(entries, by: column, ascending: ascending)
        }
        var requests = 0
        pane.searchFiles = { _, _, _, done in requests += 1; done(.success(entries)); return {} }
        pane.showRecursiveSearch()
        pane.recursiveSearchField.stringValue = "needle"
        pane.recursiveSearchChanged()
        await fulfillment(of: [started], timeout: 5)
        XCTAssertTrue(pane.searchIsRunning)
        XCTAssertEqual(pane.table.numberOfRows, 0, "Do not publish unprocessed search results")
        await completedSearch(pane) {
            pane.table.sortDescriptors = [NSSortDescriptor(key: SortColumn.size.rawValue, ascending: false)]
        }
        XCTAssertEqual(requests, 1)
        pane.table.selectAll(nil)
        XCTAssertEqual(pane.selectedURLs(), Array(urls.reversed()))
        let stale = expectation(description: "Old initial ordering must not publish")
        stale.isInverted = true
        pane.onSearchChange = { stale.fulfill() }
        release.signal()
        await fulfillment(of: [returned, stale], timeout: 0.25)
        pane.onSearchChange = nil
        XCTAssertEqual(pane.selectedURLs(), Array(urls.reversed()))
        XCTAssertFalse(pane.searchIsRunning)
    }

    @MainActor
    func testSearchRootFailureClearsOldResultsAndShowsErrorInsteadOfZeroMatches() async throws {
        _ = try files(in: root, count: 1)
        let (pane, window) = await pane()
        defer { pane.cancelBackgroundWork(); window.close() }
        await search("needle", in: pane)
        XCTAssertEqual(pane.table.numberOfRows, 1)
        pane.searchFiles = { _, _, _, done in done(.failure(FileOpError("root permission denied"))); return {} }
        await completedSearch(pane) { pane.session.reload() }
        XCTAssertEqual(pane.table.numberOfRows, 0)
        XCTAssertTrue(pane.summary().contains("검색하지 못했습니다"))
        XCTAssertTrue(pane.summary().contains(root.path))
        XCTAssertTrue(pane.summary().contains("root permission denied"))
        XCTAssertFalse(pane.summary().contains("검색 0개"))
    }

    @MainActor
    func testPartialSearchShowsMatchesAndPathsWithReasonsInsteadOfFalseEmptyResult() async throws {
        let blocked = try folder("blocked")
        _ = try files(in: blocked, count: 1)
        let healthy = try folder("healthy")
        let visible = try files(in: healthy, count: 1)
        let (pane, window) = await pane()
        defer { pane.cancelBackgroundWork(); window.close() }
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: blocked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: blocked.path) }
        await search("needle", in: pane)
        pane.table.selectAll(nil)
        XCTAssertEqual(pane.selectedURLs(), visible)
        XCTAssertTrue(pane.summary().contains("부분 검색"))
        XCTAssertTrue(pane.summary().contains("확인된 결과 1개"))
        XCTAssertTrue(pane.summary().contains(blocked.path))
        XCTAssertTrue(pane.summary().contains("검색하지 못한 경로 1개"))
        let warning = try XCTUnwrap(pane.view.subviews.compactMap { $0 as? NSTextField }
            .first { $0.stringValue.hasPrefix("부분 검색") })
        XCTAssertEqual(warning.toolTip, pane.summary())
        XCTAssertTrue(warning.toolTip?.contains(blocked.path + ": ") == true)
        await search("no-matches", in: pane)
        XCTAssertTrue(pane.summary().contains("부분 검색"))
        XCTAssertTrue(pane.summary().contains("확인된 결과 0개"))
        XCTAssertTrue(pane.summary().contains(blocked.path))
    }
}
