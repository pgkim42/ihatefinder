import Foundation
import Darwin
import CoreServices

/// Watches the folder and its parent so replacing a folder does not orphan the watch.
final class DirectoryObserver {
    private let url: URL
    private let queue = DispatchQueue(label: "IHateFinder.directory-observer", qos: .utility)
    private let onChange: () -> Void
    private var directorySource: DispatchSourceFileSystemObject?
    private var parentSource: DispatchSourceFileSystemObject?
    private var retryTimer: DispatchSourceTimer?
    private var notification: DispatchWorkItem?
    private var metadataWatch: DirectoryMetadataWatch?
    private let events: DispatchSource.FileSystemEvent = [.write, .extend, .attrib, .link, .rename, .delete, .revoke]

    init(url: URL, onChange: @escaping () -> Void) {
        self.url = url
        self.onChange = onChange
        queue.async { [weak self] in
            guard let self else { return }
            self.armDirectory()
            self.armParent()
            self.armMetadata()
            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now() + 1, repeating: 1)
            timer.setEventHandler { [weak self] in
                guard let self else { return }
                // Retry only invalidated/missing watches, never poll a healthy folder.
                if self.directorySource == nil || self.parentSource == nil || self.metadataWatch == nil {
                    self.armDirectory()
                    self.armParent()
                    self.armMetadata()
                    self.scheduleNotification()
                }
            }
            self.retryTimer = timer
            timer.resume()
            // Close the gap between the initial read and installing the watch.
            self.scheduleNotification()
        }
    }

    deinit {
        notification?.cancel()
        directorySource?.cancel()
        parentSource?.cancel()
        retryTimer?.cancel()
    }

    private func makeSource(at url: URL) -> DispatchSourceFileSystemObject? {
        let descriptor = open(url.path, O_EVTONLY | O_CLOEXEC)
        guard descriptor >= 0 else { return nil }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: events, queue: queue)
        source.setCancelHandler { close(descriptor) }
        return source
    }

    private func armDirectory() {
        guard directorySource == nil else { return }
        guard let source = makeSource(at: url) else { return }
        directorySource = source
        source.setEventHandler { [weak self] in
            guard let self, let events = self.directorySource?.data else { return }
            if !events.intersection([.rename, .delete, .revoke]).isEmpty {
                self.directorySource?.cancel()
                self.directorySource = nil
                self.armDirectory()
            }
            self.scheduleNotification()
        }
        source.resume()
    }

    private func armParent() {
        guard parentSource == nil else { return }
        guard let source = makeSource(at: url.deletingLastPathComponent()) else { return }
        parentSource = source
        source.setEventHandler { [weak self] in
            guard let self, let events = self.parentSource?.data else { return }
            if !events.intersection([.rename, .delete, .revoke]).isEmpty {
                self.parentSource?.cancel()
                self.parentSource = nil
                self.metadataWatch = nil
                self.armParent()
                self.armMetadata()
            }
            // A replacement can race the old inode's delete notification.
            self.directorySource?.cancel()
            self.directorySource = nil
            self.armDirectory()
            self.scheduleNotification()
        }
        source.resume()
    }

    private func armMetadata() {
        guard metadataWatch == nil else { return }
        metadataWatch = DirectoryMetadataWatch(url: url, queue: queue) { [weak self] in
            self?.scheduleNotification()
        }
    }

    private func scheduleNotification() {
        // A fixed coalescing window still delivers during continuous writes.
        guard notification == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.notification = nil
            DispatchQueue.main.async { [weak self] in self?.onChange() }
        }
        notification = work
        queue.asyncAfter(deadline: .now() + .milliseconds(150), execute: work)
    }
}

/// FSEvents reports writes to existing children that directory vnode events omit.
private final class DirectoryMetadataWatch {
    private let stream: FSEventStreamRef

    private final class Context {
        let path: String
        let onChange: () -> Void

        init(path: String, onChange: @escaping () -> Void) {
            self.path = path
            self.onChange = onChange
        }
    }

    init?(url: URL, queue: DispatchQueue, onChange: @escaping () -> Void) {
        guard let resolved = realpath(url.path, nil) else { return nil }
        defer { free(resolved) }
        // Foundation can shorten /private/var to /var; FSEvents reports real paths.
        let canonicalPath = String(cString: resolved)
        let context = Context(path: canonicalPath, onChange: onChange)
        defer { withExtendedLifetime(context) {} }
        var streamContext = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(context).toOpaque(),
            retain: { pointer in
                guard let pointer else { return nil }
                _ = Unmanaged<Context>.fromOpaque(pointer).retain()
                return pointer
            },
            release: { pointer in
                guard let pointer else { return }
                Unmanaged<Context>.fromOpaque(pointer).release()
            },
            copyDescription: nil
        )
        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes |
            kFSEventStreamCreateFlagWatchRoot | kFSEventStreamCreateFlagNoDefer
        )
        guard let stream = FSEventStreamCreate(
            nil,
            { _, info, count, rawPaths, eventFlags, _ in
                guard let info else { return }
                let context = Unmanaged<Context>.fromOpaque(info).takeUnretainedValue()
                let paths = unsafeBitCast(rawPaths, to: NSArray.self)
                let rescanFlags = FSEventStreamEventFlags(
                    kFSEventStreamEventFlagMustScanSubDirs | kFSEventStreamEventFlagRootChanged |
                    kFSEventStreamEventFlagUserDropped | kFSEventStreamEventFlagKernelDropped
                )
                for index in 0..<count {
                    let path = paths[index] as! String
                    if eventFlags[index] & rescanFlags != 0 || path == context.path ||
                        (path as NSString).deletingLastPathComponent == context.path {
                        context.onChange()
                        return
                    }
                }
            },
            &streamContext,
            [(canonicalPath as NSString).deletingLastPathComponent] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.15,
            flags
        ) else { return nil }
        FSEventStreamSetDispatchQueue(stream, queue)
        guard FSEventStreamStart(stream) else {
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            return nil
        }
        self.stream = stream
    }

    deinit {
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
    }
}
