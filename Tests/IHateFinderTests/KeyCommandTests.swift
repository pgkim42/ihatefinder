import AppKit
import XCTest
@testable import IHateFinder

final class KeyCommandTests: XCTestCase {
    private let table = KeyContext(tableIsResponder: true, textIsResponder: false)
    private let text = KeyContext(tableIsResponder: false, textIsResponder: true)

    private func resolve(_ keyCode: UInt16, _ chars: String = "", _ flags: NSEvent.ModifierFlags = [], _ context: KeyContext) -> KeyCommand? {
        KeyCommand.resolve(keyCode: keyCode, characters: chars, flags: flags, context: context)
    }

    func testBareBackspaceOnTableGoesBackAndNeverTrashes() {
        XCTAssertEqual(resolve(51, "\u{7f}", [], table), .goBack)
    }

    func testCommandBackspaceAndForwardDeleteTrash() {
        XCTAssertEqual(resolve(51, "\u{7f}", .command, table), .trash)
        XCTAssertEqual(resolve(117, "\u{f728}", [.function], table), .trash)
        XCTAssertEqual(resolve(117, "\u{f728}", [.function, .command], table), .trash)
    }

    func testBackspaceAndDeleteInTextFieldPassThrough() {
        XCTAssertNil(resolve(51, "\u{7f}", [], text))
        XCTAssertNil(resolve(51, "\u{7f}", .command, text))
        XCTAssertNil(resolve(117, "\u{f728}", [.function], text))
    }

    func testBackspaceWithoutTableFocusDoesNothing() {
        let none = KeyContext(tableIsResponder: false, textIsResponder: false)
        XCTAssertNil(resolve(51, "\u{7f}", [], none))
        XCTAssertNil(resolve(117, "\u{f728}", [], none))
    }

    func testControlLettersInTextFieldBecomeFieldEditorActions() {
        XCTAssertEqual(resolve(8, "c", .control, text), .send(#selector(NSText.copy(_:))))
        XCTAssertEqual(resolve(7, "x", .control, text), .send(#selector(NSText.cut(_:))))
        XCTAssertEqual(resolve(9, "v", .control, text), .send(#selector(NSText.paste(_:))))
        XCTAssertEqual(resolve(0, "a", .control, text), .send(#selector(NSText.selectAll(_:))))
    }

    func testControlLettersOnTableKeepListActions() {
        XCTAssertEqual(resolve(8, "c", .control, table), .copy)
        XCTAssertEqual(resolve(7, "x", .control, table), .cut)
        XCTAssertEqual(resolve(9, "v", .control, table), .paste)
        XCTAssertEqual(resolve(0, "a", .control, table), .selectAll)
    }

    func testControlZAndShiftZAreSentThroughResponderChainInBothContexts() {
        for context in [table, text] {
            XCTAssertEqual(resolve(6, "z", .control, context), .send(#selector(FileTableView.undo(_:))))
            XCTAssertEqual(resolve(6, "z", [.control, .shift], context), .send(#selector(FileTableView.redo(_:))))
        }
    }

    func testCommandZIsLeftToTheMenu() {
        XCTAssertNil(resolve(6, "z", .command, table))
        XCTAssertNil(resolve(6, "z", .command, text))
        XCTAssertNil(resolve(6, "z", [.command, .shift], text))
    }

    func testFunctionKeysAreUnchanged() {
        XCTAssertEqual(resolve(96, "", [], table), .copyToOther)
        XCTAssertEqual(resolve(97, "", [], table), .moveToOther)
        XCTAssertNil(resolve(96, "", [], text))
    }

    func testPathShortcutWorksEvenFromTextField() {
        XCTAssertEqual(resolve(37, "l", .command, text), .focusPath)
        XCTAssertEqual(resolve(37, "l", .control, text), .focusPath)
        XCTAssertEqual(resolve(37, "l", .control, table), .focusPath)
    }

    func testOtherListShortcutsAreUnchanged() {
        XCTAssertEqual(resolve(123, "", .option, table), .goBack)
        XCTAssertEqual(resolve(124, "", .option, table), .goForward)
        XCTAssertEqual(resolve(126, "", .option, table), .goUp)
        XCTAssertEqual(resolve(120, "", [], table), .rename)
        XCTAssertEqual(resolve(36, "\r", [], table), .open)
        XCTAssertEqual(resolve(125, "", .command, table), .open)
        XCTAssertEqual(resolve(45, "n", [.control, .shift], table), .newFolder)
        XCTAssertEqual(resolve(45, "n", [.control, .option], table), .newTextFile)
        XCTAssertEqual(resolve(47, ".", [.control, .shift], table), .toggleHidden)
        XCTAssertEqual(resolve(53, "", [], table), .clearCut)
        XCTAssertNil(resolve(36, "\r", [], text))
    }

    func testFindShortcutsOpenFilterFromAnyContext() {
        for context in [table, text] {
            XCTAssertEqual(resolve(3, "f", .command, context), .find)
            XCTAssertEqual(resolve(3, "f", .control, context), .find)
            XCTAssertEqual(resolve(99, "", [], context), .find)
        }
        XCTAssertNil(resolve(3, "f", [.command, .shift], table))
        XCTAssertNil(resolve(99, "", .shift, table))
    }
}
