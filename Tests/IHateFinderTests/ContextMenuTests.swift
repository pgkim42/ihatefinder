import AppKit
import XCTest
import IHateFinderCore
@testable import IHateFinder

final class ContextMenuTests: XCTestCase {
    private func resolve(_ keyCode: UInt16, _ flags: NSEvent.ModifierFlags, _ context: KeyContext) -> KeyCommand? {
        KeyCommand.resolve(keyCode: keyCode, characters: "\r", flags: flags, context: context)
    }

    func testOptionReturnShowsInfoOnlyOnTheList() {
        let table = KeyContext(tableIsResponder: true, textIsResponder: false)
        let text = KeyContext(tableIsResponder: false, textIsResponder: true)
        XCTAssertEqual(resolve(36, .option, table), .info)
        XCTAssertNil(resolve(36, .option, text))
        XCTAssertEqual(resolve(36, [], table), .open)
        XCTAssertNil(resolve(36, [.option, .shift], table))
    }

    @MainActor
    private func makeBrowser(_ t: TestBrowser) async throws -> FilePaneController {
        let pane = t.browser.left
        _ = pane.view
        let deadline = Date().addingTimeInterval(5)
        while pane.session.isLoading || pane.session.entries.isEmpty, Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        return pane
    }

    @MainActor
    private func withBrowser(files: [String] = [], folders: [String] = [], _ body: (TestBrowser, FilePaneController) async throws -> Void) async throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let t = try makeTestBrowser(root: root)
        for name in files { try Data(name.utf8).write(to: t.left.appendingPathComponent(name)) }
        for name in folders { try FileManager.default.createDirectory(at: t.left.appendingPathComponent(name), withIntermediateDirectories: true) }
        let pane = try await makeBrowser(t)
        try await body(t, pane)
    }

    @MainActor
    func testMenuOrderAndEnablementFollowSelection() async throws {
        try await withBrowser(files: ["a.txt", "b.txt"]) { _, pane in
            let menu = try XCTUnwrap(pane.table.menu)
            let titles = menu.items.map { $0.isSeparatorItem ? "-" : $0.title }
            XCTAssertEqual(titles, [
                "열기", "다른 앱으로 열기", "-", "새 폴더", "새 텍스트 파일", "-", "잘라두기", "복사", "붙여넣기",
                "-", "이름 바꾸기", "휴지통으로 옮기기", "-", "압축", "-", "경로 복사", "정보 보기", "터미널에서 열기",
            ])
            func item(_ title: String) -> NSMenuItem { menu.items.first { $0.title == title }! }

            pane.table.deselectAll(nil)
            pane.refreshMenu(menu)
            XCTAssertFalse(item("열기").isEnabled)
            XCTAssertFalse(item("다른 앱으로 열기").isEnabled)
            XCTAssertFalse(item("경로 복사").isEnabled)
            XCTAssertFalse(item("압축").isEnabled)
            XCTAssertTrue(item("터미널에서 열기").isEnabled)

            pane.table.selectAll(nil)
            pane.refreshMenu(menu)
            XCTAssertTrue(item("열기").isEnabled)
            XCTAssertTrue(item("경로 복사").isEnabled)
            XCTAssertFalse(item("압축").isEnabled)
            XCTAssertFalse(item("정보 보기").isEnabled)

            pane.table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            pane.refreshMenu(menu)
            XCTAssertTrue(item("압축").isEnabled)
            XCTAssertTrue(item("정보 보기").isEnabled)
        }
    }

    @MainActor
    func testOpenWithSubmenuListsCommonAppsDefaultFirstAndOpensChosenApp() async throws {
        try await withBrowser(files: ["a.txt"]) { _, pane in
            let textEdit = URL(fileURLWithPath: "/Applications/TextEdit.app")
            let preview = URL(fileURLWithPath: "/Applications/Preview.app")
            pane.appsForOpening = { _ in ([textEdit, preview], preview) }
            var opened: ([URL], URL)?
            pane.openWithApp = { urls, app in opened = (urls, app) }
            pane.table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            let menu = try XCTUnwrap(pane.table.menu)
            pane.refreshMenu(menu)

            let sub = try XCTUnwrap(menu.items.first { $0.title == "다른 앱으로 열기" }?.submenu)
            XCTAssertEqual(sub.items.count, 2)
            XCTAssertTrue(sub.items[0].title.hasSuffix("(기본)"))
            XCTAssertFalse(sub.items[1].title.contains("(기본)"))

            pane.openWithChosen(sub.items[1])
            XCTAssertEqual(opened?.1, textEdit)
            XCTAssertEqual(opened?.0.map(\.lastPathComponent), ["a.txt"])
        }
    }

    @MainActor
    func testOpenWithSubmenuShowsDisabledNoneWhenNoApp() async throws {
        try await withBrowser(files: ["a.txt"]) { _, pane in
            pane.appsForOpening = { _ in ([], nil) }
            pane.table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            let menu = try XCTUnwrap(pane.table.menu)
            pane.refreshMenu(menu)
            let sub = try XCTUnwrap(menu.items.first { $0.title == "다른 앱으로 열기" }?.submenu)
            XCTAssertEqual(sub.items.map(\.title), ["없음"])
            XCTAssertFalse(sub.items[0].isEnabled)
        }
    }

    @MainActor
    func testTerminalOpensSelectedFolderOtherwiseCurrentFolder() async throws {
        try await withBrowser(files: ["f.txt"], folders: ["sub"]) { t, pane in
            var opened: [URL] = []
            pane.openInTerminal = { opened.append($0) }
            let entries = pane.session.entries
            let folderRow = try XCTUnwrap(entries.firstIndex { $0.isDirectory })
            let fileRow = try XCTUnwrap(entries.firstIndex { !$0.isDirectory })

            pane.table.selectRowIndexes(IndexSet(integer: folderRow), byExtendingSelection: false)
            pane.openInTerminalAction()
            pane.table.selectRowIndexes(IndexSet(integer: fileRow), byExtendingSelection: false)
            pane.openInTerminalAction()
            pane.table.deselectAll(nil)
            pane.openInTerminalAction()

            XCTAssertEqual(opened.map(\.lastPathComponent), ["sub", "left", "left"])
            _ = t
        }
    }

    @MainActor
    func testCopyPathWritesTextAndEndsFileCutIntent() async throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        _ = NSApplication.shared
        let board = NSPasteboard(name: .init("IHateFinder.test.\(UUID().uuidString)"))
        let left = root.appendingPathComponent("left", isDirectory: true)
        let right = root.appendingPathComponent("right", isDirectory: true)
        for d in [left, right] { try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true) }
        try Data("a".utf8).write(to: left.appendingPathComponent("a.txt"))
        try Data("b".utf8).write(to: left.appendingPathComponent("b.txt"))
        let browser = BrowserWindowController(
            workspaceStore: nil, pasteboard: board,
            makeOps: { FileOps(sameVolume: FileOps.volumesMatch, moveToTrash: { _ in nil }) },
            initialURLs: (left: left, right: right)
        )
        let pane = browser.left
        _ = pane.view
        let deadline = Date().addingTimeInterval(5)
        while pane.session.isLoading || pane.session.entries.count < 2, Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        pane.table.selectAll(nil)
        browser.cut(nil)
        XCTAssertTrue(browser.isCut(left.appendingPathComponent("a.txt")))

        pane.table.selectAll(nil)
        pane.copyPathSelection()

        let text = try XCTUnwrap(board.string(forType: .string))
        XCTAssertEqual(text.split(separator: "\n").map { URL(fileURLWithPath: String($0)).lastPathComponent }.sorted(), ["a.txt", "b.txt"])
        XCTAssertTrue(text.hasPrefix("/"))
        XCTAssertNil(board.string(forType: .fileURL))
        XCTAssertFalse(browser.isCut(left.appendingPathComponent("a.txt")))
    }

    @MainActor
    func testInfoActionShowsSheetForSingleSelectionOnly() async throws {
        try await withBrowser(files: ["a.txt", "b.txt"]) { _, pane in
            var shown: [URL] = []
            pane.showInfoSheet = { shown.append($0) }
            pane.table.selectAll(nil)
            pane.showInfo()
            XCTAssertTrue(shown.isEmpty)
            pane.table.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false)
            pane.showInfo()
            XCTAssertEqual(shown.map(\.lastPathComponent), ["b.txt"])
        }
    }

    @MainActor
    func testInfoRowsCoverEveryField() {
        let model = InfoModel(name: "d", kind: "폴더", isDirectory: true, size: nil, itemCount: 3,
                              created: Date(timeIntervalSince1970: 0), modified: nil, path: "/x/d", permissions: "rwxr-xr-x (755)")
        let labels = InfoPanel.rows(for: model).map(\.0)
        XCTAssertEqual(labels, ["이름", "종류", "항목 수", "만든 날짜", "수정한 날짜", "경로", "권한"])
        XCTAssertEqual(InfoPanel.rows(for: model).first { $0.0 == "항목 수" }?.1, "3개")
    }

    // MARK: Compress job

    @MainActor
    func testCompressRunsAsBusyJobRecordsUndoAndUndoTrashesZip() async throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let t = try makeTestBrowser(root: root)
        try Data("hi".utf8).write(to: t.left.appendingPathComponent("x"))
        let pane = try await makeBrowser(t)
        t.browser.compressRunner = { _, destination in
            try Data("zip".utf8).write(to: destination)
            return CompressProcess(isRunning: { false }, terminate: {}, exitStatus: { 0 }, errorOutput: { "" })
        }

        pane.table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        pane.compressSelection()
        XCTAssertTrue(t.browser.isFileOperationRunning)
        try await t.browser.waitIdle()

        let zip = t.left.appendingPathComponent("x.zip")
        XCTAssertTrue(FileManager.default.fileExists(atPath: zip.path))
        XCTAssertEqual(t.browser.undoJournal.count, 1)
        XCTAssertEqual(t.browser.undoJournal.peek?.title, "압축")

        t.browser.undoFileOperation()
        try await t.browser.waitIdle()

        XCTAssertFalse(FileManager.default.fileExists(atPath: zip.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: t.left.appendingPathComponent("x").path))
        XCTAssertEqual(t.browser.lastUndoReport?.undone.count, 1)
    }

    @MainActor
    func testCompressFailureAddsNoUndoRecord() async throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let t = try makeTestBrowser(root: root)
        try Data("hi".utf8).write(to: t.left.appendingPathComponent("x"))
        let pane = try await makeBrowser(t)
        t.browser.compressRunner = { _, _ in throw FileOpError("no") }
        pane.table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)

        pane.compressSelection()
        try await t.browser.waitIdle()

        XCTAssertEqual(t.browser.undoJournal.count, 0)
        guard case .failure? = t.browser.lastCompressResult else { return XCTFail("expected failure") }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: t.left.path), ["x"])
    }
}
