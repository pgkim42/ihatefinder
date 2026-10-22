import Darwin
import Foundation

public final class FileTransferCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    public init() {}

    public var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    public func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    func check() throws {
        if isCancelled { throw TransferCancelled() }
    }
}

public struct FileTransferProgress: Sendable {
    public enum Operation: Equatable, Sendable { case copy, move }
    public enum Phase: Equatable, Sendable { case preparing, copying, committing, finished }

    public let operation: Operation
    public let phase: Phase
    public let source: URL
    public let currentFile: URL
    public let processedItems: Int
    public let totalItems: Int
    /// Data bytes for currentFile, not an aggregate directory or batch percentage.
    public let bytesCopied: Int64
    /// Nil for directory traversal, metadata, conflict resolution, and commit.
    public let totalBytes: Int64?
}

struct TransferCancelled: LocalizedError {
    var errorDescription: String? { "작업을 취소했습니다." }
}

struct FileCopyProgress {
    let file: URL
    let bytesCopied: Int64
    let totalBytes: Int64?
}

typealias FileCopyOperation = (
    URL, URL, FileTransferCancellation?, @escaping (FileCopyProgress) -> Void
) throws -> Void

/// Used only on the transfer worker. Cancellation checks are never throttled.
final class TransferProgressEmitter {
    let source: URL
    let index: Int
    let total: Int
    let moving: Bool
    let interval: TimeInterval
    let callback: ((FileTransferProgress) -> Void)?
    private var lastTime = -Double.infinity
    private var lastPhase: FileTransferProgress.Phase?
    private var lastFile: URL?
    private var lastDeterminate = false

    init(source: URL, index: Int, total: Int, moving: Bool, interval: TimeInterval,
         callback: ((FileTransferProgress) -> Void)?) {
        self.source = source
        self.index = index
        self.total = total
        self.moving = moving
        self.interval = max(0, interval)
        self.callback = callback
    }

    func emit(_ phase: FileTransferProgress.Phase, copy: FileCopyProgress? = nil) {
        guard let callback else { return }
        let file = copy?.file ?? source
        let determinate = copy?.totalBytes != nil
        let now = ProcessInfo.processInfo.systemUptime
        let finalBytes = copy?.totalBytes.map { copy?.bytesCopied == $0 } ?? false
        guard phase != lastPhase || file != lastFile || determinate != lastDeterminate
                || finalBytes || now - lastTime >= interval else { return }
        lastTime = now
        lastPhase = phase
        lastFile = file
        lastDeterminate = determinate
        callback(FileTransferProgress(
            operation: moving ? .move : .copy, phase: phase, source: source,
            currentFile: file, processedItems: phase == .finished ? index + 1 : index,
            totalItems: total, bytesCopied: copy?.bytesCopied ?? 0, totalBytes: copy?.totalBytes
        ))
    }
}

/// COPYFILE_ALL retains ACLs, extended attributes and stat metadata. NOFOLLOW
/// preserves symbolic links, including dangling links, rather than their targets.
/// `copy` uses no clone flag: data callbacks allow cancellation inside a single large
/// file. `cloneCopy` adds COPYFILE_CLONE for same-volume copies: APFS clones the item
/// at once (no byte progress, not interruptible), and other filesystems fall back to
/// the data copy. Both check cancellation before starting and after finishing.
enum NativeFileCopy {
    private final class Context {
        let cancellation: FileTransferCancellation?
        let progress: (FileCopyProgress) -> Void
        let rootPath: String
        var file: URL
        var path: String
        var total: Int64?

        init(source: URL, cancellation: FileTransferCancellation?,
             progress: @escaping (FileCopyProgress) -> Void) {
            self.file = source
            self.path = source.path
            self.rootPath = source.path
            self.cancellation = cancellation
            self.progress = progress
        }
    }

    private static let callback: copyfile_callback_t = { what, stage, state, source, _, opaque in
        guard let opaque else { return COPYFILE_QUIT }
        let context = Unmanaged<Context>.fromOpaque(opaque).takeUnretainedValue()
        if context.cancellation?.isCancelled == true { return COPYFILE_QUIT }
        // Let copyfile propagate the original filesystem error; never skip it.
        if stage == COPYFILE_ERR || what == COPYFILE_RECURSE_ERROR { return COPYFILE_QUIT }
        if let source, context.path.withCString({ strcmp(source, $0) != 0 }) {
            context.path = String(cString: source)
            context.file = URL(fileURLWithPath: context.path)
            context.total = nil
        }
        // FAT exposes its AppleDouble xattr storage to copyfile's raw traversal.
        // COPYFILE_ALL already copies that metadata with the owning item; copying
        // the sidecar again collides with the newly generated destination sidecar.
        // An explicitly selected sidecar remains an ordinary file copy.
        if what == COPYFILE_RECURSE_FILE, stage == COPYFILE_START,
           context.path != context.rootPath, isFATAppleDouble(context.file) {
            return context.cancellation?.isCancelled == true ? COPYFILE_QUIT : COPYFILE_SKIP
        }
        if what == COPYFILE_COPY_DATA {
            if stage == COPYFILE_START || context.total == nil {
                var info = stat()
                if lstat(context.path, &info) == 0,
                   (info.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG) {
                    context.total = Int64(info.st_size)
                }
            }
            var copied: off_t = 0
            if let state { _ = copyfile_state_get(state, UInt32(COPYFILE_STATE_COPIED), &copied) }
            context.progress(FileCopyProgress(
                file: context.file, bytesCopied: Int64(copied), totalBytes: context.total
            ))
        } else {
            context.progress(FileCopyProgress(file: context.file, bytesCopied: 0, totalBytes: nil))
        }
        // A consumer can request cancellation from the progress callback itself.
        return context.cancellation?.isCancelled == true ? COPYFILE_QUIT : COPYFILE_CONTINUE
    }

    static func copy(_ source: URL, _ destination: URL, _ cancellation: FileTransferCancellation?,
                     _ progress: @escaping (FileCopyProgress) -> Void) throws {
        try perform(source, destination, cancellation, progress, clone: false)
    }

    static func cloneCopy(_ source: URL, _ destination: URL, _ cancellation: FileTransferCancellation?,
                          _ progress: @escaping (FileCopyProgress) -> Void) throws {
        try perform(source, destination, cancellation, progress, clone: true)
    }

    private static func isFATAppleDouble(_ file: URL) -> Bool {
        let name = file.lastPathComponent
        guard name.hasPrefix("._"), name.count > 2 else { return false }
        let ownerName = String(name.dropFirst(2))
        guard ownerName != ".", ownerName != ".." else { return false }
        // Fail closed on unreadable, non-regular, orphaned or malformed files.
        // In particular, never discard arbitrary user files named ._something.
        let descriptor = open(file.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
        guard descriptor >= 0 else { return false }
        defer { close(descriptor) }
        var info = stat()
        var volume = statfs()
        guard fstat(descriptor, &info) == 0,
              info.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG),
              fstatfs(descriptor, &volume) == 0 else { return false }
        let fileSystem = withUnsafePointer(to: &volume.f_fstypename) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MFSTYPENAMELEN)) { String(cString: $0) }
        }
        guard fileSystem == "exfat" || fileSystem == "msdos" else { return false }
        var owner = stat()
        let ownerPath = file.deletingLastPathComponent().appendingPathComponent(ownerName).path
        guard lstat(ownerPath, &owner) == 0,
              [mode_t(S_IFREG), mode_t(S_IFDIR)].contains(owner.st_mode & mode_t(S_IFMT)) else { return false }

        // macOS accepts v2 FinderInfo/xattrs with an optional resource fork.
        // Filler is not a signature; gaps and trailing bytes are permitted.
        // Keep bounds checks, and let COPYFILE_ALL copy the metadata as macOS
        // exposes it, including the named resource fork's bytes.
        var header = [UInt8](repeating: 0, count: 50)
        guard read(descriptor, &header, header.count) == header.count else { return false }
        func word(_ offset: Int) -> UInt64 {
            header[offset..<(offset + 4)].reduce(0) { ($0 << 8) | UInt64($1) }
        }
        guard word(0) == 0x00051607, word(4) == 0x00020000,
              header[24] == 0, (1...2).contains(header[25]),
              word(26) == 9, word(30) == 50, word(34) >= 32,
              50 + word(34) <= UInt64(info.st_size) else { return false }
        if header[25] == 2 {
            guard word(38) == 2, word(42) >= 50 + word(34),
                  word(42) + word(46) <= UInt64(info.st_size) else { return false }
        }
        return true
    }

    private static func perform(_ source: URL, _ destination: URL, _ cancellation: FileTransferCancellation?,
                                _ progress: @escaping (FileCopyProgress) -> Void, clone: Bool) throws {
        try cancellation?.check()
        guard let state = copyfile_state_alloc() else { throw POSIXError(.ENOMEM) }
        defer { copyfile_state_free(state) }
        let context = Context(source: source, cancellation: cancellation, progress: progress)
        let opaque = Unmanaged.passUnretained(context).toOpaque()
        let callbackPointer = unsafeBitCast(callback, to: UnsafeRawPointer.self)
        // Bound each data write so a large file remains cancellable between chunks.
        var blockSize: UInt32 = 1024 * 1024
        guard copyfile_state_set(state, UInt32(COPYFILE_STATE_STATUS_CB), callbackPointer) == 0,
              copyfile_state_set(state, UInt32(COPYFILE_STATE_STATUS_CTX), opaque) == 0,
              copyfile_state_set(state, UInt32(COPYFILE_STATE_BSIZE), &blockSize) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        var flags = copyfile_flags_t(COPYFILE_ALL | COPYFILE_RECURSIVE | COPYFILE_NOFOLLOW | COPYFILE_EXCL)
        if clone { flags |= copyfile_flags_t(COPYFILE_CLONE) }
        let result = withExtendedLifetime(context) {
            copyfile(source.path, destination.path, state, flags)
        }
        let code = errno
        try cancellation?.check()
        if result != 0 { throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO) }
    }
}
