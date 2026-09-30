# IHateFinder

[한국어](README.ko.md)

IHateFinder is a macOS file manager. You type a path, you read a details list, and you move files with cut and paste.

## Build and run

You need macOS 14 or later, and the Swift tools that ship with Xcode.

```bash
make test
make run
```

`make test` runs the file-operation tests in a temporary folder. `make run` builds `IHateFinder.app`, signs it for this Mac, and opens it.

The first time the app reads Desktop, Documents, or Downloads, macOS asks for access. Allow that access. Otherwise those folders stay closed.

## Daily use

Press Command-L to edit the path. Press Return to open the folder.

Command-X then Command-V moves the selection. Command-C then Command-V copies it. If the destination already has that name, choose Replace, Skip, or Keep both. Replace sends the existing item to the Trash.

Delete sends the selection to the Trash. The app has no command that erases a file from the disk.

Command-Shift-N creates a folder. Command-Option-N creates an empty text file. The default names are `새 폴더` and `새 텍스트 문서.txt`.

Click **양쪽 창** to show a second list. Click a list to make that list the target of the keyboard. F5 copies the selection to the other list. F6 moves it.

## Not in this version

This version has no tabs, no icon view, no column view, no folder search, no Quick Look, and no undo.

## Check the right-hand list

Run this from the repository root.

```bash
swift build && .build/debug/IHateFinder --repro-focus
```

The process prints `copied=right-only.txt` and `pasteDest=right`, then exits. That line means a click on the right list makes copy, paste, Delete, and F6 use the right list.
