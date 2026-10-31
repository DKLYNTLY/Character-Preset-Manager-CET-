local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime
local paths = require("modules/domain/paths")
local trashModel = require("modules/domain/trash")
local recoveryItems = require("modules/application/recovery_items")
local trashCodec = require("modules/domain/trash_codec")
local journalCodec = require("modules/domain/journal_codec")
local recovery = require("modules/application/recovery")
local fileAdapter = require("modules/adapters/files")
local recoveryPorts = {
  exists = function(path) return fileExists(path) end,
  rename = function(source, destination) return renameFile(source, destination) end,
  delete = function(path) return deleteFile(path) end,
  writeTransaction = function(phase, operation, plans) return writeTransaction(phase, operation, plans) end,
}

do

local function trashCatalogLines(trash, groups)
  return trashCodec.encode(trash, groups, MAX_CATALOG_LINES)
end

local function writeTrashCatalog(trash, groups)
  groups = groups or state.trash.groups
  local lines = trashCatalogLines(trash, groups)
  if not lines then
    log("[TRASH] The Trash list contains an unsafe entry or too many entries.", "error")
    return false
  end
  local result, changed = writeLinesIfChanged(
    TRASH_CATALOG_FILE, lines, "Trash list", MAX_CATALOG_BYTES)
  if result and not changed then
    log("[TRASH] The saved Trash list already matches its contents. No file was changed.", "info")
  end
  return result
end

local function readTrashCatalog()
  local contents, readError = readBoundedFile(TRASH_CATALOG_FILE, MAX_CATALOG_BYTES)
  if not contents then return {}, {}, readError == "missing" end
  return trashCodec.decode(contents, MAX_CATALOG_LINES)
end

writeTransaction = function(phase, operation, plans)
  local lines = journalCodec.encode(phase, operation, plans, MAX_TRANSACTION_LINES)
  if not lines then return false end
  local result = writeLinesIfChanged(
    TRANSACTION_FILE, lines, "transaction journal", MAX_TRANSACTION_BYTES)
  return result == true
end

local function readTransaction()
  local contents, readError = readBoundedFile(TRANSACTION_FILE, MAX_TRANSACTION_BYTES)
  if not contents then return nil, readError == "missing" and "missing" or "invalid" end
  return journalCodec.decodeLegacy(contents, MAX_TRANSACTION_LINES)
end

completeTransaction = function(operation, plans)
  return recovery.completeTransaction(recoveryPorts, operation, plans, TRANSACTION_FILE)
end

recoverTransaction = function()
  local transaction, transactionError = readTransaction()
  return fileAdapter.run(recovery.recoverTransaction, log, recoveryPorts,
    transaction, transactionError, {
      presetDirectory = PRESET_DIR, trashDirectory = TRASH_DIR, transactionFile = TRANSACTION_FILE,
    })
end

refreshTrash = function(recoveredOriginals)
  local originals, groups, catalogOk = readTrashCatalog()
  if not catalogOk then
    log("[TRASH] The Trash list cannot be read, contains unsafe data, or is too large. The last good Trash list was kept.", "error")
    return false
  end
  for filename, item in pairs(recoveredOriginals or {}) do originals[filename] = item end
  local trash, trashBundles = {}, {}
  local entries, listError = safeDirectoryEntries(TRASH_DIR, 0)
  if not entries then
    log(("[TRASH] The Trash folder could not be read safely: %s. The last good Trash list was kept.")
      :format(tostring(listError)), "error")
    return false
  end
  local trashPresetCount = 0
  for _, entry in ipairs(entries) do
    if entry.type == "file" and entry.name:lower():sub(-7) == ".preset" then
      if trashPresetCount >= AUTO_LOAD_LIMITS.maximumScannedPresets then
        log("[TRASH] The Trash folder contains more presets than the safety limit. The last good Trash list was kept.", "error")
        return false
      end
      trashPresetCount = trashPresetCount + 1
      local catalogItem = originals[entry.name]
      trash[entry.name] = {
        original = catalogItem and catalogItem.original or entry.name:sub(1, -8),
        group = catalogItem and catalogItem.group or nil,
        preset = { entryCount = 0, entryCountKnown = false, lazy = true },
      }
    elseif entry.type == "file" and isFolderBundleFilename(entry.name) then
      trashBundles[entry.name] = true
    end
  end
  state.trash.items = trash
  state.trash.groups = groups
  state.trash.bundles = trashBundles
  state.trash.viewDirty = true
  if not writeTrashCatalog(trash, groups) then return false end
  return true
end

state.invalidateTrashViewCache = function()
  state.trash.viewDirty = true
end

state.ensureTrashViewCache = function()
  if not state.trash.viewDirty then return end
  local trashNames, groupIds, bundleNames, groupStats = trashModel.buildView(
    state.trash.items,state.trash.groups,state.trash.bundles)
  state.trash.cachedNames = trashNames
  state.trash.cachedGroupIds = groupIds
  state.trash.cachedBundleNames = bundleNames
  state.trash.cachedGroupStats = groupStats
  state.trash.viewDirty = false
end

local function uniqueTrashFilename(name, reserved)
  local leaf = sanitizeName(baseName(name))
  for index = 1, 9999 do
    local candidate = trashModel.trashCandidate(leaf,index)
    if not state.trash.items[candidate] and not (reserved or {})[candidate]
        and not fileExists(TRASH_DIR .. "/" .. candidate) then
      return candidate
    end
  end
  return nil
end

local function uniqueRestoredBundleFilename(filename)
  local stem = filename:sub(1, -#FOLDER_BUNDLE_EXTENSION - 1)
  for index = 1, 9999 do
    local candidate = trashModel.bundleCandidate(filename,index,FOLDER_BUNDLE_EXTENSION,true)
    if not fileExists(PRESET_DIR .. "/" .. candidate) then return candidate end
  end
  return nil
end

restoreTrashBundle = function(filename)
  if not state.trash.bundles[filename] or not isFolderBundleFilename(filename) then
    setStatus("delete", "The shared-folder file is no longer in Trash.", true)
    return
  end
  local sourcePath = TRASH_DIR .. "/" .. filename
  local fingerprint = fileFingerprint(sourcePath, MAX_FOLDER_BUNDLE_BYTES)
  local restoredFilename = fingerprint and uniqueRestoredBundleFilename(filename) or nil
  if not fingerprint then
    setStatus("delete", "The shared-folder file in Trash could not be checked safely.", true)
    return
  end
  if not restoredFilename then
    setStatus("delete", "The mod could not create a safe file name for the restored shared folder.", true)
    return
  end
  local destinationPath = PRESET_DIR .. "/" .. restoredFilename
  local moved, moveError = renameFile(sourcePath, destinationPath)
  if not moved then
    setStatus("delete", "The shared-folder file could not be restored: " ..
      tostring(moveError), true)
    return
  end
  if fileFingerprint(destinationPath, MAX_FOLDER_BUNDLE_BYTES) ~= fingerprint then
    local rolledBack = renameFile(destinationPath, sourcePath) ~= nil
    setStatus("delete", rolledBack
      and "The restored shared-folder file could not be checked, so it was returned to Trash."
      or "The restored shared-folder file could not be checked or returned to Trash.", true)
    return
  end
  state.trash.bundles[filename] = nil
  state.invalidateTrashViewCache()
  state.library.selectedBundleFile = restoredFilename
  state.cache.folderBundleFilesDirty = true
  setStatus("delete", ("Restored shared-folder file \"%s\" to Character Presets.")
    :format(restoredFilename), false, "success")
  log(("[FOLDER BUNDLE] Restored Trash file='%s' as '%s'.")
    :format(filename, restoredFilename), "complete")
end

trashPreset = function(source)
  helpers.auditSection("TRASH PRESET")
  local nativeRequest = source == "native"
  local pendingName, pendingFingerprint
  if nativeRequest then
    pendingName = state.trash.nativePendingDeleteName
    pendingFingerprint = state.trash.nativePendingDeleteFingerprint
  else
    pendingName = state.trash.pendingDeleteName
    pendingFingerprint = state.trash.pendingDeleteFingerprint
  end
  log(("[PRESET] Trash requested: selected='%s' confirmed=%s")
    :format(tostring(state.library.selected),
      tostring(state.library.selected ~= nil and pendingName == state.library.selected)), "info")
  if not state.library.selected then return end
  local old = state.library.selected
  local preset = state.library.presets[old]
  if not preset then
    setStatus("delete", "The selected preset is no longer available.", true)
    return
  end
  local currentFingerprint = fileFingerprint(presetPath(old))
  if not currentFingerprint then
    cancelConfirmations()
    setStatus("delete", "The selected preset file could not be verified safely.", true)
    return
  end
  if pendingName ~= old then
    if nativeRequest then
      state.trash.nativePendingDeleteName = old
      state.trash.nativePendingDeleteFingerprint = currentFingerprint
    else
      state.trash.pendingDeleteName = old
      state.trash.pendingDeleteFingerprint = currentFingerprint
    end
    setStatus("delete", ("Move \"%s\" to Trash? Select Confirm Move to Trash.")
      :format(old))
    return
  end
  if pendingFingerprint ~= currentFingerprint then
    cancelConfirmations()
    setStatus("delete", "The preset changed after you confirmed it. Review that file before you start deleting it again.", true)
    return
  end
  state.trash.pendingDeleteName = nil
  state.trash.pendingDeleteFingerprint = nil
  state.trash.nativePendingDeleteName = nil
  state.trash.nativePendingDeleteFingerprint = nil

  local oldPath = presetPath(old)
  local trashFilename = uniqueTrashFilename(old)
  if not trashFilename then
    setStatus("delete", "The mod could not create a safe file name in Trash.", true)
    return
  end
  local trashPath = TRASH_DIR .. "/" .. trashFilename
  local plan = {
    storage = preset.storage,
    trashFilename = trashFilename,
    name = old,
  }
  if not writeTransaction("prepared", "trash", { plan }) then
    setStatus("delete", "The recovery record for this Trash action could not be created.", true)
    return
  end
  local moved, moveError = renameFile(oldPath, trashPath)
  if not moved then
    deleteFile(TRANSACTION_FILE)
    setStatus("delete", ("Could not move \"%s\" to Trash: %s")
      :format(old, tostring(moveError)), true)
    return
  end
  state.library.presets[old] = nil
  state.trash.items[trashFilename] = { original = old, preset = preset }
  local catalogsSaved = writeCatalog(state.library.presets, state.library.folders, state.library.manualFolders,
      state.library.ignoredPhysicalFolders) and writeTrashCatalog(state.trash.items)
  local transactionCompleted = catalogsSaved and completeTransaction("trash", { plan })
  if not transactionCompleted then
    state.library.presets[old] = preset
    state.trash.items[trashFilename] = nil
    local restored = renameFile(trashPath, oldPath) ~= nil
    writeCatalog(state.library.presets, state.library.folders, state.library.manualFolders,
      state.library.ignoredPhysicalFolders)
    writeTrashCatalog(state.trash.items)
    if restored then deleteFile(TRANSACTION_FILE) end
    setStatus("delete", restored
      and "The preset was returned because the Trash records could not be saved."
      or "Moving the preset to Trash failed, and its file could not be put back.", true)
    return
  end
  state.library.selected = nil
  state.library.presetNotes = ""
  state.library.presetTags = ""
  invalidatePresetAndTrashCaches()
  state.library.renameName = ""
  resetLoadState()
  clearStatus("rename")
  if writeInventory(state.library.presets, state.library.folders) then
    setStatus("delete", "Moved \"" .. old .. "\" to Trash.", false, "success")
  else
    setStatus("delete", "Moved \"" .. old .. "\" to Trash, but the preset file list could not be updated.",
      false, "warning")
  end
end

restoreTrashPreset = function(filename)
  local item = state.trash.items[filename]
  if not item then setStatus("delete", "The Trash item is no longer available.", true); return end
  local logicalName = item.original
  if findPresetCollision(logicalName) then
    logicalName = uniquePresetCopyName(logicalName)
  end
  if not logicalName then
    setStatus("delete", "The mod could not create an unused name for the restored preset.", true); return
  end
  local storage = uniqueStorageName(baseName(logicalName))
  if not storage then
    setStatus("delete", "The mod could not create a safe file name for the restored preset.", true); return
  end
  local sourcePath = TRASH_DIR .. "/" .. filename
  local destinationPath = PRESET_DIR .. "/" .. storage .. ".preset"
  local plan = {
    storage = storage, trashFilename = filename, name = logicalName,
    recoveryName = item.original,
  }
  if not writeTransaction("prepared", "restore", { plan }) then
    setStatus("delete", "The recovery record for this restore action could not be created.", true); return
  end
  local moved, moveError = renameFile(sourcePath, destinationPath)
  if not moved then
    deleteFile(TRANSACTION_FILE)
    setStatus("delete", "The preset could not be restored: " .. tostring(moveError), true); return
  end
  local preset = readPresetFile(destinationPath)
  if not preset then
    renameFile(destinationPath, sourcePath)
    deleteFile(TRANSACTION_FILE)
    setStatus("delete", "The restored preset could not be verified.", true); return
  end
  preset.fingerprint = fileFingerprint(destinationPath, MAX_PRESET_BYTES)
  preset.storage = storage
  local previousFolders = cloneMap(state.library.folders)
  state.library.presets[logicalName] = preset
  addFolderAncestors(state.library.folders, parentFolder(logicalName))
  state.trash.items[filename] = nil
  local catalogsSaved = writeCatalog(state.library.presets, state.library.folders, state.library.manualFolders,
      state.library.ignoredPhysicalFolders) and writeTrashCatalog(state.trash.items)
  local transactionCompleted = catalogsSaved and completeTransaction("restore", { plan })
  if not transactionCompleted then
    state.library.presets[logicalName] = nil
    state.library.folders = previousFolders
    state.trash.items[filename] = item
    local restored = renameFile(destinationPath, sourcePath) ~= nil
    writeCatalog(state.library.presets, state.library.folders, state.library.manualFolders,
      state.library.ignoredPhysicalFolders)
    writeTrashCatalog(state.trash.items)
    if restored then deleteFile(TRANSACTION_FILE) end
    setStatus("delete", restored
      and "The preset was returned to Trash because the restore records could not be saved."
      or "The restore could not finish or return the file to Trash. Recovery will try again when you next start the game.", true)
    return
  end
  state.library.selected = logicalName
  state.library.presetNotes = preset.notes or ""
  state.library.presetTags = preset.tags or ""
  cancelConfirmations()
  invalidatePresetAndTrashCaches()
  local inventorySaved = writeInventory(state.library.presets, state.library.folders)
  setStatus("delete", "Restored \"" .. logicalName .. "\" from Trash." ..
    (inventorySaved and "" or " The preset file list could not be updated."), false,
    inventorySaved and "success" or "warning")
end

local function allocateRestoreLogicalName(original,reserved)
  return trashModel.allocateRestoreLogicalName(original,reserved,state.library.presets)
end

restoreTrashGroup = function(groupId)
  local group = state.trash.groups[groupId]
  if not group then
    setStatus("delete", "The trashed folder group is no longer available.", true); return
  end
  local filenames = trashModel.groupFilenames(state.trash.items,groupId)
  local reservedLogical, reservedStorage = {}, storageFilenamesInUse()
  if not reservedStorage then
    setStatus("delete", "The existing preset file names could not be checked safely.", true); return
  end
  for name in pairs(state.library.presets) do reservedLogical[name:lower()] = true end
  local plans = {}
  for _, filename in ipairs(filenames) do
    local item = state.trash.items[filename]
    local logicalName = allocateRestoreLogicalName(item.original, reservedLogical)
    local storage = logicalName and uniqueStorageName(baseName(logicalName), reservedStorage)
    if not logicalName or not storage then
      setStatus("delete", "The mod could not create a safe name for every preset in this folder.", true); return
    end
    table.insert(plans, {
      filename = filename,
      trashFilename = filename,
      name = logicalName,
      recoveryName = item.original,
      storage = storage,
      item = item,
      source = TRASH_DIR .. "/" .. filename,
      destination = PRESET_DIR .. "/" .. storage .. ".preset",
    })
  end

  if #plans > 0 and not writeTransaction("prepared", "restore", plans) then
    setStatus("delete", "The recovery record for this folder restore could not be created.", true); return
  end
  local moved = {}
  for _, plan in ipairs(plans) do
    if not renameFile(plan.source, plan.destination) then
      local rollbackFailed = false
      for index = #moved, 1, -1 do
        local item = moved[index]
        if not renameFile(item.destination, item.source) then rollbackFailed = true end
      end
      if not rollbackFailed then deleteFile(TRANSACTION_FILE) end
      setStatus("delete", rollbackFailed
        and "The folder restore stopped, and some files could not be returned to Trash. The mod will try to recover them at the next startup."
        or "Folder restore stopped before all preset files could be moved.", true)
      return
    end
    local verified = readPresetFile(plan.destination)
    if not verified or (plan.item.preset.entryCountKnown ~= false
        and not presetsMatch(plan.item.preset, verified)) then
      table.insert(moved, plan)
      local rollbackFailed = false
      for index = #moved, 1, -1 do
        local item = moved[index]
        if not renameFile(item.destination, item.source) then rollbackFailed = true end
      end
      if not rollbackFailed then deleteFile(TRANSACTION_FILE) end
      setStatus("delete", rollbackFailed
        and "A restored preset could not be checked, and some files could not be returned to Trash. The mod will try to recover them at the next startup."
        or "The restored folder failed its check. Its moved files were returned to Trash.", true)
      return
    end
    verified.fingerprint = fileFingerprint(plan.destination, MAX_PRESET_BYTES)
    plan.preset = verified
    table.insert(moved, plan)
  end

  local newPresets,newFolders,newTrash,newGroups,newManualFolders,newIgnored = recoveryItems.restoreGroupMaps(
    state.library,state.trash,group,groupId,plans)
  local catalogsSaved = writeCatalog(newPresets, newFolders, newManualFolders,
      newIgnored) and writeTrashCatalog(newTrash, newGroups)
  local transactionCompleted = #plans == 0 or
    (catalogsSaved and completeTransaction("restore", plans))
  if #plans == 0 then transactionCompleted = catalogsSaved end
  if not transactionCompleted then
    local rollbackFailed = false
    for index = #moved, 1, -1 do
      local plan = moved[index]
      if not renameFile(plan.destination, plan.source) then rollbackFailed = true end
    end
    writeCatalog(state.library.presets, state.library.folders, state.library.manualFolders,
      state.library.ignoredPhysicalFolders)
    writeTrashCatalog(state.trash.items, state.trash.groups)
    if not rollbackFailed then deleteFile(TRANSACTION_FILE) end
    setStatus("delete", rollbackFailed
      and "The folder restore could not finish, and some files could not be returned to Trash. The mod will try to recover them at the next startup."
      or "The presets were returned to Trash because the folder or Trash lists could not be saved.", true)
    return
  end

  state.library.presets, state.library.folders = newPresets, newFolders
  state.trash.items, state.trash.groups = newTrash, newGroups
  state.library.manualFolders, state.library.ignoredPhysicalFolders = newManualFolders, newIgnored
  if plans[1] then
    state.library.selected = plans[1].name
    state.library.presetNotes = plans[1].preset.notes or ""
    state.library.presetTags = plans[1].preset.tags or ""
  end
  cancelConfirmations()
  invalidatePresetAndTrashCaches()
  resetLoadState()
  local inventorySaved = writeInventory(newPresets, newFolders)
  setStatus("delete", ("Restored folder \"%s\" with %d preset%s, including empty folders inside it.")
    :format(group.root, #plans, #plans == 1 and "" or "s") ..
    (inventorySaved and "" or " The preset file list could not be updated."), false,
    inventorySaved and "success" or "warning")
end

emptyTrash = function()
  local count,groupCount,bundleCount = trashModel.counts(state.trash.items,state.trash.groups,state.trash.bundles)
  if count == 0 and groupCount == 0 and bundleCount == 0 then
    setStatus("delete", "Trash is already empty."); return
  end
  if not state.trash.pendingEmpty then
    cancelConfirmations()
    state.trash.pendingEmpty = true
    setStatus("delete", ("Permanently delete %d preset%s, %d saved folder record%s, and %d shared-folder file%s from Trash? Select Empty Trash Permanently again.")
      :format(count, count == 1 and "" or "s", groupCount,
        groupCount == 1 and "" or "s", bundleCount, bundleCount == 1 and "" or "s"))
    return
  end
  state.trash.pendingEmpty = false
  local failed, presetFailed = 0, 0
  for filename in pairs(state.trash.items) do
    if deleteFile(TRASH_DIR .. "/" .. filename) then
      state.trash.items[filename] = nil
    else
      failed = failed + 1
      presetFailed = presetFailed + 1
    end
  end
  for filename in pairs(state.trash.bundles) do
    if deleteFile(TRASH_DIR .. "/" .. filename) then
      state.trash.bundles[filename] = nil
    else
      failed = failed + 1
    end
  end
  if presetFailed == 0 then state.trash.groups = {} end
  state.invalidateTrashViewCache()
  local catalogSaved = writeTrashCatalog(state.trash.items, state.trash.groups)
  if failed > 0 then
    setStatus("delete", ("Trash cleanup stopped with %d file%s remaining.")
      :format(failed, failed == 1 and "" or "s"), true)
  elseif not catalogSaved then
    setStatus("delete", "Trash was emptied, but its list could not be updated.", true)
  else
    setStatus("delete", "Trash emptied permanently.", false, "success")
  end
end

bulkPresetNamesInFolder = function(folder)
  ensureViewCache()
  if state.trash.cachedBulkFolder == folder then return state.trash.cachedBulkFolderNames end
  local names,nestedFolderCount = trashModel.namesInFolder(state.cache.presetNames,state.library.folders,folder)
  state.trash.cachedBulkFolder = folder
  state.trash.cachedBulkFolderNames = names
  state.trash.cachedBulkNestedFolderCount = nestedFolderCount
  return names
end

selectedBulkPresetNames = function()
  if not state.trash.bulkSelectionDirty then return state.trash.cachedBulkSelectedNames end
  local names = trashModel.selectedNames(state.trash.bulkSelected,state.library.presets)
  state.trash.cachedBulkSelectedNames = names
  state.trash.bulkSelectionDirty = false
  return names
end

local function bulkTrashFingerprint(names, folder)
  local parts = { "folder:" .. tostring(folder or "") }
  for _, name in ipairs(names) do
    local preset = state.library.presets[name]
    if not preset then return nil, "A selected preset is no longer available." end
    local fingerprint = fileFingerprint(presetPath(name))
    if not fingerprint then
      return nil, ("The preset \"%s\" could not be verified safely."):format(name)
    end
    table.insert(parts, "preset:" .. name .. ":" .. fingerprint)
  end
  if folder then
    for candidate in pairs(state.library.folders) do
      if isInFolderTree(candidate, folder) then table.insert(parts, "folder:" .. candidate) end
    end
  end
  table.sort(parts)
  return table.concat(parts, "\30")
end

local function moveBulkPresetsToTrash(names, folder, statusSection)
  statusSection = statusSection or "bulk"
  local physicalFolderWasImported = folder and state.library.manualFolders[folder] == true
  local reserved, plans = {}, {}
  for _, name in ipairs(names) do
    local preset = state.library.presets[name]
    local trashFilename = uniqueTrashFilename(name, reserved)
    if not preset or not trashFilename then
      setStatus(statusSection, "The mod could not create a safe file name in Trash.", true)
      return false
    end
    reserved[trashFilename] = true
    table.insert(plans, {
      name = name,
      preset = preset,
      storage = preset.storage,
      source = presetPath(name),
      destination = TRASH_DIR .. "/" .. trashFilename,
      trashFilename = trashFilename,
    })
  end

  if folder then
    plans.recoveryFolders, plans.recoveryManualFolders = {}, {}
    for candidate in pairs(state.library.folders) do
      if isInFolderTree(candidate, folder) then
        plans.recoveryFolders[candidate] = true
        if state.library.manualFolders[candidate] then
          plans.recoveryManualFolders[candidate] = true
        end
      end
    end
  end

  if not writeTransaction("prepared", "trash", plans) then
    setStatus(statusSection, "The recovery record for moving these items to Trash could not be created.", true)
    return false
  end

  local moved = {}
  for _, plan in ipairs(plans) do
    local movedFile, moveError = renameFile(plan.source, plan.destination)
    if not movedFile then
      local rollbackFailed = false
      for index = #moved, 1, -1 do
        local item = moved[index]
        if not renameFile(item.destination, item.source) then rollbackFailed = true end
      end
      if rollbackFailed then
        refreshPresets("bulk-recovery")
        refreshTrash()
      else
        deleteFile(TRANSACTION_FILE)
      end
      setStatus(statusSection, rollbackFailed
        and "Bulk Trash failed, and at least one moved preset could not be restored. Refresh completed; review Trash."
        or ("Bulk Trash stopped at \"%s\": %s"):format(plan.name, tostring(moveError)), true)
      return false
    end
    table.insert(moved, plan)
  end

  local newPresets,newTrash,newTrashGroups,newFolders,newManualFolders,newIgnored,nestedFolderCount = recoveryItems.bulkTrashMaps(
    state.library,state.trash,plans,folder)
  local catalogsSaved = writeCatalog(newPresets, newFolders, newManualFolders, newIgnored)
    and writeTrashCatalog(newTrash, newTrashGroups)
  local transactionCompleted = catalogsSaved and completeTransaction("trash", plans)
  if not transactionCompleted then
    local rollbackFailed = false
    for index = #moved, 1, -1 do
      local plan = moved[index]
      if not renameFile(plan.destination, plan.source) then rollbackFailed = true end
    end
    if rollbackFailed then
      refreshPresets("bulk-recovery")
      refreshTrash()
    else
      writeCatalog(state.library.presets, state.library.folders, state.library.manualFolders,
        state.library.ignoredPhysicalFolders)
      writeTrashCatalog(state.trash.items, state.trash.groups)
      deleteFile(TRANSACTION_FILE)
    end
    setStatus(statusSection, rollbackFailed
      and "The Trash lists could not be saved, and at least one preset could not be returned. Refresh is complete; check Trash."
      or "The presets were returned because the folder, Trash, or recovery lists could not be saved.", true)
    return false
  end

  state.library.presets, state.trash.items = newPresets, newTrash
  state.trash.groups = newTrashGroups
  state.library.folders, state.library.manualFolders = newFolders, newManualFolders
  state.library.ignoredPhysicalFolders = newIgnored
  if state.library.selected and not newPresets[state.library.selected] then
    state.library.selected = nil
    state.library.presetNotes, state.library.presetTags = "", ""
  end
  if folder then
    local destination = parentFolder(folder)
    state.library.selectedFolder = newFolders[destination] and destination or ""
  end
  for _, name in ipairs(names) do state.trash.bulkSelected[name] = nil end
  invalidatePresetAndTrashCaches()
  resetLoadState()
  cancelConfirmations()
  local inventorySaved = writeInventory(newPresets, newFolders)
  local physicalFolderRemoved = false
  if physicalFolderWasImported
      and directoryTreeContainsFiles(folderPath(folder), 0) == false then
    physicalFolderRemoved = removeEmptyDirectoryTree(folderPath(folder), 0)
  end
  setStatus(statusSection, (folder
    and ("Moved folder \"%s\" and %d preset%s to Trash; removed %d folder%s inside it. Restoring the folder rebuilds this structure.%s")
      :format(folder, #names, #names == 1 and "" or "s", nestedFolderCount,
        nestedFolderCount == 1 and "" or "s",
        physicalFolderWasImported and (physicalFolderRemoved
          and " Its empty Windows folder was removed."
          or " Its Windows folder was kept because it contains other files or could not be removed safely.") or "")
    or ("Moved %d preset%s to Trash. You can restore them later.")
      :format(#names, #names == 1 and "" or "s")) ..
    (inventorySaved and "" or " The preset file list could not be updated."), false,
    inventorySaved and "success" or "warning")
  return true
end

requestBulkTrash = function(names, folder)
  local statusSection = folder and "folder" or "bulk"
  if #names == 0 then
    setStatus(statusSection, folder
      and "This folder has no presets. To remove it, use Remove Folder, Keep Presets."
      or "Select at least one preset before using this group action.", true)
    return
  end
  local fingerprint, fingerprintError = bulkTrashFingerprint(names, folder)
  if not fingerprint then setStatus(statusSection, fingerprintError, true); return end
  local action = folder and ("folder:" .. folder) or "presets"
  if state.trash.pendingBulkAction ~= action
      or state.trash.pendingBulkFingerprint ~= fingerprint then
    state.trash.pendingBulkAction = action
    state.trash.pendingBulkFingerprint = fingerprint
    setStatus(statusSection, folder
      and ("Move folder \"%s\" and %d preset%s to Trash? Select Confirm Move Folder & Presets to Trash.")
        :format(folder, #names, #names == 1 and "" or "s")
      or ("Move %d selected preset%s to Trash? Select Confirm Bulk Trash.")
        :format(#names, #names == 1 and "" or "s"))
    return
  end
  moveBulkPresetsToTrash(names, folder, statusSection)
end

end

return _ENV
