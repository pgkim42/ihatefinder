import Foundation
import XCTest
import IHateFinderCore
@testable import IHateFinder

final class DirectorySearchTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("directory-search-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }

    @MainActor
    private func search(at searchRoot: URL? = nil, readValues: @escaping (URL, Set<URLResourceKey>) throws -> URLResourceValues = {
        try $0.resourceValues(forKeys: $1)
    }) async throws -> DirectoryQueries.SearchResult {
        let done = expectation(description: "Search completion")
        var result: Result<DirectoryQueries.SearchResult, Error>?
        DirectoryQueries.search(searchRoot ?? root, query: "needle", includeHidden: false, readValues: readValues) {
            XCTAssertTrue(Thread.isMainThread)
            result = $0
            done.fulfill()
        }
        await fulfillment(of: [done], timeout: 5)
        return try XCTUnwrap(result).get()
    }

    @MainActor
    func testOptionalMetadataFailureKeepsHealthyMatchesAndStillVisitsFolderDescendants() async throws {
        let badFolder = root.appendingPathComponent("needle-folder", isDirectory: true)
        try FileManager.default.createDirectory(at: badFolder, withIntermediateDirectories: false)
        let child = badFolder.appendingPathComponent("needle-child.txt")
        let sibling = root.appendingPathComponent("needle-sibling.txt")
        let badFile = root.appendingPathComponent("needle-broken.txt")
        for url in [child, sibling, badFile] { try Data().write(to: url) }
        let report = try await search { url, keys in
            if [badFolder.path, badFile.path].contains(url.standardizedFileURL.path) && keys.contains(.fileSizeKey) {
                throw FileOpError("metadata unavailable")
            }
            return try url.resourceValues(forKeys: keys)
        }
        XCTAssertEqual(Set(report.entries.map(\.url)), Set([child, sibling]))
        XCTAssertEqual(Set(report.issues.map(\.url)), Set([badFolder, badFile]))
        XCTAssertTrue(report.issues.allSatisfy { $0.message == "metadata unavailable" })
    }

    @MainActor
    func testStructuralMetadataFailureSkipsOnlyThatPathAndReportsReason() async throws {
        let bad = root.appendingPathComponent("needle-bad.txt")
        let good = root.appendingPathComponent("needle-good.txt")
        for url in [bad, good] { try Data().write(to: url) }
        let report = try await search { url, keys in
            if url.standardizedFileURL.path == bad.path { throw FileOpError("vanished during enumeration") }
            return try url.resourceValues(forKeys: keys)
        }
        XCTAssertEqual(report.entries.map(\.url), [good])
        XCTAssertEqual(report.issues, [.init(url: bad, message: "vanished during enumeration")])
    }

    @MainActor
    func testUnreadableRootFailsInsteadOfReportingAnEmptyOrPartialSuccess() async throws {
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: root.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path) }
        do {
            _ = try await search()
            XCTFail("An unreadable root must fail")
        } catch {
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }

    @MainActor
    func testEmptyReadableRootIsACompleteEmptySuccess() async throws {
        let report = try await search()
        XCTAssertTrue(report.entries.isEmpty)
        XCTAssertTrue(report.issues.isEmpty)
    }

    @MainActor
    func testSymbolicLinkRootSearchesRealFolderWithoutFollowingDescendantLinks() async throws {
        let folder = root.appendingPathComponent("real", isDirectory: true)
        let outside = root.appendingPathComponent("outside", isDirectory: true)
        for url in [folder, outside] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        }
        let match = folder.appendingPathComponent("needle-file.txt")
        try Data().write(to: match)
        try Data().write(to: outside.appendingPathComponent("needle-outside.txt"))
        let descendantLink = folder.appendingPathComponent("needle-link")
        try FileManager.default.createSymbolicLink(at: descendantLink, withDestinationURL: outside)
        let alias = root.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: folder)

        let report = try await search(at: alias)

        XCTAssertEqual(Set(report.entries.map { $0.url.path }), Set([match.path, descendantLink.path]))
        XCTAssertTrue(report.issues.isEmpty)
    }

    @MainActor
    func testSystemLinkRootsReachEnumerationOrCompleteWhenEmpty() async {
        // Stop at the first entry: this checks the real system roots without
        // recursively searching /tmp, /etc or /var and unrelated user data.
        for path in ["/tmp", "/private/tmp", "/etc", "/private/etc", "/var", "/private/var"] {
            let started = expectation(description: "Enumeration started at \(path)")
            let returned = expectation(description: "Read returned at \(path)")
            let release = DispatchSemaphore(value: 0)
            var reachedEntry = false
            var completedSuccessfully = false
            let cancel = DirectoryQueries.search(URL(fileURLWithPath: path), query: "needle", includeHidden: false,
                                                readValues: { url, keys in
                if keys.contains(.isSymbolicLinkKey) {
                    reachedEntry = true
                    started.fulfill()
                    release.wait()
                    returned.fulfill()
                }
                return try url.resourceValues(forKeys: keys)
            }) { result in
                switch result {
                case .success: completedSuccessfully = true
                case .failure(let error): XCTFail("\(path): \(error)")
                }
                started.fulfill()
                returned.fulfill()
            }
            await fulfillment(of: [started], timeout: 5)
            cancel()
            release.signal()
            await fulfillment(of: [returned], timeout: 5)
            XCTAssertTrue(reachedEntry || completedSuccessfully, "The linked system root must pass validation: \(path)")
        }
    }

    @MainActor
    func testDescendantLinksDoNotDropSiblingFolderContents() async throws {
        let folder = root.appendingPathComponent("real", isDirectory: true)
        let outside = root.appendingPathComponent("outside", isDirectory: true)
        for url in [folder, outside] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        }
        try Data().write(to: outside.appendingPathComponent("needle-outside.txt"))
        var expected: Set<String> = []
        for index in 0..<8 {
            let directory = folder.appendingPathComponent("dir\(index)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
            let match = directory.appendingPathComponent("needle-\(index).txt")
            try Data().write(to: match)
            expected.insert(match.path)
        }
        for index in 0..<3 {
            let link = folder.appendingPathComponent("needle-link-\(index)")
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
            expected.insert(link.path)
        }

        let report = try await search(at: folder)

        XCTAssertEqual(Set(report.entries.map { $0.url.path }), expected)
        XCTAssertTrue(report.issues.isEmpty)
    }

    @MainActor
    func testStructuralFailuresDoNotSkipOtherFoldersOrReadableDescendants() async throws {
        var expected: Set<URL> = []
        var failed: Set<URL> = []
        for index in 0..<6 {
            let directory = root.appendingPathComponent("dir\(index)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
            let match = directory.appendingPathComponent("needle-\(index).txt")
            try Data().write(to: match)
            expected.insert(match)
            if index == 2 { failed.insert(directory) }
        }
        for index in 0..<3 {
            let file = root.appendingPathComponent("vanished-\(index).txt")
            try Data().write(to: file)
            failed.insert(file)
        }
        let failedPaths = Set(failed.map(\.path))
        let report = try await search { url, keys in
            if failedPaths.contains(url.standardizedFileURL.path) {
                throw FileOpError("structure unavailable")
            }
            return try url.resourceValues(forKeys: keys)
        }

        XCTAssertEqual(Set(report.entries.map(\.url)), expected)
        XCTAssertEqual(Set(report.issues.map(\.url)), failed)
    }

    @MainActor
    func testFolderRemovedDuringMetadataReadIsReportedOnce() async throws {
        let removed = root.appendingPathComponent("needle-removed", isDirectory: true)
        try FileManager.default.createDirectory(at: removed, withIntermediateDirectories: false)
        try Data().write(to: removed.appendingPathComponent("child.txt"))
        let good = root.appendingPathComponent("needle-good.txt")
        try Data().write(to: good)
        let report = try await search { url, keys in
            if url.standardizedFileURL.path == removed.path && keys.contains(.fileSizeKey) {
                try FileManager.default.removeItem(at: removed)
                throw FileOpError("Removed during metadata read")
            }
            return try url.resourceValues(forKeys: keys)
        }

        XCTAssertEqual(report.entries.map(\.url), [good])
        XCTAssertEqual(report.issues.count, 1)
        let issue = try XCTUnwrap(report.issues.first)
        XCTAssertEqual(issue.url.lastPathComponent, removed.lastPathComponent)
        XCTAssertEqual(issue.url.deletingLastPathComponent().resolvingSymlinksInPath(),
                       removed.deletingLastPathComponent().resolvingSymlinksInPath())
        XCTAssertEqual(issue.message, "Removed during metadata read")
    }

    @MainActor
    func testUnreadableRootThroughSymbolicLinkFailsInsteadOfReturningPartialResults() async throws {
        let folder = root.appendingPathComponent("real", isDirectory: true)
        let blocked = folder.appendingPathComponent("blocked", isDirectory: true)
        try FileManager.default.createDirectory(at: blocked, withIntermediateDirectories: true)
        let alias = root.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: folder)
        let directAlias = root.appendingPathComponent("blocked-alias")
        try FileManager.default.createSymbolicLink(at: directAlias, withDestinationURL: blocked)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: blocked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: blocked.path) }

        for searchRoot in [directAlias, alias.appendingPathComponent("blocked")] {
            do {
                _ = try await search(at: searchRoot)
                XCTFail("An unreadable root must fail through a final or intermediate link")
            } catch {
                XCTAssertFalse(error.localizedDescription.isEmpty)
            }
        }
    }

    @MainActor
    func testUnreadableDescendantThroughSymbolicLinkRootKeepsHealthyMatches() async throws {
        let folder = root.appendingPathComponent("real", isDirectory: true)
        let blocked = folder.appendingPathComponent("blocked", isDirectory: true)
        try FileManager.default.createDirectory(at: blocked, withIntermediateDirectories: true)
        let good = folder.appendingPathComponent("needle-good.txt")
        try Data().write(to: good)
        try Data().write(to: blocked.appendingPathComponent("needle-blocked.txt"))
        let alias = root.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: folder)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: blocked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: blocked.path) }

        let report = try await search(at: alias)

        XCTAssertEqual(report.entries.map(\.url), [good])
        XCTAssertEqual(report.issues.map(\.url), [blocked])
        XCTAssertFalse(try XCTUnwrap(report.issues.first).message.isEmpty)
    }

    @MainActor
    func testCancellationSuppressesCompletionEvenWhenFilesystemReadReturnsLate() async throws {
        let started = expectation(description: "Read started")
        let returned = expectation(description: "Read returned")
        let completion = expectation(description: "Cancelled search must not publish")
        completion.isInverted = true
        let release = DispatchSemaphore(value: 0)
        let root = root!
        let file = root.appendingPathComponent("needle-delay.txt")
        try Data().write(to: file)
        let cancel = DirectoryQueries.search(root, query: "needle", includeHidden: false, readValues: { url, keys in
            if url.standardizedFileURL == file && keys.contains(.isSymbolicLinkKey) {
                started.fulfill()
                release.wait()
                returned.fulfill()
            }
            return try url.resourceValues(forKeys: keys)
        }) { _ in completion.fulfill() }
        await fulfillment(of: [started], timeout: 5)
        cancel()
        release.signal()
        await fulfillment(of: [returned, completion], timeout: 0.3)
    }
}
