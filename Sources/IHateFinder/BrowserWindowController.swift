import AppKit
import IHateFinderCore

final class BrowserWindowController: NSWindowController, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private let left: FilePaneController
    private let right: FilePaneController
    private let sidebar = NSTableView()
    private let status = NSTextField(labelWithString: "")
    private let paneSplit = NSSplitView()
    private var places: [SidebarItem] = []
    private var focused: FilePaneController
    private var dual = false
    private var busy = false
    private var held: Held?
    private var rememberedChoice: NameConflict?
    private var keyMonitor: Any?

    private struct Held {
        var urls: [URL]
        var cut: Bool
    }

    init() {
        let leftSession = Self.makeSession()
        let rightSession = Self.makeSession()
        left = FilePaneController(session: leftSession)
        right = FilePaneController(session: rightSession)
        focused = left
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1080, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "IHateFinder"
        window.minSize = NSSize(width: 760, height: 420)
        window.center()
        super.init(window: window)
        left.browser = self
        right.browser = self
        window.delegate = self
        installContent()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event) ?? event
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshPlaces),
            name: NSWorkspace.didMountNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshPlaces),
            name: NSWorkspace.didUnmountNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    deinit {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
    }

    func updateStatus() {
        guard !busy else { return }
        status.stringValue = focused.summary()
        window?.title = focused.session.url.lastPathComponent
        left.setFocusedLook(focused === left)
        right.setFocusedLook(dual && focused === right)
    }

    func focus(_ pane: FilePaneController) {
        focused = pane
        updateStatus()
    }

    func runFocusRepro() -> String {
        toggleDual()
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("ihatefinder-focus-\(UUID().uuidString)", isDirectory: true)
        let leftDir = root.appendingPathComponent("left", isDirectory: true)
        let rightDir = root.appendingPathComponent("right", isDirectory: true)
        try? fm.createDirectory(at: leftDir, withIntermediateDirectories: true)
        try? fm.createDirectory(at: rightDir, withIntermediateDirectories: true)
        fm.createFile(atPath: leftDir.appendingPathComponent("left-only.txt").path, contents: Data("L".utf8))
        fm.createFile(atPath: rightDir.appendingPathComponent("right-only.txt").path, contents: Data("R".utf8))
        _ = left.session.navigate(to: leftDir)
        _ = right.session.navigate(to: rightDir)
        left.show()
        right.show()
        left.table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        right.table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        window?.makeFirstResponder(right.table)
        let rightIsResponder = window?.firstResponder === right.table
        let deleteFires = focused.tableIsResponder
        let keyTarget = focused.selectedURLs().first?.lastPathComponent ?? "none"
        copy(nil)
        let copied = held?.urls.first?.lastPathComponent ?? "none"
        let pasteDest = focused.session.url.lastPathComponent
        return [
            "firstResponderRight=\(rightIsResponder)",
            "copied=\(copied)",
            "pasteDest=\(pasteDest)",
            "deleteFires=\(deleteFires)",
            "deleteTarget=\(keyTarget)",
            "f6Source=\(keyTarget)",
        ].joined(separator: "\n")
    }

    func alert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "확인")
        if let window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }

    func isCut(_ url: URL) -> Bool {
        guard let held, held.cut else { return false }
        let path = url.standardizedFileURL.path
        return held.urls.contains { $0.standardizedFileURL.path == path }
    }

    func resolveConflict(_ name: String) -> NameConflict {
        if Thread.isMainThread {
            return askConflict(name)
        }
        return DispatchQueue.main.sync { self.askConflict(name) }
    }

    func run(_ failure: String, after: (() -> Void)? = nil, work: @escaping () throws -> Void) {
        guard !busy else { return }
        busy = true
        rememberedChoice = nil
        status.stringValue = "옮기는 중…"
        DispatchQueue.global(qos: .userInitiated).async {
            var message: String?
            do {
                try work()
            } catch let error as FileOpError {
                message = error.message
            } catch {
                message = "\(failure) \(error.localizedDescription)"
            }
            DispatchQueue.main.async {
                self.busy = false
                if message == nil { after?() }
                self.reloadPanes()
                if let message {
                    self.alert(message)
                }
            }
        }
    }

    func drop(_ urls: [URL], onto dest: URL, copying: Bool) {
        run(copying ? "복사하지 못했습니다." : "옮기지 못했습니다.", after: {
            if !copying { self.forget(urls) }
        }) {
            try self.left.session.ops.transfer(
                urls: urls,
                to: dest,
                moving: !copying,
                resolve: self.resolveConflict
            )
        }
    }

    @objc func makeFolder() { focused.makeFolder() }
    @objc func makeTextFile() { focused.makeTextFile() }
    @objc func trashSelection() { focused.trashSelection() }
    @objc func beginRename() { focused.beginRename() }

    @objc func cut(_ sender: Any?) {
        let urls = focused.selectedURLs()
        guard !urls.isEmpty else { return }
        held = Held(urls: urls, cut: true)
        reloadTables()
    }

    @objc func copy(_ sender: Any?) {
        let urls = focused.selectedURLs()
        guard !urls.isEmpty else { return }
        held = Held(urls: urls, cut: false)
        reloadTables()
    }

    @objc func paste(_ sender: Any?) {
        guard let held else { return }
        let urls = held.urls
        let cut = held.cut
        let dest = focused.session.url
        run(cut ? "옮기지 못했습니다." : "복사하지 못했습니다.", after: {
            if cut { self.held = nil }
        }) {
            try self.focused.session.ops.paste(
                urls: urls,
                cut: cut,
                into: dest,
                resolve: self.resolveConflict
            )
        }
    }

    @objc func goBackAction() { focused.goBack() }
    @objc func goForwardAction() { focused.goForward() }
    @objc func goUpAction() { focused.goUp() }

    @objc func toggleHidden() {
        let hidden = !focused.session.includeHidden
        left.session.includeHidden = hidden
        right.session.includeHidden = hidden
        reloadPanes()
    }

    @objc func toggleDual() {
        dual.toggle()
        right.view.isHidden = !dual
        paneSplit.adjustSubviews()
        if !dual, focused === right {
            focused = left
            window?.makeFirstResponder(left.table)
        }
        updateStatus()
    }

    @objc func refreshPlaces() {
        places = Self.loadPlaces()
        sidebar.reloadData()
    }

    private func installContent() {
        guard let window else { return }
        let content = NSView()
        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 6
        buttons.addArrangedSubview(button("뒤로", #selector(goBackAction)))
        buttons.addArrangedSubview(button("앞으로", #selector(goForwardAction)))
        buttons.addArrangedSubview(button("위", #selector(goUpAction)))
        buttons.addArrangedSubview(button("양쪽 창", #selector(toggleDual)))

        sidebar.headerView = nil
        sidebar.rowHeight = 22
        sidebar.allowsEmptySelection = true
        sidebar.dataSource = self
        sidebar.delegate = self
        sidebar.target = self
        sidebar.action = #selector(openPlace)
        sidebar.style = .sourceList
        sidebar.floatsGroupRows = true
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("place"))
        column.title = ""
        sidebar.addTableColumn(column)
        let sidebarScroll = NSScrollView()
        sidebarScroll.documentView = sidebar
        sidebarScroll.hasVerticalScroller = true
        sidebarScroll.drawsBackground = false

        paneSplit.isVertical = true
        paneSplit.dividerStyle = .thin
        paneSplit.addArrangedSubview(left.view)
        paneSplit.addArrangedSubview(right.view)
        right.view.isHidden = true

        let outer = NSSplitView()
        outer.isVertical = true
        outer.dividerStyle = .thin
        outer.addArrangedSubview(sidebarScroll)
        outer.addArrangedSubview(paneSplit)

        status.font = .systemFont(ofSize: 12)
        status.textColor = .secondaryLabelColor
        status.lineBreakMode = .byTruncatingTail

        for item in [buttons, outer, status] {
            item.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(item)
        }
        NSLayoutConstraint.activate([
            buttons.topAnchor.constraint(equalTo: content.topAnchor, constant: 8),
            buttons.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 8),
            outer.topAnchor.constraint(equalTo: buttons.bottomAnchor, constant: 8),
            outer.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            outer.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            status.topAnchor.constraint(equalTo: outer.bottomAnchor, constant: 6),
            status.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            status.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            status.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -8),
            sidebarScroll.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),
        ])
        window.contentView = content
        refreshPlaces()
        updateStatus()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.window?.makeFirstResponder(self.left.table)
            self.outerPosition(outer)
        }
    }

    private func outerPosition(_ outer: NSSplitView) {
        outer.setPosition(180, ofDividerAt: 0)
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard event.window === window else { return event }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let command = flags.contains(.command)
        let control = flags.contains(.control)
        let option = flags.contains(.option)
        let shift = flags.contains(.shift)
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        if (command || control) && !option && !shift && key == "l" {
            focused.focusPath()
            return nil
        }
        if window?.firstResponder is NSTextView { return event }

        if control && !command && !option {
            switch key {
            case "c":
                copy(nil)
                return nil
            case "x":
                cut(nil)
                return nil
            case "v":
                paste(nil)
                return nil
            case "a":
                focused.table.selectAll(nil)
                return nil
            case "n" where shift:
                focused.makeFolder()
                return nil
            default:
                break
            }
        }
        if control && option && !command && !shift && key == "n" {
            focused.makeTextFile()
            return nil
        }
        if control && shift && key == "." {
            toggleHidden()
            return nil
        }
        if option && event.keyCode == 126 {
            focused.goUp()
            return nil
        }
        if option && event.keyCode == 123 {
            focused.goBack()
            return nil
        }
        if option && event.keyCode == 124 {
            focused.goForward()
            return nil
        }
        if event.keyCode == 96 {
            copyToOther()
            return nil
        }
        if event.keyCode == 97 {
            moveToOther()
            return nil
        }
        if event.keyCode == 120, focused.tableIsResponder {
            focused.beginRename()
            return nil
        }
        if event.keyCode == 53, clearCut() {
            return nil
        }
        if (event.keyCode == 51 || event.keyCode == 117), focused.tableIsResponder, !control, !option, !shift {
            focused.trashSelection()
            return nil
        }
        if event.keyCode == 36, focused.tableIsResponder, !command, !control, !option {
            focused.openSelection()
            return nil
        }
        if command && event.keyCode == 125, focused.tableIsResponder {
            focused.openSelection()
            return nil
        }
        return event
    }

    private func copyToOther() {
        guard dual else { return }
        let urls = focused.selectedURLs()
        guard !urls.isEmpty else { return }
        let dest = other().session.url
        run("복사하지 못했습니다.") {
            try self.left.session.ops.transfer(urls: urls, to: dest, moving: false, resolve: self.resolveConflict)
        }
    }

    private func moveToOther() {
        guard dual else { return }
        let urls = focused.selectedURLs()
        guard !urls.isEmpty else { return }
        let dest = other().session.url
        run("옮기지 못했습니다.", after: {
            self.forget(urls)
        }) {
            try self.left.session.ops.transfer(urls: urls, to: dest, moving: true, resolve: self.resolveConflict)
        }
    }

    private func other() -> FilePaneController {
        focused === left ? right : left
    }

    private func clearCut() -> Bool {
        guard held?.cut == true else { return false }
        held = nil
        reloadTables()
        return true
    }

    private func forget(_ urls: [URL]) {
        guard let held else { return }
        let gone = Set(urls.map { $0.standardizedFileURL.path })
        let remaining = held.urls.filter { !gone.contains($0.standardizedFileURL.path) }
        self.held = remaining.isEmpty ? nil : Held(urls: remaining, cut: held.cut)
    }

    private func reloadPanes() {
        try? left.session.reload()
        try? right.session.reload()
        left.show()
        right.show()
        updateStatus()
    }

    private func reloadTables() {
        left.table.reloadData()
        right.table.reloadData()
    }

    private func askConflict(_ name: String) -> NameConflict {
        if let rememberedChoice { return rememberedChoice }
        let alert = NSAlert()
        alert.messageText = "같은 이름이 있습니다"
        alert.informativeText = name
        alert.addButton(withTitle: "바꾸기")
        alert.addButton(withTitle: "건너뛰기")
        alert.addButton(withTitle: "둘 다 유지")
        let check = NSButton(checkboxWithTitle: "남은 항목에도 적용", target: nil, action: nil)
        check.frame = NSRect(x: 0, y: 0, width: 240, height: 20)
        alert.accessoryView = check
        let response = alert.runModal()
        let choice: NameConflict
        switch response {
        case .alertFirstButtonReturn: choice = .replace
        case .alertSecondButtonReturn: choice = .skip
        default: choice = .keepBoth
        }
        if check.state == .on { rememberedChoice = choice }
        return choice
    }

    private func button(_ title: String, _ action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        return button
    }

    @objc private func openPlace() {
        let row = sidebar.clickedRow
        guard places.indices.contains(row), case .place(_, let url, _) = places[row] else { return }
        focused.navigateSidebar(url)
        window?.makeFirstResponder(focused.table)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        places.count
    }

    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        if case .header = places[row] { return true }
        return false
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        if case .header = places[row] { return false }
        return true
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        switch places[row] {
        case .header(let title):
            let cell = sidebarCell(tableView, identifier: "header", symbol: nil)
            cell.textField?.stringValue = title
            cell.textField?.font = .systemFont(ofSize: 11, weight: .semibold)
            cell.textField?.textColor = .secondaryLabelColor
            return cell
        case .place(let title, _, let symbol):
            let cell = sidebarCell(tableView, identifier: "place", symbol: symbol)
            cell.textField?.stringValue = title
            cell.textField?.font = .systemFont(ofSize: 13)
            cell.textField?.textColor = .labelColor
            cell.imageView?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            cell.imageView?.contentTintColor = .secondaryLabelColor
            return cell
        }
    }

    private func sidebarCell(_ tableView: NSTableView, identifier: String, symbol: String?) -> NSTableCellView {
        let id = NSUserInterfaceItemIdentifier(identifier)
        if let cell = tableView.makeView(withIdentifier: id, owner: self) as? NSTableCellView {
            return cell
        }
        let cell = NSTableCellView()
        cell.identifier = id
        let text = NSTextField(labelWithString: "")
        text.translatesAutoresizingMaskIntoConstraints = false
        text.lineBreakMode = .byTruncatingTail
        cell.addSubview(text)
        cell.textField = text
        if symbol != nil {
            let image = NSImageView()
            image.translatesAutoresizingMaskIntoConstraints = false
            image.imageScaling = .scaleProportionallyDown
            cell.addSubview(image)
            cell.imageView = image
            NSLayoutConstraint.activate([
                image.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                image.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                image.widthAnchor.constraint(equalToConstant: 16),
                image.heightAnchor.constraint(equalToConstant: 16),
                text.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 6),
                text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                text.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        } else {
            NSLayoutConstraint.activate([
                text.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                text.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }
        return cell
    }

    private static func makeSession() -> BrowserSession {
        let home = FileManager.default.homeDirectoryForCurrentUser
        if let session = try? BrowserSession(url: home) { return session }
        return try! BrowserSession(url: FileManager.default.temporaryDirectory)
    }

    private static func loadPlaces() -> [SidebarItem] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        var items: [SidebarItem] = [
            .header("위치"),
            .place(title: "홈", url: home, symbol: "house"),
            .place(title: "데스크탑", url: home.appendingPathComponent("Desktop"), symbol: "desktopcomputer"),
            .place(title: "문서", url: home.appendingPathComponent("Documents"), symbol: "doc.text"),
            .place(title: "다운로드", url: home.appendingPathComponent("Downloads"), symbol: "arrow.down.circle"),
            .place(title: "응용 프로그램", url: URL(fileURLWithPath: "/Applications", isDirectory: true), symbol: "square.grid.2x2"),
        ]
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsBrowsableKey, .volumeIsEjectableKey]
        let volumes = fm.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
        var disks: [SidebarItem] = []
        for volume in volumes {
            let path = volume.standardizedFileURL.path
            let inVolumes = path == "/Volumes" || path.hasPrefix("/Volumes/")
            guard path == "/" || inVolumes else { continue }
            let values = try? volume.resourceValues(forKeys: Set(keys))
            if values?.volumeIsBrowsable == false { continue }
            let name = values?.volumeName ?? volume.lastPathComponent
            let symbol = values?.volumeIsEjectable == true ? "externaldrive" : "internaldrive"
            disks.append(.place(title: name, url: volume, symbol: symbol))
        }
        if !disks.isEmpty {
            items.append(.header("디스크"))
            items.append(contentsOf: disks)
        }
        return items
    }
}

private enum SidebarItem {
    case header(String)
    case place(title: String, url: URL, symbol: String)
}
