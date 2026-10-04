import Foundation

/// A started compression the caller can poll and stop. `ditto` in production; a fake in tests.
public struct CompressProcess {
    public var isRunning: () -> Bool
    public var terminate: () -> Void
    /// Valid once `isRunning` is false. Zero means success.
    public var exitStatus: () -> Int32
    /// What the tool reported on failure.
    public var errorOutput: () -> String

    public init(
        isRunning: @escaping () -> Bool,
        terminate: @escaping () -> Void,
        exitStatus: @escaping () -> Int32,
        errorOutput: @escaping () -> String
    ) {
        self.isRunning = isRunning
        self.terminate = terminate
        self.exitStatus = exitStatus
        self.errorOutput = errorOutput
    }
}

/// Starts compressing `source` into the zip file at `destination` and returns at once.
public typealias CompressRunner = (_ source: URL, _ destination: URL) throws -> CompressProcess

extension FileOpError {
    public static let compressCancelled = FileOpError("압축을 취소했습니다.")
}

extension FileOps {
    /// Zips one item next to itself as `이름.zip`, or `이름 (2).zip` and so on; never overwrites.
    /// The archive is built in a hidden stage in the same folder and published by a move that
    /// refuses to replace anything. The stage is always removed, so a cancelled or failed run
    /// leaves nothing behind.
    public func compress(
        _ item: URL,
        cancellation: FileTransferCancellation? = nil,
        runner: CompressRunner = FileOps.dittoRunner
    ) -> Result<URL, FileOpError> {
        guard itemExists(item) else { return .failure(FileOpError("원본 항목이 없습니다.")) }
        let directory = item.deletingLastPathComponent()
        let baseName = item.lastPathComponent
        let stage = directory.appendingPathComponent(".ihatefinder-transfer-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: stage) }
        do {
            try fm.createDirectory(at: stage, withIntermediateDirectories: false)
        } catch {
            return .failure(FileOpError("압축할 임시 폴더를 만들지 못했습니다. \(error.localizedDescription)"))
        }
        let staged = stage.appendingPathComponent("\(baseName).zip")
        let process: CompressProcess
        do {
            process = try runner(item, staged)
        } catch {
            return .failure(FileOpError("압축을 시작하지 못했습니다. \(error.localizedDescription)"))
        }
        var cancelled = false
        while process.isRunning() {
            if cancellation?.isCancelled == true {
                cancelled = true
                process.terminate()
                while process.isRunning() { Thread.sleep(forTimeInterval: 0.005) }
                break
            }
            Thread.sleep(forTimeInterval: 0.02)
        }
        if cancelled || cancellation?.isCancelled == true {
            return .failure(.compressCancelled)
        }
        guard process.exitStatus() == 0 else {
            let detail = process.errorOutput().trimmingCharacters(in: .whitespacesAndNewlines)
            return .failure(FileOpError("‘\(baseName)’을(를) 압축하지 못했습니다.\(detail.isEmpty ? "" : " (\(detail))")"))
        }
        guard itemExists(staged) else {
            return .failure(FileOpError("‘\(baseName)’을(를) 압축하지 못했습니다. 압축 파일이 만들어지지 않았습니다."))
        }
        var number = 1
        while true {
            let name = number == 1 ? "\(baseName).zip" : "\(baseName) (\(number)).zip"
            let target = directory.appendingPathComponent(name)
            // moveItem refuses to replace, so a name taken in the meantime just moves on to the next number.
            if !itemExists(target) {
                do {
                    try fm.moveItem(at: staged, to: target)
                    return .success(target)
                } catch let error as CocoaError where error.code == .fileWriteFileExists {
                    // taken since the check
                } catch {
                    return .failure(FileOpError("압축 파일을 옮기지 못했습니다. \(error.localizedDescription)"))
                }
            }
            number += 1
        }
    }

    /// The undo record for a finished compression: undo sends the zip to the Trash.
    public func undoRecord(compressed zip: URL) -> UndoRecord {
        UndoRecord(title: "압축", items: [.created(zip, id: fileIdentity(zip))])
    }

    /// Runs `/usr/bin/ditto -c -k --sequesterRsrc --keepParent`.
    public static let dittoRunner: CompressRunner = { source, destination in
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", source.path, destination.path]
        let errorFile = destination.deletingLastPathComponent().appendingPathComponent("ditto-errors.txt")
        FileManager.default.createFile(atPath: errorFile.path, contents: nil)
        let handle = try FileHandle(forWritingTo: errorFile)
        process.standardError = handle
        process.standardOutput = FileHandle.nullDevice
        process.terminationHandler = { _ in try? handle.close() }
        try process.run()
        return CompressProcess(
            isRunning: { process.isRunning },
            terminate: { process.terminate() },
            exitStatus: { process.terminationStatus },
            errorOutput: { (try? String(contentsOf: errorFile, encoding: .utf8)) ?? "" }
        )
    }
}
