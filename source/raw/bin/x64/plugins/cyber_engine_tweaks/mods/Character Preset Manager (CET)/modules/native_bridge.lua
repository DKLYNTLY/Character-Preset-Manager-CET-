local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

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

local function selectedStatus()
  for _, section in ipairs({ "load", "create", "delete", "rename" }) do
    local status = state.status.sections[section]
    if status and tostring(status.message or "") ~= "" then
      return status.message, status.error == true
    end
  end
  return "Ready.", false
end

local function listPayload(query)
  query = tostring(query or ""):lower()
  local lines = {}
  local selected = state.library.selected and state.library.presets[state.library.selected]
  if selected then selected = hydrateNamedPresetMetadata(state.library.selected) or selected end
  lines[#lines + 1] = table.concat({
    "SELECTED", cleanField(state.library.selected),
    cleanField(selected and selected.notes), cleanField(selected and selected.tags),
    tostring(state.presetEntryCount(selected)),
    selected and selected.favorite == true and "1" or "0",
  }, "\t")
  local message, isError = selectedStatus()
  lines[#lines + 1] = table.concat({ "STATUS", isError and "1" or "0",
    cleanField(message), state.load.auto and "1" or "0" }, "\t")
  local added = 0
  for _, name in ipairs(helpers.sortedPresetNames()) do
    local preset = state.library.presets[name]
    local metadata = preset and (hydrateNamedPresetMetadata(name) or preset)
    local haystack = (name .. " " .. tostring(metadata and metadata.tags or "")):lower()
    if query == "" or haystack:find(query, 1, true) then
      lines[#lines + 1] = table.concat({
        "PRESET", cleanField(name),
        metadata and metadata.favorite == true and "1" or "0",
        tostring(state.presetEntryCount(metadata)),
        cleanField(metadata and metadata.modified),
        cleanField(metadata and metadata.tags),
      }, "\t")
      added = added + 1
      if added >= NATIVE_LIST_LIMIT then break end
    end
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
  local warnings = {}
  local comparison = compareSelectedPreset()
  if state.preferences.missingWarnings and comparison
      and comparison.missing + comparison.ambiguous + comparison.invalid > 0 then
    warnings[#warnings + 1] = ("%d missing, repeated, uncertain, or invalid option%s")
      :format(comparison.missing + comparison.ambiguous + comparison.invalid,
        comparison.missing + comparison.ambiguous + comparison.invalid == 1 and "" or "s")
  end
  local clothingActive = false
  if state.preferences.clothingWarning and not state.editor.newGameCharacterCreator then
    clothingActive = helpers.activeWardrobeSetEquipped()
    if clothingActive then warnings[#warnings + 1] = "an active clothing outfit" end
  end
  if #warnings > 0 and state.load.nativeWarningPreset ~= state.library.selected then
    state.load.nativeWarningPreset = state.library.selected
    return false, "Review " .. table.concat(warnings, " and ") ..
      ". Select Load Selected again to continue."
  end
  state.load.nativeWarningPreset = nil
  resetLoadState()
  state.load.autoTimer = 0
  state.load.autoPasses = 0
  state.load.resetBefore = true
  loadPreset()
  if state.load.needsContinue then state.load.auto = true end
  return true, state.status.sections.load.message
end

local function handleNativeRequest(action, payload)
  if action == "list" then return "list", listPayload(payload) end
  if action == "select" then
    if state.library.presets[payload] then
      state.library.selected = payload
      state.invalidatePreflight()
      cancelConfirmations()
      resetLoadState()
    end
    return "list", listPayload("")
  end
  if action == "save" then
    state.library.newName = payload
    savePreset(false)
    return "list", listPayload("")
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
    local _, message = startSelectedLoad()
    return "status", cleanField(message)
  end
  if action == "compare" then return "comparison", comparisonPayload() end
  if action == "favorite" then
    toggleSelectedPresetFavorite()
    return "list", listPayload("")
  end
  if action == "delete" then
    trashPreset()
    return "list", listPayload("")
  end
  if action == "refresh" then
    refreshPresets("external")
    refreshTrash()
    return "list", listPayload("")
  end
  if action == "history" then return "history", historyPayload() end
  if action == "restore_history" then
    restoreAppearanceHistory(tonumber(payload))
    return "status", cleanField(state.status.sections.load.message)
  end
  if action == "restore_previous" then
    restoreLastAppearance()
    return "status", cleanField(state.status.sections.load.message)
  end
  if action == "clear_history" then
    local cleared, message = clearAppearanceHistory(payload == "confirm")
    return cleared and "history" or "confirm_clear", cleared and historyPayload() or message
  end
  if action == "open_advanced" then
    state.app.windowOpen = true
    return "status", "Open the CET overlay to use the advanced preset manager."
  end
  return "status", "The native panel sent an unsupported request."
end

local function syncNativePreferences()
  local ok, revision = bridgeCall("GetConfigRevision")
  revision = ok and tonumber(revision) or nil
  if not revision or revision == state.preferences.nativeRevision then return end
  local getters = {
    nativePanel = "GetNativePanel",
    customizationReminder = "GetCustomizationReminder",
    historySize = "GetHistorySize",
    saveBeforeHistoryRestore = "GetSaveBeforeHistoryRestore",
    comparisonDetails = "GetComparisonDetails",
    missingWarnings = "GetMissingWarnings",
    clothingWarning = "GetClothingWarning",
    cetFallback = "GetCetFallback",
  }
  for key, getter in pairs(getters) do
    local valueOk, value = bridgeCall(getter)
    if valueOk then state.preferences[key] = key == "historySize"
      and tonumber(value) or value == true end
  end
  local sortOk, sort = bridgeCall("GetPresetSort")
  local detailOk, detail = bridgeCall("GetActivityLogDetail")
  state.preferences.presetSort = sortOk and tonumber(sort) == 1 and "modified" or "name"
  state.preferences.activityLogDetail = detailOk and tonumber(detail) == 1
    and "technical" or "normal"
  state.preferences.nativeRevision = revision
  state.library.sortMode = state.preferences.presetSort
  state.ui.discoveryNoticeIgnored = not state.preferences.customizationReminder
  invalidateViewCache()
  trimAppearanceHistory()
  writeConfig()
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
  bridgeCall("ImportLegacyConfig", state.preferences.customizationReminder,
    state.preferences.presetSort == "modified")
  bridgeCall("SetLuaReady", true, VERSION, NATIVE_BRIDGE_PROTOCOL)
  syncNativePreferences()
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
  syncNativePreferences()
  local busy = state.load.auto or state.load.needsContinue
  local status = busy and ("Loading pass " .. tostring(state.load.pass) .. "...")
    or tostring(state.status.sections.load.message or "")
  if state.app.nativeBusy ~= busy or state.app.nativeStatus ~= status then
    bridgeCall("SetBusy", busy, status)
    state.app.nativeBusy = busy
    state.app.nativeStatus = status
  end
  local ok, sequence = bridgeCall("GetRequestSequence")
  sequence = ok and tonumber(sequence) or 0
  if sequence <= state.app.nativeBridgeSequence then return end
  local actionOk, action = bridgeCall("GetRequestAction")
  local payloadOk, payload = bridgeCall("GetRequestPayload")
  state.app.nativeBridgeSequence = sequence
  local responseKind, responsePayload = "status", "The native request could not be read."
  if actionOk and payloadOk then
    local handled, kind, data = pcall(handleNativeRequest,
      tostring(action or ""), tostring(payload or ""))
    if handled then responseKind, responsePayload = kind, data
    else
      responsePayload = "The native request failed safely. Use the CET interface."
      log("[NATIVE PANEL] Request failed: " .. tostring(kind), "error")
    end
  end
  bridgeCall("Respond", sequence, responseKind, responsePayload,
    state.load.auto or state.load.needsContinue)
end

return _ENV
