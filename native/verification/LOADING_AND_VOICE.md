# Part C test build: release timed-out loads

I fixed the automatic-load timeout leaving the menu busy and automatic camera focus suppressed. Part B's cancel removal remains in place, and this commit changes only the timeout terminal path.

## Timeout behavior

The safety threshold is unchanged: `max(60, savedOptionCount * 2 + 10)` seconds. The existing strict `elapsed > maximumSeconds` comparison also stays unchanged. A 59-option load reaches the limit at 128 seconds and times out only after exceeding it.

The timeout branch now performs these steps in order:

1. Record `[MEASURE] Load safety-limit` before clearing the original preset name, elapsed time, and counters.
2. Call the existing `resetLoadState` and finished-load working-data cleanup, then invalidate preflight results.
3. Clear the active timing marker and explicit camera hold. Pending choices, batch, staged work, and temporary option data are released.
4. Keep the original safety-limit warning and publish it as an error status.
5. Use a timeout-specific native adapter to call the existing protected `SetBusy(false, message, true)` method. It also clears the old summary and updates the Lua busy/status cache.

The immediate bridge notification is needed because ordinary bridge synchronization runs earlier in the update. Clearing its cached busy flag without notifying the panel could prevent the next update from releasing the panel.

The private `bridgeCall` stays in `native_bridge.lua`; no game-boundary call moves into a domain module. If the bridge is missing or its call fails, the existing protected adapter handles it while local load and camera state still reset. Reconnection continues to use the existing code.

Queued CPM work is discarded. The fix does not undo appearance choices already applied or retract a game write already submitted. The visible hair/cyberware report and wardrobe retry gap remain separate stage 8 work.

## Compatibility and scope

Protocol 1, all redscript method signatures and action strings, the safety constants, and preset formats are unchanged from Part B. The redscript files and DLL are unchanged as well. Both menus continue to use the same state locations.

The old domain `stopAutomaticAtTimeout` footprint remains for compatibility and its original state-constructor tests. The production timeout path no longer calls it; that path now uses the existing full reset. Other terminal paths and matching/write logic are unchanged.

## Validation

- Stage 1: all 833 fixtures and additional compatibility checks pass.
- Stage 2: all 183 cases, 62 baseline writer comparisons, and seven canonical format-8 byte comparisons pass.
- Stage 3: all 63 snapshots pass. Only the real `update_timeout` snapshot, at file line 60, changes its expected state and bridge notification; the other 62 expected snapshots remain unchanged.
- Additional checks cover the exact 60-second and 128-second boundaries, crossing each boundary, ready/missing/failing bridges, measurements before cleanup, idle behavior on the next update, and starting another load immediately afterward.
- The ready-bridge check uses the actual protected native adapter and verifies `SetBusy(false)` reaches a panel stub. A following real bridge update keeps the timeout status and does not reassert busy.
- Lua 5.1 parsing passes for all 47 Lua files.
- The installed redscript compiler successfully compiles the four CPM scripts and installed Codeware scripts against the current game bundle in a temporary copy. Installed scripts and game caches are not changed.

The timeout test now checks `auto=false`, `needsContinue=false`, no pending choice or batch, released temporary data, no camera hold, and an idle bridge cache. It also confirms no further load pass runs after timeout.

Run the existing suites from the repository root:

```text
lua "source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/modules/domain/stage1_tests.lua"
lua "source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/modules/domain/stage2_tests.lua"
lua "source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/modules/domain/stage3_tests.lua"
node native/verification/check_code.js
```

## Files to install

For an installation already running Part B, replace these files under the CET mod directory:

- `modules/events.lua`
- `modules/native_bridge.lua`
- `modules/domain/stage3_tests.lua`
- `modules/domain/stage3_fixtures.lua`

The first two files are required at runtime; the test files preserve local validation. The full ZIP includes all three shipped roots and the complete current build, including Part B's matching Lua/redscript pair. Install that ZIP through Vortex or extract into the game folder and allow overwrites, then restart the game. No DLL replacement beyond the unchanged bundled file is required.

README, CHANGELOG, this guide, and the stage 3 audit note are repository documentation. They do not add settings or saved fields.

## In-game checklist

1. **Normal completion:** Start an available preset and let it finish. Look for `[PRESET] Load requested`, its `SUMMARY` with `result=complete` or the existing warning result, and the final status. Verify that busy controls become usable and automatic camera focus works again.
2. **Close mid-load:** Close the character screen during loading. If the load was active, expect `[MEASURE] Load editor-closed`. Reopen it, confirm the normal editor-open message, and start a new load. There should be no old load activity after the reset.
3. **Timeout:** A natural load must remain active beyond the unchanged threshold. For 59 options that means more than 128 seconds; missing choices usually stall sooner, so they are not a reliable trigger. The automated suite forces this state through the real update path, but the normal menus have no dedicated timeout test control.
4. **After timeout:** Look for `[MEASURE] Load safety-limit` with the original preset name and elapsed time, followed by `Loading took longer than the safety limit allows.` The menu should leave its busy state immediately, camera suppression should end, and starting a second load should not require closing the editor.
5. **Both menus:** Repeat completion and close/reopen checks in CET and the character-screen panel. Switch between them and check that the timeout message, if reached, is consistent. Cancel remains absent.

There is no new cleanup-success log. The existing measurement and warning identify the timeout; usable controls, camera behavior, and the next load establish the in-game outcome.

**UNVERIFIED:** a natural timeout and the rest of this Part C build's in-game checklist still need game testing. Automated and compile checks establish the covered state transitions, not rendered appearance behavior.

No release or version change is made. Stop after Part C; stage 4 needs the user's confirmation.
