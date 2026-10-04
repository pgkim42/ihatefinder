import Foundation

/// Which part of a name is selected when rename starts.
public enum RenameSelection {
    /// UTF-16 range, as used by `NSText.selectedRange`.
    /// Files and packages (`FileEntry.isDirectory` is false for packages) select the stem only.
    /// Folders, dotfiles and names without an extension select the whole name.
    public static func range(name: String, isDirectory: Bool) -> NSRange {
        let whole = NSRange(location: 0, length: (name as NSString).length)
        if isDirectory { return whole }
        let ext = (name as NSString).pathExtension
        if ext.isEmpty { return whole }
        if name.hasPrefix("."), name.dropFirst().firstIndex(of: ".") == nil { return whole }
        let stemLength = whole.length - (ext as NSString).length - 1
        return NSRange(location: 0, length: max(stemLength, 0))
    }
}
