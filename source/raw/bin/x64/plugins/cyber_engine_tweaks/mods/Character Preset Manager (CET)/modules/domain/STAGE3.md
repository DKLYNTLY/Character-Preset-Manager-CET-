# Stage 3 state constructors and operation results

## Stage 2 session review

I reviewed the October 27 session that initialized CPM at 12:27:28 and ended at 12:28:49, in America/New_York time. I read CET's main log, `scripting.log`, the CPM Activity Log, the current redscript log, the available game log, and the native service log.

The stage 2 commit was pushed: `f0b611b773dc117f0eb8c645960c9c8cb3c18da2`, **Move stage 2 preset and config codecs into domain modules**. A live `git ls-remote origin refs/heads/main` check returned that hash before stage 3 work was committed.

The installed `json.lua`, `preset_codec.lua`, `config_codec.lua`, `modules/presets.lua`, and `modules/constants.lua` matched the stage 2 source bytes before extraction. These are the relevant session lines:

```text
[2026-10-27 12:27:17 UTC-04:00] [2780] Mod Character Preset Manager (CET) loaded!
[2026-10-27 12:27:28] [#0005] [INFO] [CONFIG] Loaded 'Data/Config/Config.txt': presetSort=name.
[2026-10-27 12:27:28] [#0016] [INFO] [FILES] Scanned 'Character Presets': 27 readable preset files found (reason=startup).
[2026-10-27 12:28:24] [#0987] [COMPLETE] SUMMARY | preset='hi' | processed=59 | confirmed=59 | unconfirmed=0 | forced=0 | cleanupUnconfirmed=0 | failed=0 | unavailable=0 | ambiguous=0 | passes=29 | result=complete
[INFO - Tue, 27 Oct 2026 12:27:16 -0400] Compilation complete
```

The first line is the CET message without its trailing installation path. These are general startup and workflow messages; none names a domain module. I cannot provide a per-module log line that does not exist.

The evidence for codec loading is indirect: the installed files match the commit, `presets.lua` requires all three codecs unconditionally, CET reports CPM loaded, and subsequent config and preset reads succeed. The logs do not prove that every JSON branch was exercised.

CET's main log ends with successful initialization. The current redscript log reports a successful compiled output, and there is no CPM Lua exception or redscript compile error in the reviewed session. `gamelog.log` ends on October 21, so it provides no coverage of this session.

### Warnings and errors

| Evidence | Assessment |
|---|---|
| `Alina`: 48 choices applied, two eyelash choices unavailable; load stopped after 31 passes. | Same identities and outcome appear in pre-stage 4.0.1 logs. No stage 2 regression is shown. |
| `ACU Presets/female/Mariko 1.0`: five unavailable choices and a stopped load. | These are loader availability warnings. The current preset model and parser warnings match the pre-stage reader. Exact reproduction of all five missing choices on the baseline is UNVERIFIED. |
| `gh98t9`: one unconfirmed pubic-hair write and one unavailable choice; load stopped. | The parser returns the same model and warnings as the baseline. Game timing and availability remain UNVERIFIED; the log does not establish a codec regression. |
| `[ERROR] [create] "hi" already exists. Select Confirm Overwrite to replace it.` | Expected overwrite protection, followed by a successful explicit save. This is an error-level user message, not a script exception. |
| Refresh reports two changed default presets: `Streetkid - Male` and `CORPO - Male`. | Both current files match the packaged source and have timestamps older than this session. The warning reports an inventory comparison, not proof that the codecs rewrote either file. Its exact cause is UNVERIFIED and remains a storage follow-up. |
| Native service: `ACU folder watching is not available. Select Refresh to check files.` | The optional source folder is absent, and the installed DLL is byte-identical to baseline 4.0.1. See the separate defect notes below. |
| Toggle Armware reports missing NativeSettings; CET NPC Body Tweaks reports missing archives. | Warnings from other mods. No link to CPM stage 2 is shown. |

For an additional read-only comparison, I ran the pre-stage reader from commit `387d44d` and the extracted reader against five current files: `Alina`, `gh98t9`, `hi`, and two copies of `Mariko 1.0`. Their parsed models and parser warning messages matched. All five source hashes stayed unchanged.

I found no evidence of a stage 2 regression, so I continued with the authorized state extraction. JSON coverage, the sort setting across a restart, and game-save persistence are not established by these log lines alone.

## Inventory before extraction

`STAGE3_STATE_INVENTORY.md` records the original fresh declarations and all 422 assignments to `state.load` or `state.app`. It also lists the exact field footprints moved here, with their original source locations. Indexed matching writes and other algorithm-owned data updates remain where they were.

Fresh load state declares 60 fields, and full reset assigns 56. The reset explicitly clears `batch`, `stageApplied`, `stagePending`, and `choiceStage`, which are absent from the fresh declaration. A Lua field initialized to nil is absent from the resulting table.

Full reset leaves these eight fresh-state fields alone:

- `scanResult`
- `forceFull`
- `forceFullPresetName`
- `preflight`
- `preflightDirty`
- `preflightPresetName`
- `recoverySnapshotAvailable`
- `comparison`

Unknown fields and dynamic fields outside the reset list, such as `updateStarted`, also remain untouched. Reset changes the existing load table in place, so held references stay valid.

Finished-load cleanup has its own 29-assignment footprint, including `app.optionsMemo`. It clears `scanResult` and working tables, but preserves fields such as `presetName`, `overrideName`, `phase`, `pendingElapsed`, measurements, force-load selection, and comparison data. It is not interchangeable with full reset.

The other differences remain explicit in separate functions: completion clears four fields; unavailable options clear five; a stalled load changes two; the normal automatic stop clears three; the post-pass stop clears two; timeout changes only `auto`. The old preflight invalidator sets `preflightDirty=true`, while the fallback preflight-start path sets it false and records the selected name. Both rules are retained.

The three assignments in the CET Load button remain in `ui/sections_load.lua` because UI files are outside this stage. They still call the preserved reset entry point, and their values match the automatic-start footprint. Selection, matching, per-choice write bookkeeping, and state fields owned by those algorithms have not been redesigned.

## What changed

`domain/state.lua` returns explicit constructors and functions for the recorded lifecycle footprints. `newLoad(passInterval)` and `newApp(readyStatus)` receive their old constant values from the adapter. They create independent tables without reading runtime state.

Reset functions receive the existing table and return it after applying the same assignments. The legacy forwarders still return no values where that was the old contract. Prepared preset tables and entry indexes retain their existing references; extraction does not clone those inputs or change their ownership.

`domain/operation_result.lua` adds an unused shared result contract for later menu work:

```text
success: boolean
failure: boolean
warnings: independent table
statusMessage: string
```

`success` and `failure` are complementary. `new`, `success`, and `failure` constructors copy warning tables, including nested values, so result instances do not share mutable warnings. No result is attached to shared state, persisted, or consumed by either menu in this stage.

The eight legacy files only replace assignment groups with state-function calls. I parsed the old and new code, expanded the new calls back into their assignments, and compared the resulting syntax trees. All eight files matched. This check covers conditions, matching decisions, game-write calls, hook code, return behavior, and update-loop ordering outside the extracted assignments.

The new calls add no per-frame tables or closures. Each reset still allocates the same empty working tables as before; constructors run at the same initialization points. UI files, redscript, native code, constants, settings, formats, and persistent fields are unchanged.

## Temporary entry points and remaining callers

All old entry points remain. The table includes the enclosing functions whose inline reset groups now delegate; calls that only pass a callback are included.

| Entry point | Remaining references |
|---|---|
| `resetLoadState` | `acu_import.lua:156`; `backup.lua:447`; `bundles.lua:574`; `catalog.lua:271,282`; `editor.lua:130`; `events.lua:97,118,290`; `folders.lua:148,376`; `history.lua:135`; `load_engine.lua:1237,1243,1314,1434`; `native_bridge.lua:241,292,303`; `presets.lua:306,451,593,638,823`; `trash.lua:475,690,937`; `ui/sections_load.lua:181,246,325` |
| `helpers.releaseFinishedLoadWorkingData` | `events.lua:45`; `load_engine.lua:1284` |
| `beginLoadPass` | `load_engine.lua:1278` |
| `helpers.clearVisibleLoadSatisfaction` | `load_engine.lua:371,397,736,799` |
| `state.invalidatePreflight` | `editor.lua:131`; `events.lua:53,100,122`; `load_engine.lua:1285`; `native_bridge.lua:271,290,301`; `options.lua:150`; `view_cache.lua:56`; `ui/sections_load.lua:173,313,326` |
| `helpers.clearOptionCatalog` | `events.lua:92,114,280`; `options.lua:142,279,296` |
| `helpers.scanLoadOptions` | `load_engine.lua:703` |
| `helpers.checkPendingChange` | `load_engine.lua:545,711` |
| `helpers.writeLoadGroup` | `load_engine.lua:597,791` |
| `continueLoadPass` | `load_engine.lua:1280` |
| `loadPreset` | `events.lua:359`; `history.lua:137`; `load_engine.lua:1316`; `native_bridge.lua:243`; `ui/sections_load.lua:244,251` |
| `restoreLastAppearance` | `native_bridge.lua:382`; `ui/sections_load.lua:266` |
| `restoreAppearanceHistory` | `load_engine.lua:1307`; `native_bridge.lua:375`; `ui/sections_load.lua:286` |
| `startSelectedLoad` | `native_bridge.lua:304,337` |
| `refreshPreflight` | `ui/sections_load.lua:316` |
| `cancelLoading` | `native_bridge.lua:389`; `ui/sections_load.lua:257` |
| `helpers.clearLoadScanTable` | `load_engine.lua:79,80,81,82,83,84,85,86` |
| `events.onUpdate` | `../init.lua:38` |

The `modules/state` module entry point also remains in `init.lua`. It still returns the same root table, with `state.load` and `state.app` in their original locations. The original initialization module delegates only those two tables to constructors.

The generic `helpers.clearLoadScanTable` also remains as a zero-return forwarding function. Its callers are the option-scan collection reset loop in `helpers.scanLoadOptions`; it forwards to `clearScanCollection`, which removes every existing key while preserving the collection identity.

## Validation

I recorded 62 original state snapshots before the main extraction, then added two scratch-table cases against the original helper before moving that helper. All 64 results are frozen in the fixtures. They cover fresh and seeded state for each footprint, legacy forwarders, begin-load setup, cancellation, missing selection, unreadable presets, unavailable options, a controlled completed-load boundary, idle cleanup, and update-loop stop paths.

The completed-boundary fixture supplies a controlled terminal result and tests the existing cleanup boundary. It does not simulate game matching or certify an in-game load. Matching and write logic are instead protected here by the unchanged expanded syntax trees.

Results on Lua 5.1:

- Stage 1: 833 fixtures pass, along with its compatibility and codec checks.
- Stage 2: 183 cases, 62 baseline writer comparisons, and seven canonical byte-identical format-8 round trips pass.
- Stage 3: all 64 snapshots match field-for-field, including untouched sentinel fields and retained app data.
- Constructor independence, nested warning isolation, input-reference preservation, in-place reset identity, and old zero-return contracts pass.
- The timeout fixture still has `auto=false`, `needsContinue=true`, a pending choice, and a batch after timeout.
- The Lua 5.1 syntax check passes for all 47 Lua files.
- The state and result modules have no runtime import, file I/O, protected game call, or shared-state access.

Run from the repository root:

```text
lua "source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/modules/domain/stage1_tests.lua"
lua "source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/modules/domain/stage2_tests.lua"
lua "source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/modules/domain/stage3_tests.lua"
node native/verification/check_code.js
```

## Files to install

Replace these eight files under the existing CET mod:

- `modules/state.lua`
- `modules/filesystem.lua`
- `modules/load_engine.lua`
- `modules/events.lua`
- `modules/native_bridge.lua`
- `modules/history.lua`
- `modules/presets.lua`
- `modules/options.lua`

Add all six new files:

- `modules/domain/state.lua`
- `modules/domain/operation_result.lua`
- `modules/domain/stage3_tests.lua`
- `modules/domain/stage3_fixtures.lua`
- `modules/domain/STAGE3.md`
- `modules/domain/STAGE3_STATE_INVENTORY.md`

The state model is required at runtime. The result model is ready for later application work, while the tests, fixtures, and reports preserve this stage's checks. Keep all stage 1 and stage 2 files.

The test archive includes the three existing shipped roots and all tracked files inside them. Each ZIP entry is checked against its source, including every new stage 3 file and the single `init.lua`. Install through Vortex or extract into the game folder and allow overwrites. This is a test build, not a published release.

## Defects found

### Unavailable eyelash choices

The current session reports unavailable `eyelashes_options` and `eyelash_color` choices, then stops at 48 of 50. A retained baseline 4.0.1 session on October 26 reports the same identities and outcome:

```text
[2026-10-26 21:12:47] [#0217] [WARN] SUMMARY | preset='Alina' | applied=48 | unresolved=2 | passes=22 | result=stopped
```

The baseline log is `Data/Logs/Archive/Activity 2026-10-27_12-12-07.txt`. It predates the staged extraction. The pre-stage and current readers also produce the same model for the current `Alina` file.

The loader cannot find usable current options for those saved choices. A changed or inactive CCXL/body setup is a likely cause, but the precise missing dependency or availability flag is UNVERIFIED. The unavailable-choice warning and repeated-unresolved stop path remain in `load_engine.lua`, inside `continueLoadPass`. This needs a separate matching investigation, not a codec or state change.

### ACU folder watcher unavailable

The current native warning comes from `native/src/Main.cpp:840`, in `Worker`, after `DirectoryWatcher::Start` fails. `ResolvePaths` points it at `bin/x64/plugins/cyber_engine_tweaks/mods/AppearanceChangeUnlocker/character-presets`. That directory does not exist in the inspected installation.

`DirectoryWatcher::Start` opens the path with `CreateFileW` and `OPEN_EXISTING` at `native/src/Main.cpp:737`; an absent directory fails that call. The installed and shipped DLLs are byte-identical to the baseline 4.0.1 archive, so the baseline implementation would report the same warning with this folder state. No retained pre-stage native session log is available to prove that it was observed during an earlier baseline run.

This is expected when the optional source folder is absent. I left the warning, fallback, and directory layout unchanged for a separate native-service review.

### Automatic-load timeout retains active state

The old path is `events.onUpdate`, `events.lua:352` in the original inventory: after the safety limit is exceeded, it assigns only `state.load.auto=false`. The current path is `events.onUpdate` calling `stateModel.stopAutomaticAtTimeout`; the domain function also assigns only `auto=false`.

`needsContinue`, `pendingChange`, `batch`, `phase`, and other fields survive. Bridge busy status and the camera guard can still see that active state. The exact current call and function line numbers are listed below. A fix belongs in a separate stage 8 commit; the regression test deliberately preserves this bug.

### Wardrobe restoration has no regular retry

`editor.lua:54`, `restoreTemporarilyDisabledWardrobe`, returns false if the player or equipment system is unavailable. A failed request also returns false, and the temporary-disable flag stays set.

Menu teardown and shutdown call this function, as do editor-launch failure paths. The update loop calls it only for an editor-open timeout; it does not regularly retry an earlier failed restoration while `openPending` is false. The helper and its call paths are unchanged. Keep a fix separate during stage 8.

### Other observations left unchanged

The stage 2 UTF-8 byte-truncation and path-validator differences remain. Unconfirmed writes, other unavailable legacy choices, and the external-change warnings are recorded in the session review above; their exact game or storage causes need separate evidence. No corrective change is part of this stage.

## In-game checklist and expected log evidence

1. **Open and close the character screen several times.** Each open should log `[UI] The character editor opened; the simple preset menu is ready.` or the existing waiting message. If closing interrupts an active load, look for a `[MEASURE]` entry with `editor-closed`; idle closes have no dedicated success line. Confirm the next open works and the busy state clears.
2. **Run a load to completion.** Use a preset whose choices are available. Look for `[PRESET] Load requested`, a `SUMMARY` with `result=complete` or the existing `complete-with-warning`, followed by the loaded-options status. For a complete result, check `unconfirmed=0`, `failed=0`, `unavailable=0`, and `ambiguous=0` where those fields are reported.
3. **Cancel mid-load.** Look for `[MEASURE] Load canceled` and `Loading canceled for "...".` in the Activity Log. Confirm that loading stops and the editor can be used again. The next step must not require reopening the screen.
4. **Start a second load immediately.** A new `[PRESET] Load requested` should appear. Progress should belong to the new preset and finish with its own summary; old pending choices must not continue afterward.
5. **Switch between the simple menu and CET.** Look for `[UI] CET opened; showing Character Preset Manager` and `[UI] CET overlay closed.` The selected preset, current load status, and controls should remain consistent. No new operation-result log is expected because neither UI consumes that model yet.
6. **Reload CET.** The exact reload mechanism and event ordering are UNVERIFIED on the installed CET build. If reload emits teardown callbacks, expect `SESSION END` and the old summary, then a fresh `session started`, config load, and hook-registration messages. There is no per-constructor success log. Verify the menus reopen and the first new load starts normally; missing teardown lines alone do not prove a reset failure.

**UNVERIFIED:** stage 3 in-game behavior, repeated screen transitions, cancellation, menu switching, and CET reload still need this new build tested. The user confirmed stage 2 only. Automated state fixtures do not establish game compatibility.

I stopped after stage 3. Stage 4 requires the user's confirmation.

Current deferred-fix locations: `events.lua:349`, `domain/state.lua:341`, `editor.lua:54`, and the editor-open-timeout restoration call at `events.lua:315`.
