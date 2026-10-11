import Foundation

public enum FileOperationKind: Equatable {
    case copy
    case move
    case rename
    case trash
    case createFolder
    case createFile
    case compress
    case undo

    public var title: String {
        switch self {
        case .copy: return "복사"
        case .move: return "옮기기"
        case .rename: return "이름 바꾸기"
        case .trash: return "휴지통으로 이동"
        case .createFolder: return "새 폴더 만들기"
        case .createFile: return "새 파일 만들기"
        case .compress: return "압축"
        case .undo: return "실행 취소"
        }
    }
}

public enum FileOperationStatus: Equatable {
    case running
    case completed
    case skipped
    case failed
    case cancelled
    case unprocessed
    case partial

    public var title: String {
        switch self {
        case .running: return "진행 중"
        case .completed: return "완료"
        case .skipped: return "건너뜀"
        case .failed: return "실패"
        case .cancelled: return "취소됨"
        case .unprocessed: return "미처리"
        case .partial: return "부분 완료"
        }
    }
}

public struct FileOperationItem: Equatable {
    public let source: URL?
    public let destination: URL?
    public let status: FileOperationStatus
    public let message: String?
    public let recoveryLocations: [URL]

    public init(source: URL? = nil, destination: URL? = nil, status: FileOperationStatus,
                message: String? = nil, recoveryLocations: [URL] = []) {
        self.source = source
        self.destination = destination
        self.status = status
        self.message = message
        self.recoveryLocations = recoveryLocations
    }
}

public struct FileOperationRecord: Equatable {
    public let id: UUID
    public let kind: FileOperationKind
    public let windowID: UUID
    public let windowTitle: String
    public let startedAt: Date
    public let finishedAt: Date?
    public let parentID: UUID?
    public let items: [FileOperationItem]

    public init(id: UUID = UUID(), kind: FileOperationKind, windowID: UUID, windowTitle: String,
                startedAt: Date, finishedAt: Date? = nil, parentID: UUID? = nil,
                items: [FileOperationItem]) {
        self.id = id
        self.kind = kind
        self.windowID = windowID
        self.windowTitle = windowTitle
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.parentID = parentID
        self.items = items
    }

    public var status: FileOperationStatus {
        guard finishedAt != nil, !items.contains(where: { $0.status == .running }) else { return .running }
        guard let first = items.first else { return .unprocessed }
        if items.allSatisfy({ $0.status == first.status }) { return first.status }
        // Completed work mixed with anything else, or an incomplete item, is never all-completed.
        if items.contains(where: { $0.status == .completed || $0.status == .partial }) { return .partial }
        // A stopped batch can include skipped or unprocessed items without having succeeded.
        if items.contains(where: { $0.status == .failed }) { return .failed }
        if items.contains(where: { $0.status == .cancelled }) { return .cancelled }
        return .partial
    }

    public var summary: String {
        let statuses: [FileOperationStatus] = [.running, .completed, .skipped, .failed, .cancelled, .unprocessed, .partial]
        return statuses.compactMap { status in
            let count = items.filter { $0.status == status }.count
            return count == 0 ? nil : "\(status.title) \(count)"
        }.joined(separator: ", ")
    }
}

/// Main-thread only. Lives for the current run and never performs file system operations.
public final class FileOperationHistory {
    public private(set) var records: [FileOperationRecord] = []
    public var onChange: (() -> Void)?
    private let limit: Int

    public init(limit: Int = 1000) {
        precondition(limit >= 0)
        self.limit = limit
    }

    @discardableResult
    public func begin(kind: FileOperationKind, windowID: UUID, windowTitle: String,
                      items: [FileOperationItem], parentID: UUID? = nil) -> UUID {
        let record = FileOperationRecord(kind: kind, windowID: windowID, windowTitle: windowTitle,
                                         startedAt: Date(), parentID: parentID, items: items)
        records.insert(record, at: 0)
        onChange?()
        return record.id
    }

    public func finish(_ id: UUID, items: [FileOperationItem]) {
        guard let index = records.firstIndex(where: { $0.id == id }), records[index].finishedAt == nil else { return }
        let record = records[index]
        records[index] = FileOperationRecord(id: record.id, kind: record.kind, windowID: record.windowID,
                                            windowTitle: record.windowTitle, startedAt: record.startedAt,
                                            finishedAt: Date(), parentID: record.parentID, items: items)
        var finishedCount = 0
        records.removeAll { record in
            guard record.finishedAt != nil else { return false }
            finishedCount += 1
            return finishedCount > limit
        }
        onChange?()
    }
}
