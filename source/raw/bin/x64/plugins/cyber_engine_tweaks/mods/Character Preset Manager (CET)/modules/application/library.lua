local paths = require("modules/domain/paths")
local names = require("modules/domain/names")
local libraryModel = require("modules/domain/library")
local parentFolder, baseName, joinFolder = paths.parentFolder, paths.baseName, paths.joinFolder
local addFolderAncestors, validRelativePath = paths.addFolderAncestors, paths.validRelativePath
local validatedPresetName = names.validatedPresetName
local MAX_NAME_BYTES = 64
local MAX_COLLISION_CANDIDATES = 9999
local FIRST_COLLISION_SUFFIX = 2

local function reconcile(scannedPresets, catalogFolders, assignments, physicalFolders,
    ignoredPhysicalFolders, previousPresets, scanReason, scannedEntryCount, maximumScannedEntries)
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
      for index = FIRST_COLLISION_SUFFIX, MAX_COLLISION_CANDIDATES do
        local suffix = (" %d"):format(index)
        local candidate = joinFolder(folder, leaf:sub(1, MAX_NAME_BYTES - #suffix) .. suffix)
        if not usedLogicalNames[candidate:lower()] then
          logicalName = candidate
          lowered = candidate:lower()
          resolved = true
          break
        end
      end
      if not resolved then
        return nil, nil, nil, "identity", storage
      end
    end
    usedLogicalNames[lowered] = true
    local inventoryPreset = previousPresets[logicalName]
    if scanReason == "startup" and type(inventoryPreset) == "table" then
      preset.entryCount = libraryModel.presetEntryCount(inventoryPreset)
      preset.entryCountKnown = inventoryPreset.entryCountKnown
      preset.format = inventoryPreset.format
      preset.modified = inventoryPreset.modified
      preset.fingerprint = inventoryPreset.fingerprint
      local knownEntries = inventoryPreset.entryCountKnown
        and libraryModel.presetEntryCount(inventoryPreset) or 0
      scannedEntryCount = scannedEntryCount + knownEntries
      if scannedEntryCount > maximumScannedEntries then
        return nil, nil, nil, "entries", scannedEntryCount
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

  return presets, folders, manualFolders
end

return {reconcile=reconcile}
