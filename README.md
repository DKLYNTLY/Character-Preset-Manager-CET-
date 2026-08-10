# Character Preset Manager (CET)

**Current version: 2.0.5**

A standalone Cyber Engine Tweaks character preset manager for saving and loading complete
Cyberpunk 2077 character appearances—including face, hair, eyes, makeup,
cyberware, tattoos, scars, and exposed CC/CCXL options—inside the game's active
vanilla character-customization flow.

## What changed

- Provides a standalone CET ImGui window named **Character Preset Manager (CET)**.
- Temporarily removes an active wardrobe outfit while character customization
  is open, then restores that outfit when the editor closes.
- Opens the full vanilla appearance editor from normal gameplay through either
  the Character Preset Manager window or an optional CET hotkey.
- Upgrades normal mirror customization sessions to the full character-creator
  option set.
- Creates a named preset from the appearance currently shown in the vanilla editor.
- Loads any saved preset back into an active vanilla editor.
- Keeps Appearance Editor, Load, and Create expanded by default while Folders
  and Manage start collapsed. Native arrow headers control each section.
- Runs directly through Cyber Engine Tweaks with no additional runtime layer.
- Contains no RED4ext plugin, DLL, redscript, Codeware, archive, or additional
  runtime dependency.
- Loads a preset only when the vanilla customization system is initialized.
- Applies each active option through the game's `ApplyChangeToOption` method.
- Stores values by option localization key rather than by array position.
- Adds rename, delete, refresh, and visible success/error status.
- Reads presets recursively from folders and lets users add, rename, delete, or
  move folders and presets from the CET window.
- Duplicates individual presets in place or recursively copies an entire folder
  with a unique name.

## Requirements

- Cyber Engine Tweaks 1.37.1 or newer

## Installation

Extract the release archive into the Cyberpunk 2077 game directory.

When upgrading from any 1.0.x version, first copy your `.preset` files somewhere
safe outside the mod folder. Completely delete
`mods/Preset Manager (CET)`, install version 2.0.5, and then place the copied
presets in `mods/Character Preset Manager (CET)/Character Presets`. Do not
install version 2.0.5 over version 1.0.x or leave both folders installed.

Open the CET overlay and select **Character Preset Manager (CET)**. Create and load
controls become available only while the game exposes a vanilla character
creator, mirror, or ripperdoc customization session.

On its first launch, the panel is placed near the right edge and writes
`Window Position Status.txt`. After that, CET preserves the position selected
by the user across game restarts.

### Opening the full editor

Open CET, choose **Bindings**, find **Character Preset Manager (CET)**, and assign
**Open Full Appearance Editor**. Close the CET overlay, then press the assigned
key during normal gameplay. The current assignment is shown in Character Preset Manager's
Help panel. Apartment mirrors expose the same full character-creator options.

## Creating a preset

1. Choose **Open Full Appearance Editor** in Character Preset Manager, use its optional
   CET hotkey, or open a vanilla mirror or ripperdoc customization screen.
2. Open the CET overlay and select **Character Preset Manager (CET)**.
3. Enter a name and choose **Create New Preset**.

## Loading a preset

1. Open a supported vanilla customization screen.
2. Select a saved preset and choose **Load Selected Preset** once.
3. Wait while the remaining passes run automatically. A green **Preset fully
   applied** message means loading is complete.

The loader clears exposed, editable cosmetics that are not part of the incoming
preset, which helps prevent leftover cyberware, makeup, tattoos, scars, and
other optional appearance elements.

Presets are individual files stored in:

`bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Character Presets`

Each `.preset` file can be shared or packaged for Nexus Mods. Drop downloaded
preset files into that directory or any folder beneath it and reopen the CET
overlay to refresh the list. In Load, folder rows appear first as
`Name (folder)` and can be clicked to show or hide the presets inside them;
presets in the root directory appear below every folder. The Folders section can create and rename folders,
move presets between them, and delete folders. Empty folders require two delete
clicks. Folders containing presets or other contents require three red-button
clicks and permanently delete everything inside them, including nested folders.
External additions, removals, moves, and detected file changes are logged as
warnings when CET rescans. A saved inventory also detects path changes made
while the game is closed at the next startup.
Preset and inventory updates are written to temporary files and safely swapped
into place so an interrupted write does not truncate the existing data. If an
imported preset contains malformed nonblank lines, the activity log identifies
the affected file and line while continuing to load its valid entries.
Use **Duplicate Selected Preset** to copy one preset in its current folder, or
**Duplicate Selected Folder** to copy the full selected folder tree. Duplicate
names use `Copy`, `Copy 2`, and so on automatically.

Folder creation uses 16 recyclable slots bundled with the mod because CET's
sandbox does not expose a general directory-creation command. Deleting an empty
folder returns its slot for reuse; folders created manually are also discovered.
The Folders section shows the live number of recyclable slots still available
and highlights the count when capacity is nearly exhausted. The pool may grow
beyond the 16 bundled slots when a manually created folder is recycled.
Recycling restores a tiny marker file so deployment tools do not discard the
slot as an empty directory, and startup repairs any missing slot markers.
The mod does not bundle any character presets.

Appearance Change Unlocker uses the same `LocKey:index` preset format. To import
an ACU preset, copy its `.preset` file into Character Preset Manager's `Character Presets`
folder and reopen the CET overlay. Imported files appear as normal editable
presets and can be renamed, resaved, or deleted in Character Preset Manager.

The full ACU mod is incompatible with Character Preset Manager and should not be installed
at the same time. Copy the preset file before disabling or uninstalling ACU,
then fully restart the game before using Character Preset Manager.

CCXL options are stored as an ordered series of localization-key and
selected-index entries. The order is preserved, so multiple heterochromia or
CCXL options with the same localization key do not overwrite one another.

## Compatibility

### Appearance Change Unlocker

The full Appearance Change Unlocker mod is incompatible with Character Preset Manager;
do not run both mods together. Remove ACU and fully restart Cyberpunk before using
Character Preset Manager. This warning appears in the Compatibility Warnings panel.

This does not prevent Character Preset Manager from reading ACU-format `.preset` files
copied into its own `Character Presets` folder. If the installed customization
or CCXL setup has changed since a preset was created, correct anything necessary
and resave the preset from the editor you already have open.

### Character Customization Anywhere

Character Customization Anywhere is incompatible because it changes vanilla mirrors
and the character customization screen used by Character Preset Manager. It is also
affected by the game's long-standing risk of an infinite loading screen when leaving
customization, especially while equipment or wardrobe outfits are active. Character
Preset Manager does not attempt to detect this mod. Remove Character Customization
Anywhere and fully restart Cyberpunk before using Character Preset Manager. This
warning appears in the Compatibility Warnings panel.

If the game gets stuck loading when leaving any customization screen, unequip
your clothing and select **No Outfit** in the wardrobe before opening customization.
This long-standing game issue can also affect the vanilla mirror and may happen
more often with Equipment-EX or highly detailed outfits. Re-equip everything after
leaving customization. The Load section repeats this workaround beside the preset
controls when it detects equipped clothing, replacing the normal ready message
with a yellow warning before loading. The warning is suppressed in the genuine
new-game character creator.

The red **Compatibility Warnings — Read First** panel appears at the top of the
interface and starts expanded. It contains all compatibility restrictions and
known-issue workarounds in one location.

### CC and CCXL customization mods

Character Preset Manager saves and loads custom options when those mods expose them
through the game's active customization list. Repeated and linked options such
as heterochromia are supported. For the most reliable results, keep the same
customization mods installed and in the same order when creating and loading a
preset. Ambiguous repeated entries are reported rather than applied to a guessed
slot; correct anything necessary and resave the preset from the current editor.

### Custom character creators and customization fixes

Custom character creators and fixes can work with Character Preset Manager when they add
or modify options in the vanilla customization system. Character Preset Manager does not
change meshes, rigs, archives, or another mod's assets, so conflicts between
those assets remain outside its scope.

### Photo Mode and Appearance Menu Mod

Photo Mode and Appearance Menu Mod (AMM) do not expose the vanilla character
customization option list used by Character Preset Manager. AMM appearances use a
different system for outfits or entity/model swaps. Presets therefore must be
created and loaded from a supported character creator, mirror, or ripperdoc
customization screen.

## Diagnostic log

Character Preset Manager (CET) writes a detailed log to:

`bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Character Preset Manager (CET) Activity.log`

Each full game launch starts a fresh Activity log. Before it is cleared, the
existing log is copied to a timestamped text file such as
`Character Preset Manager (CET) Activity 2026-08-03_20-30-00.txt` for troubleshooting.
The newest 10 dated archives are retained. Creating an 11th archive deletes the
oldest one automatically.

The file records startup, preset counts, every load summary, application
failures, inactive options, and saved options unavailable in the current
customization screen.

Loading may require several passes because Cyberpunk temporarily disables
dependent options while rebuilding the editor. One click now runs those passes
automatically, with a short delay that lets the editor finish rebuilding.
After the final pass is verified, Character Preset Manager asks the active customization
page to fully recreate its visible option list from the applied values. The
displayed selectors and sliders therefore update without requiring Next and
Back.

Application is also staged. At most one changed preset option is applied per
rebuild interval, then the option list is queried again. Parent choices such as
hairstyle are applied before their dependent color choices. If a CCXL hair
replaces its color selector with a different localization key, the loader can
map the saved color to that replacement when its two neighboring preset options
identify one unambiguous ordered slot. Multiple unavailable saved entries are
never allowed to claim the same replacement selector; ambiguous replacements
remain unresolved instead of repeatedly changing the appearance.

Every click starts with a targeted cleanup, even when loading the same preset
again. Currently exposed, editable, active cosmetic occurrences that are absent
from the incoming preset are returned to index `0` one at a time, with a rebuild
delay after each change. Target hair, face, eye, and other preset options are not
reset first. This avoids overlapping meshes caused by changing many dependent
options inside one frame. Options hidden or locked by the current editor cannot
be cleared safely and are reported as unresolved instead.

Legacy and ACU preset entries are matched by their displayed label and
occurrence. When the number of repeated labels saved in the preset differs from
the number safely exposed by the current editor, the loader now refuses to
guess. Those entries remain unresolved instead of risking a value being applied
to the wrong color, makeup, hair, or cosmetic slot.

CCXL options such as heterochromia remain supported as ordered repeated entries.
Both eye slots are reset and restored when the same number of entries is exposed.
For reliable CCXL loading, keep the same customization mods enabled and in the
same order. If the count differs, that repeated group is skipped and reported
rather than applied to a guessed slot.

If the exact same options remain unresolved on three consecutive passes, the mod
stops the retry loop. Adding, removing, or reordering CCXL customization mods can
change the option keys, repeated-option counts, or numeric indexes stored by an
older preset. Correct anything necessary and resave the preset from the editor
you already have open.

The launched editor and apartment mirrors expose the full character-creator
option set. A preset mismatch means the installed customization/CCXL setup or
its option ordering changed, not that the mirror is restricted.

## Technical note

The built-in launcher and normal mirror interactions open the vanilla
customization flow in its full creator edit mode. Character Preset Manager still does not
alter archives or add customization assets: it can save and load only the
vanilla and modded options registered with the active customization system.

## Credits

Character Preset Manager (CET) by dklyntly.

## Screenshot preset

The author's personal character preset shown in promotional screenshots is not
included or planned for release. The screenshots demonstrate Character Preset Manager;
shared community presets remain separate `.preset` files.
