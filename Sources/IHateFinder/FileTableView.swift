import AppKit

final class FileTableView: NSTableView {
    weak var pane: FilePaneController?
    private var renameGeneration = 0

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { pane?.claimFocus() }
        return accepted
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount > 1 {
            renameGeneration += 1
        }
        let local = convert(event.locationInWindow, from: nil)
        let row = self.row(at: local)
        let alreadySelected = row >= 0 && selectedRowIndexes.contains(row)
        let generation = renameGeneration
        super.mouseDown(with: event)
        guard event.clickCount == 1, alreadySelected, selectedRow == row else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            guard let self,
                  self.renameGeneration == generation,
                  self.selectedRow == row,
                  self.window?.firstResponder === self else { return }
            self.pane?.beginRename()
        }
    }

    func cancelPendingRename() {
        renameGeneration += 1
    }
}
