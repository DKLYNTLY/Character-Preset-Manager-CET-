# Stage 7 matching audit

Baseline: `758189928482b8e65fdb7f76236250bf5f42594e`.

## Before extraction

Pure sections of the following boundaries will move to domain/matching.lua and domain/comparison.lua. Game reads, caches, writes, timing, state transitions, status and logs remain in their adapters. Existing identity primitives in domain/identities.lua are reused unchanged.

| Boundary | Baseline callers |
|---|---|
| `optionKey` | `acu_import.lua:94`; `comparison.lua:41`; `history.lua:16`; `load_engine.lua:103`; `load_engine.lua:217`; `load_engine.lua:225`; `load_engine.lua:471`; `load_engine.lua:620`; `load_engine.lua:1363`; `options.lua:90`; `presets.lua:307`; `presets.lua:421` |
| `optionSlot` | `comparison.lua:45`; `history.lua:24`; `load_engine.lua:104`; `load_engine.lua:219`; `load_engine.lua:472`; `load_engine.lua:620`; `load_engine.lua:1368`; `options.lua:92`; `presets.lua:346`; `presets.lua:433` |
| `isRuntimePointerText` | `options.lua:29`; `options.lua:35`; `options.lua:45`; `options.lua:48` |
| `stableRuntimeValue` | `options.lua:67` |
| `stableChoiceIdentity` | `options.lua:53`; `options.lua:156`; `options.lua:187` |
| `choiceCollectionValue` | `options.lua:75`; `options.lua:118`; `options.lua:169`; `options.lua:178`; `options.lua:195` |
| `optionChoiceKey` | `history.lua:25`; `presets.lua:347`; `presets.lua:434` |
| `bindOptionCatalog` | `options.lua:300` |
| `cachedOptionChoices` | `options.lua:165`; `options.lua:172` |
| `optionChoiceIndex` | `comparison.lua:97`; `load_engine.lua:185`; `load_engine.lua:1394`; `load_engine.lua:1401` |
| `optionChoiceMatchesIndex` | `load_engine.lua:184`; `load_engine.lua:622`; `load_engine.lua:767` |
| `optionIndexValidationError` | `history.lua:20`; `options.lua:235`; `presets.lua:335`; `presets.lua:425` |
| `optionIndexIsValid` | `comparison.lua:92`; `load_engine.lua:590`; `load_engine.lua:825`; `load_engine.lua:859`; `load_engine.lua:963`; `load_engine.lua:1021`; `load_engine.lua:1048`; `load_engine.lua:1398`; `options.lua:239`; `options.lua:242`; `options.lua:243`; `options.lua:244`; `options.lua:245`; `options.lua:246`; `options.lua:247` |
| `occurrenceKeyParts` | `load_engine.lua:941`; `load_engine.lua:1119`; `load_engine.lua:1126`; `options.lua:251` |
| `preparePresetEntries` | `comparison.lua:69`; `load_engine.lua:677` |
| `liveAppearanceIndex` | `comparison.lua:70` |
| `comparePresetWithCurrent` | `comparison.lua:152` |
| `scanLoadOptions` | `load_engine.lua:703` |
| `loadOptionNeedsLongSettle` | `load_engine.lua:267` |
| `isSecondaryLoadOption` | `load_engine.lua:581` |
| `finalVerifyUnconfirmed` | `load_engine.lua:1179` |
| `applyLoadGroup` | `load_engine.lua:805` |
| `continueLoadPass` | `load_engine.lua:1280` |
| `refreshPreflight` | `ui/sections_load.lua:311` |

The eyelash fixture will use the exact logged identities and indices, with other options modeled explicitly. Missing installed preset dependencies can explain these warnings. The logs do not prove a matching bug or provide a complete real Codeware option snapshot.

## What moved and what stayed

- domain/matching.lua returns explicit functions for slot validation, identity/occurrence keys, choice parsing and source checks, duplicate-index policy, index lookup, count agreement, unavailable/reverted/unconfirmed classification, remap identity, cleanup eligibility, secondary/long-settle text rules, anchored legacy selection, and completion classification.
- domain/comparison.lua returns saved-entry preparation and the separate comparison/preflight classifiers. Their differences remain deliberate copies of the baseline behavior.
- Existing domain/identities.lua still owns stable choice normalization, pointer-text rejection, occurrence parsing and Uint32 index validation. Its functions were already pure; it is reused unchanged.
- options.lua still reads/protects game fields, converts runtime values and owns all option caches. It reads a choice value at the original point and forwards matching values to the duplicate-resolution policy. This avoids an added function call for every nonmatching choice in large collections.
- comparison.lua still captures live fields, keeps game-object references locally, resolves choices through the original adapter, and builds the returned comparison at its old call sites.
- load_engine.lua still owns sequencing, pending/batch work, writes, retries, confirmation deadlines, state updates and logs. Its matching branches now delegate decisions using existing scalar captures and plain maps. No whole choice snapshot is built each frame.

No persistent fields, formats, settings, dependencies or limits changed. Game-object references do not enter either new module. An instrumented run recursively checks every exported function input and rejects proxy/metatable/function/userdata values. The model tests use Lua proxy objects at the boundary, not claims about Codeware's actual representation.

## Remaining old entry points and callers

These entries retain their names and return contracts. The IO/game portions remain adapters; their pure portions forward to the new function tables. Other existing identity forwarders also remain unchanged.

| Entry | Remaining shipped callers, current module-relative lines |
|---|---|
| `optionSlot` | `comparison.lua:19`; `history.lua:24`; `load_engine.lua:106`; `load_engine.lua:217`; `load_engine.lua:468`; `load_engine.lua:608`; `load_engine.lua:1349`; `options.lua:91`; `presets.lua:346`; `presets.lua:433` |
| `optionChoiceKey` | `history.lua:25`; `presets.lua:347`; `presets.lua:434` |
| `bindOptionCatalog` | `options.lua:296` |
| `cachedOptionChoices` | `options.lua:159`; `options.lua:166` |
| `optionChoiceIndex` | `comparison.lua:69`; `load_engine.lua:187`; `load_engine.lua:1375`; `load_engine.lua:1381` |
| `optionChoiceMatchesIndex` | `load_engine.lua:186`; `load_engine.lua:610`; `load_engine.lua:749` |
| `preparePresetEntries` | `comparison.lua:9`; `comparison.lua:43`; `load_engine.lua:665` |
| `liveAppearanceIndex` | `comparison.lua:44` |
| `comparePresetWithCurrent` | `comparison.lua:108` |
| `scanLoadOptions` | `load_engine.lua:691` |
| `loadOptionNeedsLongSettle` | `load_engine.lua:262` |
| `checkPendingChange` | `load_engine.lua:536`; `load_engine.lua:699` |
| `finalVerifyUnconfirmed` | `load_engine.lua:1159` |
| `isSecondaryLoadOption` | `load_engine.lua:569` |
| `applyLoadGroup` | `load_engine.lua:782` |
| `continueLoadPass` | `load_engine.lua:1261` |
| `refreshPreflight` | `ui/sections_load.lua:311` |

## Baseline fixtures and validation

I recorded the first fixtures before changing production files. Expanded cases were then recorded from immutable options.lua, comparison.lua and load_engine.lua sources at commit 7581899 through the restricted loader's explicit source override. I did not regenerate expected results from extracted code.

All 67 fixtures pass against both original and extracted code. Each compares preparation output, comparison and fallback preflight, full log/status/write order, ordered game-field reads, cache builds/hits, original matching API call counts, final live values, satisfaction/unconfirmed/forced/cleanup maps, remaps, resolved indices, pass/phase and exact SUMMARY text. Failures and empty/scan-only cases with no SUMMARY remain marked as not emitted.

Coverage includes repeated labels and slots, missing/hidden/zero choices, reordered/duplicate choices, same-size cache mutations, unavailable fields, Unicode, malformed identities, invalid/fractional/NaN/Uint32 indices, 1,000 CCXL-style choices, a collection above the 16,384-choice cache limit, and more than the preset entry limit in a live snapshot. It includes formats 1–8, readable format 8, ACU text, and ACU 3.0.0/current JSON-derived entries. Some oversized cases intentionally scan/compare without a full load. Three additional end-to-end cases call the real loadPreset entry point through completion/stall, including per-frame memo clearing, real getOptions/binding, pending writes, and final working-data release. The game and history capture remain mocks; editor hooks are outside this stage.

The log-derived cases use actual identities and targets. Their surrounding available options are modeled, because logs do not contain a complete real option snapshot. In particular, modeled Alina reproduces 48 applied / 2 unresolved but does not claim to reproduce the real 31-pass timing.

| Gate | Result |
|---|---|
| Stage 1 | 833 fixtures, plus binary/naming/fallback checks pass. |
| Stage 2 | 183 fixtures, 62 accepted-write checks and 7 format-8 round trips pass. |
| Stage 3 | 63 state fixtures and timeout checks pass. |
| Stage 4 | 2,981 comparisons, including 396 interruption/recovery cases pass. |
| Stage 5 | 6,349 comparisons pass. |
| Stage 6 | 9,039 comparisons, including 426 interruptions, pass. |
| Stage 7 | 67 complete baseline comparisons pass in the restricted environment. |
| Lua 5.1 | All 75 Lua files parse with the repository's installed luaparse. Tests execute in the installed Lua 5.1 DLL. |
| redscript | Isolated installed scc compile succeeds against copied vanilla cache and installed Codeware declarations. Shipped redscript is unchanged. |

### SUMMARY counts for every fixture

Applied below reads the baseline's `applied` field on a stopped load or `processed` on completion. A dash means the baseline SUMMARY does not emit that field; it is not an assumed zero. The full original and new SUMMARY strings match, including confirmed/unconfirmed, result and ordering. The load's remaining count also matches independently.

| Fixture | Applied/processed | Unresolved | Forced | cleanupUnconfirmed | Result |
|---|---:|---:|---:|---:|---|
| vanilla | 1 | - | 0 | 0 | complete |
| choice reordered | 1 | - | 0 | 0 | complete |
| duplicate choice | 0 | 1 | - | - | stopped |
| cached unique becomes duplicate | 1 | - | 0 | 0 | complete |
| cache mutate | 0 | 1 | - | - | stopped |
| cached duplicate becomes unique | 0 | 1 | - | - | stopped |
| missing choice | 0 | 1 | - | - | stopped |
| choice Unicode | 1 | - | 0 | 0 | complete |
| missing nonzero | 0 | 1 | - | - | stopped |
| missing zero | 1 | - | 0 | 0 | complete |
| repeated labels equal | 2 | - | 0 | 0 | complete |
| repeated labels mismatch | 0 | 1 | - | - | stopped |
| duplicate slots | 0 | 1 | - | - | stopped |
| slot remap | 1 | - | 0 | 0 | complete |
| force missing choice fallback | 1 | - | 1 | 0 | complete |
| legacy anchored | 3 | - | 1 | 0 | complete |
| inactive | 0 | 1 | - | - | stopped |
| not editable | 0 | 1 | - | - | stopped |
| unconfirmed saved | 1 | - | 0 | 0 | complete-with-warning |
| unconfirmed cleanup | 1 | - | 0 | 1 | complete-with-warning |
| unconfirmed pubic log | 1 | - | 0 | 0 | complete-with-warning |
| write failure | - | - | - | - | - |
| dependent disappears | 1 | - | 0 | 0 | complete |
| dependency shape | 1 | - | 0 | 0 | complete |
| dependency reorder | 1 | - | 0 | 0 | complete |
| cleanup extras | 1 | - | 0 | 0 | complete |
| cleanup protected slot | 1 | - | 0 | 0 | complete |
| cleanup zero slot | 1 | - | 0 | 0 | complete |
| empty | - | - | - | - | - |
| empty live | 0 | 1 | - | - | stopped |
| invalid index | 0 | 1 | - | - | stopped |
| negative index | 0 | 1 | - | - | stopped |
| numeric string | 1 | - | 0 | 0 | complete |
| NaN | 0 | 1 | - | - | stopped |
| bad slot control | 1 | - | 0 | 0 | complete |
| bad slot oversized | 1 | - | 0 | 0 | complete |
| missing info field | 1 | - | 0 | 0 | complete |
| choice field definitions | 1 | - | 0 | 0 | complete |
| choice field options | 1 | - | 0 | 0 | complete |
| choice field morphNames | 1 | - | 0 | 0 | complete |
| identity  | 0 | 1 | - | - | stopped |
| identity options: | 0 | 1 | - | - | stopped |
| identity unknown:two | 0 | 1 | - | - | stopped |
| identity definitions:table: 0x123 | 0 | 1 | - | - | stopped |
| identity options:userdata: 0x123 | 0 | 1 | - | - | stopped |
| identity options:猫 | 0 | 1 | - | - | stopped |
| legacy format 1 | 1 | - | 0 | 0 | complete |
| legacy format 2 | 1 | - | 0 | 0 | complete |
| legacy format 3 | 1 | - | 0 | 0 | complete |
| legacy format 4 | 1 | - | 0 | 0 | complete |
| legacy format 5 | 1 | - | 0 | 0 | complete |
| legacy format 6 | 1 | - | 0 | 0 | complete |
| legacy format 7 | 1 | - | 0 | 0 | complete |
| legacy format 8 | 1 | - | 0 | 0 | complete |
| ACU text | 1 | - | 0 | 0 | complete |
| ACU JSON | 1 | - | 0 | 0 | complete |
| readable format 8 | 1 | - | 0 | 0 | complete |
| ACU 3.0.0 JSON | 1 | - | 0 | 0 | complete |
| Uint32 maximum | 1 | - | 0 | 0 | complete |
| full pipeline vanilla | 1 | - | 0 | 0 | complete |
| full pipeline unavailable | 0 | 1 | - | - | stopped |
| full pipeline CCXL | 1 | - | 0 | 0 | complete |
| CCXL many choices | 1 | - | 0 | 0 | complete |
| above choice cache limit | - | - | - | - | - |
| oversized live snapshot | - | - | - | - | - |
| Alina eyelash log identities | 48 | 2 | - | - | stopped |
| archived unavailable identities | 0 | 3 | - | - | stopped |

## Per-frame work and cache ownership

A source-instrumented comparison wraps every Lua table constructor in the original three adapters and the two new modules, then runs the same fixtures. The original/new constructor counts match in all 67 cases. Those baseline counts are stored in stage7_fixtures.allocations; instrumented test runs assert them for each case. Full fixtures separately prove identical original API calls, game reads and writes, cache builds/hits and scans. No new table, closure, full-list capture or additional traversal was added to the hot matching path. Existing allocations in the baseline remain, including loadChoiceShape's tables and the secondary-word list.

The following counts cover the complete fixture, including its initial comparison/preflight and probes. Each before/after pair is equal. New pure dispatches are shown separately: extraction necessarily adds thin function calls at old inline decision points. I do not claim zero raw call overhead or verified real CET frame time. These are logical-work/table-allocation checks, not a game FPS benchmark.

| Fixture | Scans old/new | Resolve calls old/new | Choice lookup old/new | Writes old/new | Existing API calls old/new | New pure dispatches | Tables old/new |
|---|---:|---:|---:|---:|---:|---:|---:|
| vanilla | 5/5 | 0/0 | 0/0 | 1/1 | 91/91 | 52 | 147/147 |
| unconfirmed saved | 8/8 | 3/3 | 3/3 | 1/1 | 163/163 | 76 | 192/192 |
| unconfirmed cleanup | 11/11 | 0/0 | 0/0 | 1/1 | 148/148 | 118 | 254/254 |
| cleanup extras | 11/11 | 0/0 | 0/0 | 2/2 | 150/150 | 118 | 266/266 |
| full pipeline vanilla | 5/5 | 0/0 | 0/0 | 1/1 | 107/107 | 63 | 187/187 |
| full pipeline unavailable | 5/5 | 0/0 | 0/0 | 0/0 | 103/103 | 54 | 142/142 |
| full pipeline CCXL | 6/6 | 3/3 | 3/3 | 1/1 | 6143/6143 | 79 | 208/208 |
| CCXL many choices | 6/6 | 3/3 | 3/3 | 1/1 | 6124/6124 | 66 | 160/160 |
| Alina eyelash log identities | 5/5 | 0/0 | 0/0 | 0/0 | 933/933 | 1712 | 2064/2064 |

Source checks also confirm the stateModel call sequence and arguments are identical. Pending polling and writes, confirmLoadGroup, writeLoadGroup, beginLoadPass and the load entry/game-boundary bodies are textually unchanged. checkPendingChange only delegates its identity predicate; its timing and transitions stay in place.

| Cache | Owner and key | Existing invalidation/lifetime, preserved |
|---|---|---|
| optionsMemo | state.app; cached system/options/error | getOptions(forceRefresh) bypasses it; events.onUpdate clears it each update; successful beginPendingChange, native randomizer, overlay open, idle release and working-data release clear it. clearOptionCatalog clears it too. |
| optionCatalog | state.app; length-prefixed label + slot + occurrence; fields hold size/values/indexes | This is the leftover options.lua cache noted in PLAN. bindOptionCatalog prunes missing entries and reuses surviving entries. It is not removed or moved into the domain. |
| optionChoiceBindings | state.app; weak option-object keys, entry + checked fields | Rebuilt by every bindOptionCatalog. First lookup checks the field; repeated same-size lookups reuse it. Positive results verify the selected value, resetting checked/rebuilding on disagreement; negative/duplicate results return without that recheck. Size above OPTION_CHOICE_CACHE_LIMIT bypasses it. |
| catalog clear | helpers.clearOptionCatalog -> stateModel.clearOptionCatalog | Refresh Options; missing/unready getOptions; body-morph OnInitialize/OnUninitialize hooks; shutdown. Clears catalog, bindings and memo. Idle release alone does not clear the catalog. |
| resolvedChoiceIndexes | state.load; saved occurrence key | resolveLoadChoice validates the cached index against the current choice before fallback. Reset by begin/reset/release and resetChoiceCaches. Scan structure changes and pending identity/shape/target-poll fallback call resetChoiceCaches. |
| optionIdentityCache | state.load; key + occurrence | Same begin/reset/release/resetChoiceCaches paths. Stores display/audit text, not game objects. |
| scanResult/records/signatureParts | state.load; reused records and maps | Clear/reuse on each scan, release/reset removes it. Signature rebuild conditions, lastOptionCount and forceStructureScan are unchanged. |
| dependencyRemaps | state.load; live occurrence key | Reset with choice caches, begin/reset/release. Cleanup removes a remap when identity/value/choice no longer qualifies. |
| emptyCustomizationName | runtime CName cached in options.lua | Created once on the first successful getOptions call. No explicit clear in the baseline; preserved. This game value never enters the new modules. |

## Restricted global list

Both new modules return explicit function tables. They have no runtime, file, logging, Game or UI access.

| Module | Referenced globals | Baseline source proving use |
|---|---|---|
| domain/matching | require, ipairs, math.floor, tonumber, tostring, type | options.lua uses all of these in CET; math.floor validates indices. |
| domain/comparison | ipairs, tonumber, tostring | comparison.lua's original preparation/classification uses these. |

The stage 5–7 pure-module allowlist is:

```text
ipairs, pairs, require, tonumber, tostring, type
math.floor, math.max
table.concat, table.insert, table.sort
```

Dependencies are the existing domain paths/names/codecs/library/folders/identities and the two new pure modules. The new sandbox rejects unknown reads/writes, library members and unlisted dependencies. It self-tests rejection of coroutine, debug, package, io, os and _G. Legacy production modules retain the 297-name baseline allowlist and namespace restrictions printed below. Trusted test code can use host tools to load immutable sources and instrument constructors; those tools are not exposed to production modules.

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

Real CET collection lengths/indexing, CName/LocKey conversion, option activity, delayed currIndex reporting and Codeware list changes remain UNVERIFIED without captured real snapshots. The fake directory listing from earlier stages is still UNVERIFIED; this stage does not change it. No new game API was introduced.

## Defects found

The following observations and odd behavior are retained, without a bug fix:

1. **Eyelashes may be a missing-mod/preset dependency issue.** The old Activity log reports LocKey#13879517178655718515 / eyelashes_options / options:UI-Customization-icxrus_softnaturaleyelashes / index 2 and LocKey#8824472266055663870 / eyelash_color / index 2 unavailable, then 48 applied / 2 unresolved. options.lua optionKey/optionChoiceIndex -> load_engine.lua continueLoadPass's unavailable branch (current lines 1105–1112) and the unchanged repeated-unresolved stop path produce this. New matching.unavailableReason/disposition preserve it. This is not proof of a loader defect, especially with preset mods missing.
2. **Other unavailable identities stay unavailable.** Archive Activity 2026-10-28_23-57-23.txt lines 321–323 reports LocKey#7910919425215809506, #7910918325704181295 and #7910917226192553084 at target 101, format 4. The fixture uses those identities/targets. Named choices that cannot be resolved follow load_engine.lua lines 842–848, logging `[SKIPPED] Saved choice is no longer exposed ...`; missing selectors follow the unavailable branch above. An absent zero target is still considered clear.
3. **Unconfirmed writes are not repeated.** checkPendingChange retains its apply-not-confirmed and cleanup-not-confirmed paths (lines 395–408). Archived pubic_hair LocKey#13523242420079111419 / target 3 / reported 0 and cleanup LocKey#11868209119990413348 are modeled. The former sets satisfied + unconfirmed; the latter sets cleanupSkipped. Both can complete with a warning. Real game visibility cannot be inferred from currIndex alone.
4. **Rapid-load visible hair/cyberware remains unresolved.** The extracted cleanup decisions are matching.keepRemap and matching.cleanupNeeded, used in continueLoadPass lines 743–767. They clear only extra label occurrences with a nonzero current index, without a protected nonzero saved slot, valid satisfied remap, cleanupSkipped or stageApplied flag. A matching saved slot/remap, zero reported current, hidden/inactive option, or skipped/unconfirmed cleanup can leave a visible choice unchanged. checkPendingChange may also accept a disappeared dependent option as settled. The adapter only runs cleanup in its existing precleanup/cleanup phases; a superseding load can interrupt those phases. No scheduling or reset behavior changed. These are possible paths, not proof of the visual root cause.
5. **Choice cache gaps remain.** options.lua cachedOptionChoices/optionChoiceIndex can retain a negative/duplicate result through a same-size mutation until a fresh binding/check. A positive cached index checks its own current value, but can miss a new duplicate elsewhere in the same-size list. Both directions are baseline fixtures; domain/matching.choiceIndexes preserves false-as-duplicate policy.
6. **Malformed identity index checks can return true.** optionChoiceMatchesIndex normalizes an unsupported identity to nil; its original guard does not reject nil field/wanted. A failed/missing collection read returns nil, so nil == nil may report a match. This is preserved and covered by the direct probes.
7. **Force Full Load can fall back to the numeric saved index after a missing named choice.** continueLoadPass's force branch keeps `entry.choice and resolveLoadChoice(...) or entry.index` unchanged. The fixture force missing choice fallback records the result. Its warning wording and fallback behavior were not reconciled.
8. **Comparison and loader cleanup differ.** Comparison counts extra label occurrences as Will clear, while actual cleanup can protect a saved slot or remap. Comparison also reports entry.index as detail.target even when a choice resolves to another index. Missing zero choices, forced counts and stopped SUMMARY omissions retain their original conventions.

No matching fix, dependency install, cache removal or cleanup improvement is included. Stage 8 remains separate.

## Exact install files

Close the game and extract the Stage 7 Test ZIP into the Cyberpunk 2077 folder. Preserve Character Presets and Data. Runtime changes are these five files below bin/x67/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/modules:

```text
options.lua
comparison.lua
load_engine.lua
domain/matching.lua
domain/comparison.lua
```

The archive also adds domain/STAGE7.md, domain/stage7_tests.lua, domain/stage7_fixtures.lua and domain/stage7_sandbox.lua. These are audit/test files, not required by init.lua. Existing stage 1–6 modules, hooks, UI, redscript and native plugin remain included and unchanged. Repository-only CHANGELOG.md and native/verification/check_code.js are not installed. Version 4.0.1 and bridge protocol 1 stay the same.

## In-game checklist

Keep a copy of the Stage 6 Data/Logs/Activity.log (latest successful example: line 106, October 28 23:57:59, ss/ssss processed=59 confirmed=59 unconfirmed=0 forced=0 cleanupUnconfirmed=0 passes=6 result=complete). Use the same presets and installed mods for a comparison. Changing mods changes the available snapshot, so it does not establish an extraction regression.

1. Start the game and open an editor. Expect `[CONFIG] Loaded ...`, `Preset files loaded: presets=...`, and `[NATIVE PANEL] Native bridge connected.` Confirm both menus remain responsive and no require/global/runtime/compile errors appear. New pure modules intentionally do not log loaded lines.
2. Load a vanilla-only preset. Compare CHANGE/SETTLED identities and targets to Stage 6. Expect SUMMARY with processed/confirmed equal to the preset's saved count, unconfirmed=0, forced=0, cleanupUnconfirmed=0, result=complete when the baseline also confirms every choice. The stopped SUMMARY uses applied/unresolved instead; it does not contain all success fields.
3. Load a CC/CCXL preset with many choices and its required mods installed. Confirm the same named hair/color/skin choice is selected. Reordered named choices may log `CHOICE REMAP | ... savedIndex=... currentIndex=... choice='...'`. Compare final counts and classifications to Stage 6; pass counts and wait times can vary with game scheduling.
4. Load a preset with repeated option names. Confirm occurrence numbers and slot-based matches follow the same order. Where saved/live counts differ and no safe remap exists, expect `[SKIPPED] Ambiguous repeated option: ... savedCount=... exposedCount=...` and the same stopped result as Stage 6. Do not expect arbitrary duplicate choices to be selected.
5. Load a disposable preset that references a missing named choice. Expect `[SKIPPED] Saved choice is no longer exposed ...` or the same existing forced fallback if Force Full Load is enabled. For a missing selector, expect `[SKIPPED] Saved option unavailable in current editor/body setup: ...`. Expect the same unresolved count and result=stopped as Stage 6 under identical inputs. A hidden saved zero target may instead log VERIFY and count as clear.
6. For the known Alina example, only reproduce the old missing-mod setup if that is your test condition. Expect the two logged eyelash identities above and 48 applied / 2 unresolved when the same 50 entries and available options apply. A complete result after installing the required preset mods would not be a regression. Preserve the stop/warning behavior; do not alter the preset simply to make the test pass.
7. If a game write remains unreported, compare `[UNCONFIRMED] The game did not report the new choice ...` or `[UNCONFIRMED] The game did not expose whether a remaining option cleared ...`. A completion can report unconfirmed > 0 or cleanupUnconfirmed > 0 and result=complete-with-warning. Do not count CHANGE alone as visual confirmation.
8. Load two presets in quick succession once and compare the existing hair/cyberware behavior and cleanup lines. Relevant logs are `PRECLEANUP | ...`, `APPLY | Saved choices were processed...`, `CLEANUP | ...`, and cleanupUnconfirmed in a completed SUMMARY. This stage does not promise to fix visible leftovers. If reproduced, keep both SUMMARY lines and the log around the superseding load for stage 8.
9. Close/reopen the editor and reload CET. Confirm the preset list remains populated and a subsequent load works. Cache lifetime stays tied to the same refresh/editor/update/reset paths.

Rendered output, missing mod dependencies and real Codeware timing remain UNVERIFIED until this build is tested in game. Stop after stage 7; do not begin stage 8 without confirmation.
