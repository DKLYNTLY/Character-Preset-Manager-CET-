# Changelog

The newest release appears first. Older sections show what changed at the time
of each release. They may mention controls or file locations that are no longer
used. See the README and in-game Help for current instructions.

<details open>
<summary><strong>Latest release — 3.0.4</strong></summary>

## 3.0.4

*Readable preset files with full older-format support.*

- Adds format 8 for newly saved presets.
- Replaces percent-encoded header values such as `%20` and `%3A` with plain text.
- Gives each file a clear title, preset information, and short instructions for
  reading its appearance entries.
- Keeps the familiar `OptionKey:SavedNumber` line for every character option.
- Places **Editor slot** and **Saved choice** on clearly labeled lines below the
  option they describe.
- Continues reading every older Character Preset Manager format and compatible
  ACU preset files.
- Ignores ordinary comment lines instead of reporting them as damaged preset data.
- Updates an older preset to format 8 when the user overwrites it or saves its
  optional notes or tags. Simply finding or loading an older file does not change it.
- Keeps all format-7 CCXL choice matching and **Force Full Load** information in
  the new layout.
- Raises the safe line limit from 8,192 to 16,448 so the readable layout can
  still hold the existing maximum of 4,096 character options.
- Updates Help and the README with the new layout and upgrade behavior.
- Prevents ordinary comments in older presets from being treated as format-8
  option details.
- Lets automatic loading grow with the number of saved options instead of
  stopping at a fixed 400-pass limit.
- Makes the option check use saved choices and editor positions, so its result
  is closer to what the loader can apply.
- Stops rescanning every preset whenever the CET overlay opens. Select
  **Refresh** after changing files outside CET.
- Adds stronger checks before overwriting, deleting, moving, or reinstalling a
  file while continuing to recognize older shared-folder records.
- Improves backup recovery and places size and line limits on the saved preset
  list used during startup.
- Stores status types separately from their wording, so clearer text changes do
  not alter warning or success colors.
- Uses first-person wording for my AI disclosure, credits, and personal-preset
  answer.
- Fixes a CET startup failure caused by the main Lua function reaching CET's
  200-local-variable limit.
- Groups UI-only helpers under one internal UI table and removes small wrapper
  functions that repeated a single call.
- Adds a release check that keeps the main function at 190 active local
  variables or fewer, leaving room below CET's limit.
- Keeps the last good Trash names and folder information when the Trash folder
  cannot be read safely.
- Uses lightweight preset and Trash records at startup. A preset is read in full
  only when it is selected, loaded, edited, restored, copied, exported, or
  checked with **Refresh**.
- Stops a library scan safely if it exceeds the preset or saved-option limits.
- Rechecks the live editor after every applied option so loading never continues
  with an old game option list.
- Refreshes the selected preset's compatibility summary while the character
  editor changes. Selecting another preset and switching back is no longer
  needed.
- Refreshes related selected-preset and clothing details while their source
  information changes.
- Streams shared-folder export and import one preset at a time to lower memory
  use with large `.cpmfolder` files.
- Caches sorted Trash lists and folder totals until Trash changes.
- Keeps the Activity Log open during normal work, flushes it at useful points,
  and records each repeated loading warning only once per load.
- Uses the change totals already produced by **Refresh** instead of comparing
  every preset a second time.
- Fixes numbered Activity Log archives so they remain inside the Archive folder
  when two sessions receive the same date and time.
- Removes unused diagnostic and option-position state.
- Reconnects the fast loader to the current editor options before it reuses saved
  work, preventing an old game reference from being applied after the list changes.
- Checks newly discovered preset files during startup while continuing to reuse
  lightweight saved details for presets that were already known.
- Loads lightweight source presets before duplicating a folder, so an untouched
  preset no longer causes copy verification to fail.
- Shares repeated copy cleanup, preset hydration and verification, cache
  invalidation, and panel status resets without weakening their safety checks.
- Removes two shared-folder cleanup attempts that ran before any files had been
  created and now reports if later partial files cannot be removed.
- Fixes empty or partly drawn menu panels caused by core helpers being hidden
  inside a Lua scope that the menu and startup handlers could not access.
- Fixes lightweight startup records being mistaken for fully loaded presets,
  which made every preset show zero options and prevented it from loading.
- Fixes clicking a selected preset in the bulk list so it is removed from the
  selection instead of remaining selected.
- Keeps unknown startup option counts unknown and rejects damaged saved-list
  counts instead of turning either case into a real zero-option preset.
- Stops retrying the same leftover editor option forever when the game reports
  success but does not keep the change, then continues applying the preset.
- Applies the saved preset before clearing remaining options. Hairstyle-dependent
  color options that disappear during the hairstyle change are no longer cleared
  first.
- Checks the preset again after every cleanup change so a dependency rebuild
  cannot leave an earlier saved option unverified.
- Waits for a live option value to change, or for a dependent option to disappear,
  before treating an application as successful. A successful game call alone is
  no longer enough.
- Replaces rapid three-pass applications with elapsed-time deadlines and fresh
  option lists. If the game keeps returning an old `currIndex`, the change is
  reported as unconfirmed and is not applied repeatedly.
- Polls ordinary changes quickly and gives hairstyles and other option-list
  rebuilds a longer stable period.
- Reuses only validated text identities, editor positions, choice shapes, and
  saved-choice matches. It never keeps game option objects between passes and
  rebuilds stable metadata after an ordinary structure change. A failed identity
  check or Force Full Load use returns to full scanning for the rest of the load.
- Adds Activity Log measurements for option retrieval, scanning, choice matching,
  applied calls, live-value waiting, option-structure changes, and metadata reuse.
- Limits full choice-structure inspection to preset-related options. The first
  instrumented game test spent 65.1 of 70.2 seconds scanning all 1,496 exposed
  options, which caused continuous lag.
- Uses a clear final warning for saved options or cleanup changes the game did not
  confirm. A later pass can no longer replace that warning with a false fully
  applied message.
- Treats a hidden dependent option saved as zero as already clear. It no longer
  appears as missing in the option check or stops an otherwise complete load.
- Keeps retrieving a fresh game option list but checks only the pending ordinary
  option between full safety passes. It returns to a full pass before applying
  another option and disables reuse if the pending option no longer matches its
  position, name, occurrence, slot, active state, or choice structure.
- Avoids building temporary loader records for unrelated options during normal
  application and verification. Full option exposure remains available for
  cleanup and Force Full Load.
- Safely matches a hairstyle-dependent option that reappears under a different
  name when its editor slot count, slot occurrence, and unique saved choice all
  identify the replacement. The option check uses the same rule.
- Extends the Activity Log measurements with targeted-check time and fallback
  counts.
- Uses targeted checks between the first and final full dependency-stability
  checks. This reduces the remaining full-scan stutters without allowing another
  option to start before the final structure check.
- Fixes formats below 7 losing a hair color after Force Full Load applied it.
  Cleanup now revalidates and protects the exact forced selector instead of
  resetting it to zero and then incorrectly reporting the preset as complete.
- Returns to preset verification without clearing anything if the editor
  structure changes immediately before cleanup.

</details>

<details>
<summary><strong>Version 3.0.3</strong></summary>

## 3.0.3

*More reliable CCXL choices, safer forced loading, and clearer instructions.*

- Adds format-7 presets. They keep the normal option name and also save the
  option's position in the editor and a stable name for the selected choice when
  one is available.
- Finds a saved choice at its current position before applying it. Adding new
  CCXL hairstyles no longer makes a current preset choose a different hairstyle
  when the saved choice still exists.
- Adds the optional **Force Full Load** setting for related options that were
  renamed, such as a hair-color option tied to one hairstyle.
- Current presets use the saved editor position and choice during forced loading.
  Older presets use a limited position check and show a warning because they
  cannot identify a hairstyle after the list changes.
- Does not use an old choice number when a format-7 preset's saved choice is no
  longer available. This prevents the mod from knowingly choosing the wrong item.
- Places the window inside the screen area available to the game, including when
  Windows display scaling is active.
- Removes the unnecessary "already in this folder" note after a successful move.
- Makes preset and compatibility details shorter. Less-used information is under
  **More Preset Info**.
- Adds **Shared Folder Files**. It moves one selected `.cpmfolder` file to Trash
  without changing any presets or folders. The file can be restored or removed
  with **Empty Trash Permanently**.
- Moves a selected shared-folder file to Trash with one click. The old two-step
  confirmation could reset before the second click.
- Ignores temporary values such as `userdata: 0x...` when saving a choice name.
  Older affected presets safely use their saved choice number instead.
- Checks stable choice names only when needed and remembers the result during
  loading. This removes long pauses caused by checking 1,472 CCXL options again
  on every loading pass.
- Sets aside an option when another mod immediately resets it. Later options can
  still load, and the mod stops retrying after a safe limit.
- Keeps status messages visible until the CET overlay closes.
- Remembers the main folder created by each imported `.cpmfolder` file. The same
  file can be imported again after that folder is deleted.
- Remembers the `.cpmfolder` list while the menu is open and refreshes it only
  when a file action or overlay refresh requires it.
- Rewrites the mod Help, normal menu text, README, changelog, and included text
  files in plain language. Old Help details were removed, and current controls
  now use the same names in the mod and README.

</details>

<details>
<summary><strong>Version 3.0.2</strong></summary>

## 3.0.2

- Moves settings, folder lists, preset records, recovery files, Trash, and logs
  under `Data`.
- Keeps `Character Presets` for preset files, Windows folders made by the user,
  and shareable `.cpmfolder` files.
- Keeps imported `.cpmfolder` files unchanged and records completed imports in
  `Data/Catalog/Imported Bundles.txt`.
- Skips a file only when its name and contents match an earlier completed import.
  A changed file with the same name can be imported again.
- Records an import only after all preset and folder information is saved. A
  failed import can be tried again.
- Does not move loose files left by older releases. A clean replacement install
  is needed to remove those old files.

</details>

<details>
<summary><strong>Version 3.0.1</strong></summary>

## 3.0.1

- Shows a preset's full path, such as `sa/Femme Fatale V2`.
- Lets CET remember the window size while keeping 420 by 700 as the first-use size.
- Renames the safe folder action to **Remove Folder, Keep Presets** and adds a
  clear confirmation showing where the contents will move.
- Moves known presets out of an Imported Windows folder before removing it. A
  folder containing unknown files is always kept.
- Places folder Trash under **Folders** and keeps multi-preset Trash under
  **More Trash Options**.
- Adds `.cpmfolder` export and import for sharing a complete folder group.
- Lowers memory use while importing and exporting without changing the file
  format or safety checks.
- Uses `Character Presets` as the only location for `.cpmfolder` files.
- Fixes a startup failure caused by the main Lua file becoming too large for a
  LuaJIT limit.
- Wraps long guidance so it remains readable in a narrow CET window.
- Keeps the character-screen reminder on until the user turns it off in Settings.
- Renames the main sections to **Load Preset**, **Rename & Copy**, and
  **Delete & Restore**.
- Removes old folder-slot cleanup and retired reminder, Trash, and import systems.
  Older preset files remain readable.

</details>

<details>
<summary><strong>Version 3.0.0</strong></summary>

## 3.0.0

### Interface and instructions

- Reorganizes the README and changelog into topic and release groups.
- Explains the limited use of AI for menu layout planning and expands the credits.
- Adds the official Discord link and lists EKT Custom Character Creator as a
  compatible example.
- Fixes the save-destination chooser so it stays open and shows the new location.
- Uses consistent button sizes and shows whether the reminder is on or off.
- Groups Trash, restore, and permanent cleanup controls together.
- Makes folder arrows, secondary buttons, selected rows, and first-open window
  sizing clearer and more consistent.

### File safety and speed

- Adds a recovery record for Trash, restore, multi-preset moves, folder restore,
  and preset-file renames.
- Safely undoes unfinished file actions at startup when possible.
- Saves the full folder group when moving a folder to Trash, including empty
  folders inside it, and restores the group in one action.
- Checks Trash records for unsafe names, paths, sizes, and excessive content.
- Remembers search results, folder counts, and selections until the data changes.
- Avoids rewriting folder and Trash files when their contents did not change.
- Treats invalid dates as unknown and reports incomplete file-list updates as
  warnings instead of showing a false success.

### Features

- Adds preset and folder search, **Refresh**, folder counts, and selected-preset
  details.
- Adds a compatibility summary and **Cancel Loading**.
- Keeps the save destination visible and adds sorting by name or last change.
- Adds a plain settings file and **Reload Settings File**.
- Disables actions that are not ready and explains what is missing.
- Adds Trash that can restore presets, folders, and filtered multi-selections.
- Adds **Remove Folder, Keep Presets**.
- Adds preset source, dates, notes, and tags.
- Renames a preset's shareable `.preset` file when the preset is renamed.
- Moves developer counters under advanced details and places the Activity Log in Help.
- Keeps full apartment mirror options unchanged.

</details>

<details>
<summary><strong>2.0.x release history</strong></summary>

### 2.0.8

- Makes the character-screen reminder smaller, sharper, centered, and easier to read.
- Keeps the reminder visible until CET opens and saves the user's reminder choice.
- Places the reminder, Activity Log, and Help controls in one responsive top row.
- Fixes the full-editor button staying disabled after some character screens close.
- Reduces repeated work while the menu, reminder, search, Help, and automatic
  loading are active.
- Adds clear messages for preset limits and invalid character-option values.

### 2.0.7

- Restores saving for CCXL options that use the game's full 32-bit choice range.
- Uses the same number checks while saving and loading.
- Records the exact option and failed limit in the log when a value is unsafe.

### 2.0.6

- Shows assigned editor and window keys in Help when CET can provide them.
- Clarifies that Photo Mode and Appearance Menu Mod may stay installed, but their
  own menus cannot be used to save or load.
- Stops an unsafe or overly deep Windows-folder scan without replacing the last
  good preset list.
- Adds size, line, option-count, name-length, and choice-number limits for
  imported presets.
- Stops guessing when a saved CCXL option is missing.
- Replaces the 16 packaged folder slots with unlimited folders stored by the mod.
- Finds Windows folders inside `Character Presets` and labels them Imported.
- Improves safe copying, file-list updates, new-game checks, editor fallback,
  name checks, and error messages.

### 2.0.5

- Removes unreliable automatic checks for ACU and Character Customization Anywhere.
- Moves the most important compatibility warnings to the top of Help.
- Simplifies section controls and user-facing text.
- Adds the clothing and **No Outfit** workaround for Cyberpunk's loading-screen
  problem after closing a character editor.
- Hides the clothing message in the real new-game editor and avoids changing
  equipment automatically.

### 2.0.4

- Temporarily removes an active wardrobe outfit before opening the editor and
  restores it afterward.
- Prevents some wardrobe outfits from leaving the confirmation screen stuck.

### 2.0.3

- Groups presets under folders in the Load list and shows presets without a
  folder below them.
- Makes every main section open or close and shortens the menu instructions.

### 2.0.2

- Removes unused source-code comments without changing the mod.
- Replaces the preset-folder placeholder with one short instruction.

### 2.0.1

- Removes an ACU check that could report ACU after it was uninstalled.
- Keeps the ACU warning in Help and the README.

### 2.0.0

- Renames the project to **Character Preset Manager (CET)** and updates its mod
  folder, preset folder, files, window, key label, Help, project file, and archive.
- Renames `character-presets` to `Character Presets`.
- Requires a clean update from 1.0.x: back up presets, remove the old mod folder,
  install 2.0.0, and restore the presets.
- Opens the renamed window near the right side the first time and remembers the
  user's chosen position after that.

</details>

<details>
<summary><strong>1.0.x release history</strong></summary>

### 1.0.18

- Makes preset and file-list updates safer if the game closes during a write.
- Checks new, replaced, copied, renamed, and moved presets before using them.
- Warns about damaged lines while keeping valid preset entries available.
- Shows how many recyclable folder slots remain.

### 1.0.17

- Repairs empty packaged folder slots that some mod tools could remove.
- Adds consistent full-width buttons and status panels.
- Detects preset and folder changes made outside CET.
- Adds preset and folder copying with cleanup after an incomplete copy.
- Adds confirmed permanent folder deletion and shows how many presets it affects.

### 1.0.16

- Adds Windows-folder scanning, folder creation, rename, safe deletion, and preset moves.
- Refuses to delete a non-empty folder.
- Uses 16 packaged folder slots because of the CET file limits used at the time.

### 1.0.15

- Adds **Open Full Appearance Editor** and an optional CET key.
- Opens the full game editor and gives apartment mirrors all creator options.
- Adds detailed Activity Log entries and clearer Help for keys and editor use.
- Places the window near the right side on first use.

### 1.0.14

- Removes the old companion folder under ACU and imports compatible ACU preset
  files directly from Character Preset Manager's own preset folder.
- Improves status colors, Help, file-path displays, and Activity Log archives.
- Starts a new log for each game launch and keeps the 10 newest older logs.

### 1.0.13

- Adds clearer name fields, full-width preset deletion, and responsive panel sizes.
- Adds an in-menu log viewer with Refresh and Copy.
- Adds an ACU information button when the old automatic check finds ACU.

### 1.0.12

- Improves the window layout, colors, status panels, and Help.
- Adds safe preset replacement and two-step preset deletion.
- Stops loading after repeated checks make no progress.

### 1.0.11

- Refreshes the visible character choices after loading so the screen matches the
  applied preset without using Next and Back.
- Makes editor observation failures non-fatal.
- Adds clearer ACU recovery steps, safe preset-name checks, confirmed deletion,
  and one current plus one previous session log.

### 1.0.10

- Adds automatic detection for the ACU DLL used at that time.
- Blocks Preset Manager for the session when ACU is loaded and asks the user to
  remove ACU and restart the game.

### 1.0.9

- Stops several missing ACU entries from fighting over one CCXL option.
- Leaves unclear matches unchanged instead of repeatedly changing the appearance.
- Expands the README with saving, loading, ACU import, CCXL, and Photo Mode details.

### 1.0.8

- Applies a parent option, such as hairstyle, before its related color option.
- Remembers related options that become hidden after they are applied.
- Fixes some CCXL hair presets stopping with one option left.

### 1.0.7

- Changes one option at a time while Cyberpunk rebuilds the editor.
- Clears only visible cosmetic options missing from the selected preset.
- Skips repeated options when the match is unclear.

### 1.0.6

- Makes loading one click and waits between automatic passes.
- Stops after three checks find the same missing options.
- Adds the ACU preset bridge used at that time and shows those presets as read-only.

### 1.0.5

- Darkens selected and highlighted rows so white text is easier to read.

### 1.0.3

- Renames the early project to **Preset Manager (CET)**.
- Fixes incomplete loading and keeps the Continue button active between passes.
- Clears visible cyberware, tattoos, and scars that are missing from a preset.

### 1.0.2

- Internal test build; not released.

### 1.0.1

- Makes mod managers create the preset folder on a new installation.
- Fixes saving on installs where empty folders were not included.

### 1.0.0

- First public release.
- Saves and loads shareable character preset files through CET.
- Supports standard and repeated CCXL character options.
- Shows progress during the multi-step loading system used at the time.

</details>
