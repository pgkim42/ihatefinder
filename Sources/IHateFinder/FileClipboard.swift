import AppKit

/// Owns only this app's move intent; other applications always receive ordinary file URLs.
@MainActor
final class FileClipboard {
    struct Snapshot: Sendable {
        let urls: [URL]
        let isCut: Bool
        fileprivate let identity: UUID
        fileprivate let changeCount: Int
    }

    private let pasteboard: NSPasteboard
    private var observedChangeCount: Int
    private var cutSnapshot: Snapshot?

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
        observedChangeCount = pasteboard.changeCount
    }

    @discardableResult
    func copy(_ urls: [URL]) -> Bool {
        write(urls, cut: false)
    }

    @discardableResult
    func cut(_ urls: [URL]) -> Bool {
        write(urls, cut: true)
    }

    /// Call on activation to refresh cut styling, and before using clipboard contents.
    @discardableResult
    func synchronize() -> Bool {
        let count = pasteboard.changeCount
        guard count != observedChangeCount else { return false }
        observedChangeCount = count
        cutSnapshot = nil
        return true
    }

    func snapshot() -> Snapshot? {
        synchronize()
        let count = observedChangeCount
        guard let items = pasteboard.pasteboardItems, !items.isEmpty else { return nil }
        var urls: [URL] = []
        urls.reserveCapacity(items.count)
        for item in items {
            // Do not let AppKit coerce plain text or public.url into a file operation.
            guard let value = item.string(forType: .fileURL),
                  let url = URL(string: value), Self.isLocalFileURL(url) else { return nil }
            urls.append(url.standardizedFileURL)
        }
        guard pasteboard.changeCount == count else {
            synchronize()
            return nil
        }
        if let cutSnapshot, cutSnapshot.urls == urls {
            return cutSnapshot
        }
        cutSnapshot = nil
        return Snapshot(urls: urls, isCut: false, identity: UUID(), changeCount: count)
    }

    func isCut(_ url: URL) -> Bool {
        synchronize()
        guard let cutSnapshot else { return false }
        let path = url.standardizedFileURL.path
        return cutSnapshot.urls.contains { $0.path == path }
    }

    /// Successful sources alone are removed; stale completions never replace newer contents.
    func consume(_ completed: [URL], from snapshot: Snapshot) {
        synchronize()
        guard snapshot.isCut, let current = cutSnapshot,
              current.identity == snapshot.identity,
              current.changeCount == snapshot.changeCount,
              pasteboard.changeCount == snapshot.changeCount else { return }
        let paths = Set(completed.map { $0.standardizedFileURL.path })
        let remaining = current.urls.filter { !paths.contains($0.path) }
        guard remaining.count != current.urls.count else { return }
        if remaining.isEmpty {
            cutSnapshot = nil
            observedChangeCount = pasteboard.clearContents()
        } else {
            write(remaining, cut: true)
        }
    }

    /// Escape preserves the file URLs as a copy, but invalidates every pending move snapshot.
    @discardableResult
    func cancelCut() -> Bool {
        synchronize()
        guard cutSnapshot != nil else { return false }
        cutSnapshot = nil
        return true
    }

    @discardableResult
    private func write(_ urls: [URL], cut: Bool) -> Bool {
        guard !urls.isEmpty, urls.allSatisfy(Self.isLocalFileURL) else { return false }
        let files = urls.map(\.standardizedFileURL)
        cutSnapshot = nil
        let count = pasteboard.clearContents()
        let written = pasteboard.writeObjects(files.map { $0 as NSURL })
        observedChangeCount = pasteboard.changeCount
        guard written, observedChangeCount == count else { return false }
        if cut {
            cutSnapshot = Snapshot(urls: files, isCut: true, identity: UUID(), changeCount: count)
        }
        return true
    }

    private static func isLocalFileURL(_ url: URL) -> Bool {
        guard url.isFileURL, url.path.hasPrefix("/"), url.query == nil, url.fragment == nil,
              url.user == nil, url.password == nil, url.port == nil else { return false }
        return url.host == nil || url.host == "" || url.host?.lowercased() == "localhost"
    }
}
