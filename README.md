<h1 align="center">Character Preset Manager (CET)</h1>

<p align="center"><em>Save, load, organize, and share complete Cyberpunk 2077 character appearances directly through CET.</em></p>

<p align="center">
  <strong><a href="https://www.nexusmods.com/cyberpunk2077/mods/31886">Download on Nexus Mods</a></strong>
  ·
  <a href="CHANGELOG.md">View the complete changelog</a>
</p>

**Current version: 2.0.8**

## AI disclosure

The CET interface used AI-generated visual work for its layout, styling, and
presentation. All Lua code, preset saving and loading logic, and mod features
were written and tested by the author.

## Features

- **Complete appearance presets:** Save and load face, hair, eyes, makeup,
  cyberware, tattoos, scars, and exposed CC or CCXL options.
- **Full appearance editor anywhere:** Open the full vanilla editor during normal
  gameplay from CET or an optional hotkey.
- **Full apartment mirror options:** Apartment mirrors expose the full
  character-creator option set.
- **One-click loading:** Select a preset once and the remaining loading passes
  continue automatically.
- **Cosmetic cleanup:** Clears exposed cosmetics that are not included in the
  incoming preset.
- **Unlimited virtual preset folders:** Create, rename, copy, nest, and organize
  folders directly in CET with no fixed folder limit.
- **Preset and folder duplication:** Copy one preset or an entire virtual folder,
  including its presets and nested folders.
- **Manual folder import:** Directories created manually inside `Character
  Presets` are detected recursively and shown as **Imported**.
- **ACU preset import:** Import supported ACU-format `.preset` files without
  running ACU itself.
- **Easy preset sharing:** Each appearance is stored as an individual shareable
  `.preset` file.
- **Activity log:** View preset actions, results, notices, and errors through
  **Debug** or the log file.
- **Clean interface:** Collapsible sections and folder rows keep the CET window
  organized.

## Requirements

- [Cyber Engine Tweaks 1.37.1 or newer](https://www.nexusmods.com/cyberpunk2077/mods/107)
- No additional runtime dependency beyond CET is required.

## Installation

1. [Download the latest release from Nexus Mods](https://www.nexusmods.com/cyberpunk2077/mods/31886).
2. Extract the release archive into your Cyberpunk 2077 game folder.
3. Launch the game and open the Cyber Engine Tweaks overlay.
4. Select **Character Preset Manager (CET)**.

The window starts near the right side of the screen. CET remembers where you
move it.

### Optional hotkeys

1. Open CET and select **Bindings**.
2. Find **Character Preset Manager (CET)**.
3. Assign a key to **Open Full Appearance Editor**.
4. Optionally assign **Toggle Character Preset Manager (CET)** to open or close
   the mod window quickly.
5. Close the CET overlay before using the editor input during gameplay.

The Help panel shows the current editor and window-toggle bindings when CET can
provide their key names. It falls back to session input detection when the
installed CET version cannot return a key name.

## Creating a preset

1. Open the **Full Appearance Editor**, a mirror, a ripperdoc customization
   screen, or the new-game editor.
2. Open Character Preset Manager in CET.
3. Under **Folders**, select where you want the preset organized, or select
   **All Presets**.
4. Enter a name under **Create**.
5. Select **Create New Preset**.

If a preset with the same name already exists, confirm the overwrite only if
you want to replace it.

## Loading a preset

1. Open a supported character customization screen.
2. Select a saved preset under **Load**.
3. Select **Load Selected Preset** once.
4. Wait for the green **Preset fully applied** message.

Cyberpunk may rebuild the editor several times while loading. Character Preset
Manager waits for each rebuild and continues automatically.

If the same options cannot be found after three checks, loading stops instead
of applying them to the wrong option. This usually means your installed
character option mods or their load order changed after the preset was created.
Fix the appearance and save the preset again.

## Folders and preset management

- Use `[+]` and `[-]` under **Load** to expand or collapse preset folders.
- Presets not assigned to a folder appear below the folder list.
- Select a folder under **Folders** before creating a preset to organize it
  there. Select **All Presets** to create it at the root.
- Create a folder while another folder is selected to place the new folder
  inside it. Select **All Presets** first to create a root folder.
- To move a preset, select it under **Load**, choose the destination under
  **Folders**, then select **Move Selected Preset Here**.
- Select **All Presets** as the destination to move a preset back to the root.
- A copied preset is placed beside the original.
- A copied virtual folder includes its presets and nested virtual folders.
- Copy names use `Copy`, `Copy 2`, and so on.
- Preset and folder deletion requires confirmation and is permanent.

### Virtual folders

Folders created through CET are virtual. They organize presets without creating
or renaming directories in File Explorer. Their organization is stored in:

```text
Character Preset Manager (CET) Folders.txt
```

There is no fixed virtual-folder limit.

On upgrade, untouched legacy folder-slot directories are removed automatically.
Any legacy slot containing an unrecognized file or folder is left unchanged.

### Manually created folders

Directories created manually inside `Character Presets` are discovered
recursively and labeled **Imported**. Their preset files remain at their
original physical paths.

- Renaming an Imported folder in CET changes only its displayed virtual name.
- Moving one of its presets changes only its catalog assignment, not its file
  location.
- Deleting an Imported folder through CET permanently deletes the presets
  assigned to it, but leaves the manually created directory and unrelated files
  in place.
- Directory discovery stops if an entry cannot be verified or nesting exceeds
  12 levels.
- Linked folders and junctions are not supported.

## Compatibility

### ✅ CC and CCXL character option mods

**Supported.** Character Preset Manager saves and loads custom options when they
appear in Cyberpunk's normal character customization system. Repeated and linked
options, including heterochromia, are supported.

Keep the same character option mods installed and in the same load order when
creating and loading a preset. If the setup changes, fix the appearance and save
the preset again.

### ✅ Custom character creators and customization fixes

**Supported when they use the vanilla customization system.** Character Preset
Manager does not modify meshes, rigs, archives, or another mod's assets.

### ❌ Appearance Change Unlocker (ACU)

**Hard incompatible.** Do not run ACU and Character Preset Manager together.
Remove ACU and fully restart Cyberpunk before using Character Preset Manager.

Automatic ACU checks were removed because they could still report ACU after it
had been uninstalled. Make sure ACU is removed before using this mod.

### ✅ ACU preset files

**Import supported.** Supported ACU-format `.preset` files can be imported after
ACU itself has been removed.

Copy the file into:

```text
bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Character Presets
```

Close and reopen the CET window after copying the file. Imported ACU presets
work like normal presets and can be renamed, copied, saved again, or deleted.

### ❌ Character Customization Anywhere

**Hard incompatible.** [Character Customization Anywhere](https://www.nexusmods.com/cyberpunk2077/mods/3930)
changes the same mirrors and character customization screens used by Character
Preset Manager. Remove it and fully restart Cyberpunk before using this mod.

Character Preset Manager does not automatically check whether Character
Customization Anywhere is installed.

### ✅ Photo Mode and Appearance Menu Mod

**Compatible, with a usage limitation.** Photo Mode and Appearance Menu Mod may
remain installed. Character Preset Manager simply cannot save or load presets
from inside their interfaces.

Use the **Full Appearance Editor**, a mirror, a ripperdoc customization screen,
or the new-game editor instead. This is a limitation on where Character Preset
Manager can be used, not an incompatibility.

### ⚠️ Known game issue: loading screen after customization

Cyberpunk may sometimes remain on a loading screen after a character editor
closes. This can happen even without Character Preset Manager, especially while
clothing or wardrobe outfits are active. Equipment-EX and detailed outfits may
make the issue more likely.

If this happens, unequip all clothing and select **No Outfit** before opening the
editor. Put your items back on afterward.

The Load section may show an optional yellow clothing notice. You can ignore it
and load normally. The notice does not mean the mod is broken. It is hidden in
the new-game editor because that screen may contain hidden starter equipment.

## Sharing and importing presets

Preset location:

```text
bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Character Presets
```

- **Sharing:** Upload the individual `.preset` file.
- **Installing:** Place a downloaded `.preset` file in this directory or any
  directory inside it.
- **Refreshing:** Close and reopen the CET window after changing preset files
  outside the game.
- **Virtual folder assignments:** Folder organization is local catalog data and
  is not stored inside a shared `.preset` file.
- **Import safety:** Unsafe or unusually large preset files are ignored. A preset
  is limited to 1 MB, 8,192 lines, 4,096 valid options, 256 bytes per option key,
  and option indexes within the game's unsigned 32-bit range.

## Activity log

Select **Debug** in the mod window to view or copy the activity log.

Log location:

```text
bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Character Preset Manager (CET) Activity.log
```

Each full game launch starts a new log. The previous log is saved with a date
and time, and the 10 newest archived logs are kept automatically.

The log records startup information, preset operations, loading results,
failures, inactive options, and unavailable saved options.

## Frequently asked questions

<details>
<summary><strong>Show FAQ</strong></summary>

### Can I import ACU presets?

Yes. Remove ACU, copy the `.preset` file into the `Character Presets` folder,
then reopen CET.

### Can ACU remain installed?

No. ACU is incompatible with Character Preset Manager. Remove it and fully
restart Cyberpunk.

### Is Character Customization Anywhere compatible?

No. It changes the same mirrors and customization screens used by Character
Preset Manager.

### Does this work with Photo Mode or Appearance Menu Mod?

Yes, they may remain installed. Character Preset Manager cannot save or load
presets from inside their interfaces. Use the Full Appearance Editor, a mirror,
a ripperdoc, or the new-game editor instead.

### Why does the game sometimes stay on a loading screen after customization?

This is a Cyberpunk issue that can happen after character customization,
especially while clothing or wardrobe outfits are active. Unequip your clothing
and select **No Outfit** before opening the editor, then put everything back on
afterward.

### Is the character preset shown in the screenshots included?

No. The author's personal character preset is not included or planned for
release. The screenshots showcase Character Preset Manager itself.

</details>

## Upgrading from version 1.0.x

<details>
<summary><strong>Show upgrade instructions</strong></summary>

Do not install version 2.0.8 directly over a 1.0.x installation.

1. Back up your `.preset` files somewhere outside the mod folder.
2. Delete `mods/Preset Manager (CET)`.
3. Install version 2.0.8 normally.
4. Move your presets into
   `mods/Character Preset Manager (CET)/Character Presets`.
5. Launch the game and open CET.

Do not leave both the old and new mod folders installed.

</details>

## Character Preset Manager vs. ACU

<details>
<summary><strong>Show comparison</strong></summary>

| Area | Character Preset Manager | ACU |
| --- | --- | --- |
| Runtime | Runs through Cyber Engine Tweaks with no additional runtime dependency beyond CET. | Uses a separate implementation. |
| Character editor | Opens the full vanilla appearance editor during normal gameplay through CET or an optional input. | Uses its own approach to expanded customization. |
| Apartment mirrors | Expands apartment mirrors to show the full character-creator option set. | Uses its own customization system. |
| Preset organization | Includes unlimited virtual folders, nested folders, moving, copying, renaming, deletion, and shareable preset files. | Uses its own preset management system. |
| Preset loading | Waits for Cyberpunk's editor rebuilds and continues automatically. | Uses its own preset-loading implementation. |
| Missing options | Stops instead of guessing when a saved option can no longer be matched safely. | Uses its own matching and loading behavior. |
| Troubleshooting | Includes an in-game Debug view and detailed activity logs. | Uses its own interface and diagnostics. |
| ACU preset migration | Imports supported ACU-format `.preset` files after ACU has been removed. | Not applicable. |

Do not install or run ACU and Character Preset Manager together. ACU must be
removed and Cyberpunk must be fully restarted before using Character Preset
Manager.

This comparison explains differences between the approaches. It does not claim
that both mods provide the same feature set.

</details>

## Version 2.0.8 highlights

- Keeps the frame update dormant while the window and background actions are
  inactive, and uses character-editor open/close events instead of polling the
  full customization system four times per second.
- Caches unchanged preset/folder lists, Debug log formatting, CET bindings, and
  window geometry, plus the clothing check for each editor opening; automatic
  loading also reuses saved lookup data and performs one editor query per pass.
- Shows a small gold-and-white CET HUD notice whenever a character-customization
  screen opens and keeps it visible until CET is opened, so
  modpack users know to press their assigned CET Overlay key and open Character
  Preset Manager.
- Measures and positions each popup once, then reuses that cached layout while
  it remains visible instead of repeating the layout work every frame.
- Reuses its constant text and window flags and skips manager drawing entirely
  while CET or the manager window is closed.
- Sizes the centered discovery reminder to its text instead of stretching it
  into a wide banner.
- Uses CET's native font size for crisp notification text and color.
- Keeps a compact notification toggle beside Debug and Help without an
  additional text box. All three controls share one right-aligned row. Select
  **Ignore Notification** to suppress future popups or **Enable Notification**
  to restore them; the choice persists across restarts.
- Covers vanilla creation, mirrors, ripperdocs, and the full appearance editor
  launched by Character Preset Manager.
- Keeps the full-editor button and assigned input usable after leaving any
  customization screen by clearing stale editor-controller state on close.
- Prevents save and load validation from drifting apart by routing every preset
  option index through one native unsigned 32-bit contract.
- Verifies the previously failing `65,536` boundary and the game's unsigned
  no-selection value when the mod starts.
- Replaces the generic safe-limit failure with the exact option, value, and
  violated limit in Debug and a cause-specific message in the Create panel.

## Version 2.0.7 highlights

- Restores preset saving for CCXL and other custom options that expose the
  game's unsigned no-selection index.
- Uses the same native unsigned-index validation when saving and loading so
  shared custom presets are not rejected by incomplete CCXL choice metadata.
- Identifies the exact option if future customization data cannot be saved.

## Version 2.0.6 highlights

- Replaced the old 16 packaged folder slots with unlimited virtual folders.
- Added nested virtual-folder support and improved preset organization.
- Added recursive discovery for manually created directories, shown as
  **Imported**.
- Added Help display for the editor input and window-toggle hotkey bindings.
- Clarified that Photo Mode and Appearance Menu Mod may remain installed.
- Rejects invalid or unusually large imported preset files before loading.
- Stops missing CCXL options from being guessed by nearby position.
- Preserves the previous preset list when a folder scan cannot finish safely.
- Improves editor safety when required hooks or editor setup are unavailable.
- Includes additional folder, file, naming, loading, and stability improvements.

See [CHANGELOG.md](CHANGELOG.md) for the complete version history.

## Links

- [Download Character Preset Manager on Nexus Mods](https://www.nexusmods.com/cyberpunk2077/mods/31886)
- [GitHub source code](https://github.com/DKLYNTLY/Character-Preset-Manager-CET-)
- [Complete changelog](CHANGELOG.md)

## Credits

Character Preset Manager (CET) by dklyntly.
