# Real desktop investigation
HEAD: 0970c61. Current rebuilt .build/debug/IHateFinder, not bundled app (hashes differ). OS darwin arm64, current user's System Events accessibility is enabled.

## Isolation and resource ownership
Before launch: `osascript -e 'tell application "System Events" to get {UI elements enabled, name of every application process whose name is "IHateFinder"}'` returned `true,` (no prior app process).
`mktemp -d /tmp/ihatefinder-research.XXXXXX` returned `/tmp/ihatefinder-research.2zmKoL`.
`env CFFIXED_USER_HOME=/tmp/ihatefinder-research.2zmKoL swift -e 'import Foundation; print(NSHomeDirectory()); print(FileManager.default.homeDirectoryForCurrentUser.path)'` returned that path twice.
Launch: `env CFFIXED_USER_HOME=/tmp/ihatefinder-research.2zmKoL .build/debug/IHateFinder`, owned async bg_16. User's real file manager preferences are outside this isolated home.

## Scenario GUI1: path navigation
Invocation: System Events sets process IHateFinder frontmost; sets AXFocused on address field 1 of nested splitter group; Cmd-A, types `/Users/pgkim/projects/study/ihatefinder`, Return. Bounded command timeout 30s, no sleeps or polling.
PASS observable: window title is `ihatefinder`; repository entries including Sources, Tests, README.md appear. Observed via osascript and actual screenshot `desktop-browse.png`.
Initial Cmd-L/typing and a direct click+AX value attempt had not committed navigation in `desktop-path.png`/`desktop-address.png`. Explicit AXFocused and normal typing/Return succeeded. This is a recorded automation/focus ambiguity, not evidence that product Cmd-L is broken. No bug claim is derived from it.

## Scenario GUI2: visible two-place workspace
Invocation: `osascript` System Events `perform action "AXPress" of button 4 of window 1`.
PASS observable: two distinct address bars/lists appear, left repository and right isolated home. Screenshot `desktop-dual.png` inspected by lead confirms both.
Observation: default-width split shows names/dates/kinds but the size column is beyond the visible horizontal range. No clipping bug claimed; horizontal scrolling exists. Toolbar shows navigation and split controls, not copy-to-other/move-to-other controls. Active list has blue focus border; app became inactive during capture. No observation of user confusion or transfer failure.

## Scenario GUI3: existing current-folder filter
Invocation: System Events clicks menu bar item `편집`, then menu item `찾기`; inspected GUI2 screenshot confirms visible `이 폴더에서 이름 거르기` field. Next action focuses AX text field 2 and types `README`.
PASS: actual `desktop-filter.png` inspected by lead shows README.ko.md and README.md only, the typed README query, and `11개 중 2개 표시` status. Existing filtering works through the real GUI.

## Limits
No destructive file operation, cloud download, real external drive mount/eject, default file-viewer settings change, external AppleEvent producer, or performance benchmark was performed. The app GUI is native, inspected through OS accessibility + screencapture, not replaced by test/CLI dumps. Clipboard was not changed by QA.
Cleanup PASS: proc://bg_16/kill returned cancelled; removed only `/tmp/ihatefinder-research.2zmKoL`; `test ! -e` succeeded; System Events reports zero IHateFinder processes. Screenshots are retained evidence, not disposable QA state.
