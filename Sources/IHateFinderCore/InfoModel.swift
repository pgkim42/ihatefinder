import Foundation

/// What the info sheet shows for one item.
public struct InfoModel: Equatable {
    public var name: String
    public var kind: String
    public var isDirectory: Bool
    /// Bytes for a file; nil for a folder or package.
    public var size: Int64?
    /// Items directly inside a folder; nil for files.
    public var itemCount: Int?
    public var created: Date?
    public var modified: Date?
    public var path: String
    /// `rwxr-xr-x (755)`.
    public var permissions: String

    public init(
        name: String, kind: String, isDirectory: Bool, size: Int64?, itemCount: Int?,
        created: Date?, modified: Date?, path: String, permissions: String
    ) {
        self.name = name
        self.kind = kind
        self.isDirectory = isDirectory
        self.size = size
        self.itemCount = itemCount
        self.created = created
        self.modified = modified
        self.path = path
        self.permissions = permissions
    }

    /// Counting a folder lists it, so call with `countItems: true` off the main thread.
    public static func make(url: URL, fileManager fm: FileManager = .default, countItems: Bool = true) -> InfoModel? {
        let keys: Set<URLResourceKey> = [
            .nameKey, .isDirectoryKey, .isPackageKey, .fileSizeKey,
            .creationDateKey, .contentModificationDateKey, .localizedTypeDescriptionKey,
        ]
        guard let values = try? url.resourceValues(forKeys: keys) else { return nil }
        let isPackage = values.isPackage ?? false
        let isDirectory = (values.isDirectory ?? false) && !isPackage
        let count = isDirectory && countItems ? (try? fm.contentsOfDirectory(atPath: url.path).count) : nil
        let attributes = try? fm.attributesOfItem(atPath: url.path)
        let mode = (attributes?[.posixPermissions] as? NSNumber)?.intValue
        return InfoModel(
            name: values.name ?? url.lastPathComponent,
            kind: values.localizedTypeDescription ?? (isDirectory ? "폴더" : "파일"),
            isDirectory: isDirectory,
            size: isDirectory || isPackage ? nil : Int64(values.fileSize ?? 0),
            itemCount: count,
            created: values.creationDate,
            modified: values.contentModificationDate,
            path: url.path,
            permissions: mode.map(permissionText) ?? "—"
        )
    }

    public static func permissionText(_ mode: Int) -> String {
        let triads = [(mode >> 6) & 7, (mode >> 3) & 7, mode & 7]
        let letters = triads.map { bits in
            (bits & 4 != 0 ? "r" : "-") + (bits & 2 != 0 ? "w" : "-") + (bits & 1 != 0 ? "x" : "-")
        }.joined()
        return "\(letters) (\(String(format: "%03o", mode & 0o777)))"
    }
}
