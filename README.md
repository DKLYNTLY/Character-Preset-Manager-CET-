<h1 align="center">Character Preset Manager (CET)</h1>

<p align="center"><strong>Save, load, organize, and share your Cyberpunk 2077 appearances.</strong><br>
<em>A complete preset library in CET, with a Preset Manager menu in the character screen.</em></p>

<p align="center">If you enjoy my mods, you can support my work through Ko-fi or PayPal.</p>

<p align="center">
  <a href="https://ko-fi.com/A3G129JCLF"><img src="https://ko-fi.com/img/githubbutton_sm.svg" alt="Support me on Ko-fi"></a>
  <a href="https://www.paypal.com/ncp/payment/7ZKG8YG6GCERC"><img src="https://img.shields.io/badge/Support%20via-PayPal-0070BA?style=for-the-badge&amp;logo=paypal&amp;logoColor=white" alt="Support via PayPal" height="30"></a>
</p>

<p align="center">
  <a href="https://www.nexusmods.com/cyberpunk2077/mods/31886">Download</a>
  · <a href="https://discord.com/invite/mUGHmQxHG8">Discord</a>
  · <a href="https://github.com/DKLYNTLY/Character-Preset-Manager-CET-">Source Code</a>
</p>

<p align="center"><strong>Current version: 4.0.1</strong> · <a href="CHANGELOG.md">Changelog</a></p>

> [!IMPORTANT]
> Remove the **ACU mod**, but keep your **ACU presets**.

## About Character Preset Manager

Character Preset Manager is a successor to Appearance Change Unlocker (ACU).
It saves and loads your character's appearance, so you can switch between presets without recreating each look.

It supports all ACU presets and older Character Preset Manager files. You can:

- Save and load vanilla, CC, and CCXL appearance choices.
- Open the character customization menu anywhere with a hotkey.
- Search by preset name, folder, or tag.
- Organize presets into folders, mark favorites, add notes, and rename or copy them.
- Share individual presets, folders, or selected groups.
- Recover deleted items from Trash.

<details>
<summary><strong>Showcase</strong></summary>

[![Watch my Character Preset Manager showcase](https://img.youtube.com/vi/zxrJ2Ryq-G8/hqdefault.jpg)](https://www.youtube.com/watch?v=zxrJ2Ryq-G8)

</details>

<details>
<summary><strong>Install and update</strong></summary>

## Requirements

Install these four frameworks:

- [Cyber Engine Tweaks](https://www.nexusmods.com/cyberpunk2077/mods/107) **1.38.0 or newer**
- [RED4ext](https://www.nexusmods.com/cyberpunk2077/mods/2380) **1.31.0 or newer**
- [redscript](https://www.nexusmods.com/cyberpunk2077/mods/1511) **0.5.32 or newer**
- [Codeware](https://www.nexusmods.com/cyberpunk2077/mods/7780) **1.21.1 or newer**

*Use versions that support your installed game. After a game update, check that the frameworks and this mod are compatible before using the editor.*

---

## First installation

1. Install the four required frameworks listed above.
2. Download Character Preset Manager from [Nexus Mods](https://www.nexusmods.com/cyberpunk2077/mods/31886).
3. For **manual installation**, extract the ZIP into your main `Cyberpunk 2077` folder. With a **mod manager**, install the archive normally.
4. Start the game and set up your CET overlay key if prompted.
5. Open character creation or an apartment mirror to use the Preset Manager.

---

## Update an existing installation

1. Close the game.
2. Back up the `Character Presets` and `Data` folders inside your current `Character Preset Manager (CET)` mod folder.
3. Remove these three folders from your game directory, including the native DLL in the last folder:

   ```text
   bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)
   r6/scripts/CharacterPresetManager
   red4ext/plugins/CharacterPresetManager
   ```

4. Install the new version using the installation steps above, and update the required frameworks if needed.
5. Restore your backed-up `Character Presets` and `Data` folders to the mod folder.
6. Start the game.

</details>

<details>
<summary><strong>Compatibility and incompatibilities</strong></summary>

- EKT Custom Character Creator — Compatible
- All CCXL mods — Compatible
- Character Customization Anywhere — Incompatible
- Appearance Change Unlocker (ACU) — Incompatible

</details>

<details>
<summary><strong>Menus</strong></summary>

## Preset Manager

Appears in the character customization screen. From here, you can:

- Load a preset with one click.
- Save your appearance as a new preset or overwrite an existing one.
- Browse folders and favorites.
- Search by preset name, folder, or tag.
- Refresh the list after adding or changing preset files.
- Randomize your appearance and choose which categories can change.
- Undo the last load or restore an appearance from recovery history.
- Move a preset to Trash.
- Open the Advanced Preset Manager.
- Check Panel Status for progress, warnings, and confirmations.

![Preset Manager in the character customization screen](https://raw.githubusercontent.com/DKLYNTLY/Character-Preset-Manager-CET-/34244e2f4fc334dbf0016fc4fd5a2ff976958d3b/images/Simple%20Menu.png)

---

## Advanced Preset Manager

Open it with your CET overlay key, or select **Advanced Preset Manager** in the Preset Manager menu. From here, you can:

- Save, load, rename, and copy presets.
- Search presets and organize them with folders, favorites, notes, and tags.
- Move, export, or delete several presets at once.
- Import ACU presets and shared preset folders.
- Share individual presets, folders, or selected groups.
- Back up and restore your preset library.
- Restore an earlier appearance from recovery history.
- Move items to Trash, restore them, or delete them permanently.
- Check preset compatibility and use Force Full Load.
- Open the full character customization menu.
- Randomize your appearance and choose which categories can change.
- Change preset sorting in **Settings** and view the Activity Log.

![Advanced Preset Manager](https://raw.githubusercontent.com/DKLYNTLY/Character-Preset-Manager-CET-/34244e2f4fc334dbf0016fc4fd5a2ff976958d3b/images/Advanced%20Menu.gif)

---

## Apartment mirrors

Apartment mirrors give you access to the full character customization menu.

**Gender cannot be changed mid-game.** Choose it when creating a new character.

![Full character customization options in an apartment mirror](https://raw.githubusercontent.com/DKLYNTLY/Character-Preset-Manager-CET-/34244e2f4fc334dbf0016fc4fd5a2ff976958d3b/images/Mirror.gif)

</details>

<details>
<summary><strong>Manage presets: imports, folders, and sharing</strong></summary>

## Import ACU presets

1. Remove the ACU mod, but keep its `.preset` files.
2. Put those presets in this folder inside your game directory. Create the folder if it no longer exists:

   ```text
   bin/x64/plugins/cyber_engine_tweaks/mods/AppearanceChangeUnlocker/character-presets
   ```

3. Start the game with Character Preset Manager installed.
4. Open the Advanced Preset Manager and look under **ACU Presets**. Select **Refresh** if a preset is missing.

Importing is automatic. Your original files stay unchanged, and imported copies keep their subfolders.

---

## Where files are stored

Your presets are stored here, inside the game folder:

```text
bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Character Presets
```

To share a preset, send its `.preset` file. To install one, place it in this folder or a subfolder, then select **Refresh** in the Advanced Preset Manager.

Loading an older preset leaves its file unchanged. Overwriting it or saving changes to its notes or tags updates it to the current format.

---

## Preset folders

Folders created in the Advanced Preset Manager organize your library without creating Windows folders. You can also make subfolders.

Copying a folder includes its presets and subfolders. **Remove Folder, Keep Presets** moves its contents to the parent folder.

---

## Folders added outside the game

If you put a folder inside `Character Presets`, it appears in the menu as **Imported**. Renaming or moving it in the menu does not rename or move the folder on your computer.

Choose **Remove Folder, Keep Presets** to move its presets into the main preset folder. The old folder is removed only when empty, so any other files stay safe.

Use regular folders, with no more than 12 levels of subfolders. Folder links that point somewhere else on your computer are not supported.

---

## Share a folder

1. Select a folder in **Create & Organize Folders**.
2. Open **Share & Import Folders** and choose **Export Selected Folder as a .cpmfolder File**.
3. Find the exported file in `Character Presets` and send it to someone else.

The file includes presets, subfolders, notes, tags, and favorites. Empty folders cannot be exported.

---

## Install a shared folder

1. Put the `.cpmfolder` file in `Character Presets`.
2. In the Advanced Preset Manager, open **Create & Organize Folders > Share & Import Folders**.
3. Select **Install .cpmfolder Files from Character Presets**.

To preview a file first, choose it under **Manage & Remove .cpmfolder Files**, then select **View Selected .cpmfolder Contents**.

Deleting the shared file afterward does not remove the presets you installed.

</details>

<details>
<summary><strong>Recovery and Trash</strong></summary>

## Appearance history

Before loading a preset, the mod saves your current appearance. It keeps up to five different appearances for recovery.

In the Preset Manager, use **Undo Last Load** or **Recovery History**. In the Advanced Preset Manager, use **Restore Previous Appearance** or **Appearance History**.

---

## Trash

Presets and folders moved to Trash can be restored through **Delete & Restore Items** in the Advanced Preset Manager. If a name is already taken, the restored item gets “Copy” added to its name.

**Empty Trash Permanently** deletes the items in Trash. This cannot be undone.

</details>

<details>
<summary><strong>Common issues and bug reports</strong></summary>

## Redscript compilation failed

The error may name Character Preset Manager even when another mod is causing the problem. Check the log before deciding which mod to remove.

1. Open `r6/logs/redscript_rCURRENT.log` inside your game folder and look for errors.
2. Update or reinstall the four required frameworks listed under [Requirements](#requirements).
3. Check for outdated or duplicate mods, including Virtual Atelier.
4. Remove **cybercmd** if you have it installed.
5. Close the game and delete its `r6/cache` folder, then verify your game files through Steam, GOG, or Epic.
6. If compilation still fails, disable your redscript mods in small groups and test again to narrow down the cause.

You can also test with only the required frameworks installed, then enable your mods a few at a time. If you need help, share the redscript log and error message on [Discord](https://discord.com/invite/mUGHmQxHG8).

---

## Endless loading after changing your appearance

If the game gets stuck loading after you confirm your changes, your clothing or wardrobe outfit may be causing it.

Remove your clothing and select **No Outfit** in the wardrobe before opening the customization menu. You can put everything back on after you finish.

---

## Menu buttons don't respond or presets don't appear

Make sure all four required frameworks are installed and up to date, then fully restart the game.

---

## Downloaded presets don't appear

Check [Where files are stored](#where-files-are-stored) for preset installation steps. For ACU presets, follow [Import ACU presets](#import-acu-presets), then select **Refresh** in the Advanced Preset Manager.

---

## Deleted presets appear again

The original ACU preset may still be in your ACU presets folder. Automatic importing can bring it back after you delete the copy in Character Preset Manager.

Move the original out of the ACU presets folder, then delete the imported copy.

---

## Report a bug

Join [Discord](https://discord.com/invite/mUGHmQxHG8) and explain what happened and what you were doing. Include your latest `Activity.log` so I can check what went wrong.

Select **Log** at the top of the Advanced Preset Manager to read or copy it. You can also find the file inside your game folder:

```text
bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Data/Logs/Activity.log
```

</details>

<details>
<summary><strong>Common questions</strong></summary>

## Can I have your preset?

No.

---

## How do I change the settings?

Select **Settings** at the top of the Advanced Preset Manager. Use **Preset Sort Order** to sort presets by name or last changed date.

</details>

<details>
<summary><strong>About this mod</strong></summary>

## License

© Dnydd (formerly known as dklyntly). All Rights Reserved.

You may edit configuration files and share your own presets. Public and private modpacks may include unmodified official releases with credit, the official link, the license, and original notices.

For other uses, permissions, and exceptions, refer to the [full license](LICENSE).

---

## Credits

ChatGPT helped me with this mod. I wrote the code myself.

- [PotatoOfDoom](https://www.nexusmods.com/cyberpunk2077/mods/3850) for ACU, which came before this mod.
- [keanuWheeze](https://www.nexusmods.com/cyberpunk2077/mods/3930) for Character Customization Anywhere, which inspired the customization hotkey.
- **yamashi and contributors** — [Cyber Engine Tweaks](https://www.nexusmods.com/cyberpunk2077/mods/107)
- **WopsS and contributors** — [RED4ext](https://www.nexusmods.com/cyberpunk2077/mods/2380)
- **jac3km4 and contributors** — [redscript](https://www.nexusmods.com/cyberpunk2077/mods/1511)
- **psiberx and contributors** — [Codeware](https://www.nexusmods.com/cyberpunk2077/mods/7780)

Thanks to CD Projekt Red for Cyberpunk 2077, and to everyone who has tested the mod, reported problems, or shared feedback.

</details>
