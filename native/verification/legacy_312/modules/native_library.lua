local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

nativeLibrary = {generation = 0, pending = nil, busy = false, revision = 0}

function nativeLibrary.cancelView()
  nativeLibrary.generation = nativeLibrary.generation + 1
  if nativeLibrary.pending then nativeService.cancel(nativeLibrary.pending) end
  nativeLibrary.pending = nil
  nativeLibrary.busy = false
end

function nativeLibrary.requestView(query, sort, callback)
  nativeLibrary.cancelView()
  local generation = nativeLibrary.generation
  local session = nativeService.session
  local staged = {
    presets = {}, folders = {}, presetNames = {}, folderNames = {}, presetsByFolder = {},
    folderPresetCounts = {}, filteredPresetNames = {}, matchedFolders = {},
    matchingPresetsByFolder = {}, folderMatches = {},
    treePresetsByFolder = {}, folderNestedCounts = {}, manualFolders = {},
  }
  local revision, total, folderTotal
  nativeLibrary.busy = true
  local function finish(message)
    nativeLibrary.pending = nil
    nativeLibrary.busy = false
    if callback then callback(message == nil, message) end
  end
  local requestPage
  requestPage = function()
    local offset, folderOffset = #staged.presetNames, #staged.folderNames
    local operation, errorText = nativeService.submit("view", {
      query = query or "", sort = sort or "name", revision = revision,
      offset = offset, folderOffset = folderOffset, limit = 128,
    }, function(status, result)
      if generation ~= nativeLibrary.generation or session ~= nativeService.session then return end
      nativeLibrary.pending = nil
      if status ~= "complete" then
        finish(result and result.error or "The preset list could not be read. Refresh and try again.")
        return
      end
      if type(result) ~= "table" or type(result.rows) ~= "table" or type(result.folderRows) ~= "table"
          or type(result.revision) ~= "number" or type(result.total) ~= "number"
          or type(result.folderTotal) ~= "number" or result.total > 8192 or result.folderTotal > 32768
          or result.offset ~= offset or result.folderOffset ~= folderOffset
          or (revision and result.revision ~= revision)
          or (total and result.total ~= total) or (folderTotal and result.folderTotal ~= folderTotal) then
        finish("The preset list changed while it was being read. Refresh and try again.")
        return
      end
      revision, total, folderTotal = result.revision, result.total, result.folderTotal
      for _, row in ipairs(result.rows) do
        if type(row.name) ~= "string" or type(row.preset) ~= "table"
            or type(row.folder) ~= "string" or staged.presets[row.name] then
          finish("The preset list contains an invalid entry. Refresh and try again.")
          return
        end
        staged.presets[row.name] = row.preset
        staged.presetNames[#staged.presetNames + 1] = row.name
        local names = staged.presetsByFolder[row.folder] or {}
        names[#names + 1] = row.name
        staged.presetsByFolder[row.folder] = names
        for _, folder in ipairs(row.ancestors or {}) do
          local tree = staged.treePresetsByFolder[folder] or {}
          tree[#tree + 1] = row.name
          staged.treePresetsByFolder[folder] = tree
        end
        if row.matches then
          staged.filteredPresetNames[#staged.filteredPresetNames + 1] = row.name
          local matches = staged.matchingPresetsByFolder[row.folder] or {}
          matches[#matches + 1] = row.name
          staged.matchingPresetsByFolder[row.folder] = matches
        end
      end
      for _, row in ipairs(result.folderRows) do
        if type(row.name) ~= "string" or type(row.count) ~= "number"
            or type(row.matching) ~= "number" or staged.folders[row.name] then
          finish("The folder list contains an invalid entry. Refresh and try again.")
          return
        end
        staged.folders[row.name] = true
        if row.manual then staged.manualFolders[row.name] = true end
        staged.folderNames[#staged.folderNames + 1] = row.name
        staged.folderPresetCounts[row.name] = row.count
        staged.folderNestedCounts[row.name] = row.nested or 0
        if row.matching > 0 then staged.matchedFolders[row.name] = true end
        if row.matches then staged.folderMatches[row.name] = true end
      end
      if #staged.presetNames > total or #staged.folderNames > folderTotal
          or (offset < total and #result.rows == 0)
          or (folderOffset < folderTotal and #result.folderRows == 0) then
        finish("The preset list could not be completed. Refresh and try again.")
        return
      end
      if #staged.presetNames < total or #staged.folderNames < folderTotal then
        requestPage()
        return
      end
      state.library.presets = staged.presets
      state.library.folders = staged.folders
      state.library.manualFolders = staged.manualFolders
      state.trash.bulkSelectionDirty = true
      state.trash.cachedBulkFolder = nil
      for _, key in ipairs({"presetNames", "folderNames", "presetsByFolder", "folderPresetCounts",
          "filteredPresetNames", "matchedFolders", "matchingPresetsByFolder", "folderMatches",
          "treePresetsByFolder", "folderNestedCounts"}) do
        state.cache[key] = staged[key]
      end
      state.cache.searchText = result.query
      state.cache.queryActive = result.query ~= ""
      state.cache.viewDirty = false
      state.cache.filteredViewDirty = false
      state.cache.revision = (state.cache.revision or 0) + 1
      nativeLibrary.revision = revision
      if state.library.selected and not staged.presets[state.library.selected] then
        state.library.selected = nil
      end
      if state.invalidatePreflight then state.invalidatePreflight() end
      finish()
    end)
    if operation then nativeLibrary.pending = operation else finish(errorText) end
  end
  requestPage()
end

return _ENV
