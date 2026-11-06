import AppKit
import Quartz
import IHateFinderCore

final class FileTableView: NSTableView, NSMenuItemValidation {
    weak var pane: FilePaneController?
    private var renameGeneration = 0

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { pane?.claimFocus() }
        return accepted
    }

    /// Ctrl+left-click toggles the row like Cmd+click instead of opening the context menu.
    /// Secondary click and two-finger tap arrive as other event types and keep the menu.
    private func isControlToggle(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return event.type == .leftMouseDown && flags.contains(.control) && !flags.contains(.command)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        isControlToggle(event) ? nil : super.menu(for: event)
    }

    func toggleSelection(atRow row: Int) {
        guard row >= 0, row < numberOfRows else { return }
        if selectedRowIndexes.contains(row) {
            deselectRow(row)
        } else {
            selectRowIndexes(IndexSet(integer: row), byExtendingSelection: true)
        }
    }

    override func mouseDown(with event: NSEvent) {
        if isControlToggle(event) {
            cancelPendingRename()
            window?.makeFirstResponder(self)
            toggleSelection(atRow: row(at: convert(event.locationInWindow, from: nil)))
            return
        }
        cancelPendingRename()
        let local = convert(event.locationInWindow, from: nil)
        let row = self.row(at: local)
        let column = self.column(at: local)
        let plain = event.modifierFlags.intersection([.command, .shift, .control, .option]).isEmpty
        let soleSelected = row >= 0 && selectedRowIndexes == IndexSet(integer: row)
        let onName = column >= 0 && tableColumns[column].identifier.rawValue == SortColumn.name.rawValue
        super.mouseDown(with: event)
        guard plain, onName, soleSelected, event.clickCount == 1,
              selectedRowIndexes == IndexSet(integer: row) else { return }
        let generation = renameGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            guard let self,
                  self.renameGeneration == generation,
                  self.selectedRowIndexes == IndexSet(integer: row),
                  self.window?.firstResponder === self else { return }
            self.pane?.beginRename()
        }
    }

    /// Any selection change (keyboard, type-select, programmatic) voids a pending click-to-rename.
    override func selectRowIndexes(_ indexes: IndexSet, byExtendingSelection extend: Bool) {
        cancelPendingRename()
        super.selectRowIndexes(indexes, byExtendingSelection: extend)
    }

    override func deselectRow(_ row: Int) {
        cancelPendingRename()
        super.deselectRow(row)
    }

    /// 편집 > 실행 취소 and Ctrl+Z reach the list through the responder chain.
    /// While a text field is being edited, its field editor receives them instead.
    @objc func undo(_ sender: Any?) {
        pane?.browser?.undoFileOperation()
    }

    /// Exists only so 다시 실행 can be validated as disabled; there is no file redo.
    @objc func redo(_ sender: Any?) {}

    /// True while an inline rename editor belongs to this table. The editor's responder chain
    /// runs through the table, so without this the table would take 실행 취소 away from the text.
    /// True while the window's field editor belongs to a cell of this table. `currentEditor()` is not
    /// used: it asks `responds(to:)` and would recurse.
    private var isEditingText: Bool {
        if editedRow >= 0 { return true }
        guard let editor = window?.firstResponder as? NSTextView, editor.isFieldEditor else { return false }
        return (editor.delegate as? NSView)?.isDescendant(of: self) == true
    }

    /// While renaming, undo:/redo: must reach the window's text undo manager, not the file journal.
    override func responds(to selector: Selector!) -> Bool {
        if isEditingText,
           selector == #selector(FileTableView.undo(_:)) || selector == #selector(FileTableView.redo(_:)) {
            return false
        }
        return super.responds(to: selector)
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        if isEditingText,
           item.action == #selector(FileTableView.undo(_:)) || item.action == #selector(FileTableView.redo(_:)) {
            return false
        }
        switch item.action {
        case #selector(FileTableView.undo(_:)):
            guard let browser = pane?.browser, let record = browser.undoJournal.peek else {
                item.title = "실행 취소"
                return false
            }
            item.title = "실행 취소 \(record.title)"
            return !browser.isFileOperationRunning
        case #selector(FileTableView.redo(_:)):
            item.title = "다시 실행"
            return false
        default:
            return true
        }
    }

    /// Space or Cmd+Y. Shift/Ctrl/Option+Space are not Quick Look keys.
    static func isQuickLookKey(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        let modifiers = flags.intersection([.command, .shift, .control, .option])
        switch keyCode {
        case 49: return modifiers.isEmpty
        case 16: return modifiers == .command
        default: return false
        }
    }

    static func isQuickLookKey(_ event: NSEvent) -> Bool {
        isQuickLookKey(keyCode: event.keyCode, flags: event.modifierFlags)
    }

    override func keyDown(with event: NSEvent) {
        cancelPendingRename()
        if FileTableView.isQuickLookKey(event), editedRow < 0 {
            pane?.toggleQuickLook()
            return
        }
        if event.keyCode == 53 {
            if pane?.clearRecursiveSearch() == true || pane?.clearActiveFilter() == true { return }
        }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.type == .keyDown, event.keyCode == 16, FileTableView.isQuickLookKey(event),
           editedRow < 0, window?.firstResponder === self {
            pane?.toggleQuickLook()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        true
    }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = pane
        panel.delegate = pane
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        if panel.dataSource === pane { panel.dataSource = nil }
        if panel.delegate === pane { panel.delegate = nil }
    }

    func cancelPendingRename() {
        renameGeneration += 1
    }
}
