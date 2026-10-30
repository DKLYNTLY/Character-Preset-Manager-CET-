<h1 align="center">Character Preset Manager (CET)</h1>

<p align="center"><em>Save, load, organize, and share your Cyberpunk 2077 appearances.</em></p>

<p align="center">
  <strong><a href="https://www.nexusmods.com/cyberpunk2077/mods/31886">Download on Nexus Mods</a></strong>
  · <a href="https://discord.com/invite/mUGHmQxHG8">Discord</a>
  · <a href="https://github.com/DKLYNTLY/Character-Preset-Manager-CET-">GitHub source</a>
</p>

<p align="center">If you enjoy my mods, you can support my work through Ko-fi or PayPal.</p>

<p align="center">
  <a href="https://ko-fi.com/A3G129JCLF"><img src="https://ko-fi.com/img/githubbutton_sm.svg" alt="Support me on Ko-fi"></a>
  <a href="https://www.paypal.com/ncp/payment/7ZKG8YG6GCERC"><img src="https://img.shields.io/badge/Support%20via-PayPal-0070BA?style=for-the-badge&amp;logo=paypal&amp;logoColor=white" alt="Support via PayPal" height="30"></a>
</p>

<p align="center"><strong>Current version: 4.0.1</strong> · <a href="CHANGELOG.md">Changelog</a></p>

Character Preset Manager saves your character's appearance as a preset you can
load again later. It follows on from Appearance Change Unlocker (ACU) and reads
older CPM files as well as supported ACU presets.

CET runs the preset engine and complete manager. The simple menu adds quick
controls to the game's character screens, while a small native DLL handles
file watching and ACU imports. Both menus use the same library and loader.

> [!IMPORTANT]
> Uninstall **Appearance Change Unlocker (ACU)** and fully restart the game.
> Keep only its preset files; **the ACU mod itself must not remain installed**.
> The importer can read those files from the folder listed below without ACU.

## What you can do

- Save and load vanilla, CC, and CCXL choices shown in a supported character editor.
- Open the Full Appearance Editor during play, or use full apartment mirrors.
- Search presets by name, folder, or tag and keep favorites together.
- Organize presets in folders, add notes, and copy or rename them.
- Restore one of five saved recovery appearances.
- Share one preset, a folder, or a group of selected presets.
- Back up the whole library, including folders and settings.
- Restore items from Trash before choosing permanent deletion.
- Read the Activity Log and search Help inside CET.

New files use readable format 8. Older CPM and compatible ACU files stay
unchanged when found or loaded; overwriting one, or saving its notes or tags,
updates it to format 8.

## Showcase

Watch my mod showcase to see Character Preset Manager in action.

[![Watch my Character Preset Manager showcase](https://img.youtube.com/vi/zxrJ2Ryq-G8/hqdefault.jpg)](https://www.youtube.com/watch?v=zxrJ2Ryq-G8)

<details>
<summary><strong>Install, update, and check compatibility</strong></summary>

## Requirements

Cyberpunk 2077 **2.5** requires at least these framework versions:

- [**Cyber Engine Tweaks 1.38.0 or newer**](https://www.nexusmods.com/cyberpunk2077/mods/107)
- [**RED4ext 1.31.0 or newer**](https://www.nexusmods.com/cyberpunk2077/mods/2380)
- [**redscript 0.5.32 or newer**](https://www.nexusmods.com/cyberpunk2077/mods/1511)
- [**Codeware 1.21.1 or newer**](https://www.nexusmods.com/cyberpunk2077/mods/7780)

*These frameworks must support your installed game version. After a game update,
check for compatible framework and mod versions before using the editor.*

---

## First installation

1. Download the mod from [Nexus Mods](https://www.nexusmods.com/cyberpunk2077/mods/31886).
2. Install all four required frameworks: **Cyber Engine Tweaks (CET)**,
   **RED4ext**, **redscript**, and **Codeware**. CET is required for both menus.
3. Remove Character Customization Anywhere and fully restart the game.
4. Extract `Character Preset Manager (CET) 4.0.1.zip` into the main
   `Cyberpunk 2077` folder. Merge its `bin`, `r6`, and `red4ext` folders with
   the folders already there.
5. Start the game. If CET asks you to choose an overlay key on its first launch,
   finish that setup and close the overlay.
6. Open character creation for a new game, or load a save and use an apartment
   mirror to change your appearance. The **simple menu** appears on the left
   of the character screen automatically.
7. Use **Preset Name**, **Save Location**, and **Save Preset** to save your
   appearance, or select a preset in the list to load it. Read **Panel Status**
   for progress and check the result before confirming your appearance.

The simple menu includes saving, loading, search, folders, recovery, Trash,
and randomizing. Keep the CET overlay closed while using those controls.

For more tools, select **Advanced Preset Manager** to open CET and show the
complete manager. Keep the game in focus while it opens.
The complete manager includes backups, sharing, compatibility checks, Help,
and logs. It starts near the right side; move or resize it as needed, and
CET remembers where you leave it.

---

## Update an existing installation

1. ***Back up*** *the complete `Character Presets` and `Data` folders from your
   current mod folder.* This keeps presets, sharing files, folder lists, settings,
   recovery history, and Trash.
2. Remove the old `Character Preset Manager (CET)` mod folder.
3. Remove `r6/scripts/CharacterPresetManager` so no old menu scripts remain in the game.
   Your presets are stored elsewhere.
4. Install version 4.0.1 and its four required frameworks.
5. Restore your saved `Character Presets` and `Data` folders.
6. Fully restart the game.

Install the complete `modules` folder, including its `domain`, `application`,
and `adapters` subfolders. These contain required mod code.

Keep a separate copy of older presets if you still need them in an earlier
mod version. Loading alone does not upgrade their file format.

---

## Compatibility

### Character-option mods

CC and CCXL choices work when they appear in the game's normal character
screens. Linked options and separate eye colors are supported.

Examples include [EKT Custom Character Creator - FEMV ONLY](https://www.nexusmods.com/cyberpunk2077/mods/12807)
for facial choices and [Head Cyberware CCXL](https://www.nexusmods.com/cyberpunk2077/mods/23969)
for added cyberware choices. Install each mod and its requirements separately;
presets save choices, not the mod files.

Keep the mods, versions, body and eye choices, and load order used to make a
preset. If that setup changes, check the result and save the corrected appearance
again; missing custom choices cannot be recreated by the mod.

### Incompatibility

Remove **Character Customization Anywhere**, then fully restart the game.
Both mods change the same character screens and **cannot work together**.

</details>

<details>
<summary><strong>Use the menus: save, load, and randomize</strong></summary>

Loading clears unused old choices, applies main choices, then applies linked colors and details. Changes run in small groups, with a shared check after each stage. Automatic camera focus pauses during preset loading. Check your appearance before confirming the editor.

## Choose a menu

| Menu | Use it for |
|---|---|
| **Complete CET manager** | Every preset tool, including folders, sharing, backups, compatibility checks, Help, and logs |
| **Simple menu in the character screen** | Search, one-click loading, saving, recovery, Trash, and Randomize |

The simple menu uses red frames and cyan highlights to match the game.
**Randomize** and **Randomize Settings** sit below its title and also appear
under **Open & Edit Appearance** in CET. Both use the game's randomizer and
category locks. The original buttons hide only when the replacements are ready.

**R** still works in the character screen. Wait for loading or recovery to
finish before randomizing; from CET, select **Randomize Settings**, then close
the overlay to see the game's settings.

Open the complete manager with your normal CET overlay key. The unused
**Toggle Character Preset Manager (CET)** binding has been removed.

---

## Optional editor key

Open **CET Bindings > Character Preset Manager (CET)** and assign
**Open Full Appearance Editor**. Close the overlay before pressing the key
in normal gameplay.

Help shows the assigned key when CET provides it. Otherwise, Help reports
whether that input has been received during the current game session.

---

## Open the advanced manager

Select **Advanced Preset Manager** to open CET and show the CPM window.
The native helper reads your saved CET binding and presses it once after you
release the mouse button. Keep the game in focus and release other keys.

If CET does not open, press its overlay binding yourself. Set that binding in
CET first if you have not chosen one; CPM does not change your bindings.

---

## Use the simple menu

Select a preset once to load it. Open a folder row to see its contents, or use
**Search** to narrow the list by preset name, folder, or tag. **Refresh** reads files
added or changed outside the game.

Loading finishes automatically after that one click. The loader waits for hair,
cyberware, and linked choices to settle before sending another change.
If a value cannot be confirmed, check the warning and appearance before continuing.

A closed folder hides its subfolders too. Main folders are cyan; nested folders
are yellow and begin with `>`. Favorites appear near the top, and presets outside
folders appear under **All Presets**.

The selected-preset line shows its folder, number of saved options, format,
and tags. Read **Panel Status** for progress, errors, overwrite prompts, and
the final result.

To save, enter a name in **Preset Name**, select **Save Location**, and choose
a folder or **All Presets**. Press **Save Preset** once. If the name is in use,
press **Confirm Overwrite** only when you want to replace that preset.

**Move Preset to Trash** becomes **Confirm Move to Trash** before moving the
selected file. Restore it or delete it permanently through CET.

---

## Use the complete CET manager

To save an appearance:

1. Open a supported character screen and the CET manager.
2. Check the save location in the status card.
3. Use **Change Save Location** to choose another folder or **All Presets**.
4. Enter a name and select **Save New Preset**.
5. Use the overwrite prompt only if you want to replace an existing preset.

To load an appearance:

1. Open a supported character screen.
2. Choose a preset under **Load & Restore Appearance**.
3. Check its name, folder, format, and number of saved options.
4. Select **Load Selected Preset** once and wait for the final status.
5. Check the visible result before confirming the editor.

The loader reads the current options as the editor updates. It waits for linked
choices, including cyberware layers, clears old choices the preset does not
use, and checks the saved values at the end. It also rebuilds the visible option
list; a confirmed value does not replace your visual check.

*A warning names choices the game could not confirm. If the same required
options stay missing after three checks, loading stops; check your character
mods, correct the appearance if needed, and save it again.*

---

## Check compatibility

Choose a preset, open **Advanced Preset Options**, and select
**Check Compatibility**. The Load status card separates matching and changing
choices, missing options, repeated or unclear matches, invalid entries, and
old choices that loading will clear.

The mod keeps an option cache in memory while the character editor is open.
It checks current lists as they are used, so added, removed, renamed, or reordered
choices replace stale entries. Linked choices are checked again after their style
changes. Game objects are always read from the current editor.

Use **Refresh options** in **Load & Restore Appearance** to clear this cache
and read the current editor list again. This is separate from **Refresh**, which
updates preset files. Wait for loading to finish before refreshing options.
Installing or removing character mods may still require restarting the game;
refreshing cannot make the game load new mod files.

Checks run when you request them. Selecting a preset, opening CET, refreshing,
changing Force Full Load, or finishing a load does not start another comparison.

---

## Force Full Load

Find this under **Load & Restore Appearance > Advanced Preset Options**.
Current format-8 files normally match by editor slot and saved choice name;
Force Full Load also allows less certain matches by position when older files
lack those details.

It turns on automatically for older formats that need it, and turns off when
you choose a current preset. You can change it yourself. After adding, removing,
or reordering character mods, check hair, colors, and other matched choices,
then save the corrected preset in format 8.

---

## Randomize

Use **Randomize** or **Randomize Settings** in either menu. The settings choose
which categories the game can change, and both menus share those locks.
**R** remains available in the character screen.

From CET, select **Randomize Settings**, then close the overlay to open the
settings. These actions are unavailable while a preset is loading or restoring.

---

## Interface previews

### Simple menu

![The updated simple menu in Cyberpunk's character editor](https://raw.githubusercontent.com/DKLYNTLY/Character-Preset-Manager-CET-/34244e2f4fc334dbf0016fc4fd5a2ff976958d3b/images/Simple%20Menu.png)

Find a preset on the left and select it to load. The same panel has save,
recovery, Trash, and advanced-manager controls.

---

### Complete CET manager

![The complete CET preset manager](https://raw.githubusercontent.com/DKLYNTLY/Character-Preset-Manager-CET-/34244e2f4fc334dbf0016fc4fd5a2ff976958d3b/images/Advanced%20Menu.gif)

CET keeps all library tools in one window. Open a section heading to see its
controls, or use Help to find a specific action.

---

### Full apartment mirrors

![Full character options in an apartment mirror](https://raw.githubusercontent.com/DKLYNTLY/Character-Preset-Manager-CET-/34244e2f4fc334dbf0016fc4fd5a2ff976958d3b/images/Mirror.gif)

Apartment mirrors show the full character-creation list. They use the same
preset tools as the Full Appearance Editor.

**Voice Tone cannot be changed mid-game.** Choose your voice during new-game character creation; confirming appearance edits does not save a different voice.

</details>

<details>
<summary><strong>Manage presets: imports, sharing, backups, and recovery</strong></summary>

## Supported ACU files

The importer reads these layouts:

- ACU 3.0.0 JSON with camel-case field names.
- ACU 3.0.1 JSON with snake-case field names.
- ACU 3.2.1 text and JSON.

JSON is a text format with named fields. The importer reads these older
layouts without changing your original files.

---

## Import steps

1. Back up your ACU `.preset` files, uninstall ACU, and keep only the presets.
   Recreate this folder if needed, then put the saved files here:

   ```text
   bin/x64/plugins/cyber_engine_tweaks/mods/AppearanceChangeUnlocker/character-presets
   ```

2. Install Character Preset Manager and its required frameworks.
3. Fully restart the game and wait briefly after startup.
4. Open Character Preset Manager in CET and look under **ACU Presets**.
5. If a file is missing, select **Refresh** once and wait a moment.
6. Use **Check Compatibility** if you want to review a copy before loading it.
7. Load the copy through Character Preset Manager. ACU must stay uninstalled.

Copies go into `Character Presets/ACU Presets`, keeping ACU's subfolders.
The originals are not moved, renamed, or rewritten. Changed files are copied
when needed, while unchanged files are skipped.

The Activity Log reports internal eye locks and other options marked inactive
or not editable by the game. That warning does not change the imported file
or its loading behavior.

If a preset is still missing, check its path, `.preset` extension, and size.
It must not be empty or exceed 1 MB. Then look for **ACU IMPORT** and
**ACU SAFETY** entries in the Activity Log.

---

## Where files are stored

Presets and exports are stored here:

```text
bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Character Presets
```

Send one `.preset` file to share an appearance. To install one, put it in
`Character Presets` or a Windows folder inside that location, then select
**Refresh** under **Load & Restore Appearance**.

A preset can contain up to 4,096 valid options and 16,448 lines, with a total
size of 1 MB. Each option key is limited to 256 bytes. Option numbers must fit
in an unsigned 32-bit value, from 0 to 4,294,967,295.

---

## Readable format 8

A preset stores visible editor choices, their slots and list numbers, and
stable choice names when available. It can also store its name, library folder,
source, dates, notes, tags, and favorite state.

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

Each main line holds the option key and its saved number. **Editor slot** and
**Saved choice** describe the line above them. Other comment lines are ignored.

`CPM Preset` identifies a file saved by this mod. `Name` and `Library folder`
help rebuild a missing library entry; `/` means **All Presets**. Older files
remain readable, but may not contain these recovery details.

---

## Notes, tags, and favorites

Choose a preset, then open **Rename & Copy Presets > Tags, Notes & File** to
edit notes or tags. **Copy File Path** copies its path from the game folder.
Saving those details may also upgrade an older file to format 8.

To pin a preset, choose **Add Selected Preset to Favorites** under
**Load & Restore Appearance > Advanced Preset Options**. It stays in its
original folder and also appears in Favorites; current files store this in
the readable header.

---

## CET folders

These folders arrange your library without creating matching Windows folders.
You can nest them with no set depth limit. Their layout is stored in
`Data/Catalog/Virtual Folders.txt`.

Choose a parent before creating a nested folder. Renaming a preset changes
its `.preset` filename too, while moving it between CET folders changes its
library location. Copies use names such as `Copy` or `Copy 2` when needed.

Copying a folder includes all its presets and nested folders.
**Remove Folder, Keep Presets** moves those contents to the folder above
without permanently deleting presets.

---

## Imported Windows folders

Windows folders inside `Character Presets` appear with an **Imported** label.
Moving or renaming them in CET changes the library layout, leaving the Windows
folder name alone.

When you remove an imported folder and keep its presets, known `.preset`
files move to the main preset folder first. The Windows folder is removed only
if it is confirmed empty. Unknown files are kept, so a folder containing any
will remain in place.

Linked folders and Windows junctions are not supported. A scan stops if an
entry cannot be checked safely or a physical folder is more than 12 levels
deep; this limit does not apply to folders made inside CET.

---

## Share a folder

A `.cpmfolder` file contains one CET folder, its nested folders, and their
presets. Notes, tags, favorites, and other supported preset details are included.

1. Select a non-empty folder under **Create & Organize Folders**.
2. Open **Share & Import Folders**.
3. Select **Export Selected Folder as a .cpmfolder File**.
4. Send the new file from `Character Presets`.

One file can hold up to 512 presets and 32 MB. Empty folders cannot be exported.
Large exports are written one preset at a time to limit memory use.

---

## Preview or install a shared folder

Put a `.cpmfolder` file in `Character Presets`. Under **Create & Organize
Folders > Share & Import Folders**, use **Manage & Remove .cpmfolder Files**
to choose the file. Select **View Selected .cpmfolder Contents** to preview
its folders and presets without installing anything.

Select **Install .cpmfolder Files from Character Presets** to import it.
The source file stays in place. Moving that source file to Trash later does
not remove presets or folders already installed from it.

`Data/Catalog/Imported Bundles.txt` records the filename, contents, and installed
folder. An unchanged file is skipped while that folder exists. Changed files
can be imported again, and duplicate names receive a `Copy` name. Failed
imports are not marked complete.

---

## Work with several presets

Open **Select & Manage Multiple Presets** and choose rows from any folder or
search result. Select a row again to remove it from the group. Use **Select All Visible** to add the results, or **Clear Selection** to
start over.

Move the selection to one folder, export it, or move it to Trash.
**Export Selected** creates a `.cpmfolder` file that keeps each preset's path
inside a **Selected Presets** group when imported.

---

## Back up the whole library

Under **Export & Import Backups**, select **Export Complete Library Backup**.
The `.cpmbackup` file appears in `Character Presets` and includes every preset,
the CET folder layout, empty CET folders, and current settings.

Choose a filename under **Backup File**, then select **Import Selected Library
Backup** to restore it. An empty library receives the original layout. If
names are already in use, imports go into an **Imported Library** folder
without replacing your existing items.

A backup cannot exceed 256 MB. **Delete Selected Backup Permanently** removes
only the selected `.cpmbackup` file, leaving installed presets alone. Check
the displayed filename before confirming deletion.

---

## Appearance history

Before a normal load, the mod saves your current appearance for recovery.
Up to five different entries are kept, with identical copies skipped. Restoring
an older entry creates a new safety save first.

Use **Undo Last Load** or **Recovery History** in the simple menu. In CET,
open **Load & Restore Appearance** and use **Restore Previous Appearance**
or **Appearance History** to choose an entry.

History is separate from your preset library. Its files are stored in
`Data/Recovery/Appearance History`.

---

## Move items to Trash

Presets, shared-folder files, and whole folder groups can be moved to Trash.
Folder groups remember nested folders, including empty ones. Restore items
through **Delete & Restore Items** in CET when you want them back.

If a name is in use, the restored item gets a `Copy` name instead of replacing
anything. Imported Windows folders are removed only when empty; unknown files
are never deleted.

---

## Interrupted actions

If the game closes during a move, rename, Trash action, or restore, the mod
tries to finish or undo that action at the next startup. If Trash cannot be
read safely, the last good list and folder details are kept.

---

## Permanent deletion

**Empty Trash Permanently** deletes trashed presets and folder groups.
That cannot be undone by the mod. The simple menu only moves a preset to Trash;
restoring and permanent deletion are available through CET.

</details>

<details>
<summary><strong>Troubleshooting, FAQ, and settings</strong></summary>

## Activity Log

Select **Log** at the top of CET, or open it through Help. You can read or
copy the log in game. Its file is here:

```text
bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Data/Logs/Activity.log
```

Each full game launch starts a new log. The previous file is dated and moved
to the archive, which keeps the ten newest logs. Entries cover startup, menu
connections, file actions, loading, warnings, errors, and missing choices.
**More Technical Details** shows information for tracking down problems.

If an option check takes at least 0.05 seconds, a warning separates the time
spent reading the game from the time spent matching presets.


For help or to report a problem, join [**Discord**](https://discord.com/invite/mUGHmQxHG8).
Include your newest **Activity Log**, what you were doing, and what went wrong.
Check the common issues below for steps you can try first.

---

## Bug FAQ

### The menu says the library is connecting

Wait briefly for CET to load. If the message stays, check CET, RED4ext,
redscript, and Codeware, then reinstall the complete mod and fully restart
the game. Changes to redscript files require a new game session.

---

### The simple menu is missing after an update

Use the complete CET manager when CET and its required game functions support
your version. Your files are still in the same library. Update the mod and
its frameworks when compatible versions become available.

---

### Game updates

An update can change the character screens or the functions used by the loader.
CET, RED4ext, redscript, and Codeware may also need updates.

If only the simple menu stops working, use the complete CET manager once its
requirements support the new game version. It uses the same files. A missing
panel does not mean your presets were deleted.

The DLL provides a file catalog that CET checks against its own folder reader.
If the catalog is missing, late, outdated, or different, CET uses its own safe
folder list. If both the panel and file service are unavailable, a small reminder in the
character screen points to CET.

---

### The CET window is missing

Select **Advanced Preset Manager** to open CET and show the window.
If it does not open, keep the game in focus, release other keys, and check that
the native file service is installed. You can also press your CET binding yourself.

---

### Loading screen after closing an editor

Cyberpunk can remain on a loading screen after an editor closes, even without
this mod. Clothing, wardrobe outfits, Equipment-EX, and detailed outfits may
make this more likely.

Remove all clothing and choose **No Outfit** before opening the editor if this
happens. Put your clothes and outfit back on afterward.

---

### A preset reports missing choices

Check the character mods, versions, body and eye choices, and load order used
to create it. **Check Compatibility** gives more detail. Correct the appearance
and save a new format-8 preset after changing your setup.

---

### A load reaches the safety limit

If loading exceeds the safety limit, CPM stops further changes and releases the menu and camera controls. Changes already applied stay visible, so check the appearance and include the Activity Log when reporting the timeout.

---

### Old cyberware or another old choice stays visible

Wait for the final status before confirming your appearance. The loader reads
fresh option lists as the game updates and waits for cyberware and other linked
choices to settle. It checks saved values, but it cannot inspect the rendered
character for you.

If an old choice remains, include the newest Activity Log when reporting it.
Name the preset and the choice that stayed visible so I can follow the load.

---

## Search Help

Open **Help**, type a word or phrase, then select **Search**. Topics pause
while you type. Try words such as `share`, `bug`, `clothing`, `ACU`, `backup`,
`Trash`, or `favorite`; matching also uses related terms.

---

## Settings

Select **Settings** at the top of the manager, then use **Preset Sort Order**
to sort by name or last changed date. Key assignments remain under
**CET Bindings**.

The mod saves settings to `Data/Config/Config.txt` and updates that file when
you change them through CET. Do not edit it while the game is running.

---

## Data folders

The mod stores settings, file lists, recovery data, Trash, and logs under
`Data` in its CET folder:

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

</details>

<details>
<summary><strong>About this mod</strong></summary>

## License

All Rights Reserved, by **Dnydd (formerly known as dklyntly)**.
The same license can cover my mods for Minecraft, Cyberpunk 2077, and other games.

You may edit configuration files and share your own presets. Copies of my mod,
modified releases, ports, and reused code or assets need my written permission.
Public and private modpacks and collections may include and redistribute
unmodified official releases with credit, a link to the official page, and
the license and original notices.
Standalone mirrors, modified releases, and paid redistribution need my written
permission. Earlier versions keep the permissions that came with those copies.
Private code edits need permission, except when preparing a direct contribution.

*Translations, bug fixes, compatibility patches, and similar changes can be
approved with my **prior written permission**. Approval must cover publishing
before you upload anything; credit me, link the original mod, and follow
the agreed limits. It does not automatically allow a full-mod reupload.*

You may submit fixes for me to use in my mods without further permission or payment.
Contributors keep ownership of their original work; their grant also covers
future monetized releases without compensation or a share of revenue.

Written approval must come from my contact email or an account identified on
my official mod page or repository. The license includes warranty and liability
limits where the law allows them, while preserving mandatory protections.

Read [the full All Rights Reserved license](LICENSE) for the terms and approved uses.

---

## Source and development archive

I keep the stage reports and tests on the [**dev-archive branch**](https://github.com/DKLYNTLY/Character-Preset-Manager-CET-/tree/dev-archive).
Plans, fixtures, verification scripts, and scratch work belong there too.
The main branch holds the files needed to build and run the mod, along with
this README, the license, and the changelog. Release downloads contain only
runtime files.

---

## Personal presets

My character shown in the screenshots is not included. I do not plan to share my personal preset as a download.

---

## Credits

I credit **ChatGPT by OpenAI** for helping me build the UIs, diagnose issues,
and write and review parts of the Lua, redscript, documentation, and release
checks. This mod is not all AI-generated; I promise there is human code in
here too. I made the final design and release choices and reviewed the work
before publishing it.

I created and maintain Character Preset Manager as **Dnydd (formerly known as dklyntly)**.

[ACU - Character Preset Manager](https://www.nexusmods.com/cyberpunk2077/mods/3850)
by **PotatoOfDoom** came before this project. I kept support for compatible ACU
presets so existing collections can still be used. My format, code, menus,
loader, and controls are separate implementations.

[Character Customization Anywhere](https://www.nexusmods.com/cyberpunk2077/mods/3930)
by **keanuWheeze** inspired my Full Appearance Editor.

I thank the authors and contributors of all four required frameworks:

- [**Cyber Engine Tweaks**](https://www.nexusmods.com/cyberpunk2077/mods/107) by **yamashi** and its contributors, for scripting and the complete menu.
- [**RED4ext**](https://www.nexusmods.com/cyberpunk2077/mods/2380) by **WopsS** and its contributors, for the native file service.
- [**redscript**](https://www.nexusmods.com/cyberpunk2077/mods/1511) by **jac3km4** and its contributors, for the simple menu scripts.
- [**Codeware**](https://www.nexusmods.com/cyberpunk2077/mods/7780) by **psiberx** and its contributors, for the simple menu's UI tools and game access.

I credit CD Projekt Red for Cyberpunk 2077 and its character system.
I also appreciate the modding community's testing, research, and feedback.

</details>
