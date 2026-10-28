local paths = require("modules/domain/paths")
local names = require("modules/domain/names")
local parentFolder, baseName, joinFolder, isInFolderTree = paths.parentFolder, paths.baseName, paths.joinFolder, paths.isInFolderTree

local function buildView(items,groups,bundles)
  local trashNames, groupIds, bundleNames, groupStats = {}, {}, {}, {}
  for filename, item in pairs(items) do
    table.insert(trashNames, filename)
    if item.group then
      local stats = groupStats[item.group] or { presets = 0, folders = 0 }
      stats.presets = stats.presets + 1
      groupStats[item.group] = stats
    end
  end
  for groupId, group in pairs(groups) do
    table.insert(groupIds, groupId)
    local stats = groupStats[groupId] or { presets = 0, folders = 0 }
    for _ in pairs(group.folders or {}) do stats.folders = stats.folders + 1 end
    groupStats[groupId] = stats
  end
  for filename in pairs(bundles) do table.insert(bundleNames, filename) end
  table.sort(trashNames, function(a, b) return a:lower() < b:lower() end)
  table.sort(groupIds, function(a, b)
    return groups[a].root:lower() < groups[b].root:lower()
  end)
  table.sort(bundleNames, function(a, b) return a:lower() < b:lower() end)
  return trashNames, groupIds, bundleNames, groupStats
end

local function allocateRestoreLogicalName(original, reserved, presets)
  if not reserved[original:lower()] and not names.findPresetCollision(original,nil,presets) then
    reserved[original:lower()] = true
    return original
  end
  local folder, leaf = parentFolder(original), baseName(original)
  for index = 1, 999 do
    local suffix = index == 1 and " Copy" or (" Copy %d"):format(index)
    local candidate = joinFolder(folder, leaf:sub(1, 64 - #suffix) .. suffix)
    if not reserved[candidate:lower()] and not names.findPresetCollision(candidate,nil,presets) then
      reserved[candidate:lower()] = true
      return candidate
    end
  end
  return nil
end

local function groupFilenames(items,groupId)
  local filenames = {}
  for filename, item in pairs(items) do
    if item.group == groupId then table.insert(filenames, filename) end
  end
  table.sort(filenames, function(a, b) return a:lower() < b:lower() end)
  return filenames
end

local MAX_NAME_BYTES = 64
local MAX_FILENAME_BYTES = 255
local function trashCandidate(leaf,index)
  local suffix = index == 1 and "" or (" %d"):format(index)
  return leaf:sub(1,MAX_NAME_BYTES-#suffix)..suffix..".preset"
end
local function bundleCandidate(filename,index,extension,restoring)
  local stem = filename:sub(1,-#extension-1)
  local suffix = index == 1 and "" or (restoring and " Copy %d" or " %d"):format(index)
  return stem:sub(1,MAX_FILENAME_BYTES-#extension-#suffix)..suffix..extension
end
local function counts(items,groups,bundles)
  local count, groupCount, bundleCount = 0,0,0
  for _ in pairs(items)do count=count+1 end
  for _ in pairs(groups)do groupCount=groupCount+1 end
  for _ in pairs(bundles)do bundleCount=bundleCount+1 end
  return count,groupCount,bundleCount
end

local function namesInFolder(presetNames,folders,folder)
  local names = {}
  for _, name in ipairs(presetNames) do
    if isInFolderTree(parentFolder(name), folder) then table.insert(names, name) end
  end
  local nestedFolderCount = 0
  for candidate in pairs(folders) do
    if candidate ~= folder and isInFolderTree(candidate, folder) then
      nestedFolderCount = nestedFolderCount + 1
    end
  end
  return names,nestedFolderCount
end

local function selectedNames(selected,presets)
  local names = {}
  for name in pairs(selected) do
    if presets[name] then table.insert(names, name) end
  end
  table.sort(names, function(a, b) return a:lower() < b:lower() end)
  return names
end

return {buildView=buildView,allocateRestoreLogicalName=allocateRestoreLogicalName,groupFilenames=groupFilenames,trashCandidate=trashCandidate,bundleCandidate=bundleCandidate,counts=counts,namesInFolder=namesInFolder,selectedNames=selectedNames}
