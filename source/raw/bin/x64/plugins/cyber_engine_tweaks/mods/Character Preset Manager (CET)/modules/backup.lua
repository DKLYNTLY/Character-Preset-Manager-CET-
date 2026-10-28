local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime
local recoveryItems = require("modules/application/recovery_items")
local backupCodec = require("modules/domain/backup_codec")
local codecs = require("modules/domain/codecs")

local function setBackupStatus(message, isError, kind)
  setStatus("backup", message, isError, kind)
end

do

local function encode(value)
  return codecs.backupEncode(value)
end

local function decode(value)
  return codecs.backupDecode(value)
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

libraryBackupFiles = function(forceRefresh)
  if forceRefresh or state.backup.filesDirty then
    state.backup.files = backupFiles()
    state.backup.filesDirty = false
  end
  return state.backup.files
end

local function uniqueBackupFilename()
  for index = 1, 999 do
    local path = backupCodec.exportCandidate(index,PRESET_DIR,LIBRARY_BACKUP_EXTENSION)
    if not fileExists(path) and not fileExists(path .. ".tmp")
        and not fileExists(path .. ".bak") then return path end
  end
  return nil
end

local function verifyBackupContents(path, expectedNames, expectedFolders)
  local verifier = backupCodec.newVerifier(expectedNames, expectedFolders)
  local file = io.open(path, "rb")
  if not file then return false, "The finished library backup could not be reopened." end
local backupVerifyErrors = {
  invalid_header = "The new backup has an invalid first line.",
  invalid_config = "The finished library backup has invalid settings data.",
  unexpected_folder = "The new backup contains an unexpected folder entry.",
  unexpected_preset = "The new backup contains an unexpected preset entry.",
}
  local function fail(message)
    pcall(file.close, file)
    return false, message
  end
  for line in file:lines() do
    local issue = backupCodec.verifyLine(verifier,line,MAX_PRESET_BYTES)
    if issue then return fail(backupVerifyErrors[issue] or ("Line %d in the new backup is invalid."):format(verifier.lineNumber)) end
  end
  local closeOk, closeResult = pcall(file.close, file)
  if not closeOk or closeResult == nil or not verifier.sawConfig
      or verifier.presetCount ~= #expectedNames or verifier.folderCount ~= #expectedFolders then
    return false, "The new backup is missing part of the library."
  end
  return true
end

exportLibraryBackup = function()
  helpers.auditSection("EXPORT LIBRARY BACKUP")
  local names = helpers.sortedPresetNames()
  local folders = sortedFolderNames()
  if #names == 0 then
    setBackupStatus("Save at least one preset before exporting a library backup.", true)
    return false
  end
  local filename = uniqueBackupFilename()
  if not filename then
    setBackupStatus("No unused filename could be found for the backup.", true)
    return false
  end
  local config = readBoundedFile(CONFIG_FILE, MAX_CATALOG_BYTES)
  if not config then
    local preferences = state.preferences
    config = "presetSort=" .. tostring(preferences.presetSort) .. "\n"
  end
  local exportError = nil
  local wrote = atomicReplace(filename, function(temporary)
    return writeFileSafely(temporary, "wb", function(file)
      local totalBytes = 0
      local function writeLine(line)
        totalBytes = totalBytes + #line + 1
        return totalBytes <= MAX_LIBRARY_BACKUP_BYTES and file:write(line .. "\n") ~= nil
      end
      if not writeLine(backupCodec.header()) or not writeLine(backupCodec.configLine(config)) then
        exportError = "This backup would exceed the 256 MB limit."
        return false
      end
      for _, folder in ipairs(folders) do
        if not validRelativePath(folder) or not writeLine(backupCodec.folderLine(folder)) then
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
        local sizeOk, sourceBytes = false, nil
        if input then sizeOk, sourceBytes = pcall(input.seek, input, "end") end
        if input then input:close() end
        if not input or not sizeOk or not sourceBytes or sourceBytes > MAX_PRESET_BYTES then
          exportError = "This preset could not be read and was not exported: " .. name
          return false
        end
        local prefix = backupCodec.presetPrefix(name)
        totalBytes = totalBytes + #prefix + sourceBytes * 2 + 1
        if totalBytes > MAX_LIBRARY_BACKUP_BYTES or not file:write(prefix) then
          exportError = "This backup would exceed the 256 MB limit."
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
    setBackupStatus(exportError or "The library backup could not be saved.", true)
    return false
  end
  local verified, verificationError = verifyBackupContents(filename, names, folders)
  if not verified then
    local removed = deleteFile(filename) ~= nil or not fileExists(filename)
    local verificationMessage = verificationError
      or "The finished library backup did not pass verification."
    if not removed then
      verificationMessage = verificationMessage
        .. " The unverified backup file could not be removed."
    end
    setBackupStatus(verificationMessage, true)
    log(("[LIBRARY BACKUP] Verification failed file='%s' reason='%s'.")
      :format(filename, tostring(verificationMessage)), "error")
    return false
  end
  state.backup.selectedFile = filename
  state.backup.filesDirty = true
  setBackupStatus(("Exported and verified %d preset%s and %d folder%s in %s.")
    :format(#names, #names == 1 and "" or "s", #folders,
      #folders == 1 and "" or "s", filename), false, "success")
  log(("[LIBRARY BACKUP] Exported presets=%d folders=%d file='%s'.")
    :format(#names, #folders, filename), "complete")
  return true
end

deleteSelectedLibraryBackup = function()
  helpers.auditSection("DELETE LIBRARY BACKUP")
  local selected = state.backup.selectedFile
  local selectedPath = nil
  for _, path in ipairs(libraryBackupFiles(true)) do
    if selected and path:lower() == selected:lower() then
      selected, selectedPath = path, path
      break
    end
  end
  if not selectedPath then
    cancelConfirmations()
    state.backup.selectedFile = nil
    setBackupStatus("Choose an available library-backup file first.", true)
    return false
  end
  local fingerprint = fileFingerprint(selectedPath, MAX_LIBRARY_BACKUP_BYTES)
  if not fingerprint then
    cancelConfirmations()
    setBackupStatus("The selected library backup could not be checked safely.", true)
    return false
  end
  local leaf = selectedPath:match("([^/]+)$") or selectedPath
  if state.backup.pendingDeleteFile ~= selectedPath
      or state.backup.pendingDeleteFingerprint ~= fingerprint then
    cancelConfirmations()
    state.backup.pendingDeleteFile = selectedPath
    state.backup.pendingDeleteFingerprint = fingerprint
    setBackupStatus(("Permanently delete \"%s\"? Select Confirm Delete Selected Backup Permanently.")
      :format(leaf), false, "warning")
    return false
  end
  state.backup.pendingDeleteFile = nil
  state.backup.pendingDeleteFingerprint = nil
  local removed, removeError = deleteFile(selectedPath)
  if not removed or fileExists(selectedPath) then
    setBackupStatus(("The selected library backup could not be deleted: %s")
      :format(tostring(removeError or "the file is still present")), true)
    return false
  end
  state.backup.selectedFile = nil
  state.backup.filesDirty = true
  setBackupStatus(("Permanently deleted \"%s\"."):format(leaf), false, "success")
  log(("[LIBRARY BACKUP] Permanently deleted file='%s'."):format(selectedPath), "complete")
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
local backupReadErrors = {
  invalid_header = "The selected file is not a valid library backup.",
  duplicate_config = "The library backup contains more than one settings file.",
  unsafe_folder = "The library backup contains an unsafe folder name.",
  invalid_preset = "The backup contains an invalid preset or a duplicate entry.",
}
  local context = backupCodec.newReader()
  local backup = context.backup
  for line in file:lines() do
    local issue = backupCodec.readLine(context, line, MAX_PRESET_BYTES)
    if issue then
      file:close()
      return nil, backupReadErrors[issue] or ("Line %d in the library backup is invalid."):format(context.lineNumber)
    end
  end
  local closeOk, closeResult = pcall(file.close, file)
  if not closeOk or closeResult == nil or not backup.config or #backup.presets == 0 then
    return nil, "The library backup is incomplete."
  end
  return backup
end

local function uniqueImportRoot()
  return backupCodec.chooseImportRoot(state.library.folders,state.library.presets)
end

importLibraryBackup = function()
  helpers.auditSection("IMPORT LIBRARY BACKUP")
  local path = state.backup.selectedFile
  if not path or not fileExists(path) then
    setBackupStatus("Choose an available library-backup file first.", true)
    return false
  end
  local backup, readError = readBackup(path)
  if not backup then setBackupStatus(readError, true); return false end
  local needsRoot = backupCodec.needsImportRoot(backup,state.library.folders,state.library.presets)
  local root = needsRoot and uniqueImportRoot() or ""
  if needsRoot and not root then
    setBackupStatus("A safe folder could not be created for backup items with names already in use.", true)
    return false
  end
  local newPresets,newFolders,newManualFolders,newIgnored = recoveryItems.importMaps(state.library,root,backup.folders)
  local reservedStorage = storageFilenamesInUse()
  if not reservedStorage then
    setBackupStatus("Existing preset file names could not be checked safely.", true)
    return false
  end
  local createdFiles = {}
  for _, item in ipairs(backup.presets) do
    item.logicalName = joinFolder(root, item.name)
    item.storage = uniqueStorageName(baseName(item.logicalName), reservedStorage)
    if not item.storage then
      removeFileList(createdFiles)
      setBackupStatus("The mod could not create a safe file name for an imported preset.", true)
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
      setBackupStatus("An imported preset could not be written or verified safely.", true)
      return false
    end
    table.insert(createdFiles, item.path)
    preset.storage = item.storage
    preset.fingerprint = fileFingerprint(item.path, MAX_PRESET_BYTES)
    local folderUpdated = state.updatePresetLibraryFolder(preset, item.logicalName)
    if not folderUpdated then
      removeFileList(createdFiles)
      setBackupStatus("An imported preset's saved library folder could not be updated safely.", true)
      return false
    end
    newPresets[item.logicalName] = preset
  end
  local catalogSaved = writeCatalog(newPresets, newFolders, newManualFolders, newIgnored)
  local inventorySaved = catalogSaved and writeInventory(newPresets, newFolders)
  if not inventorySaved then
    writeCatalog(state.library.presets, state.library.folders, state.library.manualFolders,
      state.library.ignoredPhysicalFolders)
    writeInventory(state.library.presets, state.library.folders)
    removeFileList(createdFiles)
    setBackupStatus("The library lists could not be saved, so the new preset copies were removed.", true)
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
    setBackupStatus("The saved settings could not be restored, so the new preset copies were removed.", true)
    return false
  end
  state.library.presets, state.library.folders = newPresets, newFolders
  state.library.manualFolders, state.library.ignoredPhysicalFolders = newManualFolders, newIgnored
  local config, loaded = readConfig()
  if loaded then
    state.preferences.presetSort = config.presetSort
    state.library.sortMode = config.presetSort == "modified" and "modified" or "name"
    writeConfig()
  end
  state.library.selectedFolder = root
  if root ~= "" then state.library.expandedLoadFolders[root] = true end
  invalidateViewCache()
  resetLoadState()
  cancelConfirmations()
  local folderCount = 0
  for _ in pairs(backup.folders) do folderCount = folderCount + 1 end
  setBackupStatus(("Imported %d preset%s and %d folder%s with the saved settings%s.")
    :format(#backup.presets, #backup.presets == 1 and "" or "s",
      folderCount, folderCount == 1 and "" or "s",
      root ~= "" and (" under " .. root) or ""), false, "success")
  log(("[LIBRARY BACKUP] Imported presets=%d folders=%d root='%s' file='%s'.")
    :format(#backup.presets, folderCount, root, path), "complete")
  return true
end

end

return _ENV
