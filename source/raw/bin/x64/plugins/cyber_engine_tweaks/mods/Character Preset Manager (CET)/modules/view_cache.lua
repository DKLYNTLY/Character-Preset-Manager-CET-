local _ENV = require("modules.runtime")

function unresolvedSignature(unresolved)
  local keys = {}
  for key in pairs(unresolved) do table.insert(keys, key) end
  table.sort(keys)
  return table.concat(keys, "\30")
end

function baseName(name)
  return name:match("([^/]+)$") or name
end

helpers.breadcrumb = function(name)
  if not name or name == "" then return "All Presets" end
  return (name:gsub("/", " > "))
end

function normalizeSearch(query)
  return tostring(query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
end

function textMatches(value, query)
  return query == "" or tostring(value or ""):lower():find(query, 1, true) ~= nil
end

function validModifiedTimestamp(value)
  local year, month, day, hour, minute, second = tostring(value or "")
    :match("^(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d):(%d%d)$")
  year, month, day = tonumber(year), tonumber(month), tonumber(day)
  hour, minute, second = tonumber(hour), tonumber(minute), tonumber(second)
  return year ~= nil and year >= 2000 and month >= 1 and month <= 12
    and day >= 1 and day <= 31 and hour >= 0 and hour <= 23
    and minute >= 0 and minute <= 59 and second >= 0 and second <= 59
end

function invalidateFilteredViewCache()
  state.filteredViewDirty = true
  state.cachedBulkFolder = nil
end

function invalidateBulkSelectionCache()
  state.bulkSelectionDirty = true
end

function invalidateViewCache()
  state.viewCacheDirty = true
  invalidateFilteredViewCache()
  invalidateBulkSelectionCache()
  if state.invalidatePreflight then state.invalidatePreflight() end
end

function invalidatePresetAndTrashCaches()
  invalidateViewCache()
  if state.invalidateTrashViewCache then state.invalidateTrashViewCache() end
end

helpers.rebuildViewCache = function()
  local presetNames = {}
  local folderNames = {}
  local presetsByFolder = {}
  local folderPresetCounts = {}
  for name in pairs(state.presets) do
    table.insert(presetNames, name)
    local folder = parentFolder(name)
    presetsByFolder[folder] = presetsByFolder[folder] or {}
    table.insert(presetsByFolder[folder], name)
    local current = folder
    while current ~= "" do
      folderPresetCounts[current] = (folderPresetCounts[current] or 0) + 1
      current = parentFolder(current)
    end
  end
  for name in pairs(state.folders) do table.insert(folderNames, name) end
  local function presetLess(a, b)
    if state.sortMode == "modified" then
      local aValue = tostring((state.presets[a] or {}).modified or "")
      local bValue = tostring((state.presets[b] or {}).modified or "")
      local aModified = validModifiedTimestamp(aValue) and aValue or ""
      local bModified = validModifiedTimestamp(bValue) and bValue or ""
      if aModified ~= bModified then return aModified > bModified end
    end
    return baseName(a):lower() < baseName(b):lower()
  end
  table.sort(presetNames, presetLess)
  table.sort(folderNames, function(a, b) return a:lower() < b:lower() end)
  for _, names in pairs(presetsByFolder) do
    table.sort(names, presetLess)
  end
  state.cachedPresetNames = presetNames
  state.cachedFolderNames = folderNames
  state.cachedPresetsByFolder = presetsByFolder
  state.cachedFolderPresetCounts = folderPresetCounts
  state.viewCacheDirty = false
end

function ensureViewCache()
  if state.viewCacheDirty then helpers.rebuildViewCache() end
end

EMPTY_LIST = {}

helpers.sortedPresetNames = function()
  ensureViewCache()
  return state.cachedPresetNames
end

function sortedFolderNames()
  ensureViewCache()
  return state.cachedFolderNames
end

helpers.presetsInFolder = function(folder)
  ensureViewCache()
  return state.cachedPresetsByFolder[folder] or EMPTY_LIST
end

helpers.rebuildFilteredViewCache = function()
  ensureViewCache()
  local query = normalizeSearch(state.searchText)
  local visibleNames = {}
  local matchedFolders = {}
  local folderMatches = {}
  local matchingByFolder = {}
  for _, name in ipairs(state.cachedPresetNames) do
    local preset = state.presets[name]
    if textMatches(name, query) or textMatches(preset and preset.tags, query) then
      table.insert(visibleNames, name)
      local directFolder = parentFolder(name)
      matchingByFolder[directFolder] = matchingByFolder[directFolder] or {}
      table.insert(matchingByFolder[directFolder], name)
      local current = directFolder
      while current ~= "" do
        matchedFolders[current] = true
        current = parentFolder(current)
      end
    end
  end
  for _, folder in ipairs(state.cachedFolderNames) do
    if textMatches(folder, query) then folderMatches[folder] = true end
  end
  state.cachedSearchText = query
  state.cachedQueryActive = query ~= ""
  state.cachedFilteredPresetNames = visibleNames
  state.cachedMatchedFolders = matchedFolders
  state.cachedFolderMatches = folderMatches
  state.cachedMatchingPresetsByFolder = matchingByFolder
  state.filteredViewDirty = false
end

function ensureFilteredViewCache()
  local query = normalizeSearch(state.searchText)
  if state.filteredViewDirty or state.cachedSearchText ~= query then
    helpers.rebuildFilteredViewCache()
  end
end

helpers.filteredPresetNames = function()
  ensureFilteredViewCache()
  return state.cachedFilteredPresetNames
end

function joinFolder(folder, name)
  if not folder or folder == "" then return name end
  return folder .. "/" .. name
end

function isInFolderTree(path, folder)
  return path == folder or path:sub(1, #folder + 1) == folder .. "/"
end

function addFolderAncestors(folders, folder)
  local current = folder
  while current and current ~= "" do
    folders[current] = true
    current = parentFolder(current)
  end
end

function findPresetCollision(name, excludeName)
  local lowered = name:lower()
  for existing in pairs(state.presets) do
    if existing:lower() == lowered and existing ~= excludeName then
      return existing
    end
  end
  return nil
end

function validRelativePath(value)
  if type(value) ~= "string" or value == ""
      or value:sub(1, 1) == "/" or value:sub(-1) == "/"
      or value:find("//", 1, true) or value:find("\\", 1, true) then
    return false
  end
  for part in value:gmatch("[^/]+") do
    if part == "." or part == ".." or part == "" then return false end
  end
  return true
end

function storageFilenamesInUse()
  local entries = safeDirectoryEntries(PRESET_DIR, 0)
  if not entries then return nil end
  local used = {}
  for _, entry in ipairs(entries) do used[entry.name:lower()] = true end
  return used
end

function uniqueStorageName(leafName, used)
  used = used or storageFilenamesInUse()
  if not used then return nil end
  for index = 1, 9999 do
    local suffix = index == 1 and "" or (" %d"):format(index)
    local candidate = leafName:sub(1, 64 - #suffix) .. suffix
    local filename = (candidate .. ".preset"):lower()
    if not used[filename] then
      used[filename] = true
      return candidate
    end
  end
  return nil
end

function validatedFolderName(value)
  local name, nameError = validatedPresetName(value)
  if not name then
    nameError = nameError:gsub("Preset names", "Folder names")
      :gsub("preset name", "folder name")
      :gsub("filename", "folder name")
    return nil, nameError
  end
  return name
end

return _ENV
