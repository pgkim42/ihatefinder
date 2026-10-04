import AppKit
import IHateFinderCore
import Quartz

final class FilePaneController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSSearchFieldDelegate, NSMenuDelegate, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    let session: BrowserSession
    weak var browser: BrowserWindowController?
    let pathField = NSTextField()
    let table = FileTableView()
    let filterField = NSSearchField()
    private var filterTopConstraint: NSLayoutConstraint?
    private var filterHeightConstraint: NSLayoutConstraint?
    /// Seams so tests never launch apps or block on a dialog.
    var openFiles: ([URL]) -> Void = { urls in urls.forEach { NSWorkspace.shared.open($0) } }
    var confirmOpen: (Int) -> Bool = FilePaneController.askConfirmOpen
    /// Apps that can open `url`, and the default one. Replaced in tests.
    var appsForOpening: (URL) -> (apps: [URL], defaultApp: URL?) = { url in
        (NSWorkspace.shared.urlsForApplications(toOpen: url), NSWorkspace.shared.urlForApplication(toOpen: url))
    }
    var openWithApp: ([URL], URL) -> Void = { urls, app in
        NSWorkspace.shared.open(urls, withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
    }
    var openInTerminal: (URL) -> Void = { folder in
        guard let terminal = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else { return }
        NSWorkspace.shared.open([folder], withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration())
    }
    var showInfoSheet: (URL) -> Void = { url in
        InfoPanel.present(for: url, in: NSApp.keyWindow ?? NSApp.mainWindow)
    }
    private let openWithMenu = NSMenu()
    private let scroll = NSScrollView()
    private let loadStatus = NSTextField(labelWithString: "")
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    private let sizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()
    private var editingRow = -1
    private var editingSelection: Set<URL>?
    private var displayedEntries: [FileEntry] = []
    private var displayedURL: URL
    private var displayedRevision = -1
    /// An item to select (and optionally rename) once the listing contains it.
    /// Dropped when the pane shows a folder that cannot contain it.
    private(set) var pendingReveal: (url: URL, rename: Bool)?
    private var dropVolumeCache: (sequence: Int, destination: URL, allSame: Bool)?

    init(session: BrowserSession) {
        self.session = session
        self.displayedURL = session.url
        super.init(nibName: nil, bundle: nil)
        session.onChange = { [weak self] in self?.show() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    var tableIsResponder: Bool {
        view.window?.firstResponder === table
    }

    override func loadView() {
        let root = NSView()
        pathField.isEditable = true
        pathField.isSelectable = true
        pathField.isBezeled = true
        pathField.bezelStyle = .roundedBezel
        pathField.font = .systemFont(ofSize: 13)
        pathField.lineBreakMode = .byTruncatingMiddle
        pathField.cell?.lineBreakMode = .byTruncatingMiddle
        pathField.delegate = self
        pathField.target = self
        pathField.action = #selector(commitPath)
        pathField.placeholderString = "경로를 입력하거나 Command-L을 누르세요"

        table.pane = self
        table.headerView = NSTableHeaderView()
        table.usesAlternatingRowBackgroundColors = false
        table.allowsMultipleSelection = true
        table.allowsEmptySelection = true
        table.allowsColumnReordering = false
        table.rowHeight = 24
        table.intercellSpacing = NSSize(width: 3, height: 2)
        table.doubleAction = #selector(openSelection)
        table.target = self
        table.dataSource = self
        table.delegate = self
        table.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        table.menu = makeMenu()
        table.registerForDraggedTypes([.fileURL])
        table.setDraggingSourceOperationMask([.copy, .move, .generic], forLocal: true)
        table.setDraggingSourceOperationMask(.copy, forLocal: false)

        for column in Self.columns {
            let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(column.rawValue))
            tableColumn.title = column.title
            tableColumn.width = column.width
            tableColumn.minWidth = column.rawValue == SortColumn.name.rawValue ? 180 : 60
            tableColumn.sortDescriptorPrototype = NSSortDescriptor(key: column.rawValue, ascending: true)
            table.addTableColumn(tableColumn)
        }
        table.sortDescriptors = [NSSortDescriptor(key: session.sortColumn.rawValue, ascending: session.ascending)]

        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .lineBorder
        scroll.drawsBackground = true
        loadStatus.font = .systemFont(ofSize: 11, weight: .regular)
        loadStatus.textColor = .secondaryLabelColor
        loadStatus.lineBreakMode = .byTruncatingMiddle
        loadStatus.translatesAutoresizingMaskIntoConstraints = false

        filterField.placeholderString = "이 폴더에서 이름 거르기"
        filterField.font = .systemFont(ofSize: 13)
        filterField.sendsSearchStringImmediately = true
        filterField.delegate = self
        filterField.target = self
        filterField.action = #selector(filterChanged)
        filterField.isHidden = true

        pathField.translatesAutoresizingMaskIntoConstraints = false
        filterField.translatesAutoresizingMaskIntoConstraints = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(pathField)
        root.addSubview(filterField)
        root.addSubview(scroll)
        root.addSubview(loadStatus)
        NSLayoutConstraint.activate([
            pathField.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
            pathField.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            pathField.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            filterField.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            filterField.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            scroll.topAnchor.constraint(equalTo: filterField.bottomAnchor, constant: 8),
            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            scroll.bottomAnchor.constraint(equalTo: loadStatus.topAnchor, constant: -6),
            loadStatus.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 2),
            loadStatus.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -2),
            loadStatus.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -8),
        ])
        let filterTop = filterField.topAnchor.constraint(equalTo: pathField.bottomAnchor, constant: 0)
        let filterHeight = filterField.heightAnchor.constraint(equalToConstant: 0)
        filterTopConstraint = filterTop
        filterHeightConstraint = filterHeight
        NSLayoutConstraint.activate([filterTop, filterHeight])
        view = root
        show()
        session.reload()
    }

    func show() {
        guard isViewLoaded else { return }
        if case .failed = session.loadState {
            loadStatus.textColor = .systemRed
        } else {
            loadStatus.textColor = .secondaryLabelColor
        }
        if editingRow < 0 && table.editedRow < 0 {
            let selection = editingSelection ?? Set(selectedURLs())
            editingSelection = nil
            let sameDirectory = displayedURL == session.url
            if !sameDirectory { resetFilter() }
            if displayedRevision != session.revision {
                table.cancelPendingRename()
            }
            displayedEntries = EntryFilter.filter(session.entries, query: filterField.stringValue)
            displayedURL = session.url
            displayedRevision = session.revision
            table.reloadData()
            let indexes = IndexSet(displayedEntries.indices.filter {
                sameDirectory && selection.contains(displayedEntries[$0].url)
            })
            table.selectRowIndexes(indexes, byExtendingSelection: false)
            if !sameDirectory, let pending = pendingReveal,
               pending.url.deletingLastPathComponent().standardizedFileURL.path != displayedURL.standardizedFileURL.path {
                pendingReveal = nil
            }
            applyPendingReveal()
        }
        if pathField.currentEditor() == nil {
            pathField.stringValue = displayedURL.path
        }
        loadStatus.stringValue = summary()
        loadStatus.toolTip = loadStatus.stringValue
        browser?.updateStatus()
    }

    /// Selects `url` as soon as the listing shows it; with `rename` it also starts renaming.
    func revealAfterReload(_ url: URL, rename: Bool) {
        pendingReveal = (url, rename)
        if isViewLoaded, editingRow < 0, table.editedRow < 0 { applyPendingReveal() }
    }

    private func applyPendingReveal() {
        guard let pending = pendingReveal else { return }
        let path = pending.url.standardizedFileURL.path
        var found = displayedEntries.firstIndex(where: { $0.url.standardizedFileURL.path == path })
        if found == nil, filterIsActive,
           session.entries.contains(where: { $0.url.standardizedFileURL.path == path }) {
            // The filter would hide the new item; show it instead.
            resetFilter()
            displayedEntries = session.entries
            table.reloadData()
            found = displayedEntries.firstIndex(where: { $0.url.standardizedFileURL.path == path })
        }
        guard let row = found else { return }
        pendingReveal = nil
        table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        table.scrollRowToVisible(row)
        if pending.rename {
            DispatchQueue.main.async { [weak self] in self?.beginRename() }
        }
    }

    func setFocusedLook(_ focused: Bool) {
        scroll.wantsLayer = true
        scroll.borderType = .lineBorder
        if focused {
            scroll.layer?.borderWidth = 1.0
            scroll.layer?.borderColor = NSColor.controlAccentColor.cgColor
        } else {
            scroll.layer?.borderWidth = 1.0
            scroll.layer?.borderColor = NSColor.separatorColor.cgColor
        }
    }

    func selectedURLs() -> [URL] {
        table.selectedRowIndexes.compactMap { index in
            displayedEntries.indices.contains(index) ? displayedEntries[index].url : nil
        }
    }

    func summary() -> String {
        switch session.loadState {
        case .loading(let url): return "불러오는 중… \(url.path)"
        case .failed(let url, let message): return "\(url.path): \(message)"
        case .idle: break
        }
        if let notice = session.restorationNotice { return notice }
        let count = displayedEntries.count
        let total = session.entries.count
        let countText = filterIsActive ? "\(total)개 중 \(count)개 표시" : "\(count)개 항목"
        let selected = table.selectedRowIndexes.compactMap { index -> FileEntry? in
            displayedEntries.indices.contains(index) ? displayedEntries[index] : nil
        }
        guard !selected.isEmpty else { return countText }
        let bytes = selected.reduce(Int64(0)) { partial, entry in
            entry.isDirectory ? partial : partial + entry.size
        }
        return "\(countText) · 선택 \(selected.count)개, \(sizeFormatter.string(fromByteCount: bytes))"
    }

    func claimFocus() {
        browser?.focus(self)
    }

    func focusPath() {
        view.window?.makeFirstResponder(pathField)
        pathField.currentEditor()?.selectAll(nil)
    }

    func goUp() {
        table.cancelPendingRename()
        let origin = session.url
        if session.goUp() { pendingReveal = (origin, false) }
    }

    func goBack() {
        table.cancelPendingRename()
        _ = session.goBack()
    }

    func goForward() {
        table.cancelPendingRename()
        _ = session.goForward()
    }

    func navigateSidebar(_ url: URL) {
        table.cancelPendingRename()
        session.navigate(to: url)
    }

    @objc func openSelection() {
        table.cancelPendingRename()
        let entries = table.selectedRowIndexes.compactMap { index in
            displayedEntries.indices.contains(index) ? displayedEntries[index] : nil
        }
        switch OpenPlan.make(entries: entries) {
        case nil:
            return
        case .navigate(let url):
            session.navigate(to: url)
        case .openFiles(let urls, let confirm):
            if confirm && !confirmOpen(urls.count) { return }
            openFiles(urls)
        case .refuse(let message):
            browser?.alert(message)
        }
    }

    private static func askConfirmOpen(_ count: Int) -> Bool {
        let alert = NSAlert()
        alert.messageText = "파일 \(count)개를 모두 여시겠습니까?"
        alert.addButton(withTitle: "열기")
        alert.addButton(withTitle: "취소")
        return alert.runModal() == .alertFirstButtonReturn
    }

    // MARK: Filter

    var filterIsActive: Bool {
        !filterField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var filterIsVisible: Bool { !filterField.isHidden }

    func showFilter() {
        _ = view
        filterField.isHidden = false
        filterTopConstraint?.constant = 8
        filterHeightConstraint?.constant = 28
        view.window?.makeFirstResponder(filterField)
        filterField.currentEditor()?.selectAll(nil)
        browser?.focus(self)
    }

    /// Esc on the list or in the filter field. Returns false when there was nothing to clear.
    func clearActiveFilter() -> Bool {
        guard filterIsVisible || filterIsActive else { return false }
        let hadFilter = filterIsActive
        resetFilter()
        if hadFilter { applyFilter() }
        view.window?.makeFirstResponder(table)
        return true
    }

    /// Clears the text and hides the field without touching the displayed rows.
    private func resetFilter() {
        if filterField.currentEditor() != nil { view.window?.makeFirstResponder(table) }
        filterField.stringValue = ""
        filterField.isHidden = true
        filterTopConstraint?.constant = 0
        filterHeightConstraint?.constant = 0
    }

    @objc private func filterChanged() {
        applyFilter()
    }

    /// Rebuilds the rows for the current query and keeps the selection of the rows that stay visible.
    private func applyFilter() {
        guard isViewLoaded, editingRow < 0, table.editedRow < 0 else { return }
        let selection = Set(selectedURLs())
        displayedEntries = EntryFilter.filter(session.entries, query: filterField.stringValue)
        table.reloadData()
        let indexes = IndexSet(displayedEntries.indices.filter { selection.contains(displayedEntries[$0].url) })
        table.selectRowIndexes(indexes, byExtendingSelection: false)
        loadStatus.stringValue = summary()
        loadStatus.toolTip = loadStatus.stringValue
        browser?.updateStatus()
    }

    // MARK: Quick Look

    func toggleQuickLook() {
        let panel = QLPreviewPanel.shared()!
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            guard !selectedURLs().isEmpty else { return }
            browser?.focus(self)
            panel.makeKeyAndOrderFront(nil)
        }
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        selectedURLs().count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        let urls = selectedURLs()
        guard urls.indices.contains(index) else { return nil }
        return urls[index] as NSURL
    }

    /// Every key except Esc goes to the list, so Space closes the preview and arrows move the selection.
    func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        guard event.type == .keyDown, event.keyCode != 53 else { return false }
        table.keyDown(with: event)
        return true
    }

    func previewPanel(_ panel: QLPreviewPanel!, sourceFrameOnScreenFor item: QLPreviewItem!) -> NSRect {
        guard let url = (item as? NSURL) as URL?,
              let row = displayedEntries.firstIndex(where: { $0.url == url }),
              let window = view.window else { return .zero }
        let rect = table.convert(table.rect(ofRow: row), to: nil)
        return window.convertToScreen(rect)
    }

    private func reloadPreviewIfShowing() {
        guard QLPreviewPanel.sharedPreviewPanelExists() else { return }
        let panel = QLPreviewPanel.shared()!
        if panel.isVisible, panel.dataSource === self { panel.reloadData() }
    }

    @objc func beginRename() {
        guard browser?.isFileOperationRunning != true else {
            browser?.alert("파일 작업이 진행 중입니다. 완료한 뒤 이름을 바꾸십시오.")
            return
        }
        let row = table.selectedRow
        guard displayedEntries.indices.contains(row) else { return }
        editingRow = row
        editingSelection = Set(selectedURLs())
        table.editColumn(0, row: row, with: nil, select: true)
        let entry = displayedEntries[row]
        let range = RenameSelection.range(name: entry.name, isDirectory: entry.isDirectory)
        (view.window?.firstResponder as? NSTextView)?.setSelectedRange(range)
    }

    @objc func makeFolder() {
        let directory = displayedURL
        let ops = session.ops
        browser?.runReporting("폴더를 만들지 못했습니다.", work: {
            let url = try ops.createFolder(in: directory)
            return (url, ops.undoRecord(created: url))
        }, completion: { [weak self] created in
            self?.browser?.recordUndo(created.1)
            self?.revealAfterReload(created.0, rename: true)
        })
    }

    @objc func makeTextFile() {
        let directory = displayedURL
        let ops = session.ops
        browser?.runReporting("파일을 만들지 못했습니다.", work: {
            let url = try ops.createTextFile(in: directory)
            return (url, ops.undoRecord(created: url))
        }, completion: { [weak self] created in
            self?.browser?.recordUndo(created.1)
            self?.revealAfterReload(created.0, rename: true)
        })
    }

    @objc func trashSelection() {
        let urls = selectedURLs()
        guard !urls.isEmpty else { return }
        let ops = session.ops
        browser?.runReporting("휴지통으로 보내지 못했습니다.", work: {
            let report = ops.trash(urls: urls)
            return (report, ops.undoRecord(trash: report))
        }, completion: { [weak browser] result in
            browser?.finishTrash(result.0, record: result.1)
        })
    }

    func controlTextDidBeginEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        if field === filterField {
            browser?.focus(self)
        } else if field === pathField {
            browser?.focus(self)
            field.currentEditor()?.selectAll(nil)
        } else {
            editingRow = table.row(for: field)
            if editingSelection == nil { editingSelection = Set(selectedURLs()) }
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if control === filterField {
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                _ = clearActiveFilter()
                return true
            }
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                view.window?.makeFirstResponder(table)
                return true
            }
            return false
        }
        guard control === pathField else { return false }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            pathField.stringValue = session.url.path
            view.window?.makeFirstResponder(table)
            return true
        }
        return false
    }

    func controlTextDidChange(_ obj: Notification) {
        if (obj.object as? NSSearchField) === filterField { applyFilter() }
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        if field === filterField { return }
        if field === pathField {
            DispatchQueue.main.async { [weak self] in self?.show() }
            return
        }
        let row = editingRow
        editingRow = -1
        defer { DispatchQueue.main.async { [weak self] in self?.show() } }
        guard displayedEntries.indices.contains(row) else { return }
        let movement = obj.userInfo?["NSTextMovement"] as? Int
        if movement == NSTextMovement.cancel.rawValue {
            return
        }
        let entry = displayedEntries[row]
        let newName = field.stringValue
        guard newName != entry.name else { return }
        let url = entry.url
        let ops = session.ops
        browser?.runReporting("이름을 바꾸지 못했습니다.", work: {
            let outcome = try ops.rename(url: url, to: newName, resolve: { name in
                self.browser?.resolveConflict(name) ?? .skip
            })
            return ops.undoRecord(rename: outcome, from: url)
        }, completion: { [weak browser] record in
            browser?.recordUndo(record)
        })
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        displayedEntries.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn, displayedEntries.indices.contains(row) else { return nil }
        let entry = displayedEntries[row]
        let cell = reusedCell(tableView, column: tableColumn)
        let column = SortColumn(rawValue: tableColumn.identifier.rawValue)
        switch column {
        case .name:
            cell.textField?.stringValue = entry.name
            cell.imageView?.image = NSWorkspace.shared.icon(forFile: entry.url.path)
        case .modified:
            cell.textField?.stringValue = dateFormatter.string(from: entry.modified)
        case .kind:
            cell.textField?.stringValue = entry.kind
        case .size:
            cell.textField?.stringValue = entry.isDirectory ? "—" : sizeFormatter.string(fromByteCount: entry.size)
        case nil:
            break
        }
        let cut = browser?.isCut(entry.url) ?? false
        cell.alphaValue = cut ? 0.4 : 1
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        reloadPreviewIfShowing()
        loadStatus.stringValue = summary()
        loadStatus.toolTip = loadStatus.stringValue
        browser?.updateStatus()
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard let descriptor = tableView.sortDescriptors.first,
              let column = SortColumn(rawValue: descriptor.key ?? "") else { return }
        session.setSort(column, ascending: descriptor.ascending)
    }

    func tableView(
        _ tableView: NSTableView,
        pasteboardWriterForRow row: Int
    ) -> NSPasteboardWriting? {
        guard displayedEntries.indices.contains(row) else { return nil }
        return displayedEntries[row].url as NSURL
    }

    func tableView(
        _ tableView: NSTableView,
        draggingSession session: NSDraggingSession,
        willBeginAt screenPoint: NSPoint,
        forRowIndexes rowIndexes: IndexSet
    ) {
        table.cancelPendingRename()
    }

    func tableView(
        _ tableView: NSTableView,
        validateDrop info: NSDraggingInfo,
        proposedRow row: Int,
        proposedDropOperation dropOperation: NSTableView.DropOperation
    ) -> NSDragOperation {
        if displayedEntries.indices.contains(row), displayedEntries[row].isDirectory {
            tableView.setDropRow(row, dropOperation: .on)
        } else {
            tableView.setDropRow(-1, dropOperation: .above)
        }
        guard let urls = droppedURLs(info) else { return [] }
        let dest = dropDestination(row: row, dropOperation: dropOperation)
        switch resolveDropOperation(for: info, urls: urls, destination: dest) {
        case .move: return .move
        case .copy: return .copy
        case nil: return []
        }
    }

    func tableView(
        _ tableView: NSTableView,
        acceptDrop info: NSDraggingInfo,
        row: Int,
        dropOperation: NSTableView.DropOperation
    ) -> Bool {
        guard let urls = droppedURLs(info) else { return false }
        let dest = dropDestination(row: row, dropOperation: dropOperation)
        guard let operation = resolveDropOperation(for: info, urls: urls, destination: dest) else { return false }
        browser?.drop(urls, onto: dest, moving: operation == .move)
        return true
    }

    private func droppedURLs(_ info: NSDraggingInfo) -> [URL]? {
        guard let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              !urls.isEmpty else { return nil }
        return urls
    }

    private func dropDestination(row: Int, dropOperation: NSTableView.DropOperation) -> URL {
        if dropOperation == .on, displayedEntries.indices.contains(row), displayedEntries[row].isDirectory {
            return displayedEntries[row].url
        }
        return displayedURL
    }

    /// The single decision behind both the drag cursor and the action.
    /// The volume check is cached per drag session and destination, since validateDrop runs on every mouse move.
    private func resolveDropOperation(for info: NSDraggingInfo, urls: [URL], destination: URL) -> DropOperation? {
        let sequence = info.draggingSequenceNumber
        let allSame: Bool
        if let cache = dropVolumeCache, cache.sequence == sequence, cache.destination == destination {
            allSame = cache.allSame
        } else {
            let ops = session.ops
            allSame = urls.allSatisfy { ops.sameVolume($0, destination) }
            dropVolumeCache = (sequence, destination, allSame)
        }
        let source = info.draggingSourceOperationMask
        var mask: DropMask = []
        if source.contains(.copy) { mask.insert(.copy) }
        if source.contains(.move) { mask.insert(.move) }
        if source.contains(.generic) { mask.insert(.generic) }
        return DropPolicy.operation(allSourcesOnDestinationVolume: allSame, mask: mask)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu === openWithMenu { return }
        let row = table.clickedRow
        if row >= 0, !table.selectedRowIndexes.contains(row) {
            table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }
        refreshMenu(menu)
    }

    /// Sets enablement from the selection and rebuilds the 다른 앱으로 열기 submenu.
    func refreshMenu(_ menu: NSMenu) {
        let selection = selectedURLs()
        let state = MenuState.make(selection: selection)
        let enabled: [Selector: Bool] = [
            #selector(openSelection): state.open,
            #selector(BrowserWindowController.cut(_:)): state.cut,
            #selector(BrowserWindowController.copy(_:)): state.copy,
            #selector(beginRename): state.rename,
            #selector(trashSelection): state.trash,
            #selector(compressSelection): state.compress,
            #selector(copyPathSelection): state.copyPath,
            #selector(showInfo): state.info,
            #selector(openInTerminalAction): state.terminal,
        ]
        for item in menu.items {
            if let action = item.action, let value = enabled[action] { item.isEnabled = value }
        }
        if let item = menu.items.first(where: { $0.submenu === openWithMenu }) {
            item.isEnabled = state.openWith
            rebuildOpenWithMenu(for: selection)
        }
    }

    private func rebuildOpenWithMenu(for selection: [URL]) {
        openWithMenu.removeAllItems()
        let lists = selection.map(appsForOpening)
        let apps = MenuState.commonApps(lists.map(\.apps), defaultApp: lists.first?.defaultApp)
        let defaultPath = lists.first?.defaultApp?.path
        if apps.isEmpty {
            let none = NSMenuItem(title: "없음", action: nil, keyEquivalent: "")
            none.isEnabled = false
            openWithMenu.addItem(none)
            return
        }
        for app in apps {
            let name = FileManager.default.displayName(atPath: app.path).replacingOccurrences(of: ".app", with: "")
            let isDefault = app.path == defaultPath && lists.allSatisfy { $0.defaultApp?.path == defaultPath }
            let item = NSMenuItem(title: isDefault ? "\(name) (기본)" : name, action: #selector(openWithChosen(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = app
            item.image = NSWorkspace.shared.icon(forFile: app.path)
            item.image?.size = NSSize(width: 16, height: 16)
            openWithMenu.addItem(item)
        }
    }

    @objc func openWithChosen(_ sender: NSMenuItem) {
        guard let app = sender.representedObject as? URL else { return }
        let urls = selectedURLs()
        guard !urls.isEmpty else { return }
        openWithApp(urls, app)
    }

    @objc func copyPathSelection() {
        browser?.copyPaths(selectedURLs())
    }

    @objc func openInTerminalAction() {
        let selected = table.selectedRowIndexes.compactMap { index in
            displayedEntries.indices.contains(index) ? displayedEntries[index] : nil
        }
        openInTerminal(MenuState.terminalFolder(selection: selected, current: displayedURL))
    }

    @objc func compressSelection() {
        let urls = selectedURLs()
        guard urls.count == 1 else { return }
        browser?.compress(urls[0])
    }

    @objc func showInfo() {
        let urls = selectedURLs()
        guard urls.count == 1 else { return }
        showInfoSheet(urls[0])
    }

    @objc private func commitPath() {
        let typed = pathField.stringValue
        session.navigate(to: URL(fileURLWithPath: (typed as NSString).expandingTildeInPath))
        view.window?.makeFirstResponder(table)
    }

    private var selectedEntry: FileEntry? {
        let row = table.selectedRow
        guard displayedEntries.indices.contains(row) else { return nil }
        return displayedEntries[row]
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        menu.addItem(NSMenuItem(title: "열기", action: #selector(openSelection), keyEquivalent: ""))
        let openWith = NSMenuItem(title: "다른 앱으로 열기", action: nil, keyEquivalent: "")
        openWith.submenu = openWithMenu
        openWithMenu.delegate = self
        menu.addItem(openWith)
        menu.addItem(.separator())
        let items: [(String, Selector)] = [
            ("새 폴더", #selector(makeFolder)),
            ("새 텍스트 파일", #selector(makeTextFile)),
            ("잘라두기", #selector(BrowserWindowController.cut(_:))),
            ("복사", #selector(BrowserWindowController.copy(_:))),
            ("붙여넣기", #selector(BrowserWindowController.paste(_:))),
            ("이름 바꾸기", #selector(beginRename)),
            ("휴지통으로 옮기기", #selector(trashSelection)),
            ("압축", #selector(compressSelection)),
            ("경로 복사", #selector(copyPathSelection)),
            ("정보 보기", #selector(showInfo)),
            ("터미널에서 열기", #selector(openInTerminalAction)),
        ]
        for (title, action) in items {
            if title == "잘라두기" || title == "이름 바꾸기" || title == "압축" || title == "경로 복사" {
                menu.addItem(.separator())
            }
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            if [#selector(makeFolder), #selector(makeTextFile), #selector(openSelection), #selector(beginRename),
                #selector(trashSelection), #selector(compressSelection), #selector(copyPathSelection),
                #selector(showInfo), #selector(openInTerminalAction)].contains(action) {
                item.target = self
            }
            menu.addItem(item)
        }
        return menu
    }

    private func reusedCell(_ tableView: NSTableView, column: NSTableColumn) -> NSTableCellView {
        if let cell = tableView.makeView(withIdentifier: column.identifier, owner: self) as? NSTableCellView {
            return cell
        }
        let cell = NSTableCellView()
        cell.identifier = column.identifier
        let text = NSTextField()
        text.isBezeled = false
        text.drawsBackground = false
        text.font = .systemFont(ofSize: 13, weight: .regular)
        text.lineBreakMode = .byTruncatingTail
        text.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(text)
        cell.textField = text
        if column.identifier.rawValue == SortColumn.name.rawValue {
            text.isEditable = true
            text.isSelectable = true
            text.delegate = self
            let image = NSImageView()
            image.imageScaling = .scaleProportionallyDown
            image.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(image)
            cell.imageView = image
            NSLayoutConstraint.activate([
                image.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
                image.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                image.widthAnchor.constraint(equalToConstant: 16),
                image.heightAnchor.constraint(equalToConstant: 16),
                text.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 6),
                text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
                text.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        } else {
            text.isEditable = false
            NSLayoutConstraint.activate([
                text.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
                text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
                text.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }
        return cell
    }

    private struct Column {
        var rawValue: String
        var title: String
        var width: CGFloat
    }

    private static let columns = [
        Column(rawValue: SortColumn.name.rawValue, title: "이름", width: 280),
        Column(rawValue: SortColumn.modified.rawValue, title: "수정한 날짜", width: 160),
        Column(rawValue: SortColumn.kind.rawValue, title: "종류", width: 120),
        Column(rawValue: SortColumn.size.rawValue, title: "크기", width: 90),
    ]
}
