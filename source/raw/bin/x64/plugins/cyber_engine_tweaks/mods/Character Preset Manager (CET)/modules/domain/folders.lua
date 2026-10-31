local paths = require("modules/domain/paths")
local names = require("modules/domain/names")
local parentFolder, baseName = paths.parentFolder, paths.baseName
local isInFolderTree, remapFolderTreePath, joinFolder = paths.isInFolderTree, paths.remapFolderTreePath, paths.joinFolder
local function cloneMap(source)
  local copy = {}
  for key, value in pairs(source or {}) do copy[key] = value end
  return copy
end

local function renameContents(library, old, destination)
  local newPresets, newFolders = {}, {}
  local newManualFolders = {}
  local newIgnored = cloneMap(library.ignoredPhysicalFolders)
  local usedPresetNames = {}
  for name, preset in pairs(library.presets) do
    local mapped = isInFolderTree(parentFolder(name), old)
      and remapFolderTreePath(name, old, destination) or name
    if usedPresetNames[mapped:lower()] then
      return nil, nil, nil, nil, "presets"
    end
    usedPresetNames[mapped:lower()] = true
    newPresets[mapped] = preset
  end
  local usedFolders = {}
  for folder in pairs(library.folders) do
    local mapped = remapFolderTreePath(folder, old, destination)
    if usedFolders[mapped:lower()] then
      return nil, nil, nil, nil, "folders"
    end
    usedFolders[mapped:lower()] = true
    newFolders[mapped] = true
    if mapped == folder and library.manualFolders[folder] then
      newManualFolders[mapped] = true
    elseif mapped ~= folder and library.manualFolders[folder] then
      newIgnored[folder] = true
    end
  end
  return newPresets, newFolders, newManualFolders, newIgnored
end

local function removeContents(library, folder, destinationParent)
  local newPresets, newFolders = {}, {}
  local newManualFolders = {}
  local newIgnored = cloneMap(library.ignoredPhysicalFolders)
  local usedPresets, usedFolders = {}, {}
  for name, preset in pairs(library.presets) do
    local mapped = name
    if isInFolderTree(parentFolder(name), folder) then
      mapped = joinFolder(destinationParent, name:sub(#folder + 2))
    end
    if usedPresets[mapped:lower()] then
      return nil, nil, nil, nil, "presets"
    end
    usedPresets[mapped:lower()] = true
    newPresets[mapped] = preset
  end
  for candidate in pairs(library.folders) do
    if candidate ~= folder then
      local mapped = candidate
      if isInFolderTree(candidate, folder) then
        mapped = joinFolder(destinationParent, candidate:sub(#folder + 2))
      end
      if usedFolders[mapped:lower()] then
        return nil, nil, nil, nil, "folders"
      end
      usedFolders[mapped:lower()] = true
      newFolders[mapped] = true
      if mapped == candidate and library.manualFolders[candidate] then
        newManualFolders[mapped] = true
      elseif mapped ~= candidate and library.manualFolders[candidate] then
        newIgnored[candidate] = true
      end
    elseif library.manualFolders[candidate] then
      newIgnored[candidate] = true
    end
  end
  return newPresets, newFolders, newManualFolders, newIgnored
end

local function currentNames(presets)
  local current = {}
  for name, preset in pairs(presets) do current[preset] = name end
  return current
end

local function needsHeaderSync(previousName, preset, name)
  local desiredFolder = parentFolder(name)
  local folderChanged = previousName and parentFolder(previousName) ~= desiredFolder
  local savedFolderChanged = preset.libraryFolder ~= nil and preset.libraryFolder ~= desiredFolder
  local savedNameChanged = preset.presetName ~= nil and preset.presetName ~= baseName(name)
  return not previousName or folderChanged or savedFolderChanged or savedNameChanged
end

local function copyFolderMaps(library)
  local newPresets = cloneMap(library.presets)
  local newFolders = cloneMap(library.folders)
  local newManualFolders = cloneMap(library.manualFolders)
  return newPresets, newFolders, newManualFolders
end

local function addCopiedFolders(folders, newFolders, newManualFolders, source, destination)
  for folder in pairs(folders) do
    if isInFolderTree(folder, source) then
      local mapped = remapFolderTreePath(folder, source, destination)
      newFolders[mapped] = true
      newManualFolders[mapped] = nil
    end
  end
  newFolders[destination] = true
end

local function relocationPlans(presets, folder, reservedStorage)
  local relocationPlans = {}
  for logicalName, preset in pairs(presets) do
    local storageFolder = parentFolder(preset.storage or "")
    if storageFolder ~= "" and isInFolderTree(storageFolder, folder) then
      local destinationStorage = names.uniqueStorageName(baseName(preset.storage), reservedStorage)
      if not destinationStorage then
        return nil
      end
      table.insert(relocationPlans, {
        storage = preset.storage,
        destinationStorage = destinationStorage,
        name = logicalName,
        preset = preset,
      })
    end
  end
  table.sort(relocationPlans, function(a, b)
    return a.storage:lower() < b.storage:lower()
  end)
  return relocationPlans
end

return {cloneMap=cloneMap,renameContents=renameContents, removeContents=removeContents, currentNames=currentNames,
  needsHeaderSync=needsHeaderSync, relocationPlans=relocationPlans, copyFolderMaps=copyFolderMaps, addCopiedFolders=addCopiedFolders}
