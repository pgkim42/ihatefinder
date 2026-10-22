import Darwin
import XCTest
@testable import IHateFinderCore

final class NativeFileCopyAppleDoubleTests: XCTestCase {
    private let fm = FileManager.default
    private var root: URL!

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: "/tmp/ihf-appledouble-tests-\(UUID())", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try fm.removeItem(at: root)
    }

    func testDotUnderscoreUserFilesDirectoriesAndLinksAreCopied() throws {
        let source = try directory("source", in: root)
        try Data("owner".utf8).write(to: source.appendingPathComponent("ordinary"))
        try Data("user data".utf8).write(to: source.appendingPathComponent("._ordinary"))
        let folder = try directory("._folder", in: source)
        try Data("nested".utf8).write(to: folder.appendingPathComponent("file"))
        try fm.createSymbolicLink(atPath: source.appendingPathComponent("._link").path,
                                  withDestinationPath: "missing")
        for clone in [false, true] {
            let target = root.appendingPathComponent("copy-\(clone)")
            let copy = clone ? NativeFileCopy.cloneCopy : NativeFileCopy.copy
            try copy(source, target, nil) { _ in }
            XCTAssertEqual(try Data(contentsOf: target.appendingPathComponent("._ordinary")), Data("user data".utf8))
            XCTAssertEqual(try Data(contentsOf: target.appendingPathComponent("._folder/file")), Data("nested".utf8))
            XCTAssertEqual(try fm.destinationOfSymbolicLink(atPath: target.appendingPathComponent("._link").path), "missing")
        }
    }

    func testAppleDoubleArchiveOnNativeFileSystemIsAnOrdinaryFile() throws {
        let source = try directory("source", in: root)
        let owner = source.appendingPathComponent("owner")
        try Data("contents".utf8).write(to: owner)
        try setAttribute(owner)
        let archive = source.appendingPathComponent("._owner")
        XCTAssertEqual(copyfile(owner.path, archive.path, nil,
                                copyfile_flags_t(COPYFILE_PACK | COPYFILE_METADATA | COPYFILE_EXCL)), 0)
        let original = try Data(contentsOf: archive)
        for clone in [false, true] {
            let target = root.appendingPathComponent("copy-\(clone)")
            let copy = clone ? NativeFileCopy.cloneCopy : NativeFileCopy.copy
            try copy(source, target, nil) { _ in }
            XCTAssertEqual(try Data(contentsOf: target.appendingPathComponent("._owner")), original)
            try assertAttribute(target.appendingPathComponent("owner"))
        }
    }

    // Opt in to disposable disk images; no user-mounted or physical disk is used.
    // IHF_TEST_FAT_COPY=1 swift test --filter NativeFileCopyAppleDoubleTests
    func testExFATDiskImageCopyAndCancellation() throws {
        try withDiskImage(fileSystem: "ExFAT", exerciseCopyAndCancellation)
    }

    func testFAT32DiskImageCopyAndCancellation() throws {
        try withDiskImage(fileSystem: "MS-DOS FAT32", exerciseCopyAndCancellation)
    }

    func testExFATCompatibleAppleDoubleVariantsPreserveMetadata() throws {
        try withDiskImage(fileSystem: "ExFAT", exerciseCompatibleAppleDoubleVariants)
    }

    func testFAT32CompatibleAppleDoubleVariantsPreserveMetadata() throws {
        try withDiskImage(fileSystem: "MS-DOS FAT32", exerciseCompatibleAppleDoubleVariants)
    }

    private func withDiskImage(fileSystem: String, _ exercise: (URL) throws -> Void) throws {
        guard ProcessInfo.processInfo.environment["IHF_TEST_FAT_COPY"] == "1" else {
            throw XCTSkip("Set IHF_TEST_FAT_COPY=1 to exercise disposable FAT disk images")
        }
        let image = root.appendingPathComponent("volume.dmg")
        let volume = try directory("volume", in: root)
        try hdiutil(["create", "-size", "96m", "-fs", fileSystem, "-volname", "IHFCOPY", image.path])
        try hdiutil(["attach", "-nobrowse", "-mountpoint", volume.path, image.path])
        defer {
            do { try hdiutil(["detach", volume.path]) }
            catch { XCTFail("Failed to detach test image \(image.path): \(error)") }
        }
        try exercise(volume)
    }

    private func exerciseCopyAndCancellation(_ volume: URL) throws {
        let empty = try directory("empty", in: volume)
        let files = try directory("files", in: volume)
        let file = files.appendingPathComponent("file")
        let contents = Data(repeating: 0x5a, count: 8 * 1024 * 1024)
        try contents.write(to: file)
        try setAttribute(file)
        // FAT's xattr setter rejects resource forks shorter than its 286-byte
        // empty-fork header, so use a nonempty payload larger than that header.
        let resourceFork = [UInt8](repeating: 0x72, count: 512)
        try setAttribute(file, name: "com.apple.ResourceFork", value: resourceFork)
        let tree = try directory("tree", in: volume)
        let child = try directory("child", in: tree)
        try setAttribute(child)
        let leaf = child.appendingPathComponent("leaf")
        try Data("nested payload".utf8).write(to: leaf)
        try setAttribute(leaf)
        let date = Date(timeIntervalSince1970: 1_600_000_000)
        try fm.setAttributes([.modificationDate: date], ofItemAtPath: child.path)
        // Real AppleDouble bytes, but without an owning item: preserve the orphan.
        let orphan = tree.appendingPathComponent("._orphan")
        let sidecar = files.appendingPathComponent("._file")
        let archive = try Data(contentsOf: sidecar)
        try archive.write(to: orphan)
        try Data("user data".utf8).write(to: tree.appendingPathComponent("._notes"))

        for clone in [false, true] {
            let copy = clone ? NativeFileCopy.cloneCopy : NativeFileCopy.copy
            for source in [empty, files, tree] {
                let target = volume.appendingPathComponent("\(source.lastPathComponent)-\(clone)")
                var intermediate = false
                var complete = false
                try copy(source, target, nil) { progress in
                    if progress.file == file, let total = progress.totalBytes {
                        intermediate = intermediate || (progress.bytesCopied > 0 && progress.bytesCopied < total)
                        complete = complete || progress.bytesCopied == total
                    }
                }
                if source == files {
                    XCTAssertTrue(intermediate, "FAT clone fallback must retain byte callbacks")
                    XCTAssertTrue(complete)
                    XCTAssertEqual(try Data(contentsOf: target.appendingPathComponent("file")), contents)
                    try assertAttribute(target.appendingPathComponent("file"))
                    try assertAttribute(target.appendingPathComponent("file"), name: "com.apple.ResourceFork", expected: resourceFork)
                } else if source == tree {
                    try assertAttribute(target.appendingPathComponent("child"))
                    try assertAttribute(target.appendingPathComponent("child/leaf"))
                    XCTAssertEqual(try Data(contentsOf: target.appendingPathComponent("child/leaf")), Data("nested payload".utf8))
                    XCTAssertEqual(try fm.attributesOfItem(atPath: target.appendingPathComponent("child").path)[.modificationDate] as? Date, date)
                    XCTAssertEqual(try Data(contentsOf: target.appendingPathComponent("._orphan")), archive)
                    XCTAssertEqual(try Data(contentsOf: target.appendingPathComponent("._notes")), Data("user data".utf8))
                } else {
                    XCTAssertEqual(try fm.contentsOfDirectory(atPath: target.path), [])
                }
            }
        }

        // Direct selection of a real sidecar still copies its bytes.
        let selected = volume.appendingPathComponent("selected-sidecar")
        try NativeFileCopy.copy(sidecar, selected, nil) { _ in }
        XCTAssertEqual(try Data(contentsOf: selected), archive)

        // Both cross-volume directions retain the owning item's data and xattrs.
        let returned = root.appendingPathComponent("returned")
        try NativeFileCopy.copy(files, returned, nil) { _ in }
        let exported = volume.appendingPathComponent("exported")
        try NativeFileCopy.copy(returned, exported, nil) { _ in }
        for target in [returned, exported] {
            XCTAssertEqual(try Data(contentsOf: target.appendingPathComponent("file")), contents)
            try assertAttribute(target.appendingPathComponent("file"))
            try assertAttribute(target.appendingPathComponent("file"), name: "com.apple.ResourceFork", expected: resourceFork)
        }

        for clone in [false, true] {
            let destination = try directory("cancel-\(clone)", in: volume)
            let old = try directory("files", in: destination)
            try Data("old target".utf8).write(to: old.appendingPathComponent("keep"))
            let cancellation = FileTransferCancellation()
            var cancelledInData = false
            var trashCalls = 0
            let ops = FileOps(trash: { _ in trashCalls += 1 }, cloneOnSameVolume: clone)
            let report = ops.transfer(
                urls: [files], to: destination, moving: false, resolve: { _ in .replace },
                cancellation: cancellation, progressInterval: 0
            ) { progress in
                if let total = progress.totalBytes, progress.bytesCopied > 0, progress.bytesCopied < total {
                    cancelledInData = true
                    cancellation.cancel()
                }
            }
            XCTAssertTrue(cancelledInData)
            XCTAssertEqual(report.items.map(\.status), [.cancelled])
            XCTAssertEqual(trashCalls, 0)
            XCTAssertEqual(try Data(contentsOf: file), contents)
            XCTAssertEqual(try Data(contentsOf: old.appendingPathComponent("keep")), Data("old target".utf8))
            XCTAssertEqual(try fm.contentsOfDirectory(atPath: destination.path), ["files"])
        }
    }

    private func exerciseCompatibleAppleDoubleVariants(_ volume: URL) throws {
        let seed = try directory("seed", in: volume)
        let owner = seed.appendingPathComponent("owner")
        let contents = Data("owner contents".utf8)
        try contents.write(to: owner)
        // Also exercise a sidecar larger than the initial 4 KiB allocation.
        let custom = [UInt8](repeating: 0x61, count: 6000)
        let resourceFork = [UInt8](repeating: 0x72, count: 512)
        let finderInfo = Array("TEXTttxt".utf8) + [UInt8](repeating: 0, count: 24)
        try setAttribute(owner, value: custom)
        try setAttribute(owner, name: "com.apple.ResourceFork", value: resourceFork)
        try setAttribute(owner, name: "com.apple.FinderInfo", value: finderInfo)
        let original = try Data(contentsOf: seed.appendingPathComponent("._owner"))
        let resourceOffset = original[42..<46].reduce(0) { ($0 << 8) | Int($1) }
        XCTAssertGreaterThan(original.count, 4096)

        var variants: [(String, Data)] = []
        var bytes = original
        bytes.replaceSubrange(8..<24, with: "Netatalk        ".utf8)
        variants.append(("netatalk", bytes))
        bytes = original
        bytes.replaceSubrange(8..<24, with: [UInt8](repeating: 0, count: 16))
        variants.append(("zero-filler", bytes))
        bytes = original.prefix(resourceOffset)
        bytes[25] = 1
        bytes.replaceSubrange(38..<50, with: [UInt8](repeating: 0, count: 12))
        variants.append(("one-entry", bytes))
        bytes = original
        bytes.insert(contentsOf: [UInt8](repeating: 0x67, count: 16), at: resourceOffset)
        var shiftedOffset = UInt32(resourceOffset + 16).bigEndian
        withUnsafeBytes(of: &shiftedOffset) { bytes.replaceSubrange(42..<46, with: $0) }
        variants.append(("resource-gap", bytes))
        variants.append(("trailing-bytes", original + Data(repeating: 0xee, count: 64)))

        for (name, archive) in variants {
            let source = try directory(name, in: volume)
            let file = source.appendingPathComponent("owner")
            try contents.write(to: file)
            let sidecar = source.appendingPathComponent("._owner")
            try archive.write(to: sidecar)
            let expected = try attributes(file)
            XCTAssertEqual(expected["com.ihatefinder.appledouble-test"], Data(custom), name)
            XCTAssertEqual(expected["com.apple.FinderInfo"], Data(finderInfo), name)
            XCTAssertEqual(expected["com.apple.ResourceFork"], name == "one-entry" ? nil : Data(resourceFork), name)

            var expectedCopy = expected
            if name == "trailing-bytes" {
                // macOS copies the named fork through EOF, including the tail,
                // although source getxattr reports only its declared length.
                expectedCopy["com.apple.ResourceFork"] = Data(resourceFork) + Data(repeating: 0xee, count: 64)
            }
            let baseline = volume.appendingPathComponent("\(name)-filemanager")
            try fm.copyItem(at: source, to: baseline)
            XCTAssertEqual(try attributes(baseline.appendingPathComponent("owner")), expectedCopy, name)
            for clone in [false, true] {
                let destination = try directory("\(name)-\(clone)", in: volume)
                let report = FileOps(cloneOnSameVolume: clone).transfer(
                    urls: [source], to: destination, moving: false, resolve: { _ in .replace }
                )
                XCTAssertEqual(report.items.map(\.status), [.completed], "\(name), clone=\(clone)")
                let copied = destination.appendingPathComponent(name).appendingPathComponent("owner")
                if report.items.first?.status == .completed {
                    XCTAssertEqual(try Data(contentsOf: copied), contents, name)
                    XCTAssertEqual(try attributes(copied), expectedCopy, name)
                }
            }

            // An explicitly selected or orphaned variant remains a byte copy,
            // including filler, gap and trailing bytes not exposed as metadata.
            let selected = volume.appendingPathComponent("\(name)-selected")
            try NativeFileCopy.copy(sidecar, selected, nil) { _ in }
            XCTAssertEqual(try Data(contentsOf: selected), archive, name)
            let orphanSource = try directory("\(name)-orphan", in: volume)
            try archive.write(to: orphanSource.appendingPathComponent("._absent"))
            let orphanCopy = volume.appendingPathComponent("\(name)-orphan-copy")
            try NativeFileCopy.copy(orphanSource, orphanCopy, nil) { _ in }
            XCTAssertEqual(try Data(contentsOf: orphanCopy.appendingPathComponent("._absent")), archive, name)
        }
    }

    private func attributes(_ file: URL) throws -> [String: Data] {
        let size = listxattr(file.path, nil, 0, XATTR_NOFOLLOW)
        guard size >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        var names = [UInt8](repeating: 0, count: size)
        let count = names.withUnsafeMutableBytes {
            listxattr(file.path, $0.baseAddress?.assumingMemoryBound(to: CChar.self), $0.count, XATTR_NOFOLLOW)
        }
        guard count == size else { throw POSIXError(.EIO) }
        var attributes: [String: Data] = [:]
        for bytes in names.split(separator: 0) {
            let name = String(decoding: bytes, as: UTF8.self)
            let length = getxattr(file.path, name, nil, 0, 0, XATTR_NOFOLLOW)
            guard length >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
            var value = Data(count: length)
            let received = value.withUnsafeMutableBytes {
                getxattr(file.path, name, $0.baseAddress, $0.count, 0, XATTR_NOFOLLOW)
            }
            guard received == length else { throw POSIXError(.EIO) }
            attributes[name] = value
        }
        return attributes
    }

    private func directory(_ name: String, in parent: URL) throws -> URL {
        let directory = parent.appendingPathComponent(name, isDirectory: true)
        try fm.createDirectory(at: directory, withIntermediateDirectories: false)
        return directory
    }

    private func setAttribute(_ file: URL, name: String = "com.ihatefinder.appledouble-test",
                              value: [UInt8] = Array("metadata payload".utf8)) throws {
        let result = value.withUnsafeBytes {
            setxattr(file.path, name, $0.baseAddress, $0.count, 0, XATTR_NOFOLLOW)
        }
        if result != 0 { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    }

    private func assertAttribute(_ file: URL, name: String = "com.ihatefinder.appledouble-test",
                                 expected: [UInt8] = Array("metadata payload".utf8)) throws {
        var value = [UInt8](repeating: 0, count: expected.count)
        let size = value.withUnsafeMutableBytes {
            getxattr(file.path, name, $0.baseAddress, $0.count, 0, XATTR_NOFOLLOW)
        }
        XCTAssertEqual(size, expected.count)
        XCTAssertEqual(value, expected)
    }

    private func hdiutil(_ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "DiskImageTest", code: Int(process.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: String(decoding: data, as: UTF8.self)])
        }
    }
}
