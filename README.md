# IHateFinder

[한국어](README.ko.md)

IHateFinder is a macOS file manager. You type a path, you read a details list, and you move files with cut and paste.

## Build and run

You need macOS 14 or later, and the Swift tools that ship with Xcode.

```bash
make test
make run
```

`make test` checks file operations, asynchronous browsing, session restoration, and clipboard/selection behavior using isolated folders, preferences, and pasteboards. `make run` builds `IHateFinder.app`, signs it for this Mac, and opens it.

The first time the app reads Desktop, Documents, or Downloads, macOS asks for access. Allow that access. Otherwise those folders stay closed.

## Daily use

Press Command-L to edit the path. Press Return to open the folder.

Command-X then Command-V moves the selection. Command-C then Command-V copies it. If the destination already has that name, choose Replace, Skip, or Keep both. Replace sends the existing item to the Trash.

fn-Delete or Command-Delete sends the selection to the Trash. Backspace alone goes Back. The app has no command that erases a file from the disk.

Option-Return shows an item's info (name, kind, size, dates, path, permissions). The right-click menu also has Open With, Compress (to `name.zip`, never overwriting, cancellable, undoable), Copy Path, and Open in Terminal. Space or Command-Y previews the selection (Quick Look); Esc closes it. Command-F, Control-F, or F3 filters the current folder by name; Esc clears the filter. Pressing Return on several selected items opens every selected file (asking first above 20); a single selected folder is entered.

In a text box, both Command and Control work for C/X/V/A/Z, and Shift-Z redoes. Control-click toggles a row in the selection without opening a menu; right-click and a two-finger tap still open the menu. Renaming selects only the name without its extension. Edit > Undo (Command-Z or Control-Z) with the list focused undoes the last file operation (trash, rename, move, copy, create) by moving things back only into empty places or to the Trash; anything that changed in between is skipped and reported.

Dragging within one disk moves; dragging to another disk copies. Hold Option to always copy, Command to always move.

Command-Shift-N creates a folder. Command-Option-N creates an empty text file. The default names are `새 폴더` and `새 텍스트 문서.txt`.

Click **양쪽 창** to show a second list. Click a list to make that list the target of the keyboard. F5 copies the selection to the other list. F6 moves it.

Copy files between Finder and IHateFinder using the system clipboard. Escape cancels local cut intent and leaves the files available as a copy. Completing an older move never clears a newer clipboard selection.

Transfers show the current file, item count, and byte progress where available. **취소** stops an in-progress copy safely; already completed items stay completed. Partial results identify skipped, failed, cancelled, and unprocessed items, including recovery locations when needed.

Folder reads run in the background and external changes refresh the list without shifting selection onto another file. The next launch restores both folder paths, sorting, hidden-file settings, and single/dual-pane mode. Unavailable saved folders fall back to Home, then the temporary folder, with an explanation.

## Use it as the default file viewer

This is optional, changes a system-wide setting, and you run the commands yourself. The app never changes it. Revert commands follow.

Prepare: run `make build`, copy `IHateFinder.app` to `/Applications`, and open it once.

Set (run in Terminal, then log out and back in, or restart):

```bash
defaults write -g NSFileViewer -string study.ihatefinder
defaults write com.apple.LaunchServices/com.apple.launchservices.secure LSHandlers -array-add '{LSHandlerContentType="public.folder";LSHandlerRoleAll="study.ihatefinder";}'
```

After that, "Show in Finder" and "open this folder" requests from other apps open here: a folder opens in the focused list, and a file opens its folder with the file selected.

Revert (then log out and back in, or restart; Finder is the viewer again):

```bash
defaults delete -g NSFileViewer
/usr/libexec/PlistBuddy -c "Print :LSHandlers" ~/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist
/usr/libexec/PlistBuddy -c "Delete :LSHandlers:<index>" ~/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist
```

Use the second command to find the entry whose `LSHandlerContentType` is `public.folder` and whose `LSHandlerRoleAll` is `study.ihatefinder`; put its index in place of `<index>` in the third command.

Limits: open and save panels, the Desktop, the Dock's Finder icon, and apps that call Finder directly still use Finder.

## Not in this version

This version has no tabs, no icon view, no column view, no subfolder search, and no redo for file operations.

## Check the right-hand list

Run this from the repository root.

```bash
swift build && .build/debug/IHateFinder --repro-focus
```

The process prints `copied=right-only.txt`, `pasteDest=right`, `backspace=goBack`, and `forwardDelete=trash`, then exits. It checks the copy source and paste/Delete/F6 target state after giving the right table keyboard focus; it does not actually delete or move files. It uses an isolated clipboard and does not save its temporary browsing session.
