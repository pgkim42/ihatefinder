import XCTest
@testable import IHateFinderCore

final class BrowserSessionTests: XCTestCase {
    @MainActor
    func testSlowSupersededReadCannotReplaceNewerDirectory() async throws {
        let root = URL(fileURLWithPath: "/initial", isDirectory: true)
        let slow = URL(fileURLWithPath: "/slow", isDirectory: true)
        let fast = URL(fileURLWithPath: "/fast", isDirectory: true)
        let started = expectation(description: "slow listing started off main")
        let returned = expectation(description: "slow listing returned")
        let release = DispatchSemaphore(value: 0)
        let session = BrowserSession(url: root, listing: { url, _ in
            XCTAssertFalse(Thread.isMainThread)
            if url == slow {
                started.fulfill()
                release.wait()
                returned.fulfill()
            }
            return [Self.entry(in: url, name: url.lastPathComponent)]
        })
        defer { release.signal() }
        session.navigate(to: slow)
        await fulfillment(of: [started], timeout: 3)
        XCTAssertEqual(session.loadState, .loading(slow))
        XCTAssertEqual(session.url, root)
        XCTAssertTrue(session.entries.isEmpty)
        await settle(session) { session.navigate(to: fast) }
        XCTAssertEqual(session.url, fast)
        XCTAssertEqual(session.entries.map(\.name), ["fast"])

        let staleNotification = expectation(description: "stale read must not publish")
        staleNotification.isInverted = true
        session.onChange = { staleNotification.fulfill() }
        release.signal()
        await fulfillment(of: [returned, staleNotification], timeout: 0.3)
        XCTAssertEqual(session.url, fast)
        XCTAssertEqual(session.entries.map(\.name), ["fast"])
        await settle(session) { XCTAssertTrue(session.goBack()) }
        XCTAssertEqual(session.url, root, "superseded slow folder never enters history")
    }

    @MainActor
    func testFailedNavigationAndHistoryLoadsPreserveCommittedSnapshot() async throws {
        let base = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: base) }
        let root = base.appendingPathComponent("root", isDirectory: true)
        let child = base.appendingPathComponent("child", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        try Data("root".utf8).write(to: root.appendingPathComponent("root.txt"))
        try Data("child".utf8).write(to: child.appendingPathComponent("child.txt"))
        let session = BrowserSession(url: root, listing: nil)
        await settle(session) { session.reload() }
        await settle(session) { session.navigate(to: child) }
        let committed = session.entries
        let hiddenRoot = base.appendingPathComponent("hidden-root", isDirectory: true)
        try FileManager.default.moveItem(at: root, to: hiddenRoot)
        await settle(session) { XCTAssertTrue(session.goBack()) }
        XCTAssertEqual(session.url, child)
        XCTAssertEqual(session.entries, committed)
        XCTAssertTrue(session.canGoBack)
        XCTAssertFalse(session.canGoForward)
        guard case .failed(let failedURL, let message) = session.loadState else {
            return XCTFail("failed history load must expose error state")
        }
        XCTAssertEqual(failedURL, root)
        XCTAssertFalse(message.isEmpty)
        try FileManager.default.moveItem(at: hiddenRoot, to: root)
        await settle(session) { XCTAssertTrue(session.goBack()) }
        XCTAssertEqual(session.url, root)
        XCTAssertFalse(session.canGoBack)
        XCTAssertTrue(session.canGoForward)
        let missing = base.appendingPathComponent("missing")
        await settle(session) { session.navigate(to: missing) }
        XCTAssertEqual(session.url, root)
        XCTAssertEqual(session.entries.map(\.name), ["root.txt"])
        XCTAssertTrue(session.canGoForward, "failed navigation must not discard forward history")
        await settle(session) { XCTAssertTrue(session.goForward()) }
        XCTAssertEqual(session.url, child)
        XCTAssertEqual(session.entries, committed)
        XCTAssertEqual(session.loadState, .idle)
    }

    @MainActor
    func testSortAndHiddenChangesDuringNavigationKeepLatestTarget() async {
        let root = URL(fileURLWithPath: "/root", isDirectory: true)
        let target = URL(fileURLWithPath: "/target", isDirectory: true)
        let started = expectation(description: "first request started")
        let release = DispatchSemaphore(value: 0)
        let session = BrowserSession(url: root, listing: { url, hidden in
            if !hidden {
                started.fulfill()
                release.wait()
            }
            return [Self.entry(in: url, name: "a"), Self.entry(in: url, name: "z")]
        })
        defer { release.signal() }
        session.navigate(to: target)
        await fulfillment(of: [started], timeout: 3)
        session.includeHidden = true
        await settle(session) { session.setSort(.name, ascending: false) }
        XCTAssertEqual(session.url, target)
        XCTAssertEqual(session.entries.map(\.name), ["z", "a"])
    }

    @MainActor
    func testExternalCreateRenameDeleteAndFolderReplacementRefreshListing() async throws {
        let base = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: base) }
        let folder = base.appendingPathComponent("folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        let session = BrowserSession(url: folder)
        await settle(session) { session.reload() }
        let original = folder.appendingPathComponent("created.txt")
        let renamed = folder.appendingPathComponent("renamed.txt")
        try await observe(session, names: ["created.txt"]) { try Data().write(to: original) }
        try await observe(session, names: ["renamed.txt"]) {
            try FileManager.default.moveItem(at: original, to: renamed)
        }
        let metadataChanged = expectation(description: "existing file content updates size")
        session.onChange = {
            if !session.isLoading && session.entries.first?.size == 7 {
                session.onChange = nil
                metadataChanged.fulfill()
            }
        }
        try Data("updated".utf8).write(to: renamed)
        await fulfillment(of: [metadataChanged], timeout: 5)
        session.onChange = nil
        XCTAssertEqual(session.entries.first?.size, 7)
        try await observe(session, names: []) { try FileManager.default.removeItem(at: renamed) }
        try await observe(session, names: ["replacement.txt"]) {
            try FileManager.default.moveItem(at: folder, to: base.appendingPathComponent("old-folder"))
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
            try Data().write(to: folder.appendingPathComponent("replacement.txt"))
        }
        try await observe(session, names: ["after-rearm.txt", "replacement.txt"]) {
            try Data().write(to: folder.appendingPathComponent("after-rearm.txt"))
        }
        XCTAssertEqual(session.url, folder)
        XCTAssertFalse(session.canGoBack)
    }

    @MainActor
    private func settle(_ session: BrowserSession, action: () -> Void) async {
        let finished = expectation(description: "load settles")
        session.onChange = {
            XCTAssertTrue(Thread.isMainThread)
            if !session.isLoading { finished.fulfill() }
        }
        action()
        await fulfillment(of: [finished], timeout: 5)
        session.onChange = nil
    }

    @MainActor
    private func observe(_ session: BrowserSession, names: [String], action: () throws -> Void) async throws {
        let changed = expectation(description: "external change: \(names)")
        session.onChange = {
            if !session.isLoading && session.entries.map(\.name) == names {
                session.onChange = nil
                changed.fulfill()
            }
        }
        try action()
        await fulfillment(of: [changed], timeout: 5)
        session.onChange = nil
        XCTAssertEqual(session.entries.map(\.name), names)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("session-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        return url
    }

    private static func entry(in directory: URL, name: String) -> FileEntry {
        FileEntry(url: directory.appendingPathComponent(name), name: name, isDirectory: false,
                  size: 0, modified: .distantPast, kind: "text", isHidden: false)
    }
}
