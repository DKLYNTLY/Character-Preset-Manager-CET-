local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

do

local function validBundlePath(value)
  if not validRelativePath(value) then return false end
  for part in value:gmatch("[^/]+") do
    local validated = validatedPresetName(part)
    if validated ~= part then return false end
  end
  return true
end

local function hexEncode(value)
  return (value:gsub(".", function(character)
    return ("%02X"):format(character:byte())
  end))
end

local function hexDecode(value)
  if #value % 2 ~= 0 or not value:match("^%x+$") then return nil end
  return (value:gsub("(%x%x)", function(pair)
    return string.char(tonumber(pair, 16))
  end))
end

local function writeHexFile(output, path)
  local input = io.open(path, "rb")
  if not input then return false, nil end
  local sizeOk, size = pcall(input.seek, input, "end")
  local rewindOk, rewindResult = pcall(input.seek, input, "set", 0)
  if not sizeOk or not size or size > MAX_PRESET_BYTES
      or not rewindOk or rewindResult == nil then
    input:close()
    return false, size
  end
  local readBytes = 0
  local writeOk, writeResult = pcall(function()
    while true do
      local chunk = input:read(FILE_COPY_CHUNK_SIZE)
      if not chunk then break end
      readBytes = readBytes + #chunk
      if not output:write(hexEncode(chunk)) then return false end
    end
    return readBytes == size
  end)
  local closeOk, closeResult = pcall(input.close, input)
  return writeOk and writeResult == true and closeOk and closeResult ~= nil, size
end

folderBundleFiles = function(forceRefresh)
  if not forceRefresh and not state.cache.folderBundleFilesDirty then
    return state.cache.folderBundleFiles
  end
  local bundles = {}
  local entries = safeDirectoryEntries(PRESET_DIR, 0)
  if not entries then return state.cache.folderBundleFiles end
  for _, entry in ipairs(entries) do
    if entry.type == "file"
        and entry.name:lower():sub(-#FOLDER_BUNDLE_EXTENSION) == FOLDER_BUNDLE_EXTENSION then
      table.insert(bundles, PRESET_DIR .. "/" .. entry.name)
    end
  end
  table.sort(bundles, function(a, b) return a:lower() < b:lower() end)
  state.cache.folderBundleFiles = bundles
  state.cache.folderBundleFilesDirty = false
  return state.cache.folderBundleFiles
end

local function uniqueTrashedBundleFilename(filename)
  local stem = filename:sub(1, -#FOLDER_BUNDLE_EXTENSION - 1)
  for index = 1, 9999 do
    local suffix = index == 1 and "" or (" %d"):format(index)
    local candidate = stem:sub(1, 255 - #FOLDER_BUNDLE_EXTENSION - #suffix) ..
      suffix .. FOLDER_BUNDLE_EXTENSION
    if not fileExists(TRASH_DIR .. "/" .. candidate) then return candidate end
  end
  return nil
end

trashSelectedFolderBundle = function()
  clearStatus("folder")
  helpers.auditSection("TRASH FOLDER BUNDLE")
  local selected = state.library.selectedBundleFile
  if not isFolderBundleFilename(selected) then
    setStatus("folder", "Select a shared-folder file to move to Trash.", true)
    return
  end
  local selectedPath = nil
  for _, path in ipairs(folderBundleFiles(true)) do
    local leaf = path:match("([^/]+)$")
    if leaf and leaf:lower() == selected:lower() then
      selected, selectedPath = leaf, path
      break
    end
  end
  if not selectedPath then
    state.library.selectedBundleFile = nil
    setStatus("folder", "That shared-folder file is no longer available.", true)
    return
  end
  local fingerprint = fileFingerprint(selectedPath, MAX_FOLDER_BUNDLE_BYTES)
  if not fingerprint then
    setStatus("folder", "The selected shared-folder file could not be checked safely.", true)
    return
  end
  local trashFilename = uniqueTrashedBundleFilename(selected)
  if not trashFilename then
    setStatus("folder", "The mod could not create a safe Trash file name for the shared folder.", true)
    return
  end
  local trashPath = TRASH_DIR .. "/" .. trashFilename
  local moved, moveError = os.rename(selectedPath, trashPath)
  if not moved then
    setStatus("folder",
      ("The shared-folder file could not be moved to Trash: %s"):format(tostring(moveError)), true)
    return
  end
  if fileFingerprint(trashPath, MAX_FOLDER_BUNDLE_BYTES) ~= fingerprint then
    local rolledBack = os.rename(trashPath, selectedPath) ~= nil
    setStatus("folder", rolledBack
      and "Folder bundle verification failed; the file was returned to Character Presets."
      or "Folder bundle verification failed, and the file could not be returned from Trash.", true)
    return
  end
  state.trash.bundles[trashFilename] = true
  state.trash.viewDirty = true
  state.library.selectedBundleFile = nil
  state.cache.folderBundleFilesDirty = true
  setStatus("folder",
    ("Moved shared-folder file \"%s\" to Trash. Presets and folders were not changed.")
      :format(selected), false, "success")
  log(("[FOLDER BUNDLE] Moved file='%s' to Trash as '%s'.")
    :format(selectedPath, trashFilename), "complete")
end

local function readImportedBundles()
  local imported = {}
  local contents, readError = readBoundedFile(IMPORTED_BUNDLES_FILE, MAX_CATALOG_BYTES)
  if not contents then return imported, readError == "missing" end
  local lineCount = 0
  for line in (contents .. "\n"):gmatch("(.-)\n") do
    if line ~= "" then
      lineCount = lineCount + 1
      if lineCount > MAX_CATALOG_LINES then return nil, false end
      local encodedName, fingerprint, encodedRoot =
        line:match("^B\t([^\t]+)\t(2:%d+:%d+:%d+)\t([^\t]+)$")
      if not encodedName then
        encodedName, fingerprint, encodedRoot =
          line:match("^B\t([^\t]+)\t(%d+:%d+)\t([^\t]+)$")
      end
      if not encodedName then
        encodedName, fingerprint = line:match("^B\t([^\t]+)\t(2:%d+:%d+:%d+)$")
      end
      if not encodedName then
        encodedName, fingerprint = line:match("^B\t([^\t]+)\t(%d+:%d+)$")
      end
      local filename = encodedName and catalogDecode(encodedName) or nil
      local root = encodedRoot and catalogDecode(encodedRoot) or nil
      if not isFolderBundleFilename(filename)
          or (root ~= nil and not validBundlePath(root)) then return nil, false end
      imported[filename:lower()] = {
        filename = filename,
        fingerprint = fingerprint,
        root = root,
      }
    end
  end
  return imported, true
end

local function writeImportedBundles(imported)
  local lines = {}
  for _, item in pairs(imported or {}) do
    if not isFolderBundleFilename(item.filename)
        or type(item.fingerprint) ~= "string"
        or (not item.fingerprint:match("^%d+:%d+$")
          and not item.fingerprint:match("^2:%d+:%d+:%d+$")) then return false end
    local line = "B\t" .. catalogEncode(item.filename) .. "\t" .. item.fingerprint
    if item.root ~= nil then
      if not validBundlePath(item.root) then return false end
      line = line .. "\t" .. catalogEncode(item.root)
    end
    table.insert(lines, line)
  end
  table.sort(lines, function(a, b) return a:lower() < b:lower() end)
  return writeLinesIfChanged(
    IMPORTED_BUNDLES_FILE, lines, "imported-bundle registry", MAX_CATALOG_BYTES) == true
end

local function uniqueFolderBundleFilename(folder)
  local stem = "Character Preset Manager Folder - " .. baseName(folder)
  for index = 1, 999 do
    local suffix = index == 1 and "" or (" Copy %d"):format(index)
    local filename = PRESET_DIR .. "/" .. stem .. suffix .. FOLDER_BUNDLE_EXTENSION
    if not fileExists(filename) and not fileExists(filename .. ".tmp")
        and not fileExists(filename .. ".bak") then return filename end
  end
  return nil
end

exportSelectedFolderBundle = function()
  clearStatus("folder")
  helpers.auditSection("EXPORT FOLDER BUNDLE")
  local folder = state.library.selectedFolder
  if folder == "" or not state.library.folders[folder] then
    setStatus("folder", "Select a folder to export.", true); return
  end
  local names = {}
  for name in pairs(state.library.presets) do
    if isInFolderTree(parentFolder(name), folder) then table.insert(names, name) end
  end
  table.sort(names, function(a, b) return a:lower() < b:lower() end)
  if #names == 0 then
    setStatus("folder", "The selected folder contains no presets to share.", true); return
  end
  if #names > MAX_FOLDER_BUNDLE_PRESETS then
    setStatus("folder",
      ("This folder has more than the %d presets allowed in one shared-folder file."):format(MAX_FOLDER_BUNDLE_PRESETS), true); return
  end
  local folders = {}
  for candidate in pairs(state.library.folders) do
    if candidate ~= folder and isInFolderTree(candidate, folder) then
      table.insert(folders, candidate:sub(#folder + 2))
    end
  end
  table.sort(folders, function(a, b) return a:lower() < b:lower() end)
  local filename = uniqueFolderBundleFilename(folder)
  if not filename then
    setStatus("folder", "The mod could not create an unused file name for the shared folder.", true); return
  end
  local bundleError = nil
  local wrote = atomicReplace(filename, function(temporary)
    return writeFileSafely(temporary, "wb", function(file)
      local header = "CPMFOLDER\t1\nROOT\t" .. catalogEncode(baseName(folder)) .. "\n"
      local totalBytes = #header
      if not file:write(header) then return false end
      for _, relativeFolder in ipairs(folders) do
        if not validBundlePath(relativeFolder) then
          bundleError = "A folder or preset name inside this folder is not safe to export."
          return false
        end
        local line = "F\t" .. catalogEncode(relativeFolder) .. "\n"
        totalBytes = totalBytes + #line
        if totalBytes > MAX_FOLDER_BUNDLE_BYTES then
          bundleError = "The shared-folder file would be larger than the 32 MB limit."
          return false
        end
        if not file:write(line) then return false end
      end
      for _, name in ipairs(names) do
        local relativeName = name:sub(#folder + 2)
        if not validBundlePath(relativeName) then
          bundleError = "This preset could not be read and was not exported: " .. name
          return false
        end
        local prefix = "P\t" .. catalogEncode(relativeName) .. "\t"
        local source = io.open(presetPath(name), "rb")
        if not source then
          bundleError = "This preset could not be read and was not exported: " .. name
          return false
        end
        local sizeOk, sourceBytes = pcall(source.seek, source, "end")
        source:close()
        if not sizeOk or not sourceBytes or sourceBytes > MAX_PRESET_BYTES then
          bundleError = "This preset could not be read and was not exported: " .. name
          return false
        end
        totalBytes = totalBytes + #prefix + (sourceBytes * 2) + 1
        if totalBytes > MAX_FOLDER_BUNDLE_BYTES then
          bundleError = "The shared-folder file would be larger than the 32 MB limit."
          return false
        end
        if not file:write(prefix) then return false end
        local streamed, streamedBytes = writeHexFile(file, presetPath(name))
        if not streamed or streamedBytes ~= sourceBytes or not file:write("\n") then
          bundleError = "This preset could not be read and was not exported: " .. name
          return false
        end
      end
      return file:flush() ~= nil
    end)
  end, "folder bundle")
  if not wrote then
    setStatus("folder", bundleError or "The shared-folder file could not be saved.", true); return
  end
  state.cache.folderBundleFilesDirty = true
  setStatus("folder",
    ("Exported %d preset%s to %s. Share this one file.")
      :format(#names, #names == 1 and "" or "s", filename), false, "success")
  log(("[FOLDER BUNDLE] Exported folder='%s' presets=%d file='%s'.")
    :format(folder, #names, filename), "complete")
end

local function inspectFolderBundle(filename)
  local file = io.open(filename, "rb")
  if not file then return nil, "The shared-folder file could not be opened." end
  local function fail(message)
    pcall(file.close, file)
    return nil, message
  end
  local sizeOk, size = pcall(file.seek, file, "end")
  local rewindOk, rewindResult = pcall(file.seek, file, "set", 0)
  if not sizeOk or not size or size > MAX_FOLDER_BUNDLE_BYTES
      or not rewindOk or rewindResult == nil then
    file:close()
    return nil, "The shared-folder file is unreadable or larger than the 32 MB limit."
  end
  local bundle = { folders = {}, folderNames = {}, presets = {}, presetNames = {} }
  local lineNumber = 0
  for line in file:lines() do
    line = line:gsub("\r$", "")
    if line ~= "" then
      lineNumber = lineNumber + 1
      if lineNumber == 1 then
        if line ~= "CPMFOLDER\t1" then
          return fail("The shared-folder file has an invalid first line.")
        end
      else
        local root = line:match("^ROOT\t([^\t]+)$")
        local folder = line:match("^F\t([^\t]+)$")
        local name, encoded = line:match("^P\t([^\t]+)\t([%x]+)$")
        if root then
          root = catalogDecode(root)
          if bundle.root or not validBundlePath(root) or parentFolder(root) ~= "" then
            return fail("The shared folder has an invalid main folder name.")
          end
          bundle.root = root
        elseif folder then
          folder = catalogDecode(folder)
          if not validBundlePath(folder) then
            return fail("The shared folder contains an invalid folder name.")
          end
          if bundle.folderNames[folder:lower()] then
            return fail("The shared-folder file contains the same folder more than once.")
          end
          bundle.folderNames[folder:lower()] = true
          bundle.folders[folder] = true
        elseif name then
          name = catalogDecode(name)
          if not validBundlePath(name) or #encoded % 2 ~= 0
              or #encoded > MAX_PRESET_BYTES * 2
              or #bundle.presets >= MAX_FOLDER_BUNDLE_PRESETS then
            return fail("The shared-folder file contains an invalid preset.")
          end
          if bundle.presetNames[name:lower()] then
            return fail("The shared-folder file contains the same preset more than once.")
          end
          bundle.presetNames[name:lower()] = true
          table.insert(bundle.presets, { name = name })
        else
          return fail(("Line %d in the shared-folder file is invalid."):format(lineNumber))
        end
      end
    end
  end
  local closeOk, closeResult = pcall(file.close, file)
  if not closeOk or closeResult == nil then
    return nil, "The shared-folder file could not be closed safely."
  end
  if not bundle.root or #bundle.presets == 0 then return nil, "The shared-folder file is empty or incomplete." end
  bundle.folderNames = nil
  bundle.presetNames = nil
  return bundle
end

local function writeRawPreset(path, contents)
  return atomicReplace(path, function(temporary)
    return writeFileSafely(temporary, "wb", function(file)
      return file:write(contents) ~= nil and file:flush() ~= nil
    end)
  end, "imported folder preset")
end

local function importFolderBundle(filename, fingerprint, importedBundles)
  local bundle, bundleError = inspectFolderBundle(filename)
  if not bundle then return nil, bundleError end
  local root = bundle.root
  if folderNameExists(root) then root = uniqueFolderCopyName(root) end
  if not root then return nil, "The mod could not create an unused name for the imported folder." end
  local newPresets = cloneMap(state.library.presets)
  local newFolders = cloneMap(state.library.folders)
  local newManualFolders = cloneMap(state.library.manualFolders)
  local newIgnored = cloneMap(state.library.ignoredPhysicalFolders)
  addFolderAncestors(newFolders, root)
  for folder in pairs(bundle.folders) do
    addFolderAncestors(newFolders, joinFolder(root, folder))
  end
  local reservedStorage = storageFilenamesInUse()
  if not reservedStorage then return nil, "The existing preset file names could not be checked safely." end
  local createdFiles = {}
  for _, item in ipairs(bundle.presets) do
    local logicalName = joinFolder(root, item.name)
    if findPresetCollision(logicalName) then
      return nil, "An imported preset has the same name as an existing preset."
    end
    local storage = uniqueStorageName(baseName(logicalName), reservedStorage)
    if not storage then
      return nil, "The mod could not create a safe file name for an imported preset."
    end
    item.logicalName = logicalName
    item.storage = storage
    item.path = PRESET_DIR .. "/" .. storage .. ".preset"
  end
  local plansByName = {}
  for _, item in ipairs(bundle.presets) do plansByName[item.name:lower()] = item end
  local file = io.open(filename, "rb")
  if not file then return nil, "The shared-folder file could not be reopened for installation." end
  local importedCount = 0
  local importError = nil
  for line in file:lines() do
    line = line:gsub("\r$", "")
    local encodedName, encoded = line:match("^P\t([^\t]+)\t([%x]+)$")
    if encodedName then
      local name = catalogDecode(encodedName)
      local item = plansByName[name:lower()]
      local contents = item and hexDecode(encoded) or nil
      if not item or not contents or #contents > MAX_PRESET_BYTES
          or not writeRawPreset(item.path, contents) then
        importError = "An imported preset file could not be written safely."
        break
      end
      table.insert(createdFiles, item.path)
      local preset = readPresetFile(item.path, true)
      if not preset then
        importError = "An imported preset failed verification."
        break
      end
      preset.fingerprint = fileFingerprint(item.path, MAX_PRESET_BYTES)
      preset.storage = item.storage
      newPresets[item.logicalName] = preset
      importedCount = importedCount + 1
    end
  end
  local closeOk, closeResult = pcall(file.close, file)
  if importError or not closeOk or closeResult == nil
      or importedCount ~= #bundle.presets
      or fileFingerprint(filename, MAX_FOLDER_BUNDLE_BYTES) ~= fingerprint then
    local message = importError
      or "The shared-folder file changed or could not be read completely during installation."
    return nil, cleanupFailureMessage(createdFiles, message,
      message .. " Some partial preset files could not be removed.")
  end
  if not writeCatalog(newPresets, newFolders, newManualFolders, newIgnored) then
    return nil, cleanupFailureMessage(createdFiles,
      "The imported folder was removed again because the folder list could not be saved.",
      "The folder list could not be saved, and some imported preset files could not be removed.")
  end
  local inventorySaved = writeInventory(newPresets, newFolders)
  if not inventorySaved then
    writeCatalog(state.library.presets, state.library.folders, state.library.manualFolders,
      state.library.ignoredPhysicalFolders)
    return nil, cleanupFailureMessage(createdFiles,
      "The imported folder was removed again because the preset file list could not be saved.",
      "The preset file list could not be saved, and some imported preset files could not be removed.")
  end
  local leaf = filename:match("([^/]+)$")
  local updatedImported = cloneMap(importedBundles)
  updatedImported[leaf:lower()] = {
    filename = leaf,
    fingerprint = fingerprint,
    root = root,
  }
  if not writeImportedBundles(updatedImported) then
    writeCatalog(state.library.presets, state.library.folders, state.library.manualFolders,
      state.library.ignoredPhysicalFolders)
    writeInventory(state.library.presets, state.library.folders)
    return nil, cleanupFailureMessage(createdFiles,
      "The imported folder was removed again because the completed import could not be recorded.",
      "The completed import could not be recorded, and some imported preset files could not be removed.")
  end
  state.library.presets, state.library.folders = newPresets, newFolders
  state.library.manualFolders, state.library.ignoredPhysicalFolders = newManualFolders, newIgnored
  state.library.selectedFolder = root
  invalidateViewCache()
  resetLoadState()
  cancelConfirmations()
  importedBundles[leaf:lower()] = updatedImported[leaf:lower()]
  log(("[FOLDER BUNDLE] Imported file='%s' root='%s' presets=%d fingerprint='%s'.")
    :format(filename, root, #bundle.presets, fingerprint), "complete")
  return root, ""
end

importAvailableFolderBundles = function()
  clearStatus("folder")
  helpers.auditSection("IMPORT FOLDER BUNDLES")
  local files = folderBundleFiles(true)
  if #files == 0 then
    setStatus("folder",
      "Place a .cpmfolder file in Character Presets, then select Install Shared Folders.", true); return
  end
  local importedBundles, registryOk = readImportedBundles()
  if not registryOk then
    setStatus("folder",
      "Imported Bundles.txt is unreadable or unsafe. No bundles were changed.", true); return
  end
  local imported, skipped, failures, warnings = 0, 0, {}, {}
  for _, filename in ipairs(files) do
    local leaf = filename:match("([^/]+)$")
    local fingerprint, legacyFingerprint = fileFingerprint(filename, MAX_FOLDER_BUNDLE_BYTES)
    local previousImport = importedBundles[leaf:lower()]
    local previouslySame = previousImport
      and (previousImport.fingerprint == fingerprint
        or previousImport.fingerprint == legacyFingerprint)
    if not fingerprint then
      table.insert(failures, filename .. ": The file could not be checked safely.")
    elseif previouslySame
        and previousImport.root and folderNameExists(previousImport.root) then
      if previousImport.fingerprint ~= fingerprint then
        previousImport.fingerprint = fingerprint
        if not writeImportedBundles(importedBundles) then
          table.insert(warnings,
            filename .. ": The saved file check could not be updated, but the existing folder was kept.")
        end
      end
      skipped = skipped + 1
      log(("[FOLDER BUNDLE] Skipped previously imported file='%s' fingerprint='%s' root='%s'.")
        :format(filename, fingerprint, previousImport.root), "info")
    else
      if previouslySame then
        log(("[FOLDER BUNDLE] Previously imported folder root='%s' is no longer present; reimporting file='%s'.")
          :format(tostring(previousImport.root or "unknown"), filename), "info")
      end
      local root, result = importFolderBundle(filename, fingerprint, importedBundles)
      if root then
        imported = imported + 1
        if result ~= "" then table.insert(warnings, filename .. ":" .. result) end
      else
        table.insert(failures, filename .. ": " .. tostring(result))
      end
    end
  end
  if #failures > 0 then
    setStatus("folder",
      ("Imported %d bundle%s; skipped %d already imported. Failed: %s")
        :format(imported, imported == 1 and "" or "s", skipped, table.concat(failures, " | ")), true)
  else
    setStatus("folder",
      ("Installed %d shared folder%s; skipped %d already installed.%s")
        :format(imported, imported == 1 and "" or "s",
          skipped,
          #warnings > 0 and (" " .. table.concat(warnings, " | ")) or ""),
      false, "success")
  end
end

end

return _ENV
