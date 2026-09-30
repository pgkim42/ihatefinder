import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var browser: BrowserWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        let browser = BrowserWindowController()
        self.browser = browser
        browser.showWindow(nil)
        if CommandLine.arguments.contains("--repro-focus") {
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
        ]))
        main.addItem(menu("편집", [
            item("잘라두기", #selector(BrowserWindowController.cut(_:)), "x", .command),
            item("복사", #selector(BrowserWindowController.copy(_:)), "c", .command),
            item("붙여넣기", #selector(BrowserWindowController.paste(_:)), "v", .command),
            item("모두 선택", #selector(NSText.selectAll(_:)), "a", .command),
            item("이름 바꾸기", #selector(BrowserWindowController.beginRename), "", []),
        ]))
        main.addItem(menu("이동", [
            item("뒤로", #selector(BrowserWindowController.goBackAction), "[", .command),
            item("앞으로", #selector(BrowserWindowController.goForwardAction), "]", .command),
            item("위", #selector(BrowserWindowController.goUpAction), upArrow, .command),
        ]))
        main.addItem(menu("보기", [
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
