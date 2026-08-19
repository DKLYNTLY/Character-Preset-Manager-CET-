<h1 align="center">Character Preset Manager (CET)</h1>

<p align="center"><em>Save, load, organize, and share complete Cyberpunk 2077 character appearances through CET.</em></p>

<p align="center">
  <strong><a href="https://www.nexusmods.com/cyberpunk2077/mods/31886">Download on Nexus Mods</a></strong>
  ·
  <a href="https://discord.com/invite/mUGHmQxHG8">Discord and support</a>
  ·
  <a href="CHANGELOG.md">Full changelog</a>
</p>

<p align="center"><strong>Current version: 3.0.5</strong></p>

<p align="center">
  <img src="images/Character%20Preset%20Manager%20%28CET%29%20v3.0.3.png" alt="Character Preset Manager feature overview" width="900">
</p>

## Interface and feature previews

<details open>
<summary><strong>Character Preset Manager interface</strong></summary>

![Character Preset Manager's CET interface for saving, loading, and organizing presets](images/UI%20v3.0.4.gif)

The main CET interface keeps saving, loading, folders, sharing, Trash, settings,
and help in one window.

</details>

<details open>
<summary><strong>Full apartment mirror options</strong></summary>

![The full character editor opened from an apartment mirror](images/Mirror.gif)

Apartment mirrors include the full set of character-creation options, rather
than the smaller selection normally available during play.

</details>

## Features

- **Complete appearance presets** — Save and load complete character appearances, including visible CC and CCXL options.
- **Full Appearance Editor anywhere** — Open the full game character editor during normal play from CET or an optional key.
- **Full apartment mirror options** — Use the complete character-creation option set through normal apartment mirrors.
- **One-click loading** — Select a preset once while the mod waits for Cyberpunk to refresh the editor.
- **Cosmetic cleanup** — After applying a preset, clear visible appearance options that were not part of it.
- **Search and compatibility checks** — Find presets by name, folder, or tag and see whether the current editor has the options they need.
- **Unlimited nested folders** — Organize presets in folders and folders inside folders, with no set limit.
- **Preset and folder copies** — Copy one preset or a complete folder group.
- **Readable format-8 files** — See the CPM marker, preset name, CET library folder, dates, notes, tags, favorite status, and appearance choices in plain text.
- **Notes and tags** — Store optional details with current presets.
- **Favorites and previous-appearance recovery** — Pin useful presets and undo the newest preset load.
- **Complete-library backups** — Export or safely import every preset, the CET folder layout, and settings in one `.cpmbackup` file.
- **Recoverable Trash** — Move presets and folders to Trash and restore them later.
- **Preset sharing** — Share one `.preset` file or a complete folder as a `.cpmfolder` file, and inspect a shared folder before installing it.
- **Activity log** — Review actions, loading results, warnings, and errors inside CET.

### What changed in 3.0.5

- Complete-library backup export works correctly when checking the first preset.
- Current CPM preset files identify themselves with `# CPM Preset` and record
  `# Name:` and `# Library folder:` details for library recovery.
- A selected `.cpmfolder` file can be inspected before it is installed.
- Finished loading data, full preset contents, interface lists, and displayed
  Activity Log text are released when they are no longer needed.
- Favorites, complete-library backups, previous-appearance recovery, bulk
  preset actions, Help search, and clearer section controls are part of the
  main interface.

> [!IMPORTANT]
> Remove **Appearance Change Unlocker (ACU)** and **Character Customization
> Anywhere** before using this mod. They change the same character screens and
> cannot be used with Character Preset Manager. Restart the game after removing
> either mod.

<details>
<summary><strong>Requirements, installation, and optional keys</strong></summary>

### Requirements

- [Cyber Engine Tweaks 1.37.1 or newer](https://www.nexusmods.com/cyberpunk2077/mods/107)
- No other required mod or program

### Install the mod

1. [Download the latest release from Nexus Mods](https://www.nexusmods.com/cyberpunk2077/mods/31886).
2. Extract the downloaded archive into your Cyberpunk 2077 game folder.
3. Start the game and open the Cyber Engine Tweaks overlay.
4. Select **Character Preset Manager (CET)**.

The window first opens near the right side of the screen. CET remembers its position and size after you move or resize it.

### Set optional keys

1. Open CET and select **Bindings**.
2. Find **Character Preset Manager (CET)**.
3. Set a key for **Open Full Appearance Editor**.
4. You can also set a key for **Toggle Character Preset Manager (CET)**.
5. Close the CET overlay before using the editor key during play.

The Help panel shows the assigned keys when CET makes that information available. If CET cannot show a key, the panel reports whether you used that input during the current game session.

### Update from an older release

New presets use format 8. Its file layout is easier to read, identifies files
saved by CPM, and records the preset's name and CET library folder. It keeps the
same appearance information introduced with format 7. Older Character Preset
Manager presets and compatible ACU `.preset` files can still be loaded.

Existing preset files are not rewritten just because the mod finds them. Saving
over an older preset updates it to format 8. Saving its optional notes or tags
also updates that file. Keep a backup before replacing any preset you may still
want to use with an older mod version.

Do not keep an older copy of the mod beside the current one. Version 3.0.5 does not move loose files left by older releases. For a clean update:

1. Back up the `.preset`, `.cpmfolder`, and `.cpmbackup` files you want to keep
   from `Character Presets`.
2. Remove the old Character Preset Manager folder.
3. Install version 3.0.5.
4. Put your saved presets and bundles back in `Character Presets`.

</details>

<details open>
<summary><strong>Using Character Preset Manager</strong></summary>

### Save a preset

1. Open the **Full Appearance Editor**, a mirror, a ripperdoc character screen, or the new-game editor.
2. Open Character Preset Manager in CET.
3. Under **Save & Replace Presets**, open **Save Location**.
4. Choose a folder or **All Presets**.
5. Enter a name and select **Save New Preset**.

If that name already exists, confirm **Replace Existing Preset** only when you want to overwrite it.

### Load a preset

![A complete character preset loading in Cyberpunk 2077](images/Preset%20Loading.gif)

This example shows the complete loading process, including automatic editor
refreshes and the final appearance.

1. Open one of the supported character screens listed above.
2. Choose a preset under **Load & Restore Appearance**.
3. Check its folder, number of saved options, source, details, and compatibility summary.
4. Select **Load Selected Preset** once.
5. Wait for the final result. A green message means every saved option was
   confirmed. A yellow message names anything the game did not confirm.

**Restore Previous Appearance** is under **Load & Restore Appearance**. Before
each normal preset load, the mod quietly saves the active appearance. Open a
supported character screen and use this button to undo the newest preset load.

Cyberpunk may refresh the editor several times. The mod waits and continues on
its own. It applies the saved appearance before clearing any remaining options,
then checks the preset again. Select **Cancel Loading** if you need to stop.

The compatibility summary refreshes while the mod and character editor are open.
It updates after the editor changes without making you select a different preset
and switch back. Other selected-preset details update at the same time.

Automatic loading checks a pending change quickly, then leaves more time between
ordinary passes. It reuses the option list during the same update and avoids
rebuilding the full option-list fingerprint unless the list count changes or a
recent change may affect dependent options. If a change adds, removes, disables,
or rearranges an option, the mod waits longer for the editor to settle. A final
read-only check confirms any late changes before the summary. Saved-choice
matches are reused only after the current option still proves that they match.

Loading stops if the same options are still missing after three checks. The mod does not guess. Missing options usually mean that character-option mods, their versions, or their load order changed. Correct the appearance and save the preset again.

### What a preset saves

Format-8 presets store each visible option, its position in the editor, its selected choice when a stable name is available, and its number in the choice list. They can also store the source, date, notes, and tags.

This information helps the mod find a saved choice after CCXL adds items to a
list. If a hairstyle replaces a related option under a new name, a current
preset can match it automatically when its editor slot and unique saved choice
both agree. **Force Full Load** can try less certain editor-position matches.
Always check the result after changing option mods.

Force Full Load turns on automatically for older presets that need position-based
matching and turns off when you select a current preset. You can still change it
manually under **Load & Restore Appearance**.

When Force Full Load applies a renamed option from an older preset, post-load
cleanup protects that exact live match. The protection remains only while its
position, name, occurrence, slot, and applied number still agree. Cleanup cannot
silently reset a forced hair color and then report it as applied.

Older presets only know the option name and number. If new hairstyles shift the list, an older preset may choose the wrong hairstyle because it cannot know the original choice. Correct it once and save the preset again in the current format.

### Readable preset files

Format 8 replaces encoded lines such as `%20` and `%3A` with plain text. Each
option keeps its original `OptionKey:SavedNumber` line, followed by readable
details when they are available:

```text
# CPM Preset
# Format: 8
# Name: Neon Street V
# Source: Character Preset Manager (CET)
# Created: 2026-08-15 13:19:27
# Modified: 2026-08-15 13:19:27
# Notes:
# Tags:
# Favorite: No
# Library folder: Favorites/Female V

LocKey#9502141975964618858:50
# Editor slot: hairstyle
# Saved choice: options:51
```

The mod ignores normal comment lines when reading a preset. This keeps the file
easy to inspect without treating its headings as damaged data. **CPM Preset**
identifies a file saved by this mod. **Name** records the preset name, and
**Library folder** records its CET folder. If the saved folder list has no entry
for that preset, the mod can rebuild its name and folder from these lines. `/`
means **All Presets**.

The mod keeps these two values current when it saves, renames, duplicates,
moves, or imports a format-8 CPM preset. Older files are not rewritten merely
because they were found or loaded.

</details>

<details>
<summary><strong>Organizing presets and folders</strong></summary>

### Basic folder use

- Select a folder row under **Load & Restore Appearance** to open or close it.
- Presets without a folder appear under **All Presets**.
- Choose a folder or **All Presets** before saving or moving a preset.
- To make a folder inside another folder, select the parent folder first.
- Copies appear beside the original and use names such as `Copy` and `Copy 2`.
- Copying a folder also copies every preset and folder inside it.
- Renaming a preset also renames its `.preset` file.
- Notes, tags, and the file path are under **Rename & Copy Presets > Tags, Notes & File**.
- Search checks preset names, folder names, and tags. Tags also appear beside
  preset names in the list.
- **Copy File Path** inside those optional preset tools copies the selected preset's
  complete path from the Cyberpunk 2077 game folder.

Choose a preset under **Load & Restore Appearance**, then open **Favorites & Details**
and select **Add Selected Preset to Favorites**. The same button removes it from Favorites
later. Favorites remain in their original folders and also appear in a pinned
group above the regular folder list. This choice is stored inside the readable
`.preset` file.

### Folders made in CET

Folders made in CET organize presets only inside the mod. They do not create or rename Windows folders. There is no set limit. Their organization is stored in:

```text
Data/Catalog/Virtual Folders.txt
```

### Windows folders inside Character Presets

The mod finds Windows folders placed inside `Character Presets`, including folders inside them. These folders have an **Imported** label. Their preset files stay where you placed them until an action must move a file.

- Renaming an Imported folder changes only the name shown in the mod.
- Moving one of its presets changes only where it appears in the mod.
- **Remove Folder, Keep Presets** moves known `.preset` files to the main preset folder, keeps every preset, and removes only Windows folders that are empty.
- Unknown files are never deleted, and any folder containing one stays in place.
- The mod stops checking a folder if it cannot confirm that an entry is safe or if the folder is more than 12 levels deep.
- Linked folders and Windows junctions are not supported.

### Remove a folder but keep its contents

After you confirm **Remove Folder, Keep Presets**, the selected folder is removed and everything inside it moves to the folder above. For an Imported folder, known preset files move to the main preset folder first. Its Windows folder is removed only when no unknown files remain.

</details>

<details>
<summary><strong>Sharing and importing</strong></summary>

Preset files and shared folders go here:

```text
bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Character Presets
```

### Share one preset

- To share an appearance, send its `.preset` file.
- To install a preset, place its file in `Character Presets` or in a Windows folder inside it.
- Under **Load & Restore Appearance**, select **Refresh**
  after changing files outside the game.
- Startup uses the saved preset list instead of fully reading every preset and
  every Trash file. A preset is read in full when you select or use it. Opening
  the CET overlay does not scan the library again. This keeps large collections
  responsive.
- A current format-8 CPM `.preset` file records its preset name and CET library
  folder. If its saved folder-list entry is missing, the mod can recover both
  details from the file. Older CPM and compatible ACU files continue using their
  saved catalog entry when one exists. Otherwise, the mod uses their filename
  and Windows folder.

For safety, an imported preset cannot be larger than 1 MB or contain more than
16,448 lines and 4,096 valid options. An option name cannot exceed 256 bytes,
and an option number must fit in an unsigned 32-bit value. The higher line limit
allows the readable detail lines and spacing used by format 8.

### Share a complete folder

A `.cpmfolder` file contains the selected CET folder, all folders inside it, and every preset in that group. Notes, tags, and other supported preset details are included.

#### Export a folder

1. Open **Create & Organize Folders** and choose a non-empty folder.
2. Open **Share & Import Folders**.
3. Select **Export Selected Folder as a .cpmfolder File**.
4. Find the new `.cpmfolder` file in `Character Presets` and send it.

A shared folder can contain up to 512 presets and cannot be larger than 32 MB. An empty folder cannot be exported.

The mod writes and installs shared folders one preset at a time. Large bundles
do not need to be held in memory all at once.

To check a sharing file before installing it, open **Manage & Remove .cpmfolder
Files**, select the file, and choose **View Selected .cpmfolder Contents**. The
preview shows its main folder, nested folders, and every included preset. It
does not install or change anything.

To remove only the exported file, select it in the same section and choose
**Move Selected .cpmfolder File to Trash**. This does not remove the original
folder or its presets. You can restore the file under **Delete & Restore Items**
or remove it with **Empty Trash Permanently**.

#### Import a folder

1. Put the downloaded `.cpmfolder` file in `Character Presets`.
2. Open Character Preset Manager and expand **Create & Organize Folders**.
3. Open **Share & Import Folders**.
4. Select **Install .cpmfolder Files from Character Presets**.

The mod rebuilds the complete folder group and leaves the `.cpmfolder` file in place. It remembers the filename, file contents, and imported folder in `Data/Catalog/Imported Bundles.txt`.

An unchanged bundle is skipped while its imported folder still exists. You can import it again after deleting that folder. You can also import a changed bundle that uses the same filename. If a folder name is already in use, the new folder gets a safe `Copy` name. A failed import is not marked as complete, so you can fix the file and try again.

After a successful import, **Manage & Remove .cpmfolder Files** can move the
source file to Trash without removing the imported folder or presets. This file
manager is always available under **Create & Organize Folders**, regardless of the selected folder.

### Export selected presets

Open **Select & Manage Multiple Presets**. Select presets from any folders and choose **Export Selected**.
The new `.cpmfolder` file keeps their
folder paths inside a single **Selected Presets** group when it is installed.

### Back up the complete library

Open **Export & Import Backups** and choose **Export Complete Library Backup**.
The new `.cpmbackup` file in `Character Presets` contains every preset, the CET
folder layout, and the current settings file.

To restore one, choose its filename under **Backup file to import**, then select
**Import Selected Library Backup**. On an empty installation, the original
layout is restored. If names are already in use, the imported library is placed
in a new **Imported Library** folder so nothing is overwritten. Imported
format-8 CPM presets update their recorded name and folder to match their safe
destination. A backup cannot be larger than 256 MB.

Version 3.0.5 fixes complete-library export stopping while it checked the first
preset file. A failed export or import reports the problem and does not treat a
partial file or library as complete.

</details>

<details>
<summary><strong>Bulk actions</strong></summary>

- **Select & Manage Multiple Presets** is a separate main section for working with several presets.
- Select a preset row to add it to the selection. Select it again to remove it.
- **Select All Visible** and **Clear Selection** make large selections easier.
- Selected presets can be moved to one folder, exported together, or moved to Trash.

</details>

<details>
<summary><strong>Trash and recovery</strong></summary>

- Moving a preset to Trash keeps it available for recovery.
- Under **Create & Organize Folders**, you can move a folder and everything inside it to Trash.
- Moving an Imported folder to Trash removes its Windows folder only when it is empty. Unknown files are never deleted.
- **Restore Folder** rebuilds the whole folder group, including empty folders inside it, and restores every preset in that Trash group.
- You can also restore presets one at a time.
- If a name is already in use, the restored item gets a `Copy` name instead of overwriting anything.
- **Empty Trash Permanently** is the only action that permanently deletes trashed files.
- If the game closes during a Trash, restore, multi-move, or file-rename action, the mod finishes or safely rolls back that action the next time it starts.
- If the Trash folder cannot be read safely, the mod keeps its last good Trash
  list and does not replace the saved names or folder information.

</details>

<details>
<summary><strong>Compatibility and known issues</strong></summary>

### CC and CCXL character-option mods

**Supported.** Custom options are saved when they appear in Cyberpunk's normal character screens. Repeated and linked options, including different eye colors, are supported.

Keep the same option mods, versions, body and eye choices, and load order that were used to create the preset. Check the result whenever you change them.

[EKT Custom Character Creator - FEMV ONLY](https://www.nexusmods.com/cyberpunk2077/mods/12807) is one supported example when it uses the game's normal character system. Character Preset Manager does not change body models, skeletons, archive files, or files owned by other mods.

### Appearance Change Unlocker (ACU)

**Not compatible.** Remove ACU and restart the game before using Character Preset Manager. The mod does not check for ACU because an automatic check could keep reporting it after removal.

Compatible ACU preset files can still be loaded after ACU is removed. Save new presets with Character Preset Manager's current format.

### Character Customization Anywhere

**Not compatible.** This mod changes the same mirrors and character screens. Remove it and restart the game. Character Preset Manager does not check for it automatically.

### Photo Mode and Appearance Menu Mod

**Compatible with one limit.** These mods may stay installed, but Character Preset Manager cannot save or load inside their menus. Use the Full Appearance Editor, a mirror, a ripperdoc, or the new-game editor.

### Loading screen after closing the editor

Cyberpunk can sometimes stay on a loading screen after any character editor closes. This can happen without Character Preset Manager. Clothing, wardrobe outfits, Equipment-EX, and detailed outfits may make it more likely.

If this happens, remove all clothing and choose **No Outfit** before opening the
editor. Put everything back on afterward. Character Preset Manager does not scan
equipped clothing while its window is open.

</details>

<details>
<summary><strong>Settings and files</strong></summary>

### Settings

- **Customization Reminder: Enabled/Disabled** turns the character-screen reminder on or off. It starts on and stays off after you disable it.
- **Preset Sort** sorts presets by name or by the most recently changed preset.
- Open **Settings File**, then select **Reload Settings File**, to apply manual changes without restarting.

The same choices are stored in:

```text
Data/Config/Config.txt
```

Available values:

```text
discoveryReminder=true
presetSort=name
```

`presetSort` accepts `name` or `modified`. The mod creates this file when needed and does not replace an existing copy during installation. No separate settings mod is required.

### Mod data folders

The mod keeps its settings, folder lists, recovery files, Trash, and logs under `Data`:

```text
Data/
|-- Config/
|-- Catalog/
|-- Recovery/
|   `-- Trash/
`-- Logs/
    `-- Archive/
```

Folders made inside CET exist only in the mod's folder list. They do not create matching Windows folders.

### Memory use while idle

Version 3.0.5 releases temporary loading data as soon as a load finishes. When
the mod window is hidden or the CET overlay closes, it also unloads full preset
contents and clears interface lists that can be rebuilt. Preset names, folders,
notes, tags, favorites, and other library details stay available.

The next time a preset or list is needed, the mod reads or rebuilds it. This is
most useful for large libraries and long game sessions. Cleanup never runs
while an automatic preset load is active.

</details>

<details>
<summary><strong>Troubleshooting and FAQ</strong></summary>

### Search Help

Open **Help**, enter a word or short phrase, then select **Search**. The panel
pauses the long Help list while you type, then shows only matching topics.
Searches such as `share`, `bug`, `clothing`, `ACU`, `backup`, `Trash`,
and `favorite` include common related terms, so the required instructions and
known problems are easier to find.

### Activity log

Select **Log** at the top of the window. You can also open it from Help. You can
read or copy the log from CET. Opening Settings, Help, or the Activity Log closes
either of the other two panels. The file is stored here:

```text
bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Data/Logs/Activity.log
```

Each full game launch starts a new log. The old log is saved with its date and
time, and the 10 newest old logs are kept. The log includes startup details,
preset actions, load results, warnings, errors, inactive options, and missing
saved options. Developer information is under **More Technical Details**.

Closing the Activity Log clears its displayed copy from memory. The log file on
disk is not deleted and can be opened again with **Log**.

If the game does not confirm a saved change, the log shows the preset's saved
LocKey, editor slot, choice, and index for format-7 and format-8 presets. Older
formats did not store the slot and choice, so the exact option may be unknown.

### Can I use older Character Preset Manager or ACU presets?

Yes. Version 3.0.5 can load older Character Preset Manager formats and compatible
ACU presets. New and updated presets use format 8.

### What happens if the CET folder list is missing an entry?

A current format-8 CPM preset records its own name and CET library folder. The
mod uses those details to rebuild the missing entry. `/` means the preset belongs
under **All Presets**. Older files remain loadable, but they do not contain this
new recovery information.

### Can ACU or Character Customization Anywhere stay installed?

No. Remove them and restart the game.

### Can Photo Mode or Appearance Menu Mod stay installed?

Yes, but do not try to save or load inside their menus. Use a supported character screen.

### Is the character shown in the screenshots included?

No. The screenshots show the mod. My personal character preset is not included,
and I do not plan to release it.

</details>

<details>
<summary><strong>Version 3.0.5 summary</strong></summary>

- Fixes complete-library backup export and keeps backup import non-destructive
  when names already exist.
- Adds `# CPM Preset`, `# Name:`, and `# Library folder:` details to current
  format-8 files. These details can rebuild a missing catalog assignment.
- Keeps older CPM formats and compatible ACU presets readable without changing
  them merely because they were found or loaded.
- Adds a read-only `.cpmfolder` contents preview showing its main folder, nested
  folders, and every included preset before installation.
- Adds persistent Favorites, complete-library `.cpmbackup` controls, automatic
  previous-appearance snapshots, and a separate bulk preset section.
- Adds Help search, a top-level **Log** button, preset-tag searching, tags beside
  preset names, and **Copy File Path** for the selected preset.
- Improves loading confirmation, editor refresh timing, compatibility details,
  automatic **Force Full Load** defaults, and narrow-window controls.
- Releases completed-load data immediately and unloads full preset contents,
  rebuildable interface lists, and displayed log text when they are idle.
- Keeps safe writing, recovery, older preset support, Trash protection, and
  `.cpmfolder` import tracking while organizing the mod into smaller modules.

See [CHANGELOG.md](CHANGELOG.md) for the complete release history.

</details>

<details>
<summary><strong>Credits and AI disclosure</strong></summary>

### AI disclosure

I used AI only to help plan and improve the CET menu's layout and appearance. I
made the final design choices, changed the AI-assisted work to fit the mod, and
manually tested saving, loading, folders, recovery, and gameplay features.

### Credits

- **Character Preset Manager (CET):** I created and maintain this mod as
  **dklyntly**.
- **[ACU - Character Preset Manager](https://www.nexusmods.com/cyberpunk2077/mods/3850):**
  **PotatoOfDoom** created ACU, which inspired this project. I kept support for
  compatible ACU presets so existing collections are not lost, while using my
  own current format and controls.
- **[Character Customization Anywhere](https://www.nexusmods.com/cyberpunk2077/mods/3930):**
  **keanuWheeze** created this mod. Its way of opening character customization
  during normal play inspired me when I made the Full Appearance Editor.
- **[Cyber Engine Tweaks](https://www.nexusmods.com/cyberpunk2077/mods/107):**
  **yamashi** created CET, and its contributors maintain it. I use CET's
  scripting and menu system for Character Preset Manager.
- **CD Projekt Red:** I credit CD Projekt Red for Cyberpunk 2077 and its
  character system.
- **Cyberpunk 2077 modding community:** I appreciate the testing, research,
  compatibility information, and feedback shared by the community.

I do not include or require the mods I named as inspiration. Do not install ACU
or Character Customization Anywhere beside Character Preset Manager.

### Links

- [Download on Nexus Mods](https://www.nexusmods.com/cyberpunk2077/mods/31886)
- [GitHub source code](https://github.com/DKLYNTLY/Character-Preset-Manager-CET-)
- [Discord community and support](https://discord.com/invite/mUGHmQxHG8)
- [Full changelog](CHANGELOG.md)
- [MIT license](LICENSE)

</details>
