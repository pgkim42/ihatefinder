import AppKit
import XCTest
import IHateFinderCore
@testable import IHateFinder

final class BrowserSeamTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("browser-seam-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: root)
    }

    @MainActor
    func testTestBrowserPanesStartInTempFoldersNotHome() throws {
        let test = try makeTestBrowser(root: root)

        XCTAssertEqual(test.browser.left.session.url.path, test.left.standardizedFileURL.path)
        XCTAssertEqual(test.browser.right.session.url.path, test.right.standardizedFileURL.path)
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        XCTAssertNotEqual(test.browser.left.session.url.path, home)
        XCTAssertNotEqual(test.browser.right.session.url.path, home)
        XCTAssertFalse(test.browser.isFileOperationRunning)
    }

    @MainActor
    func testEachPaneGetsInjectedOpsThatTrashIntoTheTempBinWithoutCloning() throws {
        let test = try makeTestBrowser(root: root)
        let file = test.left.appendingPathComponent("gone.txt")
        try Data("bye".utf8).write(to: file)

        for pane in [test.browser.left, test.browser.right] {
            XCTAssertFalse(pane.session.ops.cloneOnSameVolume)
        }
        let trashURL = try XCTUnwrap(test.browser.left.session.ops.moveToTrash(file))

        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertTrue(trashURL.path.hasPrefix(test.bin.path + "/"))
        XCTAssertEqual(try String(contentsOf: trashURL, encoding: .utf8), "bye")
    }

    @MainActor
    func testBusyIsTestVisibleAndWaitIdleReturnsOnceCleared() async throws {
        let test = try makeTestBrowser(root: root)
        test.browser.busy = true
        XCTAssertTrue(test.browser.isFileOperationRunning)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { test.browser.busy = false }

        try await test.browser.waitIdle()

        XCTAssertFalse(test.browser.isFileOperationRunning)
    }

    @MainActor
    func testDropCopyRunsThroughInjectedOpsInsideTempFolders() async throws {
        let test = try makeTestBrowser(root: root)
        let file = test.left.appendingPathComponent("moved.txt")
        try Data("data".utf8).write(to: file)

        test.browser.drop([file], onto: test.right, moving: false)
        try await test.browser.waitIdle()

        XCTAssertEqual(try String(contentsOf: test.right.appendingPathComponent("moved.txt"), encoding: .utf8), "data")
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: test.bin.path), [])
    }
}
