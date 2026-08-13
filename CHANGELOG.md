# Changelog

## 2.0.7

- Restores preset saving for CCXL and other custom options that expose the
  game's unsigned 32-bit no-selection index instead of rejecting the entire
  snapshot at the 2.0.6 safety limit.
- Trusts valid native indexes read from the active character editor while
  retaining choice-range checks when imported preset values are applied.
- Validates against all available custom-option choice metadata instead of
  stopping at the first populated collection.
- Logs the exact option, index, key size, and saved-entry count if customization
  data still cannot be represented safely.

## 2.0.6

- Shows the assigned editor input and window-toggle hotkey directly in Help by
  using CET's supported binding API, with an honest session-detection fallback
  when the installed CET version cannot return a key name.
- Clarifies that Photo Mode and Appearance Menu Mod are compatible and may remain
  installed; Character Preset Manager simply cannot save or load presets from
  inside their interfaces.
- Separates the Photo Mode and Appearance Menu Mod limitation from the in-game
  incompatible-mod warning.
- Makes recursive manual-folder scans fail closed when a directory entry cannot
  be verified or nesting exceeds the safety limit.
- Retains the previous in-memory preset list and inventory after an incomplete
  filesystem scan instead of replacing them with partial or empty results.
- Rejects oversized and unsafe imported preset data before it reaches the game,
  with limits for file size, lines, entries, key length, and option indexes, plus
  active option-choice range checks when the game exposes that metadata.
- Removes positional CCXL replacement guessing so a missing saved option can no
  longer be applied to a different option based only on neighboring positions.
- Reports accurate in-progress load counts and cancels automatic loading when
  the selected preset disappears.
- Centralizes load-state and confirmation cleanup, clears destructive actions
  when the overlay or selection changes, fingerprints confirmed preset files,
  and restarts folder confirmation if its inspected entries change.
- Replaces the 16 packaged directory slots with virtual folders stored in a
  manager-owned catalog, removing the fixed slot limit.
- Removes untouched legacy slot directories during startup while leaving any
  slot directory containing unrecognized files or folders unchanged.
- Discovers manually created directories recursively, labels them as imported,
  retains each preset's physical path, and never renames or removes the manual
  directory itself during virtual folder operations.
- Reports incomplete duplicate-folder rollback honestly and streams copied files
  and activity-log reads instead of loading them entirely into memory.
- Keeps the preset inventory synchronized after in-app saves and deletions.
- Uses actual new-game scenario tracking so expanded mirrors are not mistaken
  for the new-game editor.
- Disables the full-editor launcher when required hooks are unavailable and
  falls back to the game's original handler if custom editor setup fails.
- Validates final truncated names, handles case-insensitive folder collisions,
  removes duplicate file helpers, and replaces unsupported punctuation.

## 2.0.5

- Removes unreliable automatic checks for Appearance Change Unlocker and Character
  Customization Anywhere.
- Moves compatibility and known-issue information from the main window to the top
  of Help, ordered by the problems users are most likely to encounter.
- Uses the same standard ImGui collapsing-header pattern as 0-Engine.
- Matches section-header backgrounds to the window while retaining amber text,
  borders, and interaction feedback.
- Resets saved section state so Appearance Editor, Load, and Create start expanded.
- Uses `[+]` and `[-]` markers for preset-folder rows to distinguish expansion
  controls from folder names.
- Clears completed, error, and informational status messages after eight seconds
  while retaining active operations, confirmations, and required guidance.
- Rewrites all user-facing interface text in a concise, neutral, formal tone.
- Documents why Character Customization Anywhere conflicts with vanilla mirror
  customization and shares the game's customization-exit loading issue.
- Adds an in-game Help workaround recommending that affected users unequip
  clothing and select No Outfit before customization, especially with
  Equipment-EX or highly detailed outfits.
- Detects equipped clothing while customization is open and replaces the normal
  green Load status with an optional yellow notice explaining the workaround.
- States that the clothing notice may be ignored and does not indicate a mod problem.
- Reorganizes Help into short, clearly labeled sections with simpler wording and
  less repeated information.
- Rewrites the README to match the public mod description and removes internal
  implementation details that are not needed for installation or normal use.
- Tracks the dedicated new-game customization screen to hide clothing notices
  caused by hidden starter items without running a native pre-game query.
- Suppresses the clothing warning in the genuine new-game character creator.
- Leaves equipment management manual to avoid interfering with equipment mods.

## 2.0.4

- Temporarily disables an active wardrobe outfit before the character editor
  initializes and restores it when the editor closes.
- Prevents wardrobe outfits from leaving the customization confirmation screen
  stuck in an endless loading state.

## 2.0.3

- Groups presets in the Load list beneath collapsible `Name (folder)` rows.
- Lists presets stored in the root preset directory below all folder groups.
- Makes every main section collapsible, with Load and Create expanded by
  default and the other sections collapsed to save vertical space.
- Rewrites the in-game help, warnings, status messages, and section text in
  shorter, more conversational language without changing behavior.
- Keeps Appearance Editor expanded by default and replaces the small collapse
  arrows with clearer `[+]` and `[-]` markers.

## 2.0.2

- Removes nonfunctional explanatory and decorative comments from the shipped
  Lua source without changing runtime behavior.
- Reduces the packaged preset-folder placeholder to one plain instruction.

## 2.0.1

- Removes automatic ACU DLL detection and all related control blocking after
  runtime symbol checks falsely identified ACU on systems where it was no
  longer installed.
- Keeps the ACU incompatibility warning in the in-game Help panel and README;
  users remain responsible for not running both mods together.

## 2.0.0

- Renames the mod everywhere to **Character Preset Manager (CET)** so its
  purpose is clear and the full name is discoverable in Nexus Mods searches.
- Renames the installed CET mod directory to `Character Preset Manager (CET)`.
- Renames the preset directory from `character-presets` to the properly
  capitalized, dash-free `Character Presets`.
- Renames the packaged recyclable folder-slot pool and marker resources to use
  the Character Preset Manager name.
- Renames the inventory, activity log, archived logs, CET window, hotkey label,
  help text, project metadata, and release archive consistently.
- Documents the one-time upgrade process for preserving existing presets and
  removing the old CET mod folder before installation.
- Removes hyphens from all new mod-owned folder and file names, including the
  hidden `Character Preset Manager Folder Slots`, its marker files, and the
  `Slot 01` through `Slot 16` resource directories.
- Requires users upgrading from 1.0.x to back up their presets, completely
  delete the old mod folder, install 2.0.0 cleanly, and restore the presets into
  `Character Presets`; no legacy loader stub is included.
- Removes the unreliable automatic migration experiment. Upgrades from 1.0.x
  use only the documented manual backup, clean removal, and restore process.
- Gives the 2.0 panel a new saved-window identity so CET cannot reuse the old
  left-side position; its first appearance defaults near the right edge and
  later respects the position chosen by the user.
- Uses CET's `GetDisplayResolution()` and an explicit one-time startup position
  instead of relying only on ImGui's saved-window condition, ensuring the panel
  is placed at the right edge and logging the detected width and target X.
- Writes `Window Position Status.txt` after the right-side default is applied;
  later launches stop forcing a position and preserve CET's saved user-selected
  placement across restarts.

## 1.0.18

- Makes every preset and inventory update crash-safe by writing, flushing, and
  closing a temporary file before atomically replacing the destination, with a
  backup swap and recovery path where direct replacement is unavailable.
- Verifies temporary preset contents before installing them, covering new
  presets, overwrites, duplicates, renames, and moves through the same safe
  write path.
- Warns in the activity log when a preset contains malformed nonblank lines,
  including the affected file and line number, while preserving valid entries.
- Shows the live recyclable-folder-slot count in the Folders section and
  highlights it when only two slots remain.
- Keeps every Move Selected Preset result in the Folders status card instead
  of incorrectly displaying it beneath Manage.
- Reports folder slots as an available count without a fixed maximum, since
  recycling a manually created folder can legitimately expand the slot pool.
- Keeps the existing staged preset loader intact to avoid destabilizing CET's
  asynchronous option-rebuild handling; its larger state-machine refactor is
  deferred to a dedicated compatibility-tested release.

## 1.0.17

- Fixes deleted folders returning as empty slot directories that deployment or
  archive tools could discard; recycling now restores a non-empty marker first.
- Repairs any already-empty recyclable slots automatically at startup and logs
  every inspected or repaired slot.
- Standardizes every main action button to one full-width responsive height and
  routes editor, Load, Create, Folders, and Manage feedback through the same
  bordered status-card component.
- Detects presets and folders added, removed, moved, or modified outside CET
  during overlay rescans and records each path plus a warning summary.
- Persists a lightweight preset/folder inventory so external path changes made
  while the game is closed are warned about at the next startup.
- Gives folder results the same bordered status cards as Load, Create, and
  Manage: green SUCCESS cards, red WARNING cards, and red ERROR cards.
- Expands the activity log to cover every new preset/folder action, selection,
  confirmation stage, slot acquisition or recycle, copied/deleted file, nested
  folder operation, rollback, failure, and completion summary.
- Renders every destructive preset/folder confirmation and final warning in
  red, including red status borders for pending preset deletion.
- Rewrites the in-app Help panel so every folder, duplication, movement,
  confirmation, slot, import, and refresh behavior matches the current UI.
- Adds Duplicate Selected Preset, creating a verified uniquely named copy in
  the same folder.
- Adds Duplicate Selected Folder, recursively copying presets, nested folders,
  and other files under a unique sibling folder name.
- Rolls back incomplete folder copies if a file cannot be copied or CET runs
  out of recyclable folder slots.
- Replaces empty-folder-only deletion with a three-click permanent delete for
  the selected folder and everything inside it, including presets, nested
  folders, other files, and mod-manager bookkeeping files.
- Keeps empty-folder deletion at two clicks; only folders with real contents
  require the additional third confirmation.
- Shows the number of affected presets before the final destructive action.
- Fixes folder deletion confirmation being cleared every frame by CET reporting
  the already-selected folder row as selected again.
- Shows the pending folder-deletion instruction in amber while keeping the
  destructive delete and confirmation buttons red.
- Allows Vortex's harmless `__folder_managed_by_vortex` bookkeeping marker when
  determining whether a folder is empty enough to delete safely.

## 1.0.16

- Orders the main CET workflow as Load, Create, Folders, then Manage.
- Scans `character-presets` recursively so presets inside folders appear in CET.
- Adds folder creation, renaming, and protected deletion from the CET window.
- Adds controls to move a selected preset into any discovered folder or back to
  the root preset directory.
- Keeps preset renaming within its current folder and shows folder-qualified
  names in the preset list.
- Refuses to delete non-empty folders so preset files cannot be removed by a
  folder-management action.
- Uses 16 recyclable bundled folder slots so creation works within CET's
  filesystem sandbox without executing external commands.

## 1.0.15

- Adds an original CET-integrated **Open Full Appearance Editor** control.
- Adds an optional CET hotkey for opening the same editor without the overlay.
- Uses CET's gameplay-input binding for reliable editor launching and captures
  the in-game menu controller during both initialization and Blackboard setup.
- Gives the editor input a fresh registration ID and matches the proven menu
  event/redirect timing.
- Fixes the hotkey launcher resolving its customization-state helper as an
  undefined global because of Lua declaration order.
- Captures and logs any future exception thrown inside the input callback.
- Uses the proven immediate menu-scenario redirect used by the working editor
  launcher and makes no direct pause or unpause calls.
- Logs input presses, controller capture, pause-scenario interception, puppet
  readiness, editor construction failures, and request timeouts.
- Expands the activity log into a numbered, readable audit trail covering hook
  registration, file scans, UI activity, preset operations, option snapshots,
  every attempted character-option write, skipped options, and shutdown.
- Resolves customization localization keys to visible names such as hairstyle
  or hair color when the game or CCXL mod provides localization, while always
  retaining the raw LocKey and occurrence for troubleshooting.
- Places the Preset Manager window near the right edge by default on its first
  appearance while preserving positions chosen by the user afterward.
- Adds a Help section for opening the full editor, shows the current CET
  binding, and explains how to assign or change it.
- Clarifies that mirrors expose the full options and recommends resaving an
  outdated preset from the current editor after correcting it.
- Restyles Help with the same clear dark panels and white body text used by the
  rest of Preset Manager; amber is reserved for headings and borders.
- Replaces the blocked binding-file reader with accurate CET Bindings guidance
  and a live confirmation when the editor input fires during the session.
- Labels LocKeys without registered localization as custom/CCXL options while
  preserving their raw keys, and fixes singular option-count grammar.
- Simplifies load diagnostics to one header, one compact line per actual option
  change, and one final summary; repetitive pass and verification status remains
  visible in the UI without cluttering the activity log.
- Exposes the full character-creator option set during normal mirror sessions.
- Redirects only Preset Manager's pending menu request, leaving ordinary
  pause-menu behavior unchanged.
- Adds missing-save, duplicate-request, active-editor, timeout, and ACU safety
  checks with activity-log diagnostics.

## 1.0.14

- Removes the companion folder previously installed under
  `AppearanceChangeUnlocker` and the cross-mod preset bridge.
- Keeps ACU-format preset compatibility through direct file import: copy `.preset`
  files into Preset Manager's own `character-presets` folder.
- Imported ACU-format files now behave like normal editable presets.
- Improves status wording and shows ready and successful results in green.
- Color-codes the activity log: normal entries are white, completed loads are
  green, warnings are yellow, and errors are red.
- Rewrites and reorganizes Help with clearer steps, highlighted guidance, and a
  red ACU compatibility warning.
- Replaces numbered section labels with larger LOAD, CREATE, and MANAGE headings.
- Expands Help with complete loading, creation, management, import, file-path,
  troubleshooting, and diagnostic-log guidance.
- Highlights Load, Create, and Manage guidance in crisp white and turns the
  irreversible-delete notice into a clear red warning.
- Adopts the clearer typography and contrast from the supplied 1.0.14 build:
  native-size crisp text, white guidance, stronger panels, and brighter borders.
- Restores gray Name and New name input hints, removes unsupported warning
  glyphs, and makes activity-log level coloring case-insensitive.
- Gives Rename and Delete separate feedback cards directly beneath their own
  controls.
- Standardizes title capitalization and presents preset/log paths in dedicated
  amber callout boxes so important locations stand out from white body text.
- Stores the mod's own records in `Preset Manager (CET) Activity.log`, separate
  from CET's automatic log, and removes duplicate CET console output.
- Copies each completed Activity log to a timestamped `.txt` archive before
  starting a fresh log at the next full game launch.
- Keeps only the newest 10 dated Activity-log archives and deletes the oldest
  automatically when an 11th archive is created.
- Updates the log legend to show green completion, yellow warning, and red error
  states without labeling ordinary white entries.
- Colors each log-legend label to match the state it represents instead of
  rendering the entire legend in gray.
- Removes unsupported non-ASCII UI punctuation. Status cards retain the standard
  dark panel background, with green borders for success and red borders for
  failure. Normal log entries remain white, warnings yellow, and errors red.
- Matches neutral status panels to the standard preset-list panel styling.
- Improves status-card readability with READY, SUCCESS, ERROR, LOADING, and
  STATUS labels, white message text, and more room for wrapped messages.
- Removes repeated Ready wording and adds clearer log categories: LOAD for
  normal loading, COMPLETE for successful completion, and LOAD ERROR when a
  load fails or unresolved duplicate options stop progress. Only COMPLETE log
  entries are green.
- Matches the full Help panel to its file-path callouts with the same dark amber
  background, amber border, and gold text treatment.
- Automatically expands file-path callouts so the longer Activity-log path wraps
  without being clipped.
- Uses wrapped red text for critical Help notices, including unsupported screens,
  cosmetic cleanup, irreversible deletion, partial loads, ACU incompatibility,
  and the previous-session log location, preventing those lines from clipping.
- Renames Activity Log to Preset Manager Log and right-aligns its Refresh and
  Copy buttons to match the Debug and Help controls.

## 1.0.13

- Uses in-field Name and New name hints that disappear when typing.
- Makes Delete Preset full-width while retaining its red styling and two-step
  confirmation.
- Uses capped panel growth when the window is enlarged so Load, Create, and
  Manage remain visible together, while full-width action buttons grow slightly.
- Adds a compact Debug control with a refreshable, copyable in-menu view of
  `Preset Manager (CET).log`.
- Adds an ACU Info control when the incompatible ACU DLL is detected, opening
  the existing compatibility and recovery details.
- Keeps version and editor state on the left while anchoring Debug, Help, and
  optional ACU Info to the right of the same responsive top line.
- Anchors the top controls to the true content-right edge, matching the window
  margin used by the main controls.
- Adds extra text padding to the top controls so labels remain readable with
  larger CET font and interface scaling.

## 1.0.12

- Refreshes the window colors and layout for clearer visual hierarchy.
- Keeps a separate status panel under Load, Create, and Manage so feedback
  appears beside the action that produced it.
- Separates Rename from the smaller red Delete button and moves help to the
  top of the window.
- Shows a clear ACU incompatibility banner while leaving the affected controls
  visible but disabled.
- Uses distinct colors for preset selection, progress, stalls, success, and
  errors.
- Throttles editor-state checks used by the UI and automatic loader to avoid
  unnecessary native calls every rendered frame.
- Writes and verifies a temporary preset before replacing an existing save,
  with rollback protection if the replacement fails.
- Treats repeated unresolved results as the normal progress-aware stopping
  condition and keeps a larger fixed pass limit only as an emergency backstop.
- Restores the two-step Confirm Delete safeguard and keeps Rename and Delete
  visible at the default window height by using a shorter scrolling preset list.
- Uses simple Load, Create, and Manage section names and replaces the stylized
  deletion warning with direct wording.
- Keeps the ACU warning glyph while replacing question-mark button labels with
  the clearer Help and Show Fix labels.
- Clarifies the closed-editor prompt and labels the delete action Delete Preset.
- Reorganizes Help into concise sections for setup, saving, loading, managing,
  compatibility, recovery, sharing, and diagnostics.
- Preserves the filename validation, session-log rotation, customization-list
  refresh, and confirmation-state cleanup introduced previously.
## 1.0.11

- Rebuilds the visible Character Creator option list after a preset finishes
  loading, so selector and slider positions can be recreated from the applied
  values without requiring Next and Back.
- Registers the Character Creator observer only after CET initialization and
  treats observer failure as non-fatal, preventing the CET menu from vanishing.
- Replaces the dense ACU conflict warning with a clearer explanation and three
  numbered recovery steps, without changing ACU detection or blocking behavior.
- Verifies that a preset file was removed before deleting it from the UI.
- Requires a second **Confirm Delete** click before permanent deletion.
- Rejects Windows-reserved preset names and names ending in a period or space.
- Starts a fresh `Preset Manager (CET).log` every game session and keeps the
  immediately previous session as `Preset Manager (CET).previous.log`.

## 1.0.10

- Detects the native redscript bindings registered by ACU's `acu_rs.dll`.
- Disables Preset Manager for the entire game session when the incompatible ACU
  DLL is loaded, preventing both mods from changing the customization system.
- Shows a clear warning to disable or uninstall ACU and fully restart the game;
  there is no in-menu bypass because a loaded DLL cannot be unloaded safely.

## 1.0.9

- Prevents multiple unavailable ACU preset entries from claiming the same CCXL
  replacement selector and switching the hair color back and forth until the
  automatic-load safety limit.
- Applies an ordered replacement only when exactly one saved entry maps to that
  active selector; ambiguous entries remain unresolved instead of changing the
  appearance repeatedly.
- Documents the safer handling of ambiguous CCXL replacement selectors and the
  automatic staged-loading behavior.
- Expands the README with current creation and loading instructions, ACU import
  guidance, CC/CCXL compatibility notes, and the Photo Mode/AMM limitation.
- Clarifies that the full Appearance Change Unlocker mod is incompatible, while
  ACU-format preset files remain readable through the included companion bridge.

## 1.0.8

- Applies parent options such as hairstyle before their dependent color choices.
- Maps a saved CCXL color value to a replacement color option when the selected
  hair changes its localization key in one unambiguous ordered slot.
- Remembers successfully applied dependent options across staged rebuilds instead
  of incorrectly reporting them as unavailable after their parent hides them.
- Fixes CCXL hair presets stopping at 49 of 50 options after adding new hair
  mods.
- Identifies added, removed, or reordered CCXL mods as a possible cause when an
  older preset cannot fully load.
- Updates recovery guidance for presets that no longer match the current CCXL
  customization setup.

## 1.0.7

- Uses staged cleanup instead of resetting every dependent option in one frame;
  in-game logs showed that rapid bulk changes could stack hair and cosmetic
  meshes while Cyberpunk was still rebuilding the editor.
- Clears only active cosmetic occurrences absent from the target preset.
- Clears at most one leftover option per rebuild interval before refreshing the
  option list, preventing stale option objects and rapid dependent changes.
- Leaves target hair, face, eye, and other saved options untouched until the
  normal apply phase.
- Applies at most one changed target option per rebuild interval, then refreshes
  the list before continuing, so parent changes cannot invalidate later entries
  in the same loop.
- Raises the safety cap to 150 passes to accommodate fully staged cleanup and
  application.
- Refuses ambiguous positional matches when a repeated saved label has a
  different occurrence count in the active editor, preventing unsafe guesses
  across color, makeup, hair, and other duplicated labels.
- Aligns load-time occurrence counting with save-time behavior by counting only
  active, editable options.
- Preserves ordered CCXL/heterochromia entries when their saved and exposed
  occurrence counts match; otherwise skips the group safely.
- Reports hidden, locked, unavailable, and ambiguous options as unresolved.

## 1.0.6

- Makes preset loading one click by continuing dependent-option passes
  automatically at a conservative interval.
- Requires three identical unresolved results before declaring a load stalled,
  reducing false stalls while a busy customization editor is still rebuilding.
- Detects partial ACU preset loads and recommends using the loaded appearance as
  a base for a new, safer Preset Manager preset.
- Detects a stalled load when the exact same inactive, failed, or unavailable
  option keys remain unresolved on consecutive passes.
- Stops the endless **Continue Loading Preset** loop when another pass cannot
  make progress.
- Recommends recreating incompatible presets at a Ripperdoc or in the full
  Character Creator.
- Preserves the options that were successfully applied and keeps the unresolved
  entries distinct from a fully applied preset.
- Adds a small CET bridge inside the `AppearanceChangeUnlocker` data folder.
  The bridge reads only ACU's `female` and `male` preset folders from inside
  its own sandbox and shares parsed data through CET's inter-mod API.
- Shows bridged presets as `ACU/female/...` and `ACU/male/...` and keeps them
  read-only inside Preset Manager.
- Keeps Preset Manager limited to saving and loading the options exposed by the
  active vanilla editor.

## 1.0.5

- Darkens button and preset-list hover/active colors so white text remains
  easier to read when highlighted.
- Keeps all preset saving, loading, matching, and continuation behavior unchanged.

## 1.0.3

- Renames the mod, installed folder, and archive to **Preset Manager (CET)**.
- Fixes the load button not changing to **Continue Loading Preset** after an
  incomplete pass by tracking continuation state explicitly.
- Fixes the selected preset row resetting continuation state on every frame in
  CET, which made the button revert to **Load Selected Preset** immediately.
- Changes load state only when a different preset is actually selected.
- Clears active cyberware, tattoos, and scars when those optional choices are
  absent from the loaded preset, without counting inactive alternatives.
- Keeps the original preset matching and inactive-option retry behavior.

## 1.0.2

- Internal development build; not released.

## 1.0.1

- Ensures mod managers create the `character-presets` folder during installation.
- Fixes new presets failing to save on fresh installs where empty folders were omitted.

## 1.0.0

- Initial public release.
- Creates and loads standalone character preset files.
- Supports vanilla and repeated CCXL customization entries.
- Guides users through the required multi-pass loading process.
- Includes clear remaining-option counts and completion status.
- Stores shareable presets in the mod's `character-presets` folder.
- Uses Cyber Engine Tweaks directly with no additional runtime dependency.
- Writes detailed diagnostics to the mod log.
