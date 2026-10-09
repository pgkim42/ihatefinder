# IHateFinder

[한국어](README.ko.md)

IHateFinder is a file manager for macOS. It uses a path field, a details list, and cut and paste to move files.

This README uses ASD-STE100 Simplified Technical English.

## Requirements

- macOS 14 or later.
- The Swift tools that Xcode supplies.

## Build and run the app

1. Open Terminal in the repository root.
2. Run the tests:

   ```bash
   make test
   ```

3. Build, sign, and open the app:

   ```bash
   make run
   ```

`make test` tests the file operations, folder reads, session restore, the clipboard, and the selection. The tests use temporary folders, preferences, and pasteboards. They do not change your files.

`make run` builds `IHateFinder.app`, signs it for this Mac, and opens it.

When the app opens Desktop, Documents, or Downloads for the first time, macOS asks for access. Click **Allow**. If you do not allow access, the app cannot show these folders.

## Keys and mouse

In this section, "the list" is the details list that has the keyboard focus.

Control does the same thing as Command for the list keys that follow: C, X, V, A, L, F, Shift-N, Option-N, and Shift-period.

### Go to a folder

| Key | Result |
|---|---|
| Command-L | Puts the cursor in the path field. |
| Return (in the path field) | Opens the folder at that path. |
| Return | Opens the selected file. If you select one folder, the app opens that folder. |
| Command-Down Arrow | Opens the selection. |
| Backspace | Goes back. |
| Command-[ or Option-Left Arrow | Goes back. |
| Command-] or Option-Right Arrow | Goes forward. |
| Command-Up Arrow or Option-Up Arrow | Goes up one folder. The app selects the folder that you came from. |

If you select more than one file and push Return, the app opens all the selected files. If you select more than 20 files, the app asks before it opens them. If you select files and folders, the app opens only the files. If you select only folders, and more than one, the app opens nothing and shows a message.

### Copy and move

| Key | Result |
|---|---|
| Command-C, then Command-V | Copies the selection to the folder of the list. |
| Command-X, then Command-V | Moves the selection to the folder of the list. |
| Esc | Cancels the cut. The items stay on the clipboard as a copy. |
| F5 | Copies the selection to the other list. |
| F6 | Moves the selection to the other list. |

If the destination has an item with the same name, select one of these options:

- **Replace**: The app moves the existing item to the Trash.
- **Skip**: The app does not copy or move that item.
- **Keep both**: The app gives the new item a number.

You can copy files between Finder and IHateFinder. Both apps use the system clipboard.

### Drag

- Drag to a folder on the same disk: the app moves the items.
- Drag to a folder on a different disk: the app copies the items.
- Hold Option: the app always copies.
- Hold Command: the app always moves.

### Select and rename

| Key or mouse | Result |
|---|---|
| Command-A | Selects all the items. |
| Control-click | Adds the item to the selection, or removes it. The menu does not open. |
| Right-click or two-finger tap | Opens the menu. |
| F2 | Starts a rename. The app selects the name without the extension. |
| Command-Shift-N | Makes a new folder. Then you can type the name. |
| Command-Option-N | Makes an empty text file. Then you can type the name. |
| Command-Shift-period | Shows or hides the hidden files. |

The default names are `새 폴더` and `새 텍스트 문서.txt`.

### Trash

| Key | Result |
|---|---|
| fn-Delete | Moves the selection to the Trash. |
| Command-Delete | Moves the selection to the Trash. |

The app always moves items to the Trash. The app cannot erase an item from the disk.

Some disks do not have a Trash, for example some network disks and some USB disks. On these disks, the app does not delete the item. The app shows a message.

### Undo

When the list has the focus, Command-Z or Control-Z undoes the last file operation. You can undo these operations: trash, rename, move, copy, new item, and compress.

The undo uses only two safe steps:

- It moves an item back into an empty position.
- It moves an item to the Trash.

The undo does not write over an item. If an item changed after the operation, the app does not undo that item. The app shows a message.

When you type in a text field, Command-Z or Control-Z undoes the typing. This is also true while you rename an item. The app cannot redo a file operation.

### Preview, filter, and info

| Key | Result |
|---|---|
| Space or Command-Y | Opens the preview (Quick Look) of the selection. |
| Esc (in the preview) | Closes the preview. |
| Command-F or F3 | Opens the filter field. The list shows only the items whose names contain the text. |
| Esc (in the filter field) | Clears the filter. |
| Option-Return | Shows the info of the item: name, kind, size, dates, path, and permissions. |

The filter looks only in the current folder. It does not look in subfolders.
The Edit menu names this command **이 폴더에서 이름 거르기**. The View menu and the right-click menu also have **미리보기 (Space)**.

### Text fields

In a text field, Command and Control do the same thing for C, X, V, A, and Z. Shift-Z redoes the typing.

### Menu

The right-click menu has these commands:

- **열기** (Open)
- **다른 앱으로 열기** (Open With)
- **새 폴더**, **새 텍스트 파일**, **잘라두기**, **복사**, **붙여넣기**, **이름 바꾸기**, **휴지통으로 옮기기**
- **압축** (Compress): makes `name.zip`. It does not write over an existing file. You can cancel it and undo it.
- **경로 복사** (Copy Path): copies the full path as text.
- **정보 보기** (Info)
- **터미널에서 열기** (Open in Terminal)
- **반대쪽으로 복사 (F5)** and **반대쪽으로 이동 (F6)**: show the destination folder name. The commands are also in the Edit menu. They are disabled if the second list is hidden, nothing is selected, or a transfer is running.
- **현재 폴더를 즐겨찾기에 추가** (Add Current Folder to Favorites).

### Two lists

Click **양쪽 창** to show a second list. Click a list to give it the keyboard focus.

### Favorites

1. Open a folder in the focused list.
2. Choose **현재 폴더를 즐겨찾기에 추가** in the File menu or the right-click menu.
3. Click its sidebar shortcut to open it in the focused list.
4. Right-click a favorite to choose **즐겨찾기 열기** (Open Favorite), remove it, or move it up or down.

The app saves the order. Adding the same path twice does not add a second shortcut. Removing a shortcut does not move or delete the folder. Favorites store absolute paths; they do not track a folder renamed or moved by another app.


## Transfers

During a copy or a move, the app shows:

- The current file.
- The number of items.
- The number of bytes, when this is available.

Click **취소** to stop the transfer. The items that are complete stay complete. The app does not leave a partly written file.

When the app cannot complete all the items, it shows a list. The list shows the skipped, failed, cancelled, and unprocessed items. It also shows the recovery location when it is necessary.

On the same disk, a copy is very fast and does not use more disk space. The app uses an APFS clone for this.

## Folders and restart

The app reads folders in the background. When a different app changes a folder, the list shows the change. The selection stays on the same item.

When you start the app again, it opens the same folders. It also keeps the sort order, the hidden-file setting, and the two-list setting. If a saved folder is not available, the app opens your home folder. If your home folder is not available, the app opens the temporary folder. The app tells you why.

## Use the app as the default file viewer

This procedure is optional. It changes a setting for all of macOS. The app does not change this setting. You must do these steps yourself.

### Prepare

1. Run `make build`.
2. Copy `IHateFinder.app` to `/Applications`.
3. Open the app one time.

### Set

1. Run these commands in Terminal:

   ```bash
   defaults write -g NSFileViewer -string study.ihatefinder
   defaults write com.apple.LaunchServices/com.apple.launchservices.secure LSHandlers -array-add '{LSHandlerContentType="public.folder";LSHandlerRoleAll="study.ihatefinder";}'
   ```

2. Log out and log in again, or restart the Mac.

Other apps then send "Show in Finder" and folder requests to IHateFinder:

- A folder opens in the list that has the focus.
- A file opens its folder, and the app selects the file.

### Revert

1. Run this command:

   ```bash
   defaults delete -g NSFileViewer
   ```

2. Show the LaunchServices handler list:

   ```bash
   /usr/libexec/PlistBuddy -c "Print :LSHandlers" ~/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist
   ```

3. Find the entry that has `LSHandlerContentType` = `public.folder` and `LSHandlerRoleAll` = `study.ihatefinder`. Count from 0 to get its index.
4. Delete that entry. Replace `<index>` with the index from step 3:

   ```bash
   /usr/libexec/PlistBuddy -c "Delete :LSHandlers:<index>" ~/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist
   ```

5. Log out and log in again, or restart the Mac. Finder is then the file viewer again.

### Limits

These items continue to use Finder:

- The Open and Save panels.
- The Desktop.
- The Finder icon in the Dock.
- Apps that send their requests directly to Finder.

## Not in this version

This version does not have these functions:

- Tabs.
- Icon view and column view.
- Search in subfolders.
- Redo of a file operation.

## Test the right list

Use this test to make sure that the keys go to the list that has the focus.

1. Run this command in the repository root:

   ```bash
   swift build && .build/debug/IHateFinder --repro-focus
   ```

2. Make sure that the output contains these lines:

   - `copied=right-only.txt`
   - `pasteDest=right`
   - `backspace=goBack`
   - `forwardDelete=trash`

The test gives the keyboard focus to the right list. Then it examines the copy source and the target of paste, Delete, and F6. The test does not delete or move files. It uses a separate clipboard. It does not save its session.
