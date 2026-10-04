import AppKit
import IHateFinderCore

/// Read-only item info, shown as a sheet. The folder item count is read in the background.
@MainActor
final class InfoPanel {
    private static let sizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter
    }()

    /// The label/value rows shown for `model`.
    static func rows(for model: InfoModel, countText: String? = nil) -> [(String, String)] {
        var rows: [(String, String)] = [("이름", model.name), ("종류", model.kind)]
        if let size = model.size {
            rows.append(("크기", "\(sizeFormatter.string(fromByteCount: size)) (\(size)바이트)"))
        }
        if model.isDirectory {
            let count = model.itemCount.map { "\($0)개" } ?? countText ?? "세는 중…"
            rows.append(("항목 수", count))
        }
        rows.append(("만든 날짜", model.created.map(dateFormatter.string(from:)) ?? "—"))
        rows.append(("수정한 날짜", model.modified.map(dateFormatter.string(from:)) ?? "—"))
        rows.append(("경로", model.path))
        rows.append(("권한", model.permissions))
        return rows
    }

    /// Opens the sheet on `window`. Returns the alert so callers (tests) can inspect or end it.
    @discardableResult
    static func present(for url: URL, in window: NSWindow?) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = url.lastPathComponent
        alert.addButton(withTitle: "닫기")
        let text = NSTextField(wrappingLabelWithString: "읽는 중…")
        text.isSelectable = true
        text.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        text.preferredMaxLayoutWidth = 420
        alert.accessoryView = text
        DispatchQueue.global(qos: .userInitiated).async {
            let model = InfoModel.make(url: url)
            DispatchQueue.main.async {
                guard let model else {
                    text.stringValue = "정보를 읽지 못했습니다.\n\(url.path)"
                    return
                }
                text.stringValue = rows(for: model).map { "\($0.0): \($0.1)" }.joined(separator: "\n")
                text.sizeToFit()
            }
        }
        if let window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
        return alert
    }
}
