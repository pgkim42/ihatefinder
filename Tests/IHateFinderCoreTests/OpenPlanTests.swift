import XCTest
@testable import IHateFinderCore

final class OpenPlanTests: XCTestCase {
    private func entry(_ name: String, dir: Bool = false) -> FileEntry {
        FileEntry(
            url: URL(fileURLWithPath: "/tmp/plan/\(name)"), name: name, isDirectory: dir,
            size: 0, modified: .distantPast, kind: dir ? "폴더" : "파일", isHidden: false
        )
    }

    func testEmptySelectionHasNoPlan() {
        XCTAssertNil(OpenPlan.make(entries: []))
    }

    func testFilesOnlyOpensAllWithoutConfirmation() {
        let files = [entry("a.txt"), entry("b.txt")]
        XCTAssertEqual(OpenPlan.make(entries: files), .openFiles(files.map(\.url), confirm: false))
    }

    func testSingleFolderNavigates() {
        let folder = entry("dir", dir: true)
        XCTAssertEqual(OpenPlan.make(entries: [folder]), .navigate(folder.url))
    }

    func testMultipleFoldersAreRefusedWithReason() {
        guard case .refuse(let message)? = OpenPlan.make(entries: [entry("a", dir: true), entry("b", dir: true)]) else {
            return XCTFail("expected refuse")
        }
        XCTAssertFalse(message.isEmpty)
    }

    func testMixedSelectionOpensFilesOnly() {
        let file = entry("a.txt")
        XCTAssertEqual(
            OpenPlan.make(entries: [entry("dir", dir: true), file, entry("other", dir: true)]),
            .openFiles([file.url], confirm: false)
        )
    }

    func testTwentyOneFilesNeedConfirmationButTwentyDoNot() {
        let twenty = (0..<20).map { entry("f\($0).txt") }
        XCTAssertEqual(OpenPlan.make(entries: twenty), .openFiles(twenty.map(\.url), confirm: false))
        let twentyOne = twenty + [entry("f20.txt")]
        XCTAssertEqual(OpenPlan.make(entries: twentyOne), .openFiles(twentyOne.map(\.url), confirm: true))
    }
}
