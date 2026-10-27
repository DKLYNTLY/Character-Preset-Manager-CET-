# Part B test build: remove load cancellation

I removed the load-cancel controls from CET and the character-screen panel, plus the Lua handler, mailbox action, and current Help and README instructions. Editor close, shutdown, recovery, full reset, and every other bridge action keep their existing behavior.

This change does not repair the automatic-load timeout or the reported visible hair and cyberware leftovers. Those are separate tasks.

## Bridge compatibility

The request and response format, public method signatures, class identities, and protocol number remain unchanged. Protocol 1 is still used by the updated Lua and redscript pair.

The command set loses exactly one action: `cancel_load`. The busy-request filter changes from allowing `list` and `cancel_load` to allowing only `list`, and the guard that gave a queued cancellation priority is removed. All other action names and request arguments are unchanged.

There is no dedicated bridge `CancelLoad` method. The panel's `OnCancelLoad` widget callback and its two private runtime fields are removed, while the public mailbox methods retain their signatures.

An older panel can still show its old cancel button. Its cancellation request is unsupported by the new pair; protocol 1 does not negotiate that removed capability. Install the Lua files, `Bridge.reds`, and `Panel.reds` together, then restart the game. The updated panel uses no command that the old Lua pair lacked.

Unrelated cancellation remains: save confirmation, the location picker, editor confirmation, the native overlay-opening request, and Windows directory-watch I/O. Historical changelog entries and the stage 3 audit still describe the controls present in their original builds.

## Changed tests and validation

- `stage3_tests.lua`: removes the `realCancel` alias and cancellation integration case. It adds an assertion that the removed Lua entry point is no longer exported.
- `stage3_fixtures.lua`: removes only original snapshot 52, which recorded the cancellation result. The other 63 snapshot strings are unchanged.
- Stage 1 and stage 2 tests and fixtures are unchanged. Retired ignored tests are historical and are not part of these active suites.
- The timeout fixture deliberately retains the old bug for Part B. The state and update-loop files have not changed.

Validation results:

- Stage 1: all 833 fixtures and its additional compatibility checks pass.
- Stage 2: all 183 cases, 62 baseline writer comparisons, and seven canonical format-8 byte comparisons pass.
- Stage 3: all 63 remaining snapshots and the constructor, reference, result, and removed-entry-point checks pass.
- Lua 5.1 parsing passes for all 47 Lua files.
- The installed redscript compiler successfully compiles the four CPM scripts with the installed Codeware scripts against the current game bundle. The compile runs in a temporary copy and leaves the installed scripts and game cache untouched.
- Source comparison confirms that only `cancel_load` is removed from the Lua action set and panel requests. All public bridge signatures and protocol 1 stay unchanged.
- Editor, shutdown, full-reset, timeout, and constant definitions are unchanged from the stage 3 source.

The older `.tools/redscript-cli.exe` cannot read the current game cache. The successful check uses copies of the installed `engine/tools/scc.exe` and `scc_lib.dll`, the installed `r6/cache/final.redscripts`, and Codeware's current scripts in an isolated temporary game layout. Its output contains `Compilation complete` and `Output successfully saved`.

Run the Lua suites from the repository root with Lua 5.1, then run the existing Node syntax checker:

```text
lua "source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/modules/domain/stage1_tests.lua"
lua "source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/modules/domain/stage2_tests.lua"
lua "source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/modules/domain/stage3_tests.lua"
node native/verification/check_code.js
```

## Files to install

Replace these files under the existing CET mod directory:

- `modules/load_engine.lua`
- `modules/native_bridge.lua`
- `modules/ui/sections_load.lua`
- `modules/ui/help_panel.lua`
- `modules/domain/stage3_tests.lua`
- `modules/domain/stage3_fixtures.lua`

Also replace:

- `r6/scripts/CharacterPresetManager/Bridge.reds`
- `r6/scripts/CharacterPresetManager/Panel.reds`

The first four Lua files and both redscript files are needed for the changed controls. The test files keep local validation aligned with this build. Keep all other stage 3 files, including the unchanged DLL.

The full test ZIP includes the three shipped roots and every tracked file inside them. Its contents come from the committed snapshot. README, CHANGELOG, and this verification guide are repository documentation rather than extra ZIP-root files.

## In-game checklist

1. **Check both menus.** Cancel Loading must be absent from CET, and Cancel Load must be absent from the character-screen panel. Undo, recovery, saving, loading, and the other controls should still work. The other panel controls keep their existing positions.
2. **Complete a load.** Use an available preset and look for `[PRESET] Load requested`, its `SUMMARY` with `result=complete` or the existing warning result, and the final loaded-options message. Confirm that busy controls become available and ordinary camera behavior resumes.
3. **Close mid-load and reopen.** Look for `[MEASURE] Load editor-closed` when an active load is interrupted, followed by the usual editor-open message on return. Start another load and confirm it gets its own request and summary. Idle closes have no dedicated success line.
4. **Check recovery and switching menus.** Use Undo or recovery, then open and close CET. Expect the normal CET opened/closed messages and consistent controls. There should be no live cancellation status or request.
5. **Timeout coverage.** The threshold is still `max(60, savedOptionCount * 2 + 10)` seconds: 128 seconds for 59 saved options. A natural timeout requires the load to stay active beyond that threshold. Missing choices normally stop sooner, so they are not a reliable way to force it. The automated update-loop fixture exercises timeout directly without changing the shipped threshold.

Part B still has the known timeout stuck-busy bug. If a natural timeout occurs, expect `[MEASURE] Load safety-limit` and the safety-limit warning; the pending state may remain active. Closing and reopening the character screen invokes the existing full reset. The corrected timeout and its in-game verification belong to Part C, so I cannot claim that every terminal path is fixed in this build.

**UNVERIFIED:** in-game behavior of this Part B build. Compilation and state fixtures do not replace the checklist above. No release or version change is made, and work stops before Part C.
