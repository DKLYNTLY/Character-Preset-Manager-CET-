# Version 3.1.2 validation

I ran the automated checks below on Windows on October 18, 2026. These checks
cover the files, background service, script adapter, and simulated editor
behavior. They do not replace checks inside Cyberpunk 2077.

## Automated checks

- The Release build completed with the installed RED4ext SDK.
- Native tests passed for bounded requests, cancellation, stale sessions, one
  active appearance load, serial appearance steps, worker shutdown, and the
  production folder watcher.
- File tests covered cached library views, notes, tags, favorites, all folder
  actions, bulk moves, shared folders, backups, Trash, and appearance history.
  Interrupted transactions and older recovery records were recovered.
  Conflicting copies and outside edits were preserved.
- Native and reference Lua results agreed for 46 preset reads, a readable
  format-8 round trip, 252 comparisons, and 17 shared-file cases.
- Load planning agreed for 301 individual decisions and 120 staged sequences
  containing 873 decisions.
- Eight editor simulations covered settling, delayed updates, dependencies,
  stale snapshots, missing named choices, cancellation, and editor closure.
- Complete manager workflows ran against the actual native service through
  the production Lua adapter. They covered startup, ACU import, saving,
  metadata, every folder action, bulk moves, sharing, backups, Trash,
  compatibility, loading, history, settings, and unavailable-service handling.
  The harness rejected any attempt by Lua to open a preset file.
- Input and wardrobe tests covered one toggle per press, typing guards,
  collapsed-state preservation, missing panels, ownership of wardrobe changes,
  and restoration retries.
- All shipped Lua files, including init.lua, passed the installed
  luaparse reader in Lua 5.1 mode.
- redscript lint passed against the game cache and Codeware sources. The
  only warning came from Codeware's existing Reflection.reds return path.
- Static panel checks covered explicit loading, focus guards, collapsed load
  cancellation, compatibility controls, and required-service controls.
- The 3.1.2 archive passed its content checks: 53 files, the expected
  bin/x64 layout, one init.lua, all three redscript files, and the matching
  Release DLL. The archived init.lua was parsed again after extraction.

The older Lua implementation is retained only under the reference folder for
comparison tests. It is not included in the mod package.

## Offline performance measurements

Each preset contained 16 choices. I measured a new library and an unchanged
refresh with 64 and 2,048 presets. The baseline uses the earlier Lua directory
reader without an existing inventory or native catalog. The native measurements
include the test process transport; its first refresh also saves the inventory.
The files were already in the operating system's cache.

| Operation | 64 presets: Lua | 64 presets: native | 2,048 presets: Lua | 2,048 presets: native |
| --- | ---: | ---: | ---: | ---: |
| First refresh and inventory | 45.4 ms | 80.5 ms | 1,863.5 ms | 2,490.3 ms |
| Unchanged refresh | 30.0 ms | 21.8 ms | 609.7 ms | 733.5 ms |
| Search and sort | 0.4 ms | 1.1 ms | 23.8 ms | 5.0 ms |

A repeated native search took 1.1 ms with 64 presets and 4.5 ms with 2,048.
The larger search was faster, but the first refresh and larger unchanged
refresh were slower. Full refresh still visits every file and checks its path
and saved details. These results do not support a general speed claim.

Preset file work now runs in the background. I have not measured its effect
on game frame times, game startup, opening an editor, or real appearance loads.
Those timings remain unavailable. The raw fixture results are in
performance.json; benchmark_library.py reproduces this measurement.

## In-game checks still required

I have not performed the following checks in a running game:

- Full-editor launches, mirrors, supported ripperdoc screens, and new-game
  customization.
- Confirming or canceling an editor, failed launches, and wardrobe restoration
  with the actual equipment system.
- Randomizer access, text focus, scrolling, panel collapse, CET transitions,
  and keyboard, mouse, and controller navigation.
- Widescreen and ultrawide placement, text size, and overlap with game controls.
- Real game startup, editor-opening, and appearance-loading performance with
  small and large libraries.

These items are outstanding, not passed. I have not reproduced the commenters'
exact ACU failures without their original files.

## Running the checks

Build with CMake and CPM_BUILD_TESTS=ON, providing RED4EXT_SDK_PATH. Run CTest
for the native targets. The Python checks require lupa; adapter and workflow
checks also use CET's installed JSON library. Their optional first argument
accepts that JSON file's path when the default game location differs.

Run the test_*.py files in this folder, plus panel_contracts.cjs with Node.js.
The comparison checks load their reference modules from this folder rather
than from the shipped mod.
