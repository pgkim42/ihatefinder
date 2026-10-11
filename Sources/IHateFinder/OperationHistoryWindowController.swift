import AppKit
import IHateFinderCore

@MainActor
final class FileOperationHistoryWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    let table = NSTableView()
    let detailView = NSTextView()
    let emptyStateLabel = NSTextField(labelWithString: "이 실행에서 기록된 파일 작업이 없습니다.")
    private(set) var displayedRecords: [FileOperationRecord] = []
    private(set) var selectedRecordID: UUID?
    private let history: FileOperationHistory
    private var isReloading = false
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()

    init(history: FileOperationHistory) {
        self.history = history
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 660),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = "파일 작업 기록"
        window.minSize = NSSize(width: 620, height: 460)
        window.isReleasedWhenClosed = false
        window.backgroundColor = Studio.canvas
        super.init(window: window)
        configureContent(in: window)
        window.center()
        reloadHistory()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    func reloadHistory() {
        let retainedID = selectedRecordID
        isReloading = true
        displayedRecords = history.records
        table.reloadData()
        if let retainedID, let row = displayedRecords.firstIndex(where: { $0.id == retainedID }) {
            table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        } else {
            table.deselectAll(nil)
        }
        isReloading = false
        emptyStateLabel.isHidden = !displayedRecords.isEmpty
        updateDetails()
    }

    private func configureContent(in window: NSWindow) {
        let canvas = StudioCanvas()
        window.contentView = canvas
        let heading = NSTextField(labelWithString: "파일 작업 기록")
        heading.font = .systemFont(ofSize: 20, weight: .semibold)
        heading.textColor = Studio.ink
        let subtitle = NSTextField(labelWithString: "현재 실행의 작업과 실행 취소 시도 · 읽기 전용")
        subtitle.font = Studio.metaFont
        subtitle.textColor = Studio.muted

        table.dataSource = self
        table.delegate = self
        table.rowHeight = 30
        table.backgroundColor = Studio.card
        table.allowsMultipleSelection = false
        table.allowsEmptySelection = true
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        table.setAccessibilityLabel("파일 작업 기록 목록")
        for (identifier, title, width) in [
            ("time", "시작 시간", 165.0), ("kind", "작업", 90.0),
            ("window", "시작한 창", 130.0), ("result", "결과", 400.0),
        ] {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
            column.title = title
            column.width = width
            column.minWidth = identifier == "result" ? 180 : 80
            column.isEditable = false
            table.addTableColumn(column)
        }
        let tableScroll = NSScrollView()
        tableScroll.hasVerticalScroller = true
        tableScroll.hasHorizontalScroller = true
        tableScroll.documentView = table
        tableScroll.drawsBackground = false

        emptyStateLabel.font = Studio.metaFont
        emptyStateLabel.textColor = Studio.muted
        emptyStateLabel.alignment = .center
        let detailHeading = NSTextField(labelWithString: "작업 상세")
        detailHeading.font = Studio.headerFont
        detailHeading.textColor = Studio.muted
        detailView.isEditable = false
        detailView.isSelectable = true
        detailView.isRichText = false
        detailView.allowsUndo = false
        detailView.font = Studio.pathFont
        detailView.textColor = Studio.ink
        detailView.backgroundColor = Studio.card
        detailView.textContainerInset = NSSize(width: 14, height: 12)
        detailView.isVerticallyResizable = true
        detailView.isHorizontallyResizable = false
        detailView.autoresizingMask = [.width]
        detailView.textContainer?.widthTracksTextView = true
        detailView.setAccessibilityLabel("파일 작업 상세")
        let detailScroll = NSScrollView()
        detailView.minSize = .zero
        detailView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        detailView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        detailScroll.hasVerticalScroller = true
        detailScroll.documentView = detailView

        for view in [heading, subtitle, tableScroll, emptyStateLabel, detailHeading, detailScroll] {
            view.translatesAutoresizingMaskIntoConstraints = false
            canvas.addSubview(view)
        }
        NSLayoutConstraint.activate([
            heading.leadingAnchor.constraint(equalTo: canvas.leadingAnchor, constant: 20),
            heading.topAnchor.constraint(equalTo: canvas.topAnchor, constant: 18),
            subtitle.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            subtitle.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 6),
            tableScroll.leadingAnchor.constraint(equalTo: canvas.leadingAnchor, constant: 20),
            tableScroll.trailingAnchor.constraint(equalTo: canvas.trailingAnchor, constant: -20),
            tableScroll.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 18),
            tableScroll.heightAnchor.constraint(equalTo: canvas.heightAnchor, multiplier: 0.42),
            emptyStateLabel.centerXAnchor.constraint(equalTo: tableScroll.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: tableScroll.centerYAnchor),
            detailHeading.leadingAnchor.constraint(equalTo: tableScroll.leadingAnchor),
            detailHeading.topAnchor.constraint(equalTo: tableScroll.bottomAnchor, constant: 16),
            detailScroll.leadingAnchor.constraint(equalTo: tableScroll.leadingAnchor),
            detailScroll.trailingAnchor.constraint(equalTo: tableScroll.trailingAnchor),
            detailScroll.topAnchor.constraint(equalTo: detailHeading.bottomAnchor, constant: 8),
            detailScroll.bottomAnchor.constraint(equalTo: canvas.bottomAnchor, constant: -20),
        ])
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        displayedRecords.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard displayedRecords.indices.contains(row), let tableColumn else { return nil }
        let record = displayedRecords[row]
        let value: String
        switch tableColumn.identifier.rawValue {
        case "time": value = dateFormatter.string(from: record.startedAt)
        case "kind": value = record.kind.title
        case "window": value = "창 \(record.windowTitle)"
        default: value = "\(record.status.title) · \(record.summary)"
        }
        let field = NSTextField(labelWithString: value)
        field.font = Studio.metaFont
        field.textColor = record.status == .failed ? Studio.accent : Studio.ink
        field.lineBreakMode = .byTruncatingTail
        field.toolTip = value
        let cell = NSTableCellView()
        cell.addSubview(field)
        field.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            field.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            field.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        cell.textField = field
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !isReloading else { return }
        updateDetails()
    }

    private func updateDetails() {
        guard displayedRecords.indices.contains(table.selectedRow) else {
            selectedRecordID = nil
            detailView.string = ""
            return
        }
        let record = displayedRecords[table.selectedRow]
        selectedRecordID = record.id
        var lines = [
            "\(record.kind.title) · \(record.status.title)",
            "창 \(record.windowTitle)",
            "작업 ID: \(record.id.uuidString)",
            "시작: \(dateFormatter.string(from: record.startedAt))",
            "종료: \(record.finishedAt.map { dateFormatter.string(from: $0) } ?? "진행 중")",
        ]
        if let parentID = record.parentID {
            lines.append("원래 작업 ID: \(parentID.uuidString)")
        }
        for (index, item) in record.items.enumerated() {
            lines += [
                "", "항목 \(index + 1)",
                "원본: \(item.source?.path ?? "—")",
                "실제 대상: \(item.destination?.path ?? "—")",
                "상태: \(item.status.title)",
                "사유: \(item.message ?? "—")",
                "복구 위치: \(item.recoveryLocations.isEmpty ? "—" : item.recoveryLocations.map(\.path).joined(separator: "\n    "))",
            ]
        }
        detailView.string = lines.joined(separator: "\n")
        detailView.scrollRangeToVisible(NSRange(location: 0, length: 0))
    }
}
