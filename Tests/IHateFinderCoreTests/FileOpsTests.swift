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
        try ops.transfer(
            urls: [source.appendingPathComponent("note.txt")],
            to: root,
            moving: false,
            resolve: { _ in .keepBoth }
        )
        XCTAssertEqual(try text("note.txt"), "old")
        XCTAssertEqual(try text("note (1).txt"), "new")

        try ops.transfer(
            urls: [source.appendingPathComponent("note.txt")],
            to: root,
            moving: false,
            resolve: { _ in .skip }
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("note (2).txt").path))
    }

    func testReplaceSendsExistingToTrash() throws {
        try write("note.txt", "old")
        let source = try makeChild("src")
        try write("note.txt", "new", in: source)
        let ops = makeOps(same: true)
        try ops.transfer(
            urls: [source.appendingPathComponent("note.txt")],
            to: root,
            moving: false,
            resolve: { _ in .replace }
        )
        XCTAssertEqual(try text("note.txt"), "new")
        XCTAssertEqual(try String(contentsOf: bin.appendingPathComponent("note.txt"), encoding: .utf8), "old")
    }

    func testSameVolumeMoveDoesNotTrashSource() throws {
        let source = try makeChild("src")
        try write("a.txt", "body", in: source)
        var trashed = false
        let ops = FileOps(sameVolume: { _, _ in true }, trash: { _ in trashed = true })
        try ops.transfer(
            urls: [source.appendingPathComponent("a.txt")],
            to: root,
            moving: true,
            resolve: { _ in .skip }
        )
        XCTAssertFalse(trashed)
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.appendingPathComponent("a.txt").path))
        XCTAssertEqual(try text("a.txt"), "body")
    }

    func testCrossVolumeMoveCopiesThenTrashes() throws {
        let source = try makeChild("src")
        try write("a.txt", "body", in: source)
        let ops = makeOps(same: false)
        try ops.transfer(
            urls: [source.appendingPathComponent("a.txt")],
            to: root,
            moving: true,
            resolve: { _ in .skip }
        )
        XCTAssertEqual(try text("a.txt"), "body")
        XCTAssertEqual(try String(contentsOf: bin.appendingPathComponent("a.txt"), encoding: .utf8), "body")
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.appendingPathComponent("a.txt").path))
    }

    func testCutPasteIntoSameFolderLeavesFile() throws {
        try write("a.txt", "body")
        let ops = makeOps(same: true)
        let url = root.appendingPathComponent("a.txt")
        try ops.paste(urls: [url], cut: true, into: root, resolve: { _ in .replace })
        XCTAssertEqual(try text("a.txt"), "body")
        XCTAssertFalse(FileManager.default.fileExists(atPath: bin.appendingPathComponent("a.txt").path))
    }

    func testCopyIntoSameFolderKeepsBoth() throws {
        try write("note.txt", "body")
        let ops = makeOps(same: true)
        let url = root.appendingPathComponent("note.txt")
        try ops.paste(urls: [url], cut: false, into: root, resolve: { _ in .keepBoth })
        XCTAssertEqual(try text("note.txt"), "body")
        XCTAssertEqual(try text("note (1).txt"), "body")
    }

    func testCopyIntoSameFolderReplaceLeavesOriginal() throws {
        try write("note.txt", "body")
        let ops = makeOps(same: true)
        let url = root.appendingPathComponent("note.txt")
        try ops.paste(urls: [url], cut: false, into: root, resolve: { _ in .replace })
        XCTAssertEqual(try text("note.txt"), "body")
        XCTAssertFalse(FileManager.default.fileExists(atPath: bin.appendingPathComponent("note.txt").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("note (1).txt").path))
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

    func testNavigateBackAndInvalidPath() throws {
        let child = try makeChild("docs")
        let session = try BrowserSession(url: root, ops: makeOps(same: true))
        XCTAssertTrue(session.navigate(to: child))
        XCTAssertEqual(session.url.standardizedFileURL.path, child.standardizedFileURL.path)
        XCTAssertTrue(session.goBack())
        XCTAssertEqual(session.url.standardizedFileURL.path, root.standardizedFileURL.path)
        XCTAssertTrue(session.goForward())
        XCTAssertFalse(session.navigate(to: root.appendingPathComponent("missing")))
        XCTAssertEqual(session.url.standardizedFileURL.path, child.standardizedFileURL.path)
        XCTAssertTrue(session.goUp())
        XCTAssertEqual(session.url.standardizedFileURL.path, root.standardizedFileURL.path)
    }

    private func makeOps(same: Bool) -> FileOps {
        FileOps(
            sameVolume: { _, _ in same },
            trash: { url in
                let dest = self.bin.appendingPathComponent(url.lastPathComponent)
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.moveItem(at: url, to: dest)
            }
        )
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
