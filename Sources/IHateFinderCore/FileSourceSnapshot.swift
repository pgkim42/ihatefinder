import Darwin
import Foundation

/// A fresh, no-follow metadata inventory of the item that is about to be copied.
/// Access times are deliberately excluded: reading the source may change them.
/// This is an optimistic check, not a filesystem snapshot or a lock on other writers.
struct FileSourceSnapshot: Equatable {
    private let entries: [String: Metadata]

    static func read(at source: URL, fileManager: FileManager,
                     cancellation: FileTransferCancellation? = nil) throws -> FileSourceSnapshot {
        var entries: [String: Metadata] = [:]
        var verifiedVolumes: Set<dev_t> = []

        func visit(_ url: URL, relativePath: String) throws {
            try cancellation?.check()
            let before = try Metadata.read(url)
            if verifiedVolumes.insert(before.device).inserted {
                // A link belongs to its containing volume, not its referent's volume.
                let volumeURL = before.isSymlink ? url.deletingLastPathComponent() : url
                guard FileID.volumeSupportsPersistentIDs(URL(fileURLWithPath: volumeURL.path)) else {
                    throw FileOpError("원본 디스크에서 안정적인 파일 식별 정보를 확인할 수 없습니다. 대신 복사를 사용하고, 복사본을 확인한 뒤 원본을 직접 정리하십시오.")
                }
            }
            entries[relativePath] = before
            if before.isDirectory {
                // Throw on enumeration errors; a partial inventory must never authorize deletion.
                let children = try fileManager.contentsOfDirectory(
                    at: url, includingPropertiesForKeys: nil, options: []
                )
                for child in children {
                    try visit(child, relativePath: relativePath + "/" + child.lastPathComponent)
                }
                guard try Metadata.read(url) == before else {
                    throw FileOpError("원본 폴더가 상태를 확인하는 동안 변경되었습니다.")
                }
            }
        }

        try visit(source, relativePath: "")
        return FileSourceSnapshot(entries: entries)
    }

    /// Compare actual ancestor identities, including case-insensitive aliases and
    /// symlinks in either path's parent components. A source link is copied as a link,
    /// so its referent is intentionally not treated as the source directory.
    static func contains(_ destination: URL, inside source: URL) throws -> Bool {
        let sourceInfo = try Metadata.read(source)
        guard sourceInfo.isDirectory else { return false }
        guard let resolved = realpath(destination.path, nil) else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        defer { free(resolved) }
        var ancestor = URL(fileURLWithPath: String(cString: resolved), isDirectory: true)
        while true {
            let info = try Metadata.read(ancestor)
            if info.device == sourceInfo.device && info.inode == sourceInfo.inode { return true }
            let parent = ancestor.deletingLastPathComponent()
            if parent.path == ancestor.path { return false }
            ancestor = parent
        }
    }

    private struct Metadata: Equatable {
        let device: dev_t
        let inode: ino_t
        let generation: UInt32
        let mode: mode_t
        let size: off_t
        let links: nlink_t
        let owner: uid_t
        let group: gid_t
        let flags: UInt32
        let modifiedSeconds: Int
        let modifiedNanoseconds: Int
        let changedSeconds: Int
        let changedNanoseconds: Int
        let bornSeconds: Int
        let bornNanoseconds: Int

        var isDirectory: Bool { mode & mode_t(S_IFMT) == mode_t(S_IFDIR) }
        var isSymlink: Bool { mode & mode_t(S_IFMT) == mode_t(S_IFLNK) }

        static func read(_ url: URL) throws -> Metadata {
            var info = stat()
            guard lstat(url.path, &info) == 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
            return Metadata(
                device: info.st_dev, inode: info.st_ino, generation: info.st_gen,
                mode: info.st_mode, size: info.st_size, links: info.st_nlink,
                owner: info.st_uid, group: info.st_gid, flags: info.st_flags,
                modifiedSeconds: info.st_mtimespec.tv_sec, modifiedNanoseconds: info.st_mtimespec.tv_nsec,
                changedSeconds: info.st_ctimespec.tv_sec, changedNanoseconds: info.st_ctimespec.tv_nsec,
                bornSeconds: info.st_birthtimespec.tv_sec, bornNanoseconds: info.st_birthtimespec.tv_nsec
            )
        }
    }
}
