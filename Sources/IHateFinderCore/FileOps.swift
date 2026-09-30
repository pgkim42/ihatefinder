import Foundation

public enum NameConflict: Equatable {
    case replace
    case skip
    case keepBoth
}

public enum SortColumn: String {
    case name
    case modified
    case kind
    case size
}

public struct FileEntry: Equatable {
    public var url: URL
    public var name: String
    public var isDirectory: Bool
    public var size: Int64
    public var modified: Date
    public var kind: String
    public var isHidden: Bool

    public init(
        url: URL,
        name: String,
        isDirectory: Bool,
        size: Int64,
        modified: Date,
        kind: String,
        isHidden: Bool
    ) {
        self.url = url
        self.name = name
        self.isDirectory = isDirectory
        self.size = size
        self.modified = modified
        self.kind = kind
        self.isHidden = isHidden
    }
}

public struct FileOpError: Error, Equatable {
    public var message: String

    public init(_ message: String) {
        self.message = message
    }
}

public struct FileOps {
    public var sameVolume: (URL, URL) -> Bool
    public var trash: (URL) throws -> Void
    private let fm: FileManager

    public init(
        fileManager: FileManager = .default,
        sameVolume: @escaping (URL, URL) -> Bool = FileOps.volumesMatch,
        trash: @escaping (URL) throws -> Void = FileOps.trashItem
    ) {
        self.fm = fileManager
        self.sameVolume = sameVolume
        self.trash = trash
    }

    public func list(directory: URL, includeHidden: Bool) throws -> [FileEntry] {
        let keys: [URLResourceKey] = [
            .nameKey, .isDirectoryKey, .isPackageKey, .isHiddenKey,
            .fileSizeKey, .contentModificationDateKey, .localizedTypeDescriptionKey,
        ]
        let urls = try fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys,
            options: []
        )
        var entries: [FileEntry] = []
        for url in urls {
            let values = try url.resourceValues(forKeys: Set(keys))
            let name = values.name ?? url.lastPathComponent
            let hidden = (values.isHidden ?? false) || name.hasPrefix(".")
            if hidden && !includeHidden { continue }
            let isPackage = values.isPackage ?? false
            let isDirectory = (values.isDirectory ?? false) && !isPackage
            let kind = values.localizedTypeDescription ?? (isDirectory ? "폴더" : "파일")
            entries.append(FileEntry(
                url: url,
                name: name,
                isDirectory: isDirectory,
                size: isDirectory ? 0 : Int64(values.fileSize ?? 0),
                modified: values.contentModificationDate ?? .distantPast,
                kind: kind,
                isHidden: hidden
            ))
        }
        return entries
    }

    public func createFolder(in directory: URL) throws -> URL {
        let name = freshName(in: directory, base: "새 폴더", ext: nil, firstDuplicate: 2)
        let url = directory.appendingPathComponent(name)
        try fm.createDirectory(at: url, withIntermediateDirectories: false)
        return url
    }

    public func createTextFile(in directory: URL) throws -> URL {
        let name = freshName(in: directory, base: "새 텍스트 문서", ext: "txt", firstDuplicate: 2)
        let url = directory.appendingPathComponent(name)
        guard fm.createFile(atPath: url.path, contents: Data()) else {
            throw FileOpError("파일을 만들지 못했습니다.")
        }
        return url
    }

    public func paste(
        urls: [URL],
        cut: Bool,
        into dest: URL,
        resolve: (String) throws -> NameConflict,
        progress: ((Int, Int, String) -> Void)? = nil
    ) throws {
        if cut && urls.allSatisfy({ parentPath($0) == stdPath(dest) }) {
            return
        }
        try transfer(urls: urls, to: dest, moving: cut, resolve: resolve, progress: progress)
    }

    public func transfer(
        urls: [URL],
        to dest: URL,
        moving: Bool,
        resolve: (String) throws -> NameConflict,
        progress: ((Int, Int, String) -> Void)? = nil
    ) throws {
        guard directoryExists(dest) else {
            throw FileOpError("대상이 폴더가 아닙니다.")
        }
        let total = urls.count
        for (index, url) in urls.enumerated() {
            progress?(index + 1, total, url.lastPathComponent)
            if moving && parentPath(url) == stdPath(dest) { continue }
            if contains(dest, inside: url) {
                throw FileOpError("폴더를 그 안으로 옮길 수 없습니다.")
            }
            try place(url, in: dest, moving: moving, resolve: resolve)
        }
    }

    public func rename(
        url: URL,
        to newName: String,
        resolve: (String) throws -> NameConflict
    ) throws {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("/") else {
            throw FileOpError("그 이름은 쓸 수 없습니다.")
        }
        let destDir = url.deletingLastPathComponent()
        let target = destDir.appendingPathComponent(trimmed)
        if stdPath(target) == stdPath(url) {
            if target.lastPathComponent != url.lastPathComponent {
                let temporary = destDir.appendingPathComponent(".ihatefinder-rename-\(UUID().uuidString)")
                try fm.moveItem(at: url, to: temporary)
                try fm.moveItem(at: temporary, to: target)
            }
            return
        }
        if fm.fileExists(atPath: target.path) {
            switch try resolve(trimmed) {
            case .skip:
                return
            case .replace:
                try trash(target)
                try fm.moveItem(at: url, to: target)
            case .keepBoth:
                let unique = keepBothName(in: destDir, existingName: trimmed)
                try fm.moveItem(at: url, to: destDir.appendingPathComponent(unique))
            }
        } else {
            try fm.moveItem(at: url, to: target)
        }
    }

    public static func sorted(_ entries: [FileEntry], by column: SortColumn, ascending: Bool) -> [FileEntry] {
        entries.sorted { a, b in
            if column == .name, a.isDirectory != b.isDirectory {
                return a.isDirectory
            }
            let ordered: Bool
            switch column {
            case .name:
                ordered = a.name.localizedStandardCompare(b.name) == .orderedAscending
            case .modified:
                if a.modified == b.modified {
                    ordered = a.name.localizedStandardCompare(b.name) == .orderedAscending
                } else {
                    ordered = a.modified < b.modified
                }
            case .kind:
                let kindOrder = a.kind.localizedStandardCompare(b.kind)
                ordered = kindOrder == .orderedSame
                    ? a.name.localizedStandardCompare(b.name) == .orderedAscending
                    : kindOrder == .orderedAscending
            case .size:
                ordered = a.size == b.size
                    ? a.name.localizedStandardCompare(b.name) == .orderedAscending
                    : a.size < b.size
            }
            return ascending ? ordered : !ordered
        }
    }

    public static func volumesMatch(_ a: URL, _ b: URL) -> Bool {
        let keys: Set<URLResourceKey> = [.volumeIdentifierKey]
        let left = try? a.resourceValues(forKeys: keys).volumeIdentifier
        let right = try? b.resourceValues(forKeys: keys).volumeIdentifier
        if let left = left as? NSObject, let right = right as? NSObject {
            return left == right
        }
        return false
    }

    public static func trashItem(_ url: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }

    private func place(
        _ url: URL,
        in dest: URL,
        moving: Bool,
        resolve: (String) throws -> NameConflict
    ) throws {
        let name = url.lastPathComponent
        let target = dest.appendingPathComponent(name)
        if stdPath(target) == stdPath(url) { return }
        if fm.fileExists(atPath: target.path) {
            switch try resolve(name) {
            case .skip:
                return
            case .replace:
                try trash(target)
                try write(url, to: target, moving: moving, dest: dest)
            case .keepBoth:
                let unique = keepBothName(in: dest, existingName: name)
                try write(url, to: dest.appendingPathComponent(unique), moving: moving, dest: dest)
            }
        } else {
            try write(url, to: target, moving: moving, dest: dest)
        }
    }

    private func write(_ url: URL, to target: URL, moving: Bool, dest: URL) throws {
        if moving && sameVolume(url, dest) {
            try fm.moveItem(at: url, to: target)
            return
        }
        try fm.copyItem(at: url, to: target)
        if moving {
            do {
                try trash(url)
            } catch {
                throw FileOpError("복사본은 만들었지만 원본을 휴지통으로 보내지 못했습니다. 원본은 그 자리에 있습니다.")
            }
        }
    }

    private func freshName(in directory: URL, base: String, ext: String?, firstDuplicate: Int) -> String {
        let first = joined(base, ext)
        if !fm.fileExists(atPath: directory.appendingPathComponent(first).path) {
            return first
        }
        var number = firstDuplicate
        while true {
            let name = joined("\(base) (\(number))", ext)
            if !fm.fileExists(atPath: directory.appendingPathComponent(name).path) {
                return name
            }
            number += 1
        }
    }

    private func keepBothName(in directory: URL, existingName: String) -> String {
        let ns = existingName as NSString
        let ext = ns.pathExtension
        let stem = ns.deletingPathExtension
        var number = 1
        while true {
            let name = ext.isEmpty ? "\(stem) (\(number))" : "\(stem) (\(number)).\(ext)"
            if !fm.fileExists(atPath: directory.appendingPathComponent(name).path) {
                return name
            }
            number += 1
        }
    }

    private func joined(_ base: String, _ ext: String?) -> String {
        guard let ext, !ext.isEmpty else { return base }
        return "\(base).\(ext)"
    }

    private func directoryExists(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return fm.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    private func parentPath(_ url: URL) -> String {
        stdPath(url.deletingLastPathComponent())
    }

    private func stdPath(_ url: URL) -> String {
        url.standardizedFileURL.path
    }

    private func contains(_ dest: URL, inside ancestor: URL) -> Bool {
        let destPath = stdPath(dest)
        let ancestorPath = stdPath(ancestor)
        if destPath == ancestorPath { return true }
        return destPath.hasPrefix(ancestorPath.hasSuffix("/") ? ancestorPath : ancestorPath + "/")
    }
}
