import Foundation
import IHateFinderCore

extension BrowserWindowController {
    func beginOperation(_ kind: FileOperationKind, items: [FileOperationItem], parentID: UUID? = nil) -> UUID {
        operationHistory.begin(kind: kind, windowID: historyWindowID,
                               windowTitle: historyWindowTitle, items: items, parentID: parentID)
    }

    func finishOperation(_ id: UUID?, items: [FileOperationItem]) {
        if let id { operationHistory.finish(id, items: items) }
    }

    static func historyItem(_ result: FileTransferItemResult) -> FileOperationItem {
        let status: FileOperationStatus
        switch result.status {
        case .completed: status = result.recovery?.status == .manualRecoveryRequired ? .partial : .completed
        case .skipped: status = .skipped
        case .failed: status = result.recovery?.status == .manualRecoveryRequired ? .partial : .failed
        case .cancelled: status = .cancelled
        case .unprocessed: status = .unprocessed
        }
        let messages = [result.message, result.recovery?.message].compactMap { $0 }
        var locations = result.recovery?.locations ?? []
        for location in [result.replacedTrashURL, result.sourceTrashURL].compactMap({ $0 }) where !locations.contains(location) {
            locations.append(location)
        }
        return FileOperationItem(source: result.source, destination: result.destination, status: status,
                                 message: messages.isEmpty ? nil : messages.joined(separator: "\n"), recoveryLocations: locations)
    }

    static func historyItem(_ result: FileTrashItemResult) -> FileOperationItem {
        let status: FileOperationStatus
        var message: String?
        switch result.status {
        case .trashed: status = .completed
        case .failed(let reason):
            status = .failed
            message = reason
            if result.trashUnsupported { message = reason + "\n이 디스크는 휴지통을 지원하지 않을 수 있습니다." }
        case .unprocessed: status = .unprocessed
        }
        return FileOperationItem(source: result.original, destination: result.trashedURL, status: status,
                                 message: message, recoveryLocations: result.trashedURL.map { [$0] } ?? [])
    }

    static func historyItem(_ item: UndoItem) -> FileOperationItem {
        switch item {
        case .created(let url, _), .copied(let url, _, _):
            return FileOperationItem(source: url, status: .running)
        case .moved(let from, let to, _, _, _, _), .renamed(let from, let to, _, _):
            return FileOperationItem(source: to, destination: from, status: .running)
        case .trashed(let original, let trash):
            return FileOperationItem(source: trash.trashURL, destination: original, status: .running)
        }
    }

    static func historyItems(_ report: FileUndoReport, record: UndoRecord) -> [FileOperationItem] {
        zip(record.items.reversed(), report.items).map { item, result in
            let paths = historyItem(item)
            let status: FileOperationStatus
            switch result.status {
            case .undone: status = .completed
            case .partiallyUndone: status = .partial
            case .failed: status = .failed
            default: status = .skipped
            }
            var message = result.message
            if report.retryRecord?.items.contains(item) == true {
                message = [message, "장애물을 제거한 뒤 실행 취소를 다시 시도할 수 있습니다."].compactMap { $0 }.joined(separator: "\n")
            }
            return FileOperationItem(source: paths.source, destination: paths.destination ?? result.recoveryLocations.first,
                                     status: status, message: message, recoveryLocations: result.recoveryLocations)
        }
    }
}
