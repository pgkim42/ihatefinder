import XCTest
@testable import IHateFinderCore

final class EntryFilterTests: XCTestCase {
    private func entries(_ names: [String]) -> [FileEntry] {
        names.map {
            FileEntry(url: URL(fileURLWithPath: "/tmp/f/\($0)"), name: $0, isDirectory: false,
                      size: 0, modified: .distantPast, kind: "파일", isHidden: false)
        }
    }

    private func names(_ query: String, in list: [String]) -> [String] {
        EntryFilter.filter(entries(list), query: query).map(\.name)
    }

    func testMatchingIsCaseInsensitive() {
        XCTAssertEqual(names("report", in: ["Report.PDF", "notes.txt"]), ["Report.PDF"])
    }

    func testKoreanSubstringMatches() {
        XCTAssertEqual(names("사진", in: ["여행 사진.heic", "문서.txt"]), ["여행 사진.heic"])
    }

    func testDiacriticsAreIgnored() {
        XCTAssertEqual(names("cafe", in: ["Café.txt", "tea.txt"]), ["Café.txt"])
        XCTAssertEqual(names("é", in: ["cafe.txt", "xyz.txt"]), ["cafe.txt"])
    }

    func testEmptyAndWhitespaceQueriesKeepEverything() {
        let all = ["a.txt", "b.txt"]
        XCTAssertEqual(names("", in: all), all)
        XCTAssertEqual(names("   ", in: all), all)
    }

    func testQueryIsTrimmed() {
        XCTAssertEqual(names("  a.t ", in: ["a.txt", "b.txt"]), ["a.txt"])
    }

    func testNoMatchGivesEmptyList() {
        XCTAssertEqual(names("zzz", in: ["a.txt"]), [])
    }
}
