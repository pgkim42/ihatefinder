import XCTest
@testable import IHateFinderCore

final class BrowserNavigationStateTests: XCTestCase {
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
