import Foundation

/// A file's `fileResourceIdentifier`, read from a fresh URL so cached values are never used.
/// Two ids are equal only when the file system says they are the same item.
public struct FileID: Equatable, @unchecked Sendable {
    let raw: NSObject

    public static func == (lhs: FileID, rhs: FileID) -> Bool {
        lhs.raw.isEqual(rhs.raw)
    }

    /// Volumes without persistent IDs (FAT/exFAT, some network volumes) may reuse an identifier
    /// for a different item, so nothing read there can prove identity.
    static func volumeSupportsPersistentIDs(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.volumeSupportsPersistentIDsKey]).volumeSupportsPersistentIDs) ?? false
    }

    static func read(
        at url: URL,
        supportsPersistentIDs: (URL) -> Bool = FileID.volumeSupportsPersistentIDs
    ) -> FileID? {
        let fresh = URL(fileURLWithPath: url.path)
        guard supportsPersistentIDs(fresh) else { return nil }
        guard let value = try? fresh.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier,
              let object = value as? NSObject else { return nil }
        return FileID(raw: object)
    }
}

/// An item in the Trash. `id` is read at `trashURL` right after trashing, so a later
/// unrelated file with the same Trash path is never restored by mistake.
public struct TrashedRef: Equatable {
    public let trashURL: URL
    public let id: FileID?
}

/// An existing item that a replace moved to the Trash.
public struct ReplacedInfo: Equatable {
    public let originalPath: URL
    public let trash: TrashedRef?
}

public enum UndoItem: Equatable {
    case created(URL, id: FileID?)
    case copied(dest: URL, id: FileID?, replaced: ReplacedInfo?)
    case moved(from: URL, to: URL, id: FileID?, sameVolume: Bool, sourceTrash: TrashedRef?, replaced: ReplacedInfo?)
    case renamed(from: URL, to: URL, id: FileID?, replaced: ReplacedInfo?)
    case trashed(original: URL, trash: TrashedRef)
}

public struct UndoRecord: Equatable {
    public let title: String
    public let items: [UndoItem]
}

public struct FileUndoItemResult: Equatable {
    public enum Status: Equatable {
        case undone
        /// The item to undo, or its Trash copy, is gone.
        case missing
        /// The item (or its Trash copy) is no longer the one the operation touched.
        case stale
        /// The original place is taken, so nothing is moved there.
        case occupied
        /// No file identity was available to prove it is the same item.
        case unverifiable
        /// The operation did not record where the old item went in the Trash.
        case notRestorable
        /// The main inverse happened but a follow-up step did not; the message says what stays where.
        case partiallyUndone
        case failed(String)
    }

    /// The path the user would recognise for this item.
    public let url: URL
    public let status: Status
    /// Paths that now hold restored items; the app reveals them.
    public let restored: [URL]
    public let message: String?

    public var isUndone: Bool { status == .undone }
}

public struct FileUndoReport: Equatable {
    public let title: String
    /// Applied in reverse record order.
    public let items: [FileUndoItemResult]

    public var undone: [FileUndoItemResult] { items.filter(\.isUndone) }
    /// Items that were only partly undone; their messages say what remains and where.
    public var partial: [FileUndoItemResult] { items.filter { $0.status == .partiallyUndone } }
    /// Items that were not touched (refused or failed), excluding partly undone ones.
    public var skipped: [FileUndoItemResult] { items.filter { !$0.isUndone && $0.status != .partiallyUndone } }
    public var restoredURLs: [URL] { items.flatMap(\.restored) }
}

/// Main-thread only. Lives for the session and is not persisted.
public final class FileUndoJournal {
    public static let limit = 50
    private var records: [UndoRecord] = []

    public init() {}

    public var count: Int { records.count }
    public var peek: UndoRecord? { records.last }

    public func push(_ record: UndoRecord) {
        records.append(record)
        if records.count > Self.limit { records.removeFirst(records.count - Self.limit) }
    }

    public func popLast() -> UndoRecord? {
        records.popLast()
    }

    public func clear() {
        records.removeAll()
    }
}

// MARK: Record builders

extension FileOps {
    /// Records only completed items whose path really changed. Skipped, failed, cancelled,
    /// unprocessed and same-path items are dropped. Call on the worker right after the operation.
    public func undoRecord(transfer report: FileTransferReport, moving: Bool) -> UndoRecord? {
        var items: [UndoItem] = []
        for result in report.items where result.status == .completed {
            if stdPath(result.source) == stdPath(result.destination) { continue }
            let dest = result.destination
            let id = result.destinationID
            let replaced = result.replacedExisting
                ? ReplacedInfo(originalPath: dest, trash: trashedRef(result.replacedTrashURL))
                : nil
            if moving {
                let sourceTrash = trashedRef(result.sourceTrashURL)
                items.append(.moved(from: result.source, to: dest, id: id, sameVolume: result.movedInPlace,
                                    sourceTrash: sourceTrash, replaced: replaced))
            } else {
                items.append(.copied(dest: dest, id: id, replaced: replaced))
            }
        }
        guard !items.isEmpty else { return nil }
        return UndoRecord(title: moving ? "옮기기" : "복사", items: items)
    }

    public func undoRecord(rename outcome: RenameOutcome, from: URL) -> UndoRecord? {
        guard case .renamed(let result) = outcome, result.status == .completed,
              stdPath(result.destination) != stdPath(from) else { return nil }
        let dest = result.destination
        let replaced = result.replacedExisting
            ? ReplacedInfo(originalPath: dest, trash: trashedRef(result.replacedTrashURL))
            : nil
        return UndoRecord(title: "이름 바꾸기", items: [
            .renamed(from: from, to: dest, id: result.destinationID, replaced: replaced),
        ])
    }

    /// Items whose Trash location is unknown cannot be restored and are left out.
    public func undoRecord(trash report: FileTrashReport) -> UndoRecord? {
        let items: [UndoItem] = report.items.compactMap { item in
            guard item.status == .trashed, let trashURL = item.trashedURL else { return nil }
            return .trashed(original: item.original, trash: TrashedRef(trashURL: trashURL, id: fileIdentity(trashURL)))
        }
        guard !items.isEmpty else { return nil }
        return UndoRecord(title: "휴지통으로 보내기", items: items)
    }

    public func undoRecord(created url: URL) -> UndoRecord? {
        UndoRecord(title: "새로 만들기", items: [.created(url, id: fileIdentity(url))])
    }

    private func trashedRef(_ url: URL?) -> TrashedRef? {
        url.map { TrashedRef(trashURL: $0, id: fileIdentity($0)) }
    }
}

// MARK: Inverses

extension FileOps {
    /// Applies the inverse of each item in reverse order. Never overwrites, never deletes:
    /// it only moves into an empty place or sends an item to the Trash. An item that fails
    /// a precondition is left untouched and reported.
    public func undo(_ record: UndoRecord) -> FileUndoReport {
        FileUndoReport(title: record.title, items: record.items.reversed().map(undoItem))
    }

    private typealias Status = FileUndoItemResult.Status

    private func undoItem(_ item: UndoItem) -> FileUndoItemResult {
        switch item {
        case .created(let url, let id):
            return undoNew(url, id: id, replaced: nil)
        case .copied(let dest, let id, let replaced):
            return undoNew(dest, id: id, replaced: replaced)
        case .moved(let from, let to, let id, let same, let sourceTrash, let replaced):
            return undoMoved(from: from, to: to, id: id, sameVolume: same, sourceTrash: sourceTrash, replaced: replaced)
        case .renamed(let from, let to, let id, let replaced):
            return undoRenamed(from: from, to: to, id: id, replaced: replaced)
        case .trashed(let original, let trash):
            return undoTrashed(original: original, trash: trash)
        }
    }

    private func undoNew(_ dest: URL, id: FileID?, replaced: ReplacedInfo?) -> FileUndoItemResult {
        if let status = presenceProblem(dest, id: id) ?? replacedProblem(replaced) {
            return result(dest, status)
        }
        do {
            _ = try moveToTrash(dest)
        } catch {
            return result(dest, .failed(error.localizedDescription), "휴지통으로 보내지 못했습니다: \(error.localizedDescription)")
        }
        return finish(dest, replaced: replaced, note: "새 항목은 휴지통으로 보냈습니다.")
    }

    private func undoMoved(
        from: URL, to: URL, id: FileID?, sameVolume same: Bool,
        sourceTrash: TrashedRef?, replaced: ReplacedInfo?
    ) -> FileUndoItemResult {
        if let status = presenceProblem(to, id: id) { return result(to, status) }
        if !same {
            guard let sourceTrash else { return result(to, .notRestorable) }
            if let status = trashProblem(sourceTrash) { return result(to, status) }
        }
        if let status = replacedProblem(replaced) { return result(to, status) }
        if let status = slotProblem(from) { return result(to, status) }
        do {
            if same {
                try fm.moveItem(at: to, to: from)
            } else if let sourceTrash {
                try fm.moveItem(at: sourceTrash.trashURL, to: from)
                do {
                    _ = try moveToTrash(to)
                } catch {
                    var message = "‘\(to.lastPathComponent)’: 원본은 되돌렸지만 옮겨 간 사본을 휴지통으로 보내지 못해 \(to.path)에 남아 있습니다: \(error.localizedDescription)"
                    if let trash = replaced?.trash {
                        message += "\n바꾸기로 휴지통에 간 기존 항목은 제자리로 돌리지 않았고 휴지통(\(trash.trashURL.path))에 남아 있습니다."
                    }
                    return result(from, .partiallyUndone, message, restored: [from])
                }
            }
        } catch {
            return result(to, .failed(error.localizedDescription), "되돌리지 못했습니다: \(error.localizedDescription)")
        }
        return finish(from, replaced: replaced, restoredBase: [from], note: nil)
    }

    private func undoRenamed(from: URL, to: URL, id: FileID?, replaced: ReplacedInfo?) -> FileUndoItemResult {
        if let status = presenceProblem(to, id: id) ?? replacedProblem(replaced) {
            return result(to, status)
        }
        // A case-only rename on a case-insensitive volume sees `from` as the item itself.
        let caseOnly = to.lastPathComponent.caseInsensitiveCompare(from.lastPathComponent) == .orderedSame
            && to.deletingLastPathComponent().path == from.deletingLastPathComponent().path
            && fileIdentity(from) == id
        if caseOnly {
            let outcome = write(to, to: from, moving: true, replacing: false, stagingMove: true)
            guard outcome.status == .completed, outcome.message == nil else {
                let message = outcome.message ?? "이름을 되돌리지 못했습니다."
                return result(to, .failed(message), message)
            }
        } else {
            if let status = slotProblem(from) { return result(to, status) }
            do {
                try fm.moveItem(at: to, to: from)
            } catch {
                return result(to, .failed(error.localizedDescription), "이름을 되돌리지 못했습니다: \(error.localizedDescription)")
            }
        }
        return finish(from, replaced: replaced, restoredBase: [from], note: nil)
    }

    private func undoTrashed(original: URL, trash: TrashedRef) -> FileUndoItemResult {
        if let status = trashProblem(trash) { return result(original, status) }
        if let status = slotProblem(original) { return result(original, status) }
        do {
            try fm.moveItem(at: trash.trashURL, to: original)
        } catch {
            return result(original, .failed(error.localizedDescription), "휴지통에서 꺼내지 못했습니다: \(error.localizedDescription)")
        }
        return result(original, .undone, restored: [original])
    }

    /// Second half of undoing a replace: puts the old item back once the new one is out of the way.
    private func finish(
        _ url: URL, replaced: ReplacedInfo?, restoredBase: [URL] = [], note: String?
    ) -> FileUndoItemResult {
        guard let replaced, let trash = replaced.trash else {
            return result(url, .undone, note, restored: restoredBase)
        }
        let name = "‘\(replaced.originalPath.lastPathComponent)’"
        if let status = slotProblem(replaced.originalPath) {
            let reason = status == .occupied ? "그 자리에 다른 항목이 있어" : "그 자리의 폴더가 없어"
            return result(url, .partiallyUndone,
                          "\(name): 되돌렸지만 \(reason) 바꾸기로 휴지통에 간 기존 항목은 휴지통(\(trash.trashURL.path))에 남아 있습니다.",
                          restored: restoredBase)
        }
        do {
            try fm.moveItem(at: trash.trashURL, to: replaced.originalPath)
        } catch {
            return result(url, .partiallyUndone,
                          "\(name): 되돌렸지만 기존 항목을 휴지통에서 꺼내지 못해 휴지통(\(trash.trashURL.path))에 남아 있습니다: \(error.localizedDescription)",
                          restored: restoredBase)
        }
        return result(url, .undone, note, restored: restoredBase + [replaced.originalPath])
    }

    // MARK: Preconditions

    /// Nil means `url` still holds the item the operation produced.
    private func presenceProblem(_ url: URL, id: FileID?) -> Status? {
        guard itemExists(url) else { return .missing }
        guard let id else { return .unverifiable }
        guard let current = fileIdentity(url) else { return .unverifiable }
        return current == id ? nil : .stale
    }

    /// Nil means the recorded Trash item is still the same one and may be moved out.
    private func trashProblem(_ ref: TrashedRef) -> Status? {
        presenceProblem(ref.trashURL, id: ref.id)
    }

    private func replacedProblem(_ replaced: ReplacedInfo?) -> Status? {
        guard let replaced else { return nil }
        guard let trash = replaced.trash else { return .notRestorable }
        return trashProblem(trash)
    }

    /// Nil means `url` is free and its folder exists.
    private func slotProblem(_ url: URL) -> Status? {
        if itemExists(url) { return .occupied }
        return directoryExists(url.deletingLastPathComponent()) ? nil : .missing
    }

    private func result(_ url: URL, _ status: Status, _ message: String? = nil, restored: [URL] = []) -> FileUndoItemResult {
        FileUndoItemResult(url: url, status: status, restored: restored, message: message ?? Self.message(for: status, url: url))
    }

    private static func message(for status: Status, url: URL) -> String? {
        let name = "‘\(url.lastPathComponent)’"
        switch status {
        case .undone: return nil
        case .missing: return "\(name): 항목이 없어 건너뛰었습니다."
        case .stale: return "\(name): 그 사이 다른 항목으로 바뀌어 건너뛰었습니다."
        case .occupied: return "\(name): 되돌릴 자리에 다른 항목이 있어 건너뛰었습니다."
        case .unverifiable: return "\(name): 같은 항목인지 확인할 수 없어 건너뛰었습니다."
        case .notRestorable: return "\(name): 바꾸기로 휴지통에 간 항목의 위치를 알 수 없어 건너뛰었습니다."
        case .partiallyUndone: return "\(name): 일부만 되돌렸습니다."
        case .failed(let message): return "\(name): \(message)"
        }
    }
}
