# Codeware removal checks

The scripts compile against the installed Cyberpunk 2077 2.5 base cache with
redscript CLI 0.5.32. The compile includes only the shipped CPM scripts, and
the resulting bundle contains no Codeware classes.

Run the compile check with:

```text
node native/verification/test_codeware_free.js <redscript-cli.exe> <base-final.redscripts>
```

Use the unmodded game cache as the second path. The check compiles into a
temporary folder, inspects the result, and removes its temporary files.
It also checks callback cleanup and the game interfaces used by the full editor.

The native file service has no Codeware imports or game-address hooks.
Its importer and directory-watcher tests pass after rebuilding from source.
The preset parser, folder tree, catalog, randomizer, and delayed appearance
loader checks also pass with this change.

The older local panel suite reaches an unrelated ACU polling assertion that
expects a removed helper named `readImportGeneration`. Its menu checks were
adapted for this change, but that older polling assertion still fails.

## In-game checks still needed

I have not run the replacement menus in the game. A clean compile does not
confirm that widget focus, layout, and input work correctly during play.

- Install the current source scripts with compatible CET, RED4ext, and redscript.
  Test without Codeware, then repeat with a compatible Codeware install.
- Open character creation, an apartment mirror, and the Full Appearance Editor.
  Check both menus in each screen and confirm that they share the same library.
- Search and clear text, paste a name, and check the 64-character limit.
  Switch fields, click outside, and use Back or Confirm to leave text entry.
- Save a preset, confirm an overwrite, load another, and cancel a load.
  Check folders, save locations, recovery history, Trash, and load details in CET.
- Use randomizing and its settings from both menus with CET closed and open.
  Check mouse scrolling, controller input, disabled buttons, and text-entry focus.
- Close and reopen each editor several times, including during a load.
  Check for duplicate panels, repeated actions, stuck focus, and stale callbacks.
- Test without the panel scripts and with CET unavailable separately.
  Confirm that normal character-screen controls remain usable and presets remain intact.

Existing release archives are unchanged. These source changes do not establish
compatibility for the older packaged menu.
