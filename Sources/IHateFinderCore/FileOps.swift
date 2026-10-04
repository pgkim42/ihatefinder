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

public struct FileOpError: Error, LocalizedError, Equatable {
    public var message: String

    public init(_ message: String) {
        self.message = message
    }

    public var errorDescription: String? { message }
}

public enum FileTransferStatus: Equatable {
    case completed
    case skipped
    case failed
    case cancelled
    case unprocessed
}

public struct FileTransferRecovery: Equatable {
    public enum Status: Equatable {
        case preserved
        case restored
        case manualRecoveryRequired
    }

    public let status: Status
    public let locations: [URL]
    public let message: String
}

public struct FileTransferItemResult: Equatable {
    public let source: URL
    public let destination: URL
    public let status: FileTransferStatus
    public let message: String?
    public let recovery: FileTransferRecovery?
    /// True when an existing item at `destination` was moved aside and replaced.
    public internal(set) var replacedExisting = false
    /// Where the replaced item went in the Trash, when `moveToTrash` reported it.
    public internal(set) var replacedTrashURL: URL? = nil
    /// Where a cross-volume move's original went in the Trash, when `moveToTrash` reported it.
    public internal(set) var sourceTrashURL: URL? = nil
    /// Identity of the item at `destination`, read inside `write` the moment it was produced,
    /// so a later item written to the same path in one batch cannot lend its identity.
    public internal(set) var destinationID: FileID? = nil
    /// True when `write` moved the source by renaming it on the destination volume
    /// (so undo can move it back); false for copies and cross-volume moves.
    public internal(set) var movedInPlace = false
}

/// What a rename actually did. `renamed` carries the real destination, which differs from
/// the requested name when the user chose keep-both.
public enum RenameOutcome: Equatable {
    case renamed(FileTransferItemResult)
    case skipped
    case unchanged
}

public struct FileTrashItemResult: Equatable {
    public enum Status: Equatable {
        case trashed
        case failed(String)
        case unprocessed
    }

    public let original: URL
    /// Where the item went in the Trash, when `moveToTrash` reported it.
    public let trashedURL: URL?
    public let status: Status
    /// Best effort: the error says the volume has no Trash or cannot be written to.
    public var trashUnsupported = false
}

public struct FileTrashReport: Equatable {
    /// Input order is retained, including items not attempted after the first failure.
    public let items: [FileTrashItemResult]

    /// The user-facing text for the first failure, or nil when nothing failed.
    /// Every failure gets the same wording; the trash-less-volume hint is only added when
    /// the error code says so, and the message never depends on a code being recognised.
    public var failureMessage: String? {
        guard let failed = items.first(where: { if case .failed = $0.status { return true } else { return false } }),
              case .failed(let reason) = failed.status else { return nil }
        let trashed = items.filter { $0.status == .trashed }.count
        var message = "‘\(failed.original.lastPathComponent)’을(를) 휴지통으로 보내지 못했습니다. 아무것도 지우지 않았습니다. (\(reason))"
        if failed.trashUnsupported {
            message += "\n이 디스크는 휴지통을 지원하지 않을 수 있습니다."
        }
        message += "\n휴지통으로 보낸 항목 \(trashed)개, 그대로 남은 항목 \(items.count - trashed)개."
        return message
    }
}

public struct FileTransferReport: Equatable {
    /// Input order is retained, including items not attempted after failure or cancellation.
    public let items: [FileTransferItemResult]

    /// For moves, these sources reached their destination (including same-folder no-ops).
    /// A completed replacement can still have a warning about its preserved old destination.
    public var completedSources: [URL] {
        items.compactMap { $0.status == .completed ? $0.source : nil }
    }
}

public struct FileOps {
    public var sameVolume: (URL, URL) -> Bool
    /// The single seam that sends an item to the Trash and reports its Trash URL
    /// (nil when the seam cannot tell). Every Trash call goes through it: the
    /// replace backup, the cross-volume move's source, and user trash.
    public var moveToTrash: (URL) throws -> URL?
    /// Same-volume copies use an APFS clone when true. Production opts in; the default is off.
    public var cloneOnSameVolume: Bool
    let fm: FileManager
    // Internal copy seams keep fault-injected safety tests on the same staging path.
    var copy: FileCopyOperation = NativeFileCopy.copy
    var cloneCopy: FileCopyOperation = NativeFileCopy.cloneCopy
    /// Identity seam for undo records and checks. Returns nil when the item cannot be verified.
    var fileIdentity: (URL) -> FileID? = { FileID.read(at: $0) }

    /// `trash` adapts a closure that cannot report a Trash URL; without it the real Trash is used.
    public init(
        fileManager: FileManager = .default,
        sameVolume: @escaping (URL, URL) -> Bool = FileOps.volumesMatch,
        trash: ((URL) throws -> Void)? = nil,
        cloneOnSameVolume: Bool = false
    ) {
        self.fm = fileManager
        self.sameVolume = sameVolume
        if let trash {
            self.moveToTrash = { try trash($0); return nil }
        } else {
            self.moveToTrash = FileOps.trashItemRecording
        }
        self.cloneOnSameVolume = cloneOnSameVolume
    }

    public init(
        fileManager: FileManager = .default,
        sameVolume: @escaping (URL, URL) -> Bool = FileOps.volumesMatch,
        moveToTrash: @escaping (URL) throws -> URL?,
        cloneOnSameVolume: Bool = false
    ) {
        self.fm = fileManager
        self.sameVolume = sameVolume
        self.moveToTrash = moveToTrash
        self.cloneOnSameVolume = cloneOnSameVolume
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

    /// Callbacks run synchronously on the caller's thread. Byte samples are
    /// throttled; phase/current-file changes and final byte samples are immediate.
    public func paste(
        urls: [URL],
        cut: Bool,
        into dest: URL,
        resolve: (String) throws -> NameConflict,
        cancellation: FileTransferCancellation? = nil,
        progressInterval: TimeInterval = 0.1,
        progress: ((FileTransferProgress) -> Void)? = nil
    ) -> FileTransferReport {
        transfer(urls: urls, to: dest, moving: cut, resolve: resolve,
                 cancellation: cancellation, progressInterval: progressInterval, progress: progress)
    }

    public func transfer(
        urls: [URL],
        to dest: URL,
        moving: Bool,
        resolve: (String) throws -> NameConflict,
        cancellation: FileTransferCancellation? = nil,
        progressInterval: TimeInterval = 0.1,
        progress: ((FileTransferProgress) -> Void)? = nil
    ) -> FileTransferReport {
        var items: [FileTransferItemResult] = []
        items.reserveCapacity(urls.count)
        var stopped = false
        for (index, url) in urls.enumerated() {
            let target = dest.appendingPathComponent(url.lastPathComponent)
            if stopped {
                items.append(FileTransferItemResult(
                    source: url, destination: target, status: .unprocessed, message: nil, recovery: nil
                ))
                continue
            }
            let emitter = TransferProgressEmitter(
                source: url, index: index, total: urls.count, moving: moving,
                interval: progressInterval, callback: progress
            )
            emitter.emit(.preparing)
            let result: FileTransferItemResult
            do {
                try cancellation?.check()
                guard directoryExists(dest) else {
                    throw FileOpError("대상이 폴더가 아닙니다.")
                }
                guard itemExists(url) else {
                    throw FileOpError("원본 항목이 없습니다.")
                }
                guard !contains(dest, inside: url) else {
                    throw FileOpError("폴더를 그 안으로 옮길 수 없습니다.")
                }
                result = try place(url, at: target, moving: moving, resolve: resolve,
                                   cancellation: cancellation, progress: emitter)
            } catch {
                result = FileTransferItemResult(
                    source: url, destination: target,
                    status: error is TransferCancelled ? .cancelled : .failed,
                    message: error.localizedDescription, recovery: nil
                )
            }
            items.append(result)
            emitter.emit(.finished)
            stopped = result.status == .failed || result.status == .cancelled
        }
        return FileTransferReport(items: items)
    }

    /// Sends each item to the Trash through `moveToTrash`, stopping at the first failure.
    /// Never throws: the report keeps what was trashed so far.
    public func trash(urls: [URL]) -> FileTrashReport {
        var items: [FileTrashItemResult] = []
        items.reserveCapacity(urls.count)
        var stopped = false
        for url in urls {
            if stopped {
                items.append(FileTrashItemResult(original: url, trashedURL: nil, status: .unprocessed))
                continue
            }
            do {
                let trashed = try moveToTrash(url)
                items.append(FileTrashItemResult(original: url, trashedURL: trashed, status: .trashed))
            } catch {
                var failure = FileTrashItemResult(
                    original: url, trashedURL: nil, status: .failed(error.localizedDescription)
                )
                if let cocoa = error as? CocoaError, cocoa.code == .featureUnsupported || cocoa.code == .fileWriteVolumeReadOnly {
                    failure.trashUnsupported = true
                }
                items.append(failure)
                stopped = true
            }
        }
        return FileTrashReport(items: items)
    }

    @discardableResult
    public func rename(
        url: URL,
        to newName: String,
        resolve: (String) throws -> NameConflict
    ) throws -> RenameOutcome {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("/"), trimmed != ".", trimmed != ".." else {
            throw FileOpError("그 이름은 쓸 수 없습니다.")
        }
        guard itemExists(url) else { throw FileOpError("원본 항목이 없습니다.") }
        let target = url.deletingLastPathComponent().appendingPathComponent(trimmed)
        if stdPath(target) == stdPath(url) { return .unchanged }
        let result: FileTransferItemResult
        // Case-only renames on case-insensitive volumes need an intermediate name,
        // not replacement of an alias for the source itself.
        let sourceID = try? url.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier
        let targetID = try? target.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier
        if trimmed.caseInsensitiveCompare(url.lastPathComponent) == .orderedSame,
           let sourceID = sourceID as? NSObject, let targetID = targetID as? NSObject,
           sourceID == targetID {
            result = write(url, to: target, moving: true, replacing: false, stagingMove: true)
        } else {
            result = try place(url, at: target, moving: true, resolve: resolve)
            if result.status == .skipped { return .skipped }
        }
        if result.status == .failed || result.message != nil {
            var message = result.message ?? "이름을 바꾸지 못했습니다."
            message += "\n원본: \(url.path)\n대상: \(result.destination.path)"
            if let recovery = result.recovery {
                message += "\n\(recovery.message)"
                for location in recovery.locations { message += "\n\(location.path)" }
            }
            throw FileOpError(message)
        }
        return .renamed(result)
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

    public static func trashItemRecording(_ url: URL) throws -> URL? {
        var resulting: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resulting)
        return resulting as URL?
    }

    private func place(
        _ url: URL,
        at target: URL,
        moving: Bool,
        resolve: (String) throws -> NameConflict,
        cancellation: FileTransferCancellation? = nil,
        progress: TransferProgressEmitter? = nil
    ) throws -> FileTransferItemResult {
        try cancellation?.check()
        let samePath = stdPath(target) == stdPath(url)
        if moving && samePath {
            return FileTransferItemResult(
                source: url, destination: target, status: .completed, message: nil, recovery: nil
            )
        }
        var destination = target
        var replacing = false
        if itemExists(target) {
            let choice = try resolve(target.lastPathComponent)
            try cancellation?.check()
            switch choice {
            case .skip:
                return FileTransferItemResult(
                    source: url, destination: target, status: .skipped, message: nil, recovery: nil
                )
            case .replace:
                if samePath {
                    return FileTransferItemResult(
                        source: url, destination: target, status: .skipped, message: nil, recovery: nil
                    )
                }
                replacing = true
            case .keepBoth:
                let directory = target.deletingLastPathComponent()
                destination = directory.appendingPathComponent(
                    keepBothName(in: directory, existingName: target.lastPathComponent)
                )
            }
        }
        return write(url, to: destination, moving: moving, replacing: replacing,
                     cancellation: cancellation, progress: progress)
    }

    func write(
        _ url: URL,
        to target: URL,
        moving: Bool,
        replacing: Bool,
        stagingMove: Bool = false,
        cancellation: FileTransferCancellation? = nil,
        progress: TransferProgressEmitter? = nil
    ) -> FileTransferItemResult {
        let directory = target.deletingLastPathComponent()
        let moveSource = moving && sameVolume(url, directory)
        if moveSource && !replacing && !stagingMove {
            do {
                progress?.emit(.committing)
                try cancellation?.check()
                try fm.moveItem(at: url, to: target)
                return FileTransferItemResult(
                    source: url, destination: target, status: .completed, message: nil, recovery: nil,
                    destinationID: fileIdentity(target), movedInPlace: true
                )
            } catch {
                return FileTransferItemResult(
                    source: url, destination: target,
                    status: error is TransferCancelled ? .cancelled : .failed,
                    message: error.localizedDescription, recovery: nil
                )
            }
        }

        // All copied bytes are written on the destination volume before its old
        // item is touched. Same-volume moves stage by rename, not by copying.
        let stage = directory.appendingPathComponent(".ihatefinder-transfer-\(UUID().uuidString)", isDirectory: true)
        let incoming = stage.appendingPathComponent("incoming", isDirectory: true)
            .appendingPathComponent(target.lastPathComponent)
        let previous = stage.appendingPathComponent("previous", isDirectory: true)
            .appendingPathComponent(target.lastPathComponent)
        var sourceStaged = false
        var destinationStaged = false
        do {
            try cancellation?.check()
            try fm.createDirectory(at: incoming.deletingLastPathComponent(), withIntermediateDirectories: true)
            if moveSource {
                progress?.emit(.committing)
                try cancellation?.check()
                try fm.moveItem(at: url, to: incoming)
                sourceStaged = true
            } else {
                // Cloning needs the same volume; a clone cannot be interrupted, so
                // cancellation is checked before it starts and before commit.
                let performCopy = cloneOnSameVolume && sameVolume(url, directory) ? cloneCopy : copy
                try performCopy(url, incoming, cancellation) { sample in
                    progress?.emit(.copying, copy: sample)
                }
                progress?.emit(.committing)
                try cancellation?.check()
            }
            // Commit starts here (or at the source rename above). From this point
            // cancellation cannot interrupt publish, rollback, or source cleanup.
            if replacing {
                try fm.createDirectory(at: previous.deletingLastPathComponent(), withIntermediateDirectories: false)
                try fm.moveItem(at: target, to: previous)
                destinationStaged = true
            }
            try fm.moveItem(at: incoming, to: target)
        } catch {
            var recoveryErrors: [String] = []
            var locations: [URL] = []
            if sourceStaged {
                do {
                    try fm.moveItem(at: incoming, to: url)
                } catch {
                    recoveryErrors.append("원본 복구 실패: \(error.localizedDescription)")
                    locations.append(incoming)
                }
            }
            if destinationStaged {
                do {
                    try fm.moveItem(at: previous, to: target)
                } catch {
                    recoveryErrors.append("기존 대상 복구 실패: \(error.localizedDescription)")
                    locations.append(previous)
                }
            }
            // Never clean a stage containing the only surviving original.
            if recoveryErrors.isEmpty && itemExists(stage) {
                do {
                    try fm.removeItem(at: stage)
                } catch {
                    recoveryErrors.append("임시 항목 정리 실패: \(error.localizedDescription)")
                    locations.append(itemExists(incoming) ? incoming : stage)
                }
            }
            let recovery: FileTransferRecovery?
            if !recoveryErrors.isEmpty {
                recovery = FileTransferRecovery(
                    status: .manualRecoveryRequired, locations: locations,
                    message: recoveryErrors.joined(separator: "\n")
                )
            } else if replacing || sourceStaged {
                recovery = FileTransferRecovery(
                    status: destinationStaged || sourceStaged ? .restored : .preserved,
                    locations: replacing ? [url, target] : [url],
                    message: destinationStaged || sourceStaged
                        ? "원본과 기존 대상을 작업 전 위치로 복구했습니다."
                        : "기존 대상과 원본은 작업 전 위치에 보존되어 있습니다."
                )
            } else {
                recovery = nil
            }
            return FileTransferItemResult(
                source: url, destination: target,
                status: error is TransferCancelled ? .cancelled : .failed,
                message: error.localizedDescription, recovery: recovery
            )
        }

        // The new destination is complete. Failure from here must never remove it.
        // In particular, a failed cross-volume source trash leaves both full copies.
        var status: FileTransferStatus = .completed
        var messages: [String] = []
        var locations: [URL] = []
        var sourceTrashURL: URL?
        var replacedTrashURL: URL?
        if moving && !moveSource {
            do {
                sourceTrashURL = try moveToTrash(url)
            } catch {
                status = .failed
                messages.append("복사본은 만들었지만 원본을 휴지통으로 보내지 못했습니다: \(error.localizedDescription)")
                locations += [url, target]
            }
        }
        var preservedBackup = false
        if destinationStaged {
            do {
                replacedTrashURL = try moveToTrash(previous)
            } catch {
                preservedBackup = true
                messages.append("새 대상은 완성되었지만 기존 대상을 휴지통으로 보내지 못했습니다: \(error.localizedDescription)")
                locations.append(previous)
            }
        }
        if !preservedBackup {
            do {
                try fm.removeItem(at: stage)
            } catch {
                messages.append("임시 폴더 정리 실패: \(error.localizedDescription)")
                locations.append(stage)
            }
        }
        let message = messages.isEmpty ? nil : messages.joined(separator: "\n")
        let recovery = message.map {
            FileTransferRecovery(status: .manualRecoveryRequired, locations: locations, message: $0)
        }
        return FileTransferItemResult(
            source: url, destination: target, status: status, message: message, recovery: recovery,
            replacedExisting: destinationStaged, replacedTrashURL: replacedTrashURL,
            sourceTrashURL: sourceTrashURL,
            destinationID: status == .completed ? fileIdentity(target) : nil,
            movedInPlace: moveSource
        )
    }

    func itemExists(_ url: URL) -> Bool {
        fm.fileExists(atPath: url.path) || (try? fm.destinationOfSymbolicLink(atPath: url.path)) != nil
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

    func directoryExists(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return fm.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }


    func stdPath(_ url: URL) -> String {
        url.standardizedFileURL.path
    }

    private func contains(_ dest: URL, inside ancestor: URL) -> Bool {
        let destPath = stdPath(dest)
        let ancestorPath = stdPath(ancestor)
        if destPath == ancestorPath { return true }
        return destPath.hasPrefix(ancestorPath.hasSuffix("/") ? ancestorPath : ancestorPath + "/")
    }
}
