import XCTest
@testable import IHateFinderCore

final class FileOpsTests: XCTestCase {
    private var base: URL!
    private var root: URL!
    private var bin: URL!

    override func setUpWithError() throws {
        base = FileManager.default.temporaryDirectory
            .appendingPathComponent("ihatefinder-\(UUID().uuidString)", isDirectory: true)
        root = base.appendingPathComponent("work", isDirectory: true)
        bin = base.appendingPathComponent("trash-bin", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: base)
    }

    func testListHidesDotfilesUntilAsked() throws {
        try write("visible.txt", "a")
        try write(".secret", "b")
        let ops = makeOps(same: true)
        let visible = try ops.list(directory: root, includeHidden: false).map(\.name)
        XCTAssertEqual(visible, ["visible.txt"])
        let all = try ops.list(directory: root, includeHidden: true).map(\.name).sorted()
        XCTAssertEqual(all, [".secret", "visible.txt"])
    }

    func testCopyKeepBothAndSkip() throws {
        try write("note.txt", "old")
        let source = try makeChild("src")
        try write("note.txt", "new", in: source)
        let ops = makeOps(same: true)
        let copied = ops.transfer(
            urls: [source.appendingPathComponent("note.txt")],
            to: root,
            moving: false,
            resolve: { _ in .keepBoth }
        )
        XCTAssertEqual(try text("note.txt"), "old")
        XCTAssertEqual(try text("note (1).txt"), "new")
        XCTAssertEqual(copied.items.map(\.status), [.completed])
        XCTAssertEqual(copied.items.first?.destination, root.appendingPathComponent("note (1).txt"))

        let skipped = ops.transfer(
            urls: [source.appendingPathComponent("note.txt")],
            to: root,
            moving: false,
            resolve: { _ in .skip }
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("note (2).txt").path))
        XCTAssertEqual(skipped.items.map(\.status), [.skipped])
    }

    func testReplaceSendsExistingToTrash() throws {
        try write("note.txt", "old")
        let source = try makeChild("src")
        try write("note.txt", "new", in: source)
        let ops = makeOps(same: true)
        let report = ops.transfer(
            urls: [source.appendingPathComponent("note.txt")],
            to: root,
            moving: false,
            resolve: { _ in .replace }
        )
        XCTAssertEqual(try text("note.txt"), "new")
        XCTAssertEqual(try String(contentsOf: bin.appendingPathComponent("note.txt"), encoding: .utf8), "old")
        XCTAssertEqual(report.items.map(\.status), [.completed])
    }

    func testSameVolumeMoveDoesNotTrashSource() throws {
        let source = try makeChild("src")
        try write("a.txt", "body", in: source)
        var trashed = false
        let ops = FileOps(sameVolume: { _, _ in true }, trash: { _ in trashed = true })
        let report = ops.transfer(
            urls: [source.appendingPathComponent("a.txt")],
            to: root,
            moving: true,
            resolve: { _ in .skip }
        )
        XCTAssertFalse(trashed)
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.appendingPathComponent("a.txt").path))
        XCTAssertEqual(try text("a.txt"), "body")
        XCTAssertEqual(report.completedSources, [source.appendingPathComponent("a.txt")])
    }

    func testCrossVolumeMoveCopiesThenTrashes() throws {
        let source = try makeChild("src")
        try write("a.txt", "body", in: source)
        let ops = makeOps(same: false)
        let report = ops.transfer(
            urls: [source.appendingPathComponent("a.txt")],
            to: root,
            moving: true,
            resolve: { _ in .skip }
        )
        XCTAssertEqual(try text("a.txt"), "body")
        XCTAssertEqual(try String(contentsOf: bin.appendingPathComponent("a.txt"), encoding: .utf8), "body")
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.appendingPathComponent("a.txt").path))
        XCTAssertEqual(report.completedSources, [source.appendingPathComponent("a.txt")])
    }

    func testCutPasteIntoSameFolderLeavesFile() throws {
        try write("a.txt", "body")
        let ops = makeOps(same: true)
        let url = root.appendingPathComponent("a.txt")
        let report = ops.paste(urls: [url], cut: true, into: root, resolve: { _ in .replace })
        XCTAssertEqual(try text("a.txt"), "body")
        XCTAssertFalse(FileManager.default.fileExists(atPath: bin.appendingPathComponent("a.txt").path))
        XCTAssertEqual(report.completedSources, [url])
    }

    func testCopyIntoSameFolderKeepsBoth() throws {
        try write("note.txt", "body")
        let ops = makeOps(same: true)
        let url = root.appendingPathComponent("note.txt")
        let report = ops.paste(urls: [url], cut: false, into: root, resolve: { _ in .keepBoth })
        XCTAssertEqual(try text("note.txt"), "body")
        XCTAssertEqual(try text("note (1).txt"), "body")
        XCTAssertEqual(report.items.first?.destination, root.appendingPathComponent("note (1).txt"))
    }

    func testCopyIntoSameFolderReplaceLeavesOriginal() throws {
        try write("note.txt", "body")
        let ops = makeOps(same: true)
        let url = root.appendingPathComponent("note.txt")
        let report = ops.paste(urls: [url], cut: false, into: root, resolve: { _ in .replace })
        XCTAssertEqual(try text("note.txt"), "body")
        XCTAssertFalse(FileManager.default.fileExists(atPath: bin.appendingPathComponent("note.txt").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("note (1).txt").path))
        XCTAssertEqual(report.items.map(\.status), [.skipped])
    }

    func testCreateFolderAndTextFileNumberDuplicates() throws {
        let ops = makeOps(same: true)
        let first = try ops.createFolder(in: root)
        let second = try ops.createFolder(in: root)
        XCTAssertEqual(first.lastPathComponent, "새 폴더")
        XCTAssertEqual(second.lastPathComponent, "새 폴더 (2)")
        let file = try ops.createTextFile(in: root)
        XCTAssertEqual(file.lastPathComponent, "새 텍스트 문서.txt")
        XCTAssertEqual(try text("새 텍스트 문서.txt"), "")
    }

    func testNameSortKeepsFoldersOnTopWhenDescending() {
        let folder = FileEntry(url: URL(fileURLWithPath: "/f"), name: "b", isDirectory: true, size: 0, modified: .distantPast, kind: "폴더", isHidden: false)
        let file = FileEntry(url: URL(fileURLWithPath: "/a"), name: "a", isDirectory: false, size: 1, modified: .distantPast, kind: "텍스트", isHidden: false)
        let sorted = FileOps.sorted([file, folder], by: .name, ascending: false)
        XCTAssertEqual(sorted.map(\.name), ["b", "a"])
    }

    func testMissingSameFolderCutIsFailedRatherThanCleared() {
        let missing = root.appendingPathComponent("missing.txt")

        let report = makeOps(same: true).paste(
            urls: [missing], cut: true, into: root, resolve: { _ in .replace }
        )

        XCTAssertEqual(report.items[0].status, .failed)
        XCTAssertEqual(report.completedSources, [])
        XCTAssertEqual(report.items[0].source, missing)
        XCTAssertEqual(report.items[0].destination, missing)
    }

    func testConflictResolutionFailureStopsBeforeChangingEitherItem() throws {
        let source = try makeChild("src")
        try write("note.txt", "original", in: source)
        try write("next.txt", "later", in: source)
        try write("note.txt", "existing")
        let urls = ["note.txt", "next.txt"].map { source.appendingPathComponent($0) }

        let report = makeOps(same: true).transfer(
            urls: urls, to: root, moving: true,
            resolve: { _ in throw FileOpError("Conflict dialog failed") }
        )

        XCTAssertEqual(report.items.map(\.status), [.failed, .unprocessed])
        XCTAssertEqual(report.completedSources, [])
        XCTAssertEqual(try text("note.txt"), "existing")
        XCTAssertEqual(try String(contentsOf: urls[0], encoding: .utf8), "original")
        XCTAssertEqual(try String(contentsOf: urls[1], encoding: .utf8), "later")
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("next.txt").path))
    }

    func testMoveReportsCompletedSkippedFailedAndUnprocessedItems() throws {
        let source = try makeChild("src")
        let names = ["first.txt", "skip.txt", "broken.txt", "last.txt"]
        for name in names { try write(name, name, in: source) }
        try write("skip.txt", "existing")
        let urls = names.map { source.appendingPathComponent($0) }
        let manager = FaultFileManager()
        manager.beforeMove = { from, _ in
            if from == urls[2] { throw FileOpError("Injected move failure") }
        }

        let report = makeOps(same: true, fileManager: manager).transfer(
            urls: urls, to: root, moving: true, resolve: { _ in .skip }
        )

        XCTAssertEqual(report.items.map(\.status), [.completed, .skipped, .failed, .unprocessed])
        XCTAssertEqual(report.items.map(\.source), urls)
        XCTAssertEqual(report.completedSources, [urls[0]])
        XCTAssertFalse(FileManager.default.fileExists(atPath: urls[0].path))
        XCTAssertEqual(try text("first.txt"), "first.txt")
        XCTAssertEqual(try text("skip.txt"), "existing")
        for url in urls.dropFirst() {
            XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), url.lastPathComponent)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("broken.txt").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("last.txt").path))
        XCTAssertEqual(report.items[2].destination, root.appendingPathComponent("broken.txt"))
        XCTAssertNotNil(report.items[2].message)
    }

    func testFailedReplacementCopyPreservesOldDestinationAndSource() throws {
        let source = try makeChild("src")
        try write("note.txt", "original", in: source)
        try write("note.txt", "existing")
        let url = source.appendingPathComponent("note.txt")
        let manager = FaultFileManager()
        manager.beforeCopy = { _, target in
            try Data("partial".utf8).write(to: target)
            throw FileOpError("Injected incomplete copy")
        }

        let report = makeOps(same: false, fileManager: manager).transfer(
            urls: [url], to: root, moving: true, resolve: { _ in .replace }
        )

        XCTAssertEqual(report.items.map(\.status), [.failed])
        XCTAssertEqual(report.items[0].recovery?.status, .preserved)
        XCTAssertEqual(try text("note.txt"), "existing")
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "original")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path).sorted(), ["note.txt", "src"])
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: bin.path), [])
        XCTAssertEqual(report.completedSources, [])
    }

    func testReplacementCommitFailureRestoresDestinationAndMovedSource() throws {
        let source = try makeChild("src")
        try write("note.txt", "original", in: source)
        try write("note.txt", "existing")
        let url = source.appendingPathComponent("note.txt")
        let target = root.appendingPathComponent("note.txt")
        let manager = FaultFileManager()
        var attemptedInstall = false
        manager.beforeMove = { _, to in
            if to == target && !attemptedInstall {
                attemptedInstall = true
                throw FileOpError("Injected install failure")
            }
        }

        let report = makeOps(same: true, fileManager: manager).transfer(
            urls: [url], to: root, moving: true, resolve: { _ in .replace }
        )

        XCTAssertEqual(report.items.map(\.status), [.failed])
        XCTAssertEqual(report.items[0].recovery?.status, .restored)
        XCTAssertEqual(try text("note.txt"), "existing")
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "original")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path).sorted(), ["note.txt", "src"])
    }

    func testFailedDestinationRollbackReportsRecoverableOriginalLocation() throws {
        let source = try makeChild("src")
        try write("note.txt", "original", in: source)
        try write("note.txt", "existing")
        let url = source.appendingPathComponent("note.txt")
        let target = root.appendingPathComponent("note.txt")
        let manager = FaultFileManager()
        var backup: URL?
        manager.beforeMove = { from, to in
            if from == target { backup = to }
            if to == target { throw FileOpError("Injected install and restore failure") }
        }

        let report = makeOps(same: false, fileManager: manager).transfer(
            urls: [url], to: root, moving: false, resolve: { _ in .replace }
        )

        let saved = try XCTUnwrap(backup)
        let recovery = try XCTUnwrap(report.items[0].recovery)
        XCTAssertEqual(report.items[0].status, .failed)
        XCTAssertEqual(recovery.status, .manualRecoveryRequired)
        XCTAssertTrue(recovery.locations.contains(saved))
        XCTAssertEqual(try String(contentsOf: saved, encoding: .utf8), "existing")
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "original")
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
    }

    func testRollbackDoesNotOverwriteRecreatedSourceAndReportsStagedOriginal() throws {
        let source = try makeChild("src")
        try write("note.txt", "original", in: source)
        try write("note.txt", "existing")
        let url = source.appendingPathComponent("note.txt")
        let target = root.appendingPathComponent("note.txt")
        let manager = FaultFileManager()
        var stagedSource: URL?
        var attemptedInstall = false
        manager.beforeMove = { from, to in
            if from == url { stagedSource = to }
            if to == target && !attemptedInstall {
                attemptedInstall = true
                try Data("created by another app".utf8).write(to: url)
                throw FileOpError("Injected install failure")
            }
        }

        let report = makeOps(same: true, fileManager: manager).transfer(
            urls: [url], to: root, moving: true, resolve: { _ in .replace }
        )

        let saved = try XCTUnwrap(stagedSource)
        let recovery = try XCTUnwrap(report.items[0].recovery)
        XCTAssertEqual(recovery.status, .manualRecoveryRequired)
        XCTAssertTrue(recovery.locations.contains(saved))
        XCTAssertEqual(try String(contentsOf: saved, encoding: .utf8), "original")
        XCTAssertEqual(try text("note.txt"), "existing")
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "created by another app")
        XCTAssertEqual(report.completedSources, [])
    }

    func testFailedCrossVolumeCopyDoesNotTrashSourceOrPublishPartialDestination() throws {
        let source = try makeChild("src")
        try write("note.txt", "original", in: source)
        let url = source.appendingPathComponent("note.txt")
        let manager = FaultFileManager()
        manager.beforeCopy = { _, to in
            try Data("partial".utf8).write(to: to)
            throw FileOpError("Injected copy failure")
        }

        let report = makeOps(same: false, fileManager: manager).transfer(
            urls: [url], to: root, moving: true, resolve: { _ in .replace }
        )

        XCTAssertEqual(report.items[0].status, .failed)
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "original")
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("note.txt").path))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), ["src"])
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: bin.path), [])
    }

    func testCrossVolumeSourceTrashFailureKeepsBothCopiesAndCutItem() throws {
        let source = try makeChild("src")
        try write("note.txt", "original", in: source)
        let url = source.appendingPathComponent("note.txt")
        let ops = FileOps(sameVolume: { _, _ in false }, trash: { _ in
            throw FileOpError("Injected Trash failure")
        })

        let report = ops.transfer(urls: [url], to: root, moving: true, resolve: { _ in .replace })

        XCTAssertEqual(report.items[0].status, .failed)
        XCTAssertEqual(report.completedSources, [])
        XCTAssertEqual(try text("note.txt"), "original")
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "original")
        XCTAssertTrue(report.items[0].recovery?.locations.contains(url) == true)
        XCTAssertTrue(report.items[0].recovery?.locations.contains(root.appendingPathComponent("note.txt")) == true)
    }

    func testSuccessfulReplacementWithTrashFailureReportsPreservedBackup() throws {
        let source = try makeChild("src")
        try write("note.txt", "original", in: source)
        try write("note.txt", "existing")
        let url = source.appendingPathComponent("note.txt")
        let ops = FileOps(sameVolume: { _, _ in true }, trash: { _ in
            throw FileOpError("Injected backup Trash failure")
        })

        let report = ops.transfer(urls: [url], to: root, moving: true, resolve: { _ in .replace })

        XCTAssertEqual(report.completedSources, [url])
        XCTAssertEqual(try text("note.txt"), "original")
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        let recovery = try XCTUnwrap(report.items[0].recovery)
        XCTAssertEqual(recovery.status, .manualRecoveryRequired)
        let backup = try XCTUnwrap(recovery.locations.first)
        XCTAssertEqual(try String(contentsOf: backup, encoding: .utf8), "existing")
    }

    func testPartialCopyCleanupFailureReportsArtifact() throws {
        let source = try makeChild("src")
        try write("note.txt", "original", in: source)
        let url = source.appendingPathComponent("note.txt")
        let manager = FaultFileManager()
        var partial: URL?
        manager.beforeCopy = { _, to in
            partial = to
            try Data("partial".utf8).write(to: to)
            throw FileOpError("Injected copy failure")
        }
        manager.beforeRemove = { _ in throw FileOpError("Injected cleanup failure") }

        let report = makeOps(same: false, fileManager: manager).transfer(
            urls: [url], to: root, moving: false, resolve: { _ in .replace }
        )

        let recovery = try XCTUnwrap(report.items[0].recovery)
        XCTAssertEqual(recovery.status, .manualRecoveryRequired)
        let artifact = try XCTUnwrap(partial)
        XCTAssertTrue(recovery.locations.contains(artifact))
        XCTAssertEqual(try String(contentsOf: artifact, encoding: .utf8), "partial")
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "original")
    }

    func testRenameReplacementFailureRestoresBothItems() throws {
        try write("old.txt", "original")
        try write("new.txt", "existing")
        let target = root.appendingPathComponent("new.txt")
        let manager = FaultFileManager()
        var attemptedInstall = false
        manager.beforeMove = { _, to in
            if to == target && !attemptedInstall {
                attemptedInstall = true
                throw FileOpError("Injected rename failure")
            }
        }

        XCTAssertThrowsError(try makeOps(same: true, fileManager: manager).rename(
            url: root.appendingPathComponent("old.txt"), to: "new.txt", resolve: { _ in .replace }
        ))

        XCTAssertEqual(try text("old.txt"), "original")
        XCTAssertEqual(try text("new.txt"), "existing")
    }


    private func makeOps(same: Bool, fileManager: FileManager = .default) -> FileOps {
        var ops = FileOps(
            fileManager: fileManager,
            sameVolume: { _, _ in same },
            trash: { url in
                let dest = self.bin.appendingPathComponent(url.lastPathComponent)
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.moveItem(at: url, to: dest)
            }
        )
        if fileManager is FaultFileManager {
            ops.copy = { source, destination, cancellation, _ in
                try cancellation?.check()
                try fileManager.copyItem(at: source, to: destination)
                try cancellation?.check()
            }
        }
        return ops
    }

    private func makeChild(_ name: String) throws -> URL {
        let url = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func write(_ name: String, _ body: String, in directory: URL? = nil) throws {
        let url = (directory ?? root).appendingPathComponent(name)
        try Data(body.utf8).write(to: url)
    }

    private func text(_ name: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(name), encoding: .utf8)
    }
}

private final class FaultFileManager: FileManager, @unchecked Sendable {
    var beforeCopy: ((URL, URL) throws -> Void)?
    var beforeMove: ((URL, URL) throws -> Void)?
    var beforeRemove: ((URL) throws -> Void)?

    override func copyItem(at srcURL: URL, to dstURL: URL) throws {
        try beforeCopy?(srcURL, dstURL)
        try super.copyItem(at: srcURL, to: dstURL)
    }

    override func moveItem(at srcURL: URL, to dstURL: URL) throws {
        try beforeMove?(srcURL, dstURL)
        try super.moveItem(at: srcURL, to: dstURL)
    }

    override func removeItem(at URL: URL) throws {
        try beforeRemove?(URL)
        try super.removeItem(at: URL)
    }
}
