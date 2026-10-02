import Darwin
import XCTest
@testable import IHateFinderCore

final class FileTransferProgressTests: XCTestCase {
    private var base: URL!
    private var source: URL!
    private var destination: URL!

    override func setUpWithError() throws {
        base = FileManager.default.temporaryDirectory.appendingPathComponent("transfer-progress-\(UUID())")
        source = base.appendingPathComponent("source")
        destination = base.appendingPathComponent("destination")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: base)
    }

    func testMidFileCancellationPreservesSourceAndOldTargetAndCleansPartialStage() throws {
        let file = try makeLargeFile()
        let target = destination.appendingPathComponent(file.lastPathComponent)
        try Data("old target".utf8).write(to: target)
        let later = source.appendingPathComponent("later.txt")
        try Data("later".utf8).write(to: later)
        let cancellation = FileTransferCancellation()
        var cancelledAt: Int64?
        var trashCalls = 0
        let ops = FileOps(sameVolume: { _, _ in false }, trash: { _ in trashCalls += 1 })

        let report = ops.transfer(
            urls: [file, later], to: destination, moving: true, resolve: { _ in .replace },
            cancellation: cancellation, progressInterval: 0
        ) { sample in
            if sample.phase == .copying, let total = sample.totalBytes,
               sample.bytesCopied > 0, sample.bytesCopied < total {
                cancelledAt = sample.bytesCopied
                cancellation.cancel()
            }
        }

        XCTAssertNotNil(cancelledAt, "Cancellation must happen during data transfer, not after copying")
        XCTAssertEqual(report.items.map(\.status), [.cancelled, .unprocessed])
        XCTAssertEqual(report.completedSources, [])
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "old target")
        XCTAssertEqual(try file.resourceValues(forKeys: [.fileSizeKey]).fileSize, 32 * 1024 * 1024)
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        XCTAssertEqual(try handle.read(upToCount: 64 * 1024), Data(repeating: 0x5a, count: 64 * 1024))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: destination.path), [file.lastPathComponent])
        XCTAssertEqual(trashCalls, 0)
    }

    func testSingleFileReportsIntermediateBytesAndMetadataIsPreserved() throws {
        let file = try makeLargeFile()
        let date = Date(timeIntervalSince1970: 1_600_000_000)
        try FileManager.default.setAttributes([.posixPermissions: 0o640, .modificationDate: date], ofItemAtPath: file.path)
        let attribute = Array("metadata".utf8)
        let setResult = attribute.withUnsafeBytes {
            setxattr(file.path, "com.ihatefinder.test", $0.baseAddress, $0.count, 0, 0)
        }
        XCTAssertEqual(setResult, 0)
        var observedIntermediate = false
        var observedFullSize = false
        var lastByteCount: Int64 = 0
        var phases: [FileTransferProgress.Phase] = []
        let report = FileOps().transfer(
            urls: [file], to: destination, moving: false, resolve: { _ in .replace }, progressInterval: 0
        ) { sample in
            phases.append(sample.phase)
            XCTAssertEqual(sample.operation, .copy)
            XCTAssertEqual(sample.totalItems, 1)
            XCTAssertEqual(sample.source, file)
            XCTAssertEqual(sample.processedItems, sample.phase == .finished ? 1 : 0)
            if sample.phase == .copying, let total = sample.totalBytes {
                XCTAssertEqual(total, 32 * 1024 * 1024)
                XCTAssertGreaterThanOrEqual(sample.bytesCopied, lastByteCount)
                lastByteCount = sample.bytesCopied
                observedIntermediate = observedIntermediate || (sample.bytesCopied > 0 && sample.bytesCopied < total)
                observedFullSize = observedFullSize || sample.bytesCopied == total
            } else {
                XCTAssertNil(sample.totalBytes)
            }
        }
        XCTAssertEqual(report.items.map(\.status), [.completed])
        XCTAssertTrue(observedIntermediate)
        XCTAssertTrue(observedFullSize)
        XCTAssertEqual(phases.first, .preparing)
        XCTAssertTrue(phases.contains(.committing))
        XCTAssertEqual(phases.last, .finished)
        let target = destination.appendingPathComponent(file.lastPathComponent)
        let attributes = try FileManager.default.attributesOfItem(atPath: target.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o640)
        XCTAssertEqual(attributes[.modificationDate] as? Date, date)
        var copiedAttribute = [UInt8](repeating: 0, count: attribute.count)
        let received = copiedAttribute.withUnsafeMutableBytes {
            getxattr(target.path, "com.ihatefinder.test", $0.baseAddress, $0.count, 0, 0)
        }
        XCTAssertEqual(received, attribute.count)
        XCTAssertEqual(copiedAttribute, attribute)
        XCTAssertTrue(FileManager.default.contentsEqual(atPath: file.path, andPath: target.path))
    }

    func testDirectoryCopyReportsNestedFilesAndRetainsDanglingSymlink() throws {
        let folder = source.appendingPathComponent("folder")
        let nested = folder.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let file = nested.appendingPathComponent("data.txt")
        try Data("nested contents".utf8).write(to: file)
        try FileManager.default.createSymbolicLink(atPath: folder.appendingPathComponent("link").path,
                                                 withDestinationPath: "missing-target")
        var copiedNestedFile = false
        var indeterminate = false
        let report = FileOps().transfer(
            urls: [folder], to: destination, moving: false, resolve: { _ in .replace }, progressInterval: 0
        ) { sample in
            if sample.phase == .copying {
                indeterminate = indeterminate || sample.totalBytes == nil
                copiedNestedFile = copiedNestedFile || (sample.currentFile == file && sample.bytesCopied == 15)
            }
        }
        XCTAssertEqual(report.items.map(\.status), [.completed])
        XCTAssertTrue(copiedNestedFile)
        XCTAssertTrue(indeterminate)
        let target = destination.appendingPathComponent("folder")
        XCTAssertEqual(try String(contentsOf: target.appendingPathComponent("nested/data.txt"), encoding: .utf8), "nested contents")
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: target.appendingPathComponent("link").path), "missing-target")
    }

    func testCancellationAfterConflictChoiceDoesNotStartReplacement() throws {
        let file = source.appendingPathComponent("item")
        let target = destination.appendingPathComponent("item")
        try Data("source".utf8).write(to: file)
        try Data("target".utf8).write(to: target)
        let cancellation = FileTransferCancellation()
        let report = FileOps().transfer(
            urls: [file], to: destination, moving: true,
            resolve: { _ in cancellation.cancel(); return .replace }, cancellation: cancellation
        )
        XCTAssertEqual(report.items.map(\.status), [.cancelled])
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "source")
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "target")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: destination.path), ["item"])
    }

    func testCancellationBeforeCommitDiscardsCompleteUnpublishedCopy() throws {
        let file = source.appendingPathComponent("item")
        try Data("source".utf8).write(to: file)
        let cancellation = FileTransferCancellation()
        let report = FileOps().transfer(
            urls: [file], to: destination, moving: false, resolve: { _ in .replace }, cancellation: cancellation
        ) { sample in
            if sample.phase == .committing { cancellation.cancel() }
        }
        XCTAssertEqual(report.items.map(\.status), [.cancelled])
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "source")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: destination.path), [])
    }

    func testCancellationDuringCommittedMoveFinishesCurrentAndStopsNextItems() throws {
        let files = ["first", "second", "third"].map { source.appendingPathComponent($0) }
        for file in files { try Data(file.lastPathComponent.utf8).write(to: file) }
        let cancellation = FileTransferCancellation()
        let ops = FileOps(sameVolume: { _, _ in false }, trash: { file in
            cancellation.cancel()
            try FileManager.default.removeItem(at: file)
        })
        let report = ops.transfer(urls: files, to: destination, moving: true,
                                  resolve: { _ in .replace }, cancellation: cancellation)
        XCTAssertEqual(report.items.map(\.status), [.completed, .cancelled, .unprocessed])
        XCTAssertEqual(report.completedSources, [files[0]])
        XCTAssertFalse(FileManager.default.fileExists(atPath: files[0].path))
        XCTAssertEqual(try String(contentsOf: destination.appendingPathComponent("first"), encoding: .utf8), "first")
        for file in files.dropFirst() {
            XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), file.lastPathComponent)
            XCTAssertFalse(FileManager.default.fileExists(atPath: destination.appendingPathComponent(file.lastPathComponent).path))
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: destination.path), ["first"])
    }

    func testByteThrottlingKeepsFinalSample() throws {
        let file = try makeLargeFile()
        var determinateSamples = 0
        var finalBytes: Int64 = 0
        let report = FileOps().transfer(
            urls: [file], to: destination, moving: false, resolve: { _ in .replace }, progressInterval: 3600
        ) { sample in
            if sample.totalBytes != nil {
                determinateSamples += 1
                finalBytes = sample.bytesCopied
            }
        }
        XCTAssertEqual(report.items.map(\.status), [.completed])
        XCTAssertLessThanOrEqual(determinateSamples, 4)
        XCTAssertEqual(finalBytes, 32 * 1024 * 1024)
    }

    private func makeLargeFile() throws -> URL {
        let file = source.appendingPathComponent("large.bin")
        XCTAssertTrue(FileManager.default.createFile(atPath: file.path, contents: nil))
        let handle = try FileHandle(forWritingTo: file)
        defer { try? handle.close() }
        // A reusable 64 KiB buffer avoids allocating the full file in memory.
        let chunk = Data(repeating: 0x5a, count: 64 * 1024)
        for _ in 0..<512 { try handle.write(contentsOf: chunk) }
        return file
    }
}
