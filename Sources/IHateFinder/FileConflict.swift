import AppKit
import IHateFinderCore

enum FileConflictDecision {
    case replace, skip, keepBoth, cancel

    var choice: NameConflict? {
        switch self {
        case .replace: return .replace
        case .skip: return .skip
        case .keepBoth: return .keepBoth
        case .cancel: return nil
        }
    }
}

/// Read on the file-operation worker before presenting a conflict on the main thread.
struct FileConflictContext {
    struct Item {
        let url: URL
        let kind: String
        let size: Int64?
        let modified: Date?
        let isDirectory: Bool

        init(_ url: URL) {
            self.url = url
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
            let type = attributes?[.type] as? FileAttributeType
            isDirectory = type == .typeDirectory
            switch type {
            case .typeDirectory: kind = "폴더"
            case .typeSymbolicLink: kind = "심볼릭 링크"
            case .typeRegular: kind = "파일"
            default: kind = "확인할 수 없음"
            }
            size = isDirectory ? nil : (attributes?[.size] as? NSNumber)?.int64Value
            modified = attributes?[.modificationDate] as? Date
        }

        func description(label: String) -> String {
            let sizeText = isDirectory ? "폴더 전체 크기는 계산하지 않음" : size.map {
                ByteCountFormatter.string(fromByteCount: $0, countStyle: .file)
            } ?? "크기 확인 불가"
            let dateText = modified.map { DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .medium) }
                ?? "수정 시각 확인 불가"
            return "\(label): \(url.path)\n\(kind) · \(sizeText)\n수정: \(dateText)"
        }
    }

    let source: Item
    let destination: Item

    init(source: URL, destination: URL) {
        self.source = Item(source)
        self.destination = Item(destination)
    }

    var details: String {
        var text = source.description(label: "원본") + "\n\n" + destination.description(label: "대상")
        if destination.isDirectory {
            text += "\n\n바꾸기는 대상 폴더 전체를 교체합니다. 두 폴더의 내용을 합치지 않습니다."
        }
        text += "\n기존 대상은 바꾸기 완료 시 휴지통으로 보냅니다."
        return text
    }

    @MainActor func makeAlert(canCancelTransfer: Bool) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = "같은 이름이 있습니다"
        alert.informativeText = destination.url.lastPathComponent
        for title in ["바꾸기", "건너뛰기", "둘 다 유지", canCancelTransfer ? "전체 작업 취소" : "취소"] {
            alert.addButton(withTitle: title)
        }
        alert.buttons.last?.keyEquivalent = "\u{1b}"
        let text = NSTextView(frame: NSRect(x: 0, y: 0, width: 520, height: 220))
        text.isEditable = false
        text.isSelectable = true
        text.isRichText = false
        text.font = .systemFont(ofSize: 12)
        text.string = details
        text.isVerticallyResizable = true
        text.autoresizingMask = [.width]
        text.textContainer?.widthTracksTextView = true
        let scroll = NSScrollView(frame: text.frame)
        scroll.hasVerticalScroller = true
        scroll.documentView = text
        let stack = NSStackView(views: [scroll])
        stack.orientation = .vertical
        stack.alignment = .leading
        scroll.widthAnchor.constraint(equalToConstant: 520).isActive = true
        scroll.heightAnchor.constraint(equalToConstant: 220).isActive = true
        stack.setFrameSize(stack.fittingSize)
        alert.accessoryView = stack
        return alert
    }
}
