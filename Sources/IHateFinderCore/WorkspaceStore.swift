import Foundation

/// The durable view state of one pane; file operations and navigation targets are deliberately absent.
public struct PaneState: Codable, Equatable {
    public let path: String
    public let sortColumn: SortColumn
    public let ascending: Bool
    public let includeHidden: Bool

    public init(url: URL, sortColumn: SortColumn = .name, ascending: Bool = true, includeHidden: Bool = false) {
        path = url.standardizedFileURL.path
        self.sortColumn = sortColumn
        self.ascending = ascending
        self.includeHidden = includeHidden
    }

    public var url: URL { URL(fileURLWithPath: path, isDirectory: true) }

    private enum CodingKeys: String, CodingKey { case path, sortColumn, ascending, includeHidden }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        path = try values.decode(String.self, forKey: .path)
        guard path.hasPrefix("/"), !path.contains("\0") else {
            throw DecodingError.dataCorruptedError(forKey: .path, in: values, debugDescription: "Expected an absolute folder path")
        }
        let column = try values.decode(String.self, forKey: .sortColumn)
        guard let sortColumn = SortColumn(rawValue: column) else {
            throw DecodingError.dataCorruptedError(forKey: .sortColumn, in: values, debugDescription: "Unknown sort column")
        }
        self.sortColumn = sortColumn
        ascending = try values.decode(Bool.self, forKey: .ascending)
        includeHidden = try values.decode(Bool.self, forKey: .includeHidden)
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(path, forKey: .path)
        try values.encode(sortColumn.rawValue, forKey: .sortColumn)
        try values.encode(ascending, forKey: .ascending)
        try values.encode(includeHidden, forKey: .includeHidden)
    }
}

public struct WorkspaceState: Codable, Equatable {
    public var left: PaneState
    public var right: PaneState
    public var dual: Bool

    public init(left: PaneState, right: PaneState, dual: Bool) {
        self.left = left
        self.right = right
        self.dual = dual
    }
}

public final class WorkspaceStore {
    private let defaults: UserDefaults
    private let key: String
    private let homeDirectory: URL
    private var lastSavedState: WorkspaceState?

    public init(defaults: UserDefaults = .standard, key: String = "workspace.v1",
                homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.defaults = defaults
        self.key = key
        self.homeDirectory = homeDirectory
    }

    public func load() -> WorkspaceState {
        if let data = defaults.data(forKey: key),
           let state = try? JSONDecoder().decode(WorkspaceState.self, from: data) {
            return state
        }
        let home = PaneState(url: homeDirectory)
        return WorkspaceState(left: home, right: home, dual: false)
    }

    public func save(_ state: WorkspaceState) {
        guard state != lastSavedState else { return }
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: key)
        lastSavedState = state
    }

    /// Never replace a saved folder with an uncommitted startup or navigation target.
    public func save(left: BrowserSession, right: BrowserSession, dual: Bool) {
        precondition(Thread.isMainThread)
        var state = lastSavedState ?? load()
        if let pane = left.persistedState { state.left = pane }
        if let pane = right.persistedState { state.right = pane }
        state.dual = dual
        save(state)
    }
}
