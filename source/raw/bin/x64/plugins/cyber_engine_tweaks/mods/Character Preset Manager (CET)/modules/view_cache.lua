local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime
local names = require("modules/domain/names")
local paths = require("modules/domain/paths")
local libraryView = require("modules/domain/library_view")

function unresolvedSignature(unresolved)
  local keys = {}
  for key in pairs(unresolved) do table.insert(keys, key) end
  table.sort(keys)
  return table.concat(keys, "\30")
end

function baseName(name)
  return paths.baseName(name)
end

helpers.breadcrumb = function(name)
  return libraryView.breadcrumb(name)
end

function normalizeSearch(query)
  return libraryView.normalizeSearch(query)
end

function textMatches(value, query)
  return libraryView.textMatches(value, query)
end

function validModifiedTimestamp(value)
  return libraryView.validModifiedTimestamp(value)
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

helpers.rebuildViewCache = function()
  local presetNames, folderNames, presetsByFolder, folderPresetCounts = libraryView.buildView(
    state.library.presets, state.library.folders, state.library.sortMode)
  state.cache.presetNames = presetNames
  state.cache.folderNames = folderNames
  state.cache.presetsByFolder = presetsByFolder
  state.cache.folderPresetCounts = folderPresetCounts
  state.cache.viewDirty = false
end

function ensureViewCache()
  if state.cache.viewDirty then helpers.rebuildViewCache() end
end

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

helpers.rebuildFilteredViewCache = function()
  ensureViewCache()
  local query, queryActive, visibleNames, matchedFolders, folderMatches, matchingByFolder = libraryView.buildFiltered(
    state.library.presets, state.cache.presetNames, state.cache.folderNames, state.library.searchText)
  state.cache.searchText = query
  state.cache.queryActive = queryActive
  state.cache.filteredPresetNames = visibleNames
  state.cache.matchedFolders = matchedFolders
  state.cache.folderMatches = folderMatches
  state.cache.matchingPresetsByFolder = matchingByFolder
  state.cache.filteredViewDirty = false
end

function ensureFilteredViewCache()
  local query = normalizeSearch(state.library.searchText)
  if state.cache.filteredViewDirty or state.cache.searchText ~= query then
    helpers.rebuildFilteredViewCache()
  end
end

helpers.filteredPresetNames = function()
  ensureFilteredViewCache()
  return state.cache.filteredPresetNames
end

function joinFolder(folder, name)
  return paths.joinFolder(folder, name)
end

function isInFolderTree(path, folder)
  return paths.isInFolderTree(path, folder)
end

function addFolderAncestors(folders, folder)
  return paths.addFolderAncestors(folders, folder)
end

function findPresetCollision(name, excludeName)
  return names.findPresetCollision(name, excludeName, state.library.presets)
end

function validRelativePath(value)
  return paths.validRelativePath(value)
end

function storageFilenamesInUse()
  local entries = safeDirectoryEntries(PRESET_DIR, 0)
  if not entries then return nil end
  local used = {}
  for _, entry in ipairs(entries) do used[entry.name:lower()] = true end
  return used
end

function uniqueStorageName(leafName, used)
  return names.uniqueStorageName(leafName, used or storageFilenamesInUse())
end

function validatedFolderName(value)
  return names.validatedFolderName(value)
end

return _ENV
