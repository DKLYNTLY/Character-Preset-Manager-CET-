# Changelog

The newest release appears first. Older sections show what changed at the time
of each release. They may mention controls or file locations that are no longer
used. See the README and in-game Help for current instructions.

<details open>
<summary><strong>Latest release — 3.0.8</strong></summary>

## 3.0.8

*More recovery and library controls in the character screen, using the same compact space.*

- Adds **Refresh** beside Search so preset files changed outside the game can
  be shown without opening CET.
- Adds a selected-preset card with its folder, saved-option count, file format,
  and tags.
- Adds **Undo Last Load** for the newest recovery appearance and **Recovery
  History** for choosing from the five saved recovery entries.
- Reuses the preset-row area for recovery history instead of widening the panel
  or adding a second permanent list.
- Changes **Save Location** from a one-folder-at-a-time cycle into a scrollable
  folder picker. The picker also reuses the preset-row area and includes **All
  Presets**.
- Gives completed loads a short Panel Status result with the number of saved
  options. Loads with unconfirmed or less certain matches offer **View Load
  Details in CET** and open the advanced Load section.
- Renames **Open CET Menu** to **Advanced Preset Manager** and moves it below
  the everyday load, recovery, save, and Trash controls.
- Shortens the panel introduction and shows nine preset, folder, recovery, or
  save-location rows in the shared list area.
- Disables conflicting save, Trash, search, and recovery controls while a
  picker is open or an appearance operation is running.
- Caches the native panel's prepared preset rows by library, search, and folder
  state. Save-location rows are cached separately until the library changes.
- Reads appearance-history files only when the player opens Recovery History.
  No editor scan, compatibility check, or preset refresh was added to the
  normal frame-update path.

</details>

<details>
<summary><strong>Version 3.0.7</strong></summary>

## 3.0.7

*Preset controls inside Cyberpunk's character screens, with safer appearance recovery.*

- Clears old dependent choices before applying a preset, preventing hidden
  options such as Alina's heterochromia and separate eye colors from remaining
  on bundled default presets.
- Shows the character-screen preset panel reliably in the Full Appearance
  Editor, apartment mirrors, ripperdocs, and new-game character creation even
  when the preset library is still connecting during the screen's first setup
  moment.
- Adds an **Open CET Menu** button below the panel instructions and above
  Search. Preset rows and the lower action buttons now sit closer together.
- After **Open CET Menu** is pressed, Panel Status explains how to use the CET
  binding and find the Character Preset Manager menu on the right.
- Uses one translucent charcoal background behind the complete panel. Its
  right edge stops at the title area instead of extending over the character.
- Connects CET to the exact bridge used by each active appearance screen and
  sends the preset list immediately. This prevents mirrors and the Full
  Appearance Editor from remaining on **connecting**.
- The short panel instructions now say to click once and explain that CET
  contains extra options, permanent deletion, and Help.
- Rewrites the README as a cleaner section-by-section guide. Features and Trash
  keep concise lists, while installation, controls, preset behavior, sharing,
  compatibility, troubleshooting, and credits use clear explanations.
- Adds dedicated preview media for the simple character-screen menu and the
  advanced CET manager to their matching README sections.
- Removes redundant dependency exclusions, repeated compatibility answers, and
  other low-value text from the README.
- Checks a fresh editor state while clearing old options and gives the editor
  time to settle. This prevents successful clears from being reported as
  unconfirmed while preserving warnings for options that truly remain set.
- Paces fresh cleanup checks at the normal loading interval and reuses the
  confirmed state during its short stability wait. Large appearance lists are
  never rescanned every frame or at the faster native-panel polling rate.
- Adds an original Cyberpunk-style preset panel to new-game character creation,
  the Full Appearance Editor, apartment mirrors, and ripperdoc appearance
  editors.
- Replaces the new-game screen's three preset buttons with the complete preset
  library. Six packaged starter presets preserve the Corpo, Nomad, and
  Streetkid choices for both body types.
- Adds a larger native panel farther left on the character screen. It uses the
  red and cyan colors from Cyberpunk's character-customization controls,
  increases the text size, and moves the game's Randomize controls below it.
- Removes the solid black panel behind the native controls. The character stays
  visible through the panel, while Search and Preset Name keep their dark input
  fields. Buttons now use translucent charcoal-black surfaces with red labels
  and a cyan selected state instead of solid bright red blocks.
- Shortens the native panel on its character-facing side so it covers less of
  the appearance preview. Removes the distracting scroll caption and static
  scrollbar; mouse-wheel, stick, and navigation scrolling continue to work.
- Extends the panel downward to just above Randomize and shows ten preset rows
  at once. The remaining room gives Panel Status more space while the save
  controls stay together.
- Narrows the panel's character-facing edge by another 170 interface units so
  buttons no longer cover the hairstyle preview. Shorter headings and help text
  keep the same controls readable at the smaller width.
- Uses a standard hyphen in the combined Panel Status line because the game's
  font could leave the whole message invisible when it contained a long dash.
- Removes the cyan preset-availability subtitle and raises **Character Preset
  Manager** to align with the game's **Customize Your Look** heading. Search
  and the preset list move upward, giving Panel Status more than twice its
  previous message height without moving the bottom controls.
- Matches every preset and action button's resting transparency to the Search
  and Preset Name fields. Red and cyan labels remain fully readable, with a
  temporary stronger surface only while a button is pressed.
- Tightens the gap between preset rows from 22 to 8 interface units. Panel
  Status begins directly below the tenth row and receives the recovered space.
- Keeps strong references to the Panel Status text and color rail so the game
  cannot discard them while the panel remains open.
- Makes Panel Status event-driven and hidden when there is nothing important to
  report. It no longer repeats old CET editor guidance, search counts, folder
  browsing, or save-location changes. Loading, overwrite, Trash, and error
  messages remain visible, and Trash messages persist through list refreshes.
- Adds a reminder to native Trash confirmations and completed moves that CET is
  where the preset can be restored or deleted permanently.
- Reduces the required supporting mods from eight to four. ArchiveXL, Mod
  Settings, Native Settings UI, and Native Settings UI Side Menu Add-on are no
  longer required. Preset Sort Order remains available in CET Settings.
- Shows a ready message whenever the native character-screen panel opens, with
  short loading instructions and a reminder that logs, settings, renaming, and
  other advanced tools are in CET.
- Removes the native panel's compatibility-review interruption. Selecting a
  preset starts loading directly; Check Compatibility remains available in CET.
- Applies button transparency through the widget itself so resting charcoal
  backgrounds remain translucent in the game instead of appearing opaque.
- Fixes native overwrite confirmation being canceled when Save released focus
  from an unchanged Preset Name field. Only an actual name edit now cancels the
  pending confirmation, preserving the existing fingerprint safety check.
- Changes preset and action button surfaces from maroon to translucent
  charcoal-black like the CET window. The **Character Preset Manager** title
  now uses the same cyan as folder rows.
- Rewrites the native panel introduction around its everyday actions and adds
  one clearly labeled **Panel Status** area. Search results, folder changes,
  saves, Trash confirmations, loading progress, final results, and failures now
  appear there without requiring the CET overlay. Errors use a red marker.
- Keeps the panel's original single-click preset loading behavior.
- Combines the native status heading and message into one always-visible line
  so search, selection, loading, save, and Trash results cannot appear in an
  empty area below a separate heading.
- Releases a clicked native button's UI focus after its action so Cyberpunk's
  Q and E character rotation keeps working. Search and Preset Name still keep
  keyboard focus while the player is typing.
- Starts with only **Open & Edit Appearance** expanded in the CET window. Every
  other main section starts collapsed and can still be opened normally.
- Keeps the native preset panel synchronized after presets are restored,
  renamed, moved, or removed in CET. The native Trash button is unavailable
  until a preset is selected, and only that button's first press can change it
  to **Confirm Move to Trash**.
- Uses the proven verified loader from version 3.0.6 for every preset. It keeps
  the same deliberate waits, dependency handling, cleanup, and final checks
  instead of using the experimental Fast Load path.
- Places **Search** above one scrollable list ordered like CET's **Load & Restore
  Appearance** list. Folder rows open and close their presets, Favorites stay at
  the top, and presets outside folders appear last. Mouse-wheel and controller
  scrolling are handled by the visible list rows.
- Places **Preset Name**, **Save Location**, **Save Preset**, and **Move Preset
  to Trash** below the list. When needed, the same button changes to **Confirm
  Overwrite** or **Confirm Move to Trash** for the second press. No separate
  confirmation buttons are added.
- Keeps rename, permanent deletion, Help, comparison, favorites, folders,
  backups, Trash recovery, and Empty Trash in CET.
- Supports mouse, keyboard, and controller navigation. Actions are unavailable
  while the editor is refreshing or a preset is loading.
- Keeps Lua as the only implementation of preset files, matching, loading,
  folders, backups, Trash, and recovery. The redscript panel sends narrow
  requests to Lua instead of copying those rules.
- Leaves the original character screen working when the native bridge is not
  available. The CET window remains the advanced manager and safe fallback.
- Expands preset comparison into **Already matching**, **Will change**,
  **Missing**, **Repeated or uncertain**, **Invalid**, and options that loading
  will clear.
- Makes loading and comparison share the same prepared preset identities used
  for label, occurrence, editor-slot, and saved-choice matching.
- Replaces the single previous-appearance file with five recovery entries. It
  saves before normal loads, skips identical appearances, records the date,
  saved-option count, and triggering action, and always saves the current
  appearance before restoring an older entry.
- Keeps appearance history outside the normal library, sharing files, complete
  backups, and Trash. Clearing it requires confirmation.
- Shows all five recovery entries under **Appearance History** directly below
  **Restore Previous Appearance** in CET. Each entry can be restored, and the
  complete history can be cleared with confirmation.
- Renames **Preset Options** to **Advanced Preset Options** for compatibility
  checks, Force Full Load, and Favorites.
- Keeps only **Preset Sort Order** as a preference. It is available in the CET
  Settings tab. The reminder notification,
  clothing-warning setting and behavior, and Activity Log detail setting are
  removed.
- Keeps the native panel, five-entry history, pre-restore safety save,
  missing-option warnings, and CET fallback enabled instead of exposing settings
  that could weaken normal operation. Comparison details remain available in
  CET.
- Polls the native request bridge 20 times per second. Preset comparison and
  library refresh work runs only after a matching
  user action, preventing repeating scans during normal frames.
- Fixes the native panel's redscript compilation against the installed game
  definitions by using supported color values, string comparison, and widget
  removal calls.
- Requires only Cyber Engine Tweaks 1.37.1, RED4ext 1.30.0, redscript 0.5.31,
  and Codeware 1.20.3 or newer.
- Keeps older Character Preset Manager and compatible ACU preset files
  loadable. ACU and Character Customization Anywhere remain incompatible and
  must be removed before starting the game.

</details>

<details>
<summary><strong>Version 3.0.6</strong></summary>

## 3.0.6

*Smoother CET performance for large appearance setups and libraries.*

- Keeps preset selection lightweight by showing only the preset name, folder,
  and saved-option count. It no longer starts a compatibility scan.
- Adds **Check Compatibility** under **Preset Options**. The scan runs once when
  selected, and its found, missing, repeated, and invalid totals appear in the
  Load status card.
- Reads the selected preset's saved-option count and details before displaying
  them. **Check Compatibility** no longer changes its source, notes, or tags.
- Restores one compact selected-preset line for its name, folder, saved-option
  count, and format. **Preset Options** contains **Check Compatibility**, the
  favorite action, and **Force Full Load** so it is less likely to be enabled
  accidentally.
- Uses familiar arrow headers for main sections and Help topics. They have a
  near-black background with white text. Optional controls return to compact,
  centered charcoal buttons with white text. Their responsive width keeps short
  and long labels balanced as the window changes size. Only editor and Load
  start open.
- Adds a divider line before every main section, making section boundaries easy
  to see without relying only on the header text.
- Moves every main status card below its section introduction and above the
  controls. Current requirements, warnings, and results are easier to see
  before selecting an action.
- Places optional control bars after each section's main actions. The Save
  status card now includes the selected save location, and repeated section
  details were removed to keep the main path clear.
- Separates the important value in every status card from its instruction or
  result. Save locations, selected presets, destinations, backup counts, and
  recoverable-item counts appear on their own orange line.
- Changes neutral status headings and borders from yellow to blue. Orange now
  identifies the important current value, while green, yellow, and red retain
  their ready, warning, and error meanings.
- Stops repeating the complete preset compatibility check every 0.75 seconds
  while a preset is selected. Opening CET, refreshing presets, changing Force
  Full Load, and finishing a load also no longer start the display-only scan.
- Records a performance warning only when retrieving appearance options or
  matching a preset takes at least 0.05 seconds. The warning separates the time
  spent retrieving game options from the time spent matching the preset.
- Splits large preset, folder, Trash, sharing-file, backup, sharing-preview, and
  Activity Log lists into pages. Every item remains available without drawing
  the entire collection on every frame.
- Shows closed Help topic headings until the user opens one. Help searches still
  open all matching instructions directly.
- Caches the complete-library backup file list while the interface is open and
  adds **Refresh Backup File List** for files changed outside the mod.
- Checks for the previous-appearance recovery file when the overlay opens and
  after recovery actions instead of checking the drive on every drawn frame.

</details>

<details>
<summary><strong>Version 3.0.5</strong></summary>

## 3.0.5

*Faster access to useful details and more consistent controls.*

- Fixes complete-library backups failing while checking the size of the first
  preset file.
- Verifies that every current preset and folder record, including presets in
  Imported Windows folders and folders made in CET, is present before reporting
  a complete-library backup as successful. Export and import results now show
  both preset and folder counts.
- Adds **Delete Selected Backup Permanently** with a required second
  confirmation inside **Export & Import Backups**.
- Gives every main menu section one consistent status card. The card shows what
  the section needs, when it is ready, whether an action succeeded, and any
  warning or error. Backup actions now use the same status colors, and folder
  actions no longer display a second Bulk status card.
- Places **Force Full Load** directly above **Load Selected Preset**, moves
  **Restore Previous Appearance** below the normal loading controls, and shows
  Force Full Load and preset compatibility cautions in the Load status card
  instead of loose colored text.
- Labels new format-8 files as **CPM Preset** and records their preset name and
  CET library folder in readable text. If a preset has no saved folder-list
  entry, the mod can rebuild its name and folder from the preset file. Older
  CPM and compatible ACU presets remain readable.
- Adds **View Selected .cpmfolder Contents** so a sharing file's main folder,
  nested folders, and included presets can be checked before installation.
- Releases finished preset-loading data after it is no longer needed, reducing
  memory kept during long play sessions.
- Unloads full preset contents and clears rebuildable interface lists when the
  mod window is hidden. Preset names, notes, tags, favorites, and other details
  remain available and are read again when needed.
- Clears the displayed Activity Log from memory when its panel closes.
- Prevents the Lua 200-local-variable startup failure from returning by keeping
  the affected shared functions in one stable helper namespace. This also
  prevents missing-function errors in preset, folder, log, and session actions.
- Splits the mod into smaller, focused files so Lua compiles each part
  separately. The menu sections and preset loader are also divided into
  shorter functions without changing controls, preset files, or loading rules.
- Organizes the mod's internal working data into focused groups for presets,
  loading, Trash, the interface, cached lists, the editor, and status messages.
  This does not change controls, preset files, or loading behavior.
- Fixes the CET window failing to register after the module split. Module paths
  now use CET's required slash format, allowing every module and window callback
  to load correctly.
- Fixes the 3.0.5 menu opening as an empty window because its version label was
  unavailable to the interface after the Phase 3 internal reorganization.
- Adds a **Log** button beside **Settings** and **Help**, so the Activity Log is
  available without scrolling through Help.
- Makes Settings, Help, and the Activity Log close one another when a different
  panel opens.
- Keeps the search controls usable in a narrow CET window.
- Searches preset tags as well as preset and folder names.
- Shows a preset's tags on the same line as its name in the preset list.
- Uses the same compact **More Technical Details** control in the Activity Log
  as the other optional detail areas.
- Identifies an unconfirmed format-7 or format-8 option with the preset's saved
  LocKey, editor slot, choice, and index in the Activity Log. Older presets now
  clearly explain that they did not store enough details to identify the exact
  option.
- Keeps the selected preset's folder and its parent folders open after a search
  is cleared.
- Adds **Copy File Path** under **Rename & Copy Presets > Tags, Notes & File**. It
  copies the complete path from the Cyberpunk 2077 game folder.
- Uses the same status handling for every folder action, keeping message colors
  consistent.
- Uses one shared safe-writing path for preset, settings, catalog, bundle, log,
  and window-position files.
- Removes an unused older-format writer. Older Character Preset Manager and
  compatible ACU preset files remain fully readable.
- Simplifies the Load button's disabled state without changing when it can be
  used.
- Runs one final read-only check before the load summary. An option that finishes
  changing near the end of a load is now confirmed instead of being left as an
  unconfirmed result.
- Reuses loader work tables and rebuilds the full option-list fingerprint only
  when the option count changes or a recent change may affect dependent options.
- Checks a pending option every 0.05 seconds, while ordinary passes now wait
  0.225 seconds. This keeps confirmation responsive and reduces work between
  changes.
- Reuses the game's option list within the same update frame instead of asking
  the game for it more than once.
- Turns **Force Full Load** off when a current preset is selected and turns it on
  automatically for an older preset that needs position-based matching. The
  manual control remains available for either choice.
- Removes the repeating equipped-clothing scan from the Load status. Help still
  explains the clothing and **No Outfit** workaround, and active wardrobe outfits
  are still removed temporarily and restored afterward.
- Places **Clear** and **Refresh** on a full-width row below preset search in a
  narrow window, so neither label is cut off.
- Adds **Select & Manage Multiple Presets** so one selection can be moved to a chosen folder,
  exported as one shared-folder file, or moved to Trash.
- Moves those controls into a separate **Select & Manage Multiple Presets** section
  instead of hiding them under **Delete & Restore Items**.
- Makes every bulk preset row a clear selection button that changes to **Selected**
  and can be selected again to remove it from the group.
- Adds persistent Favorites. Favorite presets stay in their folders and also
  appear in a pinned group above the regular preset tree.
- Places **Add Selected Preset to Favorites** under **Load & Restore Appearance > Favorites & Details**, keeping it available without treating
  the small action as a primary workflow.
- Adds complete `.cpmbackup` export and import. A backup contains
  every preset, the CET folder layout, and the current settings file without
  overwriting colliding items in an existing library.
- Moves complete-library export and import out of Settings into a visible
  **Export & Import Backups** section with direct controls.
- Saves a hidden recovery snapshot before each new preset load and adds a
  **Load & Restore Appearance** action to restore the appearance that was active before that load.
  Snapshot failure is logged and never delays or blocks loading.
- Adds Help search with topic keywords and common terms such as **share**,
  **bug**, **clothing**, **ACU**, **backup**, **Trash**, and **favorite**.
- Adds a clear **Search** button and pauses the long Help list while text is being
  entered, preventing repeated redraws and making search results obvious.
- Replaces vague expandable labels with labels that name the controls inside,
  including folder actions, preset details, bulk actions, and backup tools.
- Groups `.cpmfolder` install and export under **Share & Import Folders**,
  with file removal under **Manage & Remove .cpmfolder Files**.
  Removing a sharing file still states that installed presets and folders are not deleted.
- Uses clearly named secondary buttons for Favorites and details, preset details,
  folder sharing, Settings, and Activity Log tools so each primary workflow stays short
  and focused.
- Renames every main section with the same **action & action + object** pattern.
- Keeps **Favorites & Details** above **Restore Previous Appearance**, places the
  favorite action below the preset details, keeps **Force Full Load** unchanged,
  and removes the extra undo heading.
- Renames **Save Folder Choices** to **Save Location** and removes
  the `Optional:` and `Folder:` prefixes from secondary buttons.
- Expands searchable in-game Help with a plain explanation for every button,
  including changing labels, confirmation actions, selection rows, and dropdowns.
- Renames the expanded **Hide Optional Preset Tools** label to
  **Hide Tags, Notes & File**.

</details>

<details>
<summary><strong>Version 3.0.4</strong></summary>

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
- Advances an ordinary option on the next normal check instead of targeted
  polling or a separate 0.20-second settling period. Hairstyles and other
  option-list rebuilds still receive a longer stable period.
- Removes the loader's general option-metadata cache. It keeps fresh game option
  lists, compact dependency state, and saved-choice matches that are checked
  against the current option before reuse.
- Adds Activity Log measurements for option checks, full scanning, dependency
  checks, choice matching, applied calls, waiting, and dependency changes.
- Limits full choice-structure inspection to preset-related options. The first
  instrumented game test spent 65.1 of 70.2 seconds scanning all 1,496 exposed
  options, which caused continuous lag.
- Uses a clear final warning for saved options or cleanup changes the game did not
  confirm. A later pass can no longer replace that warning with a false fully
  applied message.
- Treats a hidden dependent option saved as zero as already clear. It no longer
  appears as missing in the option check or stops an otherwise complete load.
- Keeps retrieving a fresh game option list after each applied change. Small
  targeted checks are reserved for a confirmed dependency wait and fall back to
  normal full checks if the option no longer matches its current identity.
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
- Replaces full option-structure difference reports with one short dependency
  message when the editor adds, removes, disables, or rearranges options.
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
