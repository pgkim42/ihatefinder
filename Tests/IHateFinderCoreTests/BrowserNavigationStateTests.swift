import XCTest
@testable import IHateFinderCore

final class BrowserNavigationStateTests: XCTestCase {
    @MainActor
    func testSameRootSearchExitIsAVisitAndHistoryRestoresItsHiddenScope() async {
        let root = URL(fileURLWithPath: "/root", isDirectory: true)
        var listedHidden: [Bool] = []
        let session = BrowserSession(url: root, listing: { _, hidden in
            listedHidden.append(hidden)
            return []
        })
        var current = BrowserSession.ViewState(selection: [root.appendingPathComponent("needle")], scrollOffset: 96,
                                               filter: "", filterVisible: false,
                                               search: .init(query: "needle", includeHidden: true))
        let search = current
        session.captureViewState = { current }
        session.includeHidden = true
        await settled(session) { session.navigate(to: root) }
        XCTAssertTrue(session.canGoBack)
        XCTAssertNil(session.restoredViewState?.search)
        current = BrowserSession.ViewState(selection: [], scrollOffset: 0, filter: "", filterVisible: false)
        session.includeHidden = false
        await settled(session) { _ = session.goBack() }
        XCTAssertEqual(session.restoredViewState, search)
        XCTAssertTrue(session.includeHidden)
        XCTAssertEqual(listedHidden, [true, true], "Restore hidden scope before listing the history root")
        current = search
        await settled(session) { _ = session.goForward() }
        XCTAssertNil(session.restoredViewState?.search)
        XCTAssertEqual(session.url, root)
    }

    @MainActor
    func testSortOfCommittedSnapshotDoesNotReloadOrReplayRestoration() async {
        let root = URL(fileURLWithPath: "/root", isDirectory: true)
        var reads = 0
        let session = BrowserSession(url: root, listing: { url, _ in
            reads += 1
            return ["a", "b"].map {
                FileEntry(url: url.appendingPathComponent($0), name: $0, isDirectory: false,
                          size: 0, modified: .distantPast, kind: "file", isHidden: false)
            }
        }, sorting: {
            XCTAssertFalse(Thread.isMainThread)
            return FileOps.sorted($0, by: $1, ascending: $2)
        })
        await settled(session) { session.reload() }
        let revision = session.revision
        await settled(session) { session.setSort(.name, ascending: false) }
        XCTAssertEqual(reads, 1)
        XCTAssertEqual(session.revision, revision)
        XCTAssertEqual(session.entries.map(\.name), ["b", "a"])
        XCTAssertFalse(session.isLoading)
        XCTAssertFalse(session.isSorting)
    }

    @MainActor
    func testSlowSortCannotOverwriteNewNavigation() async {
        await supersededSort(by: .navigation)
    }

    @MainActor
    func testSlowSortCannotOverwriteReload() async {
        await supersededSort(by: .reload)
    }

    @MainActor
    func testSlowSortCannotOverwriteNewSort() async {
        await supersededSort(by: .sort)
    }

    private enum SupersedingRequest { case navigation, reload, sort }

    @MainActor
    private func supersededSort(by next: SupersedingRequest) async {
        let root = URL(fileURLWithPath: "/root", isDirectory: true)
        let target = URL(fileURLWithPath: "/target", isDirectory: true)
        let started = expectation(description: "Snapshot sort started off main")
        let returned = expectation(description: "Superseded sort returned")
        let release = DispatchSemaphore(value: 0)
        var reads = 0
        let session = BrowserSession(url: root, listing: { url, _ in
            reads += 1
            return ["a", "z"].map {
                FileEntry(url: url.appendingPathComponent("\($0)-\(reads)"), name: "\($0)-\(reads)", isDirectory: false,
                          size: $0 == "a" ? 3 : 1, modified: .distantPast, kind: "file", isHidden: false)
            }
        }, sorting: { entries, column, ascending in
            XCTAssertFalse(Thread.isMainThread)
            // Only the first snapshot blocks; a subsequent filesystem load must proceed.
            if column == .size && entries.first?.name == "a-1" {
                started.fulfill()
                release.wait()
                returned.fulfill()
            }
            return FileOps.sorted(entries, by: column, ascending: ascending)
        })
        defer { release.signal() }
        await settled(session) { session.reload() }
        let original = session.entries
        session.setSort(.size, ascending: false)
        await fulfillment(of: [started], timeout: 5)
        XCTAssertTrue(session.isSorting)
        XCTAssertEqual(session.entries, original)
        let responsive = expectation(description: "Main queue remains responsive during sort")
        DispatchQueue.main.async { responsive.fulfill() }
        await fulfillment(of: [responsive], timeout: 1)
        switch next {
        case .navigation: await settled(session) { session.navigate(to: target) }
        case .reload: await settled(session) { session.reload() }
        case .sort: await settled(session) { session.setSort(.name, ascending: false) }
        }
        let expected = session.entries
        let revision = session.revision
        XCTAssertEqual(session.url, next == .navigation ? target : root)
        XCTAssertEqual(reads, next == .sort ? 1 : 2)
        XCTAssertEqual(expected.map(\.name), next == .sort ? ["z-1", "a-1"] : ["a-2", "z-2"])
        XCTAssertFalse(session.isSorting)
        let stale = expectation(description: "Superseded sort must not publish")
        stale.isInverted = true
        session.onChange = { stale.fulfill() }
        release.signal()
        await fulfillment(of: [returned, stale], timeout: 0.25)
        session.onChange = nil
        XCTAssertEqual(session.entries, expected)
        XCTAssertEqual(session.revision, revision)
        XCTAssertFalse(session.isSorting)
    }

    @MainActor
    func testRepeatedVisitsKeepIndependentSnapshotsAndFailedNavigationKeepsHistory() async {
        let root = URL(fileURLWithPath: "/root", isDirectory: true)
        let child = URL(fileURLWithPath: "/child", isDirectory: true)
        let missing = URL(fileURLWithPath: "/missing", isDirectory: true)
        let session = BrowserSession(url: root, listing: { url, _ in
            if url == missing { throw FileOpError("missing") }
            return []
        })
        var current = BrowserSession.ViewState(selection: [root.appendingPathComponent("first")], scrollOffset: 64,
                                               filter: "first", filterVisible: true)
        let first = current
        var captured = 0
        session.captureViewState = { captured += 1; return current }
        await settled(session) { session.navigate(to: child) }
        current = BrowserSession.ViewState(selection: [], scrollOffset: 32, filter: "", filterVisible: true)
        let middle = current
        await settled(session) { session.navigate(to: root) }
        current = BrowserSession.ViewState(selection: [root.appendingPathComponent("second")], scrollOffset: 128,
                                           filter: "second", filterVisible: false)
        let second = current
        await settled(session) { session.navigate(to: missing) }
        XCTAssertEqual(session.url, root)
        await settled(session) { _ = session.goBack() }
        XCTAssertEqual(session.restoredViewState, middle)
        current = middle
        await settled(session) { _ = session.goBack() }
        XCTAssertEqual(session.restoredViewState, first)
        current = first
        await settled(session) { _ = session.goForward() }
        XCTAssertEqual(session.restoredViewState, middle)
        current = middle
        await settled(session) { _ = session.goForward() }
        XCTAssertEqual(session.restoredViewState, second)
        XCTAssertEqual(captured, 7)
        await settled(session) { session.reload() }
        XCTAssertNil(session.restoredViewState, "A refresh must not replay a history restoration")
        XCTAssertEqual(captured, 7)
    }

    @MainActor
    private func settled(_ session: BrowserSession, action: () -> Void) async {
        let done = expectation(description: "Requested navigation completed")
        session.onChange = {
            if !session.isLoading {
                session.onChange = nil
                done.fulfill()
            }
        }
        action()
        await fulfillment(of: [done], timeout: 5)
        session.onChange = nil
    }
}
