local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

function remapFolderTreePath(path, source, destination)
  if path == source then return destination end
  if path:sub(1, #source + 1) == source .. "/" then
    return destination .. path:sub(#source + 1)
  end
  return path
end

local function restoreLibraryFolderChanges(changes)
  local restored = true
  for index = #changes, 1, -1 do
    if not state.restorePresetLibraryFolder(changes[index]) then restored = false end
  end
  if not restored then
    log("[FOLDER LIST] Some preset folder details could not be returned to their previous values.", "error")
  end
  return restored
end

local function syncLibraryFolders(presets)
  local currentNames = {}
  for name, preset in pairs(state.library.presets) do currentNames[preset] = name end
  local changes = {}
  for name, preset in pairs(presets or {}) do
    local previousName = currentNames[preset]
    local desiredFolder = parentFolder(name)
    local folderChanged = previousName
      and parentFolder(previousName) ~= desiredFolder
    local savedFolderChanged = preset.libraryFolder ~= nil
      and preset.libraryFolder ~= desiredFolder
    if not previousName or folderChanged or savedFolderChanged then
      local updated, change = state.updatePresetLibraryFolder(preset, name)
      if not updated then
        restoreLibraryFolderChanges(changes)
        return nil
      end
      if change then table.insert(changes, change) end
    end
  end
  return changes
end

function persistVirtualState(presets, folders, manualFolders, ignoredPhysicalFolders)
  local folderChanges = syncLibraryFolders(presets)
  if not folderChanges then return false end
  if not writeCatalog(presets, folders, manualFolders, ignoredPhysicalFolders) then
    restoreLibraryFolderChanges(folderChanges)
    return false
  end
  writeInventory(presets, folders)
  return true
end

function createFolder()
  clearStatus("folder")
  helpers.auditSection("CREATE FOLDER")
  local leaf, nameError = validatedFolderName(state.library.folderName)
  if not leaf then setStatus("folder", nameError, true); return end
  local name = joinFolder(state.library.selectedFolder, leaf)
  local existing = findExistingFolderName(name)
  if existing then
    setStatus("folder", ("A folder named \"%s\" already exists."):format(existing), true); return
  end
  state.library.folders[name] = true
  state.library.manualFolders[name] = nil
  if not persistVirtualState(state.library.presets, state.library.folders, state.library.manualFolders,
      state.library.ignoredPhysicalFolders) then
    state.library.folders[name] = nil
    setStatus("folder", "The folder could not be saved.", true); return
  end
  state.library.selectedFolder = name
  invalidateViewCache()
  state.library.folderName = ""
  cancelConfirmations()
  setStatus("folder", "Created folder \"" .. name .. "\".", false, "success")
  log(("[FOLDER] Created virtual folder '%s'."):format(name), "complete")
end

function renameFolder()
  clearStatus("folder")
  helpers.auditSection("RENAME FOLDER")
  local old = state.library.selectedFolder
  if old == "" or not state.library.folders[old] then
    setStatus("folder", "Select a folder to rename.", true); return
  end
  local newLeaf, nameError = validatedFolderName(state.library.folderRenameName)
  if not newLeaf then setStatus("folder", nameError, true); return end
  local destination = joinFolder(parentFolder(old), newLeaf)
  if destination == old then
    setStatus("folder", "The folder already has this name."); return
  end
  if destination:lower() == old:lower() then
    setStatus("folder", "Folder names cannot differ only by capitalization.", true); return
  end
  local existing = findExistingFolderName(destination, old)
  if existing then
    setStatus("folder", ("A folder named \"%s\" already exists."):format(existing), true); return
  end

  local newPresets, newFolders = {}, {}
  local newManualFolders = {}
  local newIgnored = cloneMap(state.library.ignoredPhysicalFolders)
  local usedPresetNames = {}
  for name, preset in pairs(state.library.presets) do
    local mapped = isInFolderTree(parentFolder(name), old)
      and remapFolderTreePath(name, old, destination) or name
    if usedPresetNames[mapped:lower()] then
      setStatus("folder", "The rename would create duplicate preset names.", true); return
    end
    usedPresetNames[mapped:lower()] = true
    newPresets[mapped] = preset
  end
  local usedFolders = {}
  for folder in pairs(state.library.folders) do
    local mapped = remapFolderTreePath(folder, old, destination)
    if usedFolders[mapped:lower()] then
      setStatus("folder", "The rename would create duplicate folders.", true); return
    end
    usedFolders[mapped:lower()] = true
    newFolders[mapped] = true
    if mapped == folder and state.library.manualFolders[folder] then
      newManualFolders[mapped] = true
    elseif mapped ~= folder and state.library.manualFolders[folder] then
      newIgnored[folder] = true
    end
  end
  if not persistVirtualState(newPresets, newFolders, newManualFolders, newIgnored) then
    setStatus("folder",
      "The folder could not be renamed because the folder list could not be saved.", true); return
  end
  local selectedPreset = state.library.selected
  if selectedPreset and isInFolderTree(parentFolder(selectedPreset), old) then
    selectedPreset = remapFolderTreePath(selectedPreset, old, destination)
  end
  state.library.presets = newPresets
  state.library.folders = newFolders
  state.library.manualFolders = newManualFolders
  state.library.ignoredPhysicalFolders = newIgnored
  invalidateViewCache()
  state.library.selectedFolder = destination
  state.library.selected = selectedPreset
  state.library.folderRenameName = ""
  cancelConfirmations()
  resetLoadState()
  setStatus("folder", ("Renamed folder \"%s\" to \"%s\"."):format(old, destination),
    false, "success")
  log(("[FOLDER] Virtual rename completed: '%s' -> '%s'."):format(old, destination), "complete")
end

function duplicateFolder()
  clearStatus("folder")
  helpers.auditSection("DUPLICATE FOLDER")
  local source = state.library.selectedFolder
  if source == "" or not state.library.folders[source] then
    setStatus("folder", "Select a folder to duplicate.", true); return
  end
  local destination = uniqueFolderCopyName(source)
  if not destination then
    setStatus("folder", "Could not find an available name for the duplicate folder.", true); return
  end
  local newPresets = cloneMap(state.library.presets)
  local newFolders = cloneMap(state.library.folders)
  local newManualFolders = cloneMap(state.library.manualFolders)
  local reservedStorage = storageFilenamesInUse()
  if not reservedStorage then
    setStatus("folder", "Storage filenames could not be checked safely.", true); return
  end
  local createdFiles = {}
  for folder in pairs(state.library.folders) do
    if isInFolderTree(folder, source) then
      local mapped = remapFolderTreePath(folder, source, destination)
      newFolders[mapped] = true
      newManualFolders[mapped] = nil
    end
  end
  newFolders[destination] = true
  for name, preset in pairs(state.library.presets) do
    if isInFolderTree(parentFolder(name), source) then
      preset = hydrateNamedPreset(name)
      if not preset then
        setStatus("folder", cleanupFailureMessage(createdFiles,
          "Folder duplication stopped because a source preset could not be read.",
          "A source preset could not be read, and some partial files could not be removed."), true); return
      end
      local mapped = remapFolderTreePath(name, source, destination)
      if findPresetCollision(mapped) or newPresets[mapped] then
        setStatus("folder", cleanupFailureMessage(createdFiles,
          "The copied folder would contain duplicate preset names.",
          "Folder duplication found duplicate names, and some partial files could not be removed."), true); return
      end
      local storage = uniqueStorageName(baseName(mapped), reservedStorage)
      if not storage then
        setStatus("folder", cleanupFailureMessage(createdFiles,
          "The mod could not create a safe file name for the copied preset.",
          "Storage allocation failed, and some partial files could not be removed."), true); return
      end
      local path = PRESET_DIR .. "/" .. storage .. ".preset"
      if not copyFile(presetPath(name), path) then
        table.insert(createdFiles, path)
        setStatus("folder", cleanupFailureMessage(createdFiles,
          "Folder duplication failed; partial preset copies were removed.",
          "Folder duplication failed, and some partial files could not be removed."), true); return
      end
      local copy = readVerifiedPresetCopy(preset, path)
      if not copy then
        table.insert(createdFiles, path)
        setStatus("folder", cleanupFailureMessage(createdFiles,
          "Folder duplication verification failed; partial copies were removed.",
          "Folder duplication verification failed, and some partial files could not be removed."), true); return
      end
      copy.storage = storage
      newPresets[mapped] = copy
      table.insert(createdFiles, path)
    end
  end
  if not persistVirtualState(newPresets, newFolders, newManualFolders,
      state.library.ignoredPhysicalFolders) then
    setStatus("folder", cleanupFailureMessage(createdFiles,
      "The folder copy was removed because the folder list could not be saved.",
      "The folder list could not be saved, and some copied files could not be removed."), true); return
  end
  state.library.presets = newPresets
  state.library.folders = newFolders
  state.library.manualFolders = newManualFolders
  invalidateViewCache()
  state.library.selectedFolder = destination
  cancelConfirmations()
  setStatus("folder", ("Copied folder \"%s\" as \"%s\"."):format(source, destination),
    false, "success")
  log(("[FOLDER] Virtual duplicate completed: source='%s' destination='%s' presets=%d.")
    :format(source, destination, #createdFiles), "complete")
end

function removeVirtualFolder()
  clearStatus("folder")
  helpers.auditSection("REMOVE VIRTUAL FOLDER")
  local folder = state.library.selectedFolder
  if folder == "" or not state.library.folders[folder] then
    setStatus("folder", "Select a folder to remove.", true); return
  end
  local destinationParent = parentFolder(folder)
  local wasManualFolder = state.library.manualFolders[folder] == true
  if state.library.pendingRemoveFolder ~= folder then
    state.library.pendingRemoveFolder = folder
    setStatus("folder",
      ("Remove folder \"%s\" and keep its presets? Its presets and nested folders will move to %s. No preset files will be deleted. Select Confirm Remove Folder, Keep Presets.")
        :format(folder, destinationParent == "" and "All Presets" or ("\"" .. destinationParent .. "\"")))
    return
  end
  state.library.pendingRemoveFolder = nil
  local newPresets, newFolders = {}, {}
  local newManualFolders = {}
  local newIgnored = cloneMap(state.library.ignoredPhysicalFolders)
  local usedPresets, usedFolders = {}, {}
  for name, preset in pairs(state.library.presets) do
    local mapped = name
    if isInFolderTree(parentFolder(name), folder) then
      mapped = joinFolder(destinationParent, name:sub(#folder + 2))
    end
    if usedPresets[mapped:lower()] then
      setStatus("folder", "The folder cannot be removed because preset names would collide.", true); return
    end
    usedPresets[mapped:lower()] = true
    newPresets[mapped] = preset
  end
  for candidate in pairs(state.library.folders) do
    if candidate ~= folder then
      local mapped = candidate
      if isInFolderTree(candidate, folder) then
        mapped = joinFolder(destinationParent, candidate:sub(#folder + 2))
      end
      if usedFolders[mapped:lower()] then
        setStatus("folder", "The folder cannot be removed because folder names would collide.", true); return
      end
      usedFolders[mapped:lower()] = true
      newFolders[mapped] = true
      if mapped == candidate and state.library.manualFolders[candidate] then
        newManualFolders[mapped] = true
      elseif mapped ~= candidate and state.library.manualFolders[candidate] then
        newIgnored[candidate] = true
      end
    elseif state.library.manualFolders[candidate] then
      newIgnored[candidate] = true
    end
  end
  local relocationPlans = {}
  if wasManualFolder then
    local reservedStorage = storageFilenamesInUse()
    if not reservedStorage then
      setStatus("folder", "The imported folder could not be inspected safely.", true); return
    end
    for logicalName, preset in pairs(state.library.presets) do
      local storageFolder = parentFolder(preset.storage or "")
      if storageFolder ~= "" and isInFolderTree(storageFolder, folder) then
        local destinationStorage = uniqueStorageName(baseName(preset.storage), reservedStorage)
        if not destinationStorage then
          setStatus("folder",
            "The mod could not create a safe destination file name for an imported preset.", true); return
        end
        table.insert(relocationPlans, {
          storage = preset.storage,
          destinationStorage = destinationStorage,
          name = logicalName,
          preset = preset,
        })
      end
    end
  end
  table.sort(relocationPlans, function(a, b)
    return a.storage:lower() < b.storage:lower()
  end)
  if #relocationPlans > 0
      and not writeTransaction("prepared", "rename", relocationPlans) then
    setStatus("folder",
      "The recovery record for removing this imported folder could not be created.", true); return
  end
  local movedPlans = {}
  for _, plan in ipairs(relocationPlans) do
    local sourcePath = PRESET_DIR .. "/" .. plan.storage .. ".preset"
    local destinationPath = PRESET_DIR .. "/" .. plan.destinationStorage .. ".preset"
    if not fileExists(sourcePath) or fileExists(destinationPath)
        or not os.rename(sourcePath, destinationPath) then
      local rolledBack = true
      for index = #movedPlans, 1, -1 do
        local moved = movedPlans[index]
        local movedPath = PRESET_DIR .. "/" .. moved.destinationStorage .. ".preset"
        local originalPath = PRESET_DIR .. "/" .. moved.storage .. ".preset"
        if not os.rename(movedPath, originalPath) then rolledBack = false end
      end
      if rolledBack then os.remove(TRANSACTION_FILE) end
      setStatus("folder", rolledBack
        and "The imported folder was left unchanged because a preset file could not be moved."
        or "A preset could not be moved, and some earlier moves could not be undone. The mod will try to recover them at the next startup.", true)
      return
    end
    table.insert(movedPlans, plan)
  end
  for _, plan in ipairs(relocationPlans) do
    plan.preset.storage = plan.destinationStorage
  end
  local persisted = persistVirtualState(newPresets, newFolders, newManualFolders, newIgnored)
  local transactionCompleted = persisted and (#relocationPlans == 0
    or completeTransaction("rename", relocationPlans))
  if not transactionCompleted then
    for _, plan in ipairs(relocationPlans) do plan.preset.storage = plan.storage end
    local rolledBack = true
    for index = #relocationPlans, 1, -1 do
      local plan = relocationPlans[index]
      local destinationPath = PRESET_DIR .. "/" .. plan.destinationStorage .. ".preset"
      local sourcePath = PRESET_DIR .. "/" .. plan.storage .. ".preset"
      if fileExists(destinationPath) and not os.rename(destinationPath, sourcePath) then
        rolledBack = false
      end
    end
    persistVirtualState(state.library.presets, state.library.folders, state.library.manualFolders,
      state.library.ignoredPhysicalFolders)
    if rolledBack then os.remove(TRANSACTION_FILE) end
    setStatus("folder", rolledBack
        and "The folder was restored because the folder list or recovery record could not be saved."
        or "The folder removal could not finish or be undone. The mod will try to recover it at the next startup.", true)
    return
  end
  local selectedPreset = state.library.selected
  if selectedPreset and isInFolderTree(parentFolder(selectedPreset), folder) then
    selectedPreset = joinFolder(destinationParent, selectedPreset:sub(#folder + 2))
  end
  state.library.presets, state.library.folders = newPresets, newFolders
  state.library.manualFolders, state.library.ignoredPhysicalFolders = newManualFolders, newIgnored
  state.library.selected, state.library.selectedFolder = selectedPreset, destinationParent
  invalidateViewCache()
  cancelConfirmations()
  resetLoadState()
  local physicalFolderRemoved = false
  if wasManualFolder
      and directoryTreeContainsFiles(folderPath(folder), 0) == false then
    physicalFolderRemoved = removeEmptyDirectoryTree(folderPath(folder), 0)
  end
  setStatus("folder",
    "Removed folder \"" .. folder .. "\", kept all presets, and moved them to " ..
      (destinationParent == "" and "All Presets" or ("\"" .. destinationParent .. "\"")) ..
      (wasManualFolder
        and (physicalFolderRemoved
          and ". Its empty Windows folder was also removed."
          or ". Its Windows folder was kept because it contains other files or could not be removed safely.")
        or "."), false, "success")
end

return _ENV
