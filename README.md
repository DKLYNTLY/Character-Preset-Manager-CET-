<h1 align="center">Character Preset Manager (CET)</h1>

<p align="center"><em>Save, load, organize, and share complete Cyberpunk 2077 character appearances directly through CET.</em></p>

<p align="center">
  <strong><a href="https://www.nexusmods.com/cyberpunk2077/mods/31886">Download on Nexus Mods</a></strong>
  ·
  <a href="https://discord.com/invite/mUGHmQxHG8">Discord and support</a>
  ·
  <a href="CHANGELOG.md">Complete changelog</a>
</p>

<p align="center"><strong>Current version: 3.0.3</strong></p>

> [!IMPORTANT]
> Remove **Appearance Change Unlocker (ACU)** and **Character Customization
> Anywhere** before using Character Preset Manager. They change the same
> customization screens and are not compatible. Fully restart Cyberpunk after
> removing either mod.

<details open>
<summary><strong>✨ Features at a glance</strong></summary>

- **Complete appearance presets** — Save and load full appearances, including
  exposed CC and CCXL options.
- **Full editor anywhere** — Open the vanilla appearance editor during normal
  gameplay.
- **Full apartment mirrors** — Use the complete character-creator option set
  through ordinary apartment mirrors.
- **One-click loading** — Select a preset once while the mod safely waits for
  editor rebuilds.
- **Cosmetic cleanup** — Clear exposed cosmetic choices that are absent from the
  incoming preset.
- **Search and compatibility summary** — Find presets, refresh imported files,
  and review the current editor match before loading.
- **Unlimited folder organization** — Create nested virtual folders and detect
  manually created directories.
- **Preset and folder duplication** — Copy one preset or a complete virtual
  folder tree.
- **Optional preset details** — Add notes and tags through the current format-7
  preset metadata.
- **Recoverable Trash** — Move presets, folder groups, or multi-selections to
  Trash with confirmation.
- **Easy sharing** — Share one appearance as a `.preset` file or a complete
  virtual folder tree as one `.cpmfolder` bundle.
- **Activity log** — Review actions, warnings, and errors inside CET.

</details>

<details>
<summary><strong>📦 Installation, requirements, and hotkeys</strong></summary>

### Requirements

- [Cyber Engine Tweaks 1.37.1 or newer](https://www.nexusmods.com/cyberpunk2077/mods/107)
- No additional runtime dependency beyond CET

### Installation

1. [Download the latest release from Nexus Mods](https://www.nexusmods.com/cyberpunk2077/mods/31886).
2. Extract the release archive into your Cyberpunk 2077 game folder.
3. Launch the game and open the Cyber Engine Tweaks overlay.
4. Select **Character Preset Manager (CET)**.

The window starts near the right side of the screen. CET remembers its position
and size after you move or resize it.

### Optional hotkeys

1. Open CET and select **Bindings**.
2. Find **Character Preset Manager (CET)**.
3. Assign **Open Full Appearance Editor**.
4. Optionally assign **Toggle Character Preset Manager (CET)**.
5. Close the CET overlay before using the editor input during gameplay.

The Help panel displays the assigned keys when CET can provide them. Otherwise,
it falls back to detecting whether the input was used during the current session.

### Current preset system

New presets use format 7. Existing older and compatible ACU-format `.preset`
files remain readable so established preset libraries are not lost, but all new
presets and shared folders use the current system. Do not leave an older mod
folder installed beside this one.

</details>

<details open>
<summary><strong>💾 Saving, loading, and settings</strong></summary>

### Saving a preset

1. Open the **Full Appearance Editor**, a mirror, a ripperdoc customization
   screen, or the new-game editor.
2. Open Character Preset Manager in CET.
3. Under **Save Preset**, open **Choose Save Destination**.
4. Select a folder or **All Presets**, then confirm the displayed location.
5. Enter a name and select **Save New Preset**.

If the name already exists, confirm the overwrite only if you want to replace
that preset.

### Loading a preset

1. Open a supported character customization screen.
2. Select a preset under **Load Preset**.
3. Review its folder, option count, source, metadata, and compatibility summary.
4. Select **Load Selected Preset** once.
5. Wait for the green **Preset fully applied** message.

Cyberpunk may rebuild the editor several times. Character Preset Manager waits
and continues automatically. Select **Cancel Loading** if you need to stop.

If the same options cannot be found after three checks, loading stops instead
of guessing. This usually means character-option mods or their load order have
changed. Fix the appearance and save the preset again.

### Settings and config

Settings includes:

- **Customization Reminder: Enabled/Disabled:** Shows the current state. Select
  it to switch the reminder on or off. It starts enabled on a clean install and
  stays enabled until you turn it off in Settings.
- **Preset Sort:** Sort alphabetically by name or by newest modified metadata.
- **Reload Config from Disk:** Applies manual config edits without restarting.

The same options are stored in:

```text
Data/Config/Config.txt
```

Supported values:

```text
discoveryReminder=true
presetSort=name
```

`presetSort` accepts `name` or `modified`. The config is created automatically
and is not packaged over an existing preference. CET's own Settings tab does
not discover individual mod settings, so no additional settings-menu dependency
is required.

</details>

<details>
<summary><strong>📁 Folders, preset management, Trash, and sharing</strong></summary>

### Organizing presets

- **Folder controls** — Folder rows use CET's native drawn arrow, so the open
  and closed indicator works with every font.
- **Root presets** — Presets without a folder appear below the folder list.
- **Save and move destinations** — Select a folder or **All Presets** before
  saving or moving a preset.
- **Nested folders** — Create a folder while another folder is selected.
- **Automatic copy names** — Copies sit beside the original and use names such
  as `Copy` and `Copy 2`.
- **Complete folder copies** — Duplicating a virtual folder includes its presets
  and nested folders.
- **Remove Folder, Keep Presets** — After confirmation, moves its presets and
  nested folders to the parent. For an Imported folder, recognized `.preset`
  files are safely relocated to the main preset folder first. Its physical
  directory is removed only when no unknown files remain.
- **Folder sharing** — Export a virtual folder and all of its nested presets as
  one `.cpmfolder` bundle. Complete import instructions are under **Sharing and
  importing** below.
- **Shareable renames** — Renaming a preset also renames its physical `.preset`
  file.
- **Preset editing** — **Rename & Copy** remains compact until a preset is
  selected. Rename and Duplicate stay visible, while the less-used tags and
  notes remain behind **Optional Preset Details**.

### Virtual and imported folders

Folders created through CET are virtual. They organize presets without creating
or renaming directories in File Explorer. Their organization is stored in:

```text
Data/Catalog/Virtual Folders.txt
```

There is no fixed virtual-folder limit.

Directories created manually inside `Character Presets` are discovered
recursively and labeled **Imported**. Their files remain in their original
physical locations until an operation explicitly needs to relocate them.

- Renaming an Imported folder changes only its displayed virtual name.
- Moving its presets changes only their catalog assignments.
- **Remove Folder, Keep Presets** moves recognized `.preset` files out of the
  selected Imported directory, keeps every preset, and removes only directories
  that are empty afterward. Unknown files and any directory containing them are
  always preserved.
- Discovery stops when an entry cannot be verified or nesting exceeds 12 levels.
- Linked folders and junctions are not supported.

### Deleting and restoring presets

- Moving a selected preset to Trash keeps it recoverable.
- A selected folder and all of its presets can be moved to Trash directly under
  **Folders**. **More Trash Options** handles filtered multi-selection.
- **Select All Visible** and **Clear Selection** help manage filtered results.
- Folder Trash removes the logical tree and keeps all presets recoverable.
  An imported physical directory is removed when it becomes empty; unknown
  content keeps the directory in place and is never deleted.
- **Restore Folder** rebuilds the complete logical folder tree, including empty
  nested virtual folders, and restores every preset in that Trash group.
  Restored files receive safe storage names in the main `Character Presets`
  directory; their original folder paths are restored virtually. Name conflicts
  receive a `Copy` name instead of overwriting an existing preset.
- Individual presets may also be restored separately.
- Only **Empty Trash Permanently** destroys trashed preset files.
- Interrupted Trash, restore, bulk-move, and physical-rename operations are
  resolved through the recovery journal at startup.

### Sharing individual presets

Preset folder:

```text
bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Character Presets
```

- **Share:** Upload the individual `.preset` file.
- **Install:** Place a downloaded preset in this folder or a directory inside it.
- **Refresh:** Select **Refresh** under **Load Preset** after changing files
  outside CET.
- **Virtual organization:** Folder assignments are local catalog data and are
  not embedded in an individual shared preset.
- **Format:** New presets use format 7, which stores source, timestamps, notes,
  tags, selector slots, and selected-choice identities. Existing older preset
  files remain readable.
- **Safety limits:** Imported presets are limited to 1 MB, 8,192 lines, 4,096
  valid options, 256 bytes per option key, and unsigned 32-bit option indexes.

### Sharing and importing complete folders

A `.cpmfolder` file contains one selected virtual folder, all nested virtual
folders, and every preset inside that tree. Notes, tags, and other supported
preset metadata travel with the preset files in the bundle.

#### Export a folder

1. Open **Folders** and select the folder you want to share.
2. Select **Export Folder for Sharing**.
3. Find the new `.cpmfolder` file in the same `Character Presets` folder used
   for individual preset imports:

   ```text
   bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Character Presets
   ```

4. Share that single `.cpmfolder` file.

An empty folder cannot be exported. One bundle may contain up to 512 presets and
may not exceed 32 MB. To remove an export after sharing it, select **All Presets
(root)**, open **Folder Bundle Files**, select the exact `.cpmfolder` file, and
select **Move Selected Bundle to Trash**. This moves only the
bundle file; its source folder and presets remain available in Character Preset
Manager. Restore it under **Delete & Restore**, or remove it permanently with
**Empty Trash Permanently**.

#### Import a folder

1. Put each downloaded `.cpmfolder` file in `Character Presets`, beside current
   `.preset` files:

   ```text
   bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Character Presets
   ```

2. Open Character Preset Manager and expand **Folders**.
3. Select **All Presets (root)**. The import button is shown only at the root.
4. Select **Import Folder Bundles**. Every `.cpmfolder` file currently in the
   `Character Presets` folder is processed.

A successful import recreates the complete folder tree as virtual folders and
leaves its source `.cpmfolder` file untouched. Character Preset Manager records
the bundle filename and content fingerprint in
`Data/Catalog/Imported Bundles.txt`; an unchanged bundle is skipped on later
imports, while a changed bundle using the same filename can be imported again.
If that folder name already exists, the imported folder receives a safe `Copy`
name. A failed bundle is not recorded, so the error can be corrected and the
import tried again. Bundles are imported only from `Character Presets`.
After a successful import, the same **Folder Bundle Files** menu can move the
source bundle to Trash so it no longer appears in later import scans. It can be
restored without deleting the imported virtual folder or any imported preset.

### Runtime data layout

The install root contains only `init.lua`, `Character Presets`, and `Data` from
this mod. Virtual folders never create physical directories. CPM-owned files
are grouped under:

```text
Data/
|-- Config/
|-- Catalog/
|-- Recovery/
|   `-- Trash/
`-- Logs/
    `-- Archive/
```

Version 3.0.3 does not move loose files created by older releases. For the
clean layout, remove the old mod installation before installing 3.0.3, while
backing up and restoring only the presets or bundles you want to keep from
`Character Presets`.

</details>

<details>
<summary><strong>🧩 Compatibility and known issues</strong></summary>

### ✅ CC and CCXL character-option mods

**Status: Supported**

Custom options are saved when they appear in Cyberpunk's normal
customization system. Repeated and linked options, including heterochromia, are
supported.

Format-7 presets retain each option's LocKey, UI slot, selected definition or
choice name when exposed, and numeric index. LocKey remains the primary selector
identity. When added CCXL content shifts a choice list, CPM can locate the saved
choice at its new index. **Force Full Load** may match a renamed dependent
selector, such as a hairstyle-specific color selector, through its saved UI
slot. Always verify the result after changing character-option mods.

Only stable names are stored as choice identities. Temporary runtime memory
addresses are ignored and use the saved numeric index instead. Choice matching
is spread across normal loading passes and cached, while an option that a mod
immediately resets is deferred so it cannot block every option after it.

Older presets contain only LocKeys and numeric indexes. If adding hairs shifts
the Hairstyle list, an old index may select a different hair and cannot reveal
which hair was originally intended. Correct the hair and color manually once,
then overwrite or re-save the preset in format 7 before changing the CCXL setup
again.

### ✅ Custom character creators and customization fixes

**Status: Supported when using the vanilla customization system**

Character Preset Manager does not modify meshes, rigs, archives, or another
mod's assets.

One compatible example is
[EKT Custom Character Creator - FEMV ONLY](https://www.nexusmods.com/cyberpunk2077/mods/12807).
Keep the same EKT version, body and eye variants, other option mods, and load
order for reliable preset results.

### ❌ Appearance Change Unlocker (ACU)

**Status: Hard incompatible**

Remove ACU and fully restart Cyberpunk before using this mod. Automatic checks
were removed because they could continue reporting ACU after it had been
uninstalled.

Compatible ACU preset files remain readable after ACU itself is removed. New
presets should be created and shared with Character Preset Manager's current
system.

### ❌ Character Customization Anywhere

**Status: Hard incompatible**

[Character Customization Anywhere](https://www.nexusmods.com/cyberpunk2077/mods/3930)
changes the same mirrors and character customization screens. Remove it and
fully restart Cyberpunk. Character Preset Manager does not check for it
automatically.

### ✅ Photo Mode and Appearance Menu Mod

**Status: Compatible with a usage limitation**

Both may remain installed, but Character Preset Manager cannot save or load from
inside their interfaces. Use the Full Appearance Editor, a mirror, a ripperdoc,
or the new-game editor instead.

### ⚠️ Loading screen after customization

**Status: Cyberpunk game issue**

Cyberpunk may sometimes remain on a loading screen after any character editor
closes. This can happen without Character Preset Manager, especially while
clothing or wardrobe outfits are active. Equipment-EX and detailed outfits may
make it more likely.

If this happens, unequip all clothing and select **No Outfit** before opening the
editor. Put everything back on afterward. The optional yellow clothing notice
does not mean the mod is broken and may be ignored.

### Character Preset Manager compared with ACU

| Area | Character Preset Manager | ACU |
| --- | --- | --- |
| Runtime | Uses CET with no additional runtime dependency. | Uses a separate implementation. |
| Character editor | Opens the full vanilla editor through CET or an optional input. | Uses its own expanded-customization approach. |
| Mirrors | Exposes the full creator through ordinary apartment mirrors. | Uses its own customization system. |
| Organization | Includes unlimited nested virtual folders, copying, moving, Trash, and shareable files. | Uses its own preset-management system. |
| Loading | Waits for editor rebuilds and continues automatically. | Uses its own loading implementation. |
| Missing options | Stops instead of guessing when a safe match is unavailable. | Uses its own matching behavior. |
| Troubleshooting | Includes an in-game Debug view and detailed activity logs. | Uses its own interface and diagnostics. |

This comparison explains the different approaches. Do not install or run both
mods together.

</details>

<details>
<summary><strong>🛠 Troubleshooting, activity log, and FAQ</strong></summary>

### Activity log

Open **Help > Debug and Diagnostics**, then select **Open Debug Log** to view or
copy the log.

```text
bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Data/Logs/Activity.log
```

Each full game launch starts a new log. The previous log is archived with its
date and time, and the 10 newest archives are kept. The log records startup,
preset operations, loading results, failures, inactive options, and unavailable
saved options. Developer hook counters remain under **Advanced diagnostics**.

### Can I import ACU or older presets?

Yes. Compatible files remain readable to protect existing preset libraries. New
presets use Character Preset Manager's current format-7 system.

### Can ACU remain installed?

No. Remove it and fully restart Cyberpunk.

### Is Character Customization Anywhere compatible?

No. It changes the same mirrors and customization screens.

### Do Photo Mode and Appearance Menu Mod work?

They may remain installed, but presets cannot be saved or loaded from inside
their interfaces. Use a supported character editor instead.

### Why can the game stay on a loading screen after customization?

This is a Cyberpunk issue that is more likely while clothing or wardrobe outfits
are active. Unequip clothing and select **No Outfit** before opening the editor,
then restore everything afterward.

### Is the character preset shown in screenshots included?

No. My personal character preset is not included or planned for release. The
screenshots demonstrate Character Preset Manager itself.

</details>

<details>
<summary><strong>🆕 Version 3.0.3 highlights</strong></summary>

- Saves stable selector-slot and selected-choice identities in format-7 presets
  so newly inserted CCXL choices do not silently redirect a saved hairstyle to
  the same outdated numeric index.
- Adds an opt-in **Force Full Load** fallback for renamed dependent selectors,
  with explicit warnings for legacy index-only presets.
- Uses ImGui's usable work area for first-open placement and removes the
  redundant already-in-destination message immediately after a successful move.

- Groups CPM-owned configuration, catalog, recovery, Trash, and log data under
  `Data` so the mod root and `Character Presets` stay focused.
- Keeps imported `.cpmfolder` files unchanged and skips exact previously
  imported bundles through a filename-and-fingerprint registry.
- Keeps virtual folders entirely catalog-based without creating physical
  directories.

- Displays complete slash-qualified preset paths and lets CET retain the chosen
  window size between game sessions.
- Adds search, Refresh, folder counts, and native folder controls.
- Shows each selected preset's folder, option count, source, format, modification
  time, notes, tags, and compatibility summary.
- Fixes the save-destination chooser, keeps its current location visible, and
  presents it as a smaller nested control.
- Disables unavailable actions with a short reason, standardizes primary button
  sizes, and prevents the first-frame width shift when the window opens.
- Adds Cancel Loading while automatic loading is active.
- Places selected-folder Trash directly under **Folders**, while single-preset
  Trash, filtered multi-selection, restoration, and permanent cleanup remain
  under **Delete & Restore**.
- Adds safe transaction recovery, complete folder-tree Trash records, and
  one-action folder restoration.
- Adds **Remove Folder, Keep Presets** with safe Imported-directory cleanup and
  complete `.cpmfolder` export/import for sharing virtual folder trees.
- Adds optional format-7 metadata and renames the physical file with its
  preset.
- Moves reminder and sorting preferences into Settings and a human-editable
  config.
- Keeps the discovery reminder enabled until it is turned off in Settings.
- Moves Debug into Help and developer counters under Advanced diagnostics.
- Improves caching, validation, failure reporting, and safe catalog writes.

See [CHANGELOG.md](CHANGELOG.md) for the complete history of every release.

</details>

<details>
<summary><strong>🤝 Credits, AI disclosure, and links</strong></summary>

### AI disclosure

I used AI only to help plan and improve the CET menu's layout, style, and overall
look. I made the final design choices and heavily changed the AI-assisted work
to fit the mod. I manually tested preset saving, loading, folders, recovery, and
gameplay features.

### Credits

- **Character Preset Manager (CET):** Created and maintained by **dklyntly**.
- **[ACU - Character Preset Manager](https://www.nexusmods.com/cyberpunk2077/mods/3850):**
  Created by **PotatoOfDoom**. ACU gave me the original idea for this project. I
  liked what it was trying to do, but I was disappointed by the bugs and errors
  I experienced, so I decided to make my own version. Character Preset Manager
  can read compatible ACU preset files so existing libraries are not lost, while
  new presets use its own current format and workflow.
- **[Character Customization Anywhere](https://www.nexusmods.com/cyberpunk2077/mods/3930):**
  Created by **keanuWheeze**. Its idea of opening character customization during
  normal gameplay inspired me to include the Full Appearance Editor.
- **[Cyber Engine Tweaks](https://www.nexusmods.com/cyberpunk2077/mods/107):**
  Created by **yamashi** and maintained with its contributors. CET provides the
  scripting and interface framework used by this mod.
- **CD Projekt Red:** For Cyberpunk 2077 and its character customization system.
- **Cyberpunk 2077 modding community:** For testing, technical research,
  compatibility knowledge, and feedback.

The credited inspiration mods are not bundled dependencies. ACU and Character
Customization Anywhere should not be installed alongside Character Preset
Manager.

### Links

- [Download on Nexus Mods](https://www.nexusmods.com/cyberpunk2077/mods/31886)
- [GitHub source code](https://github.com/DKLYNTLY/Character-Preset-Manager-CET-)
- [Discord community and support](https://discord.com/invite/mUGHmQxHG8)
- [Complete changelog](CHANGELOG.md)
- [MIT license](LICENSE)

</details>
