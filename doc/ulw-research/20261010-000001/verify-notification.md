# Notification center verification
Claim: BrowserWindowController.swift:78-89 subscribes mount/unmount on NotificationCenter.default, whereas NSWorkspace requires its own notificationCenter. This can prevent sidebar volume-list refresh through those handlers.
HEAD: 0970c61. Observed source directly read by lead.
Primary contract: https://developer.apple.com/documentation/appkit/nsworkspace/didmountnotification.md
Quote: "If you use a different notification center to register, you won’t receive the notification."
Invocation: `swift doc/ulw-research/20261010-000001/verify-notification.swift`
Expected binary PASS: same_center=false, workspace_received present, default_received absent, cleanup line present. Timeout 30s; no delays/polling.
Actual stdout:
```
same_center=false
workspace_received
cleanup=both_observers_removed
```
Exit success, 0.26s. CONFIRMED for center identity/dispatch and source-contract mismatch. This is a synthetic in-process notification dispatch proof, not a physical external-drive mount/eject scenario, and no claim of a measured user-visible incident is made.
No disk, file, system default, or real app state modified. Cleanup: both observer tokens removed, Swift process exited. Script retained as research evidence. Product bug left unchanged because user asked for investigation, not implementation.
