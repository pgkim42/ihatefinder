import XCTest
@testable import IHateFinderCore

final class TrashMessageTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("trashmsg-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: root)
    }

    private func file(_ name: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try Data(name.utf8).write(to: url)
        return url
    }

    private func report(failingWith error: Error) throws -> (FileTrashReport, [URL]) {
        let one = try file("one.txt")
        let two = try file("two.txt")
        let ops = FileOps(sameVolume: { _, _ in true }, moveToTrash: { url in
            if url.lastPathComponent == "two.txt" { throw error }
            return nil
        })
        return (ops.trash(urls: [one, two]), [one, two])
    }

    func testUnsupportedVolumeErrorAddsTheHint() throws {
        let (report, _) = try report(failingWith: CocoaError(.featureUnsupported))
        let message = try XCTUnwrap(report.failureMessage)
        XCTAssertTrue(message.contains("two.txt"))
        XCTAssertTrue(message.contains("아무것도 지우지 않았습니다"))
        XCTAssertTrue(message.contains("이 디스크는 휴지통을 지원하지 않을 수 있습니다."))
        XCTAssertTrue(message.contains("휴지통으로 보낸 항목 1개, 그대로 남은 항목 1개"))
    }

    func testReadOnlyVolumeErrorAddsTheHint() throws {
        let (report, _) = try report(failingWith: CocoaError(.fileWriteVolumeReadOnly))
        XCTAssertTrue(try XCTUnwrap(report.failureMessage).contains("휴지통을 지원하지 않을 수 있습니다"))
    }

    func testGenericErrorGivesSameMessageWithoutHint() throws {
        let (report, _) = try report(failingWith: FileOpError("거부됨"))
        let message = try XCTUnwrap(report.failureMessage)
        XCTAssertTrue(message.contains("two.txt"))
        XCTAssertTrue(message.contains("아무것도 지우지 않았습니다"))
        XCTAssertTrue(message.contains("거부됨"))
        XCTAssertFalse(message.contains("휴지통을 지원하지 않을 수 있습니다"))
    }

    func testUnrelatedCocoaErrorGetsNoHint() throws {
        let (report, _) = try report(failingWith: CocoaError(.fileWriteNoPermission))
        let message = try XCTUnwrap(report.failureMessage)
        XCTAssertTrue(message.contains("아무것도 지우지 않았습니다"))
        XCTAssertFalse(message.contains("휴지통을 지원하지 않을 수 있습니다"))
    }

    func testSuccessfulReportHasNoMessage() throws {
        let one = try file("ok.txt")
        let ops = FileOps(sameVolume: { _, _ in true }, moveToTrash: { _ in nil })
        XCTAssertNil(ops.trash(urls: [one]).failureMessage)
    }
}
