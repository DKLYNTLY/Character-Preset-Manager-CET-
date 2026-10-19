# Character Preset Manager (CET)

**Version 3.1.3**

Save, load and organize Cyberpunk 2077 appearance presets inside an appearance
editor. The main tools use redscript, RED4ext and Codeware. CET is optional for
force loading and technical details.

I have not yet checked this version inside the game. See the
[validation report](native/verification/VALIDATION.md) for completed checks and
outstanding work.

## Requirements and installation

Install RED4ext 1.30.0, redscript 0.5.31 and Codeware 1.20.3, or compatible newer
versions. This build targets Cyberpunk 2077 2.31. Install CET 1.37.1 only for the
optional technical menu or existing CET key assignments. CDPR's REDmod DLC and
mod deployment are not required.

1. Install the requirements. Remove Character Customization Anywhere if installed,
   then fully restart before using the Full Appearance Editor.
2. Extract `Character Preset Manager (CET) 3.1.3.zip` into the main Cyberpunk 2077
   folder. Merge its `bin`, `r6` and `red4ext` folders with those already there.
3. Open new-game creation, an apartment mirror, a supported ripperdoc appearance
   screen, or the Full Appearance Editor. Choose **Manage Presets** for library tools.

Install the complete package. The DLL and scripts must match. Missing or
mismatched files require a complete reinstall and a full game restart.

## Updating and moving your files

Back up the complete old **Character Presets** and **Data** folders. Data contains
organization, settings, recovery, history and Trash. Remove `init.lua` and the `modules` folder from the old CET mod folder, and
remove `r6/scripts/CharacterPresetManager`. Then install this package. Keep the old
Character Presets and Data folders in place for the first start:

```text
bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/
```

The first library opening copies those folders into:

```text
red4ext/plugins/CharacterPresetManager/
```

Copied files are verified and originals are kept. Interrupted copies resume on
the next attempt. Identical files are kept once. Differing old copies are saved
under `Data/Migration/Conflicts` in the native folder. Tools stop instead of
replacing conflicting records. Back up both locations, review differing copies,
and make the original and destination agree or remove the old conflicting copy
after preserving it. Reopen the editor to retry. Keep the only copy of each
preset or recovery record. Completion is recorded in `Data/Migration/Completed.txt`.

After completion, the native folder is the active library. Changes to the old
CET library are not copied again automatically. Keep the originals until you
have checked the new library and made a separate backup. Bundled presets are
copied only when their destination file does not already exist.

## Saving and loading

Search for a preset, select its row, then choose **Load**. Selecting a row only
selects it. Wait for the result before confirming the editor. **Cancel Load**
stops further changes; applied choices remain visible. Recovery can restore an
earlier appearance.

Enter a name and choose **Save Preset**. An existing name requires **Confirm
Overwrite**. **More Actions** includes save locations, Refresh, compatibility
checks and recovery. **Hide Presets** clears the panel so you can reach the
randomizer controls. **Show Presets** restores it with its search, selection and
scroll position. A new editor session starts with the panel visible. Progress
and cancellation remain available while loading.

Loading does not change an existing character's gender or body type. Photo Mode
and Appearance Menu Mod do not expose the required editor data. Use one of the
supported appearance screens.

## Managing your library

**Manage Presets** opens inside the appearance editor. **Back to Editor**, or the
Back control, returns to the compact panel. There is no pause-menu entry.

- **Presets:** Edit notes and tags, favorite, duplicate, rename, move, compare or
  send presets to Trash. Rename and Move take a full destination such as
  `My Folder/My Preset`. Mark several presets for Move Marked or Trash Marked.
- **Folders:** Create, rename, copy or remove folders. Enter source and destination
  in the labeled fields. Removing a folder keeps its presets in the parent folder.
  Save Location chooses where new presets go.
- **Sharing:** Preview and import `.cpmfolder` files and `.cpmbackup` backups.
  Export a folder or marked presets, or create a complete library backup. Files
  are saved in the native Character Presets folder. Imports keep existing
  presets and use a separate folder when names overlap.
- **Recovery:** Restore Trash items or saved appearances. Undo Last Load restores
  the appearance saved before loading. Activity Log explains results. Empty
  Trash, Clear History and Delete Backup permanently remove saved files and
  require a second selection to confirm.
- **Settings:** Choose name or date order and optional editor/panel keys. Select
  a binding, then press the key. Backspace clears it.
- **Help:** Read controls, compatibility and current file locations.

Pages contain up to 96 presets. Use Next Page or Previous Page rows for larger
libraries; scroll controls move through the current page.

## File limits, folders and recovery

A preset can contain at most 1 MB, 16,448 lines and 4,096 valid options. Option
names are limited to 256 bytes; choice numbers must fit an unsigned 32-bit value.
A shared folder can contain up to 512 presets and 32 MB. Empty groups cannot be
exported. A library backup can contain up to 256 MB. Backups include presets,
folder organization and the preset sort setting, but are separate from appearance
history. Native key assignments stay in Data/Config/Native Keys.txt; back up the
complete Data folder to keep those assignments too.

The mod keeps up to five different appearance-history entries. Identical
snapshots are skipped. Before loading a preset or restoring history, it saves
the current appearance. History is under `Data/Recovery/Appearance History`.

Folders created in the manager organize the library without creating matching
Windows folders. Their records are under `Data/Catalog/Virtual Folders.txt`.
Format-8 preset headers also record names and folders so missing catalog entries
can be rebuilt. `/` means All Presets. Physical folders inside Character Presets
are discovered too. Linked folders and Windows junctions are unsupported; the
physical scan stops beyond 12 nested levels or when it cannot verify an entry.
Unknown files are kept. Use Refresh after changing files outside the game.

**Trash Folder** keeps a complete folder group, including nested empty folders.
Recovery lists these groups separately; **Restore Folder** restores a selected
group. **Restore Shared File** restores a `.cpmfolder` source file. Removing a
shared source file does not remove presets already imported from it. Restoring
an item with a conflicting name preserves both copies with separate names.
Interrupted file actions finish or recover safely when the library next opens.

The **Bulk** tab can mark the current search page, clear marks, move or trash
marked presets, or export them together. Marks can span pages and folders.
Preview shared files or backups before importing or deleting them. If a previewed
file changes, preview it again before continuing. Unchanged shared imports are
skipped while their imported folder still exists; originals stay in place.

Settings are saved in `Data/Config/Config.txt`; native keys are in
`Data/Config/Native Keys.txt`. Avoid editing these files while the game runs.
Activity logs rotate when they grow, keeping ten older files in Data/Logs.
Compatibility checks are manual and distinguish matching, changing, missing,
repeated, invalid and extra choices. Missing choices stop after repeated checks.
There are no measured in-game performance results for this release.

## Optional keys and CET tools

Native keys work without CET. Assign them inside Manage Presets, under Settings.
Keys do nothing while typing. The panel key requires an appearance editor.
Close CET before using keys. Existing CET binding identifiers remain optional
aliases; assignments are not copied automatically into native settings.

With CET installed, open its overlay and choose **Character Preset Manager -
Technical Tools**. Select a preset in the game panel first. **Force Full Load**
requires confirmation and uses less certain matching where safe. It never
substitutes a saved number for a missing named custom choice. Review the result.
**Read Editor Options** and **Read Activity Log** provide technical information.
Opening or reloading CET does not start a second service session.

## Older presets and ACU import

Readable format 8 remains current, with plain headings and labeled Editor slot
and Saved choice lines. Older compatible CPM presets and ACU 3.0.0 JSON, 3.0.1
JSON, and 3.2.1 text and JSON layouts remain readable. Only formats 7 and 8 are
labeled CPM presets. Finding or loading an older file does not rewrite it.
Overwriting it or saving notes or tags updates it to format 8.

Compatible `.preset` files are copied from:

```text
bin/x64/plugins/cyber_engine_tweaks/mods/AppearanceChangeUnlocker/character-presets
```

Imported copies appear under **ACU Presets** in the native library. Original ACU
files are not moved or rewritten. Subfolders are preserved. Unchanged files are
skipped, and edits to imported copies are kept. ACU may remain installed for
importing; use Character Preset Manager to load its copies. Do not load from both
mods at once. Removing ACU after import does not delete imported copies.

If imports are missing, check folder spelling and the `.preset` extension. Files
must be nonempty and no larger than 1 MB. Fully restart, select Refresh, and read
the Activity Log if files remain missing.

ACU files do not record current CPM's stable editor-slot and saved-choice details.
CC and CCXL choices may shift when appearance mods, versions or load order change.
Check Compatibility, review the appearance and save a corrected format-8 preset.
Reading a preset does not prove its appearance mods are installed. Missing,
repeated or inactive choices can produce a partial load.

## Troubleshooting and limits

Activity logs are under `red4ext/plugins/CharacterPresetManager/Data/Logs`.
Include the relevant message when asking for help. Wardrobe changes made by this
mod are restored after leaving the editor; an outfit already disabled by the game
is left alone. Removing clothing and choosing No Outfit is a reported workaround
for some loading problems, not a guaranteed fix. My personal character preset
shown in screenshots is not included, and I do not plan to release it.

## AI disclosure

I used AI to help plan, write, and review parts of the interface, Lua, C++,
redscript, documentation, and release checks. I made the final design and
release choices and reviewed the finished work before publishing it.

## Credits

I created and maintain Character Preset Manager as **dklyntly**.

[ACU - Character Preset Manager](https://www.nexusmods.com/cyberpunk2077/mods/3850)
by **PotatoOfDoom** is the predecessor to this project. I built Character Preset
Manager as its successor and kept support for compatible ACU presets so existing
collections are not lost. My current format, code, interfaces, loading system,
and controls are separate implementations.

[Character Customization Anywhere](https://www.nexusmods.com/cyberpunk2077/mods/3930)
by **keanuWheeze** inspired my Full Appearance Editor.

[Cyber Engine Tweaks](https://www.nexusmods.com/cyberpunk2077/mods/107) was
created by **yamashi** and is maintained by its contributors. Character Preset
Manager uses CET for optional technical tools. RED4ext runs the preset service.
The appearance tools and game menus use redscript and Codeware.

I also credit CD Projekt Red for Cyberpunk 2077 and its character system, and I
appreciate the testing, research, compatibility information, and feedback shared
by the Cyberpunk 2077 modding community.

## Links

[Download on Nexus Mods](https://www.nexusmods.com/cyberpunk2077/mods/31886) ·
[GitHub source](https://github.com/DKLYNTLY/Character-Preset-Manager-CET-) ·
[Discord and support](https://discord.com/invite/mUGHmQxHG8) ·
[Full changelog](CHANGELOG.md) · [MIT license](LICENSE)
