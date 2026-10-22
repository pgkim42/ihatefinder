# IHateFinder

[한국어](README.ko.md)

IHateFinder is a file manager for macOS. Enter a path, find a file, and move it with cut and paste. Use two lists for transfers, or open separate windows for different tasks.

- Complete folder paths as you type.
- Filter the current folder or search its subfolders.
- Go back to the same selection, scroll position, and filter.
- Browse image and PDF thumbnails, or open Quick Look.
- Undo file operations and retry items blocked by a path conflict.

## Download

Download the DMG from the [Releases](https://github.com/pgkim42/ihatefinder/releases) page. It runs on macOS 14 or later, on Apple silicon and Intel Macs.

1. Open the DMG and drag `IHateFinder.app` to `Applications`.
2. Open the app. macOS blocks it the first time because the app has no Apple Developer ID signature.
3. Open **System Settings > Privacy & Security**, choose **Open Anyway** next to IHateFinder, and confirm.

You can also remove the download flag in Terminal instead of steps 2 and 3:

```bash
xattr -dr com.apple.quarantine /Applications/IHateFinder.app
```

After you install a new version, macOS can ask again for access to your folders.

## Build and run

You need macOS 14 or later and the Swift tools supplied with Xcode.

1. Open Terminal in the repository root.
2. Run the tests:

   ```bash
   make test
   ```

3. Build, sign, and open the app:

   ```bash
   make run
   ```

`make run` creates `IHateFinder.app` and signs it for this Mac. Use `make build` if you want to build without opening the app.

Run `make dmg` to build a universal app and put it in `dist/IHateFinder-<version>.dmg`. When you push a tag such as `v0.2.0`, GitHub Actions builds the DMG and attaches it to a new release.

macOS can ask for access to Desktop, Documents, Downloads, or connected disks. Choose **Allow** to browse those locations. If access is denied, the app shows an error and keeps the previous folder open.

## Browse folders

The **focused list** receives keyboard commands and file operations. Click a list or its path field to give it focus.

| Shortcut | Action |
|---|---|
| Command-L | Edit the path. |
| Return in the path field | Open the typed path or the selected folder candidate. |
| Return or Command-Down Arrow in the list | Open the selection. |
| Backspace, Command-[, or Option-Left Arrow | Go back. |
| Command-] or Option-Right Arrow | Go forward. |
| Command-Up Arrow or Option-Up Arrow | Open the parent folder and select the folder you left. |
| Command-Shift-period | Show or hide hidden items. |

Use `~` for your home folder. The path field lists matching folders as you type. Use the arrow keys to select a candidate, or press Tab to complete the path. Press Return to open it. Esc closes the candidates; press Esc again to cancel path editing.

Back and Forward restore the selection, scroll position, and filter for each visit. Items that no longer exist are not selected.

Return opens one selected folder or all selected files. In a mixed selection, it opens only the files. The app asks before opening more than 20 files. It does not open multiple selected folders together.

Click a folder name below the address field to jump to that location. Jumping to an ancestor selects the child folder on the path you left. Clicking the current folder keeps your selection and history.

### Filter or search

| Shortcut | Scope |
|---|---|
| Command-F or F3 | Filter names in the current folder. |
| Command-Shift-F | Search names in the current folder and its subfolders. |

For a filter, type part of a name. Only matching items stay in the list. The filter does not search subfolders. Its menu command is **이 폴더에서 이름 거르기**.

For a search, choose **하위 폴더에서 이름 검색** or press Command-Shift-F. Results show each item's original location. Right-click a result and choose **원래 폴더에서 보기** to open its folder and select it.

Search follows the hidden-item setting. If the starting folder is reached through a symbolic link, search uses its real location. It does not follow links found inside that folder or search inside app packages. You can open a result or perform file operations on the original item.

Press Return in either field to return focus to the list. Press Esc to clear the filter or leave the search. A new query replaces the previous search; leaving the search cancels it. Back and Forward restore the search query and selection. Sorting results preserves the selection without searching the file system again. If a subfolder cannot be read, accessible results remain visible with the skipped locations and reasons.

### Two lists and separate windows

Choose **양쪽 창** in the View menu or use the toolbar button to show a second list. Each list has its own folder and navigation history. F5 copies the selection to the other list; F6 moves it.

Press Command-N to open a separate window. Each window has its own lists, selection, and file undo history. The clipboard and favorites are shared across windows.

Command-W closes the current window. Closing the last window quits the app. Finish or cancel file operations before closing their window or quitting.

### Favorites

1. Open a folder in the focused list.
2. Choose **현재 폴더를 즐겨찾기에 추가** in the File menu or the right-click menu.
3. Click the new sidebar shortcut to open that folder.

Right-click a favorite to open it, remove it, or move it up or down. Changes appear in other open windows and remain after restart.

Adding the same path twice creates only one shortcut. Removing a shortcut does not change the folder. Favorites store paths; they do not track folders moved or renamed by another app.

## Inspect files

| Command | Action |
|---|---|
| Space or Command-Y | Open or close Quick Look for the selection. |
| Esc in Quick Look | Close Quick Look. |
| View > **축소판 보기** | Show content thumbnails in larger list rows. Choose it again to return to the details list. |
| Option-Return | Show information about one selected item. |

Thumbnail rows show image and PDF content alongside the file details. Quick Look remains available in either view.

The info sheet shows the name, kind, dates, path, and permissions. It also shows a file's size or a folder's immediate item count. It does not calculate the total size of a folder or change permissions.

## Work with files

### Select, create, and rename

| Shortcut or mouse action | Result |
|---|---|
| Command-A | Select all visible items. |
| Shift-click | Select a range. |
| Command-click or Control-click | Add or remove one item from the selection. |
| Right-click or two-finger tap | Open the context menu. |
| F2 | Rename the selected item. |
| Command-Shift-N | Create a folder and start editing its name. |
| Command-Option-N | Create an empty text file and start editing its name. |

Control-click changes the selection; it does not open the menu. While renaming a file, the app selects the name without its extension. Folder names and dotfile names are selected in full.

New items start with the names `새 폴더` and `새 텍스트 문서.txt`. If a name is already in use, the app adds a number.

### Copy, move, and drag

| Shortcut | Action |
|---|---|
| Command-C, then Command-V | Copy the selection into the focused list's folder. |
| Command-X, then Command-V | Move the selection into the focused list's folder. |
| Esc in the list | Cancel a cut after any active filter or search is cleared. The clipboard still contains the files for copying. |
| F5 | Copy to the other list. |
| F6 | Move to the other list. |

F5 and F6 require two visible lists. The same commands are in the Edit menu and the right-click menu, with the destination folder name.

Finder and IHateFinder use the system file clipboard. Files copied from another app are pasted as copies, not moves.

Drag items onto a folder or the other list. On the same disk, the default action is a move. Across disks, it is a copy. Hold Option to copy or Command to move, when the drag source permits that action.

If a name is already in use, choose one option:

- **바꾸기** (Replace): replace the destination item and send the old item to the Trash.
- **건너뛰기** (Skip): leave that item unchanged.
- **둘 다 유지** (Keep both): give the incoming item a numbered name.

The conflict dialog shows both paths, types, sizes, and modification times. Replacing a folder replaces the whole destination folder; it does not merge contents. You can apply the same choice to the remaining conflicts, or choose **전체 작업 취소** to cancel the transfer while keeping completed items.

### Transfer progress and cancellation

During a transfer, the app shows the current item and item count. It shows byte progress when the amount of data is known.

Click **취소** to cancel. Completed items stay complete. Unfinished copies are cleaned up without replacing the original files. If cleanup or recovery fails, the result shows the remaining file locations.

Cross-volume moves check the source before and after copying. If the source or its descendants changed, or cannot be verified, the original stays in place and the result explains the preserved locations. Copying or moving a folder into itself is rejected even through a symbolic link.

Moving to another volume is stopped if the source disk does not provide stable file identifiers, as with macOS FAT/exFAT volumes. Use Copy, check the copied files, then remove the originals yourself.

The result distinguishes completed, skipped, failed, cancelled, and unprocessed items. The app stops processing further items after a failure or cancellation.

Where supported, copies on the same APFS volume use clones. These copies initially share data blocks; later edits can require more disk space.

### Trash and undo

Press Command-Delete or fn-Delete to move the selection to the Trash. Backspace alone goes back. The app does not permanently delete files. If a disk does not support Trash, the app reports the problem instead.

Command-Z or Control-Z undoes the last file operation in the current window. Supported operations are Trash, rename, move, copy, create, and compress. Each window keeps up to 50 operations. Closing that window discards its history.

Undo does not overwrite an occupied path. If a path conflict or missing parent folder blocks an item, the app can retain it for retry. Resolve the problem, then choose **Edit > 막힌 실행 취소 다시 시도** (Retry blocked undo). This retries the blocked operation without undoing a rename or move used to clear the obstruction. Items already restored are not repeated.

Undoing a move across disks restores the current file contents, including edits made after the move. The older source copy can remain in the Trash. If the app cannot verify an item, or the path now contains a different item, it skips that item and explains why.

File operations have no Redo command. In a text field, Undo and Redo apply to typing instead.

### Other file commands

The right-click menu also provides:

- **다른 앱으로 열기**: choose an app that can open the selected items.
- **압축**: create a ZIP archive from one selected item without overwriting an existing archive. You can cancel the operation or undo it afterward.
- **경로 복사**: copy full paths as text. This replaces the clipboard contents and cancels any cut state.
- **정보 보기**: open the info sheet for one item.
- **터미널에서 열기**: open Terminal for the selected folder or the current location. For a search result, it uses the original location.

If Open, Open With, or Open in Terminal fails, the app shows the affected path and the reason.

### Control-key alternatives

When the list has focus, Control can replace Command for C, X, V, A, L, F, Z, Shift-N, Option-N, and Shift-period.

In a text field, Command and Control both support C, X, V, A, and Z. Add Shift to Command-Z or Control-Z to redo typing.

## Folder updates and restart

Folder reads run in the background. Changes made by other apps refresh the list. Existing selections remain on the same files; deleted files leave the selection.

On restart, the app restores one saved workspace, not every open window. It keeps the two folder paths, sort settings, hidden-item settings, and two-list setting from the active workspace.

If a saved folder is unavailable, the app tries your home folder, then the temporary folder. It shows the failed path and the reason. Cut state, transfer jobs, and file undo history are not restored.

## Use as the default file viewer

This optional setup changes macOS settings. IHateFinder does not make these changes itself.

### Set up

1. Run `make build`.
2. Copy `IHateFinder.app` to `/Applications` and open it once.
3. Run these commands in Terminal:

   ```bash
   defaults write -g NSFileViewer -string study.ihatefinder
   defaults write com.apple.LaunchServices/com.apple.launchservices.secure LSHandlers -array-add '{LSHandlerContentType="public.folder";LSHandlerRoleAll="study.ihatefinder";}'
   ```

4. Log out and back in, or restart the Mac.

Apps that honor these settings can send folder and "Show in Finder" requests to IHateFinder. A folder opens in the focused list. A file request opens its parent folder and selects the file.

This does not replace the system Open and Save dialogs, Desktop, or Finder's Dock icon. Apps that explicitly target Finder can still open Finder.

### Return to Finder

1. Remove the file-viewer setting:

   ```bash
   defaults delete -g NSFileViewer
   ```

2. Show the folder-handler entries:

   ```bash
   /usr/libexec/PlistBuddy -c "Print :LSHandlers" ~/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist
   ```

3. Find the entry with `LSHandlerContentType = public.folder` and `LSHandlerRoleAll = study.ihatefinder`. Its index starts at 0.
4. Remove that entry. Replace `<index>` with its index:

   ```bash
   /usr/libexec/PlistBuddy -c "Delete :LSHandlers:<index>" ~/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist
   ```

5. Log out and back in, or restart the Mac.

Remove only matching IHateFinder entries. If there is more than one, remove them from the highest index to the lowest.

## Current limits

- No tabs, icon grid, or column view.
- No Redo for file operations.
- No permanent-delete command.
- No restoration of all open windows after restart.

## Developer checks

`make test` covers file operations, navigation, search, completion, window routing, thumbnails, and clipboard behavior. Tests use temporary files, preferences, and pasteboards.

To check which list receives file commands, run:

```bash
swift build && .build/debug/IHateFinder --repro-focus
```

The output must include:

```text
copied=right-only.txt
pasteDest=right
backspace=goBack
forwardDelete=trash
```

This check gives focus to the right list and examines the command targets. It uses temporary files and a separate clipboard. It does not perform the file transfers or save the workspace.

See [the behavior reference](docs/behavior.md) for the detailed interaction rules.
