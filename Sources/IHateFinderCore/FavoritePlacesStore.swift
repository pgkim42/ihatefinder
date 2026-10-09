import Foundation

public final class FavoritePlacesStore {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "favorite-places.v1") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> [URL] {
        guard let data = defaults.data(forKey: key),
              let paths = try? JSONDecoder().decode([String].self, from: data),
              paths.allSatisfy({ $0.hasPrefix("/") && !$0.contains("\0") }) else { return [] }
        return normalized(paths.map { URL(fileURLWithPath: $0, isDirectory: true) })
    }

    public func save(_ places: [URL]) {
        let paths = normalized(places).map(\.path)
        guard let data = try? JSONEncoder().encode(paths) else { return }
        defaults.set(data, forKey: key)
    }

    private func normalized(_ places: [URL]) -> [URL] {
        var seen = Set<String>()
        return places.compactMap { url in
            guard url.isFileURL,
                  url.host == nil || url.host == "" || url.host == "localhost",
                  url.path.hasPrefix("/"), !url.path(percentEncoded: false).contains("\0") else { return nil }
            let path = url.standardizedFileURL.path
            guard seen.insert(path).inserted else { return nil }
            return URL(fileURLWithPath: path, isDirectory: true)
        }
    }
}
