import Foundation

/// Operations the drag source allows, as reported by `draggingSourceOperationMask`.
/// AppKit narrows the mask to `.copy` for Option and to `.generic` for Cmd.
public struct DropMask: OptionSet, Equatable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let copy = DropMask(rawValue: 1 << 0)
    public static let move = DropMask(rawValue: 1 << 1)
    public static let generic = DropMask(rawValue: 1 << 2)
}

public enum DropOperation: Equatable {
    case copy
    case move
}

/// One decision for both the drag cursor (validateDrop) and the action (acceptDrop).
public enum DropPolicy {
    public static func operation(allSourcesOnDestinationVolume: Bool, mask: DropMask) -> DropOperation? {
        if mask.contains(.copy) {
            if mask.contains(.move) || mask.contains(.generic) {
                return allSourcesOnDestinationVolume ? .move : .copy
            }
            return .copy
        }
        if mask.contains(.move) || mask.contains(.generic) { return .move }
        return nil
    }
}
