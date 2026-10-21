# Character Preset Manager (CET)

**Version 3.1.4**

Save a character appearance, load it later, and keep your presets organized
inside a Cyberpunk 2077 appearance editor. The main tools need redscript,
RED4ext and Codeware. You can also install CET for force loading and technical
information.

I have not tested this version inside the game. The [validation
report](native/verification/VALIDATION.md) lists the checks I have completed and
those that still need to be done.

## Requirements and installation

This build is for Cyberpunk 2077 2.31. Install RED4ext 1.30.0, redscript 0.5.31
and Codeware 1.20.3, or newer versions that work with this build. CET 1.37.1 is
optional. Install it if you want the technical menu or your existing CET key
assignments. You do not need CDPR's REDmod DLC or mod deployment.

1. Install the requirements. Remove Character Customization Anywhere if
   installed, then close and restart the game before using the Full Appearance
   Editor.
2. Extract `Character Preset Manager (CET) 3.1.4.zip` into the main Cyberpunk
   2077 folder. Merge its `bin`, `r6` and `red4ext` folders with those already
   there.
3. Open new-game creation, an apartment mirror, a supported ripperdoc appearance
   screen, or the Full Appearance Editor. Choose **Manage Presets** to organize
   your library.

Install the complete package so the DLL, which runs the preset service, matches
the scripts. If any files are missing or from another build, reinstall the full
package and restart the game.

## Updating and moving your files

Back up both old folders in full: **Character Presets** and **Data**. Data holds
your folder layout, settings, recovery files, saved appearance history and
Trash. Remove `init.lua` and the `modules` folder from the old CET mod folder,
along with `r6/scripts/CharacterPresetManager`. Install this package next. Leave
the old Character Presets and Data folders here for the first start:

```text
bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/
```

When you first open the library, the mod copies those folders here:

```text
red4ext/plugins/CharacterPresetManager/
```

The mod checks each copy and keeps the original files. If copying stops, it
resumes on the next attempt. Matching files need only one destination copy. When
old files differ from those at the new location, the mod saves the old copies
under `Data/Migration/Conflicts` and stops the tools for review.

Back up both locations before resolving a conflict. Review the differing files,
then make the original and destination match or remove the old conflicting copy
after saving it elsewhere. Reopen the editor to try again. Never delete your
only copy of a preset or recovery record. The mod records completion in
`Data/Migration/Completed.txt`.

Once copying is complete, use the library in the native folder. The mod will not
copy later changes from the old CET library on its own. Keep the originals until
you have checked the new library and backed it up somewhere else. Bundled
presets are copied only if their destination file is missing.

## Saving and loading

Search for a preset and select its row. Choose **Load** to apply it, then wait
for the result before confirming the editor. **Cancel Load** stops the remaining
changes. Choices already applied stay visible; use Recovery to restore an
earlier appearance.

Enter a name and choose **Save Preset**. An existing name requires **Confirm
Overwrite**. **More Actions** includes save locations, Refresh, compatibility
checks and recovery. **Hide Presets** clears the panel so you can reach the
randomizer controls. **Show Presets** restores it with its search, selection and
scroll position. The panel starts visible each time you open an editor. You can
still see load progress and cancel a load while the panel is hidden.

Loading does not change an existing character's gender or body type. Use one of
the supported appearance screens. Photo Mode and Appearance Menu Mod do not
provide the editor data this mod needs.

## Managing your library

**Manage Presets** opens inside the appearance editor. **Back to Editor**, or
the Back control, returns to the compact panel. There is no pause-menu entry.

- **Presets:** Edit notes and tags, favorite, duplicate, rename, move, compare
  or send presets to Trash. For Rename or Move, enter the full destination, such
  as `My Folder/My Preset`. Mark several presets for Move Marked or Trash
  Marked.
- **Folders:** Create, rename, copy or remove folders. Enter source and
  destination in the labeled fields. Removing a folder moves its presets into
  the parent folder. Save Location chooses where new presets go.
- **Sharing:** Preview and import `.cpmfolder` files and `.cpmbackup` backups.
  Export a folder or marked presets, or create a complete library backup. Files
  are saved in the native Character Presets folder. Imports keep your existing
  presets, placing new copies in a separate folder if names overlap.
- **Recovery:** Restore Trash items or saved appearances. Undo Last Load
  restores the appearance saved before loading. Read Activity Log for details
  about each result. Empty Trash, Clear History and Delete Backup permanently
  remove saved files and require a second selection to confirm.
- **Settings:** Choose name or date order and optional editor/panel keys. Select
  a binding, then press the key. Backspace clears it.
- **Help:** Read controls, compatibility and current file locations.

Each page shows up to 96 presets. In a larger library, select Next Page or
Previous Page to change pages. Scrolling moves through the page you are on.

## File limits, folders and recovery

A preset can hold up to 1 MB, 16,448 lines and 4,096 valid options. Option names
can use at most 256 bytes. Choice numbers must fit an unsigned 32-bit value,
which means a whole number from 0 to 4,294,967,295. A shared folder can contain
up to 512 presets and 32 MB. A group must contain a preset before you can export
it. A library backup can contain up to 256 MB. Backups include presets, folder
organization and the preset sort setting, but are separate from appearance
history. Native key assignments stay in `Data/Config/Native Keys.txt`. Back up
the complete Data folder if you want to keep those assignments too.

The mod keeps up to five different appearance-history entries. It skips an
appearance if it matches one already saved. Before loading a preset or restoring
history, it saves the current appearance. History is under
`Data/Recovery/Appearance History`.

Folders created in the manager organize the library without creating matching
Windows folders. The mod stores that folder list in `Data/Catalog/Virtual
Folders.txt`. Format-8 preset headers also record names and folders so missing
catalog entries can be rebuilt. `/` means All Presets. Physical folders inside
Character Presets are discovered too. The mod does not support linked folders or
Windows junctions, which point to another location. It stops scanning physical
folders beyond 12 nested levels or when it cannot check an entry safely. Unknown
files are kept. Use Refresh after changing files outside the game.

**Trash Folder** keeps a complete folder group, including nested empty folders.
Recovery lists these groups separately. Select a group and choose **Restore
Folder** to bring it back. **Restore Shared File** restores a `.cpmfolder`
source file. Removing a shared source file does not remove presets already
imported from it. If a restored item has the same name as an existing item, the
mod keeps both copies under separate names. If a file action stops before it
finishes, the mod completes it or recovers the files the next time you open the
library.

The **Bulk** tab can mark the current search page, clear marks, move or trash
marked presets, or export them together. Marks can span pages and folders.
Preview shared files or backups before importing or deleting them. If that file changes, preview it once more before you continue. The mod skips shared files
that have not changed while their imported folder still exists. It keeps the
original shared files in place.

Settings are saved in `Data/Config/Config.txt`; native keys are in
`Data/Config/Native Keys.txt`. Avoid editing these files while the game runs. As
an activity log grows, the mod starts a new file and keeps ten older files in
`Data/Logs`. Choose Check Compatibility to see which choices match, will change,
are missing, repeat, are invalid, or are extra. During loading, the mod stops
trying missing choices after repeated checks. I have not measured this release's
performance inside the game.

## Optional keys and CET tools

Native keys work without CET. Assign them inside Manage Presets, under Settings.
Keys do nothing while you type. To use the panel key, open an appearance editor
first. Close CET before using keys. Existing CET key bindings can still trigger
the same actions. To use those keys without CET, assign them again in the native
settings.

With CET installed, open its overlay and choose **Character Preset Manager -
Technical Tools**. Select a preset in the game panel first. **Force Full Load**
asks for confirmation before using less certain matches where it is safe to do
so. It cannot use a saved number to replace a missing named custom choice. Check
the appearance when loading finishes. **Read Editor Options** and **Read
Activity Log** provide technical information. The same preset service session
stays open when you open or reload CET.

## Older presets and ACU import

New presets use readable format 8. They have plain headings and labeled Editor
slot and Saved choice lines to identify each saved option. Older compatible CPM
presets and ACU 3.0.0 JSON, 3.0.1 JSON, and 3.2.1 text and JSON layouts remain
readable. The mod labels formats 7 and 8 as CPM presets. The mod leaves older
files unchanged when it finds or loads them. An overwrite or a save of notes or tags updates that file to format 8.

Compatible `.preset` files are copied from:

```text
bin/x64/plugins/cyber_engine_tweaks/mods/AppearanceChangeUnlocker/character-presets
```

Imported copies appear under **ACU Presets** in the native library. The original
ACU files stay where they are, with their contents unchanged. Subfolders are
preserved. The mod skips files that have not changed and keeps edits you make to
imported copies. ACU may remain installed for importing; use Character Preset
Manager to load its copies. Do not load from both mods at once. Removing ACU
after import does not delete imported copies.

If imports are missing, check folder spelling and the `.preset` extension. Each
file must contain data and be no larger than 1 MB. Restart the game fully and
select Refresh. If files are still missing, read the Activity Log.

ACU files lack the stable editor-slot and saved-choice details that current CPM
files store. Choices added through CC or CCXL appearance mods may shift when you
change those mods, their versions, or their load order. Check Compatibility,
review the appearance and save a corrected format-8 preset. A readable preset
may still need appearance mods you have not installed. Missing, repeated or
inactive choices can produce a partial load.

## Troubleshooting and limits

Activity logs are under `red4ext/plugins/CharacterPresetManager/Data/Logs`. When
asking for help, include the message about the problem. Wardrobe changes made by
this mod are restored after leaving the editor; an outfit already disabled by
the game is left alone. Some users report that removing clothing and choosing No
Outfit helps with loading problems. This workaround may not fix yours. My
personal character preset shown in screenshots is not included, and I do not
plan to release it.

## AI disclosure

I used AI to help plan, write, and review parts of the interface, Lua, C++,
redscript, documentation, and release checks. I chose the final design and what
went into each release. Before publishing, I reviewed the finished work.

## Credits

I created and maintain Character Preset Manager as **dnydd (formerly
dklyntly)**.

[ACU - Character Preset
Manager](https://www.nexusmods.com/cyberpunk2077/mods/3850) by **PotatoOfDoom**
is the predecessor to this project. I built Character Preset Manager as its
successor and kept support for compatible ACU presets so existing collections
are not lost. I wrote my own preset format, code, menus, loading system and
controls.

[Character Customization
Anywhere](https://www.nexusmods.com/cyberpunk2077/mods/3930) by **keanuWheeze**
inspired my Full Appearance Editor.

[Cyber Engine Tweaks](https://www.nexusmods.com/cyberpunk2077/mods/107) was
created by **yamashi** and is maintained by its contributors. Character Preset
Manager uses CET for optional technical tools. RED4ext runs the preset service.
The appearance tools and game menus use redscript and Codeware.

I credit CD Projekt Red for Cyberpunk 2077 and its character system. I also
thank the modding community for testing, research, compatibility information and
feedback.

## License and permissions

I publish this mod as **dnydd (formerly dklyntly)** under my DarklyStudios
copyright. All rights are reserved except for the uses allowed in
[LICENSE](LICENSE). This mod is not offered under the MIT license.

You may include the mod in public or private modpacks and make the configuration
changes described in the license. You need my written permission to distribute a
modified or standalone version. See the license for the full terms and contact
details. The download includes separate licenses for third-party libraries.

## Links

[Download on Nexus Mods](https://www.nexusmods.com/cyberpunk2077/mods/31886) ·
[GitHub source](https://github.com/DKLYNTLY/Character-Preset-Manager-CET-) ·
[Discord and support](https://discord.com/invite/mUGHmQxHG8) ·
[Full changelog](CHANGELOG.md) · [License and permissions](LICENSE)
