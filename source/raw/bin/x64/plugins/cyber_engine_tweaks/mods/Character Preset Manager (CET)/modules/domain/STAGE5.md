# Stage 5 library and folder audit

Baseline: `50caa52660aa156ef78b6c9bd4bc2056ac2a3ce1`, confirmed in game. Stage 4 storage and recovery modules will remain unchanged.

## Before extraction: functions and callers

I will extract the pure portions of the functions below. File access, game-option capture, logging, status changes, confirmations, loader resets, and rollback writes stay in the existing adapters. Existing action names and signatures remain the entry points. Naming and collision helpers already in stage 1 keep forwarding to those same implementations.

| Source / function | Baseline callers (definitions omitted) |
|---|---|
| `view_cache.lua` / `helpers.breadcrumb` | `native_bridge.lua:112`; `native_bridge.lua:167`; `native_bridge.lua:211`; `ui/sections_bulk.lua:59`; `ui/sections_bulk.lua:82`; `ui/sections_folders.lua:18`; `ui/sections_load.lua:119`; `ui/sections_load.lua:229`; `ui/sections_save.lua:10`; `ui/sections_trash.lua:62` |
| `view_cache.lua` / `normalizeSearch` | `ui/help_panel.lua:231`; `ui/help_panel.lua:232`; `view_cache.lua:154`; `view_cache.lua:186` |
| `view_cache.lua` / `textMatches` | `view_cache.lua:161`; `view_cache.lua:174` |
| `view_cache.lua` / `validModifiedTimestamp` | `view_cache.lua:113`; `view_cache.lua:114` |
| `view_cache.lua` / `helpers.rebuildViewCache` | `view_cache.lua:132` |
| `view_cache.lua` / `helpers.rebuildFilteredViewCache` | `view_cache.lua:188` |
| `presets.lua` / `state.presetEntryCount` | `catalog.lua:97`; `catalog.lua:172`; `catalog.lua:178`; `catalog.lua:465`; `history.lua:74`; `load_engine.lua:1416`; `native_bridge.lua:109`; `presets.lua:227`; `ui/sections_load.lua:230` |
| `presets.lua` / `state.hydratePreset` | `presets.lua:100`; `presets.lua:137` |
| `presets.lua` / `state.dehydratePreset` | `events.lua:47` |
| `presets.lua` / `state.updatePresetLibraryFolder` | `backup.lua:397`; `bundles.lua:524`; `folders.lua:36`; `presets.lua:614` |
| `presets.lua` / `state.restorePresetLibraryFolder` | `folders.lua:14`; `presets.lua:625` |
| `presets.lua` / `hydrateNamedPresetMetadata` | `native_bridge.lua:300`; `ui/sections_load.lua:174` |
| `presets.lua` / `savePreset` | `native_bridge.lua:335`; `native_bridge.lua:343`; `native_bridge.lua:344`; `ui/sections_save.lua:40` |
| `presets.lua` / `renamePreset` | `ui/sections_manage.lua:30` |
| `presets.lua` / `movePresetToSelectedFolder` | `presets.lua:678`; `ui/sections_folders.lua:68`; `ui/sections_folders.lua:98` |
| `presets.lua` / `moveSelectedBulkPresetsToFolder` | `ui/sections_bulk.lua:93` |
| `presets.lua` / `savePresetMetadata` | `ui/sections_manage.lua:48` |
| `presets.lua` / `toggleSelectedPresetFavorite` | `native_bridge.lua:353`; `ui/sections_load.lua:331` |
| `presets.lua` / `duplicatePreset` | `ui/sections_manage.lua:34` |
| `presets.lua` / `uniquePresetCopyName` | `presets.lua:781`; `trash.lua:322` |
| `presets.lua` / `findExistingFolderName` | `folders.lua:64`; `folders.lua:99` |
| `presets.lua` / `folderNameExists` | `backup.lua:333`; `backup.lua:349`; `bundles.lua:472`; `bundles.lua:606`; `native_bridge.lua:319`; `native_bridge.lua:357` |
| `presets.lua` / `uniqueFolderCopyName` | `bundles.lua:472`; `folders.lua:161` |
| `folders.lua` / `syncLibraryFolders` | `folders.lua:48` |
| `folders.lua` / `persistVirtualState` | `folders.lua:70`; `folders.lua:131`; `folders.lua:220`; `folders.lua:345`; `folders.lua:359`; `presets.lua:558`; `presets.lua:621`; `presets.lua:808` |
| `folders.lua` / `createFolder` | `ui/sections_folders.lua:51` |
| `folders.lua` / `renameFolder` | `ui/sections_folders.lua:62` |
| `folders.lua` / `duplicateFolder` | `ui/sections_folders.lua:64` |
| `folders.lua` / `removeVirtualFolder` | `ui/sections_folders.lua:74` |
| `catalog.lua` / `refreshPresets` | `events.lua:257`; `native_bridge.lua:378`; `trash.lua:678`; `trash.lua:741`; `ui/sections_load.lua:83` |
| `catalog.lua` / `helpers.readCatalog` | `catalog.lua:23` |
| `catalog.lua` / `writeCatalog` | `acu_import.lua:152`; `backup.lua:405`; `backup.lua:408`; `backup.lua:422`; `bundles.lua:542`; `bundles.lua:549`; `bundles.lua:563`; `catalog.lua:210`; `folders.lua:50`; `presets.lua:427`; `presets.lua:569`; `presets.lua:579`; `trash.lua:286`; `trash.lua:293`; `trash.lua:357`; `trash.lua:365`; `trash.lua:491`; `trash.lua:502`; `trash.lua:731`; `trash.lua:744` |
| `catalog.lua` / `helpers.readInventory` | `catalog.lua:17` |
| `catalog.lua` / `writeInventory` | `acu_import.lua:154`; `backup.lua:406`; `backup.lua:410`; `backup.lua:424`; `bundles.lua:547`; `bundles.lua:565`; `catalog.lua:275`; `folders.lua:54`; `load_engine.lua:1337`; `presets.lua:451`; `presets.lua:581`; `presets.lua:736`; `presets.lua:767`; `trash.lua:309`; `trash.lua:379`; `trash.lua:523`; `trash.lua:771` |
| `native_bridge.lua` / `setPresetSortPreference` | `ui/help_panel.lua:194`, `ui/help_panel.lua:198` |

The destinations are `domain/library.lua` for preset metadata and identity bookkeeping, `domain/library_view.lua` for sorting/filtering, `domain/folders.lua` for virtual-folder maps and relocation decisions, `domain/catalog_codec.lua` for catalog contents, and `application/library.lua` for reconciling scanned files with catalog data. Each returns an explicit function table. New modules receive data and limits explicitly and have no shared runtime access.

## Fixtures before extraction

Fixtures are recorded from the unchanged baseline adapters with in-memory files before moving production code. They compare complete file bytes, return slots, status text, log order, confirmation clears, resets, library/cache state, and failure leftovers. The fake listing is a test input, not a verified capture of CET's actual dir result.

## Defects found

- The stage 1 UTF-8 byte truncation and path-validator differences remain unchanged.
- Metadata save creates a missing `created` timestamp before writing, but its failure path does not restore that field. Preserve it.
- Favorites and metadata edits use different format/source updates and rollback field lists. Preserve those differences.
- Bulk logical moves keep earlier completed moves if a later move fails. This is not an all-or-nothing operation.
- History rotation and the missing startup mutation gate remain separate known issues. No storage or recovery fixes belong here.
- Sort-setting writes are not checked before reporting the new in-memory sort mode. A failed write can leave restart behavior different from the visible setting; preserve it.
- `validModifiedTimestamp` accepts any day from 1 through 31 for every month. Its sort behavior is preserved.
- Search matches preset names and tags, not notes. I kept that scope rather than adding notes to the search.
- Case-equivalent sort keys have no total tie-breaker. I retained the same comparator and table.sort behavior.

## UNVERIFIED

The raw shape and extra fields of actual CET directory listings remain UNVERIFIED. Existing accepted name/type checks and real-game behavior from the prior stage do not establish an exact raw capture. Rendering, persistence across an actual restart, and interactions with other mods require in-game testing.


## What moved and what stayed

| Module | Extracted responsibility |
|---|---|
| `domain/library.lua` | Entry counts, hydrate/dehydrate field bookkeeping, metadata merge, saved-preset construction, header changes and restoration, notes/tags/favorite updates with their distinct rollback fields, and rename/move target paths. |
| `domain/library_view.lua` | Search normalization, matching, breadcrumbs, timestamp validation, sort-mode normalization, ordering, folder counts, and filtered view construction. |
| `domain/folders.lua` | Folder rename/remove map decisions, copying folder maps, header-sync decisions, and physical relocation plans. Preset references remain the original objects. |
| `domain/catalog_codec.lua` | Catalog record validation, catalog-line construction, inventory encoding, and old/current inventory decoding. |
| `application/library.lua` | Reconciling scanned files with assignments, preset header identities, recovered folders, physical folders, ignored folders, and startup inventory fields. |

The original modules keep all file operations, checks at game boundaries, status text, logs, confirmation clearing, cache invalidation, loader resets, and rollback writes. Catalog reading remains streamed with the same lines/seek/close behavior. No new bounded-reader conversion changes its error path.

Metadata preparation is split around the existing timestamp call. Notes and tags are assigned before that call; favorite toggling also happens before its timestamp call, as before. Copying folder maps stays before the existing storage-list read, while adding copied folders stays after it. Preset rename computes its logical target before checking collisions and computes its storage target later at the original point. These boundaries matter when an intermediate operation fails.

Existing stage 1 naming and path helpers remain the implementations for sanitizing, Windows reserved names, collision lookup, copy suffixes, and storage allocation. Their files are unchanged. Stage 4's file adapter, storage/recovery application modules, journal/Trash codecs, and compatibility filesystem adapter are also unchanged. The loader, event hooks, UI layout, redscript, native code, format 8, settings schema, limits, and persistent field layout do not change.

## Remaining forwarding entry points and adapter callers

All old entry points retain their names and signatures. Pure helpers forward to the new modules. Action entry points remain adapters around the extracted decisions because their I/O and messages must stay at the same call sites. The existing naming forwards still call the stage 1 modules.

| Entry point | Remaining shipped callers, excluding tests and definitions |
|---|---|
| `helpers.breadcrumb` | `native_bridge.lua:113` (listPayload); `native_bridge.lua:168` (listPayload); `native_bridge.lua:212` (listPayload); `ui/sections_bulk.lua:59` (drawBulkSection); `ui/sections_bulk.lua:82` (drawBulkSection); `ui/sections_folders.lua:18` (drawFoldersSection); `ui/sections_load.lua:119` (drawLoadSection); `ui/sections_load.lua:229` (drawLoadSection); `ui/sections_save.lua:10` (drawSaveSection); `ui/sections_trash.lua:62` (drawTrashSection) |
| `normalizeSearch` | `ui/help_panel.lua:231` (drawHelpPanel); `ui/help_panel.lua:232` (drawHelpPanel); `view_cache.lua:131` (ensureFilteredViewCache) |
| `textMatches` | No direct shipped caller; entry point retained. |
| `validModifiedTimestamp` | No direct shipped caller; entry point retained. |
| `helpers.rebuildViewCache` | `view_cache.lua:97` (ensureViewCache) |
| `helpers.rebuildFilteredViewCache` | `view_cache.lua:133` (ensureFilteredViewCache) |
| `state.presetEntryCount` | `catalog.lua:99` (refreshPresets); `history.lua:74` (refreshAppearanceHistory); `load_engine.lua:1416` (refreshPreflight); `native_bridge.lua:110` (listPayload); `presets.lua:196` (presetsMatch); `ui/sections_load.lua:230` (drawLoadSection) |
| `state.hydratePreset` | `presets.lua:91` (state.updatePresetLibraryFolder); `presets.lua:113` (hydrateNamedPreset) |
| `state.dehydratePreset` | `events.lua:47` (helpers.releaseIdleMemory) |
| `state.updatePresetLibraryFolder` | `backup.lua:397` (importLibraryBackup); `bundles.lua:524` (importFolderBundle); `folders.lua:29` (syncLibraryFolders); `presets.lua:572` (movePresetToSelectedFolder) |
| `state.restorePresetLibraryFolder` | `folders.lua:15` (restoreLibraryFolderChanges); `presets.lua:583` (movePresetToSelectedFolder) |
| `hydrateNamedPresetMetadata` | `native_bridge.lua:301` (handleNativeRequest); `ui/sections_load.lua:174` (drawLoadSection) |
| `savePreset` | `native_bridge.lua:336` (handleNativeRequest); `native_bridge.lua:344` (handleNativeRequest); `native_bridge.lua:345` (handleNativeRequest); `ui/sections_save.lua:40` (drawSaveSection) |
| `renamePreset` | `ui/sections_manage.lua:30` (drawManageSection) |
| `movePresetToSelectedFolder` | `presets.lua:636` (moveSelectedBulkPresetsToFolder); `ui/sections_folders.lua:68` (drawFoldersSection); `ui/sections_folders.lua:98` (drawFoldersSection) |
| `moveSelectedBulkPresetsToFolder` | `ui/sections_bulk.lua:93` (drawBulkSection) |
| `savePresetMetadata` | `ui/sections_manage.lua:48` (drawManageSection) |
| `toggleSelectedPresetFavorite` | `native_bridge.lua:354` (handleNativeRequest); `ui/sections_load.lua:331` (drawLoadSection) |
| `duplicatePreset` | `ui/sections_manage.lua:34` (drawManageSection) |
| `uniquePresetCopyName` | `presets.lua:713` (duplicatePreset); `trash.lua:322` (restoreTrashPreset) |
| `findExistingFolderName` | `folders.lua:57` (createFolder); `folders.lua:92` (renameFolder) |
| `folderNameExists` | `backup.lua:333` (uniqueImportRoot); `backup.lua:349` (importLibraryBackup); `bundles.lua:472` (importFolderBundle); `bundles.lua:606` (importAvailableFolderBundles); `native_bridge.lua:320` (handleNativeRequest); `native_bridge.lua:358` (handleNativeRequest) |
| `uniqueFolderCopyName` | `bundles.lua:472` (importFolderBundle); `folders.lua:133` (duplicateFolder) |
| `syncLibraryFolders` | `folders.lua:41` (persistVirtualState) |
| `persistVirtualState` | `folders.lua:63` (createFolder); `folders.lua:103` (renameFolder); `folders.lua:183` (duplicateFolder); `folders.lua:265` (removeVirtualFolder); `folders.lua:279` (removeVirtualFolder); `presets.lua:516` (renamePreset); `presets.lua:579` (movePresetToSelectedFolder); `presets.lua:740` (duplicatePreset) |
| `createFolder` | `ui/sections_folders.lua:51` (drawFoldersSection) |
| `renameFolder` | `ui/sections_folders.lua:62` (drawFoldersSection) |
| `duplicateFolder` | `ui/sections_folders.lua:64` (drawFoldersSection) |
| `removeVirtualFolder` | `ui/sections_folders.lua:74` (drawFoldersSection) |
| `refreshPresets` | `events.lua:257` (events.onInit); `native_bridge.lua:379` (handleNativeRequest); `trash.lua:678` (moveBulkPresetsToTrash); `trash.lua:741` (moveBulkPresetsToTrash); `ui/sections_load.lua:83` (drawLoadSection) |
| `helpers.readCatalog` | `catalog.lua:25` (refreshPresets) |
| `writeCatalog` | `acu_import.lua:152` (finishImportQueue); `backup.lua:405` (importLibraryBackup); `backup.lua:408` (importLibraryBackup); `backup.lua:422` (importLibraryBackup); `bundles.lua:542` (importFolderBundle); `bundles.lua:549` (importFolderBundle); `bundles.lua:563` (importFolderBundle); `catalog.lua:140` (refreshPresets); `folders.lua:43` (persistVirtualState); `presets.lua:385` (savePreset); `presets.lua:527` (renamePreset); `presets.lua:537` (renamePreset); `trash.lua:286` (trashPreset); `trash.lua:293` (trashPreset); `trash.lua:357` (restoreTrashPreset); `trash.lua:365` (restoreTrashPreset); `trash.lua:491` (restoreTrashGroup); `trash.lua:502` (restoreTrashGroup); `trash.lua:731` (moveBulkPresetsToTrash); `trash.lua:744` (moveBulkPresetsToTrash) |
| `helpers.readInventory` | `catalog.lua:19` (refreshPresets) |
| `writeInventory` | `acu_import.lua:154` (finishImportQueue); `backup.lua:406` (importLibraryBackup); `backup.lua:410` (importLibraryBackup); `backup.lua:424` (importLibraryBackup); `bundles.lua:547` (importFolderBundle); `bundles.lua:565` (importFolderBundle); `catalog.lua:205` (refreshPresets); `folders.lua:47` (persistVirtualState); `load_engine.lua:1337` (refreshPreflight); `presets.lua:409` (savePreset); `presets.lua:539` (renamePreset); `presets.lua:678` (savePresetMetadata); `presets.lua:699` (toggleSelectedPresetFavorite); `trash.lua:309` (trashPreset); `trash.lua:379` (restoreTrashPreset); `trash.lua:523` (restoreTrashGroup); `trash.lua:771` (moveBulkPresetsToTrash) |
| `setPresetSortPreference` | `ui/help_panel.lua:194` (drawSettingsPanel); `ui/help_panel.lua:198` (drawSettingsPanel) |

## Verified globals and sandbox gate

Every new production module uses only the following globals. The library members listed here are the complete allowed members, not permission to use the rest of those libraries.

| Global or member | Existing baseline use in modules that run in CET |
|---|---|
| `require` | init.lua and the existing domain paths/names/codecs modules. |
| `pairs` | domain/names.lua, domain/operation_result.lua, and existing library adapters. |
| `ipairs` | domain/preset_codec.lua and the existing folder/library adapters. |
| `tonumber` | domain/preset_codec.lua and domain/json.lua. |
| `tostring` | domain/preset_codec.lua and domain/operation_result.lua. |
| `type` | domain/preset_codec.lua and domain/operation_result.lua. |
| `math.max` | presets.lua in baseline savePresetMetadata; math.floor is also used by the existing pure identities codec. |
| `table.insert` | domain/preset_codec.lua and domain/trash_codec.lua. |
| `table.sort` | domain/trash_codec.lua and the existing view/catalog/folder adapters. |
| `table.concat` | domain/preset_codec.lua and domain/json.lua. |

| New production module | Complete global identifier list |
|---|---|
| domain/library.lua | require, ipairs, pairs, tonumber, math (max only) |
| domain/library_view.lua | require, ipairs, pairs, tonumber, tostring, table (insert/sort only) |
| domain/folders.lua | require, pairs, table (insert/sort only) |
| domain/catalog_codec.lua | require, ipairs, pairs, tonumber, tostring, table (insert/sort only) |
| application/library.lua | require, ipairs, pairs, type, table (insert/sort only) |

The shared union also permits table.concat because it is an existing verified baseline feature. The current five modules do not need to call it directly. No new production module gets coroutine, debug, package, io, os, _G, Game, setfenv, or a logger. Its only allowed require targets are domain/paths, domain/names, domain/codecs, and domain/library. No module loads the shared runtime.

`native/verification/check_code.js` parses all Lua files as Lua 5.1, then checks the five new modules' free global identifiers and math/table member access. This catches unverified names even in branches not exercised by fixtures.

The entire stages 1–5 run installs `domain/stage5_sandbox.lua` before loading production modules. The five new modules use the narrow allowlist above. All existing production modules required by the suites also load in restricted environments whose identifiers were collected from the immutable baseline with luaparse scope analysis. The adapter/runtime set contains 297 identifiers, including the runtime's own exported functions, constants, and CET API names. It does not add host capabilities that the baseline did not reference.

Legacy library members are restricted to io.open; os.clock/date/time/rename/remove; math.ceil/floor/max/min; table.concat/insert/remove/sort; and string.char/rep. os.rename/remove are the original file adapter's osApi operations. Missing CET API values remain nil until a fixture supplies the same explicit runtime adapter input it already supplied before this stage.

The gate rejects unknown globals, unknown math/table members, global writes, and unapproved dependencies. Negative checks deliberately try coroutine, debug, package, io, os, and _G in the new-module environment and must fail. Loading the five modules must leave the runtime cache unchanged.

The trusted test driver runs outside CET. It still needs file loading, fixture serialization, package caching, and the existing stage 4 test's debug inspection. Those tools are not exposed to production module environments and are never loaded by init.lua. I changed the stage 3 test's retired cancel-entry assertion to inspect the runtime's own table with host rawget, so the assertion no longer performs an unapproved global lookup for the removed API. Its 63 expected snapshots are unchanged.

The fake workflow iterator is injected through the fixture runtime to make unordered-map traces reproducible; new modules see the same test iterator. Production uses its original pairs behavior and comparator. This establishes equivalence under the same input iteration, not a new ordering guarantee for tied keys.

The complete baseline identifier set is encoded in `stage5_sandbox.lua` as `legacyGlobals` and is reproduced below for review. It includes data names assigned inside runtime, not 297 assumed CET engine features:

```text
ACTIVITY_LOG_PAGE_SIZE ACU_IMPORT_FILES_PER_FRAME ACU_IMPORT_POLL_SECONDS ACU_IMPORT_REQUEST_FILE ACU_IMPORT_RESULTS_FILE APPEARANCE_HISTORY_LIMIT AUTO_LOAD_LIMITS AUTO_LOAD_TIMING CATALOG_DIR
CATALOG_FILE CName CONFIG_DIR CONFIG_FILE CURRENT_PRESET_FORMAT DATA_DIR EDITOR_OPEN_TIMEOUT EMPTY_LIST EquipmentSystem
FALLBACK_NOTICE_CET_MESSAGE FALLBACK_NOTICE_DELAY_SECONDS FALLBACK_NOTICE_MESSAGE FALLBACK_NOTICE_TITLE FILE_COPY_CHUNK_SIZE FOLDER_BUNDLE_EXTENSION FORCE_FULL_LOAD_FORMAT_THRESHOLD Game GetBind
GetDisplayResolution GetLocalizedTextByKey HISTORY_DIR HISTORY_FILE_PREFIX IMPORTED_BUNDLES_FILE INVENTORY_FILE ImGui ImGuiCol ImGuiCond
ImGuiStyleVar ImGuiWindowFlags IsBound LAST_APPEARANCE_FILE LIBRARY_BACKUP_EXTENSION LOG_ARCHIVE_DIR LOG_ARCHIVE_LIMIT LOG_ARCHIVE_PREFIX LOG_DIR
LOG_FILE LocKeyToString MAX_CATALOG_BYTES MAX_CATALOG_LINES MAX_FOLDER_BUNDLE_BYTES MAX_FOLDER_BUNDLE_PRESETS MAX_LIBRARY_BACKUP_BYTES MAX_OPTION_INDEX MAX_PRESET_BYTES
MAX_PRESET_ENTRIES MAX_PRESET_KEY_BYTES MAX_PRESET_LINES MAX_TRANSACTION_BYTES MAX_TRANSACTION_LINES MAX_TREE_DEPTH MOD_NAME MorphMenuUserData NATIVE_BRIDGE_PROTOCOL
NATIVE_FILE_CATALOG NATIVE_FILE_PROTOCOL NATIVE_LIST_LIMIT NATIVE_READY_STATUS NATIVE_REQUEST_POLL_SECONDS NameToString OPTION_CHOICE_CACHE_LIMIT Observe Override
PRESET_DIR QuestDisableWardrobeSetRequest QuestRestoreWardrobeSetRequest RECOVERY_DIR SLOW_PREFLIGHT_SECONDS STALL_CONFIRMATION_PASSES STATUS_SECTIONS THEME_COLORS THEME_VARS
TRANSACTION_FILE TRASH_CATALOG_FILE TRASH_DIR ToCName UI_LIST_PAGE_SIZE VERSION WINDOW_POSITION_STATUS_FILE _G activityLogFile
activitySequence addFolderAncestors assert atomicReplace baseName beginLoadPass bit32 bulkPresetNamesInFolder canRunAppearanceRandomizer
cancelConfirmations catalogDecode catalogEncode choiceCollectionValue cleanupFailureMessage clearAppearanceHistory clearFolderBundlePreview clearStatus cloneMap
closeActivityLog collapsibleSectionHeader coloredWrapped compactSubsectionButton comparePresetWithCurrent compareSelectedPreset completeTransaction connectNativeBridgeForMenu continueLoadPass
copyFile createFolder dangerButton deleteFile deleteSelectedLibraryBackup dir directoryTreeContainsFiles draw drawBackupSection
drawBulkSection drawEditorSection drawFallbackHudNotice drawFoldersSection drawHelpPanel drawLoadSection drawManageSection drawPageControls drawSaveSection
drawSectionStatus drawSettingsPanel drawTrashSection duplicateFolder duplicatePreset emptyCustomizationName emptyTrash ensureFilteredViewCache ensureViewCache
equipmentSystem error events exportLibraryBackup exportSelectedBulkPresetBundle exportSelectedFolderBundle fileExists fileFingerprint findExistingFolderName
findPresetCollision finishCompactSubsection folderAncestorsExpanded folderBundleFiles folderDepth folderNameExists folderPath fullWidthButton gameWardrobeClothingSetIndex
gameuiCharacterCustomizationEditTag getOptions helpHeading helpers hydrateNamedPreset hydrateNamedPresetMetadata importAvailableFolderBundles importLibraryBackup initializeAcuImport
initializeNativeBridge invalidateBulkSelectionCache invalidateFilteredViewCache invalidatePresetAndTrashCaches invalidateViewCache io ipairs isFolderBundleFilename isInFolderTree
isRuntimePointerText joinFolder libraryBackupFiles loadPreset log logAcuDangerousOptions logTimestamp math movePresetToSelectedFolder
moveSelectedBulkPresetsToFolder nativeCatalogDirectoryEntries next normalizeSearch occurrenceKeyParts openFullAppearanceEditor optionAuditIdentity optionChoiceIndex optionChoiceMatchesIndex
optionIndexIsValid optionIndexValidationError optionKey optionSlot os pagedRange pairs parentFolder pcall
persistVirtualState popFoldingHeaderTheme popTheme presetPath presetsMatch pushFoldingHeaderTheme pushTheme readBoundedFile readConfig
readNativeFileCatalog readPresetFile readVerifiedPresetCopy recoverTransaction refreshAppearanceHistory refreshCustomizationUi refreshEditorState refreshPreflight refreshPresets
refreshTrash remapFolderTreePath removeEmptyDirectoryTree removeFileList removeVirtualFolder renameFile renameFolder renamePreset requestAcuImport
requestBulkTrash require resetLoadState restoreAppearanceHistory restoreLastAppearance restoreTemporarilyDisabledWardrobe restoreTrashBundle restoreTrashGroup restoreTrashPreset
runAppearanceRandomizer safeDirectoryEntries sanitizeMetadata sanitizeName saveAppearanceHistorySnapshot saveLastAppearanceSnapshot savePreset savePresetMetadata savedEntryAuditIdentity
selectedBulkPresetNames setEditorOpenStatus setPresetSortPreference setStatus setfenv setmetatable sortedFolderNames stableChoiceIdentity stableRuntimeValue
state storageFilenamesInUse string table temporarilyDisableWardrobe textMatches toggleSelectedPresetFavorite tonumber tostring
trashPreset trashSelectedFolderBundle trimAppearanceHistory type ui uniqueFolderCopyName uniquePresetCopyName uniqueStorageName unresolvedSignature
updateAcuImport updateNativeBridge utf8 validModifiedTimestamp validRelativePath validatedFolderName validatedPresetName verifiedNativeFileCatalog viewSelectedFolderBundleContents
writeCatalog writeConfig writeFileSafely writeInventory writeLinesIfChanged writeLog writePresetContents writePresetPath writeTransaction
```

## Fixture provenance and results

I recorded the first fixtures before changing production code. Expanded cases were recorded by preloading the unchanged adapters from `50caa52660aa156ef78b6c9bd4bc2056ac2a3ce1`, not by accepting the extracted code as the baseline. The golden file pools repeated tables to keep it smaller, then reconstructs the same exact serialized snapshots.

There are 119 successful operation/input cases, 3,353 single failure runs, and 2,877 paired mutation/rollback failures: 6,349 comparisons total. Single failures include 1,975 open/write/flush/close steps, 267 renames, 363 deletes, and 748 read/seek/list steps. The paired cases reach distinct rollback branches after the first failure and inject a second write, rename, or delete failure there.

Snapshots compare the full in-memory disk map, individual written chunks, return-slot count including nils, status fields, logs and their order, timestamp boundary observations, loader resets, confirmation clearing, library/cache state, and partial-file leftovers. Cases include save/overwrite confirmation, stale confirmations, metadata/favorites, copy/move/rename, nested and imported folders, duplicate storage identities, case-only collisions, Unicode, reserved names, trailing spaces/periods, oversized notes/tags, both sort modes and fallback, search scope, malformed catalogs, old inventory records, and startup/external reconciliation.

| Check | Result |
|---|---|
| Stage 1 | 833 fixtures and additional compatibility checks pass. |
| Stage 2 | 183 cases, 62 writer comparisons, and seven byte-identical format-8 round trips pass. |
| Stage 3 | 63 snapshots and timeout/camera/bridge/restart checks pass. |
| Stage 4 | 2,981 comparisons, 396 interruption recoveries, and the missing-coroutine regression pass with original fixtures. |
| Stage 5 | All 6,349 baseline comparisons pass. |
| Identity checks | Header-change references, folder maps retaining preset objects, and saved entry-array references pass. |
| Restricted environments | All five suites pass while production modules are restricted as described above. |
| Syntax and static globals | All 62 Lua files pass Lua 5.1 parsing; every new production module's globals pass the allowlist check. |
| redscript | Four unchanged CPM scripts and five installed Codeware scripts compile against the current game cache in an isolated temporary tree. |

The stage 4 storage/recovery files, existing domain/names and domain/paths, loader, and event hooks match the confirmed baseline. Written catalog, inventory, preset header, and Config.txt bytes match the old code for every recorded input, including failed operations. No new format, setting, location, dependency, or persistent field is introduced.

To reproduce the restricted run, start a fresh Lua 5.1 process for each stage from the repository root. Add the CET mod directory to package.path in the test driver, call `require("modules/domain/stage5_sandbox").install(moduleRoot)`, then dofile that stage's test. Stage 5 installs the gate itself. Run `node native/verification/check_code.js` afterward. The host's Lua 5.1 DLL was used for validation; it is not a new shipped dependency.

## Exact install list

The full stage 5 test ZIP contains the complete matching build under the three existing shipped roots. Install through Vortex or extract into the main game folder with overwrites, then fully restart. Keep the complete modules folder.

Changed runtime files under the CET mod directory:

- modules/catalog.lua
- modules/presets.lua
- modules/folders.lua
- modules/view_cache.lua
- modules/native_bridge.lua

Every new runtime file:

- modules/domain/library.lua
- modules/domain/library_view.lua
- modules/domain/folders.lua
- modules/domain/catalog_codec.lua
- modules/application/library.lua

New validation/audit files included in the test ZIP:

- modules/domain/stage5_tests.lua
- modules/domain/stage5_fixtures.lua
- modules/domain/stage5_sandbox.lua
- modules/domain/STAGE5.md

The ZIP also includes the one-line stage 3 assertion update in modules/domain/stage3_tests.lua. CHANGELOG.md and native/verification/check_code.js are repository-only changes. There is no release or version bump, and no DLL or redscript change.

## In-game checklist

Use disposable presets and a test folder for collision and removal checks. Paths below are relative to the CET mod directory. Preserve `Data/Logs/Activity.log` and the per-mod `Character Preset Manager (CET).log` if something fails.

| Action | Expected status/log evidence | Files and persistence to inspect |
|---|---|---|
| Start the game; open both menus | `[CONFIG] Loaded ...`, `Preset files loaded: presets=...`, and `[NATIVE PANEL] Native bridge connected.` when available. The preset list is populated. No new require, forbidden-global, or nil-value error should appear. | Existing presets remain under Character Presets; catalog and inventory remain readable under Data/Catalog. |
| Add then remove a favorite | `Added "..." to Favorites.` then `Removed "..." from Favorites.` with the existing load/complete level. The favorite display changes in both menus. | The selected preset's Favorite heading changes and Data/Catalog/Preset Inventory.txt updates. Reopen both menus and verify the current value. |
| Edit notes and tags | `[rename] Saved details for "...".`; successful inventory message or the existing warning if it fails. | Notes and Tags in the preset match sanitized input. Verify the same details after restart. Older presets upgrade only through the existing explicit write action. |
| Create a folder, rename it, then remove it while keeping presets | `[FOLDER] Created virtual folder`, `[FOLDER] Virtual rename completed:`, and the `[folder] Removed folder ... kept all presets` status. Use the existing confirmation for removal. | Data/Catalog/Virtual Folders.txt changes. Current-format preset Library folder headings follow the new logical folder. Ordinary virtual folders do not require matching Windows directories. |
| Move presets between two folders | `[PRESET] Virtual move completed:` and `[folder] Moved ...`. For bulk moves, expect the existing bulk status and per-item completion lines. | Physical storage stays where the old behavior keeps it; logical paths and current preset headers agree. Check both catalogs. |
| Duplicate a preset and then its folder | `[PRESET] Duplicate completed:` and `[FOLDER] Virtual duplicate completed:`. Copied names use the existing Copy/Copy N suffixes. | New physical preset files exist, catalog mappings point to them, and copied headers identify the new library names. The originals remain readable. |
| Try case-only, existing, reserved, Unicode, and trailing-space/period names | The existing collision/reserved-name status appears where applicable. Trailing spaces retain the existing trimming behavior; do not expect a new rejection rule. No success log should claim a rejected rename. | Rejected actions keep original files and mappings. Accepted Unicode names preserve baseline byte behavior, including the known byte-truncation limit. |
| Select name sort, then modified sort | Settings status reads `Presets are sorted by name.` or `Presets are sorted by the date they were last changed.` There is no dedicated sort-success log. Modified sort puts newer valid timestamps first and retains the old fallback/tie behavior. | Data/Config/Config.txt contains presetSort=name or presetSort=modified. |
| Fully restart the game | `[CONFIG] Loaded ... presetSort=...` reflects the last successfully saved setting. Recheck presets, favorites, notes/tags, folder paths, copies, and sort order in both menus. | Preset headers, Data/Catalog/Virtual Folders.txt, Data/Catalog/Preset Inventory.txt, and Data/Config/Config.txt agree with the UI. Record any .tmp/.bak or recovery-journal leftovers rather than assuming they were cleaned. |

Search by a name and a tag as an extra check; notes alone do not match in the baseline. Do not treat tied sort keys as having a newly stable order.

**UNVERIFIED:** this stage's rendered menu behavior and persistence through a real game restart. The fake directory listing remains UNVERIFIED as a copy of CET's raw return format. Automated fixtures establish equivalence for the supplied inputs, not full game compatibility.

Stop after stage 5. Stage 6 requires the user's confirmation.
