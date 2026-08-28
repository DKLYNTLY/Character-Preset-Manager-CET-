local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime
local nativeQuery = ""

local function cleanField(value)
  return tostring(value or ""):gsub("[%c]", " ")
end

local function bridgeCall(method, ...)
  local bridge = state.app.nativeBridge
  if not bridge then return false, nil end
  local methodOk, callable = pcall(function() return bridge[method] end)
  if not methodOk or not callable then return false, nil end
  local ok, result = pcall(callable, bridge, ...)
  if not ok then
    log("[NATIVE PANEL] Bridge call failed: " .. tostring(method) .. " " .. tostring(result), "warn")
    state.app.nativeBridge = nil
  end
  return ok, result
end

local function findNativeBridge()
  local ok, container = pcall(Game.GetScriptableSystemsContainer)
  if not ok or not container then return nil end
  for _, name in ipairs({ "CPM.NativeBridge", "NativeBridge" }) do
    local foundOk, bridge = pcall(container.Get, container, name)
    if foundOk and bridge then return bridge end
  end
  return nil
end

local function nativeStatus(message, isError)
  state.app.nativePanelStatus = tostring(message or "")
  state.app.nativePanelStatusError = isError == true
  return isError and "error" or "status", cleanField(message)
end

local function listPayload(query, overrideMessage, overrideError)
  query = tostring(query or ""):lower()
  local lines = {}
  local names = helpers.sortedPresetNames()
  local selected = state.library.selected and state.library.presets[state.library.selected]
  if selected then selected = hydrateNamedPresetMetadata(state.library.selected) or selected end
  lines[#lines + 1] = table.concat({
    "SELECTED", cleanField(state.library.selected),
    cleanField(selected and selected.notes), cleanField(selected and selected.tags),
    tostring(state.presetEntryCount(selected)),
    selected and selected.favorite == true and "1" or "0",
  }, "\t")
  local message = tostring(state.app.nativePanelStatus or "")
  local isError = state.app.nativePanelStatusError == true
  if overrideMessage ~= nil then
    message = tostring(overrideMessage or "")
    isError = overrideError == true
    state.app.nativePanelStatus = message
    state.app.nativePanelStatusError = isError
  end
  lines[#lines + 1] = table.concat({ "STATUS", isError and "1" or "0",
    cleanField(message), state.load.auto and "1" or "0" }, "\t")
  lines[#lines + 1] = "CONFIRM\tSAVE\t" ..
    (state.library.pendingOverwriteName ~= nil and "1" or "0")
  lines[#lines + 1] = "CONFIRM\tTRASH\t" ..
    (state.library.selected ~= nil
      and state.trash.nativePendingDeleteName == state.library.selected and "1" or "0")
  local visibleNames = {}
  local matchedFolders = {}
  for _, name in ipairs(names) do
    local preset = state.library.presets[name]
    local metadata = preset and (hydrateNamedPresetMetadata(name) or preset)
    local haystack = (name .. " " .. tostring(metadata and metadata.tags or "")):lower()
    if query == "" or haystack:find(query, 1, true) then
      visibleNames[name] = true
      local current = parentFolder(name)
      while current ~= "" do
        matchedFolders[current] = true
        current = parentFolder(current)
      end
    end
  end
  local added = 0
  local function addRow(kind, value, label)
    if added >= NATIVE_LIST_LIMIT then return false end
    lines[#lines + 1] = table.concat({
      "ROW", kind, cleanField(value), cleanField(label),
    }, "\t")
    added = added + 1
    return true
  end
  local favoriteHeadingAdded = false
  for _, name in ipairs(names) do
    local preset = state.library.presets[name]
    if preset and preset.favorite == true and visibleNames[name] then
      if not favoriteHeadingAdded then
        addRow("HEADING", "", "FAVORITES")
        favoriteHeadingAdded = true
      end
      if not addRow("PRESET", name, helpers.breadcrumb(name)) then break end
    end
  end
  for _, folder in ipairs(sortedFolderNames()) do
    local count = state.cache.folderPresetCounts[folder] or 0
    local folderMatches = query == "" or folder:lower():find(query, 1, true) ~= nil
    if count > 0 and (folderMatches or matchedFolders[folder]) then
      local expanded = state.library.expandedLoadFolders[folder] == true
      local prefix = string.rep("  ", folderDepth(folder)) .. (expanded and "[-] " or "[+] ")
      if not addRow("FOLDER", folder,
          prefix .. baseName(folder) .. " (" .. tostring(count) .. ")") then break end
      if expanded or query ~= "" then
        for _, name in ipairs(helpers.presetsInFolder(folder)) do
          if folderMatches or visibleNames[name] then
            local metadata = state.library.presets[name]
            local tags = tostring(metadata and metadata.tags or "")
            local label = string.rep("  ", folderDepth(folder) + 1) .. baseName(name)
            if tags ~= "" then label = label .. "  -  " .. tags end
            if not addRow("PRESET", name, label) then break end
          end
        end
      end
    end
    if added >= NATIVE_LIST_LIMIT then break end
  end
  if added < NATIVE_LIST_LIMIT then
    for _, name in ipairs(helpers.presetsInFolder("")) do
      if visibleNames[name] and not addRow("PRESET", name, name) then break end
    end
  end
  lines[#lines + 1] = table.concat({ "LOCATION", "",
    state.library.selectedFolder == "" and "1" or "0" }, "\t")
  for _, folder in ipairs(sortedFolderNames()) do
    lines[#lines + 1] = table.concat({ "LOCATION", cleanField(folder),
      state.library.selectedFolder == folder and "1" or "0" }, "\t")
  end
  lines[#lines + 1] = "COUNT\t" .. tostring(added)
  return table.concat(lines, "\n")
end

local function comparisonPayload()
  local result = compareSelectedPreset()
  if not result then return "ERROR\tOpen a customization screen and select a preset first." end
  local lines = { table.concat({ "SUMMARY", result.matching, result.changing,
    result.missing, result.ambiguous, result.invalid, result.clearing }, "\t") }
  for _, detail in ipairs(result.details) do
    lines[#lines + 1] = table.concat({ "DETAIL", cleanField(detail.status),
      cleanField(detail.label), cleanField(detail.slot),
      tostring(detail.current or ""), tostring(detail.target or "") }, "\t")
  end
  return table.concat(lines, "\n")
end

local function historyPayload()
  refreshAppearanceHistory()
  local lines = {}
  for visibleIndex, entry in ipairs(state.history.entries) do
    lines[#lines + 1] = table.concat({ "HISTORY", visibleIndex,
      cleanField(entry.date), tostring(entry.count), cleanField(entry.action) }, "\t")
  end
  if #lines == 0 then lines[1] = "EMPTY\tNo appearance history is available yet." end
  return table.concat(lines, "\n")
end

local function startSelectedLoad()
  if not state.library.selected then return false, "Select a preset first." end
  if not state.app.inCustomization then return false, "Open a customization screen first." end
  resetLoadState()
  state.load.autoTimer = 0
  state.load.autoPasses = 0
  state.load.resetBefore = true
  loadPreset()
  if state.load.needsContinue then state.load.auto = true end
  return true, state.status.sections.load.message
end

local function handleNativeRequest(action, payload)
  if action == "open" then
    nativeQuery = ""
    return "list", listPayload(nativeQuery, NATIVE_READY_STATUS, false)
  end
  if action == "list" then
    nativeQuery = tostring(payload or "")
    return "list", listPayload(nativeQuery)
  end
  if action == "select" then
    if state.library.presets[payload] then
      state.library.selected = payload
      state.invalidatePreflight()
      cancelConfirmations()
      resetLoadState()
    end
    return "list", listPayload(nativeQuery)
  end
  if action == "select_load" then
    if not state.library.presets[payload] then
      return nativeStatus("That preset is no longer available.", true)
    end
    state.library.selected = payload
    state.invalidatePreflight()
    cancelConfirmations()
    resetLoadState()
    local started, message = startSelectedLoad()
    return nativeStatus(message, not started)
  end
  if action == "toggle_folder" then
    if folderNameExists(payload) then
      state.library.expandedLoadFolders[payload] =
        state.library.expandedLoadFolders[payload] ~= true
      return "list", listPayload(nativeQuery)
    end
    return "list", listPayload(nativeQuery,
      "That folder is no longer available. Open CET to refresh the list.", true)
  end
  if action == "cancel_save_confirmation" then
    state.library.pendingOverwriteName = nil
    state.library.pendingOverwriteFingerprint = nil
    return "confirm_state", "SAVE\t0"
  end
  if action == "save" then
    state.library.newName = payload
    savePreset(state.library.pendingOverwriteName ~= nil)
    local status = state.status.sections.create
    return "list", listPayload(nativeQuery, status.message, status.error)
  end
  if action == "replace" then
    if not state.library.selected then return "status", "Select a preset first." end
    state.library.newName = baseName(state.library.selected)
    state.library.selectedFolder = parentFolder(state.library.selected)
    savePreset(false)
    savePreset(true)
    return "list", listPayload("")
  end
  if action == "load" then
    local started, message = startSelectedLoad()
    return nativeStatus(message, not started)
  end
  if action == "compare" then return "comparison", comparisonPayload() end
  if action == "favorite" then
    toggleSelectedPresetFavorite()
    return "list", listPayload("")
  end
  if action == "save_location" then
    if payload == "" or folderNameExists(payload) then
      state.library.selectedFolder = payload
      cancelConfirmations()
      return "list", listPayload(nativeQuery)
    end
    return nativeStatus("That save location is no longer available. Open CET to refresh folders.", true)
  end
  if action == "delete" then
    if not state.library.selected then return nativeStatus("Select a preset first.", true) end
    trashPreset("native")
    local status = state.status.sections.delete
    local message = tostring(status.message or "")
    if status.error ~= true then
      message = message .. (state.trash.nativePendingDeleteName ~= nil
        and " After moving it, open CET to restore it or delete it permanently."
        or " Open CET to restore it or delete it permanently.")
    end
    return "list", listPayload(nativeQuery, message, status.error)
  end
  if action == "refresh" then
    refreshPresets("external")
    refreshTrash()
    return "list", listPayload("")
  end
  if action == "history" then return "history", historyPayload() end
  if action == "restore_history" then
    restoreAppearanceHistory(tonumber(payload))
    return nativeStatus(state.status.sections.load.message,
      state.status.sections.load.error == true)
  end
  if action == "restore_previous" then
    restoreLastAppearance()
    return nativeStatus(state.status.sections.load.message,
      state.status.sections.load.error == true)
  end
  if action == "clear_history" then
    local cleared, message = clearAppearanceHistory(payload == "confirm")
    return cleared and "history" or "confirm_clear", cleared and historyPayload() or message
  end
  if action == "open_advanced" then
    state.app.windowOpen = true
    return "status", "Press your CET binding, then go to the Character Preset Manager menu located on the right."
  end
  return nativeStatus("The native panel sent an unsupported request.", true)
end

setPresetSortPreference = function(value)
  local sort = value == "modified" and "modified" or "name"
  state.preferences.presetSort = sort
  state.library.sortMode = sort
  invalidateViewCache()
  writeConfig()
  state.status.settings = sort == "modified"
    and "Presets are sorted by the date they were last changed."
    or "Presets are sorted by name."
end

initializeNativeBridge = function(configLoaded)
  state.app.nativeBridge = findNativeBridge()
  if not state.app.nativeBridge then
    if not state.app.nativeBridgeUnavailableLogged then
      log("[NATIVE PANEL] Native bridge is unavailable. The CET interface remains available.", "warn")
      state.app.nativeBridgeUnavailableLogged = true
    end
    return false
  end
  state.app.nativeBridgeUnavailableLogged = false
  state.app.nativeBridgeRetryTimer = 0
  local readyOk = bridgeCall("SetLuaReady", true, VERSION, NATIVE_BRIDGE_PROTOCOL)
  if not readyOk then return false end
  local sequenceOk, sequence = bridgeCall("GetRequestSequence")
  state.app.nativeBridgeSequence = sequenceOk
    and math.max(0, tonumber(sequence) or 0) or 0
  state.app.nativeListRevision = -1
  state.app.nativeListSelection = nil
  log("[NATIVE PANEL] Native bridge connected.", "info")
  return true
end

updateNativeBridge = function(delta)
  if not state.app.ready then return end
  if not state.app.nativeBridge then
    state.app.nativeBridgeRetryTimer = state.app.nativeBridgeRetryTimer
      + math.max(0, tonumber(delta) or 0)
    if state.app.nativeBridgeRetryTimer < 2 then return end
    state.app.nativeBridgeRetryTimer = 0
    if not initializeNativeBridge(true) then return end
  end
  local elapsed = math.max(0, tonumber(delta) or 0)
  local busy = state.load.auto or state.load.needsContinue
  local wasBusy = state.app.nativeBusy == true
  local status = busy and ("Loading pass " .. tostring(state.load.pass) .. "...") or ""
  local statusError = false
  if not busy and wasBusy then
    status = tostring(state.status.sections.load.message or "")
    statusError = state.status.sections.load.error == true
    state.app.nativePanelStatus = status
    state.app.nativePanelStatusError = statusError
  end
  if state.app.nativeBusy ~= busy or (busy and state.app.nativeStatus ~= status)
      or (not busy and wasBusy) then
    bridgeCall("SetBusy", busy, status, statusError)
    state.app.nativeBusy = busy
    state.app.nativeStatus = status
    state.app.nativeStatusError = statusError
  end
  local listSelection = tostring(state.library.selected or "") .. "\31" ..
    tostring(state.trash.nativePendingDeleteName or "") .. "\31" ..
    tostring(state.library.selectedFolder or "")
  if state.app.nativeListRevision ~= state.cache.revision
      or state.app.nativeListSelection ~= listSelection then
    local panelsOk, hasPanels = bridgeCall("HasPanels")
    if panelsOk and hasPanels then
      bridgeCall("Sync", "list", listPayload(nativeQuery), busy)
    end
    state.app.nativeListRevision = state.cache.revision
    state.app.nativeListSelection = listSelection
  end
  state.app.nativeRequestPollTimer = state.app.nativeRequestPollTimer + elapsed
  if state.app.nativeRequestPollTimer < NATIVE_REQUEST_POLL_SECONDS then return end
  state.app.nativeRequestPollTimer = 0
  local ok, sequence = bridgeCall("GetRequestSequence")
  sequence = ok and tonumber(sequence) or 0
  if sequence <= state.app.nativeBridgeSequence then return end
  local actionOk, action = bridgeCall("GetRequestAction")
  local payloadOk, payload = bridgeCall("GetRequestPayload")
  state.app.nativeBridgeSequence = sequence
  local responseKind, responsePayload = "error", "The native request could not be read."
  if actionOk and payloadOk then
    local handled, kind, data = pcall(handleNativeRequest,
      tostring(action or ""), tostring(payload or ""))
    if handled then responseKind, responsePayload = kind, data
    else
      responseKind = "error"
      responsePayload = "The native request failed safely. Use the CET interface."
      log("[NATIVE PANEL] Request failed: " .. tostring(kind), "error")
    end
  end
  bridgeCall("Respond", sequence, responseKind, responsePayload,
    state.load.auto or state.load.needsContinue)
end

return _ENV
