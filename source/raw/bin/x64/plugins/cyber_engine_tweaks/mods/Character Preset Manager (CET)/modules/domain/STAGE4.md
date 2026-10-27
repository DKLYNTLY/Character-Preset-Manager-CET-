# Stage 4 storage and recovery audit

Baseline: `f776ec1673d7f4189d169a33d9570c3dcac26881`. I recorded these paths before extracting code. References below include definitions; the forwarding inventory after extraction distinguishes remaining calls.

## Before extraction: functions and references

| Function | Baseline references and line numbers |
|---|---|
| `fileExists` | `backup.lua:72,73,211,268,341`; `bundles.lua:75,197,198`; `events.lua:79`; `filesystem.lua:9,232,348,446`; `folders.lua:325,355`; `history.lua:79,87,150,152`; `presets.lua:536`; `trash.lua:193,206,222,224,227,322,335` |
| `fileFingerprint` | `backup.lua:249,396`; `bundles.lua:102,119,522,536,598`; `catalog.lua:88`; `filesystem.lua:20`; `presets.lua:79,220,266,316`; `trash.lua:346,363,401,519,637,782` |
| `safeDirectoryEntries` | `backup.lua:47`; `bundles.lua:51`; `catalog.lua:47`; `filesystem.lua:76,104,118`; `native_catalog.lua:152`; `trash.lua:250`; `view_cache.lua:218` |
| `directoryTreeContainsFiles` | `filesystem.lua:103,108`; `folders.lua:379`; `trash.lua:942` |
| `removeEmptyDirectoryTree` | `filesystem.lua:117,122`; `folders.lua:380`; `trash.lua:943` |
| `writeFileSafely` | `acu_import.lua:183`; `backup.lua:160,383,417,428`; `bundles.lua:206,462`; `filesystem.lua:238,256,263`; `native_bridge.lua:22`; `presets.lua:160,175,185`; `ui/draw.lua:32` |
| `atomicReplace` | `acu_import.lua:182`; `backup.lua:159,382,416,427`; `bundles.lua:205,461`; `filesystem.lua:344`; `presets.lua:174,184,216` |
| `readBoundedFile` | `acu_import.lua:12`; `backup.lua:153,415`; `bundles.lua:140`; `catalog.lua:408`; `filesystem.lua:386`; `native_bridge.lua:41`; `native_catalog.lua:41`; `presets.lua:172`; `trash.lua:59,139` |
| `copyFile` | `filesystem.lua:404`; `folders.lua:202`; `presets.lua:798` |
| `removeFileList` | `backup.lua:377,389,390,399,411,425`; `filesystem.lua:443`; `presets.lua:271,437` |
| `writeLinesIfChanged` | `bundles.lua:188`; `catalog.lua:392,475`; `presets.lua:169`; `trash.lua:49,133` |
| `validTrashFilename` | `trash.lua:9,10,16,73,120,154` |
| `trashCatalogLines` | `trash.lua:13,44` |
| `writeTrashCatalog` | `trash.lua:42,278,455,463,526,535,660,672,735,900,914` |
| `readTrashCatalog` | `trash.lua:57,243` |
| `writeTransaction` | `folders.lua:317`; `presets.lua:546`; `trash.lua:192,441,505,605,831` |
| `readTransaction` | `trash.lua:138,197` |
| `completeTransaction` | `folders.lua:347`; `presets.lua:564`; `trash.lua:456,527,662,901` |
| `recoverTransaction` | `events.lua:255` |

The direct `os.rename` and `os.remove` calls in preset, folder, Trash, history, sharing, and backup adapters keep their existing argument order and error handling. The new file adapter supplies those same primitives. Logging, confirmation clearing, and loader resets stay in the compatibility adapters at their old call sites.

## Guarantees

These are code-level guarantees, not an operating-system durability promise. The old code does not fsync files or directories, and a successful close does not establish persistence after a power failure.

| Operation | Before mutation / write failure | Interruption after a file change | Metadata, completion, and rollback order |
|---|---|---|---|
| Save / overwrite | Write and verify `.tmp` before replacing the target. If target is missing and `.bak` exists, first rename backup to target. | Direct replacement is tried first. If it fails, remove old `.bak`, move original to `.bak`, then install `.tmp`. A crash can leave any of these three files. | On install failure, restore `.bak` first; remove `.tmp` only if restoration succeeds. On catalog failure, rewrite the previous preset or delete a newly created file. Inventory failure warns after success; save has no journal. |
| Rename preset | Write prepared rename journal before physical rename. Failed rename attempts to delete journal. | Prepared recovery walks plans forward and renames destination back only if source is absent. If both exist it leaves both. If neither exists recovery fails. | Persist library/catalog and inventory, then write committed journal and remove it. On failure restore in-memory mapping, rename back, repair catalog as needed; only afterward remove journal. Physical rollback failure retains journal. |
| Move to folder | Usually a logical catalog move with a preset-folder rewrite. No transaction spans these writes. | A crash can leave preset header and folder catalog out of sync. | Preserve original metadata restoration and catalog writes. Bulk logical moves keep earlier completed moves if a later item fails; each failing item attempts its own metadata rollback. Imported-folder removal relocates physical files under a prepared rename journal and rolls moved files back in reverse order. |
| Trash | Prepared journal precedes moves; sources remain until each rename succeeds. | Prepared startup recovery renames Trash files back in forward plan order. Recovery assignments rebuild logical names and folders. | Save library catalog, then Trash catalog, then committed journal and removal. Single failure renames file back, rewrites original catalogs, then removes journal if rollback succeeded. Bulk move failure rolls moved files back in reverse; failed rollback refreshes scans. Do not merge these paths. |
| Restore | Prepared restore journal precedes moves from Trash. Verify restored preset after move. | Prepared startup recovery sends restored files back to Trash in forward plan order, recording surviving Trash originals. | Catalog, then Trash catalog, then commit/removal. Single verification failure attempts rename back and removes journal unconditionally. Group rollback runs in reverse, restores catalog then Trash catalog, and removes journal only if rollback succeeded. |
| Permanent delete | Each delete is independent and irreversible. | Earlier deletes remain deleted if a later delete fails or the process stops. There is no journal. | Remove successful entries from memory, then save Trash catalog. On catalog failure files remain deleted and old catalog may remain. Empty Trash preserves groups if a preset delete failed. |
| History rotation | Each individual preset replacement has `.tmp`/`.bak` protection. | Slots rotate from oldest toward newest through separate writes; partial rotation may duplicate or omit snapshots. No whole-rotation rollback. | Write newest, delete slots above five, write legacy LastAppearance, refresh history. The legacy write result is ignored. The rotation is still limited to five entries. |
| Backup restore | Verify archive, then create each imported preset with atomic replace and verification. No whole-import journal. | A crash can leave copies, new catalogs, or changed config independently. | On preset failure delete accumulated created files. On catalog/inventory failure rewrite old catalog, old inventory, then delete copies. On config failure do those three steps, then attempt restoring old config. Rollback results are not uniformly checked. |

Committed journals never roll files back. Recovery tries deleting the journal and returns success even if that deletion fails. Prepared recovery removes its journal only when every plan is considered recovered, but does not check the remove result. Existing journal `.tmp` and `.bak` files are not automatically read at startup; only the main journal is decoded.

## Defects found

- History rotation is several protected writes, not one transaction. Keep it unchanged.
- `restoreTrashPreset`: verification failure removes the journal even if rename back failed. This weakens later recovery; retain the exact order and behavior.
- `recoverTransaction`: both rollback source and destination existing counts as recovered without comparing bytes. Preserve both files and that result.
- `recoverTransaction`: committed cleanup failure returns success. Prepared cleanup ignores the delete result. Neither path adds a durability guarantee.
- `events.onInit`: Config.txt is written before journal recovery; recovery failure skips scans but later still marks the app ready and initializes bridge/import. A blanket mutation gate is absent. I preserved this behavior under the user-confirmed stage 4 scope. A recovery gate needs a separate fix.
- Stage 1 UTF-8 byte truncation and path-validator differences, wardrobe retry gap, and the rapid-load visual defect remain outside this stage.

## UNVERIFIED

Actual crash timing, file-system durability, permission behavior under CET, and rendered in-game outcomes require game testing. Fake files can establish call order, return values, and bytes; they cannot establish physical disk durability.


## Extraction and adapter boundaries

| Destination | Responsibility moved |
|---|---|
| `adapters/files.lua` | File existence, bounded reads, protected writer/close checks, fingerprinting, chunked copy, directory access, rename/delete, and the diagnostic checkpoint driver. Inputs explicitly include io, os, directory listing, limits, or file ports. |
| `application/storage.lua` | The original `.tmp`/`.bak` replacement sequence and unchanged-lines check. It calls explicit file ports and yields diagnostic result tables at the original log positions. |
| `domain/journal_codec.lua` | Original journal-line serialization, the legacy version-1 parser, and rollback path decisions. It performs no I/O and keeps prepared/committed interpretation unchanged. |
| `application/recovery.lua` | Transaction completion and startup rollback orchestration with explicit file ports, parsed journal, and paths. It yields diagnostics instead of calling a logger. |
| `domain/trash_codec.lua` | Trash-line encoding and decoding, original limits and validations, and the 256-byte group-ID limit. No file access or shared runtime. |

All five new production modules return explicit function tables. None requires the shared runtime or reads state, widgets, game objects, or a logger. Only the file adapter owns handles and protected I/O calls. Existing modules remain compatibility adapters; `filesystem.lua` keeps confirmation clearing, load reset, and logging in place, without mixing them into the extracted storage code.

The diagnostic driver runs synchronously. When replacement or recovery reaches an old log position, the application returns that diagnostic checkpoint to the adapter, which logs it before continuing. No worker, deferred mutation, persistent operation field, or format is added. Normal results retain every return slot, including nil values.

The preset, folder, Trash, history, backup, and sharing operation bodies retain their existing rollback blocks. Physical rename/delete calls now forward to the file adapter; they keep the original arguments, results, and error handling. Loader matching/write logic, UI layout, CET event ordering, redscript, native code, constants, formats, and release version are unchanged.

## Remaining compatibility entry points

References below exclude tests and new explicit modules. Definitions are omitted. `renameFile` and `deleteFile` are new adapter forwards for the former direct os calls; every other listed name remains an existing entry point. Remove a forward only after all listed callers have moved.

| Forward / adapter | Remaining callers |
|---|---|
| `fileExists` | `backup.lua:72` (uniqueBackupFilename); `backup.lua:73` (uniqueBackupFilename); `backup.lua:211` (exportLibraryBackup); `backup.lua:268` (deleteSelectedLibraryBackup); `backup.lua:341` (importLibraryBackup); `bundles.lua:75` (uniqueTrashedBundleFilename); `bundles.lua:197` (uniqueFolderBundleFilename); `bundles.lua:198` (uniqueFolderBundleFilename); `events.lua:79` (events.onInit); `filesystem.lua:12` (filePorts.exists); `filesystem.lua:174` (helpers.archiveLogForNewSession); `folders.lua:325` (removeVirtualFolder); `folders.lua:355` (removeVirtualFolder); `history.lua:79` (refreshAppearanceHistory); `history.lua:87` (trimAppearanceHistory); `history.lua:150` (clearAppearanceHistory); `history.lua:152` (clearAppearanceHistory); `presets.lua:533` (renamePreset); `trash.lua:11` (module scope); `trash.lua:154` (uniqueTrashFilename); `trash.lua:167` (uniqueRestoredBundleFilename) |
| `fileFingerprint` | `backup.lua:249` (deleteSelectedLibraryBackup); `backup.lua:396` (importLibraryBackup); `bundles.lua:102` (trashSelectedFolderBundle); `bundles.lua:119` (trashSelectedFolderBundle); `bundles.lua:522` (importFolderBundle); `bundles.lua:536` (importFolderBundle); `bundles.lua:598` (importAvailableFolderBundles); `catalog.lua:88` (refreshPresets); `presets.lua:81` (state.hydratePreset); `presets.lua:217` (writePresetPath); `presets.lua:263` (readVerifiedPresetCopy); `presets.lua:313` (savePreset); `trash.lua:178` (restoreTrashBundle); `trash.lua:195` (restoreTrashBundle); `trash.lua:233` (trashPreset); `trash.lua:351` (restoreTrashPreset); `trash.lua:469` (restoreTrashGroup); `trash.lua:614` (bulkTrashFingerprint) |
| `safeDirectoryEntries` | `backup.lua:47` (backupFiles); `bundles.lua:51` (folderBundleFiles); `catalog.lua:47` (refreshPresets); `filesystem.lua:15` (filePorts.entries); `native_catalog.lua:152` (collectLuaCatalog); `trash.lua:82` (refreshTrash); `view_cache.lua:218` (storageFilenamesInUse) |
| `directoryTreeContainsFiles` | `folders.lua:379` (removeVirtualFolder); `trash.lua:774` (moveBulkPresetsToTrash) |
| `removeEmptyDirectoryTree` | `folders.lua:380` (removeVirtualFolder); `trash.lua:775` (moveBulkPresetsToTrash) |
| `writeFileSafely` | `acu_import.lua:183` (requestAcuImport); `backup.lua:160` (exportLibraryBackup); `backup.lua:383` (importLibraryBackup); `backup.lua:417` (importLibraryBackup); `backup.lua:428` (importLibraryBackup); `bundles.lua:206` (writePresetBundle); `bundles.lua:462` (writeRawPreset); `filesystem.lua:180` (helpers.archiveLogForNewSession); `filesystem.lua:198` (helpers.archiveLogForNewSession); `filesystem.lua:205` (helpers.archiveLogForNewSession); `native_bridge.lua:22` (writeOverlayRequest); `presets.lua:162` (writePresetContents); `presets.lua:182` (writeConfig); `ui/draw.lua:32` (draw) |
| `atomicReplace` | `acu_import.lua:182` (requestAcuImport); `backup.lua:159` (exportLibraryBackup); `backup.lua:382` (importLibraryBackup); `backup.lua:416` (importLibraryBackup); `backup.lua:427` (importLibraryBackup); `bundles.lua:205` (writePresetBundle); `bundles.lua:461` (writeRawPreset); `filesystem.lua:17` (filePorts.atomicReplace); `presets.lua:181` (writeConfig); `presets.lua:213` (writePresetPath) |
| `readBoundedFile` | `acu_import.lua:12` (readImportResults); `backup.lua:153` (exportLibraryBackup); `backup.lua:415` (importLibraryBackup); `bundles.lua:140` (readImportedBundles); `catalog.lua:408` (helpers.readInventory); `filesystem.lua:16` (filePorts.read); `native_bridge.lua:41` (helpers.updateOverlayRequest); `native_catalog.lua:41` (readNativeFileCatalog); `trash.lua:43` (readTrashCatalog); `trash.lua:57` (readTransaction) |
| `copyFile` | `folders.lua:202` (duplicateFolder); `presets.lua:795` (duplicatePreset) |
| `removeFileList` | `backup.lua:377` (importLibraryBackup); `backup.lua:389` (importLibraryBackup); `backup.lua:390` (importLibraryBackup); `backup.lua:399` (importLibraryBackup); `backup.lua:411` (importLibraryBackup); `backup.lua:425` (importLibraryBackup); `presets.lua:268` (cleanupFailureMessage); `presets.lua:434` (savePreset) |
| `writeLinesIfChanged` | `bundles.lua:188` (writeImportedBundles); `catalog.lua:392` (writeCatalog); `catalog.lua:475` (writeInventory); `trash.lua:34` (writeTrashCatalog); `trash.lua:51` (writeTransaction) |
| `validTrashFilename` | None in shipped production source. |
| `trashCatalogLines` | `trash.lua:29` (writeTrashCatalog) |
| `writeTrashCatalog` | `trash.lua:110` (refreshTrash); `trash.lua:287` (trashPreset); `trash.lua:295` (trashPreset); `trash.lua:358` (restoreTrashPreset); `trash.lua:367` (restoreTrashPreset); `trash.lua:492` (restoreTrashGroup); `trash.lua:504` (restoreTrashGroup); `trash.lua:567` (emptyTrash); `trash.lua:732` (moveBulkPresetsToTrash); `trash.lua:746` (moveBulkPresetsToTrash) |
| `readTrashCatalog` | `trash.lua:75` (refreshTrash) |
| `writeTransaction` | `folders.lua:317` (removeVirtualFolder); `presets.lua:543` (renamePreset); `trash.lua:14` (module scope); `trash.lua:273` (trashPreset); `trash.lua:337` (restoreTrashPreset); `trash.lua:437` (restoreTrashGroup); `trash.lua:663` (moveBulkPresetsToTrash) |
| `readTransaction` | `trash.lua:67` (recoverTransaction) |
| `completeTransaction` | `folders.lua:347` (removeVirtualFolder); `presets.lua:561` (renamePreset); `trash.lua:288` (trashPreset); `trash.lua:359` (restoreTrashPreset); `trash.lua:494` (restoreTrashGroup); `trash.lua:733` (moveBulkPresetsToTrash) |
| `recoverTransaction` | `events.lua:255` (events.onInit) |
| `renameFile` | `bundles.lua:113` (trashSelectedFolderBundle); `bundles.lua:120` (trashSelectedFolderBundle); `folders.lua:326` (removeVirtualFolder); `folders.lua:332` (removeVirtualFolder); `folders.lua:355` (removeVirtualFolder); `presets.lua:547` (renamePreset); `presets.lua:566` (renamePreset); `trash.lua:12` (module scope); `trash.lua:189` (restoreTrashBundle); `trash.lua:196` (restoreTrashBundle); `trash.lua:277` (trashPreset); `trash.lua:292` (trashPreset); `trash.lua:340` (restoreTrashPreset); `trash.lua:347` (restoreTrashPreset); `trash.lua:364` (restoreTrashPreset); `trash.lua:442` (restoreTrashGroup); `trash.lua:446` (restoreTrashGroup); `trash.lua:461` (restoreTrashGroup); `trash.lua:500` (restoreTrashGroup); `trash.lua:670` (moveBulkPresetsToTrash); `trash.lua:675` (moveBulkPresetsToTrash); `trash.lua:738` (moveBulkPresetsToTrash) |
| `deleteFile` | `backup.lua:211` (exportLibraryBackup); `backup.lua:267` (deleteSelectedLibraryBackup); `filesystem.lua:140` (helpers.pruneLogArchives); `folders.lua:334` (removeVirtualFolder); `folders.lua:361` (removeVirtualFolder); `history.lua:87` (trimAppearanceHistory); `history.lua:115` (saveAppearanceHistorySnapshot); `history.lua:150` (clearAppearanceHistory); `history.lua:152` (clearAppearanceHistory); `presets.lua:549` (renamePreset); `presets.lua:576` (renamePreset); `trash.lua:13` (module scope); `trash.lua:279` (trashPreset); `trash.lua:296` (trashPreset); `trash.lua:342` (restoreTrashPreset); `trash.lua:348` (restoreTrashPreset); `trash.lua:368` (restoreTrashPreset); `trash.lua:448` (restoreTrashGroup); `trash.lua:463` (restoreTrashGroup); `trash.lua:505` (restoreTrashGroup); `trash.lua:551` (emptyTrash); `trash.lua:559` (emptyTrash); `trash.lua:681` (moveBulkPresetsToTrash); `trash.lua:747` (moveBulkPresetsToTrash) |

`validTrashFilename` was already a stage 1 forward and now has no local caller. `writeTrashCatalog` keeps the same diagnostic and unchanged-file messages, while its encoder and writer delegate. The legacy reader remains `readTransaction` -> `journal_codec.decodeLegacy`; no new journal reader or journal version replaces it. The `writeLinesIfChanged` adapter also passes `readBoundedFile` and `atomicReplace` by reference as its read and replace ports in presets.lua. Those references remain callers even though they have no direct call parentheses.

## Validation and fixture provenance

I recorded the first fixtures before extraction, then expanded them by loading the unchanged source from commit `f776ec1673d7f4189d169a33d9570c3dcac26881` into package.preload. The final fixture file contains outputs from that original code, not outputs recorded from the extraction. Stage 4 runs without git or external dependencies; the recording option is only for baseline maintenance.

The fake file system records all opens, seeks, reads, writes, flushes, closes, renames, deletes, diagnostics, status changes, confirmation clears, and loader resets. Successful and failed bytes, return values, logs, and event order must match the original snapshots. Failure coverage includes nil results, exceptions at each primitive step, and paired failures that reach atomic rollback failures.

For workflow interruption tests, the fake file system captures its disk map immediately after the selected step. It lets the sandboxed call finish, discards every later disk change, then starts recovery from the captured map. This avoids Lua 5.1's prohibition on yielding across pcall. The original and extracted workflows use the same test inputs. The harness supplies deterministic map traversal to runtime adapters for workflow traces; production traversal is unchanged and is not given a new ordering guarantee.

| Check | Result |
|---|---|
| Stage 1 | 833 fixtures and additional binary/naming/adapter checks pass. |
| Stage 2 | 183 cases, 62 writer comparisons, seven byte-identical format-8 round trips pass. Reads leave inputs unchanged. |
| Stage 3 | 63 snapshots and timeout, bridge, camera, and immediate-restart checks pass. |
| Stage 4 | 2,981 baseline comparisons pass; 2,100 injected failure runs and 364 paired atomic-failure cases are included. |
| Legacy reader | Original version-1 journals for trash, restore, and rename in both phases decode without changing any input bytes. Missing, malformed, duplicate, unsafe, mismatched, and leftover cases retain baseline results. |
| Written bytes | All snapshot file maps and write arguments match baseline, including journal and Trash catalog bytes, Unicode, NUL data, unchanged-file suppression, and failure leftovers. |
| Lua syntax | All 54 shipped Lua files parse as Lua 5.1. |
| redscript | Installed game compiler succeeds with four unchanged CPM scripts, current game cache, and five byte-identical installed Codeware script references in an isolated temporary tree. |
| Scope comparison | Folder, history, backup, and sharing bodies differ only in primitive forwards. Trash workflows after the extracted entry points also match exactly after those forwards are normalized. |

The module-boundary check confirms that loading the five new modules neither loads runtime nor writes globals. A checkpoint test also verifies nil/false/trailing-nil return values survive the driver.

| Real workflow | Stop points recovered and compared with baseline |
|---|---:|
| Preset rename | 50 |
| Single preset to Trash | 66 |
| Single restore | 65 |
| Folder-group restore | 72 |
| Bulk folder Trash | 74 |
| Imported-folder relocation under rename journal | 69 |
| Total | 396 |

Each recovery result includes the entire remaining disk map, returned recovered assignments/folders/originals, and exact diagnostics. A match includes weak or incomplete baseline outcomes; it does not turn them into stronger guarantees.

Run `modules/domain/stage1_tests.lua` through `stage4_tests.lua` from the repository root with Lua 5.1, followed by `native/verification/check_code.js`. The installed Lua 5.1 DLL runner was used for this validation. No new interpreter or dependency ships with the mod.

## Files to install

Under `bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/`, install these changed files:

- `modules/filesystem.lua`
- `modules/presets.lua`
- `modules/trash.lua`
- `modules/folders.lua`
- `modules/history.lua`
- `modules/backup.lua`
- `modules/bundles.lua`

Add every new production file:

- `modules/adapters/files.lua`
- `modules/application/storage.lua`
- `modules/application/recovery.lua`
- `modules/domain/journal_codec.lua`
- `modules/domain/trash_codec.lua`

The full test ZIP also includes the new validation files `modules/domain/stage4_tests.lua`, `modules/domain/stage4_fixtures.lua`, and this `modules/domain/STAGE4.md` audit. They are not runtime dependencies. It includes the complete matching build under the three existing shipped roots; no release archive, release number, or installer format is introduced. Presets and Data stay at their existing locations.

## In-game checklist

Back up `Character Presets` and `Data` before the forced-close tests. Use disposable presets such as Stage4 A and Stage4 B, and repeat the ordinary actions from both menus where those controls exist. The complete manager supplies backup export/restore and bulk tools.

All paths below are relative to the CET mod directory. The current Activity Log is `Data/Logs/Activity.log`; startup archives the previous session under `Data/Logs/Archive`. Preserve the previous session's archive when testing a forced close.

### Ordinary operations

| Action | What to observe in the Activity Log | Files to inspect after completion |
|---|---|---|
| Save Stage4 A, then overwrite it with one changed appearance choice | `[create] Saved "Stage4 A" with ... options.`, plus successful `[CATALOG]` and `[INVENTORY]` records. Overwrite requires the existing confirmation. | `Character Presets/<storage>.preset` loads correctly and remains format 8. Its `.tmp` and `.bak` should normally be absent. No recovery journal is created for a save. |
| Rename Stage4 A to Stage4 Renamed | `[rename] Renamed ...` and `[PRESET] Display and physical rename completed:`. | Physical preset name changes; old file is absent. `Data/Recovery/Recovery Journal.txt` should be removed, and journal `.tmp`/`.bak` should normally be absent. |
| Move Stage4 Renamed to a test folder | `[folder] Moved ...` and `[PRESET] Virtual move completed:`. | Logical folder, preset's saved library folder, and `Data/Catalog/Virtual Folders.txt` agree. A normal virtual move keeps physical storage in place and does not create a journal. Check the modified preset and catalog for leftover `.tmp`/`.bak`. |
| Send it to Trash, then restore it | `[delete] Moved "..." to Trash.` followed by `[delete] Restored "..." from Trash.`. Catalog/inventory success lines may also appear. | Preset moves between Character Presets and `Data/Recovery/Trash`. `Data/Recovery/Trash Catalog.txt` records/removes its mapping. The journal should be removed after each completed action. Check both catalogs and journal for `.tmp`/`.bak`. |
| Empty Trash with disposable items | `[delete] Trash emptied permanently.` or the existing partial-failure message. | Deleted files are absent from Trash and its catalog. There is no deletion journal or undo copy; other recovery entries stay unchanged. |
| Export a library backup and restore it | `[LIBRARY BACKUP] Exported` and `[LIBRARY BACKUP] Imported` completion records; no verification error. | `.cpmbackup` stays in its original location under Character Presets and verifies. Restored names use the existing collision rules. Inspect new presets, catalogs, and `Data/Config/Config.txt` for `.tmp`/`.bak`; backup restore has no whole-import journal. |
| Load several distinct appearances and inspect history | `[APPEARANCE HISTORY] Saved ...` or `Skipped an identical recovery snapshot.` | `Data/Recovery/Appearance History/Appearance 1.preset` through `Appearance 5.preset` remain readable; `Data/Recovery/LastAppearance.preset` remains compatible. Inspect each written file for `.tmp`/`.bak`. No whole-rotation journal is expected. |

An ordinary successful action should leave no new `.tmp` or `.bak` for the files it replaced, assuming cleanup succeeds. The code does not report every cleanup failure, and old leftovers can remain; record their exact paths instead of deleting them before collecting evidence.

### Forced close and restart

1. With only disposable test data selected, start a physical rename and force-close the game immediately after confirming it. Repeat with a confirmed Trash action; a group of disposable presets gives a wider timing window. These actions are synchronous and often finish too quickly to interrupt reliably.
2. Before restarting, copy any `Data/Recovery/Recovery Journal.txt`, its `.tmp` and `.bak`, the affected preset files, and both catalogs to a separate evidence folder. Do not edit the journal. Record whether its header is `H	prepared	rename`, `H	prepared	trash`, or committed, with actual tab separators.
3. Restart the game and inspect the new Activity Log. A prepared journal should produce `[RECOVERY] Unfinished rename transaction was rolled back.` or the matching Trash line when rollback succeeds. A committed journal should produce `[RECOVERY] Completed transaction journal cleanup.` when removal succeeds. The existing retry/error messages are the expected result if a file operation fails.
4. For a prepared rename, check that the original physical file and logical name return. For prepared Trash, check that the original preset returns from Trash and retains its folder. A committed action keeps its completed files; startup only cleans the journal.
5. With no interrupted main journal, no recovery message is expected. That does not prove the interruption path ran. A `.tmp`/`.bak`-only journal is not decoded at startup in the baseline, so keep that evidence and report it rather than assuming recovery succeeded.
6. Inspect `.tmp` and `.bak` beside the preset, both catalogs, and the journal after restart. Recovery only guarantees the same cleanup attempts as before; leftovers are not a new automatic sweep. Verify the library and Trash views against actual files before further mutations.

**UNVERIFIED:** real forced-close timing and the complete in-game checklist. The automated tests prove the covered disk-state transitions against the baseline; they do not simulate operating-system buffering, concurrent external writers, or game rendering.

Stage 4 ends here. Stage 5 requires the user's confirmation.
