import AppKit
import IHateFinderCore
import Quartz

final class FilePaneController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSSearchFieldDelegate, NSMenuDelegate, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    let session: BrowserSession
    weak var browser: BrowserWindowController?
    let pathField = NSTextField()
    let table = FileTableView()
    let filterField = NSSearchField()
    let recursiveSearchField = NSSearchField()
    let completionTable = NSTableView()
    private let completionScroll = NSScrollView()
    private var completionHeightConstraint: NSLayoutConstraint?
    private var searchHeightConstraint: NSLayoutConstraint?
    private var searchTopConstraint: NSLayoutConstraint?
    private(set) var completionCandidates: [URL] = []
    private var completionGeneration = 0
    private var cancelCompletion: (() -> Void)?
    var completeDirectories = DirectoryQueries.complete
    var onCompletionChange: (() -> Void)?
    private(set) var recursiveSearchVisible = false
    private(set) var searchIsRunning = false
    private var searchEntries: [FileEntry] = []
    private var searchGeneration = 0
    private var cancelSearch: (() -> Void)?
    private var searchError: String?
    var searchFiles = DirectoryQueries.search
    var onSearchChange: (() -> Void)?
    private(set) var thumbnailsEnabled = false
    let thumbnails = PaneThumbnails()
    private var filterTopConstraint: NSLayoutConstraint?
    private var filterHeightConstraint: NSLayoutConstraint?
    /// Seams so tests never launch apps or block on a dialog.
    var openFiles: ([URL], @escaping PaneLaunch.Completion) -> Void = PaneLaunch.files
    var confirmOpen: (Int) -> Bool = FilePaneController.askConfirmOpen
    /// Apps that can open `url`, and the default one. Replaced in tests.
    var appsForOpening: (URL) -> (apps: [URL], defaultApp: URL?) = { url in
        (NSWorkspace.shared.urlsForApplications(toOpen: url), NSWorkspace.shared.urlForApplication(toOpen: url))
    }
    var openWithApp: ([URL], URL, @escaping PaneLaunch.Completion) -> Void = PaneLaunch.application
    var openInTerminal: (URL, @escaping PaneLaunch.Completion) -> Void = PaneLaunch.terminal
    var presentLaunchError: ((String) -> Void)?
    var onLaunchOutcome: ((Result<Void, Error>) -> Void)?
    var onRenameStart: (() -> Void)?
    var showInfoSheet: (URL) -> Void = { url in
        InfoPanel.present(for: url, in: NSApp.keyWindow ?? NSApp.mainWindow)
    }
    private let openWithMenu = NSMenu()
    private let scroll = NSScrollView()
    private let card = StudioCanvas()
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
        session.captureViewState = { [weak self] in
            guard let self, self.isViewLoaded else {
                return BrowserSession.ViewState(selection: [], scrollOffset: 0, filter: "", filterVisible: false)
            }
            let state = BrowserSession.ViewState(selection: Set(self.selectedURLs()),
                                                 scrollOffset: Double(self.scroll.contentView.bounds.origin.y),
                                                 filter: self.filterField.stringValue, filterVisible: self.filterIsVisible)
            self.table.cancelPendingRename()
            self.dismissCompletions()
            return state
        }
    }

    deinit {
        cancelCompletion?()
        cancelSearch?()
    }

    func cancelBackgroundWork() {
        dismissCompletions()
        endRecursiveSearch()
        thumbnails.invalidate()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    var tableIsResponder: Bool {
        view.window?.firstResponder === table
    }

    override func loadView() {
        let root = StudioCanvas()
        StudioField.stylePath(pathField, placeholder: "경로를 입력하거나 Command-L을 누르세요")
        pathField.lineBreakMode = .byTruncatingMiddle
        pathField.cell?.lineBreakMode = .byTruncatingMiddle
        pathField.delegate = self
        pathField.target = self
        pathField.action = #selector(commitPath)

        table.pane = self
        table.headerView = NSTableHeaderView()
        table.usesAlternatingRowBackgroundColors = false
        table.selectionHighlightStyle = .none
        table.focusRingType = .none
        table.backgroundColor = Studio.card
        table.gridStyleMask = []
        table.allowsMultipleSelection = true
        table.allowsEmptySelection = true
        table.allowsColumnReordering = false
        table.rowHeight = 32
        table.intercellSpacing = NSSize(width: 0, height: 0)
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
            tableColumn.minWidth = column.rawValue == SortColumn.name.rawValue ? 140 : 64
            tableColumn.sortDescriptorPrototype = NSSortDescriptor(key: column.rawValue, ascending: true)
            let header = StudioHeaderCell(textCell: column.title)
            header.alignment = column.rawValue == SortColumn.size.rawValue ? .right : .left
            tableColumn.headerCell = header
            table.addTableColumn(tableColumn)
        }
        table.sortDescriptors = [NSSortDescriptor(key: session.sortColumn.rawValue, ascending: session.ascending)]

        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        scroll.borderType = .noBorder
        scroll.drawsBackground = true
        scroll.backgroundColor = Studio.card
        scroll.wantsLayer = true
        scroll.layer?.cornerRadius = 16
        scroll.layer?.masksToBounds = true
        scroll.contentView.drawsBackground = false
        loadStatus.font = .systemFont(ofSize: 11, weight: .medium)
        loadStatus.textColor = Studio.muted
        loadStatus.lineBreakMode = .byTruncatingMiddle
        loadStatus.translatesAutoresizingMaskIntoConstraints = false

        StudioField.styleSearch(filterField, placeholder: "이 폴더에서 이름 거르기")
        filterField.delegate = self
        filterField.target = self
        filterField.action = #selector(filterChanged)
        filterField.isHidden = true

        StudioField.styleSearch(recursiveSearchField, placeholder: "이 폴더와 하위 폴더에서 이름 검색")
        recursiveSearchField.delegate = self
        recursiveSearchField.target = self
        recursiveSearchField.action = #selector(recursiveSearchChanged)
        recursiveSearchField.isHidden = true
        recursiveSearchField.translatesAutoresizingMaskIntoConstraints = false

        completionTable.addTableColumn(NSTableColumn(identifier: .init("directory-completion")))
        completionTable.headerView = nil
        completionTable.rowHeight = 24
        completionTable.intercellSpacing = .zero
        completionTable.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        completionTable.dataSource = self
        completionTable.delegate = self
        completionTable.target = self
        completionTable.doubleAction = #selector(commitCompletion)
        completionScroll.documentView = completionTable
        completionScroll.hasVerticalScroller = true
        completionScroll.isHidden = true
        completionScroll.translatesAutoresizingMaskIntoConstraints = false

        pathField.translatesAutoresizingMaskIntoConstraints = false
        filterField.translatesAutoresizingMaskIntoConstraints = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        card.fill = Studio.hairline
        card.cornerRadius = 18
        card.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(scroll)
        root.addSubview(pathField)
        root.addSubview(filterField)
        root.addSubview(recursiveSearchField)
        root.addSubview(completionScroll)
        root.addSubview(card)
        root.addSubview(loadStatus)
        NSLayoutConstraint.activate([
            pathField.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
            pathField.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            pathField.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            pathField.heightAnchor.constraint(equalToConstant: 32),
            filterField.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            filterField.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            card.topAnchor.constraint(equalTo: recursiveSearchField.bottomAnchor, constant: 10),
            card.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            card.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            card.bottomAnchor.constraint(equalTo: loadStatus.topAnchor, constant: -6),
            scroll.topAnchor.constraint(equalTo: card.topAnchor, constant: 2),
            scroll.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 2),
            scroll.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -2),
            scroll.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -2),
            loadStatus.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 4),
            loadStatus.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -4),
            loadStatus.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -8),
            completionScroll.topAnchor.constraint(equalTo: pathField.bottomAnchor),
            completionScroll.leadingAnchor.constraint(equalTo: pathField.leadingAnchor),
            completionScroll.trailingAnchor.constraint(equalTo: pathField.trailingAnchor),
            recursiveSearchField.leadingAnchor.constraint(equalTo: filterField.leadingAnchor),
            recursiveSearchField.trailingAnchor.constraint(equalTo: filterField.trailingAnchor),
        ])
        let filterTop = filterField.topAnchor.constraint(equalTo: completionScroll.bottomAnchor, constant: 0)
        let filterHeight = filterField.heightAnchor.constraint(equalToConstant: 0)
        filterTopConstraint = filterTop
        filterHeightConstraint = filterHeight
        completionHeightConstraint = completionScroll.heightAnchor.constraint(equalToConstant: 0)
        searchHeightConstraint = recursiveSearchField.heightAnchor.constraint(equalToConstant: 0)
        searchTopConstraint = recursiveSearchField.topAnchor.constraint(equalTo: filterField.bottomAnchor)
        NSLayoutConstraint.activate([completionHeightConstraint!, searchHeightConstraint!, searchTopConstraint!])
        NSLayoutConstraint.activate([filterTop, filterHeight])
        root.onAppearanceChange = { [weak self] in self?.applyChrome() }
        view = root
        applyChrome()
        show()
        session.reload()
    }

    func show() {
        guard isViewLoaded else { return }
        if case .failed = session.loadState {
            loadStatus.textColor = .systemRed
        } else {
            loadStatus.textColor = Studio.muted
        }
        if editingRow < 0 && table.editedRow < 0 {
            let newRevision = displayedRevision != session.revision
            let sameDirectory = displayedURL == session.url
            let restored = newRevision ? session.restoredViewState : nil
            let selection = restored?.selection ?? editingSelection ?? Set(selectedURLs())
            editingSelection = nil
            if !sameDirectory {
                resetFilter()
                endRecursiveSearch()
                dismissCompletions()
            }
            if let restored {
                filterField.stringValue = restored.filter
                filterField.isHidden = !restored.filterVisible
                filterTopConstraint?.constant = restored.filterVisible ? 8 : 0
                filterHeightConstraint?.constant = restored.filterVisible ? 32 : 0
            }
            if newRevision {
                table.cancelPendingRename()
                thumbnails.invalidate()
            }
            displayedEntries = EntryFilter.filter(recursiveSearchVisible ? searchEntries : session.entries,
                                                   query: filterField.stringValue)
            displayedURL = session.url
            displayedRevision = session.revision
            table.reloadData()
            let indexes = IndexSet(displayedEntries.indices.filter {
                (sameDirectory || restored != nil) && selection.contains(displayedEntries[$0].url)
            })
            table.selectRowIndexes(indexes, byExtendingSelection: false)
            if !sameDirectory, let pending = pendingReveal,
               pending.url.deletingLastPathComponent().standardizedFileURL.path != displayedURL.standardizedFileURL.path {
                pendingReveal = nil
            }
            if let restored {
                view.layoutSubtreeIfNeeded()
                scroll.contentView.scroll(to: NSPoint(x: 0, y: restored.scrollOffset))
                scroll.reflectScrolledClipView(scroll.contentView)
            } else if !sameDirectory {
                view.layoutSubtreeIfNeeded()
                if !displayedEntries.isEmpty { table.scrollRowToVisible(0) }
            }
            applyPendingReveal()
            if newRevision, sameDirectory, recursiveSearchVisible { runRecursiveSearch() }
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

    private var looksFocused = false

    func setFocusedLook(_ focused: Bool) {
        looksFocused = focused
        applyChrome()
    }

    private func applyChrome() {
        scroll.wantsLayer = true
        scroll.layer?.cornerRadius = 15
        scroll.layer?.masksToBounds = true
        scroll.backgroundColor = Studio.card
        table.backgroundColor = Studio.card
        card.fill = looksFocused ? Studio.accent : Studio.hairline
        card.needsDisplay = true
        view.needsDisplay = true
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
        if recursiveSearchVisible {
            if searchIsRunning { return "하위 폴더 검색 중… \(session.url.path)" }
            if let searchError { return "검색하지 못했습니다: \(searchError)" }
            return "하위 폴더 검색 \(displayedEntries.count)개 · 선택 \(selectedURLs().count)개 · \(session.url.path)"
        }
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
            openFiles(urls, launchCompletion(context: "파일 열기", urls: urls))
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


    private func launchCompletion(context: String, urls: [URL]) -> PaneLaunch.Completion {
        { [weak self] result in
            guard let self else { return }
            if case .failure(let error) = result {
                let message = "\(context)을(를) 완료하지 못했습니다.\n\(urls.map(\.path).joined(separator: "\n"))\n\(error.localizedDescription)\n파일과 앱이 있는지 확인한 뒤 ‘다른 앱으로 열기’를 선택하거나 다시 시도해 주세요."
                if let present = self.presentLaunchError { present(message) }
                else { self.browser?.alert(message) }
            }
            self.onLaunchOutcome?(result)
        }
    }

    // MARK: Address completion

    func updatePathCompletions() {
        completionGeneration += 1
        let ticket = completionGeneration
        cancelCompletion?()
        completionCandidates = []
        completionTable.reloadData()
        completionScroll.isHidden = true
        completionHeightConstraint?.constant = 0
        let query = pathField.stringValue
        guard !query.isEmpty else { onCompletionChange?(); return }
        cancelCompletion = completeDirectories(query, session.url, session.includeHidden) { [weak self] result in
            guard let self, self.completionGeneration == ticket else { return }
            self.cancelCompletion = nil
            self.completionCandidates = (try? result.get()) ?? []
            self.completionTable.reloadData()
            self.completionScroll.isHidden = self.completionCandidates.isEmpty
            self.completionHeightConstraint?.constant = CGFloat(min(5, self.completionCandidates.count)) * 24
            self.completionTable.deselectAll(nil)
            self.onCompletionChange?()
        }
    }

    private func dismissCompletions() {
        completionGeneration += 1
        cancelCompletion?()
        cancelCompletion = nil
        completionCandidates = []
        completionTable.reloadData()
        completionScroll.isHidden = true
        completionHeightConstraint?.constant = 0
    }

    private func acceptCompletion() -> Bool {
        let row = max(0, completionTable.selectedRow)
        guard completionCandidates.indices.contains(row) else { return false }
        pathField.stringValue = completionCandidates[row].path + "/"
        pathField.currentEditor()?.string = pathField.stringValue
        pathField.currentEditor()?.selectedRange = NSRange(location: pathField.stringValue.utf16.count, length: 0)
        dismissCompletions()
        return true
    }

    @objc private func commitCompletion() {
        if acceptCompletion() { commitPath() }
    }

    // MARK: Recursive search and thumbnails

    func showRecursiveSearch() {
        _ = view
        resetFilter()
        recursiveSearchVisible = true
        recursiveSearchField.isHidden = false
        searchTopConstraint?.constant = 8
        searchHeightConstraint?.constant = 32
        if table.tableColumn(withIdentifier: .init("location")) == nil {
            let column = NSTableColumn(identifier: .init("location"))
            column.title = "원래 위치"
            column.width = 260
            column.minWidth = 120
            table.addTableColumn(column)
            table.moveColumn(table.numberOfColumns - 1, toColumn: 1)
        }
        view.window?.makeFirstResponder(recursiveSearchField)
        recursiveSearchField.currentEditor()?.selectAll(nil)
        browser?.focus(self)
        runRecursiveSearch()
    }

    @objc func recursiveSearchChanged() {
        runRecursiveSearch()
    }

    private func runRecursiveSearch() {
        guard recursiveSearchVisible else { return }
        searchGeneration += 1
        let ticket = searchGeneration
        cancelSearch?()
        cancelSearch = nil
        searchError = nil
        searchEntries = []
        thumbnails.invalidate()
        let query = recursiveSearchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        searchIsRunning = !query.isEmpty
        applyFilter()
        guard !query.isEmpty else { onSearchChange?(); return }
        let root = session.url
        cancelSearch = searchFiles(root, query, session.includeHidden) { [weak self] result in
            guard let self, self.searchGeneration == ticket, self.recursiveSearchVisible,
                  self.session.url == root else { return }
            self.cancelSearch = nil
            self.searchIsRunning = false
            switch result {
            case .success(let entries):
                self.searchEntries = FileOps.sorted(entries, by: self.session.sortColumn, ascending: self.session.ascending)
            case .failure(let error):
                self.searchError = error.localizedDescription
            }
            self.applyFilter()
            self.onSearchChange?()
        }
    }

    private func endRecursiveSearch() {
        searchGeneration += 1
        cancelSearch?()
        cancelSearch = nil
        searchIsRunning = false
        recursiveSearchVisible = false
        searchEntries = []
        thumbnails.invalidate()
        searchError = nil
        recursiveSearchField.stringValue = ""
        recursiveSearchField.isHidden = true
        searchTopConstraint?.constant = 0
        searchHeightConstraint?.constant = 0
        if let column = table.tableColumn(withIdentifier: .init("location")) { table.removeTableColumn(column) }
    }

    @discardableResult
    func clearRecursiveSearch() -> Bool {
        guard recursiveSearchVisible else { return false }
        endRecursiveSearch()
        applyFilter()
        view.window?.makeFirstResponder(table)
        onSearchChange?()
        return true
    }

    @objc func revealOriginalFolder() {
        guard let url = selectedURLs().first else { return }
        let parent = url.deletingLastPathComponent()
        endRecursiveSearch()
        pendingReveal = (url, false)
        session.navigate(to: parent)
    }

    func toggleThumbnails() {
        _ = view
        thumbnailsEnabled.toggle()
        thumbnails.invalidate()
        table.rowHeight = thumbnailsEnabled ? 88 : 32
        table.tableColumn(withIdentifier: .init(SortColumn.name.rawValue))?.minWidth = thumbnailsEnabled ? 220 : 140
        table.reloadData()
    }
    // MARK: Filter

    var filterIsActive: Bool {
        !filterField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var filterIsVisible: Bool { !filterField.isHidden }

    func showFilter() {
        _ = view
        filterField.isHidden = false
        if recursiveSearchVisible {
            endRecursiveSearch()
            applyFilter()
        }
        filterTopConstraint?.constant = 8
        filterHeightConstraint?.constant = 32
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
        displayedEntries = EntryFilter.filter(recursiveSearchVisible ? searchEntries : session.entries, query: filterField.stringValue)
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
        onRenameStart?()
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
        if field === filterField || field === recursiveSearchField {
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
        if control === recursiveSearchField {
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                return clearRecursiveSearch()
            }
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                view.window?.makeFirstResponder(table)
                return true
            }
            return false
        }
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
        if commandSelector == #selector(NSResponder.moveDown(_:)) || commandSelector == #selector(NSResponder.moveUp(_:)) {
            guard !completionCandidates.isEmpty else { updatePathCompletions(); return true }
            let step = commandSelector == #selector(NSResponder.moveDown(_:)) ? 1 : -1
            let row = max(0, min(completionCandidates.count - 1, completionTable.selectedRow + step))
            completionTable.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            completionTable.scrollRowToVisible(row)
            return true
        }
        if commandSelector == #selector(NSResponder.insertTab(_:)) {
            if !acceptCompletion() { updatePathCompletions() }
            return true
        }
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            if completionTable.selectedRow >= 0 { _ = acceptCompletion() }
            commitPath()
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            if !completionCandidates.isEmpty {
                dismissCompletions()
                return true
            }
            dismissCompletions()
            pathField.stringValue = session.url.path
            view.window?.makeFirstResponder(table)
            return true
        }
        return false
    }

    func controlTextDidChange(_ obj: Notification) {
        if (obj.object as? NSSearchField) === filterField { applyFilter() }
        if (obj.object as? NSTextField) === pathField { updatePathCompletions() }
        if (obj.object as? NSSearchField) === recursiveSearchField { runRecursiveSearch() }
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        if field === filterField || field === recursiveSearchField { return }
        if field === pathField {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.view.window?.firstResponder !== self.completionTable { self.dismissCompletions() }
                self.show()
            }
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
        tableView === completionTable ? completionCandidates.count : displayedEntries.count
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        if tableView === completionTable { return nil }
        let rowView = tableView.makeView(
            withIdentifier: NSUserInterfaceItemIdentifier("studio-file-row"),
            owner: self
        ) as? StudioRowView ?? StudioRowView()
        rowView.identifier = NSUserInterfaceItemIdentifier("studio-file-row")
        rowView.surface = Studio.card
        rowView.horizontalInset = 6
        return rowView
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView === completionTable {
            guard completionCandidates.indices.contains(row) else { return nil }
            let label = NSTextField(labelWithString: completionCandidates[row].path + "/")
            label.lineBreakMode = .byTruncatingMiddle
            label.toolTip = label.stringValue
            return label
        }
        guard let tableColumn, displayedEntries.indices.contains(row) else { return nil }
        let entry = displayedEntries[row]
        let cell = reusedCell(tableView, column: tableColumn)
        let column = SortColumn(rawValue: tableColumn.identifier.rawValue)
        switch column {
        case .name:
            cell.textField?.stringValue = entry.name
            cell.imageView?.image = NSWorkspace.shared.icon(forFile: entry.url.path)
            if let cell = cell as? PaneNameCell {
                cell.representedURL = entry.url
                cell.imageWidth?.constant = thumbnailsEnabled ? 72 : 18
                cell.imageHeight?.constant = thumbnailsEnabled ? 72 : 18
                if thumbnailsEnabled, !entry.isDirectory {
                    let generation = thumbnails.generation
                    thumbnails.image(for: entry.url) { [weak self, weak cell] image in
                        guard let self, let cell, self.thumbnailsEnabled,
                              self.thumbnails.generation == generation, cell.representedURL == entry.url,
                              let image else { return }
                        cell.imageView?.image = image
                    }
                }
            }
        case .modified:
            cell.textField?.stringValue = dateFormatter.string(from: entry.modified)
        case .kind:
            cell.textField?.stringValue = entry.kind
        case .size:
            cell.textField?.stringValue = entry.isDirectory ? "—" : sizeFormatter.string(fromByteCount: entry.size)
        case nil:
            cell.textField?.stringValue = entry.url.deletingLastPathComponent().path
            cell.textField?.lineBreakMode = .byTruncatingMiddle
            cell.toolTip = entry.url.path
        }
        let name = column == .name
        cell.textField?.textColor = name ? Studio.ink : Studio.muted
        cell.textField?.font = name ? Studio.nameFont : Studio.metaFont
        cell.textField?.alignment = column == .size ? .right : .left
        let cut = browser?.isCut(entry.url) ?? false
        cell.alphaValue = cut ? 0.45 : 1
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard notification.object as? NSTableView === table else { return }
        reloadPreviewIfShowing()
        loadStatus.stringValue = summary()
        loadStatus.toolTip = loadStatus.stringValue
        browser?.updateStatus()
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard tableView === table else { return }
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
        browser?.focus(self)
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
            #selector(revealOriginalFolder): recursiveSearchVisible && selection.count == 1,
            #selector(BrowserWindowController.previewSelection): state.open && table.editedRow < 0,
            #selector(BrowserWindowController.addCurrentFolderToFavorites): browser?.canAddCurrentFolderToFavorites ?? false,
        ]
        for item in menu.items {
            if let action = item.action, let value = enabled[action] { item.isEnabled = value }
            if item.action == #selector(revealOriginalFolder) { item.isHidden = !recursiveSearchVisible }
            if item.action == #selector(BrowserWindowController.copyToOther) ||
                item.action == #selector(BrowserWindowController.moveToOther) {
                item.isEnabled = browser?.configureTransferMenuItem(item) ?? false
            }
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
        openWithApp(urls, app, launchCompletion(context: "\(app.lastPathComponent)에서 열기", urls: urls))
    }

    @objc func copyPathSelection() {
        browser?.copyPaths(selectedURLs())
    }

    @objc func openInTerminalAction() {
        let selected = table.selectedRowIndexes.compactMap { index in
            displayedEntries.indices.contains(index) ? displayedEntries[index] : nil
        }
        let current = recursiveSearchVisible && selected.count == 1
            ? selected[0].url.deletingLastPathComponent() : displayedURL
        let folder = MenuState.terminalFolder(selection: selected, current: current)
        openInTerminal(folder, launchCompletion(context: "터미널에서 열기", urls: [folder]))
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
        let typed = (pathField.stringValue as NSString).expandingTildeInPath
        dismissCompletions()
        let target = typed.hasPrefix("/") ? URL(fileURLWithPath: typed) : session.url.appendingPathComponent(typed)
        session.navigate(to: target)
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
        menu.addItem(NSMenuItem(title: "미리보기 (Space)", action: #selector(BrowserWindowController.previewSelection), keyEquivalent: ""))
        menu.addItem(.separator())
        let items: [(String, Selector)] = [
            ("새 폴더", #selector(makeFolder)),
            ("새 텍스트 파일", #selector(makeTextFile)),
            ("잘라두기", #selector(BrowserWindowController.cut(_:))),
            ("복사", #selector(BrowserWindowController.copy(_:))),
            ("붙여넣기", #selector(BrowserWindowController.paste(_:))),
            ("반대쪽으로 복사 (F5)", #selector(BrowserWindowController.copyToOther)),
            ("반대쪽으로 이동 (F6)", #selector(BrowserWindowController.moveToOther)),
            ("이름 바꾸기", #selector(beginRename)),
            ("휴지통으로 옮기기", #selector(trashSelection)),
            ("압축", #selector(compressSelection)),
            ("경로 복사", #selector(copyPathSelection)),
            ("원래 폴더에서 보기", #selector(revealOriginalFolder)),
            ("정보 보기", #selector(showInfo)),
            ("터미널에서 열기", #selector(openInTerminalAction)),
            ("현재 폴더를 즐겨찾기에 추가", #selector(BrowserWindowController.addCurrentFolderToFavorites)),
        ]
        for (title, action) in items {
            if title == "잘라두기" || title == "이름 바꾸기" || title == "압축" || title == "경로 복사" {
                menu.addItem(.separator())
            }
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            if [#selector(makeFolder), #selector(makeTextFile), #selector(openSelection), #selector(beginRename),
                #selector(trashSelection), #selector(compressSelection), #selector(copyPathSelection),
                #selector(showInfo), #selector(openInTerminalAction), #selector(revealOriginalFolder)].contains(action) {
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
        let cell = PaneNameCell()
        cell.identifier = column.identifier
        let text = NSTextField()
        text.isBezeled = false
        text.drawsBackground = false
        text.font = column.identifier.rawValue == SortColumn.name.rawValue ? Studio.nameFont : Studio.metaFont
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
            cell.imageWidth = image.widthAnchor.constraint(equalToConstant: 18)
            cell.imageHeight = image.heightAnchor.constraint(equalToConstant: 18)
            NSLayoutConstraint.activate([
                image.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 10),
                image.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                cell.imageWidth!,
                cell.imageHeight!,
                text.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 8),
                text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
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
        Column(rawValue: SortColumn.name.rawValue, title: "이름", width: 220),
        Column(rawValue: SortColumn.modified.rawValue, title: "수정한 날짜", width: 148),
        Column(rawValue: SortColumn.kind.rawValue, title: "종류", width: 100),
        Column(rawValue: SortColumn.size.rawValue, title: "크기", width: 88),
    ]
}
