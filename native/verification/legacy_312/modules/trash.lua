local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

state.invalidateTrashViewCache = function()
  state.trash.viewDirty = true
end

state.ensureTrashViewCache = function() end

bulkPresetNamesInFolder = function(folder)
  state.trash.cachedBulkNestedFolderCount = (state.cache.folderNestedCounts or {})[folder] or 0
  if folder == "" then return state.cache.presetsByFolder[""] or EMPTY_LIST end
  return (state.cache.treePresetsByFolder or {})[folder] or EMPTY_LIST
end

selectedBulkPresetNames = function()
  if not state.trash.bulkSelectionDirty then return state.trash.cachedBulkSelectedNames end
  local names = {}
  for _, name in ipairs(state.cache.presetNames) do
    if state.trash.bulkSelected[name] then names[#names + 1] = name end
  end
  state.trash.cachedBulkSelectedNames = names
  state.trash.bulkSelectionDirty = false
  return names
end

return _ENV