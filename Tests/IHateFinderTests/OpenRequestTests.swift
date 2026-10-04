import AppKit
import XCTest
@testable import IHateFinder

final class OpenRequestTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("openreq-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: root)
    }

    private func folder(_ name: String) throws -> URL {
        let url = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func file(_ name: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try Data("x".utf8).write(to: url)
        return url
    }

    func testFolderIsShown() throws {
        let dir = try folder("dir")
        XCTAssertEqual(OpenRequest.make(url: dir), .showFolder(dir))
    }

    func testFileIsRevealedInItsParent() throws {
        let f = try file("a.txt")
        XCTAssertEqual(OpenRequest.make(url: f), .reveal(parent: root, select: f))
    }

    func testAppPackageIsRevealedNotEntered() throws {
        let app = try folder("Foo.app")
        XCTAssertEqual(OpenRequest.make(url: app), .reveal(parent: root, select: app))
    }

    func testSymlinkToFolderShowsTheTarget() throws {
        let dir = try folder("real")
        let link = root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: dir)
        XCTAssertEqual(OpenRequest.make(url: link), .showFolder(dir))
    }

    func testMissingPathIsAFailureAndChangesNothing() throws {
        let missing = root.appendingPathComponent("nope")
        guard case .failure(let message) = OpenRequest.make(url: missing) else { return XCTFail("expected failure") }
        XCTAssertTrue(message.contains("nope"))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [])
    }

    func testFirstExistingURLWinsAndFailureIsReportedOnlyWhenNoneExist() throws {
        let missing = root.appendingPathComponent("nope")
        let dir = try folder("dir")
        let f = try file("a.txt")
        XCTAssertEqual(OpenRequest.make(urls: [missing, dir, f]), .showFolder(dir))
        XCTAssertEqual(OpenRequest.make(urls: [f, dir]), .reveal(parent: root, select: f))
        guard case .failure? = OpenRequest.make(urls: [missing]) else { return XCTFail("expected failure") }
        XCTAssertNil(OpenRequest.make(urls: []))
    }

    func testDescriptorListOfFileURLs() throws {
        let a = try file("a.txt")
        let b = try file("b.txt")
        let list = NSAppleEventDescriptor.list()
        list.insert(NSAppleEventDescriptor(fileURL: a), at: 1)
        list.insert(NSAppleEventDescriptor(fileURL: b), at: 2)
        XCTAssertEqual(OpenRequest.urls(fromAppleEventDirectObject: list), [a, b])
    }

    func testDescriptorSingleFileURL() throws {
        let a = try file("a.txt")
        XCTAssertEqual(OpenRequest.urls(fromAppleEventDirectObject: NSAppleEventDescriptor(fileURL: a)), [a])
        XCTAssertEqual(OpenRequest.urls(fromAppleEventDirectObject: nil), [])
    }

    @MainActor
    func testRequestsBeforeTheBrowserExistsAreQueuedAndDrainedExactlyOnce() throws {
        _ = NSApplication.shared
        let delegate = AppDelegate()
        let one = OpenRequest.showFolder(root)
        let two = OpenRequest.failure("x")
        delegate.route(one)
        delegate.route(two)
        XCTAssertEqual(delegate.pendingOpens, [one, two])

        var handled: [OpenRequest] = []
        delegate.drainPendingOpens(into: { handled.append($0) })
        delegate.drainPendingOpens(into: { handled.append($0) })

        XCTAssertEqual(handled, [one, two])
        XCTAssertTrue(delegate.pendingOpens.isEmpty)
    }
}
