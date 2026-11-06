import AppKit

struct FolderTreeRoot: Equatable {
    let title: String
    let url: URL
    let symbol: String
    var isFavorite = false
}

/// A non-selectable group header followed by its ordered root rows.
struct FolderTreeSection: Equatable {
    let title: String
    let roots: [FolderTreeRoot]
}

struct FolderTreeEntry: Equatable {
    let url: URL
    /// False for symlinked directories, which stay leaves so links can never form a cycle.
    let isExpandable: Bool
}

final class FolderTreeNode {
    enum Kind: Equatable { case section, folder, status, error }

    let kind: Kind
    let title: String
    let url: URL?
    let symbol: String?
    let isFavorite: Bool
    /// Stable identity: section title, root path and own path. Survives root replacement.
    let key: String
    weak var parent: FolderTreeNode?
    var children: [FolderTreeNode] = []
    var isExpandable: Bool
    var isLoaded = false
    var requestID = 0

    init(kind: Kind, title: String, url: URL? = nil, symbol: String? = nil,
         isFavorite: Bool = false, key: String, isExpandable: Bool = false) {
        self.kind = kind
        self.title = title
        self.url = url
        self.symbol = symbol
        self.isFavorite = isFavorite
        self.key = key
        self.isExpandable = isExpandable
    }

    var isFolder: Bool { kind == .folder }
}

/// Lazy, folders-only sidebar tree. Expanding loads one level in the background and never navigates;
/// only a click on a folder row calls `onNavigate`.
final class FolderTreeController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    typealias Loader = (URL, Bool) throws -> [FolderTreeEntry]

    let outlineView = NSOutlineView()
    var onNavigate: ((URL) -> Void)?
    /// Main-queue notification after a reply was applied (`true`) or dropped as stale (`false`).
    var onLoadFinished: ((URL, Bool) -> Void)?
    private(set) var includeHidden: Bool
    private let loader: Loader
    private var sectionNodes: [FolderTreeNode] = []
    private var expandedKeys: Set<String> = []
    private var nextRequestID = 0

    init(includeHidden: Bool = false, loader: @escaping Loader = FolderTreeController.listFolders) {
        self.includeHidden = includeHidden
        self.loader = loader
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    // MARK: Public API

    /// Replaces the roots; expansion is restored by stable path within each section.
    func setSections(_ sections: [FolderTreeSection]) {
        _ = view
        sectionNodes = sections.map { section in
            let node = FolderTreeNode(kind: .section, title: section.title, key: section.title, isExpandable: true)
            node.isLoaded = true
            node.children = section.roots.map { root in
                let key = "\(section.title)\u{0}\(root.url.path)\u{0}\(root.url.path)"
                let child = FolderTreeNode(kind: .folder, title: root.title, url: root.url, symbol: root.symbol,
                                           isFavorite: root.isFavorite, key: key, isExpandable: true)
                child.children = [Self.loadingRow(under: child)]
                child.parent = node
                return child
            }
            return node
        }
        outlineView.reloadData()
        for section in sectionNodes {
            outlineView.expandItem(section)
            restoreExpansion(under: section)
        }
    }

    /// Refresh expanded roots now; collapsed roots reload on their next expansion.
    func refresh() {
        for section in sectionNodes {
            for root in section.children {
                root.isLoaded = false
                root.isExpandable = true
                if outlineView.isItemExpanded(root) {
                    load(root)
                } else {
                    root.requestID = -1
                    root.children = [Self.loadingRow(under: root)]
                    outlineView.reloadItem(root, reloadChildren: true)
                }
            }
        }
    }

    func setIncludeHidden(_ value: Bool) {
        guard value != includeHidden else { return }
        includeHidden = value
        refresh()
    }

    /// Highlights the visible row for `url` without expanding, scrolling into a new place, or navigating.
    func syncHighlight(to url: URL?) {
        guard let path = url?.standardizedFileURL.path else { return outlineView.deselectAll(nil) }
        let rows = 0..<outlineView.numberOfRows
        let matches = rows.filter { (outlineView.item(atRow: $0) as? FolderTreeNode)?.url?.standardizedFileURL.path == path }
        guard let row = matches.contains(outlineView.selectedRow) ? outlineView.selectedRow : matches.first else {
            return outlineView.deselectAll(nil)
        }
        outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    }

    /// Favorite root under the clicked row (or the selection), for favorite menu commands.
    var contextFavoriteURL: URL? {
        guard let node = contextNode, node.isFavorite else { return nil }
        return node.url
    }

    /// Folder under the clicked row (or the selection), for context actions.
    var contextFolderURL: URL? { contextNode?.url }

    // MARK: View

    override func loadView() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("folder"))
        column.minWidth = 180
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.headerView = nil
        outlineView.rowHeight = 28
        outlineView.indentationPerLevel = 14
        outlineView.allowsEmptySelection = true
        outlineView.selectionHighlightStyle = .none
        outlineView.focusRingType = .none
        outlineView.backgroundColor = Studio.rail
        outlineView.style = .plain
        outlineView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.target = self
        outlineView.action = #selector(rowClicked)
        let scroll = NSScrollView()
        scroll.documentView = outlineView
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        scroll.drawsBackground = true
        scroll.backgroundColor = Studio.rail
        scroll.borderType = .noBorder
        view = scroll
    }

    @objc private func rowClicked() { activate(row: outlineView.clickedRow) }

    /// Single click on a folder row navigates; section, status and error rows do nothing.
    func activate(row: Int) {
        guard row >= 0, let node = outlineView.item(atRow: row) as? FolderTreeNode,
              node.isFolder, let url = node.url else { return }
        onNavigate?(url)
    }

    private var contextNode: FolderTreeNode? {
        let row = outlineView.clickedRow >= 0 ? outlineView.clickedRow : outlineView.selectedRow
        guard row >= 0, let node = outlineView.item(atRow: row) as? FolderTreeNode, node.isFolder else { return nil }
        return node
    }

    // MARK: Loading

    private func load(_ node: FolderTreeNode) {
        guard let url = node.url else { return }
        nextRequestID += 1
        let id = nextRequestID
        node.requestID = id
        let hidden = includeHidden
        let loader = loader
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try loader(url, hidden) }
            DispatchQueue.main.async { [weak self] in self?.finish(node, id: id, hidden: hidden, result) }
        }
    }

    private func finish(_ node: FolderTreeNode, id: Int, hidden: Bool, _ result: Result<[FolderTreeEntry], Error>) {
        guard node.requestID == id, hidden == includeHidden, isAttached(node), let url = node.url else {
            if let url = node.url { onLoadFinished?(url, false) }
            return
        }
        switch result {
        case .success(let entries):
            node.isLoaded = true
            node.children = entries.map { child(of: node, entry: $0) }
            // Even an empty directory can gain children before the next refresh.
            node.isExpandable = true
        case .failure(let error):
            node.isLoaded = true
            let reason = error.localizedDescription
            let row = FolderTreeNode(kind: .error, title: "\(url.path): \(reason)", key: node.key + "\u{0}error")
            row.parent = node
            node.children = [row]
            node.isExpandable = true
        }
        outlineView.reloadItem(node, reloadChildren: true)
        restoreExpansion(under: node)
        onLoadFinished?(url, true)
    }

    private func child(of parent: FolderTreeNode, entry: FolderTreeEntry) -> FolderTreeNode {
        let node = FolderTreeNode(kind: .folder, title: entry.url.lastPathComponent, url: entry.url,
                                  symbol: "folder", key: parent.key + "\u{0}" + entry.url.path,
                                  isExpandable: entry.isExpandable)
        node.parent = parent
        if entry.isExpandable { node.children = [Self.loadingRow(under: node)] }
        return node
    }

    private static func loadingRow(under node: FolderTreeNode) -> FolderTreeNode {
        let row = FolderTreeNode(kind: .status, title: "불러오는 중…", key: node.key + "\u{0}loading")
        row.parent = node
        return row
    }

    /// A reply may only touch a node that is still reachable from the current roots.
    private func isAttached(_ node: FolderTreeNode) -> Bool {
        var current = node
        while let parent = current.parent {
            guard parent.children.contains(where: { $0 === current }) else { return false }
            current = parent
        }
        return sectionNodes.contains { $0 === current }
    }

    private func restoreExpansion(under node: FolderTreeNode) {
        for child in node.children where child.isFolder && child.isExpandable && expandedKeys.contains(child.key) {
            outlineView.expandItem(child)
        }
    }

    /// Lists immediate subfolders: no packages, natural order, hidden entries only on request.
    static func listFolders(_ url: URL, includeHidden: Bool) throws -> [FolderTreeEntry] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey, .isSymbolicLinkKey]
        let urls = try FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: keys,
            options: includeHidden ? [] : [.skipsHiddenFiles]
        )
        return urls.compactMap { item -> FolderTreeEntry? in
            guard let values = try? item.resourceValues(forKeys: Set(keys)) else { return nil }
            let isLink = values.isSymbolicLink == true
            let target = isLink ? item.resolvingSymlinksInPath() : item
            guard let targetValues = try? target.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey]),
                  targetValues.isDirectory == true, targetValues.isPackage != true else { return nil }
            return FolderTreeEntry(url: item.standardizedFileURL, isExpandable: !isLink)
        }
        .sorted { $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending }
    }

    // MARK: NSOutlineViewDataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        guard let node = item as? FolderTreeNode else { return sectionNodes.count }
        return node.children.count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        guard let node = item as? FolderTreeNode else { return sectionNodes[index] }
        return node.children[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? FolderTreeNode)?.isExpandable ?? false
    }

    // MARK: NSOutlineViewDelegate

    func outlineViewItemWillExpand(_ notification: Notification) {
        guard let node = notification.userInfo?["NSObject"] as? FolderTreeNode, node.isFolder else { return }
        expandedKeys.insert(node.key)
        if !node.isLoaded { load(node) }
    }

    func outlineViewItemDidCollapse(_ notification: Notification) {
        guard let node = notification.userInfo?["NSObject"] as? FolderTreeNode, node.isFolder else { return }
        expandedKeys.remove(node.key)
        // A later expansion rechecks the directory, including a previous load error.
        node.isLoaded = false
    }

    func outlineView(_ outlineView: NSOutlineView, shouldCollapseItem item: Any) -> Bool {
        (item as? FolderTreeNode)?.kind != .section
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        (item as? FolderTreeNode)?.isFolder ?? false
    }

    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        (item as? FolderTreeNode)?.kind == .section
    }

    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        (item as? FolderTreeNode)?.kind == .section ? 22 : 28
    }

    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        let id = NSUserInterfaceItemIdentifier("studio-folder-row")
        let rowView = outlineView.makeView(withIdentifier: id, owner: self) as? StudioRowView ?? StudioRowView()
        rowView.identifier = id
        rowView.surface = Studio.rail
        rowView.horizontalInset = 8
        return rowView
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? FolderTreeNode else { return nil }
        let cell = cell(outlineView, identifier: node.kind == .section ? "section" : "node", hasImage: node.kind != .section)
        cell.textField?.stringValue = node.title
        cell.toolTip = node.url?.path
        switch node.kind {
        case .section:
            cell.textField?.font = Studio.sectionFont
            cell.textField?.textColor = Studio.muted
        case .folder:
            cell.textField?.font = .systemFont(ofSize: 13, weight: node.isFavorite ? .medium : .regular)
            cell.textField?.textColor = Studio.ink
            let symbol = node.isFavorite ? "star.fill" : node.symbol ?? "folder"
            cell.imageView?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            cell.imageView?.contentTintColor = node.isFavorite ? Studio.accent : Studio.muted
        case .status, .error:
            cell.textField?.font = .systemFont(ofSize: 12)
            cell.textField?.textColor = node.kind == .error ? Studio.accent : Studio.muted
            cell.imageView?.image = NSImage(
                systemSymbolName: node.kind == .error ? "exclamationmark.triangle" : "ellipsis",
                accessibilityDescription: nil
            )
            cell.imageView?.contentTintColor = node.kind == .error ? Studio.accent : Studio.muted
            cell.toolTip = node.kind == .error ? node.title : nil
        }
        return cell
    }

    private func cell(_ outlineView: NSOutlineView, identifier: String, hasImage: Bool) -> NSTableCellView {
        let id = NSUserInterfaceItemIdentifier(identifier)
        if let cell = outlineView.makeView(withIdentifier: id, owner: self) as? NSTableCellView { return cell }
        let cell = NSTableCellView()
        cell.identifier = id
        let text = NSTextField(labelWithString: "")
        text.translatesAutoresizingMaskIntoConstraints = false
        text.lineBreakMode = .byTruncatingMiddle
        cell.addSubview(text)
        cell.textField = text
        var constraints = [
            text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            text.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ]
        if hasImage {
            let image = NSImageView()
            image.translatesAutoresizingMaskIntoConstraints = false
            image.imageScaling = .scaleProportionallyDown
            cell.addSubview(image)
            cell.imageView = image
            constraints += [
                image.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                image.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                image.widthAnchor.constraint(equalToConstant: 16),
                image.heightAnchor.constraint(equalToConstant: 16),
                text.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 6),
            ]
        } else {
            constraints.append(text.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2))
        }
        NSLayoutConstraint.activate(constraints)
        return cell
    }
}
