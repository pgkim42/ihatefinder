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
        alert.icon = NSWorkspace.shared.icon(forFile: url.path)
        alert.addButton(withTitle: "닫기")
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.widthAnchor.constraint(equalToConstant: 460).isActive = true
        fill(stack, with: [("상태", "읽는 중…")])
        alert.accessoryView = stack
        DispatchQueue.global(qos: .userInitiated).async {
            let model = InfoModel.make(url: url)
            DispatchQueue.main.async {
                if let model {
                    fill(stack, with: rows(for: model))
                } else {
                    fill(stack, with: [("경로", url.path), ("상태", "정보를 읽지 못했습니다.")])
                }
            }
        }
        if let window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
        return alert
    }

    private static func fill(_ stack: NSStackView, with rows: [(String, String)]) {
        for view in stack.arrangedSubviews {
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        for (label, value) in rows {
            let key = NSTextField(labelWithString: label)
            key.font = Studio.headerFont
            key.textColor = Studio.muted
            key.alignment = .right
            key.widthAnchor.constraint(equalToConstant: 72).isActive = true
            let detail = NSTextField(wrappingLabelWithString: value)
            detail.font = .systemFont(ofSize: 12, weight: .regular)
            detail.textColor = Studio.ink
            detail.isSelectable = true
            detail.preferredMaxLayoutWidth = 360
            let row = NSStackView(views: [key, detail])
            row.orientation = .horizontal
            row.alignment = .firstBaseline
            row.spacing = 12
            stack.addArrangedSubview(row)
        }
    }
}
