import XCTest
@testable import IHateFinderCore

final class DropPolicyTests: XCTestCase {
    private let full: DropMask = [.copy, .move, .generic]

    func testSameVolumeMovesAndDifferentVolumeCopiesWithFullMask() {
        XCTAssertEqual(DropPolicy.operation(allSourcesOnDestinationVolume: true, mask: full), .move)
        XCTAssertEqual(DropPolicy.operation(allSourcesOnDestinationVolume: false, mask: full), .copy)
    }

    func testMixedSourcesAreNotAllOnDestinationVolumeSoCopy() {
        // The caller passes false when any one source is on another volume.
        XCTAssertEqual(DropPolicy.operation(allSourcesOnDestinationVolume: false, mask: [.copy, .move]), .copy)
    }

    func testCopyOnlyMaskCopiesEvenOnSameVolume() {
        XCTAssertEqual(DropPolicy.operation(allSourcesOnDestinationVolume: true, mask: .copy), .copy)
        XCTAssertEqual(DropPolicy.operation(allSourcesOnDestinationVolume: false, mask: .copy), .copy)
    }

    func testGenericOnlyMovesAcrossVolumes() {
        XCTAssertEqual(DropPolicy.operation(allSourcesOnDestinationVolume: false, mask: .generic), .move)
        XCTAssertEqual(DropPolicy.operation(allSourcesOnDestinationVolume: true, mask: .generic), .move)
    }

    func testMoveOnlyMoves() {
        XCTAssertEqual(DropPolicy.operation(allSourcesOnDestinationVolume: false, mask: .move), .move)
    }

    func testEmptyMaskRefusesTheDrop() {
        XCTAssertNil(DropPolicy.operation(allSourcesOnDestinationVolume: true, mask: []))
        XCTAssertNil(DropPolicy.operation(allSourcesOnDestinationVolume: false, mask: []))
    }
}
