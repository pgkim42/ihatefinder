import AppKit

// Research-only proof of center identity and dispatch; no disk is mounted.
let ordinary = NotificationCenter.default
let workspace = NSWorkspace.shared.notificationCenter
print("same_center=\(ordinary === workspace)")
let defaultToken = ordinary.addObserver(forName: NSWorkspace.didMountNotification, object: nil, queue: nil) { _ in
    print("default_received")
}
let workspaceToken = workspace.addObserver(forName: NSWorkspace.didMountNotification, object: nil, queue: nil) { _ in
    print("workspace_received")
}
workspace.post(name: NSWorkspace.didMountNotification, object: NSWorkspace.shared)
ordinary.removeObserver(defaultToken)
workspace.removeObserver(workspaceToken)
print("cleanup=both_observers_removed")
