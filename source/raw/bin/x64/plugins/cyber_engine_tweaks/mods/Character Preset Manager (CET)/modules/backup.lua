local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

do

local function encode(value)
  return (tostring(value or ""):gsub(".", function(character)
    return ("%02X"):format(character:byte())
  end))
end

local function decode(value)
  if type(value) ~= "string" or #value % 2 ~= 0
      or (value ~= "" and not value:match("^%x+$")) then return nil end
  return (value:gsub("(%x%x)", function(pair)
    return string.char(tonumber(pair, 16))
  end))
end

local function writeEncodedFile(output, path)
  local input = io.open(path, "rb")
  if not input then return false, nil end
  local sizeOk, size = pcall(input.seek, input, "end")
  local rewindOk, rewindResult = pcall(input.seek, input, "set", 0)
  if not sizeOk or not size or size > MAX_PRESET_BYTES
      or not rewindOk or rewindResult == nil then
    input:close()
    return false, size
  end
  local bytes = 0
  local wrote, result = pcall(function()
    while true do
      local chunk = input:read(FILE_COPY_CHUNK_SIZE)
      if not chunk then break end
      bytes = bytes + #chunk
      if not output:write(encode(chunk)) then return false end
    end
    return bytes == size
  end)
  local closed, closeResult = pcall(input.close, input)
  return wrote and result == true and closed and closeResult ~= nil, size
end

local function backupFiles()
  local files = {}
  local entries = safeDirectoryEntries(PRESET_DIR, 0)
  if not entries then return files end
  for _, entry in ipairs(entries) do
    if entry.type == "file"
        and entry.name:lower():sub(-#LIBRARY_BACKUP_EXTENSION) == LIBRARY_BACKUP_EXTENSION then
      table.insert(files, PRESET_DIR .. "/" .. entry.name)
    end
  end
  table.sort(files, function(a, b) return a:lower() < b:lower() end)
  return files
end

libraryBackupFiles = function()
  return backupFiles()
end

local function uniqueBackupFilename()
  local stem = "Character Preset Manager Library Backup"
  for index = 1, 999 do
    local suffix = index == 1 and "" or (" Copy %d"):format(index)
    local path = PRESET_DIR .. "/" .. stem .. suffix .. LIBRARY_BACKUP_EXTENSION
    if not fileExists(path) and not fileExists(path .. ".tmp")
        and not fileExists(path .. ".bak") then return path end
  end
  return nil
end

exportLibraryBackup = function()
  helpers.auditSection("EXPORT LIBRARY BACKUP")
  local names = helpers.sortedPresetNames()
  if #names == 0 then
    state.status.backup = "Save at least one preset before exporting a library backup."
    return false
  end
  local filename = uniqueBackupFilename()
  if not filename then
    state.status.backup = "The mod could not create an unused library-backup file name."
    return false
  end
  local config = readBoundedFile(CONFIG_FILE, MAX_CATALOG_BYTES)
  if not config then
    config = "discoveryReminder=" .. tostring(not state.ui.discoveryNoticeIgnored) .. "\n" ..
      "presetSort=" .. (state.library.sortMode == "modified" and "modified" or "name") .. "\n"
  end
  local exportError = nil
  local wrote = atomicReplace(filename, function(temporary)
    return writeFileSafely(temporary, "wb", function(file)
      local totalBytes = 0
      local function writeLine(line)
        totalBytes = totalBytes + #line + 1
        return totalBytes <= MAX_LIBRARY_BACKUP_BYTES and file:write(line .. "\n") ~= nil
      end
      if not writeLine("CPMBACKUP\t1") or not writeLine("CONFIG\t" .. encode(config)) then
        exportError = "The library backup would be larger than the 256 MB limit."
        return false
      end
      for _, folder in ipairs(sortedFolderNames()) do
        if not validRelativePath(folder) or not writeLine("F\t" .. catalogEncode(folder)) then
          exportError = "A folder name is unsafe or the library backup is too large."
          return false
        end
      end
      for _, name in ipairs(names) do
        if not validRelativePath(name) then
          exportError = "A preset name is not safe to include in the library backup."
          return false
        end
        local source = presetPath(name)
        local input = io.open(source, "rb")
        local sizeOk, sourceBytes = input and pcall(input.seek, input, "end")
        if input then input:close() end
        if not input or not sizeOk or not sourceBytes or sourceBytes > MAX_PRESET_BYTES then
          exportError = "This preset could not be read and was not exported: " .. name
          return false
        end
        local prefix = "P\t" .. catalogEncode(name) .. "\t"
        totalBytes = totalBytes + #prefix + sourceBytes * 2 + 1
        if totalBytes > MAX_LIBRARY_BACKUP_BYTES or not file:write(prefix) then
          exportError = "The library backup would be larger than the 256 MB limit."
          return false
        end
        local streamed, streamedBytes = writeEncodedFile(file, source)
        if not streamed or streamedBytes ~= sourceBytes or not file:write("\n") then
          exportError = "This preset could not be read and was not exported: " .. name
          return false
        end
      end
      return file:flush() ~= nil
    end)
  end, "library backup")
  if not wrote then
    state.status.backup = exportError or "The library backup could not be saved."
    return false
  end
  state.backup.selectedFile = filename
  state.status.backup = ("Exported %d preset%s to %s.")
    :format(#names, #names == 1 and "" or "s", filename)
  log(("[LIBRARY BACKUP] Exported presets=%d folders=%d file='%s'.")
    :format(#names, #sortedFolderNames(), filename), "complete")
  return true
end

local function readBackup(path)
  local file = io.open(path, "rb")
  if not file then return nil, "The selected library backup could not be opened." end
  local sizeOk, size = pcall(file.seek, file, "end")
  local rewindOk, rewindResult = pcall(file.seek, file, "set", 0)
  if not sizeOk or not size or size > MAX_LIBRARY_BACKUP_BYTES
      or not rewindOk or rewindResult == nil then
    file:close()
    return nil, "The selected library backup is unreadable or larger than 256 MB."
  end
  local backup = { folders = {}, presets = {}, names = {} }
  local lineNumber = 0
  for line in file:lines() do
    line = line:gsub("\r$", "")
    lineNumber = lineNumber + 1
    if lineNumber == 1 then
      if line ~= "CPMBACKUP\t1" then file:close(); return nil, "The selected file is not a valid library backup." end
    else
      local configValue = line:match("^CONFIG\t(.*)$")
      local folderValue = line:match("^F\t([^\t]+)$")
      local nameValue, contentsValue = line:match("^P\t([^\t]+)\t([%x]+)$")
      if configValue then
        if backup.config ~= nil then file:close(); return nil, "The library backup contains more than one settings file." end
        backup.config = decode(configValue)
      elseif folderValue then
        local folder = catalogDecode(folderValue)
        if not validRelativePath(folder) then file:close(); return nil, "The library backup contains an unsafe folder name." end
        backup.folders[folder] = true
      elseif nameValue then
        local name = catalogDecode(nameValue)
        local contents = decode(contentsValue)
        if not validRelativePath(name) or not contents or #contents > MAX_PRESET_BYTES
            or backup.names[name:lower()] then
          file:close(); return nil, "The library backup contains an invalid or repeated preset."
        end
        backup.names[name:lower()] = true
        table.insert(backup.presets, { name = name, contents = contents })
      elseif line ~= "" then
        file:close(); return nil, ("Line %d in the library backup is invalid."):format(lineNumber)
      end
    end
  end
  local closeOk, closeResult = pcall(file.close, file)
  if not closeOk or closeResult == nil or not backup.config or #backup.presets == 0 then
    return nil, "The library backup is incomplete."
  end
  return backup
end

local function uniqueImportRoot()
  local base = "Imported Library"
  for index = 1, 999 do
    local root = index == 1 and base or (base .. " Copy " .. index)
    if not folderNameExists(root) and not findPresetCollision(root) then return root end
  end
  return nil
end

importLibraryBackup = function()
  helpers.auditSection("IMPORT LIBRARY BACKUP")
  local path = state.backup.selectedFile
  if not path or not fileExists(path) then
    state.status.backup = "Choose an available library-backup file first."
    return false
  end
  local backup, readError = readBackup(path)
  if not backup then state.status.backup = readError; return false end
  local needsRoot = false
  for folder in pairs(backup.folders) do
    if folderNameExists(folder) then needsRoot = true; break end
  end
  if not needsRoot then
    for _, item in ipairs(backup.presets) do
      if findPresetCollision(item.name) then needsRoot = true; break end
    end
  end
  local root = needsRoot and uniqueImportRoot() or ""
  if needsRoot and not root then
    state.status.backup = "The mod could not create a safe folder for colliding backup items."
    return false
  end
  local newPresets = cloneMap(state.library.presets)
  local newFolders = cloneMap(state.library.folders)
  local newManualFolders = cloneMap(state.library.manualFolders)
  local newIgnored = cloneMap(state.library.ignoredPhysicalFolders)
  if root ~= "" then addFolderAncestors(newFolders, root) end
  for folder in pairs(backup.folders) do addFolderAncestors(newFolders, joinFolder(root, folder)) end
  local reservedStorage = storageFilenamesInUse()
  if not reservedStorage then
    state.status.backup = "Existing preset file names could not be checked safely."
    return false
  end
  local createdFiles = {}
  for _, item in ipairs(backup.presets) do
    item.logicalName = joinFolder(root, item.name)
    item.storage = uniqueStorageName(baseName(item.logicalName), reservedStorage)
    if not item.storage then
      removeFileList(createdFiles)
      state.status.backup = "The mod could not create a safe file name for an imported preset."
      return false
    end
    item.path = PRESET_DIR .. "/" .. item.storage .. ".preset"
    local wrote = atomicReplace(item.path, function(temporary)
      return writeFileSafely(temporary, "wb", function(file)
        return file:write(item.contents) ~= nil and file:flush() ~= nil
      end)
    end, "library backup preset")
    local preset = wrote and readPresetFile(item.path, true) or nil
    if not preset then
      removeFileList(createdFiles)
      if wrote then removeFileList({ item.path }) end
      state.status.backup = "An imported preset could not be written or verified safely."
      return false
    end
    table.insert(createdFiles, item.path)
    preset.storage = item.storage
    preset.fingerprint = fileFingerprint(item.path, MAX_PRESET_BYTES)
    newPresets[item.logicalName] = preset
  end
  local catalogSaved = writeCatalog(newPresets, newFolders, newManualFolders, newIgnored)
  local inventorySaved = catalogSaved and writeInventory(newPresets, newFolders)
  if not inventorySaved then
    writeCatalog(state.library.presets, state.library.folders, state.library.manualFolders,
      state.library.ignoredPhysicalFolders)
    writeInventory(state.library.presets, state.library.folders)
    removeFileList(createdFiles)
    state.status.backup = "The imported presets were removed because the library lists could not be saved."
    return false
  end
  local previousConfig = readBoundedFile(CONFIG_FILE, MAX_CATALOG_BYTES)
  local configSaved = atomicReplace(CONFIG_FILE, function(temporary)
    return writeFileSafely(temporary, "wb", function(file)
      return file:write(backup.config) ~= nil and file:flush() ~= nil
    end)
  end, "restored config")
  if not configSaved then
    writeCatalog(state.library.presets, state.library.folders, state.library.manualFolders,
      state.library.ignoredPhysicalFolders)
    writeInventory(state.library.presets, state.library.folders)
    removeFileList(createdFiles)
    if previousConfig then
      atomicReplace(CONFIG_FILE, function(temporary)
        return writeFileSafely(temporary, "wb", function(file)
          return file:write(previousConfig) ~= nil and file:flush() ~= nil
        end)
      end, "previous config")
    end
    state.status.backup = "The imported presets were removed because the settings file could not be restored."
    return false
  end
  state.library.presets, state.library.folders = newPresets, newFolders
  state.library.manualFolders, state.library.ignoredPhysicalFolders = newManualFolders, newIgnored
  local config, loaded = readConfig()
  if loaded then
    state.ui.discoveryNoticeIgnored = not config.discoveryReminder
    state.library.sortMode = config.presetSort == "modified" and "modified" or "name"
  end
  state.library.selectedFolder = root
  invalidateViewCache()
  resetLoadState()
  cancelConfirmations()
  state.status.backup = ("Imported %d preset%s and the saved settings%s.")
    :format(#backup.presets, #backup.presets == 1 and "" or "s",
      root ~= "" and (" under " .. root) or "")
  log(("[LIBRARY BACKUP] Imported presets=%d root='%s' file='%s'.")
    :format(#backup.presets, root, path), "complete")
  return true
end

end

return _ENV
