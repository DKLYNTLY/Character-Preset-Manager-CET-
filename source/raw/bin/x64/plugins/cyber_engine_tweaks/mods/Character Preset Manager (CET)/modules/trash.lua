local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

do

local function validTrashFilename(filename)
  return type(filename) == "string" and #filename > 7 and #filename <= 71
    and filename:find("/", 1, true) == nil and filename:find("\\", 1, true) == nil
    and filename:lower():sub(-7) == ".preset"
end

local function trashCatalogLines(trash, groups)
  local lines = {}
  for filename, item in pairs(trash or {}) do
    if not validTrashFilename(filename)
        or not validRelativePath(item.original or "") then return nil end
    table.insert(lines, "P\t" .. catalogEncode(filename) .. "\t" ..
      catalogEncode(item.original) .. "\t" .. catalogEncode(item.group or ""))
  end
  for groupId, group in pairs(groups or {}) do
    if type(groupId) ~= "string" or groupId == "" or #groupId > 256
        or not validRelativePath(group.root or "") then return nil end
    table.insert(lines, "G\t" .. catalogEncode(groupId) .. "\t" ..
      catalogEncode(group.root))
    for folder in pairs(group.folders or {}) do
      if not validRelativePath(folder) then return nil end
      table.insert(lines, "F\t" .. catalogEncode(groupId) .. "\t" ..
        catalogEncode(folder))
    end
    for folder in pairs(group.manualFolders or {}) do
      if not validRelativePath(folder) then return nil end
      table.insert(lines, "M\t" .. catalogEncode(groupId) .. "\t" ..
        catalogEncode(folder))
    end
  end
  table.sort(lines, function(a, b) return a:lower() < b:lower() end)
  if #lines > MAX_CATALOG_LINES then return nil end
  return lines
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
    log("[TRASH] The saved Trash list is already current. No file update was needed.", "info")
  end
  return result
end

local function readTrashCatalog()
  local originals, groups = {}, {}
  local contents, readError = readBoundedFile(TRASH_CATALOG_FILE, MAX_CATALOG_BYTES)
  if not contents then
    return originals, groups, readError == "missing"
  end
  local lineCount = 0
  for line in (contents .. "\n"):gmatch("(.-)\n") do
    if line ~= "" then
      lineCount = lineCount + 1
      if lineCount > MAX_CATALOG_LINES then return nil, nil, false end
      local kind, first, second, third = line:match("^([PGFM])\t([^\t]+)\t([^\t]+)\t?(.*)$")
      if kind == "P" then
        local filename = catalogDecode(first)
        local original = catalogDecode(second)
        local group = third ~= "" and catalogDecode(third) or nil
        if not validTrashFilename(filename) or not validRelativePath(original)
            or (group and #group > 256) then return nil, nil, false end
        originals[filename] = { original = original, group = group }
      elseif kind == "G" then
        local groupId, root = catalogDecode(first), catalogDecode(second)
        if groupId == "" or #groupId > 256 or not validRelativePath(root) then
          return nil, nil, false
        end
        groups[groupId] = groups[groupId] or { root = root, folders = {}, manualFolders = {} }
        groups[groupId].root = root
      elseif kind == "F" or kind == "M" then
        local groupId, folder = catalogDecode(first), catalogDecode(second)
        if groupId == "" or #groupId > 256 or not validRelativePath(folder) then
          return nil, nil, false
        end
        groups[groupId] = groups[groupId] or {
          root = folder, folders = {}, manualFolders = {},
        }
        groups[groupId].manualFolders = groups[groupId].manualFolders or {}
        if kind == "M" then
          groups[groupId].manualFolders[folder] = true
        else
          groups[groupId].folders[folder] = true
        end
      else return nil, nil, false end
    end
  end
  for groupId, group in pairs(groups) do
    if not group.root or group.root == "" then groups[groupId] = nil end
  end
  for _, item in pairs(originals) do
    if item.group and not groups[item.group] then return nil, nil, false end
  end
  return originals, groups, true
end

writeTransaction = function(phase, operation, plans)
  local lines = { "V\t1", "H\t" .. phase .. "\t" .. operation }
  for _, plan in ipairs(plans or {}) do
    if operation == "rename" then
      if not validRelativePath(plan.storage or "")
          or not validRelativePath(plan.destinationStorage or "")
          or not validRelativePath(plan.name or "") then return false end
      table.insert(lines, "R\t" .. catalogEncode(plan.storage) .. "\t" ..
        catalogEncode(plan.destinationStorage) .. "\t" .. catalogEncode(plan.name))
    else
      if not validRelativePath(plan.storage or "")
          or not validTrashFilename(plan.trashFilename)
          or not validRelativePath(plan.recoveryName or plan.name or "") then return false end
      table.insert(lines, "P\t" .. catalogEncode(plan.storage) .. "\t" ..
        catalogEncode(plan.trashFilename) .. "\t" ..
        catalogEncode(plan.recoveryName or plan.name))
    end
  end
  for folder in pairs((plans or {}).recoveryFolders or {}) do
    if not validRelativePath(folder) then return false end
    table.insert(lines, "D\t" .. catalogEncode(folder) .. "\t" ..
      ((plans.recoveryManualFolders or {})[folder] and "1" or "0"))
  end
  if #lines > MAX_TRANSACTION_LINES then return false end
  local result = writeLinesIfChanged(
    TRANSACTION_FILE, lines, "transaction journal", MAX_TRANSACTION_BYTES)
  return result == true
end

local function readTransaction()
  local contents, readError = readBoundedFile(TRANSACTION_FILE, MAX_TRANSACTION_BYTES)
  if not contents then return nil, readError == "missing" and "missing" or "invalid" end
  local transaction = { plans = {}, recoveryFolders = {}, recoveryManualFolders = {} }
  local lineCount = 0
  for line in (contents .. "\n"):gmatch("(.-)\n") do
    if line ~= "" then
      lineCount = lineCount + 1
      if lineCount > MAX_TRANSACTION_LINES then return nil, "invalid" end
      local phase, operation = line:match("^H\t([^\t]+)\t([^\t]+)$")
      if phase then
        transaction.phase, transaction.operation = phase, operation
      else
        local storage, filename, name = line:match("^P\t([^\t]+)\t([^\t]+)\t([^\t]+)$")
        if storage then
          storage, filename, name = catalogDecode(storage), catalogDecode(filename), catalogDecode(name)
          if not validRelativePath(storage) or not validTrashFilename(filename)
              or not validRelativePath(name) then return nil, "invalid" end
          table.insert(transaction.plans, {
            storage = storage, trashFilename = filename, name = name,
          })
        else
          local oldStorage, newStorage, name = line:match("^R\t([^\t]+)\t([^\t]+)\t([^\t]+)$")
          if oldStorage then
            oldStorage, newStorage, name = catalogDecode(oldStorage),
              catalogDecode(newStorage), catalogDecode(name)
            if not validRelativePath(oldStorage) or not validRelativePath(newStorage)
                or not validRelativePath(name) then return nil, "invalid" end
            table.insert(transaction.plans, {
              storage = oldStorage, destinationStorage = newStorage, name = name,
            })
          else
            local folder, manual = line:match("^D\t([^\t]+)\t([01])$")
            if folder then
              folder = catalogDecode(folder)
              if not validRelativePath(folder) then return nil, "invalid" end
              transaction.recoveryFolders[folder] = true
              if manual == "1" then transaction.recoveryManualFolders[folder] = true end
            elseif line ~= "V\t1" then
              return nil, "invalid"
            end
          end
        end
      end
    end
  end
  if (transaction.phase ~= "prepared" and transaction.phase ~= "committed")
      or (transaction.operation ~= "trash" and transaction.operation ~= "restore"
        and transaction.operation ~= "rename")
      or #transaction.plans == 0 then return nil, "invalid" end
  return transaction
end

completeTransaction = function(operation, plans)
  if not writeTransaction("committed", operation, plans) then return false end
  return os.remove(TRANSACTION_FILE) ~= nil or not fileExists(TRANSACTION_FILE)
end

recoverTransaction = function()
  local transaction, transactionError = readTransaction()
  if not transaction then
    if transactionError ~= "missing" then
      log("[RECOVERY] Transaction journal is invalid; preset scanning was stopped.", "error")
      return false, {}, {}, {}, {}
    end
    return true, {}, {}, {}, {}
  end
  if transaction.phase == "committed" then
    local removed = os.remove(TRANSACTION_FILE) ~= nil or not fileExists(TRANSACTION_FILE)
    log(removed and "[RECOVERY] Completed transaction journal cleanup."
      or "[RECOVERY] The committed transaction is safe, but its journal could not be removed; cleanup will retry next startup.",
      removed and "info" or "warn")
    return true, {}, {}, {}, {}
  end
  local recoveredOriginals, recoveredAssignments, recovered = {}, {}, true
  for _, plan in ipairs(transaction.plans) do
    local mainPath = PRESET_DIR .. "/" .. plan.storage .. ".preset"
    local trashPath = plan.trashFilename and (TRASH_DIR .. "/" .. plan.trashFilename) or nil
    local renamedPath = plan.destinationStorage
      and (PRESET_DIR .. "/" .. plan.destinationStorage .. ".preset") or nil
    local rollbackSource = transaction.operation == "trash" and trashPath
      or transaction.operation == "restore" and mainPath or renamedPath
    local rollbackDestination = transaction.operation == "trash" and mainPath
      or transaction.operation == "restore" and trashPath or mainPath
    if fileExists(rollbackSource) and not fileExists(rollbackDestination) then
      if not os.rename(rollbackSource, rollbackDestination) then recovered = false end
    elseif not fileExists(rollbackSource) and not fileExists(rollbackDestination) then
      recovered = false
    end
    if trashPath and fileExists(trashPath) then
      recoveredOriginals[plan.trashFilename] = { original = plan.name }
    end
    if transaction.operation == "trash" or transaction.operation == "rename" then
      recoveredAssignments[plan.storage] = plan.name
    end
  end
  if recovered then os.remove(TRANSACTION_FILE) end
  log("[RECOVERY] Unfinished " .. transaction.operation .. " transaction " ..
    (recovered and "was rolled back." or "could not be fully rolled back; it will be retried."),
    recovered and "warn" or "error")
  return recovered, recoveredOriginals, recoveredAssignments,
    transaction.recoveryFolders, transaction.recoveryManualFolders
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
  local trashNames, groupIds, bundleNames, groupStats = {}, {}, {}, {}
  for filename, item in pairs(state.trash.items) do
    table.insert(trashNames, filename)
    if item.group then
      local stats = groupStats[item.group] or { presets = 0, folders = 0 }
      stats.presets = stats.presets + 1
      groupStats[item.group] = stats
    end
  end
  for groupId, group in pairs(state.trash.groups) do
    table.insert(groupIds, groupId)
    local stats = groupStats[groupId] or { presets = 0, folders = 0 }
    for _ in pairs(group.folders or {}) do stats.folders = stats.folders + 1 end
    groupStats[groupId] = stats
  end
  for filename in pairs(state.trash.bundles) do table.insert(bundleNames, filename) end
  table.sort(trashNames, function(a, b) return a:lower() < b:lower() end)
  table.sort(groupIds, function(a, b)
    return state.trash.groups[a].root:lower() < state.trash.groups[b].root:lower()
  end)
  table.sort(bundleNames, function(a, b) return a:lower() < b:lower() end)
  state.trash.cachedNames = trashNames
  state.trash.cachedGroupIds = groupIds
  state.trash.cachedBundleNames = bundleNames
  state.trash.cachedGroupStats = groupStats
  state.trash.viewDirty = false
end

local function uniqueTrashFilename(name, reserved)
  local leaf = sanitizeName(baseName(name))
  for index = 1, 9999 do
    local suffix = index == 1 and "" or (" %d"):format(index)
    local candidate = leaf:sub(1, 64 - #suffix) .. suffix .. ".preset"
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
    local suffix = index == 1 and "" or (" Copy %d"):format(index)
    local candidate = stem:sub(1, 255 - #FOLDER_BUNDLE_EXTENSION - #suffix) ..
      suffix .. FOLDER_BUNDLE_EXTENSION
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
  local moved, moveError = os.rename(sourcePath, destinationPath)
  if not moved then
    setStatus("delete", "The shared-folder file could not be restored: " ..
      tostring(moveError), true)
    return
  end
  if fileFingerprint(destinationPath, MAX_FOLDER_BUNDLE_BYTES) ~= fingerprint then
    local rolledBack = os.rename(destinationPath, sourcePath) ~= nil
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

trashPreset = function()
  helpers.auditSection("TRASH PRESET")
  log(("[PRESET] Trash requested: selected='%s' confirmed=%s")
    :format(tostring(state.library.selected),
      tostring(state.trash.pendingDeleteName == state.library.selected)), "info")
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
  if state.trash.pendingDeleteName ~= old then
    state.trash.pendingDeleteName = old
    state.trash.pendingDeleteFingerprint = currentFingerprint
    setStatus("delete", ("Move \"%s\" to Trash? Select Confirm Move to Trash.")
      :format(old))
    return
  end
  if state.trash.pendingDeleteFingerprint ~= currentFingerprint then
    cancelConfirmations()
    setStatus("delete", "The preset changed after confirmation. Review it and start deletion again.", true)
    return
  end
  state.trash.pendingDeleteName = nil
  state.trash.pendingDeleteFingerprint = nil

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
  local moved, moveError = os.rename(oldPath, trashPath)
  if not moved then
    os.remove(TRANSACTION_FILE)
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
    local restored = os.rename(trashPath, oldPath) ~= nil
    writeCatalog(state.library.presets, state.library.folders, state.library.manualFolders,
      state.library.ignoredPhysicalFolders)
    writeTrashCatalog(state.trash.items)
    if restored then os.remove(TRANSACTION_FILE) end
    setStatus("delete", restored
      and "The preset was returned because the Trash records could not be saved."
      or "The Trash operation failed, and the preset file could not be restored.", true)
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
  local moved, moveError = os.rename(sourcePath, destinationPath)
  if not moved then
    os.remove(TRANSACTION_FILE)
    setStatus("delete", "The preset could not be restored: " .. tostring(moveError), true); return
  end
  local preset = readPresetFile(destinationPath)
  if not preset then
    os.rename(destinationPath, sourcePath)
    os.remove(TRANSACTION_FILE)
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
    local restored = os.rename(destinationPath, sourcePath) ~= nil
    writeCatalog(state.library.presets, state.library.folders, state.library.manualFolders,
      state.library.ignoredPhysicalFolders)
    writeTrashCatalog(state.trash.items)
    if restored then os.remove(TRANSACTION_FILE) end
    setStatus("delete", restored
      and "The preset was returned to Trash because the restore records could not be saved."
      or "The restore could not finish or return the file to Trash. The mod will try to recover it at the next startup.", true)
    return
  end
  state.library.selected = logicalName
  state.library.presetNotes = preset.notes or ""
  state.library.presetTags = preset.tags or ""
  invalidatePresetAndTrashCaches()
  local inventorySaved = writeInventory(state.library.presets, state.library.folders)
  setStatus("delete", "Restored \"" .. logicalName .. "\" from Trash." ..
    (inventorySaved and "" or " The preset file list could not be updated."), false,
    inventorySaved and "success" or "warning")
end

local function allocateRestoreLogicalName(original, reserved)
  if not reserved[original:lower()] and not findPresetCollision(original) then
    reserved[original:lower()] = true
    return original
  end
  local folder, leaf = parentFolder(original), baseName(original)
  for index = 1, 999 do
    local suffix = index == 1 and " Copy" or (" Copy %d"):format(index)
    local candidate = joinFolder(folder, leaf:sub(1, 64 - #suffix) .. suffix)
    if not reserved[candidate:lower()] and not findPresetCollision(candidate) then
      reserved[candidate:lower()] = true
      return candidate
    end
  end
  return nil
end

restoreTrashGroup = function(groupId)
  local group = state.trash.groups[groupId]
  if not group then
    setStatus("delete", "The trashed folder group is no longer available.", true); return
  end
  local filenames = {}
  for filename, item in pairs(state.trash.items) do
    if item.group == groupId then table.insert(filenames, filename) end
  end
  table.sort(filenames, function(a, b) return a:lower() < b:lower() end)
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
    if not os.rename(plan.source, plan.destination) then
      local rollbackFailed = false
      for index = #moved, 1, -1 do
        local item = moved[index]
        if not os.rename(item.destination, item.source) then rollbackFailed = true end
      end
      if not rollbackFailed then os.remove(TRANSACTION_FILE) end
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
        if not os.rename(item.destination, item.source) then rollbackFailed = true end
      end
      if not rollbackFailed then os.remove(TRANSACTION_FILE) end
      setStatus("delete", rollbackFailed
        and "A restored preset could not be checked, and some files could not be returned to Trash. The mod will try to recover them at the next startup."
        or "Folder restore verification failed; moved files were returned to Trash.", true)
      return
    end
    verified.fingerprint = fileFingerprint(plan.destination, MAX_PRESET_BYTES)
    plan.preset = verified
    table.insert(moved, plan)
  end

  local newPresets, newFolders = cloneMap(state.library.presets), cloneMap(state.library.folders)
  local newTrash, newGroups = cloneMap(state.trash.items), cloneMap(state.trash.groups)
  local newManualFolders = cloneMap(state.library.manualFolders)
  local newIgnored = cloneMap(state.library.ignoredPhysicalFolders)
  for folder in pairs(group.folders or {}) do addFolderAncestors(newFolders, folder) end
  for folder in pairs(group.manualFolders or {}) do
    newManualFolders[folder] = true
    newIgnored[folder] = nil
  end
  addFolderAncestors(newFolders, group.root)
  for _, plan in ipairs(plans) do
    plan.preset.storage = plan.storage
    newPresets[plan.name] = plan.preset
    newTrash[plan.filename] = nil
    addFolderAncestors(newFolders, parentFolder(plan.name))
  end
  newGroups[groupId] = nil
  local catalogsSaved = writeCatalog(newPresets, newFolders, newManualFolders,
      newIgnored) and writeTrashCatalog(newTrash, newGroups)
  local transactionCompleted = #plans == 0 or
    (catalogsSaved and completeTransaction("restore", plans))
  if #plans == 0 then transactionCompleted = catalogsSaved end
  if not transactionCompleted then
    local rollbackFailed = false
    for index = #moved, 1, -1 do
      local plan = moved[index]
      if not os.rename(plan.destination, plan.source) then rollbackFailed = true end
    end
    writeCatalog(state.library.presets, state.library.folders, state.library.manualFolders,
      state.library.ignoredPhysicalFolders)
    writeTrashCatalog(state.trash.items, state.trash.groups)
    if not rollbackFailed then os.remove(TRANSACTION_FILE) end
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
  invalidatePresetAndTrashCaches()
  resetLoadState()
  local inventorySaved = writeInventory(newPresets, newFolders)
  setStatus("delete", ("Restored folder \"%s\" with %d preset%s, including empty folders inside it.")
    :format(group.root, #plans, #plans == 1 and "" or "s") ..
    (inventorySaved and "" or " The preset file list could not be updated."), false,
    inventorySaved and "success" or "warning")
end

emptyTrash = function()
  local count = 0
  for _ in pairs(state.trash.items) do count = count + 1 end
  local groupCount = 0
  for _ in pairs(state.trash.groups) do groupCount = groupCount + 1 end
  local bundleCount = 0
  for _ in pairs(state.trash.bundles) do bundleCount = bundleCount + 1 end
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
    if os.remove(TRASH_DIR .. "/" .. filename) then
      state.trash.items[filename] = nil
    else
      failed = failed + 1
      presetFailed = presetFailed + 1
    end
  end
  for filename in pairs(state.trash.bundles) do
    if os.remove(TRASH_DIR .. "/" .. filename) then
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
  local names = {}
  for _, name in ipairs(state.cache.presetNames) do
    if isInFolderTree(parentFolder(name), folder) then table.insert(names, name) end
  end
  local nestedFolderCount = 0
  for candidate in pairs(state.library.folders) do
    if candidate ~= folder and isInFolderTree(candidate, folder) then
      nestedFolderCount = nestedFolderCount + 1
    end
  end
  state.trash.cachedBulkFolder = folder
  state.trash.cachedBulkFolderNames = names
  state.trash.cachedBulkNestedFolderCount = nestedFolderCount
  return names
end

selectedBulkPresetNames = function()
  if not state.trash.bulkSelectionDirty then return state.trash.cachedBulkSelectedNames end
  local names = {}
  for name in pairs(state.trash.bulkSelected) do
    if state.library.presets[name] then table.insert(names, name) end
  end
  table.sort(names, function(a, b) return a:lower() < b:lower() end)
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

local function moveBulkPresetsToTrash(names, folder)
  local physicalFolderWasImported = folder and state.library.manualFolders[folder] == true
  local reserved, plans = {}, {}
  for _, name in ipairs(names) do
    local preset = state.library.presets[name]
    local trashFilename = uniqueTrashFilename(name, reserved)
    if not preset or not trashFilename then
      setStatus("bulk", "The mod could not create a safe file name in Trash.", true)
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
    setStatus("bulk", "The recovery record for moving these items to Trash could not be created.", true)
    return false
  end

  local moved = {}
  for _, plan in ipairs(plans) do
    local movedFile, moveError = os.rename(plan.source, plan.destination)
    if not movedFile then
      local rollbackFailed = false
      for index = #moved, 1, -1 do
        local item = moved[index]
        if not os.rename(item.destination, item.source) then rollbackFailed = true end
      end
      if rollbackFailed then
        refreshPresets("bulk-recovery")
        refreshTrash()
      else
        os.remove(TRANSACTION_FILE)
      end
      setStatus("bulk", rollbackFailed
        and "Bulk Trash failed, and at least one moved preset could not be restored. Refresh completed; review Trash."
        or ("Bulk Trash stopped at \"%s\": %s"):format(plan.name, tostring(moveError)), true)
      return false
    end
    table.insert(moved, plan)
  end

  local newPresets = cloneMap(state.library.presets)
  local newTrash = cloneMap(state.trash.items)
  local newTrashGroups = cloneMap(state.trash.groups)
  local newFolders = cloneMap(state.library.folders)
  local newManualFolders = cloneMap(state.library.manualFolders)
  local newIgnored = cloneMap(state.library.ignoredPhysicalFolders)
  local nestedFolderCount = 0
  local groupId = folder and plans[1].trashFilename or nil
  if groupId then
    newTrashGroups[groupId] = { root = folder, folders = {}, manualFolders = {} }
  end
  if folder then
    for candidate in pairs(state.library.folders) do
      if isInFolderTree(candidate, folder) then
        newTrashGroups[groupId].folders[candidate] = true
        if state.library.manualFolders[candidate] then
          newTrashGroups[groupId].manualFolders[candidate] = true
        end
        if candidate ~= folder then nestedFolderCount = nestedFolderCount + 1 end
      end
    end
  end
  for _, plan in ipairs(plans) do
    newPresets[plan.name] = nil
    newTrash[plan.trashFilename] = {
      original = plan.name, preset = plan.preset, group = groupId,
    }
  end
  if folder then
    newFolders, newManualFolders = {}, {}
    for candidate in pairs(state.library.folders) do
      if not isInFolderTree(candidate, folder) then
        newFolders[candidate] = true
        if state.library.manualFolders[candidate] then newManualFolders[candidate] = true end
      elseif state.library.manualFolders[candidate] then
        newIgnored[candidate] = true
      end
    end
  end

  local catalogsSaved = writeCatalog(newPresets, newFolders, newManualFolders, newIgnored)
    and writeTrashCatalog(newTrash, newTrashGroups)
  local transactionCompleted = catalogsSaved and completeTransaction("trash", plans)
  if not transactionCompleted then
    local rollbackFailed = false
    for index = #moved, 1, -1 do
      local plan = moved[index]
      if not os.rename(plan.destination, plan.source) then rollbackFailed = true end
    end
    if rollbackFailed then
      refreshPresets("bulk-recovery")
      refreshTrash()
    else
      writeCatalog(state.library.presets, state.library.folders, state.library.manualFolders,
        state.library.ignoredPhysicalFolders)
      writeTrashCatalog(state.trash.items, state.trash.groups)
      os.remove(TRANSACTION_FILE)
    end
    setStatus("bulk", rollbackFailed
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
  setStatus("bulk", (folder
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
  if #names == 0 then
    setStatus("bulk", folder
      and "The selected folder contains no presets. Use Remove Folder, Keep Presets."
      or "Select at least one preset for the bulk action.", true)
    return
  end
  local fingerprint, fingerprintError = bulkTrashFingerprint(names, folder)
  if not fingerprint then setStatus("bulk", fingerprintError, true); return end
  local action = folder and ("folder:" .. folder) or "presets"
  if state.trash.pendingBulkAction ~= action
      or state.trash.pendingBulkFingerprint ~= fingerprint then
    state.trash.pendingBulkAction = action
    state.trash.pendingBulkFingerprint = fingerprint
    setStatus("bulk", folder
      and ("Move folder \"%s\" and %d preset%s to Trash? Select Confirm Move Folder & Presets to Trash.")
        :format(folder, #names, #names == 1 and "" or "s")
      or ("Move %d selected preset%s to Trash? Select Confirm Bulk Trash.")
        :format(#names, #names == 1 and "" or "s"))
    return
  end
  moveBulkPresetsToTrash(names, folder)
end

end

return _ENV
