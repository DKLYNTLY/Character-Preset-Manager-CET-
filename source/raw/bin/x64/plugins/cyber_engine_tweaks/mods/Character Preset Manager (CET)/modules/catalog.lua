local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

function refreshPresets(scanReason, recoveryAssignments, recoveryFolders,
    recoveryManualFolders)
  state.cache.folderBundleFilesDirty = true
  local currentPresets = state.library.presets or {}
  local currentFolders = state.library.folders or {}
  local previousPresets = currentPresets
  local previousFolders = currentFolders
  local baselineAvailable = state.app.ready
  if scanReason == "startup" then
    previousPresets, previousFolders, baselineAvailable = helpers.readInventory()
    log(("[INVENTORY] Startup baseline available=%s presets=%d folders=%d.")
      :format(tostring(baselineAvailable),
        (function() local count = 0; for _ in pairs(previousPresets) do count = count + 1 end; return count end)(),
        (function() local count = 0; for _ in pairs(previousFolders) do count = count + 1 end; return count end)()), "info")
  end
  local assignments, catalogFolders, ignoredPhysicalFolders, catalogStatus = helpers.readCatalog()
  if catalogStatus == false then
    log("[FOLDER LIST] The preset scan stopped because the saved folder list is invalid.", "error")
    return currentPresets, false
  end
  for storage, logicalName in pairs(recoveryAssignments or {}) do
    assignments[storage] = logicalName
    addFolderAncestors(catalogFolders, parentFolder(logicalName))
  end
  for folder in pairs(recoveryFolders or {}) do
    addFolderAncestors(catalogFolders, folder)
  end
  for folder in pairs(recoveryManualFolders or {}) do
    ignoredPhysicalFolders[folder] = nil
  end
  local scannedPresets = {}
  local physicalFolders = {}
  local scannedPresetCount = 0
  local scannedEntryCount = 0
  local function scan(relative, depth)
    local path = folderPath(relative)
    local files, listError = safeDirectoryEntries(path, depth)
    if not files then
      log(("[FILES] Scan stopped at '%s': %s."):format(path, tostring(listError)), "error")
      return false
    end
    if relative ~= "" then physicalFolders[relative] = true end
    for _, entry in ipairs(files) do
      local filename = entry.name
      local childRelative = joinFolder(relative, filename)
      local name = filename:lower():sub(-7) == ".preset"
        and filename:sub(1, -8) or nil
      if entry.type == "file" and name and name ~= "" then
        local storage = joinFolder(relative, name)
        if scannedPresetCount >= AUTO_LOAD_LIMITS.maximumScannedPresets then
          log(("[FILES] Scan stopped after %d presets because the library exceeds the safety limit.")
            :format(scannedPresetCount), "error")
          return false
        end
        local preset
        if scanReason == "startup" then
          local inventoryName = assignments[storage]
          if not validRelativePath(inventoryName) then inventoryName = storage end
          if type(previousPresets[inventoryName]) == "table"
              and validRelativePath(assignments[storage]) then
            preset = {
              entryCount = 0,
              entryCountKnown = false,
              metadataLoaded = false,
              lazy = true,
            }
          else
            preset = readPresetFile(path .. "/" .. filename, true)
          end
        else
          preset = readPresetFile(path .. "/" .. filename, scanReason ~= "external")
        end
        if preset then
          if scanReason == "external" then
            preset.fingerprint = fileFingerprint(
              path .. "/" .. filename, MAX_PRESET_BYTES)
            if not preset.fingerprint then
              log(("[FILES] Scan stopped because '%s' could not be checked safely.")
                :format(childRelative), "error")
              return false
            end
          end
          scannedPresetCount = scannedPresetCount + 1
          local entryCount = preset.entryCountKnown == true
            and state.presetEntryCount(preset) or 0
          scannedEntryCount = scannedEntryCount + entryCount
          if scannedEntryCount > AUTO_LOAD_LIMITS.maximumScannedEntries then
            log(("[FILES] Scan stopped after %d saved options because the library exceeds the safety limit.")
              :format(scannedEntryCount), "error")
            return false
          end
          preset.storage = storage
          scannedPresets[storage] = preset
        else
          log(("[FILES] Skipped unreadable, unsafe, or empty preset '%s'.")
            :format(childRelative), "warn")
        end
      elseif entry.type == "directory"
          and childRelative ~= ".Character Preset Manager Trash"
          and not scan(childRelative, depth + 1) then
        return false
      end
    end
    return true
  end

  if not scan("", 0) then
    log(("[FILES] The preset scan did not finish. The last good preset and file lists were kept (reason=%s).")
      :format(tostring(scanReason or "unspecified")), "error")
    return currentPresets, false
  end

  local presets = {}
  local folders = {}
  local manualFolders = {}
  local usedLogicalNames = {}
  for folder in pairs(catalogFolders) do addFolderAncestors(folders, folder) end
  local storageNames = {}
  for storage in pairs(scannedPresets) do table.insert(storageNames, storage) end
  table.sort(storageNames, function(a, b) return a:lower() < b:lower() end)
  for _, storage in ipairs(storageNames) do
    local preset = scannedPresets[storage]
    local preferred = assignments[storage]
    if not validRelativePath(preferred) and preset.managedByCpm
        and (preset.libraryFolder == ""
          or validRelativePath(preset.libraryFolder)) then
      local presetName = preset.presetName
      local validated = validatedPresetName(presetName)
      if not presetName or validated ~= presetName then
        presetName = baseName(storage)
      end
      preferred = joinFolder(preset.libraryFolder, presetName)
    end
    if not validRelativePath(preferred) then preferred = storage end
    local logicalName = preferred
    local lowered = logicalName:lower()
    if usedLogicalNames[lowered] then
      local folder = parentFolder(preferred)
      local leaf = baseName(preferred)
      local resolved = false
      for index = 2, 9999 do
        local suffix = (" %d"):format(index)
        local candidate = joinFolder(folder, leaf:sub(1, 64 - #suffix) .. suffix)
        if not usedLogicalNames[candidate:lower()] then
          logicalName = candidate
          lowered = candidate:lower()
          resolved = true
          break
        end
      end
      if not resolved then
        log(("[CATALOG] Could not assign a unique display name for storage='%s'.")
          :format(storage), "error")
        return currentPresets, false
      end
    end
    usedLogicalNames[lowered] = true
    local inventoryPreset = previousPresets[logicalName]
    if scanReason == "startup" and type(inventoryPreset) == "table" then
      preset.entryCount = state.presetEntryCount(inventoryPreset)
      preset.entryCountKnown = inventoryPreset.entryCountKnown
      preset.format = inventoryPreset.format
      preset.modified = inventoryPreset.modified
      preset.fingerprint = inventoryPreset.fingerprint
      local knownEntries = inventoryPreset.entryCountKnown
        and state.presetEntryCount(inventoryPreset) or 0
      scannedEntryCount = scannedEntryCount + knownEntries
      if scannedEntryCount > AUTO_LOAD_LIMITS.maximumScannedEntries then
        log(("[FILES] Startup stopped after %d saved options because the library exceeds the safety limit.")
          :format(scannedEntryCount), "error")
        return currentPresets, false
      end
    end
    preset.storage = storage
    presets[logicalName] = preset
    local logicalFolder = parentFolder(logicalName)
    addFolderAncestors(folders, logicalFolder)
    if logicalName == storage and logicalFolder ~= "" then
      local current = logicalFolder
      while current ~= "" do
        manualFolders[current] = true
        ignoredPhysicalFolders[current] = nil
        current = parentFolder(current)
      end
    end
  end
  for folder in pairs(physicalFolders) do
    if not ignoredPhysicalFolders[folder] then
      addFolderAncestors(folders, folder)
      local current = folder
      while current ~= "" do
        manualFolders[current] = true
        current = parentFolder(current)
      end
    end
  end

  if not writeCatalog(presets, folders, manualFolders, ignoredPhysicalFolders) then
    log("[FOLDER LIST] The last good preset list was kept because the saved folder list could not be updated.", "error")
    return currentPresets, false
  end

  local changeSummary = { added = 0, removed = 0, modified = 0,
    foldersAdded = 0, foldersRemoved = 0 }
  local externalScan = scanReason == "external" or scanReason == "startup"
  if externalScan and baselineAvailable then
    local added, removed, modified = 0, 0, 0
    local foldersAdded, foldersRemoved = 0, 0
    for name, preset in pairs(presets) do
      if not previousPresets[name] then
        added = added + 1
        log(("[EXTERNAL CHANGE] Preset added or moved in: '%s'.")
          :format(PRESET_DIR .. "/" .. preset.storage .. ".preset"), "warn")
      elseif type(previousPresets[name]) == "table"
          and not presetsMatch(previousPresets[name], preset) then
        modified = modified + 1
        log(("[EXTERNAL CHANGE] Preset contents changed: '%s'.")
          :format(PRESET_DIR .. "/" .. preset.storage .. ".preset"), "warn")
      end
    end
    for name in pairs(previousPresets) do
      if not presets[name] then
        removed = removed + 1
        log(("[EXTERNAL CHANGE] Preset removed or moved out: '%s'."):format(name), "warn")
      end
    end
    for name in pairs(folders) do
      if not previousFolders[name] then
        foldersAdded = foldersAdded + 1
        log(("[EXTERNAL CHANGE] Folder added or moved in: '%s'."):format(name), "warn")
      end
    end
    for name in pairs(previousFolders) do
      if not folders[name] then
        foldersRemoved = foldersRemoved + 1
        log(("[EXTERNAL CHANGE] Folder removed or moved out: '%s'."):format(name), "warn")
      end
    end
    local total = added + removed + modified + foldersAdded + foldersRemoved
    changeSummary.added = added
    changeSummary.removed = removed
    changeSummary.modified = modified
    changeSummary.foldersAdded = foldersAdded
    changeSummary.foldersRemoved = foldersRemoved
    if total > 0 then
      log(("[EXTERNAL CHANGE WARNING] Rescan found %d change%s: presets added=%d removed=%d modified=%d; folders added=%d removed=%d. Changes made outside CET were accepted into the current list.")
        :format(total, total == 1 and "" or "s", added, removed, modified,
          foldersAdded, foldersRemoved), "warn")
    else
      log("[EXTERNAL CHANGE] Rescan found no changes made outside CET.", "info")
    end
  end

  state.library.presets = presets
  state.library.folders = folders
  state.library.manualFolders = manualFolders
  state.library.ignoredPhysicalFolders = ignoredPhysicalFolders
  invalidateViewCache()
  resetLoadState()
  for folder in pairs(state.library.expandedLoadFolders) do
    if not folders[folder] then state.library.expandedLoadFolders[folder] = nil end
  end
  writeInventory(presets, folders)
  if state.library.selectedFolder ~= "" and not folders[state.library.selectedFolder] then
    state.library.selectedFolder = ""
    cancelConfirmations()
  end
  if state.library.selected and not presets[state.library.selected] then
    state.library.selected = nil
    resetLoadState()
    cancelConfirmations()
  end
  for name in pairs(state.trash.bulkSelected) do
    if not presets[name] then state.trash.bulkSelected[name] = nil end
  end
  local count = 0
  for _ in pairs(presets) do count = count + 1 end
  log(("[FILES] Scanned '%s': %d readable preset file%s found (reason=%s).")
    :format(PRESET_DIR, count, count == 1 and "" or "s", tostring(scanReason or "unspecified")), "info")
  return presets, true, changeSummary
end

function parentFolder(name)
  return name:match("^(.*)/[^/]+$") or ""
end

function folderDepth(name)
  local depth = 0
  for _ in tostring(name or ""):gmatch("/") do depth = depth + 1 end
  return depth
end

function folderAncestorsExpanded(name, expandedFolders)
  local current = parentFolder(tostring(name or ""))
  while current ~= "" do
    if not (expandedFolders or {})[current] then return false end
    current = parentFolder(current)
  end
  return true
end

function presetPath(name)
  local preset = state.library.presets[name]
  local storage = preset and preset.storage or name
  return PRESET_DIR .. "/" .. storage .. ".preset"
end

function folderPath(name)
  return name == "" and PRESET_DIR or (PRESET_DIR .. "/" .. name)
end

function catalogEncode(value)
  return (tostring(value or ""):gsub("([^%w%-%._/])", function(character)
    return ("%%%02X"):format(character:byte())
  end))
end

function catalogDecode(value)
  return (tostring(value or ""):gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end))
end

helpers.readCatalog = function()
  local assignments, folders, ignored = {}, {}, {}
  local file = io.open(CATALOG_FILE, "rb")
  if not file then return assignments, folders, ignored, nil end
  local sizeOk, size = pcall(file.seek, file, "end")
  local rewindOk, rewindResult = pcall(file.seek, file, "set", 0)
  if not sizeOk or not size or size > MAX_CATALOG_BYTES
      or not rewindOk or rewindResult == nil then
    file:close()
    log("[FOLDER LIST] The saved folder list cannot be read or is larger than the safety limit.", "error")
    return assignments, folders, ignored, false
  end
  local lineCount = 0
  for line in file:lines() do
    lineCount = lineCount + 1
    if lineCount > MAX_CATALOG_LINES then
      file:close()
      log("[FOLDER LIST] The saved folder list has too many lines.", "error")
      return {}, {}, {}, false
    end
    local kind, first, second = line:match("^([PFX])\t([^\t]+)\t?([^\t]*)$")
    first = catalogDecode(first)
    second = catalogDecode(second)
    if kind == "P" and validRelativePath(first) and validRelativePath(second) then
      assignments[first] = second
    elseif kind == "F" and validRelativePath(first) then
      folders[first] = true
    elseif kind == "X" and validRelativePath(first) then
      ignored[first] = true
    elseif line:match("%S") then
      file:close()
      log(("[FOLDER LIST] Line %d in the saved folder list is invalid."):format(lineCount), "error")
      return {}, {}, {}, false
    end
  end
  file:close()
  return assignments, folders, ignored, true
end

function writeCatalog(presets, folders, manualFolders, ignoredPhysicalFolders)
  local lines = {}
  for logicalName, preset in pairs(presets or {}) do
    if preset.storage and validRelativePath(preset.storage)
        and validRelativePath(logicalName) then
      table.insert(lines, "P\t" .. catalogEncode(preset.storage) .. "\t" ..
        catalogEncode(logicalName))
    end
  end
  for folder in pairs(folders or {}) do
    if not (manualFolders or {})[folder] and validRelativePath(folder) then
      table.insert(lines, "F\t" .. catalogEncode(folder))
    end
  end
  for folder in pairs(ignoredPhysicalFolders or {}) do
    if validRelativePath(folder) then
      table.insert(lines, "X\t" .. catalogEncode(folder))
    end
  end
  table.sort(lines, function(a, b) return a:lower() < b:lower() end)
  if #lines > MAX_CATALOG_LINES then
    log("[FOLDER LIST] The folder list has more entries than the safety limit.", "error")
    return false
  end
  local catalogBytes = 0
  for _, line in ipairs(lines) do catalogBytes = catalogBytes + #line + 1 end
  if catalogBytes > MAX_CATALOG_BYTES then
    log("[FOLDER LIST] The folder list is larger than the safety limit.", "error")
    return false
  end
  local result, changed = writeLinesIfChanged(
    CATALOG_FILE, lines, "folder list", MAX_CATALOG_BYTES)
  log(("[CATALOG] Saved presets=%d folders=%d ignoredPhysicalFolders=%d success=%s.")
    :format(
      (function() local count = 0; for _ in pairs(presets or {}) do count = count + 1 end; return count end)(),
      (function() local count = 0; for _ in pairs(folders or {}) do count = count + 1 end; return count end)(),
      (function() local count = 0; for _ in pairs(ignoredPhysicalFolders or {}) do count = count + 1 end; return count end)(),
      tostring(result)), result and "info" or "error")
  if result and not changed then
    log("[FOLDER LIST] The saved folder list is already current. No file update was needed.", "info")
  end
  return result
end

helpers.readInventory = function()
  local presets, folders = {}, {}
  local contents, readError = readBoundedFile(INVENTORY_FILE, MAX_CATALOG_BYTES)
  if not contents then
    if readError ~= "missing" then
      log("[INVENTORY] The preset file list is unreadable or too large; it was not used as the startup comparison.", "warn")
    end
    return presets, folders, false
  end
  local lineCount = 0
  for line in (contents .. "\n"):gmatch("(.-)\n") do
    if line ~= "" then
      lineCount = lineCount + 1
      if lineCount > MAX_CATALOG_LINES then
        log("[INVENTORY] The preset file list has too many lines; it was not used as the startup comparison.", "warn")
        return {}, {}, false
      end
      local encodedName, count, format, encodedModified, fingerprint =
        line:match("^P2\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]*)\t([^\t]+)$")
      local kind, name = line:match("^([PF]):(.*)$")
      if encodedName then
        name = catalogDecode(encodedName)
        local entryCount = count ~= "-" and tonumber(count) or nil
        local presetFormat = format ~= "-" and tonumber(format) or nil
        if not validRelativePath(name)
            or (count ~= "-" and not entryCount)
            or (format ~= "-" and not presetFormat)
            or (entryCount and (entryCount < 1 or entryCount > MAX_PRESET_ENTRIES))
            or (presetFormat and presetFormat < 1)
            or (fingerprint ~= "-" and not fingerprint:match("^2:%d+:%d+:%d+$")) then
          log("[INVENTORY] The preset file list contains an invalid preset record; it was not used as the startup comparison.", "warn")
          return {}, {}, false
        end
        presets[name] = {
          entryCount = entryCount or 0,
          entryCountKnown = entryCount ~= nil,
          format = presetFormat,
          modified = catalogDecode(encodedModified),
          fingerprint = fingerprint ~= "-" and fingerprint or nil,
          metadataLoaded = false,
          lazy = true,
        }
      elseif kind == "P" and validRelativePath(name) then
        presets[name] = true
      elseif kind == "F" and validRelativePath(name) then
        folders[name] = true
      else
        log("[INVENTORY] The preset file list contains an invalid line; it was not used as the startup comparison.", "warn")
        return {}, {}, false
      end
    end
  end
  return presets, folders, true
end

function writeInventory(presets, folders)
  local lines = {}
  for name, preset in pairs(presets or {}) do
    local count = preset and preset.entryCountKnown == true
      and state.presetEntryCount(preset) or nil
    local format = tonumber(preset and preset.format)
    table.insert(lines, "P2\t" .. catalogEncode(name) .. "\t" ..
      (count and tostring(count) or "-") .. "\t" ..
      (format and tostring(format) or "-") .. "\t" ..
      catalogEncode(preset and preset.modified or "") .. "\t" ..
      tostring(preset and preset.fingerprint or "-"))
  end
  for name in pairs(folders or {}) do table.insert(lines, "F:" .. name) end
  table.sort(lines, function(a, b) return a:lower() < b:lower() end)
  local result, changed = writeLinesIfChanged(
    INVENTORY_FILE, lines, "preset file list", MAX_CATALOG_BYTES)
  log(("[INVENTORY] Saved %d tracked path%s to '%s' success=%s.")
    :format(#lines, #lines == 1 and "" or "s", INVENTORY_FILE, tostring(result)),
    result and "info" or "error")
  if result and not changed then
    log("[INVENTORY] Inventory was already current; write skipped.", "info")
  end
  return result
end

return _ENV
