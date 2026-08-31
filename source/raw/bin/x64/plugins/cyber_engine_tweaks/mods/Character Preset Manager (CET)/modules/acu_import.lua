local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

local function decodeImportField(value)
  return (tostring(value or ""):gsub("%%(%x%x)", function(hexadecimal)
    return string.char(tonumber(hexadecimal, 16))
  end))
end

local function readImportResults()
  local contents = readBoundedFile(ACU_IMPORT_RESULTS_FILE, MAX_PRESET_BYTES)
  if not contents then return nil end
  local generation, imported, skipped = nil, 0, 0
  local files = {}
  for line in contents:gmatch("[^\r\n]+") do
    local kind, first, second = line:match("^([^\t]+)\t([^\t]*)\t?(.*)$")
    if kind == "generation" then
      generation = first
    elseif kind == "summary" then
      imported = tonumber(first) or 0
      skipped = tonumber(second) or 0
    elseif kind == "file" then
      local relative = decodeImportField(first)
      if relative:sub(1, 12) == "ACU Presets/"
          and relative:lower():sub(-7) == ".preset"
          and not relative:find("[%c<>:\"|%?%*]") then
        local storage = relative:sub(1, -8)
        if validRelativePath(storage) then files[#files + 1] = storage end
      end
    end
  end
  if not generation or imported ~= #files then return nil end
  return { generation = generation, files = files, skipped = skipped }
end

local function uniqueImportedName(storage)
  local folder = parentFolder(storage)
  local preferred = joinFolder(folder, baseName(storage):sub(1, 64))
  local lowered = preferred:lower()
  for name, preset in pairs(state.library.presets) do
    if preset.storage == storage then return name end
  end
  for name in pairs(state.library.presets) do
    if name:lower() == lowered then
      local leaf = baseName(preferred)
      for index = 2, 9999 do
        local suffix = (" %d"):format(index)
        local candidate = joinFolder(folder, leaf:sub(1, 64 - #suffix) .. suffix)
        local available = true
        for existingName in pairs(state.library.presets) do
          if existingName:lower() == candidate:lower() then
            available = false
            break
          end
        end
        if available then return candidate end
      end
      return nil
    end
  end
  return preferred
end

local function addPhysicalFolders(storage)
  local current = parentFolder(storage)
  while current ~= "" do
    state.library.folders[current] = true
    state.library.manualFolders[current] = true
    state.library.ignoredPhysicalFolders[current] = nil
    current = parentFolder(current)
  end
end

local function importStorage(storage)
  local path = PRESET_DIR .. "/" .. storage .. ".preset"
  local preset = readPresetFile(path, true)
  if not preset then
    log(("[ACU IMPORT] Skipped an unreadable or incompatible preset: '%s'.")
      :format(path), "warn")
    return false
  end
  preset.storage = storage
  preset.fingerprint = fileFingerprint(path, MAX_PRESET_BYTES)
  if not preset.fingerprint then return false end
  local logicalName = uniqueImportedName(storage)
  if not logicalName then return false end
  state.library.presets[logicalName] = preset
  addFolderAncestors(state.library.folders, parentFolder(logicalName))
  addPhysicalFolders(storage)
  log(("[ACU IMPORT] Added or updated '%s'."):format(logicalName), "info")
  return true
end

local function finishImportQueue()
  local acu = state.acuImport
  local saved = true
  if acu.imported > 0 then
    saved = writeCatalog(state.library.presets, state.library.folders,
      state.library.manualFolders, state.library.ignoredPhysicalFolders)
      and writeInventory(state.library.presets, state.library.folders)
    invalidateViewCache()
    resetLoadState()
  end
  local message
  if acu.imported > 0 then
    message = ("ACU import finished: %d added or updated, %d skipped.")
      :format(acu.imported, acu.rejected + acu.skipped)
  elseif acu.requested then
    message = acu.rejected + acu.skipped > 0
      and ("ACU import found no compatible presets; %d skipped.")
        :format(acu.rejected + acu.skipped)
      or "Refresh finished. No new or updated ACU presets were found."
  end
  if message then setStatus("load", message, not saved) end
  acu.queue = {}
  acu.queueIndex = 1
  acu.imported = 0
  acu.rejected = 0
  acu.skipped = 0
  acu.requested = false
end

requestAcuImport = function(source)
  local acu = state.acuImport
  acu.requestSequence = acu.requestSequence + 1
  local token = table.concat({ tostring(os.time()), tostring(acu.requestSequence),
    tostring(source or "CET") }, "\t") .. "\n"
  local wrote = atomicReplace(ACU_IMPORT_REQUEST_FILE, function(temporary)
    return writeFileSafely(temporary, "wb", function(file)
      return file:write(token) ~= nil and file:flush() ~= nil
    end)
  end, "ACU import request")
  if wrote then
    acu.requested = true
    log("[ACU IMPORT] Refresh requested from " .. tostring(source or "CET") .. ".", "info")
  end
  return wrote
end

initializeAcuImport = function()
  local results = readImportResults()
  state.acuImport.generation = results and results.generation or nil
  state.acuImport.pollTimer = 0
end

updateAcuImport = function(elapsed)
  local acu = state.acuImport
  if acu.queueIndex <= #acu.queue then
    if state.load.auto or state.load.needsContinue or state.load.pendingChange then
      return
    end
    local finalIndex = math.min(#acu.queue,
      acu.queueIndex + ACU_IMPORT_FILES_PER_FRAME - 1)
    local changed = false
    for index = acu.queueIndex, finalIndex do
      if importStorage(acu.queue[index]) then
        acu.imported = acu.imported + 1
        changed = true
      else
        acu.rejected = acu.rejected + 1
      end
    end
    acu.queueIndex = finalIndex + 1
    if changed then invalidateViewCache() end
    if acu.queueIndex > #acu.queue then finishImportQueue() end
    return
  end
  acu.pollTimer = acu.pollTimer + (tonumber(elapsed) or 0)
  if acu.pollTimer < ACU_IMPORT_POLL_SECONDS then return end
  acu.pollTimer = 0
  local results = readImportResults()
  if not results or results.generation == acu.generation then return end
  acu.generation = results.generation
  acu.queue = results.files
  acu.queueIndex = 1
  acu.imported = 0
  acu.rejected = 0
  acu.skipped = results.skipped
  if #acu.queue == 0 then finishImportQueue() end
end

return _ENV
