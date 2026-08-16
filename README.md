<h1 align="center">Character Preset Manager (CET)</h1>

<p align="center"><em>Save, load, organize, and share complete Cyberpunk 2077 character appearances through CET.</em></p>

<p align="center">
  <strong><a href="https://www.nexusmods.com/cyberpunk2077/mods/31886">Download on Nexus Mods</a></strong>
  ·
  <a href="https://discord.com/invite/mUGHmQxHG8">Discord and support</a>
  ·
  <a href="CHANGELOG.md">Full changelog</a>
</p>

<p align="center"><strong>Current version: 3.0.4</strong></p>

> [!IMPORTANT]
> Remove **Appearance Change Unlocker (ACU)** and **Character Customization
> Anywhere** before using this mod. They change the same character screens and
> cannot be used with Character Preset Manager. Restart the game after removing
> either mod.

<details open>
<summary><strong>What the mod does</strong></summary>

- Saves and loads complete character appearances, including visible CC and CCXL options.
- Opens the full game character editor during normal play.
- Gives apartment mirrors the full set of character-creation options.
- Loads a preset with one click and waits when the editor refreshes.
- After applying a preset, can clear visible appearance options that are not part of it.
- Finds presets with search and shows whether the current editor has the needed options.
- Organizes presets in folders and folders inside folders, with no set limit.
- Copies presets or complete folder groups.
- Stores optional notes and tags with new presets.
- Moves presets and folders to Trash so they can be restored.
- Shares one preset as a `.preset` file or a complete folder as a `.cpmfolder` file.
- Shows actions, warnings, and errors in an activity log.

</details>

<details>
<summary><strong>Requirements and installation</strong></summary>

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

New presets use format 8. Its file layout is easier to read, but it keeps the
same appearance information introduced with format 7. Older Character Preset
Manager presets and compatible ACU `.preset` files can still be loaded.

Existing preset files are not rewritten just because the mod finds them. Saving
over an older preset updates it to format 8. Saving its optional notes or tags
also updates that file. Keep a backup before replacing any preset you may still
want to use with an older mod version.

Do not keep an older copy of the mod beside the current one. Version 3.0.4 does not move loose files left by older releases. For a clean update:

1. Back up the presets and `.cpmfolder` files you want to keep from `Character Presets`.
2. Remove the old Character Preset Manager folder.
3. Install version 3.0.4.
4. Put your saved presets and bundles back in `Character Presets`.

</details>

<details open>
<summary><strong>Save and load presets</strong></summary>

### Save a preset

1. Open the **Full Appearance Editor**, a mirror, a ripperdoc character screen, or the new-game editor.
2. Open Character Preset Manager in CET.
3. Under **Save Preset**, open **Choose Save Destination**.
4. Choose a folder or **All Presets**.
5. Enter a name and select **Save New Preset**.

If that name already exists, confirm **Replace Existing Preset** only when you want to overwrite it.

### Load a preset

1. Open one of the supported character screens listed above.
2. Choose a preset under **Load Preset**.
3. Check its folder, number of saved options, source, details, and compatibility summary.
4. Select **Load Selected Preset** once.
5. Wait for the final result. A green message means every saved option was
   confirmed. A yellow message names anything the game did not confirm.

Cyberpunk may refresh the editor several times. The mod waits and continues on
its own. It applies the saved appearance before clearing any remaining options,
then checks the preset again. Select **Cancel Loading** if you need to stop.

The compatibility summary refreshes while the mod and character editor are open.
It updates after the editor changes without making you select a different preset
and switch back. Other selected-preset details update at the same time.

Automatic loading gets a fresh option list after every change. It reuses only
checked names, positions, and saved-choice matches while the editor structure
remains the same. If a change adds, removes, disables, or rearranges an option,
the mod discards and rebuilds that information. It also checks quickly after
ordinary changes and waits longer for hairstyles and other changes that rebuild
related options. While an ordinary change is still pending, it checks only that
option until the value changes or the time limit is reached. A full check always
runs before the next option is applied.

Loading stops if the same options are still missing after three checks. The mod does not guess. Missing options usually mean that character-option mods, their versions, or their load order changed. Correct the appearance and save the preset again.

### What a preset saves

Format-8 presets store each visible option, its position in the editor, its selected choice when a stable name is available, and its number in the choice list. They can also store the source, date, notes, and tags.

This information helps the mod find a saved choice after CCXL adds items to a
list. If a hairstyle replaces a related option under a new name, a current
preset can match it automatically when its editor slot and unique saved choice
both agree. **Force Full Load** can try less certain editor-position matches.
Always check the result after changing option mods.

Older presets only know the option name and number. If new hairstyles shift the list, an older preset may choose the wrong hairstyle because it cannot know the original choice. Correct it once and save the preset again in the current format.

### Readable preset files

Format 8 replaces encoded lines such as `%20` and `%3A` with plain text. Each
option keeps its original `OptionKey:SavedNumber` line, followed by readable
details when they are available:

```text
# Character Preset Manager (CET) preset
# Format: 8
# Source: Character Preset Manager (CET)
# Created: 2026-08-15 13:19:27
# Modified: 2026-08-15 13:19:27
# Notes:
# Tags:

LocKey#9502141975964618858:50
# Editor slot: hairstyle
# Saved choice: options:51
```

The mod ignores normal comment lines when reading a preset. This keeps the file
easy to inspect without treating its headings as damaged data.

</details>

<details>
<summary><strong>Organize presets and folders</strong></summary>

### Basic folder use

- Select a folder row under **Load Preset** to open or close it.
- Presets without a folder appear under **All Presets**.
- Choose a folder or **All Presets** before saving or moving a preset.
- To make a folder inside another folder, select the parent folder first.
- Copies appear beside the original and use names such as `Copy` and `Copy 2`.
- Copying a folder also copies every preset and folder inside it.
- Renaming a preset also renames its `.preset` file.
- Notes and tags are under **Rename & Copy > Optional Preset Details**.

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
<summary><strong>Share and install presets</strong></summary>

Preset files and shared folders go here:

```text
bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Character Presets
```

### Share one preset

- To share an appearance, send its `.preset` file.
- To install a preset, place its file in `Character Presets` or in a Windows folder inside it.
- Select **Refresh** under **Load Preset** after changing files outside the game.
- Startup uses the saved preset list instead of fully reading every preset and
  every Trash file. A preset is read in full when you select or use it. Opening
  the CET overlay does not scan the library again. This keeps large collections
  responsive.
- A single `.preset` file does not include its CET folder assignment.

For safety, an imported preset cannot be larger than 1 MB or contain more than
16,448 lines and 4,096 valid options. An option name cannot exceed 256 bytes,
and an option number must fit in an unsigned 32-bit value. The higher line limit
allows the readable detail lines and spacing used by format 8.

### Share a complete folder

A `.cpmfolder` file contains the selected CET folder, all folders inside it, and every preset in that group. Notes, tags, and other supported preset details are included.

#### Export a folder

1. Open **Folders** and choose a non-empty folder.
2. Select **Export Folder for Sharing**.
3. Find the new `.cpmfolder` file in `Character Presets`.
4. Send that one file.

A shared folder can contain up to 512 presets and cannot be larger than 32 MB. An empty folder cannot be exported.

The mod writes and installs shared folders one preset at a time. Large bundles
do not need to be held in memory all at once.

To remove only the exported file, choose **All Presets**, open **Shared Folder Files**, select the file, and choose **Move Selected File to Trash**. This does not remove the original folder or its presets. You can restore the file under **Delete & Restore** or remove it with **Empty Trash Permanently**.

#### Import a folder

1. Put the downloaded `.cpmfolder` file in `Character Presets`.
2. Open Character Preset Manager and expand **Folders**.
3. Choose **All Presets**. The import button appears only here.
4. Select **Install Shared Folders**.

The mod rebuilds the complete folder group and leaves the `.cpmfolder` file in place. It remembers the filename, file contents, and imported folder in `Data/Catalog/Imported Bundles.txt`.

An unchanged bundle is skipped while its imported folder still exists. You can import it again after deleting that folder. You can also import a changed bundle that uses the same filename. If a folder name is already in use, the new folder gets a safe `Copy` name. A failed import is not marked as complete, so you can fix the file and try again.

After a successful import, **Shared Folder Files** can move the source file to Trash without removing the imported folder or presets. The list updates when you select **Refresh** and after any shared-folder action.

</details>

<details>
<summary><strong>Trash and restore</strong></summary>

- Moving a preset to Trash keeps it available for recovery.
- Under **Folders**, you can move a folder and everything inside it to Trash.
- **More Trash Options** lets you select several presets from the current search results.
- **Select All Visible** and **Clear Selection** make large selections easier.
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
<summary><strong>Compatibility and known problems</strong></summary>

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

If this happens, remove all clothing and choose **No Outfit** before opening the editor. Put everything back on afterward. The optional yellow clothing message does not mean that the mod failed.

</details>

<details>
<summary><strong>Settings and files</strong></summary>

### Settings

- **Customization Reminder: Enabled/Disabled** turns the character-screen reminder on or off. It starts on and stays off after you disable it.
- **Preset Sort** sorts presets by name or by the most recently changed preset.
- **Reload Settings File** applies manual changes without restarting.

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

</details>

<details>
<summary><strong>Help and common questions</strong></summary>

### Activity log

Open **Help > Activity Log**, then select **Open Activity Log**. You can read or copy the log from CET. The file is stored here:

```text
bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Data/Logs/Activity.log
```

Each full game launch starts a new log. The old log is saved with its date and time, and the 10 newest old logs are kept. The log includes startup details, preset actions, load results, warnings, errors, inactive options, and missing saved options. Developer information is under **Advanced Technical Details**.

### Can I use older Character Preset Manager or ACU presets?

Yes. Version 3.0.4 can load older Character Preset Manager formats and compatible
ACU presets. New and updated presets use format 8.

### Can ACU or Character Customization Anywhere stay installed?

No. Remove them and restart the game.

### Can Photo Mode or Appearance Menu Mod stay installed?

Yes, but do not try to save or load inside their menus. Use a supported character screen.

### Is the character shown in the screenshots included?

No. The screenshots show the mod. My personal character preset is not included,
and I do not plan to release it.

</details>

<details>
<summary><strong>Version 3.0.4 summary</strong></summary>

- Adds the readable format-8 preset layout.
- Removes percent-encoded text from newly saved preset headers and option details.
- Keeps older Character Preset Manager formats and compatible ACU presets readable.
- Updates an older preset to format 8 when it is overwritten or when its optional
  notes or tags are saved.
- Keeps the format-7 CCXL choice and editor-position information in the new layout.
- Prevents comments in older preset files from changing how their options load.
- Lets large valid presets finish instead of stopping at a fixed 400-pass limit.
- Makes the option check use the same saved choices and editor positions as the
  loader.
- Keeps the menu faster by scanning external file changes only when you select
  **Refresh**.
- Strengthens file checks, backup recovery, and startup file limits.
- Keeps lightweight preset and Trash records at startup, then reads a preset in
  full only when it is selected or used.
- Makes automatic loading reuse safe work between checks and wait less between
  stable options.
- Applies saved options before clearing remaining appearance choices, then checks
  the preset again after every cleanup change.
- Waits for each live option value to change or for a dependent option to
  disappear before continuing. If the game keeps returning an old value, the
  mod reports the option as unconfirmed instead of repeatedly applying it or
  later claiming that every option was confirmed.
- Limits full choice-list checks to options used by the preset. This avoids the
  continuous slowdown found during the first instrumented 3.0.4 game test.
- Checks only the pending ordinary option between full safety checks, and avoids
  building temporary loader records for unrelated options. A full check still
  runs before another option is applied.
- Matches a renamed hairstyle-dependent option automatically only when its
  editor slot and unique saved choice both identify the replacement.
- Treats a hidden dependent option saved as zero as already clear instead of
  reporting it as missing.
- Records option retrieval, full scanning, targeted checks, choice matching,
  update waiting, structure changes, and safe metadata reuse in the Activity Log
  for loader testing.
- Refreshes the selected preset's compatibility text while the editor changes.
- Streams shared-folder export and import one preset at a time.
- Preserves the last good Trash list when the Trash folder cannot be read.
- Caches Trash lists and folder totals until Trash changes.
- Reduces repeated loading warnings and activity-log file work.
- Uses the first Refresh comparison instead of comparing every preset twice.
- Fixes numbered activity-log archives so they stay in the Archive folder.
- Fixes the CET startup failure in the first revised 3.0.4 build and adds a
  release check that prevents the same Lua limit from being reached again.

- New presets store stable information about editor options and selected choices. This helps them keep the correct CCXL choice when new items change a list.
- **Force Full Load** can try a saved editor position when a related option was renamed. The mod warns when an older preset does not contain the information needed for this check.
- The first window position now uses the usable screen area.
- A preset no longer shows an unnecessary "already in this folder" message just after it was moved successfully.
- Mod files are grouped under `Data`, while presets and shared folders stay in `Character Presets`.
- Imported `.cpmfolder` files remain unchanged. The mod remembers finished imports and skips a bundle only when the file and imported folder are still the same.
- Search, Refresh, folder counts, preset details, compatibility checks, loading cancellation, safe Trash recovery, folder sharing, notes, tags, settings, and clearer error reports are included in the current interface.

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
