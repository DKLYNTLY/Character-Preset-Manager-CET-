# Validation

## Text update: October 21, 2026

I rewrote the project instructions, README, packaged text, Help and current
messages in plain language. I also simplified parts of the release history,
keeping old controls and behavior in their original release sections.

I checked that the source edits change only quoted text. I rebuilt the native
DLL and ran all three CTest groups: native controller, service and importer.
Each group passed. The menu source checks passed too, and luaparse parsed all
three shipped Lua files in Lua 5.1 mode.

I reran the native/Lua comparisons for 34 preset reads, format-8 writing, 252
appearance comparisons and 17 archive cases. The loading checks also passed: 301
single decisions and 120 staged sequences with 873 decisions in total. These
checks use test data rather than a character inside the game.

The game scripts compiled with Codeware against the installed game cache.
Codeware still reports its existing Reflection.reds warning about a return path.
I have not checked the revised text or its screen layout inside the game.

## Previous release: 3.1.4 validation

I rebuilt the Release DLL after updating my author name and the release version.
All three CTest checks passed with normal Windows file permissions. In the first
run, the sandbox blocked writes to temporary files and caused the checks to
fail.

I parsed all three shipped Lua files with the installed luaparse dependency,
then separately parsed init.lua extracted from the release archive. The archive
checks passed for all 22 files. They covered the bin/x64 layout, the matching
Release DLL and the included copy of my license. The four required version
fields agree on 3.1.4. I also checked the changes for whitespace errors.

This update changes credits, license documentation and version labels. At the
time of that release, I had not tested it inside the game or repeated the
broader 3.1.3 checks below.

## Previous release: 3.1.3 validation

I ran the automated checks on Windows on October 19, 2026, after adding the
preset service, menus, library move and documentation. I fixed failures and
reran the affected checks. I have not performed in-game checks for this version.

## Automated checks

- The Release DLL and native verification targets build with the installed
  RED4ext SDK. All three CTest targets pass: native controller, service and
  importer.
- The native controller runs without Lua in a separate test program. Checks
  cover initial migration and ACU import from the game folder; save and
  confirmed overwrite; notes, tags and favorites; folders and nested folder
  recovery; bulk moves; sharing and backups; Trash; comparison; staged loading;
  cancellation; history; settings and saved native keys. Technical commands use
  the same service session.
- Migration checks cover fresh installs, identical destination files,
  conflicting records, preserved originals, nested files, an interrupted
  temporary copy, repeated attempts and completed migrations that do not
  reimport old files.
- Native loading checks reject missing named choices even with force loading,
  produce a partial result for an unconfirmed choice, and reject work after the
  editor session closes. The test program supplies editor choices. It does not
  run redscript or change a character inside the game.
- redscript compilation succeeds against the installed final.redscripts game
  cache and Codeware sources. The only warning is Codeware's existing
  Reflection.reds return path. Compilation checks script code and types. It does
  not confirm that native functions connect in the game, that menus fit, or that
  input works.
- Native menu source checks cover selection before loading, panel hiding,
  cancellation, blocked keys while typing, native service control and optional
  CET communication.
- All 11 Python verification scripts pass. The older Lua checks compare against
  legacy_312 reference files, which are not shipped. Those checks do not verify
  the new redscript connection. Comparisons with the reference code cover 34
  preset reads, readable format-8 writing, 252 comparisons, 17 archive cases,
  301 planning decisions and 120 staged sequences containing 873 decisions.
- The installed luaparse tool parses all three shipped Lua files using Lua 5.1
  rules. The extracted archive's init.lua is parsed separately.
- Package inspection verifies 21 files, bin/x64 at the archive root, six native
  script files, six bundled presets, exactly one init.lua and the matching
  Release DLL. Personal Data, historical Lua references and obsolete Lua modules
  are excluded. Version fields agree on 3.1.3.

## In-game checks still required

- CET absent: saving, loading, every manager screen and native keys.
- CET present: technical tools, overlay reloads and shared session ownership.
- Native functions connecting to scripts and receiving editor events in the
  game.
- New-game creation, mirrors, supported ripperdocs and full-editor launches.
- Confirming and canceling actions, restoring wardrobe outfits and handling
  failed editor launches.
- Keyboard, mouse and controller navigation, text entry, Back, scrolling and
  hidden-panel cancellation.
- Standard, widescreen and ultrawide placement without blocked game controls.
- Real startup, migration, editor-opening and appearance-loading performance.

I still need to run these checks. Cyberpunk 2077 was not running during this
work, and I do not have the files needed to reproduce commenters' exact ACU
failures.

## Reproducing the automated checks

Build the native code with CMake and `CPM_BUILD_TESTS=ON`. Run CTest in Release
mode, then run the verification `test_*.py` scripts with lupa available and
`panel_contracts.cjs` with Node.js. Compile the shipped scripts with Codeware
against the installed game cache, saving the output to a temporary build folder.
For a requested release, run `package_release.py` last to parse Lua and check
the release archive.