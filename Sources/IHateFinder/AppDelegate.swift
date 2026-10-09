import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var browser: BrowserWindowController?
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
        if let browser {
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
        let browser = repro
            ? BrowserWindowController(workspaceStore: nil, pasteboard: NSPasteboard(name: .init("IHateFinder.repro.\(UUID().uuidString)")))
            : BrowserWindowController()
        self.browser = browser
        browser.showWindow(nil)
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
        browser?.canClose() == false ? .terminateCancel : .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        browser?.saveWorkspace()
    }

    private func buildMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "IHateFinder 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appItem.submenu = appMenu
        main.addItem(appItem)

        main.addItem(menu("파일", [
            item("새 폴더", #selector(BrowserWindowController.makeFolder), "n", [.command, .shift]),
            item("새 텍스트 파일", #selector(BrowserWindowController.makeTextFile), "n", [.command, .option]),
            item("현재 폴더를 즐겨찾기에 추가", #selector(BrowserWindowController.addCurrentFolderToFavorites), "", []),
        ]))
        main.addItem(menu("편집", [
            item("실행 취소", Selector(("undo:")), "z", .command),
            item("다시 실행", Selector(("redo:")), "z", [.command, .shift]),
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
        return item
    }
}
