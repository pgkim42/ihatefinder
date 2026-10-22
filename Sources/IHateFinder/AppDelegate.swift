import AppKit
import IHateFinderCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var browsers: [BrowserWindowController] = []
    private weak var lastActiveBrowser: BrowserWindowController?
    private let clipboard: FileClipboard
    private let makeBrowser: (FileClipboard) -> BrowserWindowController
    let operationHistory = FileOperationHistory()
    private(set) var historyWindowController: FileOperationHistoryWindowController?
    private var nextWindowNumber = 1

    init(
        pasteboard: NSPasteboard = .general,
        makeBrowser: ((FileClipboard) -> BrowserWindowController)? = nil
    ) {
        clipboard = FileClipboard(pasteboard: pasteboard)
        let workspaceStore = WorkspaceStore()
        self.makeBrowser = makeBrowser ?? { BrowserWindowController(workspaceStore: workspaceStore, clipboard: $0) }
        super.init()
        operationHistory.onChange = { [weak self] in
            self?.historyWindowController?.reloadHistory()
        }
    }

    var activeBrowser: BrowserWindowController? {
        for window in [NSApp.keyWindow, NSApp.mainWindow] {
            if let window, let browser = browsers.first(where: { $0.window === window }) {
                return browser
            }
        }
        return lastActiveBrowser ?? browsers.last
    }

    @discardableResult
    func createBrowser() -> BrowserWindowController {
        let browser = makeBrowser(clipboard)
        browser.operationHistory = operationHistory
        browser.historyWindowTitle = String(nextWindowNumber)
        nextWindowNumber += 1
        browsers.append(browser)
        lastActiveBrowser = browser
        browser.shouldSaveWorkspace = { [weak self, weak browser] in
            guard let self, let browser else { return false }
            return self.browsers.contains(where: { $0 === browser }) && self.activeBrowser === browser
        }
        browser.onBecameActive = { [weak self, weak browser] in
            self?.lastActiveBrowser = browser
        }
        browser.onClose = { [weak self, weak browser] in
            guard let self, let browser else { return }
            if self.activeBrowser === browser || self.browsers.count == 1 {
                browser.saveWorkspace(force: true)
            }
            self.browsers.removeAll { $0 === browser }
            if self.lastActiveBrowser === browser { self.lastActiveBrowser = self.browsers.last }
            if self.browsers.isEmpty { self.historyWindowController?.close() }
        }
        browser.showWindow(nil)
        browser.window?.makeKeyAndOrderFront(nil)
        return browser
    }

    @objc func newWindow(_ sender: Any?) {
        createBrowser()
    }

    @objc func showOperationHistory(_ sender: Any?) {
        if historyWindowController == nil {
            historyWindowController = FileOperationHistoryWindowController(history: operationHistory)
        }
        historyWindowController?.reloadHistory()
        historyWindowController?.showWindow(nil)
        historyWindowController?.window?.makeKeyAndOrderFront(nil)
    }
    /// Requests that arrived before the window existed. Drained once after `showWindow`.
    private(set) var pendingOpens: [OpenRequest] = []
    private let isRepro = CommandLine.arguments.contains("--repro-focus")

    /// Registered this early so a cold launch by "Show in Finder" is not lost.
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleReveal(_:withReplyEvent:)),
            forEventClass: AEEventClass(kAEMiscStandards),
            andEventID: AEEventID(kAEMakeObjectsVisible)
        )
    }

    @objc func handleReveal(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        receive(urls: OpenRequest.urls(fromAppleEventDirectObject: event.paramDescriptor(forKeyword: keyDirectObject)))
    }

    /// Open-documents (odoc) arrives here.
    func application(_ application: NSApplication, open urls: [URL]) {
        receive(urls: urls)
    }

    private func receive(urls: [URL]) {
        guard !isRepro, let request = OpenRequest.make(urls: urls) else { return }
        route(request)
    }

    func route(_ request: OpenRequest) {
        if let browser = activeBrowser {
            browser.handleOpen(request)
        } else {
            pendingOpens.append(request)
        }
    }

    func drainPendingOpens(into handle: (OpenRequest) -> Void) {
        let queued = pendingOpens
        pendingOpens = []
        queued.forEach(handle)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        let repro = isRepro
        let browser: BrowserWindowController
        if repro {
            browser = BrowserWindowController(workspaceStore: nil, pasteboard: NSPasteboard(name: .init("IHateFinder.repro.\(UUID().uuidString)")))
            browser.showWindow(nil)
        } else {
            browser = createBrowser()
        }
        drainPendingOpens(into: browser.handleOpen)
        if repro {
            let report = browser.runFocusRepro()
            FileHandle.standardOutput.write(Data(report.utf8))
            FileHandle.standardOutput.write(Data("\n".utf8))
            exit(0)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if let busyBrowser = browsers.first(where: \.isFileOperationRunning) {
            busyBrowser.window?.makeKeyAndOrderFront(nil)
            _ = busyBrowser.canClose()
            return .terminateCancel
        }
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        activeBrowser?.saveWorkspace(force: true)
    }

    func buildMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "IHateFinder 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appItem.submenu = appMenu
        main.addItem(appItem)

        main.addItem(menu("파일", [
            item("새 창", #selector(newWindow(_:)), "n", .command),
            item("새 폴더", #selector(BrowserWindowController.makeFolder), "n", [.command, .shift]),
            item("새 텍스트 파일", #selector(BrowserWindowController.makeTextFile), "n", [.command, .option]),
            item("현재 폴더를 즐겨찾기에 추가", #selector(BrowserWindowController.addCurrentFolderToFavorites), "", []),
        ]))
        main.addItem(menu("편집", [
            item("실행 취소", Selector(("undo:")), "z", .command),
            item("다시 실행", Selector(("redo:")), "z", [.command, .shift]),
            item("막힌 실행 취소 다시 시도", #selector(BrowserWindowController.retryBlockedUndo), "", []),
            .separator(),
            item("잘라두기", #selector(BrowserWindowController.cut(_:)), "x", .command),
            item("복사", #selector(BrowserWindowController.copy(_:)), "c", .command),
            item("붙여넣기", #selector(BrowserWindowController.paste(_:)), "v", .command),
            .separator(),
            item("반대쪽으로 복사 (F5)", #selector(BrowserWindowController.copyToOther), "", []),
            item("반대쪽으로 이동 (F6)", #selector(BrowserWindowController.moveToOther), "", []),
            .separator(),
            item("모두 선택", #selector(NSText.selectAll(_:)), "a", .command),
            item("이름 바꾸기", #selector(BrowserWindowController.beginRename), "", []),
            item("이 폴더에서 이름 거르기", #selector(BrowserWindowController.findInFolder), "f", .command),
            item("하위 폴더에서 이름 검색", #selector(BrowserWindowController.showRecursiveSearch), "f", [.command, .shift]),
        ]))
        main.addItem(menu("이동", [
            item("뒤로", #selector(BrowserWindowController.goBackAction), "[", .command),
            item("앞으로", #selector(BrowserWindowController.goForwardAction), "]", .command),
            item("위", #selector(BrowserWindowController.goUpAction), upArrow, .command),
        ]))
        main.addItem(menu("보기", [
            item("미리보기 (Space)", #selector(BrowserWindowController.previewSelection), "y", .command),
            item("숨김 파일", #selector(BrowserWindowController.toggleHidden), ".", [.command, .shift]),
            item("양쪽 창", #selector(BrowserWindowController.toggleDual), "", []),
            item("축소판 보기", #selector(BrowserWindowController.toggleThumbnails), "", []),
            .separator(),
            item("파일 작업 기록", #selector(showOperationHistory(_:)), "", []),
        ]))
        main.addItem(menu("창", [
            item("닫기", #selector(NSWindow.performClose(_:)), "w", .command),
        ]))
        NSApp.mainMenu = main
    }

    private var upArrow: String {
        String(UnicodeScalar(NSUpArrowFunctionKey)!)
    }

    private func menu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
        let menu = NSMenu(title: title)
        items.forEach(menu.addItem)
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }

    private func item(_ title: String, _ action: Selector, _ key: String, _ mask: NSEvent.ModifierFlags) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = mask
        if action == #selector(newWindow(_:)) || action == #selector(showOperationHistory(_:)) { item.target = self }
        return item
    }
}
