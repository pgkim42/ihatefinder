import Foundation

/// All state and callbacks belong to the main thread; filesystem work runs off it.
public final class BrowserSession {
    public enum LoadState: Equatable {
        case idle
        case loading(URL)
        case failed(URL, String)
    }

    /// A single history visit, rather than a folder-wide preference.
    public struct ViewState: Equatable {
        public var selection: Set<URL>
        public var scrollOffset: Double
        public var filter: String
        public var filterVisible: Bool
        public var search: SearchState?

        public init(selection: Set<URL>, scrollOffset: Double, filter: String, filterVisible: Bool,
                    search: SearchState? = nil) {
            self.selection = selection
            self.scrollOffset = scrollOffset
            self.filter = filter
            self.filterVisible = filterVisible
            self.search = search
        }
    }

    /// The search root is the URL of the history visit that owns this state.
    public struct SearchState: Equatable {
        public var query: String
        public var includeHidden: Bool

        public init(query: String, includeHidden: Bool) {
            self.query = query
            self.includeHidden = includeHidden
        }
    }

    /// Invoked before every navigation, including requests made outside the pane.
    public var captureViewState: (() -> ViewState)?
    public private(set) var restoredViewState: ViewState?

    public private(set) var url: URL
    public private(set) var entries: [FileEntry] = []
    public private(set) var loadState: LoadState = .idle
    public private(set) var revision = 0
    public private(set) var isSorting = false
    public private(set) var restorationNotice: String?
    public var onChange: (() -> Void)?
    public var includeHidden = false
    public private(set) var sortColumn: SortColumn = .name
    public private(set) var ascending = true
    public var ops: FileOps
    private var backStack: [Visit] = []
    private var forwardStack: [Visit] = []
    private var generation = 0
    private var pending: Request?
    private var observer: DirectoryObserver?
    private var refreshPending = false
    private let listing: ((URL, Bool) throws -> [FileEntry])?
    private let sorting: ([FileEntry], SortColumn, Bool) -> [FileEntry]
    private let observesChanges: Bool
    private var restoration: Restoration?
    private var requiresInitialCommit = false

    public convenience init(url: URL, ops: FileOps = FileOps()) {
        self.init(url: url, ops: ops, listing: nil, observesChanges: true)
    }

    /// Configures startup without reading the filesystem. The pane's first reload starts restoration.
    public convenience init(restoring state: PaneState, ops: FileOps = FileOps(),
                            homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
                            temporaryDirectory: URL = FileManager.default.temporaryDirectory) {
        self.init(restoring: state, ops: ops, homeDirectory: homeDirectory,
                  temporaryDirectory: temporaryDirectory, listing: nil, observesChanges: true)
    }

    convenience init(restoring state: PaneState, ops: FileOps = FileOps(), homeDirectory: URL,
                     temporaryDirectory: URL, listing: ((URL, Bool) throws -> [FileEntry])?,
                     observesChanges: Bool = false) {
        self.init(url: state.url, ops: ops, listing: listing, observesChanges: observesChanges)
        requiresInitialCommit = true
        sortColumn = state.sortColumn
        ascending = state.ascending
        includeHidden = state.includeHidden
        var candidates = [URL]()
        for candidate in [homeDirectory, temporaryDirectory] {
            let normalized = URL(fileURLWithPath: candidate.standardizedFileURL.path, isDirectory: true)
            if normalized != url && !candidates.contains(normalized) {
                candidates.append(normalized)
            }
        }
        restoration = Restoration(original: url, remaining: candidates)
    }

    init(url: URL, ops: FileOps = FileOps(),
         listing: ((URL, Bool) throws -> [FileEntry])?, observesChanges: Bool = false,
         sorting: @escaping ([FileEntry], SortColumn, Bool) -> [FileEntry] = { FileOps.sorted($0, by: $1, ascending: $2) }) {
        self.url = URL(fileURLWithPath: url.standardizedFileURL.path, isDirectory: true)
        self.ops = ops
        self.listing = listing
        self.sorting = sorting
        self.observesChanges = observesChanges
    }

    public var isLoading: Bool { pending != nil }
    public var canGoBack: Bool { !backStack.isEmpty }
    public var canGoForward: Bool { !forwardStack.isEmpty }

    public var persistedState: PaneState? {
        guard revision > 0 else { return nil }
        return PaneState(url: url, sortColumn: sortColumn, ascending: ascending, includeHidden: includeHidden)
    }

    public func reload() {
        load(pending ?? Request(url: url, history: .reload, isRestoration: restoration != nil))
    }

    public func navigate(to target: URL) {
        let destination = URL(fileURLWithPath: target.standardizedFileURL.path, isDirectory: true)
        restorationNotice = nil
        let departing = captureViewState?()
        let leavingSearch = departing?.search != nil
        let history: Request.History = (destination == url && !leavingSearch) || (requiresInitialCommit && revision == 0) ? .reload : .navigate
        // Viewing a result's original folder is a new visit even when it is the search root.
        let arriving = destination == url && leavingSearch
            ? ViewState(selection: [], scrollOffset: 0, filter: "", filterVisible: false) : nil
        load(Request(url: destination, history: history, departingState: departing, arrivingState: arriving))
    }

    @discardableResult
    public func goUp() -> Bool {
        let parent = url.deletingLastPathComponent().standardizedFileURL
        guard parent != url else { return false }
        navigate(to: parent)
        return true
    }

    @discardableResult
    public func goBack() -> Bool {
        guard let previous = backStack.last else { return false }
        restorationNotice = nil
        load(Request(url: previous.url, history: .back, departingState: captureViewState?(), arrivingState: previous.state))
        return true
    }

    @discardableResult
    public func goForward() -> Bool {
        guard let next = forwardStack.last else { return false }
        restorationNotice = nil
        load(Request(url: next.url, history: .forward, departingState: captureViewState?(), arrivingState: next.state))
        return true
    }

    public func setSort(_ column: SortColumn, ascending: Bool) {
        precondition(Thread.isMainThread)
        guard sortColumn != column || self.ascending != ascending else { return }
        sortColumn = column
        self.ascending = ascending
        if isLoading || revision == 0 {
            reload()
        } else {
            generation += 1
            let ticket = generation
            let snapshot = entries
            let sort = sorting
            isSorting = true
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let sorted = sort(snapshot, column, ascending)
                DispatchQueue.main.async { [weak self] in
                    guard let self, ticket == self.generation else { return }
                    self.entries = sorted
                    self.isSorting = false
                    // A reorder does not advance the filesystem revision or replay history.
                    self.onChange?()
                }
            }
        }
    }

    private func load(_ request: Request) {
        precondition(Thread.isMainThread)
        if !request.isRestoration {
            restoration = nil
        }
        generation += 1
        isSorting = false
        let ticket = generation
        pending = request
        loadState = .loading(request.url)
        let includeHidden = request.arrivingState?.search?.includeHidden ?? includeHidden
        let column = sortColumn
        let ascending = ascending
        let ops = ops
        let list = listing ?? { try ops.list(directory: $0, includeHidden: $1) }
        let sort = sorting
        onChange?()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result {
                try sort(list(request.url, includeHidden), column, ascending)
            }
            DispatchQueue.main.async { [weak self] in
                guard let self, ticket == self.generation else { return }
                self.finish(request, result: result)
            }
        }
    }

    private func finish(_ request: Request, result: Result<[FileEntry], Error>) {
        pending = nil
        switch result {
        case .success(let entries):
            if request.isRestoration, let restoration {
                if let failure = restoration.failure {
                    restorationNotice = "이전 폴더 \(restoration.original.path)를 열 수 없습니다: \(failure). 대신 \(request.url.path)를 열었습니다."
                }
                self.restoration = nil
            }
            switch request.history {
            case .reload: break
            case .navigate:
                backStack.append(Visit(url: url, state: request.departingState))
                forwardStack.removeAll()
            case .back:
                backStack.removeLast()
                forwardStack.append(Visit(url: url, state: request.departingState))
            case .forward:
                forwardStack.removeLast()
                backStack.append(Visit(url: url, state: request.departingState))
            }
            restoredViewState = request.arrivingState
            if let search = request.arrivingState?.search { includeHidden = search.includeHidden }
            let changedDirectory = url != request.url
            url = request.url
            self.entries = entries
            revision += 1
            loadState = .idle
            if observesChanges && (changedDirectory || observer == nil) {
                observer = DirectoryObserver(url: url) { [weak self] in
                    self?.directoryChanged()
                }
            }
            onChange?()
            if refreshPending {
                refreshPending = false
                directoryChanged()
            }
        case .failure(let error):
            refreshPending = false
            let message = (error as? FileOpError)?.message ?? error.localizedDescription
            if request.isRestoration, var restoration {
                if restoration.failure == nil { restoration.failure = message }
                if !restoration.remaining.isEmpty {
                    let fallback = restoration.remaining.removeFirst()
                    self.restoration = restoration
                    restorationNotice = "이전 폴더 \(restoration.original.path)를 열 수 없습니다: \(restoration.failure ?? message). \(fallback.path)를 여는 중…"
                    load(Request(url: fallback, history: .reload, isRestoration: true))
                    return
                }
                restorationNotice = "이전 폴더 \(restoration.original.path)와 대체 폴더를 열 수 없습니다. 위치를 직접 선택해 주세요."
                self.restoration = nil
            }
            loadState = .failed(request.url, message)
            onChange?()
        }
    }

    private func directoryChanged() {
        if isLoading {
            refreshPending = true
        } else {
            reload()
        }
    }

    private struct Visit {
        let url: URL
        let state: ViewState?
    }

    private struct Request {
        enum History { case reload, navigate, back, forward }
        let url: URL
        let history: History
        var isRestoration = false
        var departingState: ViewState?
        var arrivingState: ViewState?
    }

    private struct Restoration {
        let original: URL
        var remaining: [URL]
        var failure: String?
    }
}
