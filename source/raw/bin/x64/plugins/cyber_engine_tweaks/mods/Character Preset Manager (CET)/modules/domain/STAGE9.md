# Stage 9: editor lifecycle and hooks

Baseline: `0398e1c0dbca93bc3effcc78c019eba6627b6f89`. Stage 8 Part B remains skipped. This stage preserves behavior.

## Before extraction: functions and callers

| Function | Baseline callers/references (including pcall) |
|---|---|
| `setEditorOpenStatus` | `editor.lua:82`; `editor.lua:86`; `editor.lua:90`; `editor.lua:94`; `editor.lua:109`; `editor.lua:113`; `events.lua:209`; `events.lua:233`; `events.lua:239`; `events.lua:249`; `events.lua:319`; `events.lua:387` |
| `activeWardrobeSetEquipped` | `editor.lua:31` |
| `equipmentSystem` | `editor.lua:33`; `editor.lua:57` |
| `temporarilyDisableWardrobe` | `editor.lua:100`; `events.lua:93` |
| `restoreTemporarilyDisabledWardrobe` | `editor.lua:108`; `events.lua:125`; `events.lua:236`; `events.lua:285`; `events.lua:318`; `events.lua:386` |
| `openFullAppearanceEditor` | `events.lua:382`; `ui/sections_editor.lua:42` |
| `isCustomizationActive` | `editor.lua:80`; `editor.lua:89`; `editor.lua:125` |
| `refreshEditorState` | `events.lua:271`; `events.lua:347` |

Lifecycle hook targets: body-morph OnInitialize/OnUninitialize observers; BaseCharacterCreationController.RequestCameraChange override; new-game OnEnterScenario/OnLeaveScenario observers; in-game controller RegisterGlobalBlackboards/OnInitialize observers; pause OnEnterScenario override; mirror OnCCOPuppetReady override. All retain callback arguments, original-call policy and registration order. Existing events.openEditor, onShutdown and the editor-open watchdog will delegate. events.onUpdate keeps its stage 8 load section unchanged.

Redscript lifecycle wrappers: characterCreationBodyMorphMenu.OnInitialize (wrapped first, return ignored) and OnUninitialize (panel detach before wrapped, return ignored). All other hooks, bridge/native bindings and layout stay unchanged.

## Baseline facts to preserve

- Mirror puppet setup always runs for the mirror target, including ordinary mirrors. Success does not call the original. The existing exception fallback does call wrappedMethod().
- The watchdog is 5.0 seconds (constants.lua EDITOR_OPEN_TIMEOUT), compared with >=. Pause redirection clears openPending, so a later readiness failure is not watched. Negative elapsed values are not clamped.
- Wardrobe restore can fail and leave its disabled flag true. OnUpdate has no retry.
- Accept, cancel and close reach the same body-morph uninitialize observer in the Lua boundary. Actual game callback ordering is UNVERIFIED.
- Leftover hair/cyberware: could not be reproduced after the cancel removal and timeout fix (UNVERIFIED cause). Identified stage 8 paths and permanent supersede fixtures remain unchanged.

## Extracted boundaries

application/editor.lua is a pure function table. Scalars go in; scalars and preallocated ordered action lists come out. It owns launch gates, pause redirect decisions, tracked creator/mirror classification, hook-availability policy, camera suppression, the watchdog, wardrobe gates and teardown plans. It has no globals, imports, runtime, game objects, pcall or logging.

adapters/editor.lua implements the original editor functions and file-compatible entry points. adapters/cet_hooks.lua registers the same nine callbacks and executes lifecycle actions. Callbacks keep the same parameters. Game reads, object checks, protected calls, logging and status text remain in the adapters, at the same effect boundaries and in the same order.

editor.lua remains a facade returning the same runtime object. events.lua retains startup/storage/UI work and its stage 8 automatic-load call. It delegates lifecycle registration, shutdown, hotkey handling and watchdog work. The fallback reminder and overlay UI behavior are unchanged. No stage 4–8 production module, loader state constructor or native C++ file changes.

Classification uses the existing newGameCharacterCreator flag, set by the original scenario observers. It adds no engine type query or published field. Mirror-target puppet setup still runs regardless of that flag or openedByLauncher. These tags do not narrow the override. Actual engine/controller identity when those observers are unavailable remains UNVERIFIED.

The wardrobe gate is unchanged: an already disabled outfit is not disabled again; absence of an active set returns success; the same request is queued when an active set and equipment system exist. Restore is attempted only when the existing disabled flag is true. Real player/system checks remain in the adapter. Queue failures leave the flag as before. A successful QueueRequest is not confirmation that the game has finished restoring the outfit; actual completion remains UNVERIFIED.

## Hook contracts

| Target | Type | Parameters / original policy, unchanged |
|---|---|---|
| characterCreationBodyMorphMenu.OnInitialize | CET Observe | menu; catalog clear, wardrobe handling and opened actions. |
| characterCreationBodyMorphMenu.OnUninitialize | CET Observe | no arguments consumed; closed action plan. |
| BaseCharacterCreationController.RequestCameraChange | CET Override | self, slotName, delayed, wrappedMethod; suppress only for the old customization/load guard, otherwise return wrappedMethod(slotName, delayed == true). |
| MenuScenario_CharacterCustomization.OnEnterScenario | CET Observe | set the existing creator flag true. |
| MenuScenario_CharacterCustomization.OnLeaveScenario | CET Observe | set that flag false. |
| gameuiInGameMenuGameController.RegisterGlobalBlackboards | CET Observe | controller; capture and increment/log the old counter. |
| gameuiInGameMenuGameController.OnInitialize | CET Observe | same capture with the initialize diagnostic. |
| MenuScenario_PauseMenu.OnEnterScenario | CET Override | scenario, previousScenario, userData, wrappedMethod; original(previousScenario, userData) if not pending; otherwise clear pending/timer, set launcher state and switch to the mirror scenario. |
| MenuScenario_CharacterCustomizationMirror.OnCCOPuppetReady | CET Override | scenario, wrappedMethod; original is skipped on success and called without arguments after the original exception cleanup. Ordinary mirrors remain affected. |
| characterCreationBodyMorphMenu.OnInitialize | redscript @wrapMethod | protected cb func OnInitialize() -> Bool; wrappedMethod first, ignored result, then unchanged panel initialization. |
| characterCreationBodyMorphMenu.OnUninitialize | redscript @wrapMethod | protected cb func OnUninitialize() -> Bool; unchanged panel teardown before wrappedMethod, ignored result. |

The two redscript wrappers now call private CPMInitializePresetPanel() -> Void and CPMTeardownPresetPanel() -> Void methods on the same class. This keeps access to the existing private/inherited fields. No class is added. All original annotations, targets and signatures are checked against commit 0398e1c by native/verification/check_code.js, including the untouched @addMethod and @addField declarations. No @replaceMethod or @replaceGlobal is introduced or changed.

Expanding the two new helper bodies yields the original wrapper bodies with identical calls and order. The rest of Panel.reds, including layout coordinates, randomizer guards and input handlers, matches the baseline. Bridge.reds, Options.reds and Voice.reds are unchanged. Their native binding names, parameters and protocol 1 remain intact.

## Ordered exit plans

Each row preserves the baseline at its boundary. RS means the existing redscript wrapper chain; Lua means the existing CET callback chain. The actual interleaving of CET observers with redscript wrappers is UNVERIFIED by the fake game. Both hook registrations and the wrapper-relative order are preserved; no new combined ordering is imposed.

| Exit | Ordered baseline actions, retained | Evidence |
|---|---|---|
| Accept | RS: if panel exists, Detach (unregister bridge, remove widget when parent exists), null panel, wrappedMethod. Lua: clear option catalog; measure editor-closed if active; reset load; clear pending randomize; clear active menu; customization=false; invalidate preflight; clear fallback; launcher=false; restore wardrobe. | accept; expanded OnUninitialize; application/editor closed plan. |
| Cancel | Same RS and Lua chains as accept. No separate CPM accept/cancel hook exists. | cancel; same uninitialize callback. |
| Close | Same chains. Close during a load retains its editor-closed measurement before reset. | close and close active load. |
| Editor-open timeout | Advance timer by elapsed; when timer >= 5.0, pending=false; timer=0; restore wardrobe; set the original retry-in-gameplay error status. No new loader reset or watchdog retry. | below/exact/above/negative watchdog cases. |
| Shutdown | Finish overlay request; clear catalog; audit SESSION END; log counters; restore wardrobe; ready=false; customization=false; creator=false; clear confirmations; reset load; clear pending randomize/menu/controller; pending=false; timer=0; launcher=false; hooks=false; clear fallback; close activity log. | shutdown open; application/editor shutdown plan. |
| CET reload model | Run the same shutdown chain; construct fresh load/app/editor state; run the existing init and register the same callbacks. No new game wardrobe/panel cleanup is inserted. | CET reload. Real VM/registry teardown remains UNVERIFIED. |
| Launch failure from SpawnMenuInstanceEvent | pending=false; restore wardrobe; log/set the game-rejected status; return false. Timer stays at its previously reset zero. | launch failure; launchFailure plan. |
| Hotkey exception before/around launch | pending=false; timer=0; restore wardrobe; set/log hotkey-failed status. | hotkey failure; hotkeyFailure plan. |
| Unavailable controller before launch | Diagnostic options query; pending/hooks/customization gates in the old order; set Load or reload a save status and return false. No wardrobe or spawn request. | no controller. |
| Puppet setup exception | Increment/log puppet counter first; attempt the same protected setup; on failure set/log setup error; launcher=false; restore wardrobe; return original(). | puppet unavailable; puppetFailure plan. |
| Customization state changes during refresh | Assign the observed customization flag; optionally measure editor-changed; reset load; invalidate preflight; finally clear the active menu if the current flag is false. | refresh enter/leave. |

The initialization order is also retained: clear catalog; disable wardrobe; optional editor-opened measurement; reset load; capture menu; customization=true; invalidate preflight; connect bridge; clear fallback; log bridge readiness. The fake records state during wardrobe QueueRequest, so it checks that restore occurs before shutdown flags change and after close flags change.

## Constants and field names

| Value | Old location | Current handling |
|---|---|---|
| EDITOR_OPEN_TIMEOUT = 5.0 seconds | modules/constants.lua:55; events.lua old watchdog | Same constant passed explicitly to the pure watchdog; >= comparison retained. |
| Initial/reset openTimer = 0 | editor.lua launch; events.lua redirect, timeout, shutdown and hotkey exception | Same values and assignment order. |
| Wardrobe invalid sentinel | editor.lua activeWardrobeSetEquipped, gameWardrobeClothingSetIndex.INVALID | Same engine enum comparison in the adapter; no guessed numeric value. |
| FALLBACK_NOTICE_DELAY_SECONDS = 8 | constants.lua:80 and unchanged events fallback function | Unchanged; UI reminder timing is not extracted here. |

There are no new retry counts or lifecycle thresholds. A redirected pause clears openPending immediately, just as before. The watch therefore does not cover the later puppet/menu-ready portion. Input and diagnostic counters still increment by one at their original points.

Only characterCreationBodyMorphMenu is modified in redscript. Its cpmPresetPanel field is neither renamed nor redeclared. Existing reads/writes of m_randomizationSettingsWidget, m_presetsLabel, m_preset1/2/3, m_preset1Group/2Group/3Group remain in the moved body. No persistent field is added or changed. The helper methods add no data. Panel class fields and NativeBridge declarations remain untouched.

Lua continues writing the same transient MorphMenuUserData fields (optionsListInitialized, updatingFinalizedState, editMode) and MenuScenario_CharacterCustomizationMirror.currMenuName. No setting, file format, saved identity, persistent game-data name or bridge field changes. Actual game save serialization remains UNVERIFIED by the fake; this change introduces no serialization code or persistent declaration.

## Fixtures and comparisons

I recorded 47 scenarios from the original editor.lua/events.lua before extraction. The unchanged original sources were also frozen from commit 0398e1c0dbca93bc3effcc78c019eba6627b6f89 for independent instrumented replay. The fixture payloads were checked against the initial recordings. Constructor metadata comes from the frozen baseline, not the extracted code.

Each comparison includes the ordered effects, Game-boundary calls and arguments, status/log text and order, callback registration types/targets, callback return arity, load/app/editor/UI snapshots, counters and update counts. Fake API errors use stable injected messages. Real error traceback filenames/line numbers move with the code and remain UNVERIFIED. Actual Codeware callbacks, wardrobe completion and rendered UI cannot be proven by these fakes.

All rows below match before/after. Disable/restore are QueueRequest attempts, including injected failures. Camera/Pause/Puppet are original-method calls. Callback ordering across frameworks is not inferred from the table.

| Scenario | Updates old/new | Disable / restore old=new | Original camera / pause / puppet old=new | Final pending / wardrobe-disabled old=new |
|---|---:|---|---|---|
| gameplay launch | 0/0 | 1 / 0 | 0 / 0 / 0 | false / true |
| ordinary mirror | 0/0 | 1 / 0 | 0 / 1 / 0 | false / true |
| new-game creator | 0/0 | 1 / 1 | 0 / 0 / 0 | false / false |
| no controller | 0/0 | 0 / 0 | 0 / 0 / 0 | false / false |
| puppet unavailable | 0/0 | 0 / 0 | 0 / 0 / 1 | false / false |
| watchdog below | 1/1 | 1 / 0 | 0 / 0 / 0 | true / true |
| watchdog exact | 1/1 | 1 / 1 | 0 / 0 / 0 | false / false |
| watchdog above | 1/1 | 1 / 1 | 0 / 0 / 0 | false / false |
| watchdog negative | 1/1 | 1 / 0 | 0 / 0 / 0 | true / true |
| redirected but not ready | 1/1 | 1 / 0 | 0 / 0 / 0 | false / true |
| accept | 0/0 | 1 / 1 | 0 / 0 / 0 | false / false |
| cancel | 0/0 | 1 / 1 | 0 / 0 / 0 | false / false |
| close | 0/0 | 1 / 1 | 0 / 0 / 0 | false / false |
| launch failure | 0/0 | 1 / 1 | 0 / 0 / 0 | false / false |
| hotkey failure | 0/0 | 0 / 0 | 0 / 0 / 0 | false / false |
| shutdown open | 0/0 | 1 / 1 | 0 / 0 / 0 | false / false |
| CET reload | 0/0 | 1 / 1 | 0 / 0 / 0 | false / false |
| already pending | 0/0 | 0 / 0 | 0 / 0 / 0 | true / false |
| hooks unavailable | 0/0 | 0 / 0 | 0 / 0 / 0 | false / false |
| customization already active | 0/0 | 0 / 0 | 0 / 0 / 0 | false / false |
| disable no player | 0/0 | 0 / 0 | 0 / 0 / 0 | false / false |
| disable player error | 0/0 | 0 / 0 | 0 / 0 / 0 | false / false |
| disable no active set | 0/0 | 0 / 0 | 0 / 0 / 0 | false / false |
| disable set error | 0/0 | 0 / 0 | 0 / 0 / 0 | false / false |
| disable no equipment | 0/0 | 0 / 0 | 0 / 0 / 0 | false / false |
| disable queue failure | 0/0 | 1 / 0 | 0 / 0 / 0 | false / false |
| already disabled | 0/0 | 0 / 0 | 0 / 0 / 0 | false / true |
| restore no player | 20/20 | 1 / 0 | 0 / 0 / 0 | false / true |
| restore player error | 20/20 | 1 / 0 | 0 / 0 / 0 | false / true |
| restore no equipment | 20/20 | 1 / 0 | 0 / 0 / 0 | false / true |
| restore queue failure | 20/20 | 1 / 1 | 0 / 0 / 0 | false / true |
| restore without retry | 20/20 | 1 / 0 | 0 / 0 / 0 | false / true |
| refresh enter | 0/0 | 0 / 0 | 0 / 0 / 0 | false / false |
| refresh leave | 0/0 | 1 / 0 | 0 / 0 / 0 | false / true |
| close active load | 0/0 | 1 / 1 | 0 / 0 / 0 | false / false |
| camera idle | 0/0 | 0 / 0 | 20 / 0 / 0 | false / false |
| camera guard | 0/0 | 0 / 0 | 0 / 0 / 0 | false / false |
| camera auto | 0/0 | 0 / 0 | 0 / 0 / 0 | false / false |
| camera continue | 0/0 | 0 / 0 | 0 / 0 / 0 | false / false |
| camera outside editor | 0/0 | 0 / 0 | 20 / 0 / 0 | false / false |
| hotkey released | 0/0 | 0 / 0 | 0 / 0 / 0 | false / false |
| controller initialize | 0/0 | 0 / 0 | 0 / 0 / 0 | false / false |
| observer init failure | 0/0 | 0 / 0 | 0 / 0 / 0 | false / false |
| observer exit failure | 0/0 | 0 / 0 | 0 / 0 / 0 | false / false |
| both controller observers fail | 0/0 | 0 / 0 | 0 / 0 / 0 | false / false |
| pause registration failure | 0/0 | 0 / 0 | 0 / 0 / 0 | false / false |
| puppet registration failure | 0/0 | 0 / 0 | 0 / 0 / 0 | false / false |

Stages 1–9 pass under stage9_sandbox. Stages 1–8 retain their existing results (833; 183 plus 62 writes/7 round trips; 63; 2,981; 6,349; 9,039; 67; 46 scenarios). Stage 9 has 47 lifecycle comparisons plus headless launch/classification/watchdog/camera checks. The 205 per-frame/camera constructor profiles match the frozen baseline with zero production Lua table constructors in each sample. The current profile must equal the stored baseline metadata when instrumentation is enabled.

The ordinary restore-failure runs each execute 20 updates without a new restore request. Camera runs each invoke the hook 20 times: the original is called 20 times for idle/outside-editor cases and zero times for the three suppression guards. Watchdog scenarios each have one update with the same overlay/ACU/bridge call order. Stage 8 full-load OnUpdate counts and golden traces still pass unchanged.

The watchdog and camera paths use scalar arguments and reused action lists. No new option scan, game call, table constructor or closure creation is added to their per-frame bodies. There is fixed Lua delegation/dispatch overhead. VM internal allocation/GC and actual CET frame time are UNVERIFIED; the checks are not a wall-time benchmark.

All 86 Lua files parse as Lua 5.1. The suite executes in the available Lua 5.1 DLL. The isolated installed scc compiler successfully compiles all four current CPM scripts with the five installed Codeware declaration files and the vanilla cache. This confirms compilation for those references; real in-game hook ordering and mod interaction remain UNVERIFIED.

## Sandbox and globals

application/editor references no globals and imports no modules. The adapter globals are listed below. Every name is checked against the original editor.lua/events.lua plus stage 8 adapters/game_options.lua, which run in the same shared runtime environment. ipairs is already used by that game adapter. No new io/os member or Lua library feature is introduced.

**application/editor**

```text
(none)
```

**adapters/editor**

```text
EquipmentSystem, Game, QuestDisableWardrobeSetRequest, QuestRestoreWardrobeSetRequest,
equipmentSystem, gameWardrobeClothingSetIndex, getOptions, helpers, ipairs, log,
openFullAppearanceEditor, pcall, refreshEditorState, require, resetLoadState,
restoreTemporarilyDisabledWardrobe, setEditorOpenStatus, setfenv, state, temporarilyDisableWardrobe,
tostring
```

**adapters/cet_hooks**

```text
EDITOR_OPEN_TIMEOUT, MorphMenuUserData, Observe, Override, cancelConfirmations, closeActivityLog,
connectNativeBridgeForMenu, gameuiCharacterCustomizationEditTag, helpers, ipairs, log,
openFullAppearanceEditor, pcall, require, resetLoadState, restoreTemporarilyDisabledWardrobe,
setEditorOpenStatus, setfenv, state, temporarilyDisableWardrobe, tostring
```

The inherited pure-module allowlist is unchanged:

```text
ipairs, pairs, require, tonumber, tostring, type
math.floor, math.max, math.min
table.concat, table.insert, table.sort
```

The new pure module uses none of that list. The sandbox fails on new global/dependency/library access and self-tests rejection of coroutine, debug, package, io, os and _G in pure code. Test-only source/constructor instrumentation uses host libraries; it is not permission for shipped production modules to use them. The prior fake directory listing remains UNVERIFIED and is not modified.

The complete 298-name legacy allowlist is:

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
writePresetContents writePresetPath writeTransaction openFullAppearanceEditor
```

Legacy namespace members remain io.open; os.clock/date/time/rename/remove; math.ceil/floor/max/min; table.concat/insert/remove/sort; string.char/rep. The only added gate name is openFullAppearanceEditor, an existing baseline function whose hotkey path was not exercised by the stage 8 gate.

## Temporary compatibility entry points

All old editor global/helper functions remain installed with their old parameters and returns through editor.lua. events.onInit/onShutdown/onUpdate/openEditor retain their signatures and are still registered by init.lua. The old redscript wrappers and public methods remain available. No caller needs to switch in this stage.

| Entry | Remaining callers / owner |
|---|---|
| `setEditorOpenStatus` | `adapters/cet_hooks.lua:48`; `adapters/cet_hooks.lua:61`; `adapters/cet_hooks.lua:63`; `adapters/cet_hooks.lua:65`; `adapters/cet_hooks.lua:174`; `adapters/cet_hooks.lua:199`; `adapters/editor.lua:9`; `adapters/editor.lua:11`; `adapters/editor.lua:102`; `adapters/editor.lua:106`; `adapters/editor.lua:112`; `adapters/editor.lua:116` |
| `activeWardrobeSetEquipped` | `adapters/editor.lua:50` |
| `equipmentSystem` | `adapters/editor.lua:52`; `adapters/editor.lua:76` |
| `temporarilyDisableWardrobe` | `adapters/cet_hooks.lua:12`; `adapters/editor.lua:123`; `adapters/editor.lua:146` |
| `restoreTemporarilyDisabledWardrobe` | `adapters/cet_hooks.lua:31`; `adapters/editor.lua:7`; `adapters/editor.lua:146` |
| `openFullAppearanceEditor` | `adapters/cet_hooks.lua:222`; `adapters/editor.lua:146`; `ui/sections_editor.lua:42` |
| `isCustomizationActive` | `adapters/editor.lua:99`; `adapters/editor.lua:109`; `adapters/editor.lua:141` |
| `refreshEditorState` | `events.lua:107`; `events.lua:155`; `adapters/editor.lua:146` |
| `events.onInit/onShutdown/onUpdate` | init.lua registerForEvent; test harnesses. Lifecycle parts delegate to the adapter; stage 8 load update stays in events.lua. |
| `events.openEditor(keyDown)` | init.lua preset_manager_open_editor_input registration. |
| redscript OnInitialize / OnUninitialize | Game lifecycle; delegate to the two private methods without changing their hook signatures. |

## Defects found, unchanged

- The mirror puppet override bypasses the original on success and also affects ordinary mirrors. Its original exception fallback still calls the original. This is the same mod-conflict surface, not a narrowed launcher-only hook.
- Wardrobe restoration logs that it is waiting when player/system access fails, but no OnUpdate retry is scheduled. The disabled flag stays true. The 20-update no-retry fixture preserves this defect; queue errors are also unchanged.
- The editor-open watchdog covers only pending pause redirection. Once redirected, an editor that never becomes ready does not time out. The redirected-but-not-ready fixture retains that behavior and its outstanding wardrobe state.
- hooksAvailable does not require the body-morph init/exit or new-game observers to register. Those failures can leave lifecycle tracking unavailable while the launch hooks are reported available. application/editor.hooksAvailable preserves the exact old expression.
- Leftover hair/cyberware: **could not be reproduced after the cancel removal and timeout fix (UNVERIFIED cause)**. Stage 8 Part B stays skipped. The unchanged paths are application/loading.lua load_request/begin/pending/finish_pass, domain/state.lua beginLoad, adapters/game_options.lua cleanup eligibility/write group, and native_bridge.lua startSelectedLoad. The eight permanent stage 7 supersede fixtures stay untouched. No fix or superseded-load log was added.

No new runtime warning or diagnostic message is introduced. Source-line traceback changes and actual engine callback/reload behavior are UNVERIFIED. The source contract checker and fake tests establish preserved local ordering, not observed in-game ordering across CET, redscript and Codeware.

## Exact installation

Exit the game and install the Stage 9 Test archive into the Cyberpunk 2077 directory. Keep Data and Character Presets. Runtime changes are exactly:

```text
bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/modules/editor.lua
bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/modules/events.lua
bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/modules/application/editor.lua
bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/modules/adapters/editor.lua
bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/modules/adapters/cet_hooks.lua
r6/scripts/CharacterPresetManager/Panel.reds
```

The three new production Lua files return explicit function tables. The full package also adds modules/domain/STAGE9.md, stage9_tests.lua, stage9_fixtures.lua and stage9_sandbox.lua. init.lua does not run those tests. STAGE8.md includes the already-committed Part B skip note. Repository-only CHANGELOG.md and native/verification/check_code.js are not installed. The three approved package roots and release version remain unchanged; no release is created.

## In-game checklist

1. Start the game and load a save. Check Activity.log and CET/redscript logs for require, forbidden-global, runtime or compile errors. Expect the existing character-customization-observers and full-editor-hooks registration lines. The new modules do not print loaded messages.
2. Use the existing Open Full Appearance Editor binding in normal gameplay. Expect input/launch diagnostics, the controller-captured diagnostic when available, pause pending=true, Preparing the full editor, puppet-ready, Full editor opened and the existing UI readiness line. If an outfit is active, expect its removal log. Compare the order within each boundary to stage 8; actual cross-framework timing may vary.
3. Open an ordinary mirror directly. Confirm the same full-editor access and puppet-ready/full-editor-opened messages. No launcher-only restriction should appear. Check that the panel and randomizer controls retain their positions and behavior.
4. Enter new-game character creation. Confirm it opens normally and the simple preset panel is available. Expect the existing UI readiness line, not a new creator-classification message. Leave and re-enter to check tracking and teardown.
5. Close through accept, cancel and ordinary close using disposable appearance changes. Check the wardrobe restore log when an outfit was disabled. There is no dedicated CPM accept/cancel log. Reopen and confirm preset load, camera movement, randomizing and menu access still work. If a load was active, expect its existing editor-closed measurement before reset.
6. Reload CET with the editor open. Expect SESSION END/counter summary, wardrobe restore when available, then the original startup/config/scan/hook lines. Reopen or reload a save if the controller has not been captured, as before. Confirm another editor launch and preset load work. Real CET registry teardown is UNVERIFIED by the scripted reload.
7. If a normal launch fails before pause redirection, expect the unchanged five-second gameplay-retry error, or the immediate game-rejected/hotkey-failed error when the game throws. Do not change the threshold or remove dependencies to manufacture the failure. If pause redirected but readiness never follows, retain the logs; the baseline watchdog does not cover that portion.
8. Confirm wardrobe returns after close. If the log says it is waiting or restoration failed, record the state; automatic retry was not added. Compare against stage 8 rather than assuming a new retry exists.

Stop after stage 9. Stage 10 is not started. Stage 8 Part B remains skipped.
