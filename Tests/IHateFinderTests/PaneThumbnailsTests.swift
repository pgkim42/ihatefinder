import AppKit
import XCTest
@testable import IHateFinder

final class PaneThumbnailsTests: XCTestCase {
    @MainActor
    func testVisibleConsumersShareOneRequestAndThenUseCachedImage() throws {
        let thumbnails = PaneThumbnails()
        let url = URL(fileURLWithPath: "/tmp/thumbnail.png")
        var requests = 0
        var finish: ((NSImage?) -> Void)?
        thumbnails.generate = { requested, completion in
            XCTAssertEqual(requested, url)
            requests += 1
            finish = completion
            return {}
        }
        var received: [NSImage?] = []
        thumbnails.image(for: url) { received.append($0) }
        thumbnails.image(for: url) { received.append($0) }
        XCTAssertEqual(requests, 1)
        XCTAssertTrue(received.isEmpty)

        let image = NSImage(size: NSSize(width: 96, height: 96))
        try XCTUnwrap(finish)(image)
        thumbnails.image(for: url) { received.append($0) }
        XCTAssertEqual(requests, 1)
        XCTAssertEqual(received.count, 3)
        XCTAssertTrue(received.allSatisfy { $0 === image })
    }

    @MainActor
    func testInvalidationCancelsOldWorkAndRejectsItsLateImage() throws {
        let thumbnails = PaneThumbnails()
        let url = URL(fileURLWithPath: "/tmp/changed.png")
        var completions: [(NSImage?) -> Void] = []
        var cancellations = 0
        thumbnails.generate = { _, completion in
            completions.append(completion)
            return { cancellations += 1 }
        }
        var obsoleteDeliveries = 0
        var received: [NSImage?] = []
        thumbnails.image(for: url) { _ in obsoleteDeliveries += 1 }
        thumbnails.invalidate()
        XCTAssertEqual(cancellations, 1)
        thumbnails.image(for: url) { received.append($0) }
        XCTAssertEqual(completions.count, 2)

        completions[0](NSImage(size: NSSize(width: 10, height: 10)))
        XCTAssertEqual(obsoleteDeliveries, 0)
        XCTAssertTrue(received.isEmpty)
        let current = NSImage(size: NSSize(width: 96, height: 96))
        completions[1](current)
        thumbnails.image(for: url) { received.append($0) }
        XCTAssertEqual(received.count, 2)
        XCTAssertTrue(received.allSatisfy { $0 === current })
        XCTAssertEqual(completions.count, 2)
    }

    @MainActor
    func testRefreshDiscardsCompletedImageAndFailureCanBeRetried() {
        let thumbnails = PaneThumbnails()
        let url = URL(fileURLWithPath: "/tmp/updated.pdf")
        var completions: [(NSImage?) -> Void] = []
        thumbnails.generate = { _, completion in
            completions.append(completion)
            return {}
        }
        var received: [NSImage?] = []
        thumbnails.image(for: url) { received.append($0) }
        completions[0](NSImage(size: NSSize(width: 96, height: 96)))
        thumbnails.invalidate()
        thumbnails.image(for: url) { received.append($0) }
        XCTAssertEqual(completions.count, 2)
        completions[1](nil)
        XCTAssertNil(received.last!)
        thumbnails.image(for: url) { received.append($0) }
        XCTAssertEqual(completions.count, 3)
        let replacement = NSImage(size: NSSize(width: 80, height: 80))
        completions[2](replacement)
        XCTAssertTrue(received.last! === replacement)
    }

    @MainActor
    func testSynchronousCompletionDoesNotLeaveACancellationBehind() {
        let thumbnails = PaneThumbnails()
        var cancellations = 0
        thumbnails.generate = { _, completion in
            completion(NSImage(size: NSSize(width: 96, height: 96)))
            return { cancellations += 1 }
        }
        var deliveries = 0
        thumbnails.image(for: URL(fileURLWithPath: "/tmp/synchronous.png")) { _ in deliveries += 1 }
        thumbnails.invalidate()
        XCTAssertEqual(deliveries, 1)
        XCTAssertEqual(cancellations, 0)
    }

    @MainActor
    func testReleaseCancelsRequestsAndLateCompletionDoesNotRetainOwner() throws {
        var thumbnails: PaneThumbnails? = PaneThumbnails()
        var finish: ((NSImage?) -> Void)?
        var cancellations = 0
        var deliveries = 0
        thumbnails?.generate = { _, completion in
            finish = completion
            return { cancellations += 1 }
        }
        thumbnails?.image(for: URL(fileURLWithPath: "/tmp/pending.png")) { _ in deliveries += 1 }
        thumbnails = nil
        XCTAssertEqual(cancellations, 1, "Releasing the owner must deinitialize it and cancel its request")
        try XCTUnwrap(finish)(NSImage(size: NSSize(width: 96, height: 96)))
        XCTAssertEqual(deliveries, 0)
    }
}
