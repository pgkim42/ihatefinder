import XCTest
@testable import IHateFinderCore

final class FileOutcomeTests: XCTestCase {
    private var root: URL!
    private var bin: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("outcome-\(UUID())", isDirectory: true)
        bin = root.appendingPathComponent("bin", isDirectory: true)
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: root)
    }

    private func write(_ name: String, _ body: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try Data(body.utf8).write(to: url)
        return url
    }

    private func binOps(failingOn failing: Set<String> = []) -> FileOps {
        let bin = self.bin!
        return FileOps(sameVolume: { _, _ in true }, moveToTrash: { url in
            if failing.contains(url.lastPathComponent) { throw FileOpError("거부됨") }
            let holder = bin.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: holder, withIntermediateDirectories: true)
            let moved = holder.appendingPathComponent(url.lastPathComponent)
            try FileManager.default.moveItem(at: url, to: moved)
            return moved
        })
    }

    func testRenameKeepBothReportsTheRealDestination() throws {
        let a = try write("a.txt", "a")
        _ = try write("b.txt", "existing")

        let outcome = try binOps().rename(url: a, to: "b.txt", resolve: { _ in .keepBoth })

        guard case .renamed(let result) = outcome else { return XCTFail("expected .renamed, got \(outcome)") }
        XCTAssertEqual(result.destination.lastPathComponent, "b (1).txt")
        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("b.txt"), encoding: .utf8), "existing")
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("b (1).txt"), encoding: .utf8), "a")
    }

    func testRenameReplaceReportsReplacementAndTrashURL() throws {
        let a = try write("a.txt", "new")
        _ = try write("b.txt", "old")

        let outcome = try binOps().rename(url: a, to: "b.txt", resolve: { _ in .replace })

        guard case .renamed(let result) = outcome else { return XCTFail("expected .renamed") }
        XCTAssertTrue(result.replacedExisting)
        XCTAssertEqual(try String(contentsOf: try XCTUnwrap(result.replacedTrashURL), encoding: .utf8), "old")
    }

    func testRenameSkipReportsSkippedAndChangesNothing() throws {
        let a = try write("a.txt", "a")
        _ = try write("b.txt", "existing")

        let outcome = try binOps().rename(url: a, to: "b.txt", resolve: { _ in .skip })

        XCTAssertEqual(outcome, .skipped)
        XCTAssertEqual(try String(contentsOf: a, encoding: .utf8), "a")
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("b.txt"), encoding: .utf8), "existing")
    }

    func testRenameToSamePathReportsUnchanged() throws {
        let a = try write("a.txt", "a")
        XCTAssertEqual(try binOps().rename(url: a, to: "a.txt", resolve: { _ in .replace }), .unchanged)
        XCTAssertEqual(try binOps().rename(url: a, to: "  a.txt ", resolve: { _ in .replace }), .unchanged)
    }

    func testTrashUrlsStopsAtFirstFailureAndKeepsPartialResults() throws {
        let one = try write("one.txt", "1")
        let two = try write("two.txt", "2")
        let three = try write("three.txt", "3")

        let report = binOps(failingOn: ["two.txt"]).trash(urls: [one, two, three])

        XCTAssertEqual(report.items.map(\.original), [one, two, three])
        guard case .trashed = report.items[0].status, case .failed = report.items[1].status,
              report.items[2].status == .unprocessed else {
            return XCTFail("statuses were \(report.items.map(\.status))")
        }
        let trashURL = try XCTUnwrap(report.items[0].trashedURL)
        XCTAssertEqual(try String(contentsOf: trashURL, encoding: .utf8), "1")
        XCTAssertNil(report.items[1].trashedURL)
        XCTAssertNil(report.items[2].trashedURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: one.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: two.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: three.path))
    }

    func testTrashUrlsWithLegacyClosureReportsNilTrashURL() throws {
        let one = try write("legacy.txt", "1")
        let ops = FileOps(sameVolume: { _, _ in true }, trash: { _ in })

        let report = ops.trash(urls: [one])

        XCTAssertEqual(report.items.first?.status, .trashed)
        XCTAssertNil(report.items.first?.trashedURL)
    }
}
