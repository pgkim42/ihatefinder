import AppKit
import XCTest
@testable import IHateFinder

final class FileClipboardTests: XCTestCase {
    @MainActor
    func testExternalFileURLsAreCopiesAndPreserveEscapedNames() async throws {
        try withClipboard { clipboard, pasteboard in
            let files = [URL(fileURLWithPath: "/tmp/a # 한글.txt"), URL(fileURLWithPath: "/tmp/folder", isDirectory: true)]
            pasteboard.clearContents()
            XCTAssertTrue(pasteboard.writeObjects(files.map { $0 as NSURL }))
            let snapshot = try XCTUnwrap(clipboard.snapshot())
            XCTAssertEqual(snapshot.urls, files)
            XCTAssertFalse(snapshot.isCut)
        }
    }

    @MainActor
    func testWrittenFilesAreReadableByExternalFileURLConsumer() async throws {
        try withClipboard { clipboard, pasteboard in
            let files = [URL(fileURLWithPath: "/tmp/a b.txt"), URL(fileURLWithPath: "/tmp/한글.txt")]
            XCTAssertTrue(clipboard.copy(files))
            let objects = try XCTUnwrap(pasteboard.readObjects(
                forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]
            ) as? [URL])
            XCTAssertEqual(objects, files)
            XCTAssertFalse(try XCTUnwrap(clipboard.snapshot()).isCut)
        }
    }

    @MainActor
    func testTextGenericURLsAndRemoteFileURLsAreNotFileOperations() async throws {
        withClipboard { clipboard, pasteboard in
            let representations: [(NSPasteboard.PasteboardType, String)] = [
                (.string, "/tmp/file.txt"),
                (.string, "file:///tmp/file.txt"),
                (.URL, "file:///tmp/file.txt"),
                (.fileURL, "https://example.com/file.txt"),
                (.fileURL, "file://remote.example/tmp/file.txt"),
                (.fileURL, "file:relative.txt"),
                (.fileURL, "file:///tmp/file.txt?query=not-a-file"),
                (.fileURL, "not a URL"),
            ]
            for (type, value) in representations {
                pasteboard.clearContents()
                pasteboard.setString(value, forType: type)
                XCTAssertNil(clipboard.snapshot(), "Must reject \(type.rawValue): \(value)")
            }
            let supported = NSPasteboardItem()
            supported.setString("file:///tmp/file.txt", forType: .fileURL)
            let unsupported = NSPasteboardItem()
            unsupported.setString("plain text", forType: .string)
            pasteboard.clearContents()
            pasteboard.writeObjects([supported, unsupported])
            XCTAssertNil(clipboard.snapshot(), "A mixed selection must not silently operate on a subset")
        }
    }

    @MainActor
    func testExternalReplacementInvalidatesCutEvenForSameFiles() async throws {
        try withClipboard { clipboard, pasteboard in
            let file = URL(fileURLWithPath: "/tmp/same.txt")
            XCTAssertTrue(clipboard.cut([file]))
            let old = try XCTUnwrap(clipboard.snapshot())
            pasteboard.clearContents()
            pasteboard.writeObjects([file as NSURL])
            XCTAssertFalse(clipboard.isCut(file))
            XCTAssertFalse(try XCTUnwrap(clipboard.snapshot()).isCut)
            clipboard.consume([file], from: old)
            XCTAssertEqual(clipboard.snapshot()?.urls, [file])
        }
    }

    @MainActor
    func testOldMoveCompletionDoesNotClearNewLocalCut() async throws {
        try withClipboard { clipboard, _ in
            let file = URL(fileURLWithPath: "/tmp/same.txt")
            XCTAssertTrue(clipboard.cut([file]))
            let old = try XCTUnwrap(clipboard.snapshot())
            XCTAssertTrue(clipboard.cut([file]))
            clipboard.consume([file], from: old)
            let current = try XCTUnwrap(clipboard.snapshot())
            XCTAssertEqual(current.urls, [file])
            XCTAssertTrue(current.isCut)
            clipboard.consume([file], from: current)
            XCTAssertNil(clipboard.snapshot())
            XCTAssertFalse(clipboard.isCut(file))
        }
    }

    @MainActor
    func testOldMoveCompletionDoesNotOverwriteExternalText() async throws {
        try withClipboard { clipboard, pasteboard in
            let file = URL(fileURLWithPath: "/tmp/old.txt")
            XCTAssertTrue(clipboard.cut([file]))
            let old = try XCTUnwrap(clipboard.snapshot())
            pasteboard.clearContents()
            pasteboard.setString("new text", forType: .string)
            clipboard.consume([file], from: old)
            XCTAssertEqual(pasteboard.string(forType: .string), "new text")
            XCTAssertNil(clipboard.snapshot())
            XCTAssertFalse(clipboard.isCut(file))
        }
    }

    @MainActor
    func testPartialMoveRetainsEveryUncompletedSourceAndInvalidatesOldSnapshot() async throws {
        try withClipboard { clipboard, _ in
            let files = ["completed", "skipped", "failed", "unprocessed"].map {
                URL(fileURLWithPath: "/tmp/\($0)")
            }
            XCTAssertTrue(clipboard.cut(files))
            let original = try XCTUnwrap(clipboard.snapshot())
            clipboard.consume([files[0]], from: original)
            let remaining = try XCTUnwrap(clipboard.snapshot())
            XCTAssertEqual(remaining.urls, Array(files.dropFirst()))
            XCTAssertTrue(remaining.isCut)
            XCTAssertFalse(clipboard.isCut(files[0]))
            XCTAssertTrue(clipboard.isCut(files[1]))
            XCTAssertEqual(original.urls, files, "The transfer's snapshot stays immutable")
            clipboard.consume(files, from: original)
            XCTAssertEqual(clipboard.snapshot()?.urls, remaining.urls)
            clipboard.consume(remaining.urls, from: remaining)
            XCTAssertNil(clipboard.snapshot())
        }
    }

    @MainActor
    func testDirectMoveOnlyConsumesMatchingCutSources() async throws {
        try withClipboard { clipboard, _ in
            let first = URL(fileURLWithPath: "/tmp/first")
            let second = URL(fileURLWithPath: "/tmp/second")
            let unrelated = URL(fileURLWithPath: "/tmp/unrelated")
            XCTAssertTrue(clipboard.cut([first, second]))
            let captured = try XCTUnwrap(clipboard.snapshot())
            clipboard.consume([unrelated], from: captured)
            XCTAssertEqual(clipboard.snapshot()?.urls, [first, second])
            clipboard.consume([first, unrelated], from: captured)
            XCTAssertEqual(clipboard.snapshot()?.urls, [second])
        }
    }

    @MainActor
    func testCancelCutPreservesCopyAndIgnoresPendingMoveCompletion() async throws {
        try withClipboard { clipboard, pasteboard in
            let file = URL(fileURLWithPath: "/tmp/cancelled.txt")
            XCTAssertTrue(clipboard.cut([file]))
            let old = try XCTUnwrap(clipboard.snapshot())
            let count = pasteboard.changeCount
            XCTAssertTrue(clipboard.cancelCut())
            XCTAssertFalse(clipboard.cancelCut())
            XCTAssertEqual(pasteboard.changeCount, count, "Escape does not replace system contents")
            XCTAssertFalse(clipboard.isCut(file))
            clipboard.consume([file], from: old)
            let copy = try XCTUnwrap(clipboard.snapshot())
            XCTAssertEqual(copy.urls, [file])
            XCTAssertFalse(copy.isCut)
            clipboard.consume([file], from: copy)
            XCTAssertEqual(clipboard.snapshot()?.urls, [file], "Copy can be pasted repeatedly")
        }
    }

    @MainActor
    func testRejectedWriteLeavesExistingClipboardAndCutIntentIntact() async throws {
        try withClipboard { clipboard, _ in
            let file = URL(fileURLWithPath: "/tmp/keep.txt")
            XCTAssertTrue(clipboard.cut([file]))
            XCTAssertFalse(clipboard.copy([URL(string: "https://example.com")!]))
            XCTAssertFalse(clipboard.cut([]))
            let snapshot = try XCTUnwrap(clipboard.snapshot())
            XCTAssertEqual(snapshot.urls, [file])
            XCTAssertTrue(snapshot.isCut)
        }
    }

    @MainActor
    private func withClipboard(_ body: (FileClipboard, NSPasteboard) throws -> Void) rethrows {
        let pasteboard = NSPasteboard(name: .init("IHateFinder.tests.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        try body(FileClipboard(pasteboard: pasteboard), pasteboard)
    }
}
