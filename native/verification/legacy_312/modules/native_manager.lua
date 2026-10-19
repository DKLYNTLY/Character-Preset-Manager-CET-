local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

nativeManager = {writing = false, refreshing = false, timer = 0, loadGeneration = 0, reads = {}}

function selectPreset(name)
  local preset = state.library.presets[name]
  if not preset then return end
  state.library.selected = name
  state.library.renameName = ""
  state.library.presetNotes = preset.notes or ""
  state.library.presetTags = preset.tags or ""
  addFolderAncestors(state.library.expandedLoadFolders, parentFolder(name))
  state.invalidatePreflight()
end

function folderNameExists(name) return state.library.folders[name] == true end

local function message(section, text, failed)
  setStatus(section, text, failed == true, failed and "error" or "success")
  state.app.nativePanelStatus = text
  state.app.nativePanelStatusError = failed == true
end

local function submit(action, payload, section, callback)
  local operation, errorText = nativeService.submit(action, payload, function(status, result, id)
    if status ~= "complete" then
      message(section, result and (result.error or result.message) or "The preset action could not finish.", true)
      if callback then callback(nil, status) end
      return
    end
    if callback then callback(result, status, id) end
  end)
  if not operation then message(section, errorText or nativeService.reason, true) end
  return operation
end

function nativeManager.view(callback)
  nativeLibrary.requestView(state.library.searchText, state.library.sortMode, function(ok, errorText)
    if not ok then message("load", errorText, true) end
    if callback then callback(ok) end
  end)
end

function nativeManager.mutate(action, payload, section, callback)
  if nativeManager.writing or nativeManager.refreshing or nativeLibrary.busy then
    message(section, "Wait for the current library action to finish.", true)
    return false
  end
  nativeManager.writing = true
  payload.revision = nativeLibrary.revision
  local operation = submit(action, payload, section, function(result)
    if not result then nativeManager.writing = false; nativeManager.importingBundles = false; return end
    nativeLibrary.revision = result.revision or nativeLibrary.revision
    nativeManager.view(function(ok)
      nativeManager.writing = false
      if ok then
        cancelConfirmations()
        if callback then callback(result) end
        message(section, result.message or "Library updated.", false)
        writeInventory()
      else
        nativeManager.importingBundles = false
      end
    end)
  end)
  if not operation then nativeManager.writing = false end
  return operation ~= nil
end

refreshPresets = function(reason)
  if nativeManager.refreshing or nativeManager.writing then return false end
  nativeManager.refreshing = true
  local operation = submit("synchronize", {}, "load", function(result)
    if not result then nativeManager.refreshing = false; return end
    nativeLibrary.revision = result.revision
    for _, warning in ipairs(result.warnings or {}) do log("[LIBRARY] " .. warning, "warn") end
    nativeManager.view(function(ok)
      nativeManager.refreshing = false
      if ok then
        message("load", "Preset library refreshed.", false)
        nativeManager.refreshArchives()
        refreshTrash()
        refreshAppearanceHistory()
        writeInventory()
      end
    end)
  end)
  if not operation then nativeManager.refreshing = false end
  return operation ~= nil
end

function nativeManager.read(name, callback)
  local cached = state.library.presets[name]
  if not cached then callback(nil); return end
  local callbacks = nativeManager.reads[name]
  if callbacks then callbacks[#callbacks + 1] = callback; return end
  callbacks = {callback}
  nativeManager.reads[name] = callbacks
  local function finish(preset)
    nativeManager.reads[name] = nil
    for _, waiting in ipairs(callbacks) do waiting(preset) end
  end
  local operation = submit("read", {name = name, fingerprint = cached.fingerprint}, "load", function(result)
    local current = state.library.presets[name]
    if not result or not current or current.fingerprint ~= cached.fingerprint
        or result.fingerprint ~= cached.fingerprint then finish(nil); return end
    local preset = result.preset
    preset.storage = current.storage
    preset.fingerprint = result.fingerprint
    state.library.presets[name] = preset
    finish(preset)
  end)
  if not operation then finish(nil) end
end

hydrateNamedPreset = function(name)
  return name and state.library.presets[name] or nil
end
hydrateNamedPresetMetadata = hydrateNamedPreset

function nativeManager.snapshot(options, description)
  local entries = {}
  for _, option in ipairs(options or {}) do
    local key = optionKey(option)
    if key and option.isEditable and option.isActive then
      local current = tonumber(option.currIndex)
      if not optionIndexIsValid(current) or #entries >= MAX_PRESET_ENTRIES then return nil end
      entries[#entries + 1] = {key = key, index = current, slot = optionSlot(option),
        choice = helpers.optionChoiceKey(option, current), label = helpers.optionDisplayName(option, key)}
    end
  end
  if #entries == 0 then return nil end
  return {format = CURRENT_PRESET_FORMAT, source = MOD_NAME, entries = entries,
    notes = description or "", tags = "", favorite = false, managedByCpm = true}
end

savePreset = function(confirm)
  if not state.app.inCustomization then
    message("create", "Open an appearance editor to save or load presets.", true); return false
  end
  local leaf, errorText = validatedPresetName(state.library.newName)
  if not leaf then message("create", errorText, true); return false end
  local name = joinFolder(state.library.selectedFolder, leaf)
  local previous = state.library.presets[name]
  local collision = findPresetCollision(name)
  if collision and collision ~= name then message("create", "A preset with that name already exists.", true); return false end
  if previous and (not confirm or state.library.pendingOverwriteName ~= name
      or state.library.pendingOverwriteFingerprint ~= previous.fingerprint) then
    state.library.pendingOverwriteName = name
    state.library.pendingOverwriteFingerprint = previous.fingerprint
    message("create", "This preset already exists. Select Confirm Overwrite to replace it.", true)
    return false
  end
  local _, options = getOptions(true)
  local preset = options and nativeManager.snapshot(options)
  if not preset then message("create", "The current appearance could not be read safely.", true); return false end
  preset.notes = state.library.presetNotes or ""
  preset.tags = state.library.presetTags or ""
  preset.favorite = previous and previous.favorite == true or false
  if previous then preset.created = previous.created end
  return nativeManager.mutate("save", {name = name, preset = preset, replace = previous ~= nil},
    "create", function() selectPreset(name) end)
end

renamePreset = function()
  local name = state.library.selected
  local leaf, errorText = validatedPresetName(state.library.renameName)
  if not name or not leaf then message("rename", errorText or "Select a preset first.", true); return false end
  return nativeManager.mutate("rename", {name = name, destination = joinFolder(parentFolder(name), leaf)},
    "rename", function(result) selectPreset(result.selected) end)
end
duplicatePreset = function()
  if not state.library.selected then message("rename", "Select a preset first.", true); return false end
  return nativeManager.mutate("duplicate", {name = state.library.selected}, "rename",
    function(result) selectPreset(result.selected) end)
end
savePresetMetadata = function()
  if not state.library.selected then message("rename", "Select a preset first.", true); return false end
  return nativeManager.mutate("metadata", {name = state.library.selected,
    notes = state.library.presetNotes, tags = state.library.presetTags}, "rename")
end
toggleSelectedPresetFavorite = function()
  if not state.library.selected then return false end
  return nativeManager.mutate("favorite", {name = state.library.selected}, "rename")
end
movePresetToSelectedFolder = function()
  local name = state.library.selected
  if not name then message("folder", "Select a preset first.", true); return false end
  return nativeManager.mutate("move", {name = name,
    destination = joinFolder(state.library.selectedFolder, baseName(name))}, "folder",
    function(result) selectPreset(result.selected) end)
end
moveSelectedBulkPresetsToFolder = function()
  return nativeManager.mutate("move_many", {name = state.trash.bulkTargetFolder,
    names = selectedBulkPresetNames()}, "bulk")
end
createFolder = function()
  local leaf, errorText = validatedFolderName(state.library.folderName)
  if not leaf then message("folder", errorText, true); return false end
  local name = joinFolder(state.library.selectedFolder, leaf)
  return nativeManager.mutate("create_folder", {name = name}, "folder",
    function() state.library.selectedFolder = name end)
end
renameFolder = function()
  local leaf, errorText = validatedFolderName(state.library.folderRenameName)
  if not leaf then message("folder", errorText, true); return false end
  local name = state.library.selectedFolder
  return nativeManager.mutate("rename_folder", {name = name,
    destination = joinFolder(parentFolder(name), leaf)}, "folder",
    function(result) state.library.selectedFolder = result.selected end)
end
duplicateFolder = function()
  return nativeManager.mutate("duplicate_folder", {name = state.library.selectedFolder}, "folder",
    function(result) state.library.selectedFolder = result.selected end)
end
removeVirtualFolder = function()
  local name = state.library.selectedFolder
  if state.library.pendingRemoveFolder ~= name then
    state.library.pendingRemoveFolder = name
    message("folder", "Select Remove Folder again to confirm. Its presets and nested folders will move up one folder.", true)
    return false
  end
  return nativeManager.mutate("remove_folder", {name = name}, "folder",
    function(result) state.library.selectedFolder = result.selected end)
end

readConfig = function() return {presetSort = "name"}, false end
writeConfig = function()
  local preferences = {presetSort = state.preferences.presetSort}
  return submit("config_save", {preferences = preferences, fingerprint = nativeManager.configFingerprint},
    "load", function(result)
      if result then nativeManager.configFingerprint = result.fingerprint end
    end) ~= nil
end
writeInventory = function()
  return submit("inventory", {revision = nativeLibrary.revision}, "load") ~= nil
end
initializeAcuImport = function() end
requestAcuImport = function() return refreshPresets("external") end
updateAcuImport = function() end
recoverTransaction = function() return true, {}, {}, {}, {} end
continueLoadPass = helpers.continueNativeLoad

local resetGameLoad = resetLoadState
resetLoadState = function()
  nativeManager.loadGeneration = nativeManager.loadGeneration + 1
  nativeManager.preparingLoad = false
  nativeManager.loadedPreset = nil
  nativeAppearance.cancel()
  resetGameLoad()
end

local function applyHistory(result)
  if not result then return end
  state.history.entries = result.entries or {}
  state.history.fingerprint = result.fingerprint
  state.load.recoverySnapshotAvailable = result.recoveryAvailable == true
  for _, entry in ipairs(state.history.entries) do
    local preset = entry.preset
    entry.date = preset.modified or preset.created or "Date unavailable"
    entry.action = preset.notes or "Automatic recovery snapshot"
    entry.count = preset.entryCount or #(preset.entries or {})
  end
end

refreshAppearanceHistory = function()
  if nativeManager.historyPending then return state.history.entries end
  nativeManager.historyPending = true
  local operation = submit("history", {}, "load", function(result)
    nativeManager.historyPending = false
    applyHistory(result)
  end)
  if not operation then nativeManager.historyPending = false end
  return state.history.entries
end

saveAppearanceHistorySnapshot = function(options, description, callback)
  local preset = nativeManager.snapshot(options, description)
  if not preset then if callback then callback(false) end; return false end
  local operation = submit("history_save", {preset = preset, description = description}, "load", function(result)
    applyHistory(result)
    if callback then callback(result ~= nil) end
  end)
  if not operation and callback then callback(false) end
  return operation ~= nil
end
trimAppearanceHistory = refreshAppearanceHistory

local function beginAppearance(preset, name, generation)
  if generation ~= nativeManager.loadGeneration then return end
  local system, options = getOptions(true)
  if not state.app.inCustomization or not system or not options then
    nativeManager.preparingLoad = false
    state.load.needsContinue = false
    state.load.auto = false
    message("load", "Open an appearance editor to save or load presets.", true)
    return
  end
  saveAppearanceHistorySnapshot(options, "Before loading " .. name, function(saved)
    if generation ~= nativeManager.loadGeneration then return end
    nativeManager.preparingLoad = false
    if not saved then
      state.load.needsContinue = false
      state.load.auto = false
      message("load", "The recovery snapshot could not be saved. Loading stopped before changing the appearance.", true)
      return
    end
    local currentSystem, current = getOptions(true)
    if not current or not state.app.inCustomization then
      state.load.needsContinue = false
      state.load.auto = false
      return
    end
    nativeManager.loadedPreset = preset
    local values, counts, entries, slots, total, byKey = beginLoadPass(preset, name)
    state.load.auto = true
    state.load.needsContinue = true
    helpers.continueNativeLoad(currentSystem, current, preset, values, counts, entries, slots, total, byKey)
  end)
end

loadPreset = function()
  if nativeManager.preparingLoad or nativeAppearance.pending then return end
  if not nativeService.available then message("load", nativeService.reason, true); return end
  if state.load.values and nativeManager.loadedPreset then
    local system, options = getOptions()
    if not options then cancelLoading(); return end
    state.load.pass = state.load.pass + 1
    helpers.continueNativeLoad(system, options, nativeManager.loadedPreset, state.load.values,
      state.load.savedCounts, state.load.orderedEntries, state.load.savedSlotCounts,
      state.load.valueCount, state.load.savedEntryByKey)
    return
  end
  if not state.app.inCustomization then message("load", "Open an appearance editor to save or load presets.", true); return end
  local name = state.load.overrideName or state.library.selected
  if not name then message("load", "Select a preset first.", true); return end
  helpers.syncForceFullLoadSelection()
  local generation = nativeManager.loadGeneration
  nativeManager.preparingLoad = true
  state.load.needsContinue = true
  state.load.auto = true
  message("load", "Reading the preset and saving an appearance recovery snapshot.", false)
  if state.load.overridePreset then
    beginAppearance(state.load.overridePreset, name, generation)
  else
    nativeManager.read(name, function(preset)
      if generation ~= nativeManager.loadGeneration then return end
      if preset then beginAppearance(preset, name, generation)
      else
        nativeManager.preparingLoad = false
        state.load.needsContinue = false
        state.load.auto = false
        message("load", "The selected preset could not be read safely. Refresh and select it again.", true)
      end
    end)
  end
end

cancelLoading = function()
  resetLoadState()
  state.app.nativeLoadSummary = "Loading canceled. Choices already applied remain visible."
  message("load", state.app.nativeLoadSummary, false)
end

restoreAppearanceHistory = function(index)
  local entry = state.history.entries[tonumber(index)]
  if not entry then message("load", "That saved appearance is no longer available.", true); return false end
  resetLoadState()
  local generation = nativeManager.loadGeneration
  return submit("history_read", {index = entry.index, fingerprint = state.history.fingerprint}, "load", function(result)
    if not result or generation ~= nativeManager.loadGeneration then return end
    state.load.overridePreset = result.preset
    state.load.overrideName = "Appearance History " .. entry.index
    state.load.resetBefore = true
    loadPreset()
  end) ~= nil
end
restoreLastAppearance = function()
  if #state.history.entries > 0 then return restoreAppearanceHistory(1) end
  resetLoadState()
  local generation = nativeManager.loadGeneration
  return submit("history_read", {index = 0, fingerprint = state.history.fingerprint}, "load", function(result)
    if not result or generation ~= nativeManager.loadGeneration then return end
    state.load.overridePreset = result.preset
    state.load.overrideName = "Appearance Before Last Load"
    state.load.resetBefore = true
    loadPreset()
  end) ~= nil
end
clearAppearanceHistory = function(confirm)
  if not confirm or not state.history.pendingClear then
    state.history.pendingClear = true
    return false, "Select Clear Appearance History again to confirm."
  end
  state.history.pendingClear = false
  local operation = submit("history_clear", {confirmed = true, fingerprint = state.history.fingerprint},
    "load", applyHistory)
  return operation ~= nil, operation and "Clearing saved appearance history." or "Appearance history could not be cleared."
end

compareSelectedPreset = function(callback)
  nativeManager.comparisonCallbacks = nativeManager.comparisonCallbacks or {}
  if type(callback) == "function" then
    nativeManager.comparisonCallbacks[#nativeManager.comparisonCallbacks + 1] = callback
  end
  if nativeManager.comparing then return state.load.comparison end
  local name = state.library.selected
  local generation = nativeManager.loadGeneration
  local function finish(result)
    nativeManager.comparing = false
    local callbacks = nativeManager.comparisonCallbacks
    nativeManager.comparisonCallbacks = {}
    for _, waiting in ipairs(callbacks) do waiting(result) end
  end
  if not name then finish(); return nil end
  nativeManager.comparing = true
  nativeManager.read(name, function(preset)
    if not preset or state.library.selected ~= name then finish(); return end
    local _, options = getOptions(true)
    local snapshot, errorText = options and nativeAppearance.snapshot(options)
    if not snapshot then
      finish()
      if errorText then message("load", errorText, true) end
      return
    end
    local operation = submit("compare", {preset = preset, options = snapshot}, "load", function(result)
      if not result or state.library.selected ~= name or not state.app.inCustomization
          or generation ~= nativeManager.loadGeneration then finish(); return end
      local _, current = getOptions(true)
      local fresh = current and nativeAppearance.snapshot(current)
      if not fresh or not nativeAppearance.sameSnapshot(snapshot, fresh) then finish(); return end
      state.load.comparison = result
      state.load.preflight = {total = result.total, available = result.matching + result.changing,
        unavailable = result.missing, ambiguous = result.ambiguous, invalid = result.invalid}
      state.load.preflightDirty = false
      state.load.preflightPresetName = name
      finish(result)
    end)
    if not operation then finish() end
  end)
  return state.load.comparison
end
refreshPreflight = compareSelectedPreset

refreshTrash = function()
  if nativeManager.trashPending then return false end
  nativeManager.trashPending = true
  local staged, offset, fingerprint = {}, 0, nil
  local nextPage
  nextPage = function()
    local operation = submit("trash_query", {offset = offset, limit = 128, fingerprint = fingerprint},
      "delete", function(result)
        if not result then nativeManager.trashPending = false; return end
        if fingerprint and fingerprint ~= result.fingerprint then
          nativeManager.trashPending = false
          message("delete", "Trash changed while it was being read. Refresh and try again.", true)
          return
        end
        fingerprint = result.fingerprint
        local added = 0
        for name, item in pairs(result.items) do staged[name] = item; added = added + 1 end
        offset = offset + added
        if offset < result.total then
          if added == 0 then nativeManager.trashPending = false; return end
          nextPage()
          return
        end
        state.trash.items = staged
        state.trash.groups = result.groups or {}
        state.trash.bundles = result.bundles or {}
        state.trash.fingerprint = fingerprint
        state.trash.cachedNames = result.names or {}
        state.trash.cachedGroupIds = result.groupNames or {}
        state.trash.cachedBundleNames = result.bundleNames or {}
        state.trash.cachedGroupStats = result.statistics or {}
        state.trash.viewDirty = false
        nativeManager.trashPending = false
      end)
    if not operation then nativeManager.trashPending = false end
  end
  nextPage()
  return true
end

local function trashAction(action, payload, section)
  if nativeManager.trashPending or not state.trash.fingerprint then
    refreshTrash()
    message(section, "Wait for the Trash list to finish refreshing.", true)
    return false
  end
  payload.fingerprint = state.trash.fingerprint
  payload.confirmed = true
  return nativeManager.mutate(action, payload, section, function()
    state.trash.bulkSelected = {}
    state.trash.bulkSelectionDirty = true
    refreshTrash()
    nativeManager.refreshArchives()
  end)
end

trashPreset = function(source)
  local name = state.library.selected
  if not name then message("delete", "Select a preset first.", true); return false end
  local preset = state.library.presets[name]
  local field = source == "native" and "nativePendingDeleteName" or "pendingDeleteName"
  local fingerprintField = source == "native" and "nativePendingDeleteFingerprint" or "pendingDeleteFingerprint"
  if state.trash[field] ~= name or state.trash[fingerprintField] ~= preset.fingerprint then
    state.trash[field] = name
    state.trash[fingerprintField] = preset.fingerprint
    message("delete", "Select Move to Trash again to confirm. You can restore this preset from Trash.", false)
    return false
  end
  return trashAction("trash_move", {names = {name}}, "delete")
end
restoreTrashPreset = function(filename) return trashAction("trash_restore", {filename = filename}, "delete") end
restoreTrashGroup = function(group) return trashAction("trash_restore", {group = group}, "delete") end
emptyTrash = function()
  if not state.trash.pendingEmpty then
    state.trash.pendingEmpty = true
    message("delete", "Select Empty Trash again to permanently delete its contents.", true)
    return false
  end
  return trashAction("trash_empty", {}, "delete")
end
requestBulkTrash = function(names, folder)
  local section = folder and "folder" or "bulk"
  local signature = json.encode({names = names, folder = folder, revision = nativeLibrary.revision})
  if state.trash.pendingBulkFingerprint ~= signature then
    state.trash.pendingBulkAction = folder and ("folder:" .. folder) or "presets"
    state.trash.pendingBulkFingerprint = signature
    message(section, "Select Confirm Move to Trash to move the selected items. They can be restored from Trash.", false)
    return false
  end
  return trashAction("trash_move", {names = names, folder = folder}, section)
end

function nativeManager.refreshArchives(callback)
  nativeManager.archiveCallbacks = nativeManager.archiveCallbacks or {}
  if callback then nativeManager.archiveCallbacks[#nativeManager.archiveCallbacks + 1] = callback end
  if nativeManager.archivesPending then return end
  nativeManager.archivesPending = true
  local operation = submit("archive_list", {}, "folder", function(result)
    nativeManager.archivesPending = false
    if result then
      state.cache.folderBundleFiles = {}
      for _, filename in ipairs(result.bundles) do
        state.cache.folderBundleFiles[#state.cache.folderBundleFiles + 1] = PRESET_DIR .. "/" .. filename
      end
      state.backup.files = {}
      for _, filename in ipairs(result.backups) do
        state.backup.files[#state.backup.files + 1] = PRESET_DIR .. "/" .. filename
      end
      state.cache.folderBundleFilesDirty = false
      state.backup.filesDirty = false
    end
    local callbacks = nativeManager.archiveCallbacks
    nativeManager.archiveCallbacks = {}
    for _, waiting in ipairs(callbacks) do waiting(result) end
  end)
  if not operation then
    nativeManager.archivesPending = false
    local callbacks = nativeManager.archiveCallbacks
    nativeManager.archiveCallbacks = {}
    for _, waiting in ipairs(callbacks) do waiting(nil) end
  end
end
folderBundleFiles = function(force)
  if force or state.cache.folderBundleFilesDirty then nativeManager.refreshArchives() end
  return state.cache.folderBundleFiles
end
libraryBackupFiles = function(force)
  if force or state.backup.filesDirty then nativeManager.refreshArchives() end
  return state.backup.files
end
clearFolderBundlePreview = function() state.library.folderBundlePreview = nil end
viewSelectedFolderBundleContents = function()
  local filename = state.library.selectedBundleFile
  if not filename then message("folder", "Select a shared-folder file first.", true); return false end
  return submit("bundle_preview", {filename = filename}, "folder", function(result)
    if not result or state.library.selectedBundleFile ~= filename then return end
    state.library.folderBundlePreview = {filename = filename, root = result.root,
      folders = result.folders, presets = result.names, fingerprint = result.fingerprint}
  end) ~= nil
end

local function archiveMutation(action, payload, section, callback)
  return nativeManager.mutate(action, payload, section, function(result)
    nativeManager.refreshArchives()
    refreshTrash()
    if callback then callback(result) end
  end)
end
exportSelectedFolderBundle = function()
  return archiveMutation("bundle_export", {folder = state.library.selectedFolder}, "folder")
end
exportSelectedBulkPresetBundle = function()
  return archiveMutation("bundle_export", {names = selectedBulkPresetNames(), label = "Shared Presets"}, "bulk")
end
exportLibraryBackup = function() return archiveMutation("backup_export", {}, "backup") end

local function archiveInfo(kind, filename, section, callback)
  if not filename then message(section, "Select a file first.", true); return false end
  return submit(kind .. "_info", {filename = filename}, section, function(result)
    if result then callback(result) end
  end) ~= nil
end
trashSelectedFolderBundle = function()
  local filename = state.library.selectedBundleFile
  return archiveInfo("bundle", filename, "folder", function(info)
    archiveMutation("bundle_trash", {filename = filename, fingerprint = info.fingerprint}, "folder",
      clearFolderBundlePreview)
  end)
end
restoreTrashBundle = function(filename)
  local item = state.trash.bundles[filename]
  if not item then message("delete", "That shared-folder file is no longer in Trash.", true); return false end
  return archiveMutation("bundle_restore", {filename = filename, fingerprint = item.fingerprint}, "delete")
end
deleteSelectedLibraryBackup = function()
  local filename = state.backup.selectedFile and baseName(state.backup.selectedFile)
  return archiveInfo("backup", filename, "backup", function(info)
    if not state.backup.selectedFile or baseName(state.backup.selectedFile) ~= filename then return end
    if state.backup.pendingDeleteFile ~= state.backup.selectedFile
        or state.backup.pendingDeleteFingerprint ~= info.fingerprint then
      state.backup.pendingDeleteFile = state.backup.selectedFile
      state.backup.pendingDeleteFingerprint = info.fingerprint
      message("backup", "Select Delete Selected Backup Permanently again to confirm.", true)
      return
    end
    archiveMutation("backup_delete", {filename = filename, fingerprint = info.fingerprint, confirmed = true}, "backup")
  end)
end
importLibraryBackup = function()
  local filename = state.backup.selectedFile and baseName(state.backup.selectedFile)
  return submit("backup_preview", {filename = filename}, "backup", function(preview)
    if not preview then return end
    archiveMutation("backup_import", {filename = filename, fingerprint = preview.fingerprint,
      restoreSettings = true}, "backup", function()
      submit("config_read", {}, "backup", function(result)
        if not result then return end
        nativeManager.configFingerprint = result.fingerprint
        state.preferences = result.preferences
        state.library.sortMode = result.preferences.presetSort
        invalidateViewCache()
      end)
    end)
  end) ~= nil
end
importAvailableFolderBundles = function()
  if nativeManager.importingBundles then return false end
  nativeManager.importingBundles = true
  nativeManager.refreshArchives(function(result)
    if not result then nativeManager.importingBundles = false; return end
    local index = 0
    local nextFile
    nextFile = function()
      index = index + 1
      local filename = result.bundles[index]
      if not filename then nativeManager.importingBundles = false; return end
      local operation = submit("bundle_preview", {filename = filename}, "folder", function(preview)
        if not preview then nextFile(); return end
        if not archiveMutation("bundle_import", {filename = filename, fingerprint = preview.fingerprint},
            "folder", nextFile) then nativeManager.importingBundles = false end
      end)
      if not operation then nativeManager.importingBundles = false end
    end
    nextFile()
  end)
  return true
end

function nativeManager.update(delta)
  nativeService.update(delta)
  nativeManager.watchTimer = (nativeManager.watchTimer or 0) + math.max(0, tonumber(delta) or 0)
  if nativeManager.watchTimer >= 1 and nativeService.available and not state.load.auto
      and not nativeManager.refreshing and not nativeManager.writing and not nativeLibrary.busy
      and not nativeManager.importingBundles then
    nativeManager.watchTimer = 0
    local status = nativeService.status()
    if status and status.changes ~= nativeService.changes then
      nativeService.changes = status.changes
      refreshPresets("external")
    end
  end
  nativeManager.timer = nativeManager.timer + math.max(0, tonumber(delta) or 0)
  if nativeManager.timer < 0.2 then return end
  nativeManager.timer = 0
  if not nativeService.available or nativeManager.refreshing or nativeManager.writing or nativeLibrary.busy then return end
  if state.cache.viewDirty or state.cache.filteredViewDirty
      or state.cache.searchText ~= normalizeSearch(state.library.searchText) then nativeManager.view() end
end

function nativeManager.initialize()
  local available, errorText = nativeService.connect()
  if not available then
    message("load", errorText, true)
    message("create", errorText, true)
    return false
  end
  submit("config_read", {}, "load", function(result)
    if result then
      nativeManager.configFingerprint = result.fingerprint
      state.preferences.presetSort = result.preferences.presetSort
      state.library.sortMode = result.preferences.presetSort
      for _, warning in ipairs(result.warnings or {}) do log("[SETTINGS] " .. warning, "warn") end
    end
    refreshPresets("startup")
  end)
  return true
end

return _ENV
