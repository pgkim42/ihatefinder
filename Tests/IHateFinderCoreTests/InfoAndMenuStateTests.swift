import XCTest
@testable import IHateFinderCore

final class InfoAndMenuStateTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("info-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: root)
    }

    func testFileInfoHasSizePermissionsAndNoCount() throws {
        let file = root.appendingPathComponent("a.txt")
        try Data("12345".utf8).write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o640], ofItemAtPath: file.path)

        let model = try XCTUnwrap(InfoModel.make(url: file))

        XCTAssertEqual(model.name, "a.txt")
        XCTAssertFalse(model.isDirectory)
        XCTAssertEqual(model.size, 5)
        XCTAssertNil(model.itemCount)
        XCTAssertEqual(model.permissions, "rw-r----- (640)")
        XCTAssertEqual(model.path, file.path)
        XCTAssertNotNil(model.modified)
        XCTAssertNotNil(model.created)
    }

    func testFolderInfoCountsOnlyTopLevelItems() throws {
        let folder = root.appendingPathComponent("dir", isDirectory: true)
        let inner = folder.appendingPathComponent("inner", isDirectory: true)
        try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: folder.appendingPathComponent("one.txt"))
        try Data("x".utf8).write(to: inner.appendingPathComponent("deep.txt"))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.path)

        let model = try XCTUnwrap(InfoModel.make(url: folder))

        XCTAssertTrue(model.isDirectory)
        XCTAssertNil(model.size)
        XCTAssertEqual(model.itemCount, 2)
        XCTAssertEqual(model.permissions, "rwxr-xr-x (755)")
    }

    func testCountCanBeSkippedForTheMainThread() throws {
        let folder = root.appendingPathComponent("dir", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        XCTAssertNil(try XCTUnwrap(InfoModel.make(url: folder, countItems: false)).itemCount)
    }

    func testMissingItemHasNoModel() {
        XCTAssertNil(InfoModel.make(url: root.appendingPathComponent("nope")))
    }

    func testPermissionText() {
        XCTAssertEqual(InfoModel.permissionText(0o000), "--------- (000)")
        XCTAssertEqual(InfoModel.permissionText(0o777), "rwxrwxrwx (777)")
        XCTAssertEqual(InfoModel.permissionText(0o4755), "rwxr-xr-x (755)")
    }

    // MARK: MenuState

    private let a = URL(fileURLWithPath: "/tmp/a")
    private let b = URL(fileURLWithPath: "/tmp/b")

    func testEmptySelectionDisablesEverythingButTerminal() {
        let state = MenuState.make(selection: [])
        XCTAssertFalse(state.open)
        XCTAssertFalse(state.openWith)
        XCTAssertFalse(state.copyPath)
        XCTAssertFalse(state.compress)
        XCTAssertFalse(state.info)
        XCTAssertFalse(state.trash)
        XCTAssertTrue(state.terminal)
    }

    func testMultiSelectionEnablesCopyPathButNotCompressOrInfo() {
        let state = MenuState.make(selection: [a, b])
        XCTAssertTrue(state.open)
        XCTAssertTrue(state.openWith)
        XCTAssertTrue(state.copyPath)
        XCTAssertFalse(state.compress)
        XCTAssertFalse(state.info)
        XCTAssertTrue(state.terminal)
    }

    func testSingleSelectionEnablesCompressAndInfo() {
        let state = MenuState.make(selection: [a])
        XCTAssertTrue(state.compress)
        XCTAssertTrue(state.info)
    }

    func testPathTextIsNewlineSeparatedPosixPaths() {
        XCTAssertEqual(MenuState.pathText([a, b]), "/tmp/a\n/tmp/b")
        XCTAssertEqual(MenuState.pathText([a]), "/tmp/a")
    }

    func testTerminalFolderIsSelectedFolderElseCurrentFolder() {
        func entry(_ name: String, dir: Bool) -> FileEntry {
            FileEntry(url: URL(fileURLWithPath: "/cur/\(name)"), name: name, isDirectory: dir,
                      size: 0, modified: .distantPast, kind: "", isHidden: false)
        }
        let current = URL(fileURLWithPath: "/cur")
        XCTAssertEqual(MenuState.terminalFolder(selection: [entry("d", dir: true)], current: current).path, "/cur/d")
        XCTAssertEqual(MenuState.terminalFolder(selection: [entry("f", dir: false)], current: current), current)
        XCTAssertEqual(MenuState.terminalFolder(selection: [], current: current), current)
        XCTAssertEqual(MenuState.terminalFolder(selection: [entry("d", dir: true), entry("e", dir: true)], current: current), current)
    }

    func testCommonAppsKeepsOnlySharedAppsWithDefaultFirst() {
        let textEdit = URL(fileURLWithPath: "/Applications/TextEdit.app")
        let code = URL(fileURLWithPath: "/Applications/Code.app")
        let preview = URL(fileURLWithPath: "/Applications/Preview.app")
        let apps = MenuState.commonApps([[textEdit, code, preview], [preview, code]], defaultApp: code)
        XCTAssertEqual(apps, [code, preview])
        XCTAssertEqual(MenuState.commonApps([], defaultApp: nil), [])
    }
}
