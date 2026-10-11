import AppKit
import QuickLookThumbnailing

/// The cache belongs to one committed listing and is discarded on refresh or mode change.
final class PaneThumbnails {
    typealias Generator = (URL, @escaping (NSImage?) -> Void) -> (() -> Void)
    var generate: Generator = { url, completion in
        let request = QLThumbnailGenerator.Request(fileAt: url, size: NSSize(width: 96, height: 96),
                                                   scale: NSScreen.main?.backingScaleFactor ?? 2,
                                                   representationTypes: .thumbnail)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
            DispatchQueue.main.async { completion(representation?.nsImage) }
        }
        return { QLThumbnailGenerator.shared.cancel(request) }
    }
    private(set) var generation = 0
    private let images = NSCache<NSURL, NSImage>()
    private var pending: [URL: [(NSImage?) -> Void]] = [:]
    private var cancellations: [URL: () -> Void] = [:]

    init() {
        images.countLimit = 128
    }

    func image(for url: URL, completion: @escaping (NSImage?) -> Void) {
        if let image = images.object(forKey: url as NSURL) { completion(image); return }
        if pending[url] != nil { pending[url]?.append(completion); return }
        pending[url] = [completion]
        let ticket = generation
        let cancel = generate(url) { [weak self] image in
            guard let self, self.generation == ticket else { return }
            if let image { self.images.setObject(image, forKey: url as NSURL) }
            let callbacks = self.pending.removeValue(forKey: url) ?? []
            self.cancellations.removeValue(forKey: url)
            callbacks.forEach { $0(image) }
        }
        if pending[url] != nil { cancellations[url] = cancel }
    }

    func invalidate() {
        generation += 1
        let cancel = Array(cancellations.values)
        cancellations.removeAll()
        pending.removeAll()
        images.removeAllObjects()
        cancel.forEach { $0() }
    }

    deinit { cancellations.values.forEach { $0() } }
}

final class PaneNameCell: NSTableCellView {
    var representedURL: URL?
    var imageWidth: NSLayoutConstraint?
    var imageHeight: NSLayoutConstraint?
}
