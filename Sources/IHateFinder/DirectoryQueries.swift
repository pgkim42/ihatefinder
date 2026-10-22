import Foundation
import IHateFinderCore

/// Both callers receive their completion on the main queue; enumeration never runs there.
enum DirectoryQueries {
    struct SearchIssue: Equatable {
        let url: URL
        let message: String
    }

    struct SearchResult {
        let entries: [FileEntry]
        let issues: [SearchIssue]
    }

    private static let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 2
        return queue
    }()

    @discardableResult
    static func complete(_ text: String, relativeTo base: URL, includeHidden: Bool,
                         completion: @escaping (Result<[URL], Error>) -> Void) -> () -> Void {
        run({ operation in
            let expanded = (text as NSString).expandingTildeInPath
            let absolute = expanded.hasPrefix("/") ? expanded : base.appendingPathComponent(expanded).path
            let path = URL(fileURLWithPath: absolute)
            let directory = text.hasSuffix("/") || text == "~" ? path : path.deletingLastPathComponent()
            let prefix = text.hasSuffix("/") || text == "~" ? "" : path.lastPathComponent
            let candidates = try FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
                options: includeHidden || prefix.hasPrefix(".") ? [] : [.skipsHiddenFiles])
            var result: [URL] = []
            for url in candidates {
                if operation.isCancelled { break }
                let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isHiddenKey])
                guard values.isDirectory == true,
                      url.lastPathComponent.range(of: prefix, options: [.anchored, .caseInsensitive, .diacriticInsensitive]) != nil || prefix.isEmpty else { continue }
                result.append(url.standardizedFileURL)
            }
            return result.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        }, completion: completion)
    }

    @discardableResult
    static func search(_ root: URL, query: String, includeHidden: Bool,
                       readValues: @escaping (URL, Set<URLResourceKey>) throws -> URLResourceValues = { try $0.resourceValues(forKeys: $1) },
                       completion: @escaping (Result<SearchResult, Error>) -> Void) -> () -> Void {
        run({ operation in
            let structureKeys: Set<URLResourceKey> = [.isDirectoryKey, .isPackageKey, .isSymbolicLinkKey, .isHiddenKey]
            let metadataKeys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey, .localizedTypeDescriptionKey]
            // The explicitly chosen root may itself be a link (including /tmp).
            // Descendant links still remain leaf entries during enumeration.
            let traversalRoot = root.resolvingSymlinksInPath()
            // Foundation may normalize /private/tmp back to the /tmp link.
            // This check follows that link; URL resource values describe the link itself.
            var rootIsDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: traversalRoot.path, isDirectory: &rootIsDirectory),
                  rootIsDirectory.boolValue else {
                throw FileOpError("폴더를 읽을 수 없습니다: \(root.path)")
            }
            var rootFailure: Error?
            var issues: [SearchIssue] = []
            var issuePaths: Set<String> = []
            func record(_ url: URL, _ error: Error) {
                let url = url.standardizedFileURL
                guard issuePaths.insert(url.path).inserted else { return }
                issues.append(SearchIssue(url: url,
                                          message: (error as? FileOpError)?.message ?? error.localizedDescription))
            }
            guard let enumerator = FileManager.default.enumerator(
                at: traversalRoot, includingPropertiesForKeys: Array(structureKeys),
                options: includeHidden ? [.skipsPackageDescendants] : [.skipsPackageDescendants, .skipsHiddenFiles],
                errorHandler: { url, error in
                    if url.resolvingSymlinksInPath().path == traversalRoot.path {
                        rootFailure = error
                        return false
                    }
                    record(url, error)
                    return !operation.isCancelled
                }) else {
                throw FileOpError("폴더를 읽을 수 없습니다: \(root.path)")
            }
            var entries: [FileEntry] = []
            while !operation.isCancelled, let url = enumerator.nextObject() as? URL {
                let values: URLResourceValues
                do { values = try readValues(url, structureKeys) }
                catch {
                    record(url, error)
                    // The item may be a file. skipDescendants() after a leaf can
                    // skip the next directory instead. Let enumeration determine
                    // whether this item's descendants can still be read.
                    continue
                }
                let hidden = values.isHidden == true || url.lastPathComponent.hasPrefix(".")
                if !includeHidden && hidden {
                    if values.isDirectory == true && values.isSymbolicLink != true { enumerator.skipDescendants() }
                    continue
                }
                guard url.lastPathComponent.localizedStandardContains(query) else { continue }
                let directory = values.isDirectory == true && values.isPackage != true
                let metadata: URLResourceValues
                do { metadata = try readValues(url, metadataKeys) }
                catch {
                    // Optional metadata for a folder must not prevent visiting its descendants.
                    record(url, error)
                    continue
                }
                entries.append(FileEntry(url: url.standardizedFileURL, name: url.lastPathComponent, isDirectory: directory,
                                         size: Int64(metadata.fileSize ?? 0), modified: metadata.contentModificationDate ?? .distantPast,
                                         kind: metadata.localizedTypeDescription ?? (directory ? "폴더" : "파일"), isHidden: hidden))
            }
            if operation.isCancelled { throw CancellationError() }
            if let rootFailure { throw rootFailure }
            return SearchResult(entries: FileOps.sorted(entries, by: .name, ascending: true), issues: issues)
        }, completion: completion)
    }

    private static func run<Value>(_ work: @escaping (Operation) throws -> Value,
                                   completion: @escaping (Result<Value, Error>) -> Void) -> () -> Void {
        let operation = QueryOperation { operation in
            let result = Result { try work(operation) }
            DispatchQueue.main.async {
                guard !operation.isCancelled else { return }
                completion(result)
            }
        }
        queue.addOperation(operation)
        return { operation.cancel() }
    }

    private final class QueryOperation: Operation, @unchecked Sendable {
        let work: (Operation) -> Void
        init(work: @escaping (Operation) -> Void) { self.work = work }
        override func main() { if !isCancelled { work(self) } }
    }
}
