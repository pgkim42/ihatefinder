import XCTest
@testable import IHateFinderCore

final class CompressTests: XCTestCase {
    private var root: URL!
    private var bin: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("compress-\(UUID())", isDirectory: true)
        bin = root.appendingPathComponent("bin", isDirectory: true)
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: root)
    }

    private func write(_ name: String, _ body: String = "x") throws -> URL {
        let url = root.appendingPathComponent(name)
        try Data(body.utf8).write(to: url)
        return url
    }

    private func names() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: root.path).filter { $0 != "bin" }.sorted()
    }

    private func binOps() -> FileOps {
        let bin = self.bin!
        return FileOps(sameVolume: { _, _ in true }, moveToTrash: { url in
            let holder = bin.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: holder, withIntermediateDirectories: true)
            let moved = holder.appendingPathComponent(url.lastPathComponent)
            try FileManager.default.moveItem(at: url, to: moved)
            return moved
        })
    }

    /// A runner that finishes at once and writes `body` as the "archive".
    private func instantRunner(body: String = "zip", status: Int32 = 0, error: String = "") -> CompressRunner {
        { _, destination in
            try Data(body.utf8).write(to: destination)
            return CompressProcess(isRunning: { false }, terminate: {}, exitStatus: { status }, errorOutput: { error })
        }
    }

    func testSuccessCreatesNameZipAndSecondRunNumbersIt() throws {
        let item = try write("x")
        let ops = binOps()
        let first = try ops.compress(item, runner: instantRunner(body: "one")).get()
        XCTAssertEqual(first.lastPathComponent, "x.zip")
        let second = try ops.compress(item, runner: instantRunner(body: "two")).get()
        XCTAssertEqual(second.lastPathComponent, "x (2).zip")
        let third = try ops.compress(item, runner: instantRunner(body: "three")).get()
        XCTAssertEqual(third.lastPathComponent, "x (3).zip")
        XCTAssertEqual(try String(contentsOf: first, encoding: .utf8), "one")
        XCTAssertEqual(try names(), ["x", "x (2).zip", "x (3).zip", "x.zip"])
    }

    func testExistingZipIsNeverOverwritten() throws {
        let item = try write("x")
        let existing = try write("x.zip", "precious")
        let created = try binOps().compress(item, runner: instantRunner()).get()
        XCTAssertEqual(created.lastPathComponent, "x (2).zip")
        XCTAssertEqual(try String(contentsOf: existing, encoding: .utf8), "precious")
    }

    func testRunnerFailureLeavesNoZipAndNoStage() throws {
        let item = try write("x")
        let result = binOps().compress(item, runner: instantRunner(status: 1, error: "boom"))
        guard case .failure(let error) = result else { return XCTFail("expected failure") }
        XCTAssertTrue(error.message.contains("x"))
        XCTAssertTrue(error.message.contains("boom"))
        XCTAssertEqual(try names(), ["x"])
    }

    func testRunnerThatCannotStartLeavesNothing() throws {
        let item = try write("x")
        let result = binOps().compress(item, runner: { _, _ in throw FileOpError("no ditto") })
        guard case .failure = result else { return XCTFail("expected failure") }
        XCTAssertEqual(try names(), ["x"])
    }

    func testMissingSourceFails() throws {
        let missing = root.appendingPathComponent("gone")
        guard case .failure = binOps().compress(missing, runner: instantRunner()) else { return XCTFail("expected failure") }
        XCTAssertEqual(try names(), [])
    }

    func testCancellationTerminatesProcessAndLeavesNoPartialFileOrStage() throws {
        let item = try write("x")
        let cancellation = FileTransferCancellation()
        let lock = NSLock()
        var running = true
        var terminated = false
        let runner: CompressRunner = { _, destination in
            try Data("partial".utf8).write(to: destination)
            return CompressProcess(
                isRunning: { lock.lock(); defer { lock.unlock() }; return running },
                terminate: { lock.lock(); terminated = true; running = false; lock.unlock() },
                exitStatus: { 15 },
                errorOutput: { "" }
            )
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { cancellation.cancel() }
        let result = binOps().compress(item, cancellation: cancellation, runner: runner)
        XCTAssertEqual(result, .failure(.compressCancelled))
        lock.lock(); let didTerminate = terminated; lock.unlock()
        XCTAssertTrue(didTerminate)
        XCTAssertEqual(try names(), ["x"])
    }

    func testCancellationBeforeStartIsHonouredWithoutPublishing() throws {
        let item = try write("x")
        let cancellation = FileTransferCancellation()
        cancellation.cancel()
        let result = binOps().compress(item, cancellation: cancellation, runner: instantRunner())
        XCTAssertEqual(result, .failure(.compressCancelled))
        XCTAssertEqual(try names(), ["x"])
    }

    func testRealDittoZipsAFolderAndKeepsParent() throws {
        let folder = root.appendingPathComponent("docs", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("hello".utf8).write(to: folder.appendingPathComponent("a.txt"))
        let zip = try binOps().compress(folder).get()
        XCTAssertEqual(zip.lastPathComponent, "docs.zip")
        let list = Process()
        list.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        list.arguments = ["-Z1", zip.path]
        let pipe = Pipe()
        list.standardOutput = pipe
        try list.run()
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        list.waitUntilExit()
        XCTAssertTrue(output.contains("docs/a.txt"), output)
        XCTAssertEqual(try names(), ["docs", "docs.zip"])
    }

    func testUndoRecordIsCreatedWithIdentityAndUndoTrashesTheZip() throws {
        let item = try write("x")
        let ops = binOps()
        let zip = try ops.compress(item, runner: instantRunner()).get()
        let record = ops.undoRecord(compressed: zip)
        XCTAssertEqual(record.items.count, 1)
        guard case .created(let url, let id) = record.items[0] else { return XCTFail("expected .created") }
        XCTAssertEqual(url, zip)
        XCTAssertNotNil(id)

        let report = ops.undo(record)

        XCTAssertEqual(report.undone.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: zip.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: item.path))
        let trashed = try FileManager.default.subpathsOfDirectory(atPath: bin.path).filter { $0.hasSuffix("x.zip") }
        XCTAssertEqual(trashed.count, 1)
    }

    func testUndoRefusesWhenTheZipWasReplacedByAnotherFile() throws {
        let item = try write("x")
        let ops = binOps()
        let zip = try ops.compress(item, runner: instantRunner()).get()
        let record = ops.undoRecord(compressed: zip)
        try FileManager.default.removeItem(at: zip)
        try Data("different".utf8).write(to: zip)

        let report = ops.undo(record)

        XCTAssertEqual(report.undone.count, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: zip.path))
    }
}
