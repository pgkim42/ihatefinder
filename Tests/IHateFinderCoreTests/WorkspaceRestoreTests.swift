import XCTest
@testable import IHateFinderCore

final class WorkspaceRestoreTests: XCTestCase {
    private let home = URL(fileURLWithPath: "/restore-home", isDirectory: true)
    private let temporary = URL(fileURLWithPath: "/restore-temp", isDirectory: true)
    private let saved = URL(fileURLWithPath: "/unavailable-saved", isDirectory: true)

    @MainActor
    func testIndependentPaneConfigurationAndSinglePaneSurviveRelaunch() async throws {
        let (defaults, suite) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let original = WorkspaceState(
            left: PaneState(url: URL(fileURLWithPath: "/left"), sortColumn: .name, ascending: false, includeHidden: true),
            right: PaneState(url: URL(fileURLWithPath: "/right"), sortColumn: .size, ascending: true, includeHidden: false),
            dual: false)
        WorkspaceStore(defaults: defaults).save(original)
        let restored = WorkspaceStore(defaults: try XCTUnwrap(UserDefaults(suiteName: suite))).load()
        XCTAssertEqual(restored, original)
        let list: (URL, Bool) throws -> [FileEntry] = { url, hidden in
            XCTAssertFalse(Thread.isMainThread)
            var entries = [Self.entry(url, "a", size: 20), Self.entry(url, "z", size: 10)]
            if hidden { entries.append(Self.entry(url, ".hidden", size: 1)) }
            return entries
        }
        let left = session(restored.left, listing: list)
        let right = session(restored.right, listing: list)
        XCTAssertEqual(left.loadState, .idle)
        XCTAssertNil(left.persistedState)
        await settle(left) { left.reload() }
        await settle(right) { right.reload() }
        XCTAssertEqual(left.entries.filter { !$0.isHidden }.map(\.name), ["z", "a"])
        XCTAssertTrue(left.entries.contains { $0.name == ".hidden" && $0.isHidden })
        XCTAssertEqual(right.entries.map(\.name), ["z", "a"])
        XCTAssertFalse(restored.dual)
        XCTAssertFalse(left.canGoBack)
        XCTAssertFalse(right.canGoBack)
        WorkspaceStore(defaults: defaults).save(left: left, right: right, dual: true)
        XCTAssertEqual(WorkspaceStore(defaults: defaults).load(), WorkspaceState(left: original.left, right: original.right, dual: true))
    }

    func testCorruptOrIncompleteSavedDataUsesSafeDefaults() throws {
        let (defaults, suite) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = WorkspaceStore(defaults: defaults, key: "test-workspace", homeDirectory: home)
        let expected = WorkspaceState(left: PaneState(url: home), right: PaneState(url: home), dual: false)
        XCTAssertEqual(store.load(), expected)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        let configured = PaneState(url: home, sortColumn: .size, ascending: false, includeHidden: true)
        let valid = try encoder.encode(WorkspaceState(left: configured, right: configured, dual: true))
        let text = try XCTUnwrap(String(data: valid, encoding: .utf8))
        for data in [Data("not-json".utf8), Data("{}".utf8),
                     Data(text.replacingOccurrences(of: "\"size\"", with: "\"unknown\"").utf8),
                     Data(text.replacingOccurrences(of: home.path, with: "relative-path").utf8)] {
            defaults.set(data, forKey: "test-workspace")
            XCTAssertEqual(store.load(), expected)
        }
        defaults.set("wrong storage type", forKey: "test-workspace")
        XCTAssertEqual(store.load(), expected)
    }

    @MainActor
    func testStartupAndPendingNavigationNeverOverwriteCommittedFolders() async {
        let (defaults, suite) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = WorkspaceStore(defaults: defaults)
        let original = WorkspaceState(left: PaneState(url: saved), right: PaneState(url: home), dual: true)
        store.save(original)
        let started = expectation(description: "pending folder read")
        let release = DispatchSemaphore(value: 0)
        let pending = URL(fileURLWithPath: "/pending", isDirectory: true)
        let left = session(original.left) { url, _ in
            if url == pending {
                started.fulfill()
                release.wait()
            }
            return []
        }
        defer { release.signal() }
        let right = session(original.right) { _, _ in [] }
        store.save(left: left, right: right, dual: true)
        XCTAssertEqual(store.load(), original)
        await settle(left) { left.reload() }
        left.navigate(to: pending)
        await fulfillment(of: [started], timeout: 3)
        store.save(left: left, right: right, dual: false)
        XCTAssertEqual(store.load().left.path, saved.path)
        XCTAssertEqual(store.load().right.path, home.path)
        XCTAssertFalse(store.load().dual)
        await settle(left) { release.signal() }
        store.save(left: left, right: right, dual: false)
        XCTAssertEqual(store.load().left.path, pending.path)
    }

    @MainActor
    func testMissingSavedFolderFallsBackHomeAndLaterErrorsStayOnCommittedFolder() async {
        let home = home
        let session = session(PaneState(url: saved)) { url, _ in
            guard url == home else { throw CocoaError(.fileReadNoSuchFile) }
            return [Self.entry(url, "home.txt", size: 1)]
        }
        await settle(session) { session.reload() }
        XCTAssertEqual(session.url, home)
        XCTAssertEqual(session.entries.map(\.name), ["home.txt"])
        XCTAssertEqual(session.loadState, .idle)
        XCTAssertTrue(session.restorationNotice?.contains(saved.path) == true)
        XCTAssertTrue(session.restorationNotice?.contains(home.path) == true)
        XCTAssertFalse(session.canGoBack)
        let notice = session.restorationNotice
        await settle(session) { session.reload() }
        XCTAssertEqual(session.restorationNotice, notice, "automatic refresh must not hide the fallback explanation")
        let missing = URL(fileURLWithPath: "/later-missing", isDirectory: true)
        await settle(session) { session.navigate(to: missing) }
        guard case .failed(let failed, _) = session.loadState else { return XCTFail("later errors must remain visible") }
        XCTAssertEqual(failed, missing)
        XCTAssertEqual(session.url, home)
        XCTAssertEqual(session.entries.map(\.name), ["home.txt"])
        XCTAssertNil(session.restorationNotice)
        XCTAssertFalse(session.canGoBack)
    }

    @MainActor
    func testDeniedSavedAndHomeFoldersFallBackToTemporaryDirectory() async {
        let temporary = temporary
        let session = session(PaneState(url: saved)) { url, _ in
            guard url == temporary else { throw CocoaError(.fileReadNoPermission) }
            return []
        }
        await settle(session) { session.reload() }
        XCTAssertEqual(session.url, temporary)
        XCTAssertEqual(session.persistedState?.path, temporary.path)
        XCTAssertTrue(session.restorationNotice?.contains(saved.path) == true)
        XCTAssertTrue(session.restorationNotice?.contains(temporary.path) == true)
        XCTAssertFalse(session.canGoBack)
    }

    @MainActor
    func testAllUnavailableCandidatesStopAndManualRetryDoesNotRestartFallback() async {
        let attempts = expectation(description: "three distinct startup attempts and one explicit retry")
        attempts.expectedFulfillmentCount = 4
        attempts.assertForOverFulfill = true
        let session = session(PaneState(url: saved)) { _, _ in
            attempts.fulfill()
            throw CocoaError(.fileReadNoPermission)
        }
        await settle(session) { session.reload() }
        guard case .failed(let target, _) = session.loadState else { return XCTFail("fallback must stop") }
        XCTAssertEqual(target, temporary)
        XCTAssertNil(session.persistedState)
        XCTAssertFalse(session.isLoading)
        XCTAssertNotNil(session.restorationNotice)
        await settle(session) { session.reload() }
        await fulfillment(of: [attempts], timeout: 3)
        guard case .failed(let retried, _) = session.loadState else { return XCTFail("retry must report failure") }
        XCTAssertEqual(retried, saved)
    }

    @MainActor
    func testIdenticalFallbackCandidatesAreAttemptedOnlyOnce() async {
        let attempted = expectation(description: "one distinct startup path")
        attempted.assertForOverFulfill = true
        let session = BrowserSession(restoring: PaneState(url: home), homeDirectory: home,
                                     temporaryDirectory: home, listing: { _, _ in
            attempted.fulfill()
            throw CocoaError(.fileReadNoPermission)
        })
        await settle(session) { session.reload() }
        await fulfillment(of: [attempted], timeout: 3)
        guard case .failed(let target, _) = session.loadState else { return XCTFail("must stop after one candidate") }
        XCTAssertEqual(target, home)
        XCTAssertNil(session.persistedState)
        XCTAssertFalse(session.isLoading)
    }

    @MainActor
    func testUserNavigationSupersedesSlowStartupFailureWithoutFallbackOrHistoryPollution() async {
        let saved = saved
        let selected = URL(fileURLWithPath: "/selected", isDirectory: true)
        let started = expectation(description: "startup listing started")
        let returned = expectation(description: "old startup listing returned")
        let release = DispatchSemaphore(value: 0)
        let session = session(PaneState(url: saved)) { url, _ in
            if url == saved {
                started.fulfill()
                release.wait()
                returned.fulfill()
                throw CocoaError(.fileReadNoSuchFile)
            }
            XCTAssertEqual(url, selected, "a superseded startup must never try its fallback")
            return [Self.entry(url, "selected.txt", size: 1)]
        }
        defer { release.signal() }
        session.reload()
        await fulfillment(of: [started], timeout: 3)
        await settle(session) { session.navigate(to: selected) }
        let stale = expectation(description: "old startup must not publish")
        stale.isInverted = true
        session.onChange = { stale.fulfill() }
        release.signal()
        await fulfillment(of: [returned, stale], timeout: 0.3)
        session.onChange = nil
        XCTAssertEqual(session.url, selected)
        XCTAssertEqual(session.entries.map(\.name), ["selected.txt"])
        XCTAssertNil(session.restorationNotice)
        XCTAssertFalse(session.canGoBack)
    }

    @MainActor
    func testLegacyCutAndJobPayloadCannotRestoreOrExecuteOperations() async throws {
        let (defaults, suite) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("source.txt")
        let destination = directory.appendingPathComponent("moved.txt")
        try Data("untouched".utf8).write(to: source)
        let pane = PaneState(url: directory)
        let state = WorkspaceState(left: pane, right: pane, dual: false)
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        payload["cut"] = [source.path]
        payload["jobs"] = [["source": source.path, "destination": destination.path, "operation": "move"]]
        defaults.set(try JSONSerialization.data(withJSONObject: payload), forKey: "workspace.v1")
        let store = WorkspaceStore(defaults: defaults)
        let restored = store.load()
        let left = session(restored.left, listing: nil)
        let right = session(restored.right, listing: nil)
        await settle(left) { left.reload() }
        await settle(right) { right.reload() }
        XCTAssertEqual(try String(contentsOf: source, encoding: .utf8), "untouched")
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        store.save(left: left, right: right, dual: false)
        let persisted = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(defaults.data(forKey: "workspace.v1"))) as? [String: Any])
        XCTAssertNil(persisted["cut"])
        XCTAssertNil(persisted["jobs"])
        XCTAssertEqual(store.load(), state)
    }

    private func isolatedDefaults() -> (UserDefaults, String) {
        let suite = "WorkspaceRestoreTests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suite)!, suite)
    }

    private func session(_ state: PaneState, listing: ((URL, Bool) throws -> [FileEntry])?) -> BrowserSession {
        BrowserSession(restoring: state, homeDirectory: home, temporaryDirectory: temporary, listing: listing)
    }

    @MainActor
    private func settle(_ session: BrowserSession, action: () -> Void) async {
        let finished = expectation(description: "restoration or navigation settled")
        session.onChange = {
            XCTAssertTrue(Thread.isMainThread)
            if !session.isLoading {
                session.onChange = nil
                finished.fulfill()
            }
        }
        action()
        await fulfillment(of: [finished], timeout: 5)
        session.onChange = nil
    }

    private static func entry(_ directory: URL, _ name: String, size: Int64) -> FileEntry {
        FileEntry(url: directory.appendingPathComponent(name), name: name, isDirectory: false,
                  size: size, modified: .distantPast, kind: "text", isHidden: name.hasPrefix("."))
    }
}
