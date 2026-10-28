local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime
local codecs = require("modules/domain/codecs")
local paths = require("modules/domain/paths")
local libraryApplication = require("modules/application/library")
local catalogCodec = require("modules/domain/catalog_codec")

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
    log("[FOLDER LIST] The saved folder list is invalid, so the preset scan stopped.", "error")
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
  local nativeCatalog = verifiedNativeFileCatalog()
  local function scan(relative, depth)
    local path = folderPath(relative)
    local files, listError = nativeCatalog
      and nativeCatalogDirectoryEntries(nativeCatalog, relative, depth)
      or safeDirectoryEntries(path, depth)
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
            local nativeFile = nativeCatalog and nativeCatalog.fileByRelative
              and nativeCatalog.fileByRelative[childRelative:lower()]
            preset.fingerprint = nativeFile and nativeFile.fingerprint
              or fileFingerprint(path .. "/" .. filename, MAX_PRESET_BYTES)
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
    log(("[FILES] The preset scan did not finish. The previous complete preset and file lists were kept (reason=%s).")
      :format(tostring(scanReason or "unspecified")), "error")
    return currentPresets, false
  end

  local presets, folders, manualFolders, reconcileError, detail = libraryApplication.reconcile(
    scannedPresets, catalogFolders, assignments, physicalFolders, ignoredPhysicalFolders,
    previousPresets, scanReason, scannedEntryCount, AUTO_LOAD_LIMITS.maximumScannedEntries)
  if reconcileError == "identity" then
    log(("[CATALOG] Could not assign a unique display name for storage='%s'.")
      :format(detail), "error")
    return currentPresets, false
  elseif reconcileError == "entries" then
    log(("[FILES] Startup stopped after %d saved options because the library exceeds the safety limit.")
      :format(detail), "error")
    return currentPresets, false
  end

  if not writeCatalog(presets, folders, manualFolders, ignoredPhysicalFolders) then
    log("[FOLDER LIST] The saved folder list could not be updated, so the previous complete preset list was kept.", "error")
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
  return paths.parentFolder(name)
end

function folderDepth(name)
  return paths.folderDepth(name)
end

function folderAncestorsExpanded(name, expandedFolders)
  return paths.folderAncestorsExpanded(name, expandedFolders)
end

function presetPath(name)
  return paths.presetPath(name, state.library.presets, PRESET_DIR)
end

function folderPath(name)
  return paths.folderPath(name, PRESET_DIR)
end

function catalogEncode(value)
  return codecs.catalogEncode(value)
end

function catalogDecode(value)
  return codecs.catalogDecode(value)
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
    local kind, first, second, valid = catalogCodec.decodeCatalogLine(line)
    if kind == "P" then
      assignments[first] = second
    elseif kind == "F" then
      folders[first] = true
    elseif kind == "X" then
      ignored[first] = true
    elseif not valid then
      file:close()
      log(("[FOLDER LIST] Line %d in the saved folder list is invalid."):format(lineCount), "error")
      return {}, {}, {}, false
    end
  end
  file:close()
  return assignments, folders, ignored, true
end

function writeCatalog(presets, folders, manualFolders, ignoredPhysicalFolders)
  local lines, encodeError = catalogCodec.encodeCatalog(presets, folders, manualFolders,
    ignoredPhysicalFolders, MAX_CATALOG_LINES, MAX_CATALOG_BYTES)
  if encodeError == "lines" then
    log("[FOLDER LIST] The folder list has more entries than the safety limit.", "error")
    return false
  elseif encodeError == "bytes" then
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
    log("[FOLDER LIST] The saved folder list already matches the library. No file was changed.", "info")
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
  local decodedPresets, decodedFolders, valid, decodeError = catalogCodec.decodeInventory(
    contents, MAX_CATALOG_LINES, MAX_PRESET_ENTRIES)
  if decodeError == "lines" then
    log("[INVENTORY] The preset file list has too many lines; it was not used as the startup comparison.", "warn")
  elseif decodeError == "preset" then
    log("[INVENTORY] The preset file list contains an invalid preset record; it was not used as the startup comparison.", "warn")
  elseif decodeError == "line" then
    log("[INVENTORY] The preset file list contains an invalid line; it was not used as the startup comparison.", "warn")
  end
  return decodedPresets, decodedFolders, valid
end

function writeInventory(presets, folders)
  local lines = catalogCodec.encodeInventory(presets, folders)
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
