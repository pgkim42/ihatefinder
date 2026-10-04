import AppKit

/// What another app asked this one to show (open-documents or Show-in-Finder Apple Events).
/// Pure: it only reads the file system to classify a path and never changes anything.
enum OpenRequest: Equatable {
    case showFolder(URL)
    case reveal(parent: URL, select: URL)
    case failure(String)

    /// Symlinks are resolved first. A folder is shown; a file or package is revealed in its parent.
    static func make(url: URL) -> OpenRequest {
        let resolved = url.resolvingSymlinksInPath()
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isPackageKey]
        guard FileManager.default.fileExists(atPath: resolved.path),
              let values = try? resolved.resourceValues(forKeys: keys) else {
            return .failure("‘\(url.lastPathComponent)’을(를) 찾을 수 없습니다.\n\(url.path)")
        }
        if values.isDirectory == true, values.isPackage != true {
            return .showFolder(resolved)
        }
        return .reveal(parent: resolved.deletingLastPathComponent(), select: resolved)
    }

    /// The first URL that exists decides; when none does, the first failure is reported.
    static func make(urls: [URL]) -> OpenRequest? {
        var firstFailure: OpenRequest?
        for url in urls {
            let request = make(url: url)
            if case .failure = request {
                firstFailure = firstFailure ?? request
            } else {
                return request
            }
        }
        return firstFailure
    }

    /// Reads a list of file URLs / aliases, or a single one, from an event's direct object.
    static func urls(fromAppleEventDirectObject descriptor: NSAppleEventDescriptor?) -> [URL] {
        guard let descriptor else { return [] }
        if descriptor.descriptorType == DescType(typeAEList) {
            return (0..<descriptor.numberOfItems).compactMap { index in
                descriptor.atIndex(index + 1).flatMap(fileURL(from:))
            }
        }
        return fileURL(from: descriptor).map { [$0] } ?? []
    }

    private static func fileURL(from descriptor: NSAppleEventDescriptor) -> URL? {
        if let url = descriptor.fileURLValue { return url }
        return descriptor.coerce(toDescriptorType: DescType(typeFileURL))?.fileURLValue
    }
}
