import AppKit
import IHateFinderCore

final class FilePaneController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSMenuDelegate {
    let session: BrowserSession
    weak var browser: BrowserWindowController?
    let pathField = NSTextField()
    let table = FileTableView()
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
        pathField.font = .systemFont(ofSize: 13)
        pathField.lineBreakMode = .byTruncatingMiddle
        pathField.cell?.lineBreakMode = .byTruncatingMiddle
        pathField.delegate = self
        pathField.target = self
        pathField.action = #selector(commitPath)

        table.pane = self
        table.headerView = NSTableHeaderView()
        table.usesAlternatingRowBackgroundColors = true
        table.allowsMultipleSelection = true
        table.allowsEmptySelection = true
        table.allowsColumnReordering = false
        table.rowHeight = 22
        table.doubleAction = #selector(openSelection)
        table.target = self
        table.dataSource = self
        table.delegate = self
        table.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        table.menu = makeMenu()
        table.registerForDraggedTypes([.fileURL])
        table.setDraggingSourceOperationMask([.copy, .move], forLocal: true)
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
        scroll.borderType = .bezelBorder
        loadStatus.font = .systemFont(ofSize: 11)
        loadStatus.lineBreakMode = .byTruncatingMiddle
        loadStatus.translatesAutoresizingMaskIntoConstraints = false

        pathField.translatesAutoresizingMaskIntoConstraints = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(pathField)
        root.addSubview(scroll)
        root.addSubview(loadStatus)
        NSLayoutConstraint.activate([
            pathField.topAnchor.constraint(equalTo: root.topAnchor, constant: 8),
            pathField.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 8),
            pathField.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -8),
            scroll.topAnchor.constraint(equalTo: pathField.bottomAnchor, constant: 8),
            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 8),
            scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -8),
            scroll.bottomAnchor.constraint(equalTo: loadStatus.topAnchor, constant: -4),
            loadStatus.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            loadStatus.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            loadStatus.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -8),
        ])
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
            if displayedRevision != session.revision {
                table.cancelPendingRename()
            }
            displayedEntries = session.entries
            displayedURL = session.url
            displayedRevision = session.revision
            table.reloadData()
            let indexes = IndexSet(displayedEntries.indices.filter {
                sameDirectory && selection.contains(displayedEntries[$0].url)
            })
            table.selectRowIndexes(indexes, byExtendingSelection: false)
        }
        if pathField.currentEditor() == nil {
            pathField.stringValue = displayedURL.path
        }
        loadStatus.stringValue = summary()
        loadStatus.toolTip = loadStatus.stringValue
        browser?.updateStatus()
    }

    func setFocusedLook(_ focused: Bool) {
        scroll.borderType = focused ? .bezelBorder : .lineBorder
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
        let selected = table.selectedRowIndexes.compactMap { index -> FileEntry? in
            displayedEntries.indices.contains(index) ? displayedEntries[index] : nil
        }
        guard !selected.isEmpty else { return "\(count)개 항목" }
        let bytes = selected.reduce(Int64(0)) { partial, entry in
            entry.isDirectory ? partial : partial + entry.size
        }
        return "\(count)개 항목 · 선택 \(selected.count)개, \(sizeFormatter.string(fromByteCount: bytes))"
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
        _ = session.goUp()
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
        guard let entry = selectedEntry else { return }
        if entry.isDirectory {
            session.navigate(to: entry.url)
        } else {
            NSWorkspace.shared.open(entry.url)
        }
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
    }

    @objc func makeFolder() {
        let directory = displayedURL
        let ops = session.ops
        browser?.run("폴더를 만들지 못했습니다.") {
            _ = try ops.createFolder(in: directory)
        }
    }

    @objc func makeTextFile() {
        let directory = displayedURL
        let ops = session.ops
        browser?.run("파일을 만들지 못했습니다.") {
            _ = try ops.createTextFile(in: directory)
        }
    }

    @objc func trashSelection() {
        let urls = selectedURLs()
        guard !urls.isEmpty else { return }
        let ops = session.ops
        browser?.run("휴지통으로 보내지 못했습니다.") {
            for url in urls {
                try ops.trash(url)
            }
        }
    }

    func controlTextDidBeginEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        if field === pathField {
            browser?.focus(self)
            field.currentEditor()?.selectAll(nil)
        } else {
            editingRow = table.row(for: field)
            if editingSelection == nil { editingSelection = Set(selectedURLs()) }
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard control === pathField else { return false }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            pathField.stringValue = session.url.path
            view.window?.makeFirstResponder(table)
            return true
        }
        return false
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
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
        browser?.run("이름을 바꾸지 못했습니다.") {
            try ops.rename(url: url, to: newName, resolve: { name in
                self.browser?.resolveConflict(name) ?? .skip
            })
        }
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
        let option = NSApp.currentEvent?.modifierFlags.contains(.option) == true
        return option ? .copy : .move
    }

    func tableView(
        _ tableView: NSTableView,
        acceptDrop info: NSDraggingInfo,
        row: Int,
        dropOperation: NSTableView.DropOperation
    ) -> Bool {
        guard let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              !urls.isEmpty else { return false }
        var dest = displayedURL
        if dropOperation == .on, displayedEntries.indices.contains(row), displayedEntries[row].isDirectory {
            dest = displayedEntries[row].url
        }
        let copying = NSApp.currentEvent?.modifierFlags.contains(.option) == true
        browser?.drop(urls, onto: dest, copying: copying)
        return true
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let row = table.clickedRow
        if row >= 0, !table.selectedRowIndexes.contains(row) {
            table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }
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
        let items: [(String, Selector)] = [
            ("새 폴더", #selector(makeFolder)),
            ("새 텍스트 파일", #selector(makeTextFile)),
            ("잘라두기", #selector(BrowserWindowController.cut(_:))),
            ("복사", #selector(BrowserWindowController.copy(_:))),
            ("붙여넣기", #selector(BrowserWindowController.paste(_:))),
            ("이름 바꾸기", #selector(beginRename)),
            ("휴지통으로 옮기기", #selector(trashSelection)),
        ]
        for (title, action) in items {
            if title == "잘라두기" || title == "이름 바꾸기" {
                menu.addItem(.separator())
            }
            menu.addItem(NSMenuItem(title: title, action: action, keyEquivalent: ""))
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
        text.font = .systemFont(ofSize: 13)
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
                image.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                image.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                image.widthAnchor.constraint(equalToConstant: 16),
                image.heightAnchor.constraint(equalToConstant: 16),
                text.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 6),
                text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                text.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        } else {
            text.isEditable = false
            NSLayoutConstraint.activate([
                text.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
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
