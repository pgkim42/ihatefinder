import AppKit

/// What a key press in the browser window means. The local key monitor only dispatches these;
/// `resolve` is a pure function so the mapping is testable without a window.
enum KeyCommand: Equatable {
    case focusPath
    case find
    case send(Selector)
    case copy
    case cut
    case paste
    case selectAll
    case newFolder
    case newTextFile
    case toggleHidden
    case goUp
    case goBack
    case goForward
    case copyToOther
    case moveToOther
    case rename
    case clearCut
    case trash
    case open
    case info

    static func resolve(
        keyCode: UInt16,
        characters: String,
        flags: NSEvent.ModifierFlags,
        context: KeyContext
    ) -> KeyCommand? {
        let flags = flags.intersection(.deviceIndependentFlagsMask)
        let command = flags.contains(.command)
        let control = flags.contains(.control)
        let option = flags.contains(.option)
        let shift = flags.contains(.shift)
        let key = characters.lowercased()

        if (command || control) && !option && !shift && key == "l" {
            return .focusPath
        }
        if (command || control) && !option && !shift && key == "f" {
            return .find
        }
        if keyCode == 99 && !command && !control && !option && !shift {
            return .find
        }
        if control && !command && !option && key == "z" {
            return .send(shift ? Selector(("redo:")) : Selector(("undo:")))
        }
        if context.textIsResponder {
            guard control && !command && !option else { return nil }
            switch key {
            case "c": return .send(#selector(NSText.copy(_:)))
            case "x": return .send(#selector(NSText.cut(_:)))
            case "v": return .send(#selector(NSText.paste(_:)))
            case "a": return .send(#selector(NSText.selectAll(_:)))
            default: return nil
            }
        }

        if control && !command && !option {
            switch key {
            case "c": return .copy
            case "x": return .cut
            case "v": return .paste
            case "a": return .selectAll
            case "n" where shift: return .newFolder
            default: break
            }
        }
        if control && option && !command && !shift && key == "n" {
            return .newTextFile
        }
        if control && shift && key == "." {
            return .toggleHidden
        }
        if option {
            switch keyCode {
            case 126: return .goUp
            case 123: return .goBack
            case 124: return .goForward
            default: break
            }
        }
        switch keyCode {
        case 96: return .copyToOther
        case 97: return .moveToOther
        case 120 where context.tableIsResponder: return .rename
        case 53: return .clearCut
        default: break
        }
        guard context.tableIsResponder else { return nil }
        let plain = !control && !option && !shift
        switch keyCode {
        case 51 where plain && !command: return .goBack
        case 51 where plain && command: return .trash
        case 117 where plain: return .trash
        case 36 where !command && !control && !option: return .open
        case 36 where option && !command && !control && !shift: return .info
        case 125 where command: return .open
        default: return nil
        }
    }
}

struct KeyContext: Equatable {
    var tableIsResponder: Bool
    var textIsResponder: Bool
}
