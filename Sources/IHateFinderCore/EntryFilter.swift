import Foundation

public enum EntryFilter {
    /// Trims the query; an empty query keeps every entry, otherwise names must contain it
    /// (case-, diacritic- and width-insensitive, like Finder search).
    public static func filter(_ entries: [FileEntry], query: String) -> [FileEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return entries }
        return entries.filter { $0.name.localizedStandardContains(trimmed) }
    }
}
