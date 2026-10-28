# Stage 6 sharing and recovery audit

Baseline: `0ea0a435685f9cfe45cdfb1c6d386b5c1b2c7a65`.

## Part A: latest session evidence, read before code changes

The October 28 session runs installed stage 5 files matching the source. No current require/global/runtime/compile error was found. The CPM error log still contains the two October 27 coroutine errors from the older stage 4 build; they are not current-session errors. scripting.log line 2849 records the mod loaded at 19:01:34. redscript_rCURRENT.log lines 22–23 record compilation complete and output saved at 19:01:33.

Activity.log startup proof:

```text
5: [2026-10-28 19:01:45] [#0005] [INFO] [CONFIG] Loaded 'Data/Config/Config.txt': presetSort=name.
18: [2026-10-28 19:01:45] [#0018] [INFO] Preset files loaded: presets=27 directory='Character Presets'
19: [2026-10-28 19:01:45] [#0019] [INFO] [NATIVE PANEL] Native bridge connected.
```

Folder creation is confirmed at lines 144–145: `[folder] Created folder "ss".` and `[FOLDER] Created virtual folder 'ss'.` Saving is confirmed at line 211: `[create] Saved "ss/ss" with 59 options.` Favorites, notes/tags, folder rename/remove, moves, duplicates, and collision tests have no matching action lines in the latest log. Sort loaded as name; no sort-change event proves both modes were exercised. The startup/previous-session archive proves another session started, not that every stage 5 change persisted. I did not assume missing checklist actions passed.

No .tmp/.bak files or Recovery Journal main/sidecar files were found under installed Data or Character Presets. There is no startup recovery message. Nothing was cleaned up.

The first current Activity Log warnings are lines 129–130, the two unavailable eyelash options:

```text
[2026-10-28 19:02:25] [#0129] [WARN] [SKIPPED] Saved option unavailable in current editor/body setup: Custom/CCXL option (no display name) | LocKey=LocKey#13879517178655718515 | occurrence=1 | preset format=8 | saved LocKey='LocKey#13879517178655718515' | editor slot='eyelashes_options' | saved choice='options:UI-Customization-icxrus_softnaturaleyelashes' | saved index=2 targetIndex=2
[2026-10-28 19:02:25] [#0130] [WARN] [SKIPPED] Saved option unavailable in current editor/body setup: Custom/CCXL option (no display name) | LocKey=LocKey#8824472266055663870 | occurrence=1 | preset format=8 | saved LocKey='LocKey#8824472266055663870' | editor slot='eyelash_color' | saved choice='not recorded' | saved index=2 targetIndex=2
[2026-10-28 19:02:25] [#0135] [WARN] SUMMARY | preset='Alina' | applied=48 | unresolved=2 | passes=31 | result=stopped
```

The prior session archived as Activity 2026-10-28_19-01-45.txt contains the same warnings at lines 129–130 and 48/2 stopped result at line 135, dated October 27. These are not new stage 5 symptoms. The current native service log characterpresetmanager-2026-10-28-19-01-25.log line 2 states:

```text
[2026-10-28 19:01:30.595] [warning ] [ 22184] [Character Preset Manager Native File Service] Character Preset Manager: ACU folder watching is not available. Select Refresh to check files.
```

That is the known watcher issue; no native change belongs to stage 5 or 6. The latest Activity Log has one load, not a rapid-load sequence, and its stopped summary does not include cleanupUnconfirmed. Visible leftover hair/cyberware and rapid-load reproduction are UNVERIFIED from this session. No new stage 5 regression is established.

Other-mod warnings in scripting.log concern Toggle Armware's missing NativeSettings and CET NPC Body Tweaks' missing archive. The CET engine log's unsupported-game errors are dated October 22, outside this session.

The stage 5 hash was verified as both HEAD and origin/main before stage 6 work. No code change was made during Part A.

## Before extraction: function inventory

The pure portions of these entries were recorded before moving them and are now delegated below. Their file access, game reads, logging/status, confirmations, loader resets, and rollback writes stay in the adapters. Stage 4 journal and Trash codecs remain unchanged; stage 5 library modules are only called, not edited.

| Function | Baseline callers |
|---|---|
| `bundles.lua` / `validBundlePath` | `bundles.lua:162`; `bundles.lua:182`; `bundles.lua:211`; `bundles.lua:225`; `bundles.lua:370`; `bundles.lua:376`; `bundles.lua:386` |
| `bundles.lua` / `hexEncode` | `bundles.lua:38` |
| `bundles.lua` / `hexDecode` | `bundles.lua:510` |
| `bundles.lua` / `writeHexFile` | `bundles.lua:247` |
| `bundles.lua` / `folderBundleFiles` | `bundles.lua:89`; `bundles.lua:421`; `bundles.lua:585`; `ui/sections_folders.lua:117` |
| `bundles.lua` / `clearFolderBundlePreview` | `bundles.lua:98`; `bundles.lua:129`; `bundles.lua:416`; `bundles.lua:430`; `bundles.lua:436`; `ui/sections_folders.lua:125`; `ui/sections_folders.lua:148`; `ui/sections_folders.lua:157`; `ui/sections_folders.lua:169` |
| `bundles.lua` / `uniqueTrashedBundleFilename` | `bundles.lua:107` |
| `bundles.lua` / `trashSelectedFolderBundle` | `ui/sections_folders.lua:175` |
| `bundles.lua` / `readImportedBundles` | `bundles.lua:590` |
| `bundles.lua` / `writeImportedBundles` | `bundles.lua:562`; `bundles.lua:609` |
| `bundles.lua` / `uniqueFolderBundleFilename` | `bundles.lua:285`; `bundles.lua:321` |
| `bundles.lua` / `writePresetBundle` | `bundles.lua:289`; `bundles.lua:326` |
| `bundles.lua` / `exportSelectedFolderBundle` | `ui/sections_folders.lua:109` |
| `bundles.lua` / `exportSelectedBulkPresetBundle` | `ui/sections_bulk.lua:97` |
| `bundles.lua` / `inspectFolderBundle` | `bundles.lua:434`; `bundles.lua:469` |
| `bundles.lua` / `viewSelectedFolderBundleContents` | `ui/sections_folders.lua:171` |
| `bundles.lua` / `writeRawPreset` | `bundles.lua:512` |
| `bundles.lua` / `importFolderBundle` | `bundles.lua:622` |
| `bundles.lua` / `importAvailableFolderBundles` | `ui/sections_folders.lua:113` |
| `backup.lua` / `setBackupStatus` | `backup.lua:145`; `backup.lua:150`; `backup.lua:206`; `backup.lua:218`; `backup.lua:225`; `backup.lua:246`; `backup.lua:252`; `backup.lua:261`; `backup.lua:269`; `backup.lua:275`; `backup.lua:342`; `backup.lua:346`; `backup.lua:358`; `backup.lua:369`; `backup.lua:378`; `backup.lua:391`; `backup.lua:400`; `backup.lua:412`; `backup.lua:433`; `backup.lua:451` |
| `backup.lua` / `encode` | `backup.lua:37`; `backup.lua:166` |
| `backup.lua` / `decode` | `backup.lua:102`; `backup.lua:303`; `backup.lua:310` |
| `backup.lua` / `writeEncodedFile` | `backup.lua:196` |
| `backup.lua` / `backupFiles` | `backup.lua:61` |
| `backup.lua` / `libraryBackupFiles` | `backup.lua:237`; `ui/sections_backup.lua:10`; `ui/sections_backup.lua:35` |
| `backup.lua` / `uniqueBackupFilename` | `backup.lua:148` |
| `backup.lua` / `verifyBackupContents` | `backup.lua:209` |
| `backup.lua` / `exportLibraryBackup` | `ui/sections_backup.lua:31` |
| `backup.lua` / `deleteSelectedLibraryBackup` | `ui/sections_backup.lua:67` |
| `backup.lua` / `readBackup` | `backup.lua:345` |
| `backup.lua` / `uniqueImportRoot` | `backup.lua:356` |
| `backup.lua` / `importLibraryBackup` | `ui/sections_backup.lua:59` |
| `trash.lua` / `refreshTrash` | `events.lua:259`; `native_bridge.lua:380`; `trash.lua:679`; `trash.lua:742`; `ui/sections_load.lua:84` |
| `trash.lua` / `state.invalidateTrashViewCache` | `trash.lua:203`; `trash.lua:566`; `view_cache.lua:55` |
| `trash.lua` / `state.ensureTrashViewCache` | `ui/sections_trash.lua:9` |
| `trash.lua` / `uniqueTrashFilename` | `trash.lua:262`; `trash.lua:635` |
| `trash.lua` / `uniqueRestoredBundleFilename` | `trash.lua:179` |
| `trash.lua` / `restoreTrashBundle` | `ui/sections_trash.lua:81` |
| `trash.lua` / `trashPreset` | `native_bridge.lua:367`; `ui/sections_trash.lua:25` |
| `trash.lua` / `restoreTrashPreset` | `ui/sections_trash.lua:73` |
| `trash.lua` / `allocateRestoreLogicalName` | `trash.lua:420` |
| `trash.lua` / `restoreTrashGroup` | `ui/sections_trash.lua:64` |
| `trash.lua` / `emptyTrash` | `ui/sections_trash.lua:93` |
| `trash.lua` / `bulkPresetNamesInFolder` | `ui/sections_folders.lua:76` |
| `trash.lua` / `selectedBulkPresetNames` | `bundles.lua:305`; `presets.lua:605`; `ui/sections_bulk.lua:11`; `ui/sections_bulk.lua:73` |
| `trash.lua` / `bulkTrashFingerprint` | `trash.lua:799` |
| `trash.lua` / `moveBulkPresetsToTrash` | `trash.lua:813` |
| `trash.lua` / `requestBulkTrash` | `ui/sections_bulk.lua:105`; `ui/sections_folders.lua:87` |
| `history.lua` / `historyPath` | `history.lua:65`; `history.lua:86`; `history.lua:98`; `history.lua:105`; `history.lua:106`; `history.lua:111`; `history.lua:115`; `history.lua:149` |
| `history.lua` / `snapshotFromOptions` | `history.lua:93` |
| `history.lua` / `sameAppearance` | `history.lua:99` |
| `history.lua` / `refreshAppearanceHistory` | `events.lua:270`; `events.lua:386`; `history.lua:89`; `history.lua:117`; `history.lua:156`; `load_engine.lua:1306`; `native_bridge.lua:238` |
| `history.lua` / `trimAppearanceHistory` | No direct shipped caller; retained compatibility entry. |
| `history.lua` / `saveAppearanceHistorySnapshot` | `history.lua:133`; `load_engine.lua:1275` |
| `history.lua` / `restoreAppearanceHistory` | `load_engine.lua:1307`; `native_bridge.lua:387`; `ui/sections_load.lua:281` |
| `history.lua` / `clearAppearanceHistory` | `native_bridge.lua:399`; `ui/sections_load.lua:289` |

Planned production modules: domain/bundle_codec.lua, domain/backup_codec.lua, domain/trash.lua, domain/appearance_history.lua, and application/recovery_items.lua. Each returns an explicit function table with explicit inputs and no shared runtime.

## Guarantees and failure leftovers to preserve

- Trash/restore use prepared/committed journals. Rollback order and incomplete-recovery behavior remain those recorded in STAGE4.md.
- Bundle import and backup restore do not have an operation journal in the baseline. Interruption tests run startup recovery without adding journals or treating those imports as transactions.
- Bundle import can leave created preset copies, partial .tmp/.bak files, and independently written catalog, inventory, or import-registry data after interruption. Its ordinary failure path only attempts its existing tracked-file cleanup and catalog rewrites.
- Backup restore can leave imported preset copies, a new catalog/inventory, and an independently replaced Config.txt. Existing rollback is best effort and not itself journaled.
- History rotates oldest toward newest using separate atomic replacements, then writes the new head, trims slots 6–10, and attempts LastAppearance. A failed legacy copy is ignored. The rotation is not one transaction.
- Permanent delete/empty Trash is irreversible per file. Earlier successful deletes remain deleted if a later delete/catalog write fails. No journal makes them reversible.

## Defects found

Known bulk move/Trash partial outcomes, nontransactional history, UTF-8 byte truncation, validator differences, unchecked rollback steps, and the missing startup mutation gate remain unchanged. A real forced close, raw CET directory entry capture, rendered state, and actual restart persistence remain UNVERIFIED.

## Stage 5 checklist coverage in the latest log

| Action | Evidence or missing line |
|---|---|
| Favorite on/off | Missing. No added/removed favorite status was found. |
| Notes/tags | Missing. No saved-details status was found. |
| Create folder | Activity lines 144–145: `[folder] Created folder "ss".` then `[FOLDER] Created virtual folder 'ss'.` |
| Rename/remove folder | Missing. No virtual-folder rename/remove action was found. |
| Move presets | Missing. No move completion was found. |
| Duplicate preset/folder | Missing. No duplicate completion was found. |
| Collisions | Missing. No collision test can be established. Some rejected actions only update status. |
| Sort | Startup line 5 shows `presetSort=name`; changing modes is not established. |
| Restart/persistence | A fresh session and the prior archive exist. Persistence of each edit is not established. |

## What moved

| Adapter | New pure module | Moved decisions |
|---|---|---|
| bundles.lua | domain/bundle_codec.lua | Streaming line inspection, registry records and legacy fingerprints, export records, folder selection, candidate names. |
| backup.lua | domain/backup_codec.lua | Import reader and separate export verifier, archive records, root selection and filename candidates. |
| trash.lua | domain/trash.lua | View entries, group selection/order, restored names, counts, candidate filenames, bulk selections. |
| history.lua | domain/appearance_history.lua | Plain snapshots, ordered identity comparison, rotation steps, trimming indices, view entries. |
| bundles.lua, backup.lua, trash.lua | application/recovery_items.lua | Import/bulk/restore catalog-map plans and imported logical/storage names. |

File opens, seek/read/close, directory enumeration, writes, renames, deletion, protected calls, game-option conversion, timestamps, logging, statuses, confirmation clearing, loader resets and rollback writes remain in the original adapters. The reader and verifier stay separate because their original validation differs. Semantic decoder failures are translated to the original messages by those adapters.

No stage 4 or 5 production module changed. Journal read/write/recover/complete bodies in trash.lua are also unchanged. Constants, current and legacy formats, limits, paths, and bridge protocol 1 are unchanged. Trash groups remain G/F/M/P records in Trash Catalog.txt; there is no new group-file format.

## Remaining compatibility entry points and callers

Each old entry remains at its original adapter boundary. Pure portions delegate to the new modules; IO orchestration remains in that adapter. The following references are from the extracted build, not the earlier inventory.

| Entry point | Remaining callers (module-relative lines) |
|---|---|
| `bundles.lua / validBundlePath` | `bundles.lua:14`; `bundles.lua:169`; `bundles.lua:183` |
| `bundles.lua / hexEncode` | `bundles.lua:18`; `bundles.lua:41` |
| `bundles.lua / hexDecode` | `bundles.lua:22`; `bundles.lua:397` |
| `bundles.lua / writeHexFile` | `bundles.lua:205` |
| `bundles.lua / folderBundleFiles` | `bundles.lua:90`; `bundles.lua:326`; `bundles.lua:472`; `ui/sections_folders.lua:117` |
| `bundles.lua / clearFolderBundlePreview` | `bundles.lua:99`; `bundles.lua:130`; `bundles.lua:321`; `bundles.lua:335`; `bundles.lua:341`; `ui/sections_folders.lua:125`; `ui/sections_folders.lua:148`; `ui/sections_folders.lua:157`; `ui/sections_folders.lua:169` |
| `bundles.lua / uniqueTrashedBundleFilename` | `bundles.lua:108` |
| `bundles.lua / trashSelectedFolderBundle` | `ui/sections_folders.lua:175` |
| `bundles.lua / readImportedBundles` | `bundles.lua:477` |
| `bundles.lua / writeImportedBundles` | `bundles.lua:449`; `bundles.lua:496` |
| `bundles.lua / uniqueFolderBundleFilename` | `bundles.lua:233`; `bundles.lua:262` |
| `bundles.lua / writePresetBundle` | `bundles.lua:237`; `bundles.lua:267` |
| `bundles.lua / exportSelectedFolderBundle` | `ui/sections_folders.lua:109` |
| `bundles.lua / exportSelectedBulkPresetBundle` | `ui/sections_bulk.lua:97` |
| `bundles.lua / inspectFolderBundle` | `bundles.lua:339`; `bundles.lua:374` |
| `bundles.lua / viewSelectedFolderBundleContents` | `ui/sections_folders.lua:171` |
| `bundles.lua / writeRawPreset` | `bundles.lua:399` |
| `bundles.lua / importFolderBundle` | `bundles.lua:509` |
| `bundles.lua / importAvailableFolderBundles` | `ui/sections_folders.lua:113` |
| `backup.lua / setBackupStatus` | `backup.lua:109`; `backup.lua:114`; `backup.lua:170`; `backup.lua:182`; `backup.lua:189`; `backup.lua:210`; `backup.lua:216`; `backup.lua:225`; `backup.lua:233`; `backup.lua:239`; `backup.lua:284`; `backup.lua:288`; `backup.lua:292`; `backup.lua:298`; `backup.lua:307`; `backup.lua:320`; `backup.lua:329`; `backup.lua:341`; `backup.lua:362`; `backup.lua:380` |
| `backup.lua / encode` | `backup.lua:39`; `presets.lua:132`; `presets.lua:153`; `trash.lua:26`; `trash.lua:51` |
| `backup.lua / decode` | `presets.lua:20`; `presets.lua:175`; `trash.lua:47` |
| `backup.lua / writeEncodedFile` | `backup.lua:160` |
| `backup.lua / backupFiles` | `backup.lua:63` |
| `backup.lua / libraryBackupFiles` | `backup.lua:201`; `ui/sections_backup.lua:10`; `ui/sections_backup.lua:35` |
| `backup.lua / uniqueBackupFilename` | `backup.lua:112` |
| `backup.lua / verifyBackupContents` | `backup.lua:173` |
| `backup.lua / exportLibraryBackup` | `ui/sections_backup.lua:31` |
| `backup.lua / deleteSelectedLibraryBackup` | `ui/sections_backup.lua:67` |
| `backup.lua / readBackup` | `backup.lua:287` |
| `backup.lua / uniqueImportRoot` | `backup.lua:290` |
| `backup.lua / importLibraryBackup` | `ui/sections_backup.lua:59` |
| `trash.lua / refreshTrash` | `events.lua:259`; `native_bridge.lua:380`; `trash.lua:609`; `trash.lua:634`; `ui/sections_load.lua:84` |
| `trash.lua / state.invalidateTrashViewCache` | `trash.lua:183`; `trash.lua:509`; `view_cache.lua:55` |
| `trash.lua / state.ensureTrashViewCache` | `ui/sections_trash.lua:9` |
| `trash.lua / uniqueTrashFilename` | `trash.lua:242`; `trash.lua:565` |
| `trash.lua / uniqueRestoredBundleFilename` | `trash.lua:159` |
| `trash.lua / restoreTrashBundle` | `ui/sections_trash.lua:81` |
| `trash.lua / trashPreset` | `native_bridge.lua:367`; `ui/sections_trash.lua:25` |
| `trash.lua / restoreTrashPreset` | `ui/sections_trash.lua:73` |
| `trash.lua / allocateRestoreLogicalName` | `trash.lua:366`; `trash.lua:383` |
| `trash.lua / restoreTrashGroup` | `ui/sections_trash.lua:64` |
| `trash.lua / emptyTrash` | `ui/sections_trash.lua:93` |
| `trash.lua / bulkPresetNamesInFolder` | `ui/sections_folders.lua:76` |
| `trash.lua / selectedBulkPresetNames` | `bundles.lua:253`; `presets.lua:605`; `ui/sections_bulk.lua:11`; `ui/sections_bulk.lua:73` |
| `trash.lua / bulkTrashFingerprint` | `trash.lua:691` |
| `trash.lua / moveBulkPresetsToTrash` | `trash.lua:705` |
| `trash.lua / requestBulkTrash` | `ui/sections_bulk.lua:105`; `ui/sections_folders.lua:87` |
| `history.lua / historyPath` | `history.lua:10`; `history.lua:42`; `history.lua:56`; `history.lua:68`; `history.lua:76`; `history.lua:77`; `history.lua:82`; `history.lua:86`; `history.lua:120` |
| `history.lua / snapshotFromOptions` | `history.lua:63` |
| `history.lua / sameAppearance` | `history.lua:35`; `history.lua:69` |
| `history.lua / refreshAppearanceHistory` | `events.lua:270`; `events.lua:386`; `history.lua:59`; `history.lua:88`; `history.lua:127`; `load_engine.lua:1306`; `native_bridge.lua:238` |
| `history.lua / trimAppearanceHistory` | No direct shipped caller; retained compatibility entry. |
| `history.lua / saveAppearanceHistorySnapshot` | `history.lua:104`; `load_engine.lua:1275` |
| `history.lua / restoreAppearanceHistory` | `load_engine.lua:1307`; `native_bridge.lua:387`; `ui/sections_load.lua:281` |
| `history.lua / clearAppearanceHistory` | `native_bridge.lua:399`; `ui/sections_load.lua:289` |

## Fixture provenance and results

I captured initial fixtures before extraction. I expanded failure and interruption cases against immutable original adapters from commit `0ea0a435685f9cfe45cdfb1c6d386b5c1b2c7a65`, supplied explicitly to the restricted loader. I then ran both original and extracted adapters against the same recorded fixture file. Both pass 9,039 comparisons. The gate's explicit source override is important: package.preload alone cannot override this restricted loader.

Each snapshot compares all fake-file bytes, return slots including nils, application error/status text, log text/order, adapter call order, catalog/library/cache/load/Trash/history/backup state, and selections. Only host Lua source-chunk/line prefixes on uncaught exceptions are normalized. Application messages are compared verbatim.

- 4,526 single injected failures: 2,351 open/write/flush/close, 222 rename, 371 delete, and 1,582 read/seek/list or other boundary steps.
- 3,973 paired mutation/rollback failure cases cover distinct rollback branches. This does not claim every possible combination of failures.
- 426 disk interruptions: capture the map immediately after a selected open/write/rename/delete, discard subsequent writes and all working state, create fresh state, then call the unchanged recoverTransaction, startup preset scan, and Trash refresh. Every resulting snapshot matches the original adapters.
- Fixtures include successful operations, old fingerprint/Trash records, Unicode, nesting, collisions, malformed/truncated archives, wrong versions, size/count boundaries, duplicates and hostile paths. History covers 0, 2, 5, 8 and 11 slots.
- Actual folder export/import checks both presets, all entries, name, notes, tags, favorite, format, created and modified values, plus nested folders.
- Actual backup export/restore checks those same fields for both presets and preserves empty/nested folders. Existing collisions intentionally remap the import root to `Imported Library`.

Library contents match after the original root/storage-name remapping. A remapped preset header is not claimed to match its old root header; its written bytes match what the baseline writes for that same operation.

| Validation | Result |
|---|---|
| Stage 1 | 833 fixtures; binary/naming and storage fallback checks pass. |
| Stage 2 | 183 adapter fixtures, 62 accepted writes, 7 byte-identical format-8 round trips pass. |
| Stage 3 | 63 state fixtures; independence and timeout regressions pass. |
| Stage 4 | 2,981 comparisons; 396 journal interruptions; missing-coroutine regression passes. |
| Stage 5 | 6,349 comparisons; restricted-environment checks pass. |
| Stage 6 | 9,039 comparisons; 426 interruptions; original and extracted builds both pass. |
| Lua 5.1 | All 70 Lua files parse with the installed luaparse dependency. Tests execute with the local Lua 5.1 DLL. |
| redscript | Isolated scc compile against the copied installed vanilla cache, CPM sources and actual installed Codeware declarations succeeds. Redscript sources are unchanged. |

## Restricted globals

The full suite runs in fresh Lua states with stage6_sandbox installed before production modules. Stage 5 and 6 pure modules receive only:

```text
ipairs, pairs, require, tonumber, tostring, type
math.max
table.concat, table.insert, table.sort
```

Allowed pure dependencies are domain/paths, domain/names, domain/codecs, domain/library and domain/folders. Unknown global reads/writes or unlisted dependencies fail. Static parsing separately rejects unknown globals or math/table members. The test host uses debug, package and IO to obtain old private functions, record fixtures and load source; those capabilities are not exposed to the new production modules.

| New module | Referenced globals | Existing baseline examples |
|---|---|---|
| domain/bundle_codec | ipairs, pairs, require, table | bundles.lua already uses each; domain paths/names/codecs are already required in CET. |
| domain/backup_codec | ipairs, pairs, require, table | backup.lua already uses each. |
| domain/trash | ipairs, pairs, require, table | trash.lua already uses each. |
| domain/appearance_history | ipairs, require, tonumber, tostring | history.lua uses these; domain/names is already used in CET. |
| application/recovery_items | ipairs, pairs, require | bundles.lua/backup.lua/trash.lua already use these. |

The remaining legacy modules retain the preexisting allowlist below, rather than gaining access to new globals. It includes existing runtime exports and game APIs. Namespace members remain restricted by stage6_sandbox.lua.

```text
ACTIVITY_LOG_PAGE_SIZE ACU_IMPORT_FILES_PER_FRAME ACU_IMPORT_POLL_SECONDS ACU_IMPORT_REQUEST_FILE
ACU_IMPORT_RESULTS_FILE APPEARANCE_HISTORY_LIMIT AUTO_LOAD_LIMITS AUTO_LOAD_TIMING CATALOG_DIR
CATALOG_FILE CName CONFIG_DIR CONFIG_FILE CURRENT_PRESET_FORMAT DATA_DIR EDITOR_OPEN_TIMEOUT
EMPTY_LIST EquipmentSystem FALLBACK_NOTICE_CET_MESSAGE FALLBACK_NOTICE_DELAY_SECONDS
FALLBACK_NOTICE_MESSAGE FALLBACK_NOTICE_TITLE FILE_COPY_CHUNK_SIZE FOLDER_BUNDLE_EXTENSION
FORCE_FULL_LOAD_FORMAT_THRESHOLD Game GetBind GetDisplayResolution GetLocalizedTextByKey HISTORY_DIR
HISTORY_FILE_PREFIX IMPORTED_BUNDLES_FILE INVENTORY_FILE ImGui ImGuiCol ImGuiCond ImGuiStyleVar
ImGuiWindowFlags IsBound LAST_APPEARANCE_FILE LIBRARY_BACKUP_EXTENSION LOG_ARCHIVE_DIR
LOG_ARCHIVE_LIMIT LOG_ARCHIVE_PREFIX LOG_DIR LOG_FILE LocKeyToString MAX_CATALOG_BYTES
MAX_CATALOG_LINES MAX_FOLDER_BUNDLE_BYTES MAX_FOLDER_BUNDLE_PRESETS MAX_LIBRARY_BACKUP_BYTES
MAX_OPTION_INDEX MAX_PRESET_BYTES MAX_PRESET_ENTRIES MAX_PRESET_KEY_BYTES MAX_PRESET_LINES
MAX_TRANSACTION_BYTES MAX_TRANSACTION_LINES MAX_TREE_DEPTH MOD_NAME MorphMenuUserData
NATIVE_BRIDGE_PROTOCOL NATIVE_FILE_CATALOG NATIVE_FILE_PROTOCOL NATIVE_LIST_LIMIT
NATIVE_READY_STATUS NATIVE_REQUEST_POLL_SECONDS NameToString OPTION_CHOICE_CACHE_LIMIT Observe
Override PRESET_DIR QuestDisableWardrobeSetRequest QuestRestoreWardrobeSetRequest RECOVERY_DIR
SLOW_PREFLIGHT_SECONDS STALL_CONFIRMATION_PASSES STATUS_SECTIONS THEME_COLORS THEME_VARS
TRANSACTION_FILE TRASH_CATALOG_FILE TRASH_DIR ToCName UI_LIST_PAGE_SIZE VERSION
WINDOW_POSITION_STATUS_FILE _G activityLogFile activitySequence addFolderAncestors assert
atomicReplace baseName beginLoadPass bit32 bulkPresetNamesInFolder canRunAppearanceRandomizer
cancelConfirmations catalogDecode catalogEncode choiceCollectionValue cleanupFailureMessage
clearAppearanceHistory clearFolderBundlePreview clearStatus cloneMap closeActivityLog
collapsibleSectionHeader coloredWrapped compactSubsectionButton comparePresetWithCurrent
compareSelectedPreset completeTransaction connectNativeBridgeForMenu continueLoadPass copyFile
createFolder dangerButton deleteFile deleteSelectedLibraryBackup dir directoryTreeContainsFiles draw
drawBackupSection drawBulkSection drawEditorSection drawFallbackHudNotice drawFoldersSection
drawHelpPanel drawLoadSection drawManageSection drawPageControls drawSaveSection drawSectionStatus
drawSettingsPanel drawTrashSection duplicateFolder duplicatePreset emptyCustomizationName emptyTrash
ensureFilteredViewCache ensureViewCache equipmentSystem error events exportLibraryBackup
exportSelectedBulkPresetBundle exportSelectedFolderBundle fileExists fileFingerprint
findExistingFolderName findPresetCollision finishCompactSubsection folderAncestorsExpanded
folderBundleFiles folderDepth folderNameExists folderPath fullWidthButton
gameWardrobeClothingSetIndex gameuiCharacterCustomizationEditTag getOptions helpHeading helpers
hydrateNamedPreset hydrateNamedPresetMetadata importAvailableFolderBundles importLibraryBackup
initializeAcuImport initializeNativeBridge invalidateBulkSelectionCache invalidateFilteredViewCache
invalidatePresetAndTrashCaches invalidateViewCache io ipairs isFolderBundleFilename isInFolderTree
isRuntimePointerText joinFolder libraryBackupFiles loadPreset log logAcuDangerousOptions
logTimestamp math movePresetToSelectedFolder moveSelectedBulkPresetsToFolder
nativeCatalogDirectoryEntries next normalizeSearch occurrenceKeyParts openFullAppearanceEditor
optionAuditIdentity optionChoiceIndex optionChoiceMatchesIndex optionIndexIsValid
optionIndexValidationError optionKey optionSlot os pagedRange pairs parentFolder pcall
persistVirtualState popFoldingHeaderTheme popTheme presetPath presetsMatch pushFoldingHeaderTheme
pushTheme readBoundedFile readConfig readNativeFileCatalog readPresetFile readVerifiedPresetCopy
recoverTransaction refreshAppearanceHistory refreshCustomizationUi refreshEditorState
refreshPreflight refreshPresets refreshTrash remapFolderTreePath removeEmptyDirectoryTree
removeFileList removeVirtualFolder renameFile renameFolder renamePreset requestAcuImport
requestBulkTrash require resetLoadState restoreAppearanceHistory restoreLastAppearance
restoreTemporarilyDisabledWardrobe restoreTrashBundle restoreTrashGroup restoreTrashPreset
runAppearanceRandomizer safeDirectoryEntries sanitizeMetadata sanitizeName
saveAppearanceHistorySnapshot saveLastAppearanceSnapshot savePreset savePresetMetadata
savedEntryAuditIdentity selectedBulkPresetNames setEditorOpenStatus setPresetSortPreference
setStatus setfenv setmetatable sortedFolderNames stableChoiceIdentity stableRuntimeValue state
storageFilenamesInUse string table temporarilyDisableWardrobe textMatches
toggleSelectedPresetFavorite tonumber tostring trashPreset trashSelectedFolderBundle
trimAppearanceHistory type ui uniqueFolderCopyName uniquePresetCopyName uniqueStorageName
unresolvedSignature updateAcuImport updateNativeBridge utf8 validModifiedTimestamp validRelativePath
validatedFolderName validatedPresetName verifiedNativeFileCatalog viewSelectedFolderBundleContents
writeCatalog writeConfig writeFileSafely writeInventory writeLinesIfChanged writeLog
writePresetContents writePresetPath writeTransaction
```

The fake directory entry shape remains UNVERIFIED against a captured CET dir result. The fixture injects a deterministic pairs iterator into both builds so unsorted journal map writes receive the same traversal input. It does not add deterministic ordering to production or claim native CET traversal is sorted.

## Failure leftovers and recovery limits

The fixture keys `<operation> failure <step>`, `<operation> paired <first>/<second>` and `<operation> interruption <step>` retain exact complete file maps and traces. stage6_fixtures.lua is the step-by-step record; the following table explains those outcomes.

| Operation/stop | Existing outcome, unchanged |
|---|---|
| Export bundle/backup before final rename | An old destination, new .tmp or .bak may remain according to atomicReplace's old failure branch. Backup verification can reject and delete its candidate; a failed cleanup can leave that candidate. No operation journal is added. |
| Bundle import while copying/verifying presets | Earlier created copies may exist; a failing current write can leave .tmp/.bak. Ordinary failure attempts its existing createdFiles deletion; failed deletions leave those named copies. Crash skips rollback. |
| Bundle import after catalog/inventory write | Catalog can already describe the new root while inventory or import registry is old/missing. Inventory failure rewrites only the old catalog before cleanup. Registry failure rewrites old catalog then inventory before cleanup. Those rollback writes can fail. |
| Bundle import after registry write | Installed copies and catalog/inventory/Imported Bundles.txt can persist even before memory/UI update. Startup has no import journal to reverse them. Existing fingerprint/root checks govern later reimport. |
| Backup restore while copying | Earlier copied presets remain on crash; normal failure tries createdFiles cleanup in its original order. The current candidate and .tmp/.bak leftovers follow the existing atomic-write branch. |
| Backup restore after catalog/inventory | New library files may persist with old Config.txt. Normal rollback writes old catalog, then old inventory, then removes created copies. Failure in those steps leaves mixed lists/copies. |
| Backup restore at Config.txt replacement | Old/new config and .tmp/.bak can coexist. Config failure rewrites old catalog, old inventory, removes copies, then restores previous config only when readable. Startup does not journal-reverse this restore. |
| Single/bulk Trash, prepared phase | Journal and moved-file subset remain. Existing prepared recovery restores recorded originals in the original order, then rewrites lists. Failed rollback can leave a mixed live/Trash set and journal for later recovery. Bulk completion is not an all-or-nothing guarantee. |
| Trash committed phase | Existing committed recovery keeps intended Trash files, clears the journal and lets startup scanning rebuild views. A failed journal cleanup can retain Recovery Journal.txt or sidecars. |
| Single/group restore, prepared phase | A subset may already be in live storage. Existing prepared recovery reverses those assignments back to Trash; failed moves/list writes can leave mixed locations and the journal. |
| Restore committed phase | Existing committed recovery keeps the live files, clears the journal and lets startup scanning rebuild views. It does not reapply preset appearance or introduce another transaction. |
| Permanent delete/empty | Each successful file deletion is final. Later failed deletions stay on disk; a failed catalog write leaves stale records. Empty clears group records only when no preset deletion failed, as before. Bundle deletions are counted separately. |
| History rotation | Each older slot may already have been replaced when a later rotation or head write fails. Earlier shifts remain; there is no rotation rollback/journal. Trim/delete failures and LastAppearance write failure remain ignored. Clear/trim scan only through slot 10, so an existing slot 11 can survive. |

Bundle import and backup restore are not journaled in the baseline. Their interruption tests call startup recovery, but do not claim prepared/committed recovery exists for them. Legacy recovery journals and their readers remain untouched. OS durability, a real forced close and real filesystem error behavior remain UNVERIFIED by an in-memory fake.

## Defects found, kept for separate fixes

- Nontransactional history rotation: history.lua saveAppearanceHistorySnapshot rotates separate writes, then writes the head, trims, and writes LastAppearance. Partial shifts remain on failure. Legacy/trim failures are not checked.
- History slots beyond 10 are outside refresh/trim/clear scanning, even when the configured visible limit is 5. The fixture with slot 11 preserves this.
- Partial bulk move/Trash and unchecked rollback results remain. Stage 5 bulk move code was not edited; Trash and import rollback write order stays in the adapters.
- Backup readLibraryBackup / domain/backup_codec.readLine accepts a malformed CONFIG hex payload as nil, so a later CONFIG can still be accepted. Its reader accepts repeated folder records, while export verification rejects unexpected duplicates. No check was tightened.
- Backup uses validRelativePath where folder bundles use stricter validBundlePath. Reserved Windows names therefore have different acceptance rules. UTF-8 truncation still slices bytes in the existing name helpers.
- Startup still writes Config.txt before journal recovery and can become ready after failed recovery. This was explicitly preserved under the earlier instruction.
- Unavailable eyelash choices, unavailable ACU watcher and rapid-load visible leftovers remain separate issues. No loader/native change was made.

## Install exactly this stage

Exit the game. Extract the Stage 6 Test archive into the Cyberpunk 2077 game folder and allow replacement. Keep your existing Character Presets and Data folders. This is a test package, not a release.

The runtime delta is nine files under bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/modules:

```text
bundles.lua
backup.lua
trash.lua
history.lua
domain/bundle_codec.lua
domain/backup_codec.lua
domain/trash.lua
domain/appearance_history.lua
application/recovery_items.lua
```

The full archive also includes the new audit/test files domain/STAGE6.md, domain/stage6_tests.lua, domain/stage6_fixtures.lua and domain/stage6_sandbox.lua. Those are not required by init.lua. The repository-only checker native/verification/check_code.js and CHANGELOG.md are not installed. All previous files in the three approved package roots remain included. No version changes or release publication is part of this stage.

## In-game checklist

Use disposable presets and copy your Data and Character Presets folders first. Disk paths below are relative to the mod folder. Read Data/Logs/Activity.log plus the CET/per-mod error logs after each action.

1. Start the game. Expect `[CONFIG] Loaded ...`, `Preset files loaded: presets=...` with your presets, and `[NATIVE PANEL] Native bridge connected.` There should be no new require/global/runtime errors. The pure modules do not emit separate loaded lines; exercised actions are the runtime check.
2. Export a test folder with two presets, notes/tags and a nested empty folder. Expect `[FOLDER BUNDLE] Exported folder='...' presets=... file='...'.` Inspect Character Presets/Character Preset Manager Folder - <folder>.cpmfolder. Put a copy in Character Presets and install it; expect `[FOLDER BUNDLE] Imported file='...' root='...' presets=... fingerprint='...'.` An existing root gets the original copy suffix. Confirm both presets and nested folders under that different root, then check Data/Catalog/Imported Bundles.txt, Virtual Folders.txt and Preset Inventory.txt.
3. Export a library backup. Expect `[LIBRARY BACKUP] Exported presets=... folders=... file='...'.` Inspect Character Presets/Character Preset Manager Library Backup.cpmbackup (or its existing collision suffix). Remove a disposable preset, then restore the backup. Expect `[LIBRARY BACKUP] Imported presets=... folders=... root='...' file='...'.` If existing presets cause an Imported Library root, inspect the restored copy there. Confirm notes/tags/favorite, empty folders and saved sort mode; inspect Data/Config/Config.txt and the catalogs.
4. Send one disposable preset to Trash. Confirm the `Moved "..." to Trash` completion, its file under Data/Recovery/Trash and its P record in Trash Catalog.txt. Restore it; expect `Restored "..."` and its live file. Test a restore name collision and confirm the original copy-name behavior.
5. Send a test folder with several presets and an empty nested folder to Trash using the existing confirmation. Expect `Moved folder "..." and ...` or `Moved ... presets to Trash.` Check G/F/M/P records in Data/Recovery/Trash Catalog.txt. Restore the group; expect `Restored folder "..." with ...`, including the empty nested folder. Then use disposable items to test permanent delete and Empty Trash Permanently; expect `Trash emptied permanently.` Successful deletes should remove those files.
6. Load several distinct appearances and make at least six distinct pre-load snapshots. Expect `[APPEARANCE HISTORY] Saved 'Data/Recovery/Appearance History/Appearance ...' with ... options.` Repeated identical snapshots can instead log `[APPEARANCE HISTORY] Skipped an identical recovery snapshot.` Confirm the menu shows at most five entries and restore one. Inspect Appearance 1.preset through Appearance 5.preset and Data/Recovery/LastAppearance.preset. Ordinary trim removes slots 6–10; a preexisting slot 11 is a known exception.
7. Restart. Expect the three startup lines again and the same imported folders, metadata, Trash groups and history list. Successful settled operations should normally leave no Recovery Journal.txt/.tmp/.bak. Inspect those files without deleting unexpected leftovers, and keep the log.
8. For one recovery check, use only the copied disposable library. Force-close immediately after confirming a folder Trash or group restore, then restart. A journal caught prepared should roll back; committed should finish. Expect the existing `[RECOVERY]` message only if a journal was actually captured. Inspect Data/Recovery/Recovery Journal.txt and its .tmp/.bak, Trash Catalog.txt, live preset files and Trash. If no journal/recovery line appears, the operation may have finished before closing; that does not prove interruption recovery. Bundle/backup imports have no journal and can leave partial copies, so do not use them for an assumed rollback test.

The checklist and actual rendered/game restart behavior are UNVERIFIED until you run this build. Stop after stage 6; stage 7 is not started.
