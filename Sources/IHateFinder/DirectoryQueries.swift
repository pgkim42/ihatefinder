import Foundation
import IHateFinderCore

/// Both callers receive their completion on the main queue; enumeration never runs there.
enum DirectoryQueries {
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
                       completion: @escaping (Result<[FileEntry], Error>) -> Void) -> () -> Void {
        run({ operation in
            let keys: Set<URLResourceKey> = [.isDirectoryKey, .isPackageKey, .isSymbolicLinkKey, .isHiddenKey,
                                            .fileSizeKey, .contentModificationDateKey, .localizedTypeDescriptionKey]
            var failure: Error?
            guard let enumerator = FileManager.default.enumerator(
                at: root, includingPropertiesForKeys: Array(keys),
                options: includeHidden ? [.skipsPackageDescendants] : [.skipsPackageDescendants, .skipsHiddenFiles],
                errorHandler: { _, error in failure = error; return false }) else {
                throw FileOpError("폴더를 읽을 수 없습니다: \(root.path)")
            }
            var entries: [FileEntry] = []
            while !operation.isCancelled, let url = enumerator.nextObject() as? URL {
                let values = try url.resourceValues(forKeys: keys)
                let hidden = values.isHidden == true || url.lastPathComponent.hasPrefix(".")
                if values.isSymbolicLink == true || (!includeHidden && hidden) { enumerator.skipDescendants() }
                if !includeHidden && hidden { continue }
                guard url.lastPathComponent.localizedStandardContains(query) else { continue }
                let directory = values.isDirectory == true && values.isPackage != true
                entries.append(FileEntry(url: url.standardizedFileURL, name: url.lastPathComponent, isDirectory: directory,
                                         size: Int64(values.fileSize ?? 0), modified: values.contentModificationDate ?? .distantPast,
                                         kind: values.localizedTypeDescription ?? (directory ? "폴더" : "파일"), isHidden: hidden))
            }
            if let failure { throw failure }
            return FileOps.sorted(entries, by: .name, ascending: true)
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
