import XCTest
@testable import IHateFinderCore

final class RenameSelectionTests: XCTestCase {
    private func range(_ name: String, dir: Bool = false) -> NSRange {
        RenameSelection.range(name: name, isDirectory: dir)
    }

    func testFilesSelectStemOnly() {
        XCTAssertEqual(range("photo.jpg"), NSRange(location: 0, length: 5))
        XCTAssertEqual(range("archive.tar.gz"), NSRange(location: 0, length: 11))
    }

    func testDotfilesSelectWholeName() {
        XCTAssertEqual(range(".bashrc"), NSRange(location: 0, length: 7))
    }

    func testFoldersSelectWholeNameEvenWithDot() {
        XCTAssertEqual(range("folder a.b", dir: true), NSRange(location: 0, length: 10))
    }

    func testRangeIsUTF16ForKoreanNames() {
        XCTAssertEqual(range("사진.heic"), NSRange(location: 0, length: 2))
    }

    func testPackageSelectsStem() {
        XCTAssertEqual(range("Foo.app"), NSRange(location: 0, length: 3))
    }

    func testNameWithoutExtensionSelectsWholeName() {
        XCTAssertEqual(range("noext"), NSRange(location: 0, length: 5))
    }

    func testDotfileWithExtensionSelectsStem() {
        XCTAssertEqual(range(".config.bak"), NSRange(location: 0, length: 7))
    }
}
