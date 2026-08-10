# Character Preset Manager (CET)

**Current version: 2.0.6**

Save, load, organize, and share complete Cyberpunk 2077 character appearances
directly through Cyber Engine Tweaks.

## AI disclosure

The CET interface used AI-generated visual work for its layout, style, and
presentation. All Lua code, preset saving and loading logic, and mod features
were written and tested by the author.

## Features

- **Complete appearance presets:** Save and load face, hair, eyes, makeup,
  cyberware, tattoos, scars, and exposed CC or CCXL options.
- **Full appearance editor anywhere:** Open the full vanilla editor during normal
  gameplay from CET or an optional hotkey.
- **Full mirror options:** Apartment mirrors show the full character-creator
  option set.
- **One-click loading:** Select a preset once. The remaining loading passes run
  automatically.
- **Cosmetic cleanup:** Clears exposed cosmetics that are not included in the
  incoming preset.
- **Preset folders:** Create, rename, copy, delete, and move presets between
  folders from CET.
- **Preset sharing:** Every appearance is stored as one shareable `.preset` file.
- **ACU preset import:** Import supported ACU-format preset files without running
  the ACU mod.
- **Activity log:** View preset actions, results, notices, and errors.
- **Clean interface:** Collapsible sections keep the CET window organized.

## Requirements

- [Cyber Engine Tweaks 1.37.1 or newer](https://www.nexusmods.com/cyberpunk2077/mods/107)
- No other runtime dependency is required.

## Installation

1. Extract the release archive into the Cyberpunk 2077 game folder.
2. Launch the game and open the Cyber Engine Tweaks overlay.
3. Select **Character Preset Manager (CET)**.

The window starts near the right side of the screen. CET remembers where you
move it.

### Optional editor hotkey

1. Open CET and select **Bindings**.
2. Find **Character Preset Manager (CET)**.
3. Assign a key to **Open Full Appearance Editor**.
4. Close CET before using the hotkey during gameplay.

The in-mod **Help** panel shows the current assignments for both **Open Full
Appearance Editor** and **Toggle Character Preset Manager (CET)**. If a CET
version cannot return the key name, Help falls back to confirming whether that
input has been received during the current session.

## Creating a preset

1. Open **Full Appearance Editor**, a mirror, a ripperdoc customization screen,
   or the new-game editor.
2. Open Character Preset Manager in CET.
3. Select a folder under **Folders**, or select **All Presets**.
4. Enter a name under **Create**.
5. Select **Create New Preset**.

If the name already exists, confirm the overwrite only if you want to replace
that preset.

## Loading a preset

1. Open a supported character customization screen.
2. Select a saved preset under **Load**.
3. Select **Load Selected Preset** once.
4. Wait for the green **Preset fully applied** message.

Cyberpunk may rebuild the editor several times while loading. Character Preset
Manager waits for each rebuild and continues automatically.

Options that are not saved in the incoming preset may be removed. If the same
options cannot be found after three checks, loading stops instead of applying
them to the wrong place. This often means the installed character option mods
or their load order changed after the preset was created.

## Folders and preset management

- Use `[+]` and `[-]` under **Load** to open or close preset folders.
- Root presets appear below the folders.
- New presets are organized under the virtual folder selected under **Folders**.
- Adding a folder while another folder is selected creates a nested virtual
  folder. Select **All Presets** first to create one at the root.
- To move a preset, select it under **Load**, select a destination under
  **Folders**, then select **Move Selected Preset Here**.
- Select **All Presets** as the destination to move a preset out of a folder.
- A copied preset is placed beside the original.
- A copied virtual folder includes its presets and nested virtual folders.
- Copy names use `Copy`, `Copy 2`, and so on.
- Preset and folder deletion requires confirmation and is permanent.

Folders created through CET are virtual and are not limited by packaged slots.
Their organization is stored in `Character Preset Manager (CET) Folders.txt`;
creating or renaming one, or moving presets between them, does not create or
rename a directory in File Explorer.

On upgrade, untouched legacy folder-slot directories are removed automatically.
Any legacy slot containing an unrecognized file or folder is left unchanged.

Directories added manually under `Character Presets` are discovered recursively
and labeled **Imported**. Their presets remain at their existing file paths.
Renaming an imported folder in CET changes only its virtual name, and moving one
of its presets changes only the catalog assignment. Deleting a folder
permanently deletes the presets assigned to it but leaves manually created
directories and unrelated files in place.

Directory discovery stops if an entry cannot be verified or nesting exceeds 12
levels. Linked folders and junctions are not supported.

## Compatibility

### CC and CCXL character option mods

**Supported.** Character Preset Manager saves and loads custom options when they
appear in Cyberpunk's normal character customization system. Repeated and linked
options, including heterochromia, are supported.

Keep the same option mods installed and in the same load order when creating and
loading a preset. If the setup changes, fix the appearance and save the preset
again.

### Custom character creators and customization fixes

**Supported when they use the vanilla customization system.** Character Preset
Manager does not change meshes, rigs, archives, or another mod's assets.

### Appearance Change Unlocker (ACU)

**Incompatible.** Do not run ACU and Character Preset Manager together. Remove
ACU and fully restart Cyberpunk before using this mod.

Automatic ACU checks were removed because they could report the mod after it was
uninstalled. Character Preset Manager can still import ACU-format `.preset`
files after ACU itself has been removed.

### Character Customization Anywhere

**Incompatible.** Character Customization Anywhere changes the same mirrors and
character customization screens used by Character Preset Manager. Remove it and
fully restart Cyberpunk before using this mod.

Character Preset Manager does not automatically check for this mod.

### Photo Mode and Appearance Menu Mod

**Compatible, with a usage limitation.** Both mods may remain installed, but
Character Preset Manager cannot save or load presets from inside Photo Mode or
Appearance Menu Mod. Create and load presets through the full editor, a mirror,
a ripperdoc, or the new-game editor.

### Known game issue: loading screen after customization

Cyberpunk may sometimes remain on a loading screen after any character editor
closes. This can happen without Character Preset Manager, especially when
clothing or wardrobe outfits are active.

If this happens, unequip all clothing and select **No Outfit** before opening
the editor. Put the items back on afterward. Equipment-EX and detailed outfits
may make the issue more likely.

The Load section may show an optional clothing notice. You can ignore it and
load normally. The notice does not mean the mod is broken. It is hidden in the
new-game editor because that screen may contain hidden starter equipment.

## Sharing and importing presets

Preset folder:

```text
bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Character Presets
```

- To share a preset, upload its `.preset` file.
- To install a preset, place the file in this folder or any folder inside it.
- Close and reopen the CET window after changing preset files outside the game.
- Virtual folder assignments are local catalog data and are not embedded in a
  shared `.preset` file. A newly imported file initially follows the manual
  directory where it was placed.
- Imported ACU-format files work like normal presets and can be renamed, copied,
  saved again, or deleted.
- Unsafe or unusually large preset files are ignored. A preset is limited to
  1 MB, 8,192 lines, 4,096 valid options, 256 bytes per option key, and option
  indexes from 0 through 65,535.

## Activity log

Select **Debug** in the mod window to view or copy the activity log.

Log file:

```text
bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Character Preset Manager (CET) Activity.log
```

Each full game launch starts a new log. The previous log is saved with a date
and time. The 10 newest old logs are kept.

## Upgrading from version 1.0.x

Do not install version 2.0.6 directly over a 1.0.x installation.

1. Back up your `.preset` files outside the mod folder.
2. Delete `mods/Preset Manager (CET)`.
3. Install version 2.0.6 normally.
4. Move your presets into
   `mods/Character Preset Manager (CET)/Character Presets`.
5. Launch the game and open CET.

Do not leave both the old and new mod folders installed.

## Frequently asked questions

### Can I import ACU presets?

Yes. Remove ACU, copy the `.preset` file into the Character Presets folder, and
reopen CET.

### Can ACU remain installed?

No. ACU is incompatible with Character Preset Manager.

### Is Character Customization Anywhere compatible?

No. It changes the same mirrors and customization screens.

### Does this work with Photo Mode or Appearance Menu Mod?

They are compatible and may remain installed. Character Preset Manager cannot
save or load presets from inside their interfaces; use a supported character
editor instead.

### Is the character preset shown in the screenshots included?

No. The author's personal preset is not included or planned for release.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for the complete version history.

## Credits

Character Preset Manager (CET) by dklyntly.
