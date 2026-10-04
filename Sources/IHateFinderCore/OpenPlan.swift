import Foundation

/// What Enter / double-click does for the current selection.
public enum OpenPlan: Equatable {
    case navigate(URL)
    /// `confirm` is true when opening this many files should be confirmed first.
    case openFiles([URL], confirm: Bool)
    case refuse(String)

    public static let confirmThreshold = 20

    /// Files are opened as long as any are selected; folders are never opened alongside them.
    /// A single folder is entered; several folders alone are refused.
    public static func make(entries: [FileEntry]) -> OpenPlan? {
        guard !entries.isEmpty else { return nil }
        let files = entries.filter { !$0.isDirectory }
        if !files.isEmpty {
            return .openFiles(files.map(\.url), confirm: files.count > confirmThreshold)
        }
        if entries.count == 1 { return .navigate(entries[0].url) }
        return .refuse("폴더는 한 번에 하나만 열 수 있습니다. 폴더를 하나만 고르십시오.")
    }
}
