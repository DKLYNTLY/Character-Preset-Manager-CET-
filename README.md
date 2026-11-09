<h1 align="center">CHARACTER PRESET MANAGER</h1>

<p align="center"><strong>Your character. Your presets.</strong><br>
<em>Save, load, and share your looks. Supports ACU preset files.</em></p>

<p align="center">If you enjoy my mods, you can support my work through Ko-fi or PayPal.</p>

<p align="center">
  <a href="https://ko-fi.com/A3G129JCLF"><img src="https://ko-fi.com/img/githubbutton_sm.svg" alt="Support me on Ko-fi"></a>
  <a href="https://www.paypal.com/ncp/payment/7ZKG8YG6GCERC"><img src="https://img.shields.io/badge/Support%20via-PayPal-0070BA?style=for-the-badge&amp;logo=paypal&amp;logoColor=white" alt="Support via PayPal" height="30"></a>
</p>

<p align="center">
  <a href="https://www.nexusmods.com/cyberpunk2077/mods/31886"><strong>DOWNLOAD</strong></a>
  • <a href="https://discord.com/invite/mUGHmQxHG8"><strong>DISCORD</strong></a>
  • <a href="https://github.com/DKLYNTLY/Character-Preset-Manager-CET-"><strong>SOURCE CODE</strong></a>
</p>

<p align="center"><strong>Current version: 4.1.0</strong> · <a href="CHANGELOG.md">Changelog</a></p>

> [!IMPORTANT]
> Remove the **ACU mod**, but keep your **ACU presets**.

## About Character Preset Manager

Character Preset Manager is a successor to Appearance Change Unlocker (ACU).
It saves and loads your character's appearance, so you can switch between presets without recreating each look.

It reads older Character Preset Manager files and compatible ACU presets. See the import section for compatibility details.

- Save and load vanilla, CC, and CCXL appearance choices.
- Open the character customization menu anywhere with a hotkey.
- Search by preset name, folder, or tag.
- Organize presets into folders, mark favorites, add notes, and rename or copy them.
- Share individual preset files.
- Recover deleted items from Trash.

---

<details>
<summary><strong>Showcase</strong></summary>

[![Watch my Character Preset Manager showcase](https://img.youtube.com/vi/zxrJ2Ryq-G8/hqdefault.jpg)](https://www.youtube.com/watch?v=zxrJ2Ryq-G8)

</details>

---

<details>
<summary><strong>Install and update</strong></summary>

### Requirements

Install these four frameworks:

- [Cyber Engine Tweaks](https://www.nexusmods.com/cyberpunk2077/mods/107) **1.38.0 or newer**
- [RED4ext](https://www.nexusmods.com/cyberpunk2077/mods/2380) **1.31.0 or newer**
- [redscript](https://www.nexusmods.com/cyberpunk2077/mods/1511) **0.5.32 or newer**
- [Codeware](https://www.nexusmods.com/cyberpunk2077/mods/7780) **1.21.1 or newer**

*Use versions that support your installed game. After a game update, check that the frameworks and this mod are compatible before using the editor.*

---

### First installation

1. Install the four required frameworks listed above.
2. Download Character Preset Manager from [Nexus Mods](https://www.nexusmods.com/cyberpunk2077/mods/31886).
3. For **manual installation**, extract the ZIP into your main Cyberpunk 2077 folder. With a **mod manager**, install the archive normally.
4. Start the game and set up your CET overlay key if prompted.
5. Open character creation or an apartment mirror to use the Preset Manager.

---

### Update an existing installation

1. Close the game.
2. Back up the **Character Presets** and **Data** folders inside your current Character Preset Manager (CET) mod folder.
3. Remove these three folders from your game directory, including the native DLL in the last folder:

   ```text
   bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)
   r6/scripts/CharacterPresetManager
   red4ext/plugins/CharacterPresetManager
   ```

   *Remove the old folders before installing the update. Overwriting them can leave old scripts active.*

4. Install the new version using the installation steps above, and update the required frameworks if needed.
5. Restore your backed-up **Character Presets** and **Data** folders to the mod folder.
6. Start the game.

</details>

---

<details>
<summary><strong>Compatibility and incompatibilities</strong></summary>

- EKT Custom Character Creator — Compatible
- CCXL customization mods — Supported when the saved choices can be identified in the installed catalog.
- Character Customization Anywhere — Incompatible
- Appearance Change Unlocker (ACU) — Incompatible

</details>

---

<details>
<summary><strong>Menus</strong></summary>

### Preset Manager

Appears in the character customization screen. From here, you can:

- Load a preset with one click.
- Save your appearance as a new preset or overwrite an existing one.
- Browse folders and favorites.
- Search by preset name, folder, or tag.
- Refresh the list after adding or changing preset files.
- Randomize your appearance and choose which categories can change.
- Undo the last preset load.
- Move a preset to Trash.
- Open the Advanced Preset Manager.
- Check Panel Status for progress, warnings, and confirmations.

![Preset Manager in the character customization screen](https://raw.githubusercontent.com/DKLYNTLY/Character-Preset-Manager-CET-/34244e2f4fc334dbf0016fc4fd5a2ff976958d3b/images/Simple%20Menu.png)

---

### Advanced Preset Manager

Open it with your CET overlay key, or select **Advanced Preset Manager** in the Preset Manager menu. From here, you can:

- Save, load, rename, and copy presets.
- Search presets and organize them with folders, favorites, notes, and tags.
- Move or delete several presets at once.
- Import ACU presets.
- Share individual preset files.
- Undo the last preset load.
- Move items to Trash, restore them, or delete them permanently.
- Refresh the library and editor options together, and review load warnings.
- Open the full character customization menu.
- Randomize your appearance and choose which categories can change.
- Change preset sorting in **Settings** and view the Activity Log.

Select **Character Creator** at the top of CET to open the customization menu. Use **Advanced Preset Actions** for renaming, copies, favorites, notes, tags, and the file path.

**Refresh** updates your library and the current editor choices. With the editor closed, it refreshes only the library; during a load, it waits until loading finishes.

![Advanced Preset Manager](https://raw.githubusercontent.com/DKLYNTLY/Character-Preset-Manager-CET-/34244e2f4fc334dbf0016fc4fd5a2ff976958d3b/images/Advanced%20Menu.gif)

---

### Apartment mirrors

Apartment mirrors give you access to the full character customization menu.

**Gender cannot be changed mid-game.** Choose it when creating a new character.

![Full character customization options in an apartment mirror](https://raw.githubusercontent.com/DKLYNTLY/Character-Preset-Manager-CET-/34244e2f4fc334dbf0016fc4fd5a2ff976958d3b/images/Mirror.gif)

</details>

---

<details>
<summary><strong>Manage presets: imports, folders, and sharing</strong></summary>

### Import ACU presets

Remove the ACU mod and keep its preset files.

1. Put the presets in this folder inside your game directory. Create it if needed:

   ```text
   bin/x64/plugins/cyber_engine_tweaks/mods/AppearanceChangeUnlocker/character-presets
   ```

2. Start the game with Character Preset Manager installed.
3. Open the Advanced Preset Manager and look under **ACU Presets**. Select **Refresh** if a preset is missing.

Importing is automatic. Original files stay unchanged, and imported copies keep their subfolders.

Older ACU text and JSON presets are supported, including **ACU 4.1.1 version-2 files** with a `// ACU-PRESET` header. Version-3 files with that header are not supported.

Version-2 choices need names that can be uniquely matched to your installed options. Choices that cannot be matched stay unchanged.

*Older ACU presets may store only choice numbers. Changing character mods can change what those numbers select, so check the appearance and warnings before confirming. Loading does not change your character's body or voice.*

Imported ACU files are read-only. After checking or correcting the appearance, **save it under a new name** to use CPM notes, tags, and favorites.

---

### Save format 9 and upgrade older CPM presets

New presets use readable **format 9** files. Overwriting an existing preset still asks for confirmation.

Older CPM presets upgrade automatically when you open an editor with the matching body type. Male presets need a male editor, and female presets need a female editor.

Each original is backed up before replacement:

```text
Data/Recovery/Preset Upgrades/<batch>/<original preset path>`.preset`
```

Names, folders, notes, tags, favorites, and creation dates are kept. An upgrade note is added, and backups are never deleted automatically.

For presets with no clear body type, open **Advanced Preset Manager → Presets needing a body type**. Choose the body the preset was saved for, regardless of its name or voice.

*Older presets may store choice numbers. Changed character mods can make those numbers select different options, so check the appearance before confirming.*

Missing choices stay unresolved. If no choices can be upgraded, or the backup fails, the original stays unchanged; check the Activity Log for details.

---

### Body filtering

Open **Settings → Preset Library → Visibility** to choose what appears.

- **Filter by body** shows known matches for your character.
- **Show all presets** also shows unknown and opposite-body presets. Known mismatches still cannot be loaded.

The selected preset shows Male, Female, or Unknown. This refers to body type, not voice, and does not change your character.

Presets with missing body information remain under **Presets needing a body type**, even when hidden from the main list. Select **Refresh** after adding files or to check their body information again.

---

### Where files are stored

Your presets are stored here, inside the game folder:

```text
bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Character Presets
```

To share a preset, send its `.preset` file. To install one, place it in this folder or a subfolder, then select **Refresh** in the Advanced Preset Manager.

Ordinary format 9 and ACU reads and loads leave source files unchanged. Identified older CPM files are replaced only through automatic migration after a verified backup.

---

### Preset folders

Open **Advanced Preset Manager → Folders** to create virtual folders and move presets between them. Folders created in the Advanced Preset Manager organize your library without creating Windows folders. You can also make subfolders.

Copying a folder includes its presets and subfolders. **Remove Folder, Keep Presets** moves its contents to the parent folder.

---

### Folders added outside the game

If you put a folder inside Character Presets, it appears in the menu as **Imported**. Renaming or moving it in the menu does not rename or move the folder on your computer.

Choose **Remove Folder, Keep Presets** to move its presets into the main preset folder. The old folder is removed only when empty, so any other files stay safe.

Use regular folders, with no more than 12 levels of subfolders. Folder links that point somewhere else on your computer are not supported.

---

### Share preset files

Send individual `.preset` files and place received presets in Character Presets, then select **Refresh**. Folder sharing and `.cpmfolder` import/export are no longer available. Existing files are left alone; a sharing file already in Trash can still be restored or permanently deleted.

</details>

---

<details>
<summary><strong>Recovery and Trash</strong></summary>

### Original presets from automatic upgrades

Automatic-upgrade backups are separate from appearance history and Trash. They keep the original file bytes and subfolders under Data/Recovery/Preset Upgrades; CPM does not delete these backups automatically.

To restore one, close the game and copy the backed-up `.preset` over its matching path in **Character Presets**. Keep the backup copy afterward, since the restored old CPM file becomes eligible for automatic upgrade on the next run.

---

### Undo Last Load

Use **Undo Last Load** in either menu to restore your appearance before the last preset load.

CPM keeps one saved appearance here:

```text
Data/Recovery/LastAppearance.preset
```

A new, different appearance replaces that recovery file.

Older files in **Data/Recovery/Appearance History** stay untouched. If the new recovery file is missing, CPM can use the newest old entry.

---

### Trash

Presets and folders moved to Trash can be restored through **Permanently Delete or Restore** in the Advanced Preset Manager. If a name is already taken, the restored item gets “Copy” added to its name.

**Empty Trash Permanently** deletes the items in Trash. This cannot be undone.

</details>

---

<details>
<summary><strong>Common issues and bug reports</strong></summary>

### Redscript compilation failed

The error may name Character Preset Manager even when another mod is causing the problem. Check the log before deciding which mod to remove.

1. Open `r6/logs/redscript_rCURRENT.log` inside your game folder and look for errors.
2. Update or reinstall the four required frameworks listed under [Requirements](#requirements).
3. Check for outdated or duplicate mods, including Virtual Atelier.
4. Remove **cybercmd** if you have it installed.
5. Close the game and delete its `r6/cache` folder, then verify your game files through Steam, GOG, or Epic.
6. If compilation still fails, disable your redscript mods in small groups and test again to narrow down the cause.

You can also test with only the required frameworks installed, then enable your mods a few at a time. If you need help, share the redscript log and error message on [Discord](https://discord.com/invite/mUGHmQxHG8).

---

### Endless loading after changing your appearance

If the game gets stuck loading after you confirm your changes, your clothing or wardrobe outfit may be causing it.

Remove your clothing and select **No Outfit** in the wardrobe before opening the customization menu. You can put everything back on after you finish.

---

### Menu buttons don't respond or presets don't appear

Make sure all four required frameworks are installed and up to date, then fully restart the game.

Startup scans the library, and the first status message also prompts **Refresh**. Refresh an empty list and check **Preset Visibility**; body filtering hides Unknown and opposite-body presets.

---

### Downloaded presets don't appear

Check [Where files are stored](#where-files-are-stored) for preset installation steps. For ACU presets, follow [Import ACU presets](#import-acu-presets), then select **Refresh** in the Advanced Preset Manager.

---

### Deleted presets appear again

The original ACU preset may still be in your ACU presets folder. Automatic importing can bring it back after you delete the copy in Character Preset Manager.

Move the original out of the ACU presets folder, then delete the imported copy.

---

### An automatic upgrade is still pending

Open an editor with the body type the preset was saved for. If it is unknown, choose it under **Advanced Preset Manager → Presets needing a body type**.

Install the full update, including the **RED4ext DLL**. Check the Activity Log for the reason the upgrade stopped, correct the problem, then select **Refresh**.

The original stays unchanged if its backup fails or none of its choices can be upgraded. When only some choices work, check the appearance before confirming; unresolved choices stay unchanged.

---

### Leftover hair, cyberware, or unconfirmed choices

Some preset loads can leave old hair or cyberware visible. The cause is still unclear, and reopening the editor may not fix it.

Check your character before confirming. A choice can be confirmed in the log even if an old part is still visible.

Missing choices stay unchanged, including eye or eyelash colors your installed mods do not provide. Include a screenshot and preset name when reporting the problem.

**Back** and closing the editor remain available during loading.

---

### Report a bug

Join [Discord](https://discord.com/invite/mUGHmQxHG8) and explain what happened and how to repeat it. Include the preset name, a screenshot if useful, and your latest Activity.log.

Select **Log** at the top of the Advanced Preset Manager to read or copy it. The file is also inside your game folder:

```text
bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Data/Logs/Activity.log
```

For appearance problems, enable **Settings → Diagnostics → Detailed appearance tracing**, repeat the problem, then turn it off.

For missing or incorrect choices, open the customization menu and select **Log → Technical Details → Export Option Catalog** after loading finishes. Send the exported file from **Data/Logs** with your report; a large list may briefly pause the game.

Include the **RED4ext log** for ACU import, folder detection, or CET opening problems. Fully restart the game if it reports that the native file service stopped.

</details>

---

<details>
<summary><strong>Common questions</strong></summary>

### Can I have your preset?

No.

---

### How do I change the settings?

Select **Settings** at the top of the Advanced Preset Manager. Use **Preset Sort Order** to sort presets by name or last changed date.

**Preset Visibility** chooses body filtering or all presets. Enable **Detailed appearance tracing** when troubleshooting, then turn it off after collecting the log.

</details>

---

<details>
<summary><strong>About this mod</strong></summary>

### License

© Dnydd (formerly known as dklyntly). All Rights Reserved.

You may edit configuration files and share your own presets. Public and private modpacks may include unmodified official releases with credit, the official link, the license, and original notices.

For other uses, permissions, and exceptions, refer to the [full license](LICENSE).

---

### Credits

ChatGPT helped me with this mod. I wrote the code myself.

- [PotatoOfDoom](https://www.nexusmods.com/cyberpunk2077/mods/3850) for ACU, which came before this mod.
- [keanuWheeze](https://www.nexusmods.com/cyberpunk2077/mods/3930) for Character Customization Anywhere, which inspired the customization hotkey.
- **yamashi and contributors** — [Cyber Engine Tweaks](https://www.nexusmods.com/cyberpunk2077/mods/107)
- **WopsS and contributors** — [RED4ext](https://www.nexusmods.com/cyberpunk2077/mods/2380)
- **jac3km4 and contributors** — [redscript](https://www.nexusmods.com/cyberpunk2077/mods/1511)
- **psiberx and contributors** — [Codeware](https://www.nexusmods.com/cyberpunk2077/mods/7780)

Thanks to CD Projekt Red for Cyberpunk 2077, and to everyone who has tested the mod, reported problems, or shared feedback.

</details>
