import Foundation

/// Which context-menu items are enabled for a selection.
public struct MenuState: Equatable {
    public var open: Bool
    public var openWith: Bool
    public var cut: Bool
    public var copy: Bool
    public var rename: Bool
    public var trash: Bool
    public var compress: Bool
    public var copyPath: Bool
    public var info: Bool
    /// Terminal opens at the single selected folder, or else at the current folder.
    public var terminal: Bool

    /// Apps that can open every item, in the first item's order, with the default app first.
    public static func commonApps(_ candidates: [[URL]], defaultApp: URL?) -> [URL] {
        guard var common = candidates.first else { return [] }
        for list in candidates.dropFirst() {
            let allowed = Set(list.map(\.path))
            common.removeAll { !allowed.contains($0.path) }
        }
        if let defaultApp, let index = common.firstIndex(where: { $0.path == defaultApp.path }) {
            common.insert(common.remove(at: index), at: 0)
        }
        return common
    }

    /// One path per line, as plain text.
    public static func pathText(_ urls: [URL]) -> String {
        urls.map(\.path).joined(separator: "\n")
    }

    /// The single selected folder, or else the folder being shown.
    public static func terminalFolder(selection: [FileEntry], current: URL) -> URL {
        if selection.count == 1, selection[0].isDirectory { return selection[0].url }
        return current
    }

    public static func make(selection: [URL]) -> MenuState {
        let any = !selection.isEmpty
        let single = selection.count == 1
        return MenuState(
            open: any, openWith: any, cut: any, copy: any, rename: any, trash: any,
            compress: single, copyPath: any, info: single, terminal: true
        )
    }
}
