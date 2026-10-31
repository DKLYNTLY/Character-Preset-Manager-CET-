local paths = require("modules/domain/paths")
local names = require("modules/domain/names")
local parentFolder, baseName, joinFolder, isInFolderTree = paths.parentFolder, paths.baseName, paths.joinFolder, paths.isInFolderTree
local folderModel = require("modules/domain/folders")
local cloneMap = folderModel.cloneMap
local function importMaps(library,root,folders)
  local newPresets,newFolders,newManualFolders = folderModel.copyFolderMaps(library)
  local newIgnored = cloneMap(library.ignoredPhysicalFolders)
  if root ~= "" then paths.addFolderAncestors(newFolders,root) end
  for folder in pairs(folders)do paths.addFolderAncestors(newFolders,joinFolder(root,folder))end
  return newPresets,newFolders,newManualFolders,newIgnored
end

local function bulkTrashMaps(library,trash,plans,folder)
  local newPresets = cloneMap(library.presets)
  local newTrash = cloneMap(trash.items)
  local newTrashGroups = cloneMap(trash.groups)
  local newFolders = cloneMap(library.folders)
  local newManualFolders = cloneMap(library.manualFolders)
  local newIgnored = cloneMap(library.ignoredPhysicalFolders)
  local nestedFolderCount = 0
  local groupId = folder and plans[1].trashFilename or nil
  if groupId then
    newTrashGroups[groupId] = { root = folder, folders = {}, manualFolders = {} }
  end
  if folder then
    for candidate in pairs(library.folders) do
      if isInFolderTree(candidate, folder) then
        newTrashGroups[groupId].folders[candidate] = true
        if library.manualFolders[candidate] then
          newTrashGroups[groupId].manualFolders[candidate] = true
        end
        if candidate ~= folder then nestedFolderCount = nestedFolderCount + 1 end
      end
    end
  end
  for _, plan in ipairs(plans) do
    newPresets[plan.name] = nil
    newTrash[plan.trashFilename] = {
      original = plan.name, preset = plan.preset, group = groupId,
    }
  end
  if folder then
    newFolders, newManualFolders = {}, {}
    for candidate in pairs(library.folders) do
      if not isInFolderTree(candidate, folder) then
        newFolders[candidate] = true
        if library.manualFolders[candidate] then newManualFolders[candidate] = true end
      elseif library.manualFolders[candidate] then
        newIgnored[candidate] = true
      end
    end
  end

  return newPresets,newTrash,newTrashGroups,newFolders,newManualFolders,newIgnored,nestedFolderCount
end

local function restoreGroupMaps(library,trash,group,groupId,plans)
  local newPresets, newFolders = cloneMap(library.presets), cloneMap(library.folders)
  local newTrash, newGroups = cloneMap(trash.items), cloneMap(trash.groups)
  local newManualFolders = cloneMap(library.manualFolders)
  local newIgnored = cloneMap(library.ignoredPhysicalFolders)
  for folder in pairs(group.folders or {}) do paths.addFolderAncestors(newFolders, folder) end
  for folder in pairs(group.manualFolders or {}) do
    newManualFolders[folder] = true
    newIgnored[folder] = nil
  end
  paths.addFolderAncestors(newFolders, group.root)
  for _, plan in ipairs(plans) do
    plan.preset.storage = plan.storage
    newPresets[plan.name] = plan.preset
    newTrash[plan.filename] = nil
    paths.addFolderAncestors(newFolders, parentFolder(plan.name))
  end
  newGroups[groupId] = nil
  return newPresets,newFolders,newTrash,newGroups,newManualFolders,newIgnored
end

local function planBundleItems(items,root,presets,reservedStorage,presetDirectory)
  for _,item in ipairs(items)do
    local logicalName=joinFolder(root,item.name)
    if names.findPresetCollision(logicalName,nil,presets)then return "collision" end
    local storage=names.uniqueStorageName(baseName(logicalName),reservedStorage)
    if not storage then return "storage" end
    item.logicalName=logicalName
    item.storage=storage
    item.path=presetDirectory.."/"..storage..".preset"
  end
end
local function itemsByName(items)
  local byName={}
  for _,item in ipairs(items)do byName[item.name:lower()]=item end
  return byName
end

return {planBundleItems=planBundleItems,itemsByName=itemsByName,importMaps=importMaps,bulkTrashMaps=bulkTrashMaps,restoreGroupMaps=restoreGroupMaps}
