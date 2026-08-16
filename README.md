<h1 align="center">Character Preset Manager (CET)</h1>

<p align="center"><em>Save, load, organize, and share complete Cyberpunk 2077 character appearances through CET.</em></p>

<p align="center">
  <strong><a href="https://www.nexusmods.com/cyberpunk2077/mods/31886">Download on Nexus Mods</a></strong>
  ·
  <a href="https://discord.com/invite/mUGHmQxHG8">Discord and support</a>
  ·
  <a href="CHANGELOG.md">Full changelog</a>
</p>

<p align="center"><strong>Current version: 3.0.3</strong></p>

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
- Can clear visible appearance options that are not part of the preset.
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

New presets use format 7. Older Character Preset Manager presets and compatible ACU `.preset` files can still be loaded. New presets and shared folders use the current system.

Do not keep an older copy of the mod beside the current one. Version 3.0.3 does not move loose files left by older releases. For a clean update:

1. Back up the presets and `.cpmfolder` files you want to keep from `Character Presets`.
2. Remove the old Character Preset Manager folder.
3. Install version 3.0.3.
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
5. Wait for the green **Preset Fully Applied** message.

Cyberpunk may refresh the editor several times. The mod waits and continues on its own. Select **Cancel Loading** if you need to stop.

Loading stops if the same options are still missing after three checks. The mod does not guess. Missing options usually mean that character-option mods, their versions, or their load order changed. Correct the appearance and save the preset again.

### What a preset saves

Format-7 presets store each visible option, its position in the editor, its selected choice when a stable name is available, and its number in the choice list. They can also store the source, date, notes, and tags.

This information helps the mod find a saved choice after CCXL adds items to a list. **Force Full Load** can also try the saved editor position when a related option was renamed. Always check the result after changing option mods.

Older presets only know the option name and number. If new hairstyles shift the list, an older preset may choose the wrong hairstyle because it cannot know the original choice. Correct it once and save the preset again in the current format.

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
- A single `.preset` file does not include its CET folder assignment.

For safety, an imported preset cannot be larger than 1 MB or contain more than 8,192 lines and 4,096 valid options. An option name cannot exceed 256 bytes, and an option number must fit in an unsigned 32-bit value.

### Share a complete folder

A `.cpmfolder` file contains the selected CET folder, all folders inside it, and every preset in that group. Notes, tags, and other supported preset details are included.

#### Export a folder

1. Open **Folders** and choose a non-empty folder.
2. Select **Export Folder for Sharing**.
3. Find the new `.cpmfolder` file in `Character Presets`.
4. Send that one file.

A shared folder can contain up to 512 presets and cannot be larger than 32 MB. An empty folder cannot be exported.

To remove only the exported file, choose **All Presets**, open **Shared Folder Files**, select the file, and choose **Move Selected File to Trash**. This does not remove the original folder or its presets. You can restore the file under **Delete & Restore** or remove it with **Empty Trash Permanently**.

#### Import a folder

1. Put the downloaded `.cpmfolder` file in `Character Presets`.
2. Open Character Preset Manager and expand **Folders**.
3. Choose **All Presets**. The import button appears only here.
4. Select **Install Shared Folders**.

The mod rebuilds the complete folder group and leaves the `.cpmfolder` file in place. It remembers the filename, file contents, and imported folder in `Data/Catalog/Imported Bundles.txt`.

An unchanged bundle is skipped while its imported folder still exists. You can import it again after deleting that folder. You can also import a changed bundle that uses the same filename. If a folder name is already in use, the new folder gets a safe `Copy` name. A failed import is not marked as complete, so you can fix the file and try again.

After a successful import, **Shared Folder Files** can move the source file to Trash without removing the imported folder or presets. The list updates when the CET overlay opens, when you select **Refresh**, and after any shared-folder action.

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

Yes. Compatible preset files can still be loaded. New presets use format 7.

### Can ACU or Character Customization Anywhere stay installed?

No. Remove them and restart the game.

### Can Photo Mode or Appearance Menu Mod stay installed?

Yes, but do not try to save or load inside their menus. Use a supported character screen.

### Is the character shown in the screenshots included?

No. The screenshots show the mod. The creator's personal character preset is not included and is not planned for release.

</details>

<details>
<summary><strong>Version 3.0.3 summary</strong></summary>

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

AI was used only to help plan and improve the CET menu's layout and appearance. The creator made the final design choices, changed the AI-assisted work to fit the mod, and manually tested saving, loading, folders, recovery, and gameplay features.

### Credits

- **Character Preset Manager (CET):** Created and maintained by **dklyntly**.
- **[ACU - Character Preset Manager](https://www.nexusmods.com/cyberpunk2077/mods/3850):** Created by **PotatoOfDoom**. ACU inspired this project. Character Preset Manager can read compatible ACU presets so existing preset collections are not lost, but it uses its own current format and controls.
- **[Character Customization Anywhere](https://www.nexusmods.com/cyberpunk2077/mods/3930):** Created by **keanuWheeze**. Its way of opening character customization during normal play inspired the Full Appearance Editor.
- **[Cyber Engine Tweaks](https://www.nexusmods.com/cyberpunk2077/mods/107):** Created by **yamashi** and maintained by its contributors. CET provides the scripting and menu system used by this mod.
- **CD Projekt Red:** Creator of Cyberpunk 2077 and its character system.
- **Cyberpunk 2077 modding community:** Testing, research, compatibility information, and feedback.

The mods named as inspiration are not included or required. Do not install ACU or Character Customization Anywhere beside Character Preset Manager.

### Links

- [Download on Nexus Mods](https://www.nexusmods.com/cyberpunk2077/mods/31886)
- [GitHub source code](https://github.com/DKLYNTLY/Character-Preset-Manager-CET-)
- [Discord community and support](https://discord.com/invite/mUGHmQxHG8)
- [Full changelog](CHANGELOG.md)
- [MIT license](LICENSE)

</details>
