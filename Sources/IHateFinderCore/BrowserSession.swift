import Foundation

public final class BrowserSession {
    public private(set) var url: URL
    public private(set) var entries: [FileEntry] = []
    public var includeHidden = false
    public var sortColumn: SortColumn = .name
    public var ascending = true
    public var ops: FileOps
    private var backStack: [URL] = []
    private var forwardStack: [URL] = []

    public init(url: URL, ops: FileOps = FileOps()) throws {
        self.url = url.standardizedFileURL
        self.ops = ops
        try reload()
    }

    public var canGoBack: Bool { !backStack.isEmpty }
    public var canGoForward: Bool { !forwardStack.isEmpty }

    public func reload() throws {
        let listed = try ops.list(directory: url, includeHidden: includeHidden)
        entries = FileOps.sorted(listed, by: sortColumn, ascending: ascending)
    }

    @discardableResult
    public func navigate(to target: URL) -> Bool {
        let dest = target.standardizedFileURL
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: dest.path, isDirectory: &isDir), isDir.boolValue else {
            return false
        }
        return commit(dest, pushHistory: dest.path != url.path)
    }

    @discardableResult
    public func goUp() -> Bool {
        let parent = url.deletingLastPathComponent().standardizedFileURL
        if parent.path == url.path { return true }
        return navigate(to: parent)
    }

    @discardableResult
    public func goBack() -> Bool {
        guard let previous = backStack.last else { return false }
        backStack.removeLast()
        return restore(previous, pushToForward: true)
    }

    @discardableResult
    public func goForward() -> Bool {
        guard let next = forwardStack.last else { return false }
        forwardStack.removeLast()
        return restore(next, pushToForward: false)
    }

    public func setSort(_ column: SortColumn, ascending: Bool) {
        sortColumn = column
        self.ascending = ascending
        entries = FileOps.sorted(entries, by: column, ascending: ascending)
    }

    private func commit(_ dest: URL, pushHistory: Bool) -> Bool {
        let snapshot = Snapshot(url: url, entries: entries, back: backStack, forward: forwardStack)
        if pushHistory {
            backStack.append(url)
            forwardStack.removeAll()
            url = dest
        }
        do {
            try reload()
            return true
        } catch {
            apply(snapshot)
            return false
        }
    }

    private func restore(_ dest: URL, pushToForward: Bool) -> Bool {
        let snapshot = Snapshot(url: url, entries: entries, back: backStack, forward: forwardStack)
        if pushToForward {
            forwardStack.append(url)
        } else {
            backStack.append(url)
        }
        url = dest
        do {
            try reload()
            return true
        } catch {
            apply(snapshot)
            return false
        }
    }

    private func apply(_ snapshot: Snapshot) {
        url = snapshot.url
        entries = snapshot.entries
        backStack = snapshot.back
        forwardStack = snapshot.forward
    }

    private struct Snapshot {
        var url: URL
        var entries: [FileEntry]
        var back: [URL]
        var forward: [URL]
    }
}
