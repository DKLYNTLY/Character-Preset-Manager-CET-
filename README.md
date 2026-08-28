<h1 align="center">Character Preset Manager (CET)</h1>

<p align="center"><em>Save, load, compare, and recover complete Cyberpunk 2077 character appearances from the character screen or CET.</em></p>

<p align="center">
  <strong><a href="https://www.nexusmods.com/cyberpunk2077/mods/31886">Download on Nexus Mods</a></strong>
  ·
  <a href="https://discord.com/invite/mUGHmQxHG8">Discord and support</a>
  ·
  <a href="CHANGELOG.md">Full changelog</a>
</p>

<p align="center"><strong>Current version: 3.0.7</strong></p>

<p align="center">
  <img src="images/Character%20Preset%20Manager%20%28CET%29%20v3.0.3.png" alt="Character Preset Manager feature overview" width="900">
</p>

## Interface and feature previews

<details open>
<summary><strong>Character Preset Manager interface</strong></summary>

![Character Preset Manager's CET interface for saving, loading, and organizing presets](images/UI%20v3.0.4.gif)

The controls built into Cyberpunk's character screens use a transparent panel
so your character remains visible. Search and Preset Name keep dark input fields,
and the buttons use translucent charcoal-black surfaces with red and cyan labels.

The main CET interface keeps saving, loading, folders, sharing, Trash, settings,
and help in one window.

Only **Open & Edit Appearance** starts expanded. Every other main section starts
collapsed and can be opened when needed.

</details>

<details open>
<summary><strong>Full apartment mirror options</strong></summary>

![The full character editor opened from an apartment mirror](images/Mirror.gif)

Apartment mirrors include the full set of character-creation options, rather
than the smaller selection normally available during play.

</details>

## Features

- **Complete appearance presets** — Save and load complete character appearances, including visible CC and CCXL options.
- **Character-screen preset panel** — Use presets directly in new-game creation, the Full Appearance Editor, apartment mirrors, and ripperdoc appearance editors.
- **Bundled default choices** — Keep the Corpo, Nomad, and Streetkid starter appearances for both body types after the new panel replaces the game's three preset buttons.
- **Full Appearance Editor anywhere** — Open the full game character editor during normal play from CET or an optional key.
- **Full apartment mirror options** — Use the complete character-creation option set through normal apartment mirrors.
- **One-click loading** — Select a preset once while the mod waits for Cyberpunk to refresh the editor.
- **Cosmetic cleanup** — After applying a preset, clear visible appearance options that were not part of it.
- **Detailed appearance comparison** — See what already matches, what will change, what is missing or uncertain, what is invalid, and which extra options loading will clear.
- **Unlimited nested folders** — Organize presets in folders and folders inside folders, with no set limit.
- **Preset and folder copies** — Copy one preset or a complete folder group.
- **Readable format-8 files** — See the CPM marker, preset name, CET library folder, dates, notes, tags, favorite status, and appearance choices in plain text.
- **Notes and tags** — Store optional details with current presets.
- **Favorites and appearance history** — Pin useful presets and restore up to 10 automatic recovery entries kept outside the normal library.
- **Complete-library backups** — Export or safely import every preset, the CET folder layout, and settings in one `.cpmbackup` file.
- **Recoverable Trash** — Move presets and folders to Trash and restore them later.
- **Preset sharing** — Share one `.preset` file or a complete folder as a `.cpmfolder` file, and inspect a shared folder before installing it.
- **Activity log** — Review actions, loading results, warnings, and errors inside CET.

### What changed in 3.0.7

Preset loading now clears old dependent choices before it changes the options
that control whether those choices are visible. This prevents settings such as
heterochromia and separate eye colors from an earlier preset remaining on a
bundled default preset. The character-screen preset panel also opens reliably
in the Full Appearance Editor, apartment mirrors, ripperdocs, and new-game
character creation when the screen appears while the preset library is still
connecting.

The panel has an **Open CET Menu** button below its white instructions and above
Search. Preset rows and the lower action buttons use tighter spacing.
Pressing that button shows how to use the CET binding and select Character
Preset Manager from the menu on the right.
Search, Preset Name, preset rows, and action buttons share the same transparent
charcoal background layers. The instructions say to click a preset once and
point to CET for extra options, permanent preset deletion, and Help.

Cleanup checks now read a fresh editor state and wait for dependent options to
settle. Successful clears are no longer reported as unconfirmed simply because
the earlier option list had not updated yet.
Fresh cleanup reads use the normal loading interval and stop when loading ends.
They do not run every frame or during ordinary gameplay.

- Adds an original Cyberpunk-style preset panel to every supported character
  customization screen. The CET window remains available for advanced library
  work and safe recovery.
- Replaces the new-game screen's three preset choices with the full preset
  library and includes six default Corpo, Nomad, and Streetkid presets.
- Adds a larger transparent panel farther left on the character screen. Search
  and Preset Name keep dark fields, while buttons use translucent charcoal-black
  surfaces with red and cyan labels. Randomize remains below the panel.
- Trims the character-facing edge of the panel and removes the distracting
  scroll caption and static scrollbar. Mouse-wheel, stick, and navigation
  scrolling continue to work.
- Extends the panel down to just above Randomize and shows ten preset rows at
  once, leaving more room for Panel Status and the save controls.
- Narrows the character-facing side further so buttons do not cover the
  hairstyle preview. Headings and instructions are shorter to remain readable.
- Uses a normal hyphen in **Panel Status** so Cyberpunk's font always displays
  the status message.
- Removes the cyan subtitle and aligns **Character Preset Manager** with the
  game's **Customize Your Look** heading. The list moves upward and the Panel
  Status message receives more than twice as much vertical space.
- Gives every preset and action button the same resting transparency as Search
  and Preset Name. The panel applies that transparency directly so the game does
  not render the charcoal background as opaque. Button labels and the cyan
  selected state remain clear.
- Tightens the spacing between preset rows and places the larger Panel Status
  area directly below the tenth visible row.
- Keeps Panel Status alive for the full character-screen session and fixes
  **Confirm Overwrite** so losing focus from an unchanged name no longer cancels
  it. Editing the name still cancels confirmation normally.
- Hides Panel Status until a load, overwrite, Trash action, or error has
  something important to report. Old CET guidance, search counts, folder
  browsing, and save-location changes no longer replace the message. Trash
  confirmations and results remain visible after the list refreshes.
- Trash status messages explain that CET is where a moved preset can be
  restored or deleted permanently.
- Uses translucent charcoal-black button surfaces like the CET window instead
  of maroon. The **Character Preset Manager** title uses the folder-row cyan.
- Adds one clearly labeled **Panel Status** area below the preset list. It shows
  overwrite and Trash messages, live loading progress, the final load result,
  and failures without requiring the CET overlay. A red marker means the action
  needs attention.
- Loads a preset with one click, matching the panel's original behavior.
- Keeps the game's Q and E character rotation available after selecting a
  preset, folder, save location, Save, or Trash action. Search and Preset Name
  keep the keyboard only while text is being entered.
- Places **Search** above one scrollable list ordered like **Load & Restore
  Appearance** in CET. Folder rows open and close their presets. Favorites stay
  at the top, folders follow, and presets outside folders appear last. Selecting
  a preset starts loading it immediately.
- Places **Preset Name**, **Save Location**, **Save Preset**, and **Move Preset to
  Trash** below the list. If confirmation is needed, the same button changes to
  **Confirm Overwrite** or **Confirm Move to Trash**. The Trash confirmation is
  armed only by its own first press and clears when the selection changes. The
  Trash button is unavailable when no preset is selected. No extra buttons
  appear.
- Keeps rename, permanent deletion, Help, comparison, favorites, folders,
  backups, Trash recovery, and Empty Trash in the CET window.
- Uses a narrow bridge so the native screen calls the existing Lua preset,
  matching, loading, folder, backup, and recovery behavior. Preset rules are
  not duplicated in redscript.
- Expands comparison results to separate matching, changing, missing,
  repeated or uncertain, invalid, and cleared options.
- Replaces the single recovery file with five protected appearance-history
  entries. Identical snapshots are skipped, and the current appearance is
  always saved before an older entry is restored.
- Shows **Preset Sort Order** in the CET Settings tab.

> [!IMPORTANT]
> Remove **Appearance Change Unlocker (ACU)** and **Character Customization
> Anywhere** before using this mod. They change the same character screens and
> cannot be used with Character Preset Manager. Restart the game after removing
> either mod.

<details>
<summary><strong>Requirements, installation, and optional keys</strong></summary>

### Requirements

- [Cyber Engine Tweaks 1.37.1 or newer](https://www.nexusmods.com/cyberpunk2077/mods/107)
- [RED4ext 1.30.0 or newer](https://www.nexusmods.com/cyberpunk2077/mods/2380)
- [redscript 0.5.31 or newer](https://www.nexusmods.com/cyberpunk2077/mods/1511)
- [Codeware 1.20.3 or newer](https://www.nexusmods.com/cyberpunk2077/mods/7780)

ArchiveXL, Mod Settings, Native Settings UI, Native Settings UI Side Menu Add-on,
TweakXL, Input Loader, cybercmd, ACU, and Character Customization Anywhere are
not required. ACU and Character Customization Anywhere are incompatible and must
be removed before the game starts.

### Install the mod

1. [Download the latest release from Nexus Mods](https://www.nexusmods.com/cyberpunk2077/mods/31886).
2. Install every required mod listed above.
3. Remove ACU and Character Customization Anywhere if either one is installed,
   then fully restart the game.
4. Extract the downloaded archive into your Cyberpunk 2077 game folder.
5. Start the game. Open a supported character screen to use the native panel,
   or open the Cyber Engine Tweaks overlay for the advanced manager.

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

Do not keep an older copy of the mod beside the current one. Version 3.0.7 does not move loose files left by older releases. For a clean update:

1. Back up the `.preset`, `.cpmfolder`, and `.cpmbackup` files you want to keep
   from `Character Presets`.
2. Remove the old Character Preset Manager folder.
3. Install version 3.0.7 and its required mods.
4. Put your saved presets and bundles back in `Character Presets`.

</details>

<details open>
<summary><strong>Using Character Preset Manager</strong></summary>

### Save a preset

1. Open the **Full Appearance Editor**, a mirror, a ripperdoc character screen, or the new-game editor.
2. Enter a name in **Preset Name** below the preset list.
3. Select **Save Location** until it shows **All Presets** or the folder you
   want.
4. Select **Save Preset**.

For folders, notes, tags, sharing, backups, Trash, and other advanced work,
open Character Preset Manager in CET. Check the orange save-location line in
the status card. To change it, open
   **Change Save Location** below the save button and choose a folder or **All
   Presets**.

If that name already exists, the button changes to **Confirm Overwrite**. Select
that same button again only when you want to overwrite it.

### Load a preset

![A complete character preset loading in Cyberpunk 2077](images/Preset%20Loading.gif)

This example shows the complete loading process, including automatic editor
refreshes and the final appearance.

1. Open one of the supported character screens listed above.
2. Scroll through the panel or use **Search** to find a preset. Select a folder
   row to show or hide the presets inside it.
3. Select a preset to load it. Compatibility review is available separately
   through **Check Compatibility** in CET.
4. When the panel opens, its ready message explains how to load a preset and
   points to CET for logs, settings, renaming, and other advanced tools. During
   loading, **Panel Status** shows progress and the final
   result. A red marker means the load needs attention and the message explains
   what did not load. Open CET only when you want the detailed Activity Log.

Before each normal preset load, the mod quietly saves the active appearance.
To recover it, open CET and use **Restore Previous Appearance** or choose an
entry under **Appearance History**. Appearance history stays outside the normal
preset library, sharing files, and backups.

Cyberpunk may refresh the editor several times. The mod waits and continues on
its own. It applies the saved appearance before clearing any remaining options,
then checks the preset again. Select **Cancel Loading** if you need to stop.

Compatibility is not checked when you select a preset, open CET, refresh the
preset list, change Force Full Load, or finish loading. Open **Advanced Preset Options**
and select **Check Compatibility** whenever you want a current result. This
avoids scanning large appearance-option lists while you browse presets.

Every preset uses the proven verified loader from version 3.0.6. It applies and
checks changes individually, waits when Cyberpunk rebuilds dependent options,
clears genuine leftovers, and verifies the final appearance before reporting
the result.

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
manually under **Load & Restore Appearance > Advanced Preset Options**.

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

Choose a preset under **Load & Restore Appearance**, then open **Advanced Preset Options**
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
folder layout, and the current settings file. This includes presets in Imported
Windows folders, folders made inside CET, and empty CET folders. The success
message shows the verified preset and folder totals.

To restore one, choose its filename under **Backup file**, then select
**Import Selected Library Backup**. On an empty installation, the original
layout is restored. If names are already in use, the imported library is placed
in a new **Imported Library** folder so nothing is overwritten. Imported
format-8 CPM presets update their recorded name and folder to match their safe
destination. A backup cannot be larger than 256 MB.

Version 3.0.5 fixes complete-library export stopping while it checked the first
preset file. A failed export or import reports the problem and does not treat a
partial file or library as complete.

To remove a backup, choose it under **Backup file**, then select
**Delete Selected Backup Permanently**. Check the filename in the warning and
select **Confirm Delete Selected Backup Permanently**. This deletes only the
selected `.cpmbackup` file. It does not delete presets already in the library.

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

- **Preset Sort Order** sorts by name or last changed date.

Change this preference through the CET **Settings** tab. CET key choices remain
under **CET Bindings**.

The character-screen panel, five-entry appearance history, pre-restore safety
save, missing-option warnings, and CET fallback stay enabled for consistent and
safe behavior. Use **Check Compatibility** in CET when you want comparison
details.

The same choices are stored in:

```text
Data/Config/Config.txt
```

The mod keeps an older sort choice when updating to 3.0.7 and safely ignores
retired reminder, clothing-warning, and log-detail settings. Changes made
through any settings menu update this mirror automatically. Do not edit the
mirror while the game is running.

### Mod data folders

The mod keeps its settings, folder lists, recovery files, Trash, and logs under `Data`:

```text
Data/
|-- Config/
|-- Catalog/
|-- Recovery/
|   |-- Appearance History/
|   `-- Trash/
`-- Logs/
    `-- Archive/
```

Folders made inside CET exist only in the mod's folder list. They do not create matching Windows folders.

### Memory use while idle

Version 3.0.7 releases temporary loading data as soon as a load finishes. When
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

Yes. Version 3.0.7 can load older Character Preset Manager formats and compatible
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
<summary><strong>Version 3.0.7 summary</strong></summary>

- Adds an original native character-screen preset panel backed by the existing
  Lua library and loading engine.
- Includes six default Corpo, Nomad, and Streetkid starter presets.
- Uses a larger panel farther left with translucent charcoal-black surfaces,
  Cyberpunk's red and cyan labels, and larger text. Randomize sits below it.
- Uses one Search field and a scrollable list ordered like CET. Folder rows open
  and close their presets, while Favorites remain at the top and presets outside
  folders remain last. Selecting a preset starts loading it immediately.
- Provides Preset Name, Save Location, Save Preset, and Move Preset to Trash
  below the list. The same button changes to Confirm Overwrite or Confirm Move
  to Trash when a second press is required; no extra confirmation buttons appear.
- Keeps rename, permanent deletion, Help, comparison, favorites, folders,
  backups, Trash recovery, and Empty Trash in CET.
- Provides Preset Sort Order through the CET Settings tab while keeping loading
  and safety behavior fixed.
- Fixes the native panel's redscript compilation and keeps preset scans tied to
  explicit actions instead of normal game frames.
- Keeps older CPM and compatible ACU preset support without including or
  requiring ACU code or assets.

See [CHANGELOG.md](CHANGELOG.md) for the complete release history.

</details>

<details>
<summary><strong>Credits and AI disclosure</strong></summary>

### AI disclosure

I used AI to help plan, write, and review parts of the interface, Lua, redscript,
documentation, and release checks. I made the final design and release choices
and reviewed the finished work before publishing it.

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
- **RED4ext, redscript, and Codeware:** I use these community tools for the
  native character-screen panel.
- **CD Projekt Red:** I credit CD Projekt Red for Cyberpunk 2077 and its
  character system.
- **Cyberpunk 2077 modding community:** I appreciate the testing, research,
  compatibility information, and feedback shared by the community.

I do not include or require the mods I named as inspiration. Do not install ACU
or Character Customization Anywhere beside Character Preset Manager.
The native panel uses my own code and presentation. It does not reuse ACU code,
interface files, or visual assets.

### Links

- [Download on Nexus Mods](https://www.nexusmods.com/cyberpunk2077/mods/31886)
- [GitHub source code](https://github.com/DKLYNTLY/Character-Preset-Manager-CET-)
- [Discord community and support](https://discord.com/invite/mUGHmQxHG8)
- [Full changelog](CHANGELOG.md)
- [MIT license](LICENSE)

</details>
