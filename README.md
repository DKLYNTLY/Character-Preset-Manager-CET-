<h1 align="center">Character Preset Manager (CET)</h1>

<p align="center"><em>Save, load, organize, and share complete Cyberpunk 2077 character appearances directly through CET.</em></p>

<p align="center">
  <strong><a href="https://www.nexusmods.com/cyberpunk2077/mods/31886">Download on Nexus Mods</a></strong>
  ·
  <a href="https://discord.com/invite/mUGHmQxHG8">Discord and support</a>
  ·
  <a href="CHANGELOG.md">Complete changelog</a>
</p>

<p align="center"><strong>Current version: 3.0.0</strong></p>

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
- **Optional preset details** — Add notes and tags through backward-compatible
  metadata.
- **Recoverable Trash** — Move presets, folder groups, or multi-selections to
  Trash with confirmation.
- **ACU preset import** — Import supported ACU-format presets without running ACU.
- **Easy sharing** — Share appearances as individual `.preset` files.
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

The window starts near the right side of the screen. CET remembers where you
move it.

### Optional hotkeys

1. Open CET and select **Bindings**.
2. Find **Character Preset Manager (CET)**.
3. Assign **Open Full Appearance Editor**.
4. Optionally assign **Toggle Character Preset Manager (CET)**.
5. Close the CET overlay before using the editor input during gameplay.

The Help panel displays the assigned keys when CET can provide them. Otherwise,
it falls back to detecting whether the input was used during the current session.

### Upgrading from version 1.0.x

Do not install version 3.0.0 directly over a 1.0.x installation.

1. Back up your `.preset` files outside the mod folder.
2. Delete `mods/Preset Manager (CET)`.
3. Install version 3.0.0 normally.
4. Move your presets into
   `mods/Character Preset Manager (CET)/Character Presets`.
5. Launch the game and open CET.

Do not leave the old and new mod folders installed together.

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
2. Select a preset under **Load**.
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
  it to switch the reminder on or off.
- **Preset Sort:** Sort alphabetically by name or by newest modified metadata.
- **Reload Config from Disk:** Applies manual config edits without restarting.

The same options are stored in:

```text
Character Preset Manager (CET) Config.txt
```

Supported values:

```text
discoveryReminder=true
presetSort=name
```

`presetSort` accepts `name` or `modified`. The config is created automatically
and is not packaged over an existing preference. Earlier `Discovery Notice
Ignored.txt` preferences migrate automatically. CET's own Settings tab does not
discover individual mod settings, so no additional settings-menu dependency is
required.

</details>

<details>
<summary><strong>📁 Folders, preset management, Trash, and sharing</strong></summary>

### Organizing presets

- **Folder controls** — Folder rows use clear **Open** and **Close** text that
  works with every CET font.
- **Root presets** — Presets without a folder appear below the folder list.
- **Save and move destinations** — Select a folder or **All Presets** before
  saving or moving a preset.
- **Nested folders** — Create a folder while another folder is selected.
- **Automatic copy names** — Copies sit beside the original and use names such
  as `Copy` and `Copy 2`.
- **Complete folder copies** — Duplicating a virtual folder includes its presets
  and nested folders.
- **Safe folder removal** — Removing a folder keeps every preset and moves its
  organization to the parent.
- **Shareable renames** — Renaming a preset also renames its physical `.preset`
  file.
- **Preset details** — Manage remains compact until a preset is selected, then
  provides Rename, Duplicate, notes, and tags.

### Virtual and imported folders

Folders created through CET are virtual. They organize presets without creating
or renaming directories in File Explorer. Their organization is stored in:

```text
Character Preset Manager (CET) Folders.txt
```

There is no fixed virtual-folder limit. Untouched legacy folder-slot directories
are removed during upgrade; a slot containing an unrecognized item is left
unchanged.

Directories created manually inside `Character Presets` are discovered
recursively and labeled **Imported**. Their files remain in their original
physical locations.

- Renaming an Imported folder changes only its displayed virtual name.
- Moving its presets changes only their catalog assignments.
- Removing it through CET preserves its presets, directory, and unrelated files.
- Discovery stops when an entry cannot be verified or nesting exceeds 12 levels.
- Linked folders and junctions are not supported.

### Trash and recovery

- Moving a selected preset to Trash keeps it recoverable.
- **More Trash Options** can move a selected folder or a filtered
  multi-selection to Trash after confirmation.
- **Select All Visible** and **Clear Selection** help manage filtered results.
- Folder Trash removes the virtual tree but leaves manual directories in place.
- **Restore Folder** rebuilds presets, imported identity, and empty nested
  folders together. Individual presets may also be restored separately.
- Only **Empty Trash Permanently** destroys trashed preset files.
- Interrupted Trash, restore, bulk-move, and physical-rename operations are
  resolved through the recovery journal at startup.

### Sharing and importing

Preset folder:

```text
bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Character Presets
```

- **Share:** Upload the individual `.preset` file.
- **Install:** Place a downloaded preset in this folder or a directory inside it.
- **Refresh:** Select **Refresh** under Load after changing files outside CET.
- **Virtual organization:** Folder assignments are local catalog data and are
  not embedded in a shared preset.
- **Metadata:** Format-5 files may include source, created, modified, notes, and
  tags while remaining backward compatible.
- **Safety limits:** Imported presets are limited to 1 MB, 8,192 lines, 4,096
  valid options, 256 bytes per option key, and unsigned 32-bit option indexes.

</details>

<details>
<summary><strong>🧩 Compatibility and known issues</strong></summary>

### ✅ CC and CCXL character-option mods

**Status: Supported**

Custom options are saved when they appear in Cyberpunk's normal
customization system. Repeated and linked options, including heterochromia, are
supported.

Keep the same option mods and load order when saving and loading. If the setup
changes, fix the appearance and save the preset again.

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

**ACU preset files — Import supported.** Supported `.preset` files can still be
imported after ACU itself has been removed. Copy them into the preset folder and
select **Refresh** under Load.

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
| ACU migration | Imports supported ACU presets after ACU is removed. | Not applicable. |

This comparison explains the different approaches. Do not install or run both
mods together.

</details>

<details>
<summary><strong>🛠 Troubleshooting, activity log, and FAQ</strong></summary>

### Activity log

Open **Help > Debug and Diagnostics**, then select **Open Debug Log** to view or
copy the log.

```text
bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Character Preset Manager (CET) Activity.log
```

Each full game launch starts a new log. The previous log is archived with its
date and time, and the 10 newest archives are kept. The log records startup,
preset operations, loading results, failures, inactive options, and unavailable
saved options. Developer hook counters remain under **Advanced diagnostics**.

### Can I import ACU presets?

Yes. Remove ACU, copy the `.preset` file into `Character Presets`, then select
**Refresh** under Load.

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
<summary><strong>🆕 Version 3.0.0 highlights</strong></summary>

- Adds search, Refresh, folder counts, compact folder paths, and clear Open/Close
  folder controls.
- Shows each selected preset's folder, option count, source, format, modification
  time, notes, tags, and compatibility summary.
- Fixes the save-destination chooser, keeps its current location visible, and
  presents it as a smaller nested control.
- Disables unavailable actions with a short reason, standardizes primary button
  sizes, and prevents the first-frame width shift when the window opens.
- Adds Cancel Loading while automatic loading is active.
- Groups deletion, bulk actions, restoration, and permanent cleanup under
  **Trash & Recovery**, with multi-item actions behind a smaller nested control.
- Adds safe transaction recovery, complete folder-tree Trash records, and
  one-action folder restoration.
- Adds optional format-5 notes and tags and renames the physical file with its
  preset.
- Moves reminder and sorting preferences into Settings and a human-editable
  config.
- Automatically disables the discovery reminder after a successful save or
  complete load.
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
  also supports importing compatible ACU preset files.
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
