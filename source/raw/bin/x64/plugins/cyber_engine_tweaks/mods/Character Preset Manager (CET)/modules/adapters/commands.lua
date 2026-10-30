local commandModel = require("modules/application/commands")
local libraryView = require("modules/domain/library_view")
local stateModel = require("modules/domain/state")
local codecs = require("modules/domain/codecs")

local function new(runtime)
  if setfenv then setfenv(1, runtime) end
  local _ENV = runtime
  local function cleanField(value) return codecs.cleanField(value) end
  local function nativeStatus(message, isError)
state.app.nativePanelStatus = tostring(message or "")

  state.app.nativePanelStatusError = isError == true

  return isError and "error" or "status", cleanField(message)
  end
  local function startSelectedLoad()
if not state.library.selected then return false, "Select a preset first." end

  if not state.app.inCustomization then return false, "Open a customization screen first." end

  state.app.nativeLoadSummary = nil

  state.app.nativePanelShowDetails = false

  resetLoadState()

  stateModel.prepareAutomaticLoad(state.load)

  loadPreset()

  if state.load.needsContinue then state.load.auto = true end

  return true, state.status.sections.load.message
  end
  local function canRandomize()
if not state.app.inCustomization or not state.editor.activeBodyMorphMenu

      or state.load.auto or state.load.needsContinue or state.load.pendingChange then return false end

  local ok, available = pcall(function() return state.editor.activeBodyMorphMenu:CPMCanRandomize() end)

  return ok and available == true
  end
  local function randomize(settings)
if not canRandomize() then

    return nativeStatus("Open a character editor and wait for the current action to finish before using Randomize.", true)

  end

  if settings and state.app.overlayOpen then

    state.editor.pendingRandomizeSettings = state.editor.activeBodyMorphMenu

    return nativeStatus("Close CET to open the game's Randomize Settings.", false)

  end

  local ok, changed = pcall(function()

    if settings then return state.editor.activeBodyMorphMenu:CPMRandomizeSettings() end

    return state.editor.activeBodyMorphMenu:CPMRandomize()

  end)

  if not ok or not changed then

    return nativeStatus("The game's randomizer is not ready. Wait for the editor and try again.", true)

  end

  state.app.optionsMemo = nil

  state.invalidatePreflight()

  return nativeStatus(settings and "Randomize Settings opened or closed." or "The game is randomizing your appearance.", false)
  end
  local function setSort(value)
local sort = libraryView.normalizeSort(value)

  state.preferences.presetSort = sort

  state.library.sortMode = sort

  invalidateViewCache()

  writeConfig()

  state.status.settings = sort == "modified"

    and "Presets are sorted by the date they were last changed."

    or "Presets are sorted by name."
  end
  local cet = {}
  cet.sort_name = function(input, ports, decision)
setSort("name")
  end
  cet.sort_modified = function(input, ports, decision)
setSort("modified")
  end
  cet.bulk_filter = function(input, ports, decision)
invalidateFilteredViewCache()

      state.ui.listPages.bulkPresets = 1
  end
  cet.bulk_select_visible = function(input, ports, decision)
    local visibleNames = input.visibleNames
for _, name in ipairs(visibleNames) do state.trash.bulkSelected[name] = true end

      invalidateBulkSelectionCache()

      cancelConfirmations()

      clearStatus("bulk")
  end
  cet.bulk_clear = function(input, ports, decision)
state.trash.bulkSelected = {}

      invalidateBulkSelectionCache()

      cancelConfirmations()

      clearStatus("bulk")
  end
  cet.bulk_select = function(input, ports, decision)
    local name = input.name
    local selectedForBulk = input.selectedForBulk
if selectedForBulk then

            state.trash.bulkSelected[name] = nil

          else

            state.trash.bulkSelected[name] = true

          end

          invalidateBulkSelectionCache()

          cancelConfirmations()

          clearStatus("bulk")
  end
  cet.bulk_location_root = function(input, ports, decision)
state.trash.bulkTargetFolder = ""

        clearStatus("bulk")
  end
  cet.bulk_location = function(input, ports, decision)
    local folder = input.folder
state.trash.bulkTargetFolder = folder

          clearStatus("bulk")
  end
  cet.bulk_move = function(input, ports, decision)
moveSelectedBulkPresetsToFolder()
  end
  cet.bulk_export = function(input, ports, decision)
exportSelectedBulkPresetBundle()
  end
  cet.bulk_trash = function(input, ports, decision)
    local selectedBulkNames = input.selectedBulkNames
requestBulkTrash(selectedBulkNames)
  end
  cet.randomize = function(input, ports, decision)
local kind, message = randomize(false)

      setStatus("editor", message, kind == "error")
  end
  cet.randomize_settings = function(input, ports, decision)
local kind, message = randomize(true)

      setStatus("editor", message, kind == "error")
  end
  cet.open_editor = function(input, ports, decision)
openFullAppearanceEditor()
  end
  cet.folder_root = function(input, ports, decision)
log(("[UI] Folder selection changed: old='%s' new='<root>'.")

        :format(state.library.selectedFolder), "info")

      state.library.selectedFolder = ""

      cancelConfirmations()
  end
  cet.folder_select = function(input, ports, decision)
    local folder = input.folder
log(("[UI] Folder selection changed: old='%s' new='%s'.")

          :format(tostring(state.library.selectedFolder), folder), "info")

        state.library.selectedFolder = folder

        cancelConfirmations()

        state.library.folderRenameName = ""
  end
  cet.folder_create = function(input, ports, decision)
createFolder()
  end
  cet.folder_rename = function(input, ports, decision)
renameFolder()
  end
  cet.folder_duplicate = function(input, ports, decision)
duplicateFolder()
  end
  cet.move = function(input, ports, decision)
movePresetToSelectedFolder()
  end
  cet.folder_remove = function(input, ports, decision)
removeVirtualFolder()
  end
  cet.folder_trash = function(input, ports, decision)
    local folderBulkNames = input.folderBulkNames
requestBulkTrash(folderBulkNames, state.library.selectedFolder)
  end
  cet.move_root = function(input, ports, decision)
movePresetToSelectedFolder()
  end
  cet.bundle_export = function(input, ports, decision)
exportSelectedFolderBundle()
  end
  cet.bundle_import = function(input, ports, decision)
importAvailableFolderBundles()
  end
  cet.bundle_select = function(input, ports, decision)
    local leaf = input.leaf
if state.library.selectedBundleFile ~= leaf then clearFolderBundlePreview() end

            state.library.selectedBundleFile = leaf

            cancelConfirmations()
  end
  cet.bundle_preview = function(input, ports, decision)
    local previewVisible = input.previewVisible
if previewVisible then

            clearFolderBundlePreview()

            clearStatus("folder")

          else viewSelectedFolderBundleContents() end
  end
  cet.bundle_trash = function(input, ports, decision)
trashSelectedFolderBundle()
  end
  cet.filter = function(input, ports, decision)
invalidateFilteredViewCache()

      state.ui.listPages.loadPresets = 1
  end
  cet.clear_filter = function(input, ports, decision)
state.library.searchText = ""

      invalidateFilteredViewCache()

      state.ui.listPages.loadPresets = 1
  end
  cet.refresh = function(input, ports, decision)
requestAcuImport("CET Refresh")

      local _, refreshed, changes = refreshPresets("external")

      refreshTrash()

      if state.library.selected and state.library.presets[state.library.selected] then

        state.library.presetNotes = state.library.presets[state.library.selected].notes or ""

        state.library.presetTags = state.library.presets[state.library.selected].tags or ""

      end

      local added = changes and changes.added or 0

      local removed = changes and changes.removed or 0

      local updated = changes and changes.modified or 0

      setStatus("load", refreshed

        and ("Refreshed: %d added, %d updated, %d removed; %d available. Checking ACU presets in the background.")

          :format(added, updated, removed, #helpers.sortedPresetNames())

        or "Refresh failed; the previous list was kept.", not refreshed)
  end
  cet.refresh_options = function(input, ports, decision)
helpers.refreshOptionCatalog()
  end
  cet.select = function(input, ports, decision)
    local name = input.name
log(("[UI] Preset selection changed: old='%s' new='%s'.")

            :format(tostring(state.library.selected), name), "info")

          state.library.selected = name

          addFolderAncestors(state.library.expandedLoadFolders, parentFolder(name))

          state.invalidatePreflight()

          local selectedPreset = hydrateNamedPresetMetadata(name)

            or state.library.presets[name]

          state.library.presetNotes = selectedPreset and selectedPreset.notes or ""

          state.library.presetTags = selectedPreset and selectedPreset.tags or ""

          invalidateFilteredViewCache()

          cancelConfirmations()

          state.library.renameName = ""

          resetLoadState()

          clearStatus("load")

          clearStatus("rename")

          clearStatus("delete")
  end
  cet.load = function(input, ports, decision)
if not state.load.needsContinue then

        resetLoadState()

      end

      state.load.autoTimer = 0

      state.load.autoPasses = 0

      state.load.resetBefore = true

      loadPreset()

      if state.load.needsContinue then state.load.auto = true end
  end
  cet.restore_previous = function(input, ports, decision)
restoreLastAppearance()
  end
  cet.restore_history = function(input, ports, decision)
    local visibleIndex = input.visibleIndex
restoreAppearanceHistory(visibleIndex)
  end
  cet.clear_history = function(input, ports, decision)
local cleared, message = clearAppearanceHistory(decision.confirm)

          setStatus("load", message, not cleared and not state.history.pendingClear)
  end
  cet.compare = function(input, ports, decision)
clearStatus("load")

          state.invalidatePreflight()

          log(("[UI] Compatibility check requested for '%s'.")

            :format(state.library.selected), "info")

          refreshPreflight()
  end
  cet.force_full = function(input, ports, decision)
state.load.forceFull = not state.load.forceFull

          resetLoadState()

          state.invalidatePreflight()

          clearStatus("load")

          log(("[UI] Force Full Load toggled %s.")

            :format(state.load.forceFull and "on" or "off"), "info")
  end
  cet.favorite = function(input, ports, decision)
toggleSelectedPresetFavorite()
  end
  cet.rename = function(input, ports, decision)
renamePreset()
  end
  cet.duplicate = function(input, ports, decision)
duplicatePreset()
  end
  cet.copy_path = function(input, ports, decision)
    local selectedPresetPath = input.selectedPresetPath
ImGui.SetClipboardText(selectedPresetPath)
  end
  cet.metadata = function(input, ports, decision)
savePresetMetadata()
  end
  cet.name_changed = function(input, ports, decision)
state.library.pendingOverwriteName = nil

      state.library.pendingOverwriteFingerprint = nil

      clearStatus("create")
  end
  cet.save = function(input, ports, decision)
    local pendingCreateName = input.pendingCreateName
savePreset(decision.overwrite)
  end
  cet.save_location_root = function(input, ports, decision)
state.library.selectedFolder = ""

        cancelConfirmations()

        clearStatus("create")

        log("[UI] Save destination changed to '<root>'.", "info")
  end
  cet.save_location = function(input, ports, decision)
    local folder = input.folder
state.library.selectedFolder = folder

          cancelConfirmations()

          clearStatus("create")

          log(("[UI] Save destination changed to '%s'."):format(folder), "info")
  end
  cet.delete = function(input, ports, decision)
trashPreset()
  end
  cet.trash_restore_group = function(input, ports, decision)
    local groupId = input.groupId
restoreTrashGroup(groupId)
  end
  cet.trash_restore = function(input, ports, decision)
    local filename = input.filename
restoreTrashPreset(filename)
  end
  cet.trash_restore_bundle = function(input, ports, decision)
    local filename = input.filename
restoreTrashBundle(filename)
  end
  cet.trash_empty = function(input, ports, decision)
emptyTrash()
  end
  cet.sort = function(input) setSort(input.value) end
  local native = {}
  native.randomize = function(input, ports, decision)
    local payload = input.payload
return randomize(false)
  end
  native.randomize_settings = function(input, ports, decision)
    local payload = input.payload
return randomize(true)
  end
  native.open = function(input, ports, decision)
    local payload = input.payload
ports.setQuery("")

    return "list", ports.listPayload(ports.query(), NATIVE_READY_STATUS, false)
  end
  native.list = function(input, ports, decision)
    local payload = input.payload
ports.setQuery(tostring(payload or ""))

    return "list", ports.listPayload(ports.query())
  end
  native.select = function(input, ports, decision)
    local payload = input.payload
if state.library.presets[payload] then

      state.library.selected = payload

      hydrateNamedPresetMetadata(payload)

      state.invalidatePreflight()

      cancelConfirmations()

      resetLoadState()

    end

    return "list", ports.listPayload(ports.query())
  end
  native.select_load = function(input, ports, decision, loadAction)
    local payload = input.payload
if not state.library.presets[payload] then

      return nativeStatus("That preset is no longer available.", true)

    end

    state.library.selected = payload

    state.invalidatePreflight()

    cancelConfirmations()

    resetLoadState()

    local started, message = (loadAction or startSelectedLoad)()

    return nativeStatus(message, not started)
  end
  native.toggle_folder = function(input, ports, decision)
    local payload = input.payload
if folderNameExists(payload) then

      state.library.expandedLoadFolders[payload] =

        state.library.expandedLoadFolders[payload] ~= true

      ports.invalidateRows()

      return "list", ports.listPayload(ports.query())

    end

    return "list", ports.listPayload(ports.query(),

      "That folder is no longer available. Open the CET manager to refresh its folder list.", true)
  end
  native.cancel_save_confirmation = function(input, ports, decision)
    local payload = input.payload
state.library.pendingOverwriteName = nil

    state.library.pendingOverwriteFingerprint = nil

    return "confirm_state", "SAVE\t0"
  end
  native.save = function(input, ports, decision)
    local payload = input.payload
state.library.newName = payload

    savePreset(decision.overwrite)

    local status = state.status.sections.create

    return "list", ports.listPayload(ports.query(), status.message, status.error)
  end
  native.replace = function(input, ports, decision)
    local payload = input.payload
if not state.library.selected then return "status", "Select a preset first." end

    state.library.newName = baseName(state.library.selected)

    state.library.selectedFolder = parentFolder(state.library.selected)

    savePreset(false)

    savePreset(true)

    return "list", ports.listPayload("")
  end
  native.load = function(input, ports, decision, loadAction)
    local payload = input.payload
local started, message = (loadAction or startSelectedLoad)()

    return nativeStatus(message, not started)
  end
  native.compare = function(input, ports, decision)
    local payload = input.payload
return "comparison", ports.comparisonPayload()
  end
  native.favorite = function(input, ports, decision)
    local payload = input.payload
toggleSelectedPresetFavorite()

    return "list", ports.listPayload("")
  end
  native.save_location = function(input, ports, decision)
    local payload = input.payload
if payload == "" or folderNameExists(payload) then

      state.library.selectedFolder = payload

      cancelConfirmations()

      return "list", ports.listPayload(ports.query())

    end

    return nativeStatus("That save location is no longer available. Open CET to refresh folders.", true)
  end
  native.delete = function(input, ports, decision)
    local payload = input.payload
if not state.library.selected then return nativeStatus("Select a preset first.", true) end

    trashPreset("native")

    local status = state.status.sections.delete

    local message = tostring(status.message or "")

    if status.error ~= true then

      message = message .. (state.trash.nativePendingDeleteName ~= nil

        and " After moving it, open CET to restore it or delete it permanently."

        or " Open CET to restore it or delete it permanently.")

    end

    return "list", ports.listPayload(ports.query(), message, status.error)
  end
  native.refresh = function(input, ports, decision)
    local payload = input.payload
requestAcuImport("native Refresh")

    refreshPresets("external")

    refreshTrash()

    return "list", ports.listPayload(ports.query())
  end
  native.history = function(input, ports, decision)
    local payload = input.payload
return "history", ports.historyPayload()
  end
  native.restore_history = function(input, ports, decision)
    local payload = input.payload
state.app.nativeLoadSummary = nil

    state.app.nativePanelShowDetails = false

    restoreAppearanceHistory(tonumber(payload))

    return nativeStatus(state.status.sections.load.message,

      state.status.sections.load.error == true)
  end
  native.restore_previous = function(input, ports, decision)
    local payload = input.payload
state.app.nativeLoadSummary = nil

    state.app.nativePanelShowDetails = false

    restoreLastAppearance()

    return nativeStatus(state.status.sections.load.message,

      state.status.sections.load.error == true)
  end
  native.clear_history = function(input, ports, decision)
    local payload = input.payload
local cleared, message = clearAppearanceHistory(decision.confirm)

    return cleared and "history" or "confirm_clear", cleared and ports.historyPayload() or message
  end
  native.open_advanced = function(input, ports, decision)
    local payload = input.payload
return ports.openAdvanced()
  end
  native.open_load_details = function(input, ports, decision)
    local payload = input.payload
state.app.windowOpen = true

    state.ui.openSections.load = true

    return "status", "Press your CET binding. Load details are open in Character Preset Manager."
  end
  native.unsupported = function()
    return nativeStatus("The simple menu requested an action this version does not support.", true)
  end
  local function context(name, input)
    local selected = state.library.selected
    local data = {
      selected = selected,
      presetExists = selected ~= nil and state.library.presets[selected] ~= nil,
      inCustomization = state.app.inCustomization,
      auto = state.load.auto,
      needsContinue = state.load.needsContinue,
      pendingChange = not not state.load.pendingChange,
      recoveryAvailable = state.load.recoverySnapshotAvailable == true,
      hasEditor = not not state.editor.activeBodyMorphMenu,
      openPending = state.editor.openPending,
      hooksAvailable = state.editor.hooksAvailable,
      available = input.available,
      rootFolder = state.library.selectedFolder == "",
      bundleSelected = state.library.selectedBundleFile ~= nil,
      pendingOverwriteName = state.library.pendingOverwriteName,
      pendingClear = state.history.pendingClear,
    }
    if name == "save" then data.validPresetName = validatedPresetName(state.library.newName) ~= nil end
    if name == "folder_create" then data.validFolderName = validatedFolderName(state.library.folderName) ~= nil end
    if name == "rename" then data.renameEmpty = sanitizeName(state.library.renameName) == "" end
    if name == "folder_rename" then data.folderRenameEmpty = sanitizeName(state.library.folderRenameName) == "" end
    if name == "move" or name == "move_root" then
      data.sameFolder = selected ~= nil and parentFolder(selected) == state.library.selectedFolder
    end
    if input.folderBulkNames then data.emptyFolder = #input.folderBulkNames == 0 end
    if input.selectedBulkNames then data.emptyBulk = #input.selectedBulkNames == 0 end
    return data
  end
  local function run(origin, name, input, ports, loadAction)
    input = input or {}
    local decision = commandModel.plan(origin, name, input, context(name, input))
    if decision.failure then return decision end
    local kind, payload, extra
    for _, action in ipairs(decision.actions) do
      local handlers = action.origin == "cet" and cet or native
      local handler = handlers[action.name]
      if handler then kind, payload, extra = handler(input, ports, decision, loadAction) end
    end
    local message, isError, warnings = "", false, nil
    if origin == "native" then
      message = kind == "list" and state.app.nativePanelStatus
        or (kind == "status" or kind == "error" or kind == "confirm_clear") and payload or ""
      isError = kind == "error" or kind == "list" and state.app.nativePanelStatusError == true
    elseif decision.section == "settings" then
      message = state.status.settings
    elseif decision.section then
      local status = state.status.sections[decision.section]
      message, isError = status and status.message, status and status.error == true
      local statusKind = state.status.kinds[decision.section]
      if statusKind == "warning" or statusKind == "critical_warning" then warnings = {message} end
    end
    local result = commandModel.complete(decision, isError, message, warnings)
    result.responseKind, result.responsePayload, result.responseExtra = kind, payload, extra
    return result
  end
  return {run = run, canRandomize = canRandomize, startSelectedLoad = startSelectedLoad,
    nativeStatus = nativeStatus, context = context}
end
return {new = new}
