local paths = require("modules/domain/paths")
local parentFolder = paths.parentFolder
local baseName = paths.baseName
local NAME_SORT = "name"
local MODIFIED_SORT = "modified"

local function normalizeSort(value)
  return value == MODIFIED_SORT and MODIFIED_SORT or NAME_SORT
end

local function breadcrumb(name)
  if not name or name == "" then return "All Presets" end
  return (name:gsub("/", " > "))
end

local function normalizeSearch(query)
  return tostring(query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
end

local function textMatches(value, query)
  return query == "" or tostring(value or ""):lower():find(query, 1, true) ~= nil
end

local function validModifiedTimestamp(value)
  local year, month, day, hour, minute, second = tostring(value or "")
    :match("^(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d):(%d%d)$")
  year, month, day = tonumber(year), tonumber(month), tonumber(day)
  hour, minute, second = tonumber(hour), tonumber(minute), tonumber(second)
  return year ~= nil and year >= 2000 and month >= 1 and month <= 12
    and day >= 1 and day <= 31 and hour >= 0 and hour <= 23
    and minute >= 0 and minute <= 59 and second >= 0 and second <= 59
end

local function buildView(presets, folders, sortMode)
  local presetNames = {}
  local folderNames = {}
  local presetsByFolder = {}
  local folderPresetCounts = {}
  for name in pairs(presets) do
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
  for name in pairs(folders) do table.insert(folderNames, name) end
  local function presetLess(a, b)
    if sortMode == MODIFIED_SORT then
      local aValue = tostring((presets[a] or {}).modified or "")
      local bValue = tostring((presets[b] or {}).modified or "")
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
  return presetNames, folderNames, presetsByFolder, folderPresetCounts
end

local function buildFiltered(presets, presetNames, folderNames, searchText)
  local query = normalizeSearch(searchText)
  local visibleNames = {}
  local matchedFolders = {}
  local folderMatches = {}
  local matchingByFolder = {}
  for _, name in ipairs(presetNames) do
    local preset = presets[name]
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
  for _, folder in ipairs(folderNames) do
    if textMatches(folder, query) then folderMatches[folder] = true end
  end
  return query, query ~= "", visibleNames, matchedFolders, folderMatches, matchingByFolder
end

return {normalizeSort = normalizeSort, breadcrumb = breadcrumb, normalizeSearch = normalizeSearch, textMatches = textMatches,
  validModifiedTimestamp = validModifiedTimestamp, buildView = buildView, buildFiltered = buildFiltered}
