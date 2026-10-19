local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

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
  state.cache.filteredViewDirty = true
  state.trash.cachedBulkFolder = nil
end

function invalidateBulkSelectionCache()
  state.trash.bulkSelectionDirty = true
end

function invalidateViewCache()
  state.cache.revision = (state.cache.revision or 0) + 1
  state.cache.viewDirty = true
  invalidateFilteredViewCache()
  invalidateBulkSelectionCache()
  if state.invalidatePreflight then state.invalidatePreflight() end
end

function invalidatePresetAndTrashCaches()
  invalidateViewCache()
  if state.invalidateTrashViewCache then state.invalidateTrashViewCache() end
end

helpers.releaseViewCaches = function()
  state.cache.presetNames = {}
  state.cache.folderNames = {}
  state.cache.presetsByFolder = {}
  state.cache.folderPresetCounts = {}
  state.cache.filteredPresetNames = {}
  state.cache.matchedFolders = {}
  state.cache.matchingPresetsByFolder = {}
  state.cache.folderMatches = {}
  state.cache.searchText = nil
  state.cache.queryActive = false
  state.cache.viewDirty = true
  state.cache.filteredViewDirty = true
  state.cache.folderBundleFiles = {}
  state.cache.folderBundleFilesDirty = true
  state.library.folderBundlePreview = nil
  state.trash.cachedNames = {}
  state.trash.cachedGroupIds = {}
  state.trash.cachedBundleNames = {}
  state.trash.cachedGroupStats = {}
  state.trash.cachedBulkSelectedNames = {}
  state.trash.cachedBulkFolder = nil
  state.trash.cachedBulkFolderNames = {}
  state.trash.cachedBulkNestedFolderCount = 0
  state.trash.viewDirty = true
  state.trash.bulkSelectionDirty = true
end

function ensureViewCache() end

EMPTY_LIST = {}

helpers.sortedPresetNames = function()
  ensureViewCache()
  return state.cache.presetNames
end

function sortedFolderNames()
  ensureViewCache()
  return state.cache.folderNames
end

helpers.presetsInFolder = function(folder)
  ensureViewCache()
  return state.cache.presetsByFolder[folder] or EMPTY_LIST
end

function ensureFilteredViewCache() end

helpers.filteredPresetNames = function()
  ensureFilteredViewCache()
  return state.cache.filteredPresetNames
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
  for existing in pairs(state.library.presets) do
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
