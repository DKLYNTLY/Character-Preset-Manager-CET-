# Version 3.1.3 validation

I ran the automated checks on Windows on October 19, 2026, after implementing
the runtime, menus, migration and documentation. I fixed failures and reran the
affected checks. I have not performed in-game checks for this version.

## Automated checks

- The Release DLL and native verification targets build with the installed
  RED4ext SDK. All three CTest targets pass: native controller, service and importer.
- The actual native controller runs without Lua in its workflow harness. Checks
  cover initial migration and ACU import from the game folder; save and confirmed
  overwrite; notes, tags and favorites; folders and nested folder recovery; bulk
  moves; sharing and backups; Trash; comparison; staged loading; cancellation;
  history; settings and saved native keys. Technical commands keep the same session.
- Migration checks cover fresh installs, identical destination files, conflicting
  records, preserved originals, nested files, an interrupted temporary copy,
  repeated attempts and completed migrations that do not reimport old files.
- Native loading checks reject missing named choices even with force loading,
  produce a partial result for an unconfirmed choice, and reject work after
  the editor session closes. The harness simulates editor choices; it does not
  execute redscript or change a character inside the game.
- redscript compilation succeeds against the installed final.redscripts game
  cache and Codeware sources. The only warning is Codeware's existing
  Reflection.reds return path. Compilation checks types and scripts; it does
  not confirm runtime native binding, menu layout or actual input handling.
- Native menu source checks cover selection before loading, panel hiding,
  cancellation, text-focus guards, native ownership and optional CET transport.
- All 11 Python verification scripts pass. Historical Lua adapter checks use
  unshipped legacy_312 files as regression references. They do not validate the
  new redscript adapter. Native/reference comparisons cover 34 preset reads,
  readable format-8 writing, 252 comparisons, 17 archive cases, 301 planning
  decisions and 120 staged sequences containing 873 decisions.
- The installed luaparse dependency parses all three shipped Lua files in Lua
  5.1 mode. The extracted archive's init.lua is parsed separately.
- Package inspection verifies 21 files, bin/x64 at the archive root, six native
  script files, six bundled presets, exactly one init.lua and the matching
  Release DLL. Personal Data, historical Lua references and obsolete Lua modules
  are excluded. Version fields agree on 3.1.3.

## In-game checks still required

- CET absent: saving, loading, every manager screen and native keys.
- CET present: technical tools, overlay reloads and shared session ownership.
- Runtime registration of the typed native transport and editor callbacks.
- New-game creation, mirrors, supported ripperdocs and full-editor launches.
- Confirm/cancel paths, wardrobe restoration and failed launches.
- Keyboard, mouse and controller navigation, text entry, Back, scrolling and
  hidden-panel cancellation.
- Standard, widescreen and ultrawide placement without blocked game controls.
- Real startup, migration, editor-opening and appearance-loading performance.

These are outstanding, not passed. Cyberpunk 2077 was not running during this
work. I have not reproduced commenters' exact ACU failures without their files.

## Reproducing the automated checks

Build native with CMake and CPM_BUILD_TESTS=ON, then run CTest in Release mode.
Run the verification test_*.py scripts with lupa available, and panel_contracts.cjs
with Node.js. Compile the shipped scripts together with Codeware against the
installed game cache, writing the output to a temporary build location. Run
package_release.py last to parse Lua and verify the release archive.
