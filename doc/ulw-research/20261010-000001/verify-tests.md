# Repository contract verification
Invocation: swift test
HEAD: 0970c61. No product changes.
Verdict: PASS. IHateFinderTests 80 tests; IHateFinderCoreTests 160 tests; total 240 tests, 0 failures. Counts verified in the full transcript below.
Cleanup: tests use their own temporary folders; no test process remains.

Building for debugging...
[1 / 17]
[2 / 18] IHateFinderCore
[4 / 19] IHateFinderCore
[11 / 24] IHateFinderCoreTests-product
[21 / 32] IHateFinder
[26 / 37] IHateFinder-product
[32 / 42] IHateFinder
[36 / 44] IHateFinder
[41 / 46] IHateFinderTests-product
[49 / 54] IHateFinderTests-product
[52 / 55] IHateFinderTests-product
[54 / 58] IHateFinderTests-product
Build complete! (16.37초)
Test Suite 'All tests' started at 2026-10-10 00:06:07.150.
Test Suite 'IHateFinderTests.xctest' started at 2026-10-10 00:06:07.152.
Test Suite 'BrowserSeamTests' started at 2026-10-10 00:06:07.152.
Test Case '-[IHateFinderTests.BrowserSeamTests testBusyIsTestVisibleAndWaitIdleReturnsOnceCleared]' started.
Test Case '-[IHateFinderTests.BrowserSeamTests testBusyIsTestVisibleAndWaitIdleReturnsOnceCleared]' passed (0.182 seconds).
Test Case '-[IHateFinderTests.BrowserSeamTests testDropCopyRunsThroughInjectedOpsInsideTempFolders]' started.
Test Case '-[IHateFinderTests.BrowserSeamTests testDropCopyRunsThroughInjectedOpsInsideTempFolders]' passed (0.038 seconds).
Test Case '-[IHateFinderTests.BrowserSeamTests testEachPaneGetsInjectedOpsThatTrashIntoTheTempBinWithoutCloning]' started.
Test Case '-[IHateFinderTests.BrowserSeamTests testEachPaneGetsInjectedOpsThatTrashIntoTheTempBinWithoutCloning]' passed (0.015 seconds).
Test Case '-[IHateFinderTests.BrowserSeamTests testTestBrowserPanesStartInTempFoldersNotHome]' started.
Test Case '-[IHateFinderTests.BrowserSeamTests testTestBrowserPanesStartInTempFoldersNotHome]' passed (0.018 seconds).
Test Suite 'BrowserSeamTests' passed at 2026-10-10 00:06:07.406.
	 Executed 4 tests, with 0 failures (0 unexpected) in 0.254 (0.254) seconds
Test Suite 'ContextMenuTests' started at 2026-10-10 00:06:07.406.
Test Case '-[IHateFinderTests.ContextMenuTests testCompressFailureAddsNoUndoRecord]' started.
Test Case '-[IHateFinderTests.ContextMenuTests testCompressFailureAddsNoUndoRecord]' passed (0.498 seconds).
Test Case '-[IHateFinderTests.ContextMenuTests testCompressRunsAsBusyJobRecordsUndoAndUndoTrashesZip]' started.
Test Case '-[IHateFinderTests.ContextMenuTests testCompressRunsAsBusyJobRecordsUndoAndUndoTrashesZip]' passed (0.233 seconds).
Test Case '-[IHateFinderTests.ContextMenuTests testCopyPathWritesTextAndEndsFileCutIntent]' started.
Test Case '-[IHateFinderTests.ContextMenuTests testCopyPathWritesTextAndEndsFileCutIntent]' passed (0.039 seconds).
Test Case '-[IHateFinderTests.ContextMenuTests testInfoActionShowsSheetForSingleSelectionOnly]' started.
Test Case '-[IHateFinderTests.ContextMenuTests testInfoActionShowsSheetForSingleSelectionOnly]' passed (0.221 seconds).
Test Case '-[IHateFinderTests.ContextMenuTests testInfoRowsCoverEveryField]' started.
Test Case '-[IHateFinderTests.ContextMenuTests testInfoRowsCoverEveryField]' passed (0.000 seconds).
Test Case '-[IHateFinderTests.ContextMenuTests testMenuOrderAndEnablementFollowSelection]' started.
Test Case '-[IHateFinderTests.ContextMenuTests testMenuOrderAndEnablementFollowSelection]' passed (0.309 seconds).
Test Case '-[IHateFinderTests.ContextMenuTests testOpenWithSubmenuListsCommonAppsDefaultFirstAndOpensChosenApp]' started.
Test Case '-[IHateFinderTests.ContextMenuTests testOpenWithSubmenuListsCommonAppsDefaultFirstAndOpensChosenApp]' passed (0.213 seconds).
Test Case '-[IHateFinderTests.ContextMenuTests testOpenWithSubmenuShowsDisabledNoneWhenNoApp]' started.
Test Case '-[IHateFinderTests.ContextMenuTests testOpenWithSubmenuShowsDisabledNoneWhenNoApp]' passed (0.218 seconds).
Test Case '-[IHateFinderTests.ContextMenuTests testOptionReturnShowsInfoOnlyOnTheList]' started.
Test Case '-[IHateFinderTests.ContextMenuTests testOptionReturnShowsInfoOnlyOnTheList]' passed (0.000 seconds).
Test Case '-[IHateFinderTests.ContextMenuTests testTerminalOpensSelectedFolderOtherwiseCurrentFolder]' started.
Test Case '-[IHateFinderTests.ContextMenuTests testTerminalOpensSelectedFolderOtherwiseCurrentFolder]' passed (0.221 seconds).
Test Suite 'ContextMenuTests' passed at 2026-10-10 00:06:09.359.
	 Executed 10 tests, with 0 failures (0 unexpected) in 1.952 (1.953) seconds
Test Suite 'FileClipboardTests' started at 2026-10-10 00:06:09.359.
Test Case '-[IHateFinderTests.FileClipboardTests testCancelCutPreservesCopyAndIgnoresPendingMoveCompletion]' started.
Test Case '-[IHateFinderTests.FileClipboardTests testCancelCutPreservesCopyAndIgnoresPendingMoveCompletion]' passed (0.001 seconds).
Test Case '-[IHateFinderTests.FileClipboardTests testDirectMoveOnlyConsumesMatchingCutSources]' started.
Test Case '-[IHateFinderTests.FileClipboardTests testDirectMoveOnlyConsumesMatchingCutSources]' passed (0.001 seconds).
Test Case '-[IHateFinderTests.FileClipboardTests testExternalFileURLsAreCopiesAndPreserveEscapedNames]' started.
Test Case '-[IHateFinderTests.FileClipboardTests testExternalFileURLsAreCopiesAndPreserveEscapedNames]' passed (0.001 seconds).
Test Case '-[IHateFinderTests.FileClipboardTests testExternalReplacementInvalidatesCutEvenForSameFiles]' started.
Test Case '-[IHateFinderTests.FileClipboardTests testExternalReplacementInvalidatesCutEvenForSameFiles]' passed (0.001 seconds).
Test Case '-[IHateFinderTests.FileClipboardTests testOldMoveCompletionDoesNotClearNewLocalCut]' started.
Test Case '-[IHateFinderTests.FileClipboardTests testOldMoveCompletionDoesNotClearNewLocalCut]' passed (0.001 seconds).
Test Case '-[IHateFinderTests.FileClipboardTests testOldMoveCompletionDoesNotOverwriteExternalText]' started.
Test Case '-[IHateFinderTests.FileClipboardTests testOldMoveCompletionDoesNotOverwriteExternalText]' passed (0.001 seconds).
Test Case '-[IHateFinderTests.FileClipboardTests testPartialMoveRetainsEveryUncompletedSourceAndInvalidatesOldSnapshot]' started.
Test Case '-[IHateFinderTests.FileClipboardTests testPartialMoveRetainsEveryUncompletedSourceAndInvalidatesOldSnapshot]' passed (0.001 seconds).
Test Case '-[IHateFinderTests.FileClipboardTests testRejectedWriteLeavesExistingClipboardAndCutIntentIntact]' started.
Test Case '-[IHateFinderTests.FileClipboardTests testRejectedWriteLeavesExistingClipboardAndCutIntentIntact]' passed (0.001 seconds).
Test Case '-[IHateFinderTests.FileClipboardTests testTextGenericURLsAndRemoteFileURLsAreNotFileOperations]' started.
Test Case '-[IHateFinderTests.FileClipboardTests testTextGenericURLsAndRemoteFileURLsAreNotFileOperations]' passed (0.002 seconds).
Test Case '-[IHateFinderTests.FileClipboardTests testWrittenFilesAreReadableByExternalFileURLConsumer]' started.
Test Case '-[IHateFinderTests.FileClipboardTests testWrittenFilesAreReadableByExternalFileURLConsumer]' passed (0.003 seconds).
Test Suite 'FileClipboardTests' passed at 2026-10-10 00:06:09.373.
	 Executed 10 tests, with 0 failures (0 unexpected) in 0.013 (0.014) seconds
Test Suite 'FilePaneControllerTests' started at 2026-10-10 00:06:09.373.
Test Case '-[IHateFinderTests.FilePaneControllerTests testNavigationDoesNotCarryRowSelectionToDifferentFile]' started.
Test Case '-[IHateFinderTests.FilePaneControllerTests testNavigationDoesNotCarryRowSelectionToDifferentFile]' passed (0.027 seconds).
Test Case '-[IHateFinderTests.FilePaneControllerTests testRefreshPreservesSelectedFileWhenRowsShiftAndClearsDeletedSelection]' started.
Test Case '-[IHateFinderTests.FilePaneControllerTests testRefreshPreservesSelectedFileWhenRowsShiftAndClearsDeletedSelection]' passed (0.042 seconds).
Test Suite 'FilePaneControllerTests' passed at 2026-10-10 00:06:09.442.
	 Executed 2 tests, with 0 failures (0 unexpected) in 0.069 (0.069) seconds
Test Suite 'FileTableViewTests' started at 2026-10-10 00:06:09.442.
Test Case '-[IHateFinderTests.FileTableViewTests testControlClickTogglesRowAndKeepsOtherSelection]' started.
Test Case '-[IHateFinderTests.FileTableViewTests testControlClickTogglesRowAndKeepsOtherSelection]' passed (0.027 seconds).
Test Case '-[IHateFinderTests.FileTableViewTests testControlLeftClickDoesNotOpenContextMenu]' started.
Test Case '-[IHateFinderTests.FileTableViewTests testControlLeftClickDoesNotOpenContextMenu]' passed (0.032 seconds).
Test Case '-[IHateFinderTests.FileTableViewTests testPlainLeftClickAndSecondaryClickKeepContextMenu]' started.
Test Case '-[IHateFinderTests.FileTableViewTests testPlainLeftClickAndSecondaryClickKeepContextMenu]' passed (0.024 seconds).
Test Case '-[IHateFinderTests.FileTableViewTests testRenameSelectsStemOfFileInRealFieldEditor]' started.
Test Case '-[IHateFinderTests.FileTableViewTests testRenameSelectsStemOfFileInRealFieldEditor]' passed (0.044 seconds).
Test Case '-[IHateFinderTests.FileTableViewTests testRenameSelectsWholeNameOfFolderAndDotfile]' started.
Test Case '-[IHateFinderTests.FileTableViewTests testRenameSelectsWholeNameOfFolderAndDotfile]' passed (0.043 seconds).
Test Case '-[IHateFinderTests.FileTableViewTests testToggleSelectionIgnoresOutOfRangeRow]' started.
Test Case '-[IHateFinderTests.FileTableViewTests testToggleSelectionIgnoresOutOfRangeRow]' passed (0.025 seconds).
Test Suite 'FileTableViewTests' passed at 2026-10-10 00:06:09.637.
	 Executed 6 tests, with 0 failures (0 unexpected) in 0.195 (0.195) seconds
Test Suite 'KeyCommandTests' started at 2026-10-10 00:06:09.637.
Test Case '-[IHateFinderTests.KeyCommandTests testBackspaceAndDeleteInTextFieldPassThrough]' started.
Test Case '-[IHateFinderTests.KeyCommandTests testBackspaceAndDeleteInTextFieldPassThrough]' passed (0.000 seconds).
Test Case '-[IHateFinderTests.KeyCommandTests testBackspaceWithoutTableFocusDoesNothing]' started.
Test Case '-[IHateFinderTests.KeyCommandTests testBackspaceWithoutTableFocusDoesNothing]' passed (0.000 seconds).
Test Case '-[IHateFinderTests.KeyCommandTests testBareBackspaceOnTableGoesBackAndNeverTrashes]' started.
Test Case '-[IHateFinderTests.KeyCommandTests testBareBackspaceOnTableGoesBackAndNeverTrashes]' passed (0.000 seconds).
Test Case '-[IHateFinderTests.KeyCommandTests testCommandBackspaceAndForwardDeleteTrash]' started.
Test Case '-[IHateFinderTests.KeyCommandTests testCommandBackspaceAndForwardDeleteTrash]' passed (0.000 seconds).
Test Case '-[IHateFinderTests.KeyCommandTests testCommandZIsLeftToTheMenu]' started.
Test Case '-[IHateFinderTests.KeyCommandTests testCommandZIsLeftToTheMenu]' passed (0.000 seconds).
Test Case '-[IHateFinderTests.KeyCommandTests testControlLettersInTextFieldBecomeFieldEditorActions]' started.
Test Case '-[IHateFinderTests.KeyCommandTests testControlLettersInTextFieldBecomeFieldEditorActions]' passed (0.000 seconds).
Test Case '-[IHateFinderTests.KeyCommandTests testControlLettersOnTableKeepListActions]' started.
Test Case '-[IHateFinderTests.KeyCommandTests testControlLettersOnTableKeepListActions]' passed (0.000 seconds).
Test Case '-[IHateFinderTests.KeyCommandTests testControlZAndShiftZAreSentThroughResponderChainInBothContexts]' started.
Test Case '-[IHateFinderTests.KeyCommandTests testControlZAndShiftZAreSentThroughResponderChainInBothContexts]' passed (0.000 seconds).
Test Case '-[IHateFinderTests.KeyCommandTests testFindShortcutsOpenFilterFromAnyContext]' started.
Test Case '-[IHateFinderTests.KeyCommandTests testFindShortcutsOpenFilterFromAnyContext]' passed (0.000 seconds).
Test Case '-[IHateFinderTests.KeyCommandTests testFunctionKeysAreUnchanged]' started.
Test Case '-[IHateFinderTests.KeyCommandTests testFunctionKeysAreUnchanged]' passed (0.000 seconds).
Test Case '-[IHateFinderTests.KeyCommandTests testOtherListShortcutsAreUnchanged]' started.
Test Case '-[IHateFinderTests.KeyCommandTests testOtherListShortcutsAreUnchanged]' passed (0.000 seconds).
Test Case '-[IHateFinderTests.KeyCommandTests testPathShortcutWorksEvenFromTextField]' started.
Test Case '-[IHateFinderTests.KeyCommandTests testPathShortcutWorksEvenFromTextField]' passed (0.000 seconds).
Test Suite 'KeyCommandTests' passed at 2026-10-10 00:06:09.640.
	 Executed 12 tests, with 0 failures (0 unexpected) in 0.001 (0.002) seconds
Test Suite 'OpenHandlingTests' started at 2026-10-10 00:06:09.640.
Test Case '-[IHateFinderTests.OpenHandlingTests testRevealNavigatesToParentAndSelectsFileWithoutChangingFiles]' started.
Test Case '-[IHateFinderTests.OpenHandlingTests testRevealNavigatesToParentAndSelectsFileWithoutChangingFiles]' passed (0.040 seconds).
Test Case '-[IHateFinderTests.OpenHandlingTests testShowFolderNavigatesFocusedPane]' started.
Test Case '-[IHateFinderTests.OpenHandlingTests testShowFolderNavigatesFocusedPane]' passed (0.045 seconds).
Test Suite 'OpenHandlingTests' passed at 2026-10-10 00:06:09.725.
	 Executed 2 tests, with 0 failures (0 unexpected) in 0.085 (0.085) seconds
Test Suite 'OpenRequestTests' started at 2026-10-10 00:06:09.725.
Test Case '-[IHateFinderTests.OpenRequestTests testAppPackageIsRevealedNotEntered]' started.
Test Case '-[IHateFinderTests.OpenRequestTests testAppPackageIsRevealedNotEntered]' passed (0.001 seconds).
Test Case '-[IHateFinderTests.OpenRequestTests testDescriptorListOfFileURLs]' started.
Test Case '-[IHateFinderTests.OpenRequestTests testDescriptorListOfFileURLs]' passed (0.001 seconds).
Test Case '-[IHateFinderTests.OpenRequestTests testDescriptorSingleFileURL]' started.
Test Case '-[IHateFinderTests.OpenRequestTests testDescriptorSingleFileURL]' passed (0.000 seconds).
Test Case '-[IHateFinderTests.OpenRequestTests testFileIsRevealedInItsParent]' started.
Test Case '-[IHateFinderTests.OpenRequestTests testFileIsRevealedInItsParent]' passed (0.000 seconds).
Test Case '-[IHateFinderTests.OpenRequestTests testFirstExistingURLWinsAndFailureIsReportedOnlyWhenNoneExist]' started.
Test Case '-[IHateFinderTests.OpenRequestTests testFirstExistingURLWinsAndFailureIsReportedOnlyWhenNoneExist]' passed (0.001 seconds).
Test Case '-[IHateFinderTests.OpenRequestTests testFolderIsShown]' started.
Test Case '-[IHateFinderTests.OpenRequestTests testFolderIsShown]' passed (0.000 seconds).
Test Case '-[IHateFinderTests.OpenRequestTests testMissingPathIsAFailureAndChangesNothing]' started.
Test Case '-[IHateFinderTests.OpenRequestTests testMissingPathIsAFailureAndChangesNothing]' passed (0.000 seconds).
Test Case '-[IHateFinderTests.OpenRequestTests testRequestsBeforeTheBrowserExistsAreQueuedAndDrainedExactlyOnce]' started.
Test Case '-[IHateFinderTests.OpenRequestTests testRequestsBeforeTheBrowserExistsAreQueuedAndDrainedExactlyOnce]' passed (0.000 seconds).
Test Case '-[IHateFinderTests.OpenRequestTests testSymlinkToFolderShowsTheTarget]' started.
Test Case '-[IHateFinderTests.OpenRequestTests testSymlinkToFolderShowsTheTarget]' passed (0.000 seconds).
Test Suite 'OpenRequestTests' passed at 2026-10-10 00:06:09.729.
	 Executed 9 tests, with 0 failures (0 unexpected) in 0.003 (0.004) seconds
Test Suite 'PaneDailyTests' started at 2026-10-10 00:06:09.729.
Test Case '-[IHateFinderTests.PaneDailyTests testGoUpSelectsTheFolderYouCameFrom]' started.
Test Case '-[IHateFinderTests.PaneDailyTests testGoUpSelectsTheFolderYouCameFrom]' passed (0.031 seconds).
Test Case '-[IHateFinderTests.PaneDailyTests testMakeFolderInBrowserSelectsTheNewFolderAndStartsRename]' started.
Test Case '-[IHateFinderTests.PaneDailyTests testMakeFolderInBrowserSelectsTheNewFolderAndStartsRename]' passed (0.081 seconds).
Test Case '-[IHateFinderTests.PaneDailyTests testNavigatingElsewhereClearsPendingReveal]' started.
Test Case '-[IHateFinderTests.PaneDailyTests testNavigatingElsewhereClearsPendingReveal]' passed (0.034 seconds).
Test Case '-[IHateFinderTests.PaneDailyTests testRevealAfterReloadSelectsAFileCreatedExternallyAfterTheCall]' started.
Test Case '-[IHateFinderTests.PaneDailyTests testRevealAfterReloadSelectsAFileCreatedExternallyAfterTheCall]' passed (0.035 seconds).
Test Suite 'PaneDailyTests' passed at 2026-10-10 00:06:09.911.
	 Executed 4 tests, with 0 failures (0 unexpected) in 0.182 (0.182) seconds
Test Suite 'PreviewAndFilterTests' started at 2026-10-10 00:06:09.911.
Test Case '-[IHateFinderTests.PreviewAndFilterTests testEnterOnSingleFolderNavigatesAndMultipleFoldersOpenNothing]' started.
Test Case '-[IHateFinderTests.PreviewAndFilterTests testEnterOnSingleFolderNavigatesAndMultipleFoldersOpenNothing]' passed (0.032 seconds).
Test Case '-[IHateFinderTests.PreviewAndFilterTests testEnterOpensEveryFileAndSkipsFoldersInMixedSelection]' started.
Test Case '-[IHateFinderTests.PreviewAndFilterTests testEnterOpensEveryFileAndSkipsFoldersInMixedSelection]' passed (0.027 seconds).
Test Case '-[IHateFinderTests.PreviewAndFilterTests testEscapeClearsAndHidesFilterAndRestoresRows]' started.
Test Case '-[IHateFinderTests.PreviewAndFilterTests testEscapeClearsAndHidesFilterAndRestoresRows]' passed (0.024 seconds).
Test Case '-[IHateFinderTests.PreviewAndFilterTests testExternalReloadKeepsFilterAndSelectionByURL]' started.
Test Case '-[IHateFinderTests.PreviewAndFilterTests testExternalReloadKeepsFilterAndSelectionByURL]' passed (0.039 seconds).
Test Case '-[IHateFinderTests.PreviewAndFilterTests testFilterHidesNonMatchingRowsAndDropsHiddenSelection]' started.
Test Case '-[IHateFinderTests.PreviewAndFilterTests testFilterHidesNonMatchingRowsAndDropsHiddenSelection]' passed (0.027 seconds).
Test Case '-[IHateFinderTests.PreviewAndFilterTests testMoreThanTwentyFilesAskFirst]' started.
Test Case '-[IHateFinderTests.PreviewAndFilterTests testMoreThanTwentyFilesAskFirst]' passed (0.026 seconds).
Test Case '-[IHateFinderTests.PreviewAndFilterTests testNavigationClearsFilter]' started.
Test Case '-[IHateFinderTests.PreviewAndFilterTests testNavigationClearsFilter]' passed (0.036 seconds).
Test Case '-[IHateFinderTests.PreviewAndFilterTests testPanelEscapeIsNotHandledAndArrowMovesListSelection]' started.
Test Case '-[IHateFinderTests.PreviewAndFilterTests testPanelEscapeIsNotHandledAndArrowMovesListSelection]' passed (0.025 seconds).
Test Case '-[IHateFinderTests.PreviewAndFilterTests testPendingRevealOfHiddenNewItemClearsFilter]' started.
Test Case '-[IHateFinderTests.PreviewAndFilterTests testPendingRevealOfHiddenNewItemClearsFilter]' passed (0.038 seconds).
Test Case '-[IHateFinderTests.PreviewAndFilterTests testPreviewDataSourceIsSelectionInRowOrder]' started.
Test Case '-[IHateFinderTests.PreviewAndFilterTests testPreviewDataSourceIsSelectionInRowOrder]' passed (0.026 seconds).
Test Case '-[IHateFinderTests.PreviewAndFilterTests testQuickLookKeyDetection]' started.
Test Case '-[IHateFinderTests.PreviewAndFilterTests testQuickLookKeyDetection]' passed (0.000 seconds).
Test Case '-[IHateFinderTests.PreviewAndFilterTests testSpaceInRenameEditorIsATypedCharacterNotPreview]' started.
Test Case '-[IHateFinderTests.PreviewAndFilterTests testSpaceInRenameEditorIsATypedCharacterNotPreview]' passed (0.030 seconds).
Test Suite 'PreviewAndFilterTests' passed at 2026-10-10 00:06:10.242.
	 Executed 12 tests, with 0 failures (0 unexpected) in 0.330 (0.331) seconds
Test Suite 'RenameUndoRoutingTests' started at 2026-10-10 00:06:10.242.
Test Case '-[IHateFinderTests.RenameUndoRoutingTests testUndoOnTheListStillReachesTheTableAndPopsTheJournal]' started.
Test Case '-[IHateFinderTests.RenameUndoRoutingTests testUndoOnTheListStillReachesTheTableAndPopsTheJournal]' passed (0.209 seconds).
Test Case '-[IHateFinderTests.RenameUndoRoutingTests testUndoWhileRenamingDoesNotReachTheTableOrTheJournal]' started.
Test Case '-[IHateFinderTests.RenameUndoRoutingTests testUndoWhileRenamingDoesNotReachTheTableOrTheJournal]' passed (0.210 seconds).
Test Suite 'RenameUndoRoutingTests' passed at 2026-10-10 00:06:10.661.
	 Executed 2 tests, with 0 failures (0 unexpected) in 0.419 (0.419) seconds
Test Suite 'UndoWiringTests' started at 2026-10-10 00:06:10.661.
Test Case '-[IHateFinderTests.UndoWiringTests testCreateFolderThenUndoMovesItToBinAndEmptiesJournal]' started.
Test Case '-[IHateFinderTests.UndoWiringTests testCreateFolderThenUndoMovesItToBinAndEmptiesJournal]' passed (0.080 seconds).
Test Case '-[IHateFinderTests.UndoWiringTests testCutAndPasteIntoTheSameFolderPushesNoRecord]' started.
Test Case '-[IHateFinderTests.UndoWiringTests testCutAndPasteIntoTheSameFolderPushesNoRecord]' passed (0.076 seconds).
Test Case '-[IHateFinderTests.UndoWiringTests testDropMovePushesARecordAndUndoMovesItBack]' started.
Test Case '-[IHateFinderTests.UndoWiringTests testDropMovePushesARecordAndUndoMovesItBack]' passed (0.082 seconds).
Test Case '-[IHateFinderTests.UndoWiringTests testPartialTrashKeepsReportAndRecordsOnlyTheFirstFileThenUndoRestoresIt]' started.
Test Case '-[IHateFinderTests.UndoWiringTests testPartialTrashKeepsReportAndRecordsOnlyTheFirstFileThenUndoRestoresIt]' passed (0.332 seconds).
Test Case '-[IHateFinderTests.UndoWiringTests testUndoIsRefusedWhileBusyAndDoesNotPop]' started.
Test Case '-[IHateFinderTests.UndoWiringTests testUndoIsRefusedWhileBusyAndDoesNotPop]' passed (0.343 seconds).
Test Case '-[IHateFinderTests.UndoWiringTests testUndoSkipsAndReportsAnItemChangedInBetween]' started.
Test Case '-[IHateFinderTests.UndoWiringTests testUndoSkipsAndReportsAnItemChangedInBetween]' passed (0.362 seconds).
Test Case '-[IHateFinderTests.UndoWiringTests testValidateMenuItemForUndoAndRedo]' started.
Test Case '-[IHateFinderTests.UndoWiringTests testValidateMenuItemForUndoAndRedo]' passed (0.076 seconds).
Test Suite 'UndoWiringTests' passed at 2026-10-10 00:06:12.014.
	 Executed 7 tests, with 0 failures (0 unexpected) in 1.352 (1.353) seconds
Test Suite 'IHateFinderTests.xctest' passed at 2026-10-10 00:06:12.014.
	 Executed 80 tests, with 0 failures (0 unexpected) in 4.853 (4.862) seconds
Test Suite 'All tests' passed at 2026-10-10 00:06:12.014.
	 Executed 80 tests, with 0 failures (0 unexpected) in 4.853 (4.863) seconds
Test Suite 'All tests' started at 2026-10-10 00:06:12.099.
Test Suite 'IHateFinderCoreTests.xctest' started at 2026-10-10 00:06:12.100.
Test Suite 'BrowserSessionTests' started at 2026-10-10 00:06:12.100.
Test Case '-[IHateFinderCoreTests.BrowserSessionTests testExternalCreateRenameDeleteAndFolderReplacementRefreshListing]' started.
Test Case '-[IHateFinderCoreTests.BrowserSessionTests testExternalCreateRenameDeleteAndFolderReplacementRefreshListing]' passed (0.988 seconds).
Test Case '-[IHateFinderCoreTests.BrowserSessionTests testFailedNavigationAndHistoryLoadsPreserveCommittedSnapshot]' started.
Test Case '-[IHateFinderCoreTests.BrowserSessionTests testFailedNavigationAndHistoryLoadsPreserveCommittedSnapshot]' passed (0.005 seconds).
Test Case '-[IHateFinderCoreTests.BrowserSessionTests testSlowSupersededReadCannotReplaceNewerDirectory]' started.
Test Case '-[IHateFinderCoreTests.BrowserSessionTests testSlowSupersededReadCannotReplaceNewerDirectory]' passed (0.308 seconds).
Test Case '-[IHateFinderCoreTests.BrowserSessionTests testSortAndHiddenChangesDuringNavigationKeepLatestTarget]' started.
Test Case '-[IHateFinderCoreTests.BrowserSessionTests testSortAndHiddenChangesDuringNavigationKeepLatestTarget]' passed (0.001 seconds).
Test Suite 'BrowserSessionTests' passed at 2026-10-10 00:06:13.404.
	 Executed 4 tests, with 0 failures (0 unexpected) in 1.303 (1.304) seconds
Test Suite 'CloneCopyTests' started at 2026-10-10 00:06:13.404.
Test Case '-[IHateFinderCoreTests.CloneCopyTests testCancellationAfterCloneButBeforeCommitKeepsOldTargetAndCleansStage]' started.
Test Case '-[IHateFinderCoreTests.CloneCopyTests testCancellationAfterCloneButBeforeCommitKeepsOldTargetAndCleansStage]' passed (0.006 seconds).
Test Case '-[IHateFinderCoreTests.CloneCopyTests testCancellationBeforeStartPublishesNothingAndLeavesNoStage]' started.
Test Case '-[IHateFinderCoreTests.CloneCopyTests testCancellationBeforeStartPublishesNothingAndLeavesNoStage]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.CloneCopyTests testCloneEnabledAcrossVolumesStillReportsIntermediateByteSamples]' started.
Test Case '-[IHateFinderCoreTests.CloneCopyTests testCloneEnabledAcrossVolumesStillReportsIntermediateByteSamples]' passed (0.029 seconds).
Test Case '-[IHateFinderCoreTests.CloneCopyTests testCloneReplaceStagesCopyAndSendsOldTargetThroughMoveToTrash]' started.
Test Case '-[IHateFinderCoreTests.CloneCopyTests testCloneReplaceStagesCopyAndSendsOldTargetThroughMoveToTrash]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.CloneCopyTests testCloneSeamIsUsedOnlyWhenEnabledAndOnSameVolume]' started.
Test Case '-[IHateFinderCoreTests.CloneCopyTests testCloneSeamIsUsedOnlyWhenEnabledAndOnSameVolume]' passed (0.003 seconds).
Test Case '-[IHateFinderCoreTests.CloneCopyTests testCrossVolumeMoveReportsSourceTrashURL]' started.
Test Case '-[IHateFinderCoreTests.CloneCopyTests testCrossVolumeMoveReportsSourceTrashURL]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.CloneCopyTests testCrossVolumeMoveWithReplaceReportsBothTrashURLs]' started.
Test Case '-[IHateFinderCoreTests.CloneCopyTests testCrossVolumeMoveWithReplaceReportsBothTrashURLs]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.CloneCopyTests testFailedTrashLeavesTrashURLFieldsNilButKeepsReplacementFlag]' started.
Test Case '-[IHateFinderCoreTests.CloneCopyTests testFailedTrashLeavesTrashURLFieldsNilButKeepsReplacementFlag]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.CloneCopyTests testKeepBothAndSkipDoNotReportReplacement]' started.
Test Case '-[IHateFinderCoreTests.CloneCopyTests testKeepBothAndSkipDoNotReportReplacement]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.CloneCopyTests testLegacyTrashClosureStillWorksAndYieldsNilTrashURLs]' started.
Test Case '-[IHateFinderCoreTests.CloneCopyTests testLegacyTrashClosureStillWorksAndYieldsNilTrashURLs]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.CloneCopyTests testMoveToTrashInitUsesTheSeamAndDefaultsCloneOff]' started.
Test Case '-[IHateFinderCoreTests.CloneCopyTests testMoveToTrashInitUsesTheSeamAndDefaultsCloneOff]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.CloneCopyTests testNativeCloneCopyChecksCancellationBeforeStarting]' started.
Test Case '-[IHateFinderCoreTests.CloneCopyTests testNativeCloneCopyChecksCancellationBeforeStarting]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.CloneCopyTests testPlainCopyAndMoveReportNoReplacementFields]' started.
Test Case '-[IHateFinderCoreTests.CloneCopyTests testPlainCopyAndMoveReportNoReplacementFields]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.CloneCopyTests testReplaceReportsReplacedExistingAndTrashURL]' started.
Test Case '-[IHateFinderCoreTests.CloneCopyTests testReplaceReportsReplacedExistingAndTrashURL]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.CloneCopyTests testSameVolumeCloneCopiesLargeFileWithMetadataAndWithoutByteProgress]' started.
Test Case '-[IHateFinderCoreTests.CloneCopyTests testSameVolumeCloneCopiesLargeFileWithMetadataAndWithoutByteProgress]' passed (0.017 seconds).
Test Case '-[IHateFinderCoreTests.CloneCopyTests testSameVolumeCloneKeepsNestedFilesAndDanglingSymlink]' started.
Test Case '-[IHateFinderCoreTests.CloneCopyTests testSameVolumeCloneKeepsNestedFilesAndDanglingSymlink]' passed (0.003 seconds).
Test Suite 'CloneCopyTests' passed at 2026-10-10 00:06:13.481.
	 Executed 16 tests, with 0 failures (0 unexpected) in 0.076 (0.078) seconds
Test Suite 'CompressTests' started at 2026-10-10 00:06:13.481.
Test Case '-[IHateFinderCoreTests.CompressTests testCancellationBeforeStartIsHonouredWithoutPublishing]' started.
Test Case '-[IHateFinderCoreTests.CompressTests testCancellationBeforeStartIsHonouredWithoutPublishing]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.CompressTests testCancellationTerminatesProcessAndLeavesNoPartialFileOrStage]' started.
Test Case '-[IHateFinderCoreTests.CompressTests testCancellationTerminatesProcessAndLeavesNoPartialFileOrStage]' passed (0.118 seconds).
Test Case '-[IHateFinderCoreTests.CompressTests testExistingZipIsNeverOverwritten]' started.
Test Case '-[IHateFinderCoreTests.CompressTests testExistingZipIsNeverOverwritten]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.CompressTests testMissingSourceFails]' started.
Test Case '-[IHateFinderCoreTests.CompressTests testMissingSourceFails]' passed (0.000 seconds).
Test Case '-[IHateFinderCoreTests.CompressTests testRealDittoZipsAFolderAndKeepsParent]' started.
Test Case '-[IHateFinderCoreTests.CompressTests testRealDittoZipsAFolderAndKeepsParent]' passed (0.028 seconds).
Test Case '-[IHateFinderCoreTests.CompressTests testRunnerFailureLeavesNoZipAndNoStage]' started.
Test Case '-[IHateFinderCoreTests.CompressTests testRunnerFailureLeavesNoZipAndNoStage]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.CompressTests testRunnerThatCannotStartLeavesNothing]' started.
Test Case '-[IHateFinderCoreTests.CompressTests testRunnerThatCannotStartLeavesNothing]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.CompressTests testSuccessCreatesNameZipAndSecondRunNumbersIt]' started.
Test Case '-[IHateFinderCoreTests.CompressTests testSuccessCreatesNameZipAndSecondRunNumbersIt]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.CompressTests testUndoRecordIsCreatedWithIdentityAndUndoTrashesTheZip]' started.
Test Case '-[IHateFinderCoreTests.CompressTests testUndoRecordIsCreatedWithIdentityAndUndoTrashesTheZip]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.CompressTests testUndoRefusesWhenTheZipWasReplacedByAnotherFile]' started.
Test Case '-[IHateFinderCoreTests.CompressTests testUndoRefusesWhenTheZipWasReplacedByAnotherFile]' passed (0.001 seconds).
Test Suite 'CompressTests' passed at 2026-10-10 00:06:13.638.
	 Executed 10 tests, with 0 failures (0 unexpected) in 0.156 (0.157) seconds
Test Suite 'DropPolicyTests' started at 2026-10-10 00:06:13.638.
Test Case '-[IHateFinderCoreTests.DropPolicyTests testCopyOnlyMaskCopiesEvenOnSameVolume]' started.
Test Case '-[IHateFinderCoreTests.DropPolicyTests testCopyOnlyMaskCopiesEvenOnSameVolume]' passed (0.000 seconds).
Test Case '-[IHateFinderCoreTests.DropPolicyTests testEmptyMaskRefusesTheDrop]' started.
Test Case '-[IHateFinderCoreTests.DropPolicyTests testEmptyMaskRefusesTheDrop]' passed (0.000 seconds).
Test Case '-[IHateFinderCoreTests.DropPolicyTests testGenericOnlyMovesAcrossVolumes]' started.
Test Case '-[IHateFinderCoreTests.DropPolicyTests testGenericOnlyMovesAcrossVolumes]' passed (0.000 seconds).
Test Case '-[IHateFinderCoreTests.DropPolicyTests testMixedSourcesAreNotAllOnDestinationVolumeSoCopy]' started.
Test Case '-[IHateFinderCoreTests.DropPolicyTests testMixedSourcesAreNotAllOnDestinationVolumeSoCopy]' passed (0.000 seconds).
Test Case '-[IHateFinderCoreTests.DropPolicyTests testMoveOnlyMoves]' started.
Test Case '-[IHateFinderCoreTests.DropPolicyTests testMoveOnlyMoves]' passed (0.000 seconds).
Test Case '-[IHateFinderCoreTests.DropPolicyTests testSameVolumeMovesAndDifferentVolumeCopiesWithFullMask]' started.
Test Case '-[IHateFinderCoreTests.DropPolicyTests testSameVolumeMovesAndDifferentVolumeCopiesWithFullMask]' passed (0.000 seconds).
Test Suite 'DropPolicyTests' passed at 2026-10-10 00:06:13.639.
	 Executed 6 tests, with 0 failures (0 unexpected) in 0.001 (0.001) seconds
Test Suite 'EntryFilterTests' started at 2026-10-10 00:06:13.639.
Test Case '-[IHateFinderCoreTests.EntryFilterTests testDiacriticsAreIgnored]' started.
Test Case '-[IHateFinderCoreTests.EntryFilterTests testDiacriticsAreIgnored]' passed (0.000 seconds).
Test Case '-[IHateFinderCoreTests.EntryFilterTests testEmptyAndWhitespaceQueriesKeepEverything]' started.
Test Case '-[IHateFinderCoreTests.EntryFilterTests testEmptyAndWhitespaceQueriesKeepEverything]' passed (0.000 seconds).
Test Case '-[IHateFinderCoreTests.EntryFilterTests testKoreanSubstringMatches]' started.
Test Case '-[IHateFinderCoreTests.EntryFilterTests testKoreanSubstringMatches]' passed (0.000 seconds).
Test Case '-[IHateFinderCoreTests.EntryFilterTests testMatchingIsCaseInsensitive]' started.
Test Case '-[IHateFinderCoreTests.EntryFilterTests testMatchingIsCaseInsensitive]' passed (0.000 seconds).
Test Case '-[IHateFinderCoreTests.EntryFilterTests testNoMatchGivesEmptyList]' started.
Test Case '-[IHateFinderCoreTests.EntryFilterTests testNoMatchGivesEmptyList]' passed (0.000 seconds).
Test Case '-[IHateFinderCoreTests.EntryFilterTests testQueryIsTrimmed]' started.
Test Case '-[IHateFinderCoreTests.EntryFilterTests testQueryIsTrimmed]' passed (0.000 seconds).
Test Suite 'EntryFilterTests' passed at 2026-10-10 00:06:13.640.
	 Executed 6 tests, with 0 failures (0 unexpected) in 0.001 (0.001) seconds
Test Suite 'FileOpsTests' started at 2026-10-10 00:06:13.640.
Test Case '-[IHateFinderCoreTests.FileOpsTests testConflictResolutionFailureStopsBeforeChangingEitherItem]' started.
Test Case '-[IHateFinderCoreTests.FileOpsTests testConflictResolutionFailureStopsBeforeChangingEitherItem]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileOpsTests testCopyIntoSameFolderKeepsBoth]' started.
Test Case '-[IHateFinderCoreTests.FileOpsTests testCopyIntoSameFolderKeepsBoth]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileOpsTests testCopyIntoSameFolderReplaceLeavesOriginal]' started.
Test Case '-[IHateFinderCoreTests.FileOpsTests testCopyIntoSameFolderReplaceLeavesOriginal]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileOpsTests testCopyKeepBothAndSkip]' started.
Test Case '-[IHateFinderCoreTests.FileOpsTests testCopyKeepBothAndSkip]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.FileOpsTests testCreateFolderAndTextFileNumberDuplicates]' started.
Test Case '-[IHateFinderCoreTests.FileOpsTests testCreateFolderAndTextFileNumberDuplicates]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileOpsTests testCrossVolumeMoveCopiesThenTrashes]' started.
Test Case '-[IHateFinderCoreTests.FileOpsTests testCrossVolumeMoveCopiesThenTrashes]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileOpsTests testCrossVolumeSourceTrashFailureKeepsBothCopiesAndCutItem]' started.
Test Case '-[IHateFinderCoreTests.FileOpsTests testCrossVolumeSourceTrashFailureKeepsBothCopiesAndCutItem]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.FileOpsTests testCutPasteIntoSameFolderLeavesFile]' started.
Test Case '-[IHateFinderCoreTests.FileOpsTests testCutPasteIntoSameFolderLeavesFile]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileOpsTests testFailedCrossVolumeCopyDoesNotTrashSourceOrPublishPartialDestination]' started.
Test Case '-[IHateFinderCoreTests.FileOpsTests testFailedCrossVolumeCopyDoesNotTrashSourceOrPublishPartialDestination]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileOpsTests testFailedDestinationRollbackReportsRecoverableOriginalLocation]' started.
Test Case '-[IHateFinderCoreTests.FileOpsTests testFailedDestinationRollbackReportsRecoverableOriginalLocation]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileOpsTests testFailedReplacementCopyPreservesOldDestinationAndSource]' started.
Test Case '-[IHateFinderCoreTests.FileOpsTests testFailedReplacementCopyPreservesOldDestinationAndSource]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileOpsTests testListHidesDotfilesUntilAsked]' started.
Test Case '-[IHateFinderCoreTests.FileOpsTests testListHidesDotfilesUntilAsked]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileOpsTests testMissingSameFolderCutIsFailedRatherThanCleared]' started.
Test Case '-[IHateFinderCoreTests.FileOpsTests testMissingSameFolderCutIsFailedRatherThanCleared]' passed (0.000 seconds).
Test Case '-[IHateFinderCoreTests.FileOpsTests testMoveReportsCompletedSkippedFailedAndUnprocessedItems]' started.
Test Case '-[IHateFinderCoreTests.FileOpsTests testMoveReportsCompletedSkippedFailedAndUnprocessedItems]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileOpsTests testNameSortKeepsFoldersOnTopWhenDescending]' started.
Test Case '-[IHateFinderCoreTests.FileOpsTests testNameSortKeepsFoldersOnTopWhenDescending]' passed (0.000 seconds).
Test Case '-[IHateFinderCoreTests.FileOpsTests testPartialCopyCleanupFailureReportsArtifact]' started.
Test Case '-[IHateFinderCoreTests.FileOpsTests testPartialCopyCleanupFailureReportsArtifact]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileOpsTests testRenameReplacementFailureRestoresBothItems]' started.
Test Case '-[IHateFinderCoreTests.FileOpsTests testRenameReplacementFailureRestoresBothItems]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileOpsTests testReplacementCommitFailureRestoresDestinationAndMovedSource]' started.
Test Case '-[IHateFinderCoreTests.FileOpsTests testReplacementCommitFailureRestoresDestinationAndMovedSource]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileOpsTests testReplaceSendsExistingToTrash]' started.
Test Case '-[IHateFinderCoreTests.FileOpsTests testReplaceSendsExistingToTrash]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.FileOpsTests testRollbackDoesNotOverwriteRecreatedSourceAndReportsStagedOriginal]' started.
Test Case '-[IHateFinderCoreTests.FileOpsTests testRollbackDoesNotOverwriteRecreatedSourceAndReportsStagedOriginal]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.FileOpsTests testSameVolumeMoveDoesNotTrashSource]' started.
Test Case '-[IHateFinderCoreTests.FileOpsTests testSameVolumeMoveDoesNotTrashSource]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileOpsTests testSuccessfulReplacementWithTrashFailureReportsPreservedBackup]' started.
Test Case '-[IHateFinderCoreTests.FileOpsTests testSuccessfulReplacementWithTrashFailureReportsPreservedBackup]' passed (0.001 seconds).
Test Suite 'FileOpsTests' passed at 2026-10-10 00:06:13.667.
	 Executed 22 tests, with 0 failures (0 unexpected) in 0.025 (0.027) seconds
Test Suite 'FileOutcomeTests' started at 2026-10-10 00:06:13.667.
Test Case '-[IHateFinderCoreTests.FileOutcomeTests testRenameKeepBothReportsTheRealDestination]' started.
Test Case '-[IHateFinderCoreTests.FileOutcomeTests testRenameKeepBothReportsTheRealDestination]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileOutcomeTests testRenameReplaceReportsReplacementAndTrashURL]' started.
Test Case '-[IHateFinderCoreTests.FileOutcomeTests testRenameReplaceReportsReplacementAndTrashURL]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileOutcomeTests testRenameSkipReportsSkippedAndChangesNothing]' started.
Test Case '-[IHateFinderCoreTests.FileOutcomeTests testRenameSkipReportsSkippedAndChangesNothing]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileOutcomeTests testRenameToSamePathReportsUnchanged]' started.
Test Case '-[IHateFinderCoreTests.FileOutcomeTests testRenameToSamePathReportsUnchanged]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileOutcomeTests testTrashUrlsStopsAtFirstFailureAndKeepsPartialResults]' started.
Test Case '-[IHateFinderCoreTests.FileOutcomeTests testTrashUrlsStopsAtFirstFailureAndKeepsPartialResults]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileOutcomeTests testTrashUrlsWithLegacyClosureReportsNilTrashURL]' started.
Test Case '-[IHateFinderCoreTests.FileOutcomeTests testTrashUrlsWithLegacyClosureReportsNilTrashURL]' passed (0.000 seconds).
Test Suite 'FileOutcomeTests' passed at 2026-10-10 00:06:13.673.
	 Executed 6 tests, with 0 failures (0 unexpected) in 0.005 (0.006) seconds
Test Suite 'FileTransferProgressTests' started at 2026-10-10 00:06:13.673.
Test Case '-[IHateFinderCoreTests.FileTransferProgressTests testByteThrottlingKeepsFinalSample]' started.
Test Case '-[IHateFinderCoreTests.FileTransferProgressTests testByteThrottlingKeepsFinalSample]' passed (0.017 seconds).
Test Case '-[IHateFinderCoreTests.FileTransferProgressTests testCancellationAfterConflictChoiceDoesNotStartReplacement]' started.
Test Case '-[IHateFinderCoreTests.FileTransferProgressTests testCancellationAfterConflictChoiceDoesNotStartReplacement]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileTransferProgressTests testCancellationBeforeCommitDiscardsCompleteUnpublishedCopy]' started.
Test Case '-[IHateFinderCoreTests.FileTransferProgressTests testCancellationBeforeCommitDiscardsCompleteUnpublishedCopy]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileTransferProgressTests testCancellationDuringCommittedMoveFinishesCurrentAndStopsNextItems]' started.
Test Case '-[IHateFinderCoreTests.FileTransferProgressTests testCancellationDuringCommittedMoveFinishesCurrentAndStopsNextItems]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.FileTransferProgressTests testDirectoryCopyReportsNestedFilesAndRetainsDanglingSymlink]' started.
Test Case '-[IHateFinderCoreTests.FileTransferProgressTests testDirectoryCopyReportsNestedFilesAndRetainsDanglingSymlink]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.FileTransferProgressTests testMidFileCancellationPreservesSourceAndOldTargetAndCleansPartialStage]' started.
Test Case '-[IHateFinderCoreTests.FileTransferProgressTests testMidFileCancellationPreservesSourceAndOldTargetAndCleansPartialStage]' passed (0.020 seconds).
Test Case '-[IHateFinderCoreTests.FileTransferProgressTests testSingleFileReportsIntermediateBytesAndMetadataIsPreserved]' started.
Test Case '-[IHateFinderCoreTests.FileTransferProgressTests testSingleFileReportsIntermediateBytesAndMetadataIsPreserved]' passed (0.175 seconds).
Test Suite 'FileTransferProgressTests' passed at 2026-10-10 00:06:13.891.
	 Executed 7 tests, with 0 failures (0 unexpected) in 0.217 (0.218) seconds
Test Suite 'FileUndoSafetyTests' started at 2026-10-10 00:06:13.891.
Test Case '-[IHateFinderCoreTests.FileUndoSafetyTests testCaseOnlyRenameUndoOnACaseSensitiveVolume]' started.
Test Case '-[IHateFinderCoreTests.FileUndoSafetyTests testCaseOnlyRenameUndoOnACaseSensitiveVolume]' passed (12.005 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoSafetyTests testCopiesAndSameVolumeStagedReplaceReportMovedInPlaceCorrectly]' started.
Test Case '-[IHateFinderCoreTests.FileUndoSafetyTests testCopiesAndSameVolumeStagedReplaceReportMovedInPlaceCorrectly]' passed (0.003 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoSafetyTests testCrossVolumeMoveThatReplacedAnItemUndoRestoresAllThree]' started.
Test Case '-[IHateFinderCoreTests.FileUndoSafetyTests testCrossVolumeMoveThatReplacedAnItemUndoRestoresAllThree]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoSafetyTests testCrossVolumeReplaceUndoWithUntrashableCopyMentionsTheOldItemStaysInTheBin]' started.
Test Case '-[IHateFinderCoreTests.FileUndoSafetyTests testCrossVolumeReplaceUndoWithUntrashableCopyMentionsTheOldItemStaysInTheBin]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoSafetyTests testCrossVolumeUndoThatCannotTrashTheCopyIsPartialAndNamesWhereTheCopyStays]' started.
Test Case '-[IHateFinderCoreTests.FileUndoSafetyTests testCrossVolumeUndoThatCannotTrashTheCopyIsPartialAndNamesWhereTheCopyStays]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoSafetyTests testFileIDReadReturnsNilWhenVolumeHasNoPersistentIDs]' started.
Test Case '-[IHateFinderCoreTests.FileUndoSafetyTests testFileIDReadReturnsNilWhenVolumeHasNoPersistentIDs]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoSafetyTests testIdentityRecordedNormallyButUndoRunsOnNonPersistentVolumeIsUnverifiable]' started.
Test Case '-[IHateFinderCoreTests.FileUndoSafetyTests testIdentityRecordedNormallyButUndoRunsOnNonPersistentVolumeIsUnverifiable]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoSafetyTests testNonPersistentIDVolumeMakesRecordsUnverifiableAndNothingMoves]' started.
Test Case '-[IHateFinderCoreTests.FileUndoSafetyTests testNonPersistentIDVolumeMakesRecordsUnverifiableAndNothingMoves]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoSafetyTests testRealTempVolumeReportsPersistentIDSupportConsistentWithTheFlag]' started.
Test Case '-[IHateFinderCoreTests.FileUndoSafetyTests testRealTempVolumeReportsPersistentIDSupportConsistentWithTheFlag]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoSafetyTests testRecordForCrossVolumeItemKeepsSourceTrashEvenWhenParentFoldersLookSameVolume]' started.
Test Case '-[IHateFinderCoreTests.FileUndoSafetyTests testRecordForCrossVolumeItemKeepsSourceTrashEvenWhenParentFoldersLookSameVolume]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoSafetyTests testRecordUsesTheItemLevelSameVolumeDecisionNotTheParentFolders]' started.
Test Case '-[IHateFinderCoreTests.FileUndoSafetyTests testRecordUsesTheItemLevelSameVolumeDecisionNotTheParentFolders]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoSafetyTests testReplaceCopyUndoWhoseBinItemCannotBeMovedIsPartialAndNamesTheBinPath]' started.
Test Case '-[IHateFinderCoreTests.FileUndoSafetyTests testReplaceCopyUndoWhoseBinItemCannotBeMovedIsPartialAndNamesTheBinPath]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoSafetyTests testReplaceCopyUndoWhoseOldSlotGetsTakenIsPartialAndNamesTheBinPath]' started.
Test Case '-[IHateFinderCoreTests.FileUndoSafetyTests testReplaceCopyUndoWhoseOldSlotGetsTakenIsPartialAndNamesTheBinPath]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoSafetyTests testTwoSameNamedCopiesInOneBatchUndoTrashesTheRightItems]' started.
Test Case '-[IHateFinderCoreTests.FileUndoSafetyTests testTwoSameNamedCopiesInOneBatchUndoTrashesTheRightItems]' passed (0.003 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoSafetyTests testTwoSameNamedSourcesInOneBatchKeepTheirOwnIdentitiesAndUndoRestoresBoth]' started.
Test Case '-[IHateFinderCoreTests.FileUndoSafetyTests testTwoSameNamedSourcesInOneBatchKeepTheirOwnIdentitiesAndUndoRestoresBoth]' passed (0.002 seconds).
Test Suite 'FileUndoSafetyTests' passed at 2026-10-10 00:06:25.922.
	 Executed 15 tests, with 0 failures (0 unexpected) in 12.029 (12.031) seconds
Test Suite 'FileUndoTests' started at 2026-10-10 00:06:25.922.
Test Case '-[IHateFinderCoreTests.FileUndoTests testBinItemRemovedBeforeUndoIsMissing]' started.
Test Case '-[IHateFinderCoreTests.FileUndoTests testBinItemRemovedBeforeUndoIsMissing]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoTests testCaseOnlyRenameUndoRestoresOriginalCase]' started.
Test Case '-[IHateFinderCoreTests.FileUndoTests testCaseOnlyRenameUndoRestoresOriginalCase]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoTests testCopyUndoTrashesTheCopyAndKeepsTheSource]' started.
Test Case '-[IHateFinderCoreTests.FileUndoTests testCopyUndoTrashesTheCopyAndKeepsTheSource]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoTests testCreateUndoAfterReplacementByDifferentFileIsStaleAndTrashesNothing]' started.
Test Case '-[IHateFinderCoreTests.FileUndoTests testCreateUndoAfterReplacementByDifferentFileIsStaleAndTrashesNothing]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoTests testCreateUndoOfMissingItemIsMissing]' started.
Test Case '-[IHateFinderCoreTests.FileUndoTests testCreateUndoOfMissingItemIsMissing]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoTests testCreateUndoTrashesTheItem]' started.
Test Case '-[IHateFinderCoreTests.FileUndoTests testCreateUndoTrashesTheItem]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoTests testCrossVolumeMoveUndoRestoresOriginalFromBinAndTrashesTheCopy]' started.
Test Case '-[IHateFinderCoreTests.FileUndoTests testCrossVolumeMoveUndoRestoresOriginalFromBinAndTrashesTheCopy]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoTests testCrossVolumeMoveUndoWithoutSourceTrashURLIsNotRestorableAndChangesNothing]' started.
Test Case '-[IHateFinderCoreTests.FileUndoTests testCrossVolumeMoveUndoWithoutSourceTrashURLIsNotRestorableAndChangesNothing]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoTests testJournalIsLifoAndKeepsAtMostFiftyRecords]' started.
Test Case '-[IHateFinderCoreTests.FileUndoTests testJournalIsLifoAndKeepsAtMostFiftyRecords]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoTests testKeepBothRenameUndoMovesNewNameBackAndLeavesExistingItem]' started.
Test Case '-[IHateFinderCoreTests.FileUndoTests testKeepBothRenameUndoMovesNewNameBackAndLeavesExistingItem]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoTests testNilIdentityIsUnverifiableAndNothingMoves]' started.
Test Case '-[IHateFinderCoreTests.FileUndoTests testNilIdentityIsUnverifiableAndNothingMoves]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoTests testPartialTrashReportRecordsOnlyTrashedItems]' started.
Test Case '-[IHateFinderCoreTests.FileUndoTests testPartialTrashReportRecordsOnlyTrashedItems]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoTests testRecordsExcludeSkippedFailedCancelledAndUnprocessedItems]' started.
Test Case '-[IHateFinderCoreTests.FileUndoTests testRecordsExcludeSkippedFailedCancelledAndUnprocessedItems]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoTests testRenameRecordIsNilForSkipUnchangedAndTitlesReflectOperation]' started.
Test Case '-[IHateFinderCoreTests.FileUndoTests testRenameRecordIsNilForSkipUnchangedAndTitlesReflectOperation]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoTests testRenameReplaceUndoRestoresTheReplacedItemFromTheBin]' started.
Test Case '-[IHateFinderCoreTests.FileUndoTests testRenameReplaceUndoRestoresTheReplacedItemFromTheBin]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoTests testRenameUndoWithOldNameTakenIsOccupiedAndNothingMoves]' started.
Test Case '-[IHateFinderCoreTests.FileUndoTests testRenameUndoWithOldNameTakenIsOccupiedAndNothingMoves]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoTests testReplaceCopyUndoTrashesNewItemAndRestoresOldOneFromBin]' started.
Test Case '-[IHateFinderCoreTests.FileUndoTests testReplaceCopyUndoTrashesNewItemAndRestoresOldOneFromBin]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoTests testReplaceCopyUndoWithNilReplacedTrashURLIsNotRestorableAndKeepsNewItem]' started.
Test Case '-[IHateFinderCoreTests.FileUndoTests testReplaceCopyUndoWithNilReplacedTrashURLIsNotRestorableAndKeepsNewItem]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoTests testReplacedTrashSwappedMakesReplaceCopyUndoStaleAndLeavesNewItem]' started.
Test Case '-[IHateFinderCoreTests.FileUndoTests testReplacedTrashSwappedMakesReplaceCopyUndoStaleAndLeavesNewItem]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoTests testReplaceMoveUndoMovesBackAndRestoresOldItem]' started.
Test Case '-[IHateFinderCoreTests.FileUndoTests testReplaceMoveUndoMovesBackAndRestoresOldItem]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoTests testSameFolderMoveIsANoOpWithoutRecord]' started.
Test Case '-[IHateFinderCoreTests.FileUndoTests testSameFolderMoveIsANoOpWithoutRecord]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoTests testSameVolumeMoveUndoIsOccupiedWhenOriginalSpotIsTaken]' started.
Test Case '-[IHateFinderCoreTests.FileUndoTests testSameVolumeMoveUndoIsOccupiedWhenOriginalSpotIsTaken]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoTests testSameVolumeMoveUndoMovesItBack]' started.
Test Case '-[IHateFinderCoreTests.FileUndoTests testSameVolumeMoveUndoMovesItBack]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoTests testSourceTrashSwappedMakesCrossVolumeMoveUndoStaleAndMovesNothing]' started.
Test Case '-[IHateFinderCoreTests.FileUndoTests testSourceTrashSwappedMakesCrossVolumeMoveUndoStaleAndMovesNothing]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoTests testTrashedItemWhoseBinFileWasSwappedIsStaleAndNotMoved]' started.
Test Case '-[IHateFinderCoreTests.FileUndoTests testTrashedItemWhoseBinFileWasSwappedIsStaleAndNotMoved]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoTests testTrashRecordIsNilWhenNothingWasTrashedOrTrashURLUnknown]' started.
Test Case '-[IHateFinderCoreTests.FileUndoTests testTrashRecordIsNilWhenNothingWasTrashedOrTrashURLUnknown]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoTests testTrashUndoRestoresMultipleItemsAndSkipsOnlyTheBlockedOne]' started.
Test Case '-[IHateFinderCoreTests.FileUndoTests testTrashUndoRestoresMultipleItemsAndSkipsOnlyTheBlockedOne]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoTests testTrashUndoRestoresTheItem]' started.
Test Case '-[IHateFinderCoreTests.FileUndoTests testTrashUndoRestoresTheItem]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoTests testTrashUndoWithMissingParentIsMissing]' started.
Test Case '-[IHateFinderCoreTests.FileUndoTests testTrashUndoWithMissingParentIsMissing]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.FileUndoTests testTrashUndoWithOriginalPathReoccupiedIsOccupiedAndBothItemsIntact]' started.
Test Case '-[IHateFinderCoreTests.FileUndoTests testTrashUndoWithOriginalPathReoccupiedIsOccupiedAndBothItemsIntact]' passed (0.001 seconds).
Test Suite 'FileUndoTests' passed at 2026-10-10 00:06:25.962.
	 Executed 30 tests, with 0 failures (0 unexpected) in 0.038 (0.040) seconds
Test Suite 'InfoAndMenuStateTests' started at 2026-10-10 00:06:25.962.
Test Case '-[IHateFinderCoreTests.InfoAndMenuStateTests testCommonAppsKeepsOnlySharedAppsWithDefaultFirst]' started.
Test Case '-[IHateFinderCoreTests.InfoAndMenuStateTests testCommonAppsKeepsOnlySharedAppsWithDefaultFirst]' passed (0.000 seconds).
Test Case '-[IHateFinderCoreTests.InfoAndMenuStateTests testCountCanBeSkippedForTheMainThread]' started.
Test Case '-[IHateFinderCoreTests.InfoAndMenuStateTests testCountCanBeSkippedForTheMainThread]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.InfoAndMenuStateTests testEmptySelectionDisablesEverythingButTerminal]' started.
Test Case '-[IHateFinderCoreTests.InfoAndMenuStateTests testEmptySelectionDisablesEverythingButTerminal]' passed (0.000 seconds).
Test Case '-[IHateFinderCoreTests.InfoAndMenuStateTests testFileInfoHasSizePermissionsAndNoCount]' started.
Test Case '-[IHateFinderCoreTests.InfoAndMenuStateTests testFileInfoHasSizePermissionsAndNoCount]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.InfoAndMenuStateTests testFolderInfoCountsOnlyTopLevelItems]' started.
Test Case '-[IHateFinderCoreTests.InfoAndMenuStateTests testFolderInfoCountsOnlyTopLevelItems]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.InfoAndMenuStateTests testMissingItemHasNoModel]' started.
Test Case '-[IHateFinderCoreTests.InfoAndMenuStateTests testMissingItemHasNoModel]' passed (0.000 seconds).
Test Case '-[IHateFinderCoreTests.InfoAndMenuStateTests testMultiSelectionEnablesCopyPathButNotCompressOrInfo]' started.
Test Case '-[IHateFinderCoreTests.InfoAndMenuStateTests testMultiSelectionEnablesCopyPathButNotCompressOrInfo]' passed (0.000 seconds).
Test Case '-[IHateFinderCoreTests.InfoAndMenuStateTests testPathTextIsNewlineSeparatedPosixPaths]' started.
Test Case '-[IHateFinderCoreTests.InfoAndMenuStateTests testPathTextIsNewlineSeparatedPosixPaths]' passed (0.000 seconds).
Test Case '-[IHateFinderCoreTests.InfoAndMenuStateTests testPermissionText]' started.
Test Case '-[IHateFinderCoreTests.InfoAndMenuStateTests testPermissionText]' passed (0.000 seconds).
Test Case '-[IHateFinderCoreTests.InfoAndMenuStateTests testSingleSelectionEnablesCompressAndInfo]' started.
Test Case '-[IHateFinderCoreTests.InfoAndMenuStateTests testSingleSelectionEnablesCompressAndInfo]' passed (0.000 seconds).
Test Case '-[IHateFinderCoreTests.InfoAndMenuStateTests testTerminalFolderIsSelectedFolderElseCurrentFolder]' started.
Test Case '-[IHateFinderCoreTests.InfoAndMenuStateTests testTerminalFolderIsSelectedFolderElseCurrentFolder]' passed (0.000 seconds).
Test Suite 'InfoAndMenuStateTests' passed at 2026-10-10 00:06:25.967.
	 Executed 11 tests, with 0 failures (0 unexpected) in 0.004 (0.005) seconds
Test Suite 'OpenPlanTests' started at 2026-10-10 00:06:25.967.
Test Case '-[IHateFinderCoreTests.OpenPlanTests testEmptySelectionHasNoPlan]' started.
Test Case '-[IHateFinderCoreTests.OpenPlanTests testEmptySelectionHasNoPlan]' passed (0.000 seconds).
Test Case '-[IHateFinderCoreTests.OpenPlanTests testFilesOnlyOpensAllWithoutConfirmation]' started.
Test Case '-[IHateFinderCoreTests.OpenPlanTests testFilesOnlyOpensAllWithoutConfirmation]' passed (0.000 seconds).
Test Case '-[IHateFinderCoreTests.OpenPlanTests testMixedSelectionOpensFilesOnly]' started.
Test Case '-[IHateFinderCoreTests.OpenPlanTests testMixedSelectionOpensFilesOnly]' passed (0.000 seconds).
Test Case '-[IHateFinderCoreTests.OpenPlanTests testMultipleFoldersAreRefusedWithReason]' started.
Test Case '-[IHateFinderCoreTests.OpenPlanTests testMultipleFoldersAreRefusedWithReason]' passed (0.000 seconds).
Test Case '-[IHateFinderCoreTests.OpenPlanTests testSingleFolderNavigates]' started.
Test Case '-[IHateFinderCoreTests.OpenPlanTests testSingleFolderNavigates]' passed (0.000 seconds).
Test Case '-[IHateFinderCoreTests.OpenPlanTests testTwentyOneFilesNeedConfirmationButTwentyDoNot]' started.
Test Case '-[IHateFinderCoreTests.OpenPlanTests testTwentyOneFilesNeedConfirmationButTwentyDoNot]' passed (0.000 seconds).
Test Suite 'OpenPlanTests' passed at 2026-10-10 00:06:25.968.
	 Executed 6 tests, with 0 failures (0 unexpected) in 0.001 (0.001) seconds
Test Suite 'RenameSelectionTests' started at 2026-10-10 00:06:25.968.
Test Case '-[IHateFinderCoreTests.RenameSelectionTests testDotfilesSelectWholeName]' started.
Test Case '-[IHateFinderCoreTests.RenameSelectionTests testDotfilesSelectWholeName]' passed (0.000 seconds).
Test Case '-[IHateFinderCoreTests.RenameSelectionTests testDotfileWithExtensionSelectsStem]' started.
Test Case '-[IHateFinderCoreTests.RenameSelectionTests testDotfileWithExtensionSelectsStem]' passed (0.000 seconds).
Test Case '-[IHateFinderCoreTests.RenameSelectionTests testFilesSelectStemOnly]' started.
Test Case '-[IHateFinderCoreTests.RenameSelectionTests testFilesSelectStemOnly]' passed (0.000 seconds).
Test Case '-[IHateFinderCoreTests.RenameSelectionTests testFoldersSelectWholeNameEvenWithDot]' started.
Test Case '-[IHateFinderCoreTests.RenameSelectionTests testFoldersSelectWholeNameEvenWithDot]' passed (0.000 seconds).
Test Case '-[IHateFinderCoreTests.RenameSelectionTests testNameWithoutExtensionSelectsWholeName]' started.
Test Case '-[IHateFinderCoreTests.RenameSelectionTests testNameWithoutExtensionSelectsWholeName]' passed (0.000 seconds).
Test Case '-[IHateFinderCoreTests.RenameSelectionTests testPackageSelectsStem]' started.
Test Case '-[IHateFinderCoreTests.RenameSelectionTests testPackageSelectsStem]' passed (0.000 seconds).
Test Case '-[IHateFinderCoreTests.RenameSelectionTests testRangeIsUTF16ForKoreanNames]' started.
Test Case '-[IHateFinderCoreTests.RenameSelectionTests testRangeIsUTF16ForKoreanNames]' passed (0.000 seconds).
Test Suite 'RenameSelectionTests' passed at 2026-10-10 00:06:25.970.
	 Executed 7 tests, with 0 failures (0 unexpected) in 0.001 (0.001) seconds
Test Suite 'TrashMessageTests' started at 2026-10-10 00:06:25.970.
Test Case '-[IHateFinderCoreTests.TrashMessageTests testGenericErrorGivesSameMessageWithoutHint]' started.
Test Case '-[IHateFinderCoreTests.TrashMessageTests testGenericErrorGivesSameMessageWithoutHint]' passed (0.000 seconds).
Test Case '-[IHateFinderCoreTests.TrashMessageTests testReadOnlyVolumeErrorAddsTheHint]' started.
Test Case '-[IHateFinderCoreTests.TrashMessageTests testReadOnlyVolumeErrorAddsTheHint]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.TrashMessageTests testSuccessfulReportHasNoMessage]' started.
Test Case '-[IHateFinderCoreTests.TrashMessageTests testSuccessfulReportHasNoMessage]' passed (0.000 seconds).
Test Case '-[IHateFinderCoreTests.TrashMessageTests testUnrelatedCocoaErrorGetsNoHint]' started.
Test Case '-[IHateFinderCoreTests.TrashMessageTests testUnrelatedCocoaErrorGetsNoHint]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.TrashMessageTests testUnsupportedVolumeErrorAddsTheHint]' started.
Test Case '-[IHateFinderCoreTests.TrashMessageTests testUnsupportedVolumeErrorAddsTheHint]' passed (0.001 seconds).
Test Suite 'TrashMessageTests' passed at 2026-10-10 00:06:25.972.
	 Executed 5 tests, with 0 failures (0 unexpected) in 0.002 (0.003) seconds
Test Suite 'WorkspaceRestoreTests' started at 2026-10-10 00:06:25.972.
Test Case '-[IHateFinderCoreTests.WorkspaceRestoreTests testAllUnavailableCandidatesStopAndManualRetryDoesNotRestartFallback]' started.
Test Case '-[IHateFinderCoreTests.WorkspaceRestoreTests testAllUnavailableCandidatesStopAndManualRetryDoesNotRestartFallback]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.WorkspaceRestoreTests testCorruptOrIncompleteSavedDataUsesSafeDefaults]' started.
Test Case '-[IHateFinderCoreTests.WorkspaceRestoreTests testCorruptOrIncompleteSavedDataUsesSafeDefaults]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.WorkspaceRestoreTests testDeniedSavedAndHomeFoldersFallBackToTemporaryDirectory]' started.
Test Case '-[IHateFinderCoreTests.WorkspaceRestoreTests testDeniedSavedAndHomeFoldersFallBackToTemporaryDirectory]' passed (0.000 seconds).
Test Case '-[IHateFinderCoreTests.WorkspaceRestoreTests testIdenticalFallbackCandidatesAreAttemptedOnlyOnce]' started.
Test Case '-[IHateFinderCoreTests.WorkspaceRestoreTests testIdenticalFallbackCandidatesAreAttemptedOnlyOnce]' passed (0.000 seconds).
Test Case '-[IHateFinderCoreTests.WorkspaceRestoreTests testIndependentPaneConfigurationAndSinglePaneSurviveRelaunch]' started.
Test Case '-[IHateFinderCoreTests.WorkspaceRestoreTests testIndependentPaneConfigurationAndSinglePaneSurviveRelaunch]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.WorkspaceRestoreTests testLegacyCutAndJobPayloadCannotRestoreOrExecuteOperations]' started.
Test Case '-[IHateFinderCoreTests.WorkspaceRestoreTests testLegacyCutAndJobPayloadCannotRestoreOrExecuteOperations]' passed (0.002 seconds).
Test Case '-[IHateFinderCoreTests.WorkspaceRestoreTests testMissingSavedFolderFallsBackHomeAndLaterErrorsStayOnCommittedFolder]' started.
Test Case '-[IHateFinderCoreTests.WorkspaceRestoreTests testMissingSavedFolderFallsBackHomeAndLaterErrorsStayOnCommittedFolder]' passed (0.000 seconds).
Test Case '-[IHateFinderCoreTests.WorkspaceRestoreTests testStartupAndPendingNavigationNeverOverwriteCommittedFolders]' started.
Test Case '-[IHateFinderCoreTests.WorkspaceRestoreTests testStartupAndPendingNavigationNeverOverwriteCommittedFolders]' passed (0.001 seconds).
Test Case '-[IHateFinderCoreTests.WorkspaceRestoreTests testUserNavigationSupersedesSlowStartupFailureWithoutFallbackOrHistoryPollution]' started.
Test Case '-[IHateFinderCoreTests.WorkspaceRestoreTests testUserNavigationSupersedesSlowStartupFailureWithoutFallbackOrHistoryPollution]' passed (0.302 seconds).
Test Suite 'WorkspaceRestoreTests' passed at 2026-10-10 00:06:26.283.
	 Executed 9 tests, with 0 failures (0 unexpected) in 0.310 (0.310) seconds
Test Suite 'IHateFinderCoreTests.xctest' passed at 2026-10-10 00:06:26.283.
	 Executed 160 tests, with 0 failures (0 unexpected) in 14.169 (14.183) seconds
Test Suite 'All tests' passed at 2026-10-10 00:06:26.283.
	 Executed 160 tests, with 0 failures (0 unexpected) in 14.169 (14.184) seconds
◇ Test run started.
↳ Testing Library Version: 2084
↳ Target Platform: arm64e-apple-macos14.0
✔ Test run with 0 tests in 0 suites passed after 0.001 seconds.
◇ Test run started.
↳ Testing Library Version: 2084
↳ Target Platform: arm64e-apple-macos14.0
✔ Test run with 0 tests in 0 suites passed after 0.001 seconds.
