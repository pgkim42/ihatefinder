import AppKit
import Quartz
import IHateFinderCore

final class BrowserWindowController: NSWindowController, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate, NSMenuItemValidation {
    let left: FilePaneController
    let right: FilePaneController
    let sidebar = NSTableView()
    private let status = NSTextField(labelWithString: "")
    private let transferProgress = NSProgressIndicator()
    private let cancelTransferButton = NSButton(title: "취소", target: nil, action: nil)
    private let paneSplitController = NSSplitViewController()
    private let outerSplitController = NSSplitViewController()
    private var paneSplit: NSSplitView {
        _ = paneSplitController.view
        return paneSplitController.splitView
    }
    private var places: [SidebarItem] = []
    private var focused: FilePaneController
    private var dual = false
    var busy = false {
        didSet { onFileOperationStateChange?() }
    }
    var onFileOperationStateChange: (() -> Void)?
    private let clipboard: FileClipboard
    private let workspaceStore: WorkspaceStore?
    private let favoriteStore: FavoritePlacesStore?
    private(set) var favoritePlaces: [URL] = []
    private(set) var placesRevision = 0
    private var transferCancellation: FileTransferCancellation?
    private var rememberedChoice: NameConflict?
    let undoJournal = FileUndoJournal()
    /// Set on the main thread before any alert, so tests can assert on the outcome.
    private(set) var lastTrashReport: FileTrashReport?
    private(set) var lastUndoReport: FileUndoReport?
    private(set) var lastCompressResult: Result<URL, FileOpError>?
    /// Test seam: the production runner is `ditto`.
    var compressRunner: CompressRunner = FileOps.dittoRunner
    private var keyMonitor: Any?


    /// `makeOps` and `initialURLs` are the test seam. Production uses the defaults, which
    /// is the only place `cloneOnSameVolume` is switched on. With `initialURLs`, saved
    /// state is ignored and both sessions start at those folders.
    init(
        workspaceStore: WorkspaceStore? = WorkspaceStore(),
        favoriteStore: FavoritePlacesStore? = nil,
        pasteboard: NSPasteboard = .general,
        makeOps: @escaping () -> FileOps = { FileOps(cloneOnSameVolume: true) },
        initialURLs: (left: URL, right: URL)? = nil
    ) {
        self.workspaceStore = workspaceStore
        self.favoriteStore = favoriteStore ?? (initialURLs == nil ? FavoritePlacesStore() : nil)
        favoritePlaces = self.favoriteStore?.load() ?? []
        clipboard = FileClipboard(pasteboard: pasteboard)
        let saved = initialURLs == nil ? workspaceStore?.load() : nil
        let leftSession: BrowserSession
        let rightSession: BrowserSession
        if let initialURLs {
            leftSession = BrowserSession(url: initialURLs.left, ops: makeOps())
            rightSession = BrowserSession(url: initialURLs.right, ops: makeOps())
        } else {
            leftSession = saved.map { BrowserSession(restoring: $0.left, ops: makeOps()) } ?? Self.makeSession(ops: makeOps())
            rightSession = saved.map { BrowserSession(restoring: $0.right, ops: makeOps()) } ?? Self.makeSession(ops: makeOps())
        }
        dual = saved?.dual ?? false
        left = FilePaneController(session: leftSession)
        right = FilePaneController(session: rightSession)
        focused = left
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1120, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "IHateFinder"
        window.minSize = NSSize(width: 800, height: 480)
        window.center()
        super.init(window: window)
        left.browser = self
        right.browser = self
        window.delegate = self
        installContent()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event) ?? event
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(refreshPlaces),
            name: NSWorkspace.didMountNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(refreshPlaces),
            name: NSWorkspace.didUnmountNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(syncClipboard),
            name: NSApplication.didBecomeActiveNotification, object: nil
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
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    func updateStatus() {
        saveWorkspace()
        guard !busy else { return }
        status.stringValue = focused.summary()
        window?.title = focused.session.url.lastPathComponent
        left.setFocusedLook(focused === left)
        right.setFocusedLook(dual && focused === right)
    }

    func focus(_ pane: FilePaneController) {
        focused = pane
        if QLPreviewPanel.sharedPreviewPanelExists(), QLPreviewPanel.shared().isVisible {
            QLPreviewPanel.shared().updateController()
        }
        updateStatus()
    }

    var isFileOperationRunning: Bool { busy }

    func saveWorkspace() {
        workspaceStore?.save(left: left.session, right: right.session, dual: dual)
    }

    func canClose() -> Bool {
        guard !busy else {
            alert("파일 작업이 진행 중입니다. 작업을 완료하거나 취소한 뒤 닫으십시오.")
            return false
        }
        saveWorkspace()
        return true
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        canClose()
    }

    @objc private func syncClipboard() {
        if clipboard.synchronize() { reloadTables() }
    }

    func runFocusRepro() -> String {
        toggleDual()
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("ihatefinder-focus-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        let leftDir = root.appendingPathComponent("left", isDirectory: true)
        let rightDir = root.appendingPathComponent("right", isDirectory: true)
        try? fm.createDirectory(at: leftDir, withIntermediateDirectories: true)
        try? fm.createDirectory(at: rightDir, withIntermediateDirectories: true)
        fm.createFile(atPath: leftDir.appendingPathComponent("left-only.txt").path, contents: Data("L".utf8))
        fm.createFile(atPath: rightDir.appendingPathComponent("right-only.txt").path, contents: Data("R".utf8))
        left.session.navigate(to: leftDir)
        right.session.navigate(to: rightDir)
        let deadline = Date().addingTimeInterval(10)
        while (left.session.isLoading || right.session.isLoading), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        guard left.session.url == leftDir, right.session.url == rightDir,
              !left.session.isLoading, !right.session.isLoading else {
            return "focusReproFailed=directoryLoad"
        }
        left.table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        right.table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        window?.makeFirstResponder(right.table)
        let rightIsResponder = window?.firstResponder === right.table
        let deleteFires = focused.tableIsResponder
        let keyTarget = focused.selectedURLs().first?.lastPathComponent ?? "none"
        copy(nil)
        let copied = clipboard.snapshot()?.urls.first?.lastPathComponent ?? "none"
        let pasteDest = focused.session.url.lastPathComponent
        let context = KeyContext(tableIsResponder: true, textIsResponder: false)
        let backspace = KeyCommand.resolve(keyCode: 51, characters: "\u{7f}", flags: [], context: context)
        let forwardDelete = KeyCommand.resolve(keyCode: 117, characters: "\u{f728}", flags: [.function], context: context)
        return [
            "firstResponderRight=\(rightIsResponder)",
            "copied=\(copied)",
            "pasteDest=\(pasteDest)",
            "deleteFires=\(deleteFires)",
            "deleteTarget=\(keyTarget)",
            "f6Source=\(keyTarget)",
            "backspace=\(backspace == .goBack ? "goBack" : "other")",
            "forwardDelete=\(forwardDelete == .trash ? "trash" : "other")",
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

    /// Shows what another app asked for in the focused pane. Navigation and selection only.
    func handleOpen(_ request: OpenRequest) {
        if window?.isMiniaturized == true { window?.deminiaturize(nil) }
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        switch request {
        case .failure(let message):
            alert(message)
        case .showFolder(let url):
            focused.navigateSidebar(url)
            window?.makeFirstResponder(focused.table)
        case .reveal(let parent, let item):
            focused.navigateSidebar(parent)
            focused.revealAfterReload(item, rename: false)
            window?.makeFirstResponder(focused.table)
        }
    }

    /// Replaces the clipboard with the paths as text; ends any cut intent.
    func copyPaths(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        if !clipboard.writeText(MenuState.pathText(urls)) { alert("클립보드에 경로를 기록하지 못했습니다.") }
        reloadTables()
    }

    func isCut(_ url: URL) -> Bool {
        clipboard.isCut(url)
    }

    func resolveConflict(_ name: String) -> NameConflict {
        if Thread.isMainThread {
            return askConflict(name)
        }
        return DispatchQueue.main.sync { self.askConflict(name) }
    }

    func failureMessage(_ error: Error, _ failure: String) -> String {
        (error as? FileOpError)?.message ?? "\(failure) \(error.localizedDescription)"
    }

    /// Runs `work` off the main thread while the browser is busy. A successful or partially
    /// failed run delivers its value to `completion` on main before the panes reload; an
    /// error shows an alert after the reload. Returns false when another operation is running.
    @discardableResult
    func runReporting<T>(_ failure: String, work: @escaping () throws -> T, completion: @escaping (T) -> Void) -> Bool {
        guard !busy else {
            alert("파일 작업이 진행 중입니다. 완료한 뒤 다시 시도하십시오.")
            return false
        }
        busy = true
        rememberedChoice = nil
        status.stringValue = "파일 작업 중…"
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try work() }
            DispatchQueue.main.async {
                self.busy = false
                switch result {
                case .success(let value):
                    completion(value)
                    self.reloadPanes()
                case .failure(let error):
                    self.reloadPanes()
                    self.alert(self.failureMessage(error, failure))
                }
            }
        }
        return true
    }

    func run(_ failure: String, after: (() -> Void)? = nil, work: @escaping () throws -> Void) {
        runReporting(failure, work: work, completion: { after?() })
    }

    func recordUndo(_ record: UndoRecord?) {
        if let record { undoJournal.push(record) }
    }

    func finishTrash(_ report: FileTrashReport, record: UndoRecord?) {
        lastTrashReport = report
        recordUndo(record)
        if let message = report.failureMessage { alert(message) }
    }

    /// Undoes the last file operation. Refused (no pop) while another operation runs.
    @objc func undoFileOperation() {
        guard !busy else {
            alert("파일 작업이 진행 중입니다. 완료한 뒤 다시 시도하십시오.")
            return
        }
        guard let record = undoJournal.popLast() else { return }
        let ops = focused.session.ops
        runReporting("되돌리지 못했습니다.", work: { ops.undo(record) }, completion: { [weak self] report in
            guard let self else { return }
            self.lastUndoReport = report
            for url in report.restoredURLs {
                let folder = url.deletingLastPathComponent().standardizedFileURL.path
                for pane in [self.left, self.right] where pane.session.url.path == folder {
                    pane.revealAfterReload(url, rename: false)
                }
            }
            let skipped = report.skipped
            let partial = report.partial
            if !skipped.isEmpty || !partial.isEmpty {
                let lines = (partial + skipped).compactMap(\.message).joined(separator: "\n")
                let partialText = partial.isEmpty ? "" : ", 일부만 되돌린 항목 \(partial.count)개"
                self.alert("실행 취소(\(report.title)): 되돌린 항목 \(report.undone.count)개\(partialText), 건너뛴 항목 \(skipped.count)개.\n\(lines)")
            }
        })
    }

    func drop(_ urls: [URL], onto dest: URL, moving: Bool) {
        runTransfer(urls: urls, to: dest, moving: moving)
    }

    private func runTransfer(urls: [URL], to destination: URL, moving: Bool, pasting: Bool = false, clipboardSnapshot: FileClipboard.Snapshot? = nil) {
        guard !busy else {
            alert("파일 작업이 진행 중입니다. 완료한 뒤 다시 시도하십시오.")
            return
        }
        let ops = focused.session.ops
        let snapshot = clipboardSnapshot ?? clipboard.snapshot()
        let cancellation = beginCancellableJob(status: moving ? "옮기는 중…" : "복사하는 중…")
        let progress: (FileTransferProgress) -> Void = { [weak self] progress in
            DispatchQueue.main.async {
                guard let self, self.transferCancellation === cancellation else { return }
                self.updateTransferProgress(progress, cancellation: cancellation)
            }
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let report: FileTransferReport
            let record: UndoRecord?
            if pasting {
                report = ops.paste(urls: urls, cut: moving, into: destination, resolve: self.resolveConflict, cancellation: cancellation, progress: progress)
            } else {
                report = ops.transfer(urls: urls, to: destination, moving: moving, resolve: self.resolveConflict, cancellation: cancellation, progress: progress)
            }
            record = ops.undoRecord(transfer: report, moving: moving)
            DispatchQueue.main.async {
                self.endCancellableJob()
                self.recordUndo(record)
                if moving, let snapshot {
                    self.clipboard.consume(report.completedSources, from: snapshot)
                }
                self.reloadPanes()
                self.showTransferResult(report)
            }
        }
    }

    /// Marks the browser busy and shows the progress bar with the 취소 button. Main thread only.
    private func beginCancellableJob(status text: String) -> FileTransferCancellation {
        let cancellation = FileTransferCancellation()
        transferCancellation = cancellation
        busy = true
        rememberedChoice = nil
        status.stringValue = text
        transferProgress.isHidden = false
        transferProgress.isIndeterminate = true
        transferProgress.startAnimation(nil)
        cancelTransferButton.isHidden = false
        cancelTransferButton.isEnabled = true
        return cancellation
    }

    private func endCancellableJob() {
        busy = false
        transferCancellation = nil
        transferProgress.stopAnimation(nil)
        transferProgress.isHidden = true
        cancelTransferButton.isHidden = true
    }

    /// Zips one item next to itself. Cancellable; the undo record trashes the zip.
    func compress(_ url: URL) {
        guard !busy else {
            alert("파일 작업이 진행 중입니다. 완료한 뒤 다시 시도하십시오.")
            return
        }
        let ops = focused.session.ops
        let runner = compressRunner
        let cancellation = beginCancellableJob(status: "압축하는 중… \(url.lastPathComponent)")
        DispatchQueue.global(qos: .userInitiated).async {
            let result = ops.compress(url, cancellation: cancellation, runner: runner)
            let record: UndoRecord?
            if case .success(let zip) = result { record = ops.undoRecord(compressed: zip) } else { record = nil }
            DispatchQueue.main.async {
                self.endCancellableJob()
                self.recordUndo(record)
                self.lastCompressResult = result
                switch result {
                case .success(let zip):
                    let folder = zip.deletingLastPathComponent().standardizedFileURL.path
                    for pane in [self.left, self.right] where pane.session.url.path == folder {
                        pane.revealAfterReload(zip, rename: false)
                    }
                    self.reloadPanes()
                case .failure(let error):
                    self.reloadPanes()
                    if error != .compressCancelled { self.alert(error.message) }
                }
            }
        }
    }

    @objc private func cancelTransfer() {
        transferCancellation?.cancel()
        cancelTransferButton.isEnabled = false
        status.stringValue = "취소하는 중… 완료된 항목은 유지합니다."
    }

    private func updateTransferProgress(_ progress: FileTransferProgress, cancellation: FileTransferCancellation) {
        guard !cancellation.isCancelled else { return }
        let operation = progress.operation == .move ? "이동" : "복사"
        let phase: String
        switch progress.phase {
        case .preparing: phase = "준비"
        case .copying: phase = "전송"
        case .committing: phase = "확정"
        case .finished: phase = "처리 완료"
        }
        var detail = "\(operation) · \(phase) · 완료 \(progress.processedItems)/\(progress.totalItems) · \(progress.currentFile.lastPathComponent)"
        if let total = progress.totalBytes, total > 0, progress.phase == .copying {
            transferProgress.stopAnimation(nil)
            transferProgress.isIndeterminate = false
            transferProgress.doubleValue = min(1, Double(progress.bytesCopied) / Double(total))
            detail += " · \(ByteCountFormatter.string(fromByteCount: progress.bytesCopied, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))"
        } else {
            transferProgress.isIndeterminate = true
            transferProgress.startAnimation(nil)
        }
        status.stringValue = detail
        status.toolTip = progress.currentFile.path
    }

    private func showTransferResult(_ report: FileTransferReport) {
        guard report.items.contains(where: { $0.status != .completed || $0.message != nil || $0.recovery != nil }) else { return }
        let details = report.items.map { item -> String in
            let state: String
            switch item.status {
            case .completed: state = "완료"
            case .skipped: state = "건너뜀"
            case .failed: state = "실패"
            case .unprocessed: state = "미처리"
            case .cancelled: state = "취소"
            }
            var lines = ["[\(state)] \(item.source.path)", "대상: \(item.destination.path)"]
            if let message = item.message { lines.append(message) }
            if let recovery = item.recovery {
                lines.append(recovery.message)
                lines.append(contentsOf: recovery.locations.map(\.path))
            }
            return lines.joined(separator: "\n")
        }.joined(separator: "\n\n")
        let result = NSAlert()
        result.messageText = "파일 작업 결과"
        result.informativeText = "완료 \(report.items.filter { $0.status == .completed }.count) · 건너뜀 \(report.items.filter { $0.status == .skipped }.count) · 실패 \(report.items.filter { $0.status == .failed }.count) · 취소 \(report.items.filter { $0.status == .cancelled }.count) · 미처리 \(report.items.filter { $0.status == .unprocessed }.count)"
        result.addButton(withTitle: "확인")
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 560, height: 260))
        scroll.hasVerticalScroller = true
        let text = NSTextView(frame: scroll.bounds)
        text.isEditable = false
        text.isSelectable = true
        text.font = .systemFont(ofSize: 12)
        text.string = details
        text.isVerticallyResizable = true
        text.autoresizingMask = [.width]
        text.textContainer?.widthTracksTextView = true
        scroll.documentView = text
        result.accessoryView = scroll
        if let window { result.beginSheetModal(for: window) }
    }

    @objc func makeFolder() { focused.makeFolder() }
    @objc func makeTextFile() { focused.makeTextFile() }
    @objc func trashSelection() { focused.trashSelection() }
    @objc func beginRename() { focused.beginRename() }
    @objc func findInFolder() { focused.showFilter() }

    @objc func previewSelection() {
        guard focused.table.editedRow < 0, !focused.selectedURLs().isEmpty else { return }
        window?.makeFirstResponder(focused.table)
        focused.toggleQuickLook()
    }

    func configureTransferMenuItem(_ item: NSMenuItem) -> Bool {
        let copying = item.action == #selector(copyToOther)
        let destination = other().session.url
        item.title = "반대쪽 \(destination.lastPathComponent)으로 \(copying ? "복사" : "이동") (\(copying ? "F5" : "F6"))"
        item.toolTip = destination.path
        return dual && !busy && focused.table.editedRow < 0 && !focused.selectedURLs().isEmpty
    }

    var canAddCurrentFolderToFavorites: Bool {
        focused.session.persistedState != nil && !favoritePlaces.contains(focused.session.url)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(copyToOther), #selector(moveToOther):
            return configureTransferMenuItem(menuItem)
        case #selector(previewSelection):
            return focused.table.editedRow < 0 && !focused.selectedURLs().isEmpty
        case #selector(addCurrentFolderToFavorites):
            return canAddCurrentFolderToFavorites
        default:
            return true
        }
    }

    @objc func addCurrentFolderToFavorites() {
        guard canAddCurrentFolderToFavorites else { return }
        let url = URL(fileURLWithPath: focused.session.url.standardizedFileURL.path, isDirectory: true)
        favoritePlaces.append(url)
        favoriteStore?.save(favoritePlaces)
        refreshPlaces()
    }

    @objc func openFavorite(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL, favoritePlaces.contains(url) else { return }
        focused.navigateSidebar(url)
        window?.makeFirstResponder(focused.table)
    }

    @objc func removeFavorite(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL,
              let index = favoritePlaces.firstIndex(of: url) else { return }
        favoritePlaces.remove(at: index)
        favoriteStore?.save(favoritePlaces)
        refreshPlaces()
    }

    @objc func moveFavoriteUp(_ sender: NSMenuItem) { moveFavorite(sender, offset: -1) }
    @objc func moveFavoriteDown(_ sender: NSMenuItem) { moveFavorite(sender, offset: 1) }

    private func moveFavorite(_ sender: NSMenuItem, offset: Int) {
        guard let url = sender.representedObject as? URL,
              let index = favoritePlaces.firstIndex(of: url),
              favoritePlaces.indices.contains(index + offset) else { return }
        favoritePlaces.swapAt(index, index + offset)
        favoriteStore?.save(favoritePlaces)
        refreshPlaces()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === sidebar.menu else { return }
        let row = sidebar.clickedRow >= 0 ? sidebar.clickedRow : sidebar.selectedRow
        let url: URL?
        if places.indices.contains(row), case .favorite(let favorite) = places[row] {
            url = favorite
        } else {
            url = nil
        }
        let index = url.flatMap { favoritePlaces.firstIndex(of: $0) }
        for item in menu.items {
            item.representedObject = url
            switch item.action {
            case #selector(openFavorite): item.isEnabled = index != nil
            case #selector(removeFavorite): item.isEnabled = index != nil
            case #selector(moveFavoriteUp): item.isEnabled = index.map { $0 > 0 } ?? false
            case #selector(moveFavoriteDown): item.isEnabled = index.map { $0 + 1 < favoritePlaces.count } ?? false
            default: break
            }
        }
    }

    @objc func cut(_ sender: Any?) {
        let urls = focused.selectedURLs()
        guard !urls.isEmpty else { return }
        guard clipboard.cut(urls) else { alert("클립보드에 파일을 기록하지 못했습니다."); return }
        reloadTables()
    }

    @objc func copy(_ sender: Any?) {
        let urls = focused.selectedURLs()
        guard !urls.isEmpty else { return }
        guard clipboard.copy(urls) else { alert("클립보드에 파일을 기록하지 못했습니다."); return }
        reloadTables()
    }

    @objc func paste(_ sender: Any?) {
        guard let snapshot = clipboard.snapshot() else { return }
        runTransfer(urls: snapshot.urls, to: focused.session.url, moving: snapshot.isCut, pasting: true, clipboardSnapshot: snapshot)
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
        paneSplitController.splitViewItems[1].isCollapsed = !dual
        window?.contentView?.layoutSubtreeIfNeeded()
        if dual { paneSplit.setPosition(paneSplit.bounds.width / 2, ofDividerAt: 0) }
        if !dual, focused === right {
            focused = left
            window?.makeFirstResponder(left.table)
        }
        updateStatus()
    }

    @objc func refreshPlaces() {
        places = Self.loadPlaces(favorites: favoritePlaces)
        placesRevision += 1
        sidebar.reloadData()
    }

    private func installContent() {
        guard let window else { return }
        let content = NSView()
        
        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 8
        buttons.addArrangedSubview(toolbarButton("뒤로", #selector(goBackAction), "chevron.left"))
        buttons.addArrangedSubview(toolbarButton("앞으로", #selector(goForwardAction), "chevron.right"))
        buttons.addArrangedSubview(toolbarButton("위", #selector(goUpAction), "chevron.up"))
        
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.widthAnchor.constraint(equalToConstant: 12).isActive = true
        buttons.addArrangedSubview(spacer)
        
        buttons.addArrangedSubview(toolbarButton("양쪽 창", #selector(toggleDual), "rectangle.split.2x1"))

        sidebar.headerView = nil
        sidebar.rowHeight = 24
        sidebar.allowsEmptySelection = true
        sidebar.dataSource = self
        sidebar.delegate = self
        sidebar.target = self
        sidebar.action = #selector(openPlace)
        let placesMenu = NSMenu()
        placesMenu.autoenablesItems = false
        placesMenu.delegate = self
        for (title, action) in [
            ("즐겨찾기 열기", #selector(openFavorite(_:))),
            ("즐겨찾기에서 제거", #selector(removeFavorite(_:))),
            ("즐겨찾기 위로 이동", #selector(moveFavoriteUp(_:))),
            ("즐겨찾기 아래로 이동", #selector(moveFavoriteDown(_:))),
        ] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            placesMenu.addItem(item)
        }
        sidebar.menu = placesMenu
        sidebar.style = .sourceList
        sidebar.floatsGroupRows = true
        sidebar.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        sidebar.intercellSpacing = NSSize(width: 4, height: 1)
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("place"))
        column.title = ""
        column.width = 200
        column.minWidth = 160
        sidebar.addTableColumn(column)
        let sidebarScroll = NSScrollView()
        sidebarScroll.documentView = sidebar
        sidebarScroll.hasVerticalScroller = true
        sidebarScroll.drawsBackground = true
        sidebarScroll.borderType = .noBorder

        paneSplit.isVertical = true
        paneSplit.dividerStyle = .thin
        let leftItem = NSSplitViewItem(viewController: left)
        leftItem.minimumThickness = 260
        let rightItem = NSSplitViewItem(viewController: right)
        rightItem.minimumThickness = 260
        rightItem.canCollapse = true
        rightItem.isCollapsed = !dual
        paneSplitController.addSplitViewItem(leftItem)
        paneSplitController.addSplitViewItem(rightItem)

        let sidebarController = NSViewController()
        sidebarController.view = sidebarScroll
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarController)
        sidebarItem.minimumThickness = 160
        sidebarItem.maximumThickness = 240
        sidebarItem.canCollapse = false
        sidebarItem.holdingPriority = .defaultHigh
        let panesItem = NSSplitViewItem(viewController: paneSplitController)
        panesItem.minimumThickness = 260
        outerSplitController.addSplitViewItem(sidebarItem)
        outerSplitController.addSplitViewItem(panesItem)
        _ = outerSplitController.view
        let outer = outerSplitController.splitView
        outer.isVertical = true
        outer.dividerStyle = .thin

        status.font = .systemFont(ofSize: 11, weight: .regular)
        status.textColor = .secondaryLabelColor
        status.lineBreakMode = .byTruncatingTail
        transferProgress.style = .bar
        transferProgress.minValue = 0
        transferProgress.maxValue = 1
        transferProgress.isHidden = true
        transferProgress.widthAnchor.constraint(equalToConstant: 160).isActive = true
        cancelTransferButton.target = self
        cancelTransferButton.action = #selector(cancelTransfer)
        cancelTransferButton.bezelStyle = .rounded
        cancelTransferButton.controlSize = .small
        cancelTransferButton.isHidden = true
        let footer = NSStackView(views: [status, transferProgress, cancelTransferButton])
        footer.orientation = .horizontal
        footer.spacing = 10
        footer.edgeInsets = NSEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        status.setContentHuggingPriority(.defaultLow, for: .horizontal)
        status.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        for item in [buttons, outer, footer] {
            item.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(item)
        }
        NSLayoutConstraint.activate([
            buttons.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            buttons.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            outer.topAnchor.constraint(equalTo: buttons.bottomAnchor, constant: 12),
            outer.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            outer.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            footer.topAnchor.constraint(equalTo: outer.bottomAnchor, constant: 8),
            footer.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -10),
            buttons.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -12),
        ])
        window.contentView = content
        refreshPlaces()
        updateStatus()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.window?.makeFirstResponder(self.left.table)
            self.window?.contentView?.layoutSubtreeIfNeeded()
            self.outerPosition(outer)
        }
    }

    private func outerPosition(_ outer: NSSplitView) {
        outer.setPosition(200, ofDividerAt: 0)
        if dual { paneSplit.setPosition(paneSplit.bounds.width / 2, ofDividerAt: 0) }
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard event.window === window else { return event }
        guard let command = KeyCommand.resolve(
            keyCode: event.keyCode,
            characters: event.charactersIgnoringModifiers ?? "",
            flags: event.modifierFlags,
            context: keyContext()
        ) else { return event }
        return perform(command) ? nil : event
    }

    private func keyContext() -> KeyContext {
        KeyContext(tableIsResponder: focused.tableIsResponder, textIsResponder: window?.firstResponder is NSTextView)
    }

    /// Returns false when the key should still reach the responder chain.
    private func perform(_ command: KeyCommand) -> Bool {
        switch command {
        case .focusPath: focused.focusPath()
        case .find: focused.showFilter()
        case .info: focused.showInfo()
        case .send(let selector): NSApp.sendAction(selector, to: nil, from: nil)
        case .copy: copy(nil)
        case .cut: cut(nil)
        case .paste: paste(nil)
        case .selectAll: focused.table.selectAll(nil)
        case .newFolder: focused.makeFolder()
        case .newTextFile: focused.makeTextFile()
        case .toggleHidden: toggleHidden()
        case .goUp: focused.goUp()
        case .goBack: focused.goBack()
        case .goForward: focused.goForward()
        case .copyToOther: copyToOther()
        case .moveToOther: moveToOther()
        case .rename: focused.beginRename()
        case .clearCut: return clearCut()
        case .trash: focused.trashSelection()
        case .open: focused.openSelection()
        }
        return true
    }

    @objc func copyToOther() {
        guard dual, !busy, focused.table.editedRow < 0 else { return }
        let urls = focused.selectedURLs()
        guard !urls.isEmpty else { return }
        let dest = other().session.url
        runTransfer(urls: urls, to: dest, moving: false)
    }

    @objc func moveToOther() {
        guard dual, !busy, focused.table.editedRow < 0 else { return }
        let urls = focused.selectedURLs()
        guard !urls.isEmpty else { return }
        let dest = other().session.url
        runTransfer(urls: urls, to: dest, moving: true)
    }

    private func other() -> FilePaneController {
        focused === left ? right : left
    }

    private func clearCut() -> Bool {
        guard clipboard.cancelCut() else { return false }
        reloadTables()
        return true
    }


    private func reloadPanes() {
        left.session.reload()
        right.session.reload()
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

    private func toolbarButton(_ title: String, _ action: Selector, _ symbol: String) -> NSButton {
        let button = NSButton(title: "", target: self, action: action)
        button.bezelStyle = .texturedRounded
        button.imagePosition = .imageOnly
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        button.toolTip = title
        button.widthAnchor.constraint(equalToConstant: 28).isActive = true
        button.heightAnchor.constraint(equalToConstant: 24).isActive = true
        return button
    }

    private func button(_ title: String, _ action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        return button
    }

    @objc func openPlace() {
        let row = sidebar.clickedRow >= 0 ? sidebar.clickedRow : sidebar.selectedRow
        guard places.indices.contains(row) else { return }
        let url: URL
        switch places[row] {
        case .place(_, let place, _), .favorite(let place): url = place
        case .header: return
        }
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
            cell.textField?.textColor = .tertiaryLabelColor
            return cell
        case .place(let title, _, let symbol):
            let cell = sidebarCell(tableView, identifier: "place", symbol: symbol)
            cell.textField?.stringValue = title
            cell.textField?.font = .systemFont(ofSize: 13, weight: .regular)
            cell.textField?.textColor = .labelColor
            cell.imageView?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            cell.imageView?.contentTintColor = .secondaryLabelColor
            return cell
        case .favorite(let url):
            let cell = sidebarCell(tableView, identifier: "favorite", symbol: "star")
            cell.textField?.stringValue = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
            cell.textField?.font = .systemFont(ofSize: 13)
            cell.textField?.textColor = .labelColor
            cell.toolTip = url.path
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
                image.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 10),
                image.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                image.widthAnchor.constraint(equalToConstant: 16),
                image.heightAnchor.constraint(equalToConstant: 16),
                text.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 6),
                text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -10),
                text.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        } else {
            NSLayoutConstraint.activate([
                text.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 10),
                text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -10),
                text.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }
        return cell
    }

    private static func makeSession(ops: FileOps) -> BrowserSession {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return BrowserSession(url: home, ops: ops)
    }

    private static func loadPlaces(favorites: [URL]) -> [SidebarItem] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        var items: [SidebarItem] = [
            .header("즐겨찾기"),
        ]
        items.append(contentsOf: favorites.map(SidebarItem.favorite))
        items.append(contentsOf: [
            .header("위치"),
            .place(title: "홈", url: home, symbol: "house"),
            .place(title: "데스크탑", url: home.appendingPathComponent("Desktop"), symbol: "desktopcomputer"),
            .place(title: "문서", url: home.appendingPathComponent("Documents"), symbol: "doc.text"),
            .place(title: "다운로드", url: home.appendingPathComponent("Downloads"), symbol: "arrow.down.circle"),
            .place(title: "응용 프로그램", url: URL(fileURLWithPath: "/Applications", isDirectory: true), symbol: "square.grid.2x2"),
        ])
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
    case favorite(URL)
}
