local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime
local commandAdapter = require("modules/ui/commands").forRuntime(runtime)
local codecs = require("modules/domain/codecs")
local nativeQuery = ""
local nativeViewRevision = 0
local nativeRowsCacheKey = nil
local nativeRowsCache = {}
local nativeRowsCount = 0
local nativeLocationsRevision = -1
local nativeLocationsCache = {}
local overlayRequestPath = CONFIG_DIR .. "/CET Overlay Request.txt"
local overlayResultPath = CONFIG_DIR .. "/CET Overlay Result.txt"
local overlayRequestCounter = 0
local overlayRequest = nil
local overlayFallback = "CET did not open. Press your CET binding to show Character Preset Manager."
local bridgeCall

local function writeOverlayRequest(id, action)
  return writeFileSafely(overlayRequestPath, "w", function(file)
    return file:write(id .. "\t" .. action) ~= nil
  end)
end

helpers.finishOverlayRequest = function()
  if overlayRequest then
    writeOverlayRequest(overlayRequest.id, "cancel")
    overlayRequest = nil
  end
end

helpers.updateOverlayRequest = function(delta)
  if not overlayRequest then return end
  if state.app.overlayOpen then
    helpers.finishOverlayRequest()
    return
  end
  overlayRequest.elapsed = overlayRequest.elapsed + math.max(0, tonumber(delta) or 0)
  local result = readBoundedFile(overlayResultPath, 256)
  local id, status = tostring(result or ""):match("^([%d%-]+)\t([%a%-]+)$")
  if (id == overlayRequest.id and status ~= "sent") or overlayRequest.elapsed >= 3 then
    helpers.finishOverlayRequest()
    state.app.nativePanelStatus = overlayFallback
    state.app.nativePanelStatusError = true
    bridgeCall("SetBusy", false, overlayFallback, true)
    log("[NATIVE PANEL] " .. overlayFallback, "warn")
  end
end

local function cleanField(value)
  return codecs.cleanField(value)
end

bridgeCall = function(method, ...)
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

helpers.finishTimedOutNativeLoad = function(message)
  state.app.nativeLoadSummary = nil
  state.app.nativePanelStatus = message
  state.app.nativePanelStatusError = true
  state.app.nativePanelShowDetails = true
  bridgeCall("SetBusy", false, message, true)
  state.app.nativeBusy = false
  state.app.nativeStatus = message
  state.app.nativeStatusError = true
end

local function findNativeBridge()
  local ok, container = pcall(Game.GetScriptableSystemsContainer)
  if not ok or not container then return nil end
  for _, name in ipairs({ "CPM.NativeBridge", "NativeBridge" }) do
    local identifier = name
    if CName and CName.new then
      local cnameOk, cname = pcall(CName.new, name)
      if cnameOk and cname then identifier = cname end
    end
    local foundOk, bridge = pcall(container.Get, container, identifier)
    if foundOk and bridge then return bridge end
  end
  return nil
end


local function listPayload(query, overrideMessage, overrideError)
  query = tostring(query or ""):lower()
  local lines = {}
  local names = helpers.sortedPresetNames()
  local selected = state.library.selected and state.library.presets[state.library.selected]
  lines[#lines + 1] = table.concat({
    "SELECTED", cleanField(state.library.selected),
    cleanField(selected and selected.notes), cleanField(selected and selected.tags),
    tostring(state.presetEntryCount(selected)),
    selected and selected.favorite == true and "1" or "0",
    tostring(selected and selected.format or ""),
    cleanField(helpers.breadcrumb(parentFolder(state.library.selected or ""))),
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
    cleanField(message), state.load.auto and "1" or "0",
    state.app.nativePanelShowDetails and "1" or "0" }, "\t")
  lines[#lines + 1] = "CONFIRM\tSAVE\t" ..
    (state.library.pendingOverwriteName ~= nil and "1" or "0")
  lines[#lines + 1] = "CONFIRM\tTRASH\t" ..
    (state.library.selected ~= nil
      and state.trash.nativePendingDeleteName == state.library.selected and "1" or "0")
  lines[#lines + 1] = "RECOVERY\t" ..
    (state.load.recoverySnapshotAvailable == true and "1" or "0")
  local rowsKey = table.concat({ tostring(state.cache.revision), query,
    tostring(nativeViewRevision) }, "\31")
  if nativeRowsCacheKey ~= rowsKey then
    local visibleNames = {}
    local matchedFolders = {}
    for _, name in ipairs(names) do
      local metadata = state.library.presets[name]
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
    local cachedRows = {}
    local added = 0
    local function addRow(kind, value, label)
      if added >= NATIVE_LIST_LIMIT then return false end
      cachedRows[#cachedRows + 1] = table.concat({
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
      local parentVisible = query ~= ""
        or folderAncestorsExpanded(folder, state.library.expandedLoadFolders)
      if count > 0 and parentVisible and (folderMatches or matchedFolders[folder]) then
        local expanded = state.library.expandedLoadFolders[folder] == true
        local depth = folderDepth(folder)
        local prefix = depth > 0
          and string.rep("  ", depth - 1) .. "> " or ""
        prefix = prefix .. (expanded and "[-] " or "[+] ")
        if not addRow(depth > 0 and "SUBFOLDER" or "FOLDER", folder,
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
    nativeRowsCacheKey = rowsKey
    nativeRowsCache = cachedRows
    nativeRowsCount = added
  end
  for _, row in ipairs(nativeRowsCache) do lines[#lines + 1] = row end
  if nativeLocationsRevision ~= state.cache.revision then
    local locations = { "LOCATION\t\tAll Presets" }
    for _, folder in ipairs(sortedFolderNames()) do
      locations[#locations + 1] = table.concat({
        "LOCATION", cleanField(folder), cleanField(helpers.breadcrumb(folder)),
      }, "\t")
    end
    nativeLocationsCache = locations
    nativeLocationsRevision = state.cache.revision
  end
  lines[#lines + 1] = "SELECTED_LOCATION\t" .. cleanField(state.library.selectedFolder)
  for _, location in ipairs(nativeLocationsCache) do lines[#lines + 1] = location end
  lines[#lines + 1] = "COUNT\t" .. tostring(nativeRowsCount)
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

local startSelectedLoad = commandAdapter.startSelectedLoad

canRunAppearanceRandomizer = commandAdapter.canRandomize

runAppearanceRandomizer = function(settings)
  local result = commandAdapter.run("native", settings and "randomize_settings" or "randomize", {payload = ""})
  if result.responseExtra ~= nil then
    return result.responseKind, result.responsePayload, result.responseExtra
  end
  return result.responseKind, result.responsePayload
end

local nativeCommandPorts = {
  query = function() return nativeQuery end,
  setQuery = function(value) nativeQuery = value end,
  invalidateRows = function() nativeViewRevision = nativeViewRevision + 1 end,
  listPayload = listPayload,
  comparisonPayload = comparisonPayload,
  historyPayload = historyPayload,
  openAdvanced = function()
state.app.windowOpen = true
    state.ui.focusWindowRequested = true
    if state.app.overlayOpen then return "status", "Character Preset Manager is open in CET." end
    if overlayRequest then return "status", "Opening Character Preset Manager in CET..." end
    overlayRequestCounter = overlayRequestCounter + 1
    local id = tostring(os.time()) .. "-" .. tostring(overlayRequestCounter)
    if not writeOverlayRequest(id, "open") then return "error", overlayFallback end
    overlayRequest = { id = id, elapsed = 0 }
    return "status", "Opening Character Preset Manager in CET..."
  end,
}
local function handleNativeRequest(action, payload)
  local result = commandAdapter.run("native", action, {payload = payload}, nativeCommandPorts, startSelectedLoad)
  if result.responseExtra ~= nil then
    return result.responseKind, result.responsePayload, result.responseExtra
  end
  return result.responseKind, result.responsePayload
end

initializeNativeBridge = function(configLoaded, preferredBridge)
  state.app.nativeBridge = preferredBridge or findNativeBridge()
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
  local panelsOk, hasPanels = bridgeCall("HasPanels")
  if panelsOk and hasPanels then
    bridgeCall("Sync", "list", listPayload(nativeQuery, NATIVE_READY_STATUS, false), false)
    state.app.nativeListRevision = state.cache.revision
    state.app.nativeListSelection = tostring(state.library.selected or "") .. "\31" ..
      tostring(state.trash.nativePendingDeleteName or "") .. "\31" ..
      tostring(state.library.selectedFolder or "") .. "\31" ..
      tostring(state.app.nativePanelShowDetails == true) .. "\31" ..
      tostring(state.load.recoverySnapshotAvailable == true)
  end
  log("[NATIVE PANEL] Native bridge connected.", "info")
  return true
end

connectNativeBridgeForMenu = function(menu)
  if not menu then return false end
  local ok, bridge = pcall(function() return menu:CPMGetNativeBridge() end)
  if not ok or not bridge then
    log("[NATIVE PANEL] The active appearance screen bridge could not be found.", "warn")
    return false
  end
  state.app.nativeBridge = bridge
  local connected = initializeNativeBridge(true, bridge)
  log(connected
    and "[NATIVE PANEL] Connected without reading preset files during character-screen initialization."
    or "[NATIVE PANEL] The bridge did not finish connecting.",
    connected and "info" or "warn")
  return connected
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
  local busy = state.load.auto or state.load.needsContinue or state.load.pendingChange ~= nil
  local wasBusy = state.app.nativeBusy == true
  local status = busy and ("Loading pass " .. tostring(state.load.pass) .. "...") or ""
  local statusError = false
  if not busy and wasBusy then
    status = tostring(state.app.nativeLoadSummary
      or state.status.sections.load.message or "")
    statusError = state.status.sections.load.error == true
    state.app.nativePanelStatus = status
    state.app.nativePanelStatusError = statusError
    state.app.nativePanelShowDetails = state.app.nativePanelShowDetails
      or statusError
  end
  if state.app.nativeBusy ~= busy or (busy and state.app.nativeStatus ~= status)
      or (not busy and wasBusy) then
    bridgeCall("SetBusy", busy, status, statusError)
    state.app.nativeBusy = busy
    state.app.nativeStatus = status
    state.app.nativeStatusError = statusError
  end
  if state.editor.activeBodyMorphMenu then
    pcall(function() state.editor.activeBodyMorphMenu:CPMUpdateRandomizerControls() end)
  end
  local listSelection = tostring(state.library.selected or "") .. "\31" ..
    tostring(state.trash.nativePendingDeleteName or "") .. "\31" ..
    tostring(state.library.selectedFolder or "") .. "\31" ..
    tostring(state.app.nativePanelShowDetails == true) .. "\31" ..
    tostring(state.load.recoverySnapshotAvailable == true)
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
  local responseKind, responsePayload = "error", "The simple menu's request could not be read."
  if actionOk and payloadOk then
    local handled, kind, data = pcall(handleNativeRequest,
      tostring(action or ""), tostring(payload or ""))
    if handled then responseKind, responsePayload = kind, data
    else
      responseKind = "error"
      responsePayload = "The simple menu action failed. Open CET to try it there."
      log("[NATIVE PANEL] Request failed: " .. tostring(kind), "error")
    end
  end
  bridgeCall("Respond", sequence, responseKind, responsePayload,
    state.load.auto or state.load.needsContinue or state.load.pendingChange ~= nil)
end

return _ENV
