local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime
local codecs = require("modules/domain/codecs")
local paths = require("modules/domain/paths")
local trashModel = require("modules/domain/trash")
local recoveryItems = require("modules/application/recovery_items")
local bundleCodec = require("modules/domain/bundle_codec")

do

local function validBundlePath(value)
  return paths.validBundlePath(value, validatedPresetName)
end

local function hexEncode(value)
  return codecs.hexEncode(value)
end

local function hexDecode(value)
  return codecs.hexDecode(value)
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

clearFolderBundlePreview = function()
  state.library.folderBundlePreview = nil
end

local function uniqueTrashedBundleFilename(filename)
  for index = 1, 9999 do
    local candidate = trashModel.bundleCandidate(filename,index,FOLDER_BUNDLE_EXTENSION,false)
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
    clearFolderBundlePreview()
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
  local moved, moveError = renameFile(selectedPath, trashPath)
  if not moved then
    setStatus("folder",
      ("The shared-folder file could not be moved to Trash: %s"):format(tostring(moveError)), true)
    return
  end
  if fileFingerprint(trashPath, MAX_FOLDER_BUNDLE_BYTES) ~= fingerprint then
    local rolledBack = renameFile(trashPath, selectedPath) ~= nil
    setStatus("folder", rolledBack
      and "The shared-folder file failed its check and was returned to Character Presets."
      or "The shared-folder file failed its check and could not be returned from Trash.", true)
    return
  end
  state.trash.bundles[trashFilename] = true
  state.trash.viewDirty = true
  state.library.selectedBundleFile = nil
  clearFolderBundlePreview()
  state.cache.folderBundleFilesDirty = true
  setStatus("folder",
    ("Moved shared-folder file \"%s\" to Trash. Your installed presets and folders were left unchanged.")
      :format(selected), false, "success")
  log(("[FOLDER BUNDLE] Moved file='%s' to Trash as '%s'.")
    :format(selectedPath, trashFilename), "complete")
end

local function readImportedBundles()
  local contents, readError = readBoundedFile(IMPORTED_BUNDLES_FILE, MAX_CATALOG_BYTES)
  if not contents then return {}, readError == "missing" end
  return bundleCodec.decodeRegistry(contents, MAX_CATALOG_LINES)
end

local function writeImportedBundles(imported)
  local lines = bundleCodec.encodeRegistry(imported)
  if not lines then return false end
  return writeLinesIfChanged(
    IMPORTED_BUNDLES_FILE, lines, "imported-bundle registry", MAX_CATALOG_BYTES) == true
end

local function uniqueFolderBundleFilename(label)
  for index = 1, 999 do
    local filename = bundleCodec.exportCandidate(label,index,PRESET_DIR,FOLDER_BUNDLE_EXTENSION)
    if not fileExists(filename) and not fileExists(filename .. ".tmp")
        and not fileExists(filename .. ".bak") then return filename end
  end
  return nil
end

local function writePresetBundle(filename, root, folders, names, relativeName)
  local bundleError = nil
  local wrote = atomicReplace(filename, function(temporary)
    return writeFileSafely(temporary, "wb", function(file)
      local header = bundleCodec.header(root)
      local totalBytes = #header
      if not file:write(header) then return false end
      for _, relativeFolder in ipairs(folders) do
        if not validBundlePath(relativeFolder) then
          bundleError = "This selection contains a folder or preset name that cannot be exported safely."
          return false
        end
        local line = bundleCodec.folderLine(relativeFolder)
        totalBytes = totalBytes + #line
        if totalBytes > MAX_FOLDER_BUNDLE_BYTES then
          bundleError = "This shared-folder file would exceed the 32 MB limit."
          return false
        end
        if not file:write(line) then return false end
      end
      for _, name in ipairs(names) do
        local exportedName = relativeName(name)
        if not validBundlePath(exportedName) then
          bundleError = "This preset could not be read and was not exported: " .. name
          return false
        end
        local prefix = bundleCodec.presetPrefix(exportedName)
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
          bundleError = "This shared-folder file would exceed the 32 MB limit."
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
  return wrote, bundleError
end

exportSelectedFolderBundle = function()
  clearStatus("folder")
  helpers.auditSection("EXPORT FOLDER BUNDLE")
  local folder = state.library.selectedFolder
  if folder == "" or not state.library.folders[folder] then
    setStatus("folder", "Select a folder to export.", true); return
  end
  local names = bundleCodec.folderPresetNames(state.library.presets,folder)
  if #names == 0 then
    setStatus("folder", "The selected folder contains no presets to share.", true); return
  end
  if #names > MAX_FOLDER_BUNDLE_PRESETS then
    setStatus("folder",
      ("This folder exceeds the limit of %d presets per shared-folder file."):format(MAX_FOLDER_BUNDLE_PRESETS), true); return
  end
  local folders = bundleCodec.nestedFolders(state.library.folders,folder)
  local filename = uniqueFolderBundleFilename(folder)
  if not filename then
    setStatus("folder", "The mod could not create an unused file name for the shared folder.", true); return
  end
  local wrote, bundleError = writePresetBundle(filename, baseName(folder), folders, names,
    function(name) return name:sub(#folder + 2) end)
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

exportSelectedBulkPresetBundle = function()
  clearStatus("bulk")
  helpers.auditSection("EXPORT BULK PRESET BUNDLE")
  local names = selectedBulkPresetNames()
  if #names == 0 then
    setStatus("bulk", "Select at least one preset before exporting.", true); return false
  end
  if #names > MAX_FOLDER_BUNDLE_PRESETS then
    setStatus("bulk", ("This selection exceeds the limit of %d presets per shared-folder file.")
      :format(MAX_FOLDER_BUNDLE_PRESETS), true); return false
  end
  local folders = bundleCodec.selectionFolders(names)
  local filename = uniqueFolderBundleFilename("Selected Presets")
  if not filename then
    setStatus("bulk", "The mod could not create an unused file name for the selected presets.", true)
    return false
  end
  local wrote, bundleError = writePresetBundle(filename, "Selected Presets", folders, names,
    function(name) return name end)
  if not wrote then
    setStatus("bulk", bundleError or "The shared-folder file could not be saved.", true)
    return false
  end
  state.cache.folderBundleFilesDirty = true
  setStatus("bulk", ("Exported %d selected preset%s to %s.")
    :format(#names, #names == 1 and "" or "s", filename), false, "success")
  log(("[FOLDER BUNDLE] Exported bulk selection presets=%d file='%s'.")
    :format(#names, filename), "complete")
  return true
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
  local bundleLineErrors = {
    invalid_header = "The shared-folder file has an invalid first line.",
    invalid_root = "The shared folder has an invalid main folder name.",
    invalid_folder = "The shared folder contains an invalid folder name.",
    duplicate_folder = "The shared-folder file contains the same folder more than once.",
    invalid_preset = "The shared-folder file contains an invalid preset.",
    duplicate_preset = "The shared-folder file contains the same preset more than once.",
  }
  local context = bundleCodec.newInspector()
  local bundle = context.bundle
  for line in file:lines() do
    local issue = bundleCodec.inspectLine(context, line, MAX_PRESET_BYTES, MAX_FOLDER_BUNDLE_PRESETS)
    if issue then return fail(bundleLineErrors[issue] or ("Line %d in the shared-folder file is invalid."):format(context.lineNumber)) end
  end
  local closeOk, closeResult = pcall(file.close, file)
  if not closeOk or closeResult == nil then
    return nil, "The shared-folder file could not be closed safely."
  end
  if not bundleCodec.finishInspection(bundle) then return nil, "The shared-folder file is empty or incomplete." end
  return bundle
end

viewSelectedFolderBundleContents = function()
  clearStatus("folder")
  local selected = state.library.selectedBundleFile
  if not isFolderBundleFilename(selected) then
    clearFolderBundlePreview()
    setStatus("folder", "Select a shared-folder file to view its contents.", true)
    return false
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
    clearFolderBundlePreview()
    setStatus("folder", "That shared-folder file is no longer available.", true)
    return false
  end
  local bundle, bundleError = inspectFolderBundle(selectedPath)
  if not bundle then
    clearFolderBundlePreview()
    setStatus("folder", bundleError, true)
    return false
  end
  local folders, presets = {}, {}
  for folder in pairs(bundle.folders) do table.insert(folders, folder) end
  for _, preset in ipairs(bundle.presets) do table.insert(presets, preset.name) end
  table.sort(folders, function(a, b) return a:lower() < b:lower() end)
  table.sort(presets, function(a, b) return a:lower() < b:lower() end)
  state.library.selectedBundleFile = selected
  state.library.folderBundlePreview = {
    filename = selected,
    root = bundle.root,
    folders = folders,
    presets = presets,
  }
  setStatus("folder",
    ("Showing %d preset%s from \"%s\".")
      :format(#presets, #presets == 1 and "" or "s", selected), false, "success")
  log(("[FOLDER BUNDLE] Viewed file='%s' root='%s' folders=%d presets=%d.")
    :format(selectedPath, bundle.root, #folders, #presets), "info")
  return true
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
  local newPresets,newFolders,newManualFolders,newIgnored = recoveryItems.importMaps(state.library,root,bundle.folders)
  local reservedStorage = storageFilenamesInUse()
  if not reservedStorage then return nil, "The existing preset file names could not be checked safely." end
  local createdFiles = {}
  local planError = recoveryItems.planBundleItems(bundle.presets,root,state.library.presets,reservedStorage,PRESET_DIR)
  if planError == "collision" then return nil, "An imported preset has the same name as an existing preset." end
  if planError == "storage" then return nil, "The mod could not create a safe file name for an imported preset." end
  local plansByName = recoveryItems.itemsByName(bundle.presets)
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
      local folderUpdated = state.updatePresetLibraryFolder(preset, item.logicalName)
      if not folderUpdated then
        importError = "An imported preset's saved library folder could not be updated safely."
        break
      end
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
      "The folder list could not be saved, so the new folder copy was removed.",
      "The folder list could not be saved, and some imported preset files could not be removed.")
  end
  local inventorySaved = writeInventory(newPresets, newFolders)
  if not inventorySaved then
    writeCatalog(state.library.presets, state.library.folders, state.library.manualFolders,
      state.library.ignoredPhysicalFolders)
    return nil, cleanupFailureMessage(createdFiles,
      "The preset file list could not be saved, so the new folder copy was removed.",
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
      "The completed import could not be recorded, so the new folder copy was removed.",
      "The completed import could not be recorded. Some new preset copies could not be removed.")
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
      "Place a .cpmfolder file in Character Presets, then select Install .cpmfolder Files from Character Presets.", true); return
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
