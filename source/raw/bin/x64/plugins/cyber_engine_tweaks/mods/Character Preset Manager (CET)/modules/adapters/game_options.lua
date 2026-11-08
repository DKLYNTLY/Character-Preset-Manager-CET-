local loading = require("modules/application/loading")

local function install(runtime)
if setfenv then setfenv(1,runtime) end
local _ENV = runtime
local stateModel = require("modules/domain/state")
local acuBatch = require("modules/adapters/shared_load_adapter").new(runtime)
helpers.compareFormat9 = acuBatch.compare
helpers.noteAcuBatchChange = acuBatch.changed
local AUTO_LOAD_SAFETY_MARGIN = 10
local control = {}
local eventBuffers = {}
local emptyFields = {}
for kind in pairs(loading.fields) do
  eventBuffers[kind] = {kind=kind,timing=AUTO_LOAD_TIMING,limits=AUTO_LOAD_LIMITS,safetyMargin=AUTO_LOAD_SAFETY_MARGIN}
end
local reservedEventFields = {
  "elapsed","hasSelection","invocationBefore","signature","present","label","occurrence","slot","shape",
  "key","optionKey","position","target","current","identity","longSettle","changeKind","attempts","pending",
  "group","waiting","waitSeconds","accountedAt","closed","valueCount","loadName","values","savedCounts",
  "orderedEntries","savedEntryByKey","savedSlotCounts","format","threshold","selected","hasPreset","remaining",
  "optionCount","structureChanged","pendingResult","count","seconds","previous","activeKeySet","rebuild","result",
}
for _,event in pairs(eventBuffers) do
  for _,field in ipairs(reservedEventFields) do event[field] = false end
  for _,field in ipairs(reservedEventFields) do event[field] = nil end
end
for _,fields in pairs(loading.fields) do
  for _,field in ipairs(fields) do control[field] = false end
end
for _,fields in pairs(loading.appFields) do
  for _,field in ipairs(fields) do control[field] = false end
end
for field in pairs(control) do control[field] = nil end
eventBuffers.release.app = {optionsMemo=false}
local function releaseControl()
  acuBatch.reset()
  for key in pairs(control) do control[key] = nil end
  for _,event in pairs(eventBuffers) do
    for key in pairs(event) do
      if key ~= "kind" and key ~= "timing" and key ~= "limits" and key ~= "safetyMargin"
          and key ~= "stallPasses" and key ~= "app" then event[key] = nil end
    end
  end
end
local function transition(kind)
  local fields = loading.fields[kind]
  local appFields = loading.appFields[kind] or emptyFields
  for _,field in ipairs(fields) do
    control[field] = state.load[field]
  end
  for _,field in ipairs(appFields) do
    if field == "optionsMemo" then control[field] = nil else control[field] = state.app[field] end
  end
  local _,actions = loading.transition(control,eventBuffers[kind])
  for _,field in ipairs(fields) do state.load[field] = control[field] end
  for _,field in ipairs(appFields) do state.app[field] = control[field] end
  if kind == "entries" then
    local event = eventBuffers.entries
    event.values,event.savedCounts,event.orderedEntries,event.savedEntryByKey,event.savedSlotCounts = nil,nil,nil,nil,nil
  end
  if kind == "release" then releaseControl() end
  return actions[1]
end
local profile=require("modules/adapters/load_profile").new(function() return helpers.loadClock() end,log)
helpers.loadProfile=nil
local oldReset = resetLoadState
resetLoadState = function()
  profile.finish("reset")
  helpers.loadProfile=nil
  if helpers.appearanceTrace then helpers.appearanceTrace("after", "load", "reset") end
  if transition("reset") == "reset" then
    oldReset()
    releaseControl()
  end
end


state.logLoadOnce = function(key, message, level)
  key = tostring(key or message)
  if state.load.loggedWarnings[key] then return end
  state.load.loggedWarnings[key] = true
  log(message, level)
end

state.loadOptionIdentity = function(option, key, occurrence)
  local cacheKey = tostring(key or "unknown") .. "\31" .. tostring(occurrence or 1)
  local identity = state.load.optionIdentityCache[cacheKey]
  if not identity then
    identity = optionAuditIdentity(option, key, occurrence)
    state.load.optionIdentityCache[cacheKey] = identity
  end
  return identity
end

function savedEntryAuditIdentity(entry)
  local preset = state.load.overridePreset
    or state.library.presets[state.load.presetName or state.library.selected]
  local format = tonumber(preset and preset.format) or 4
  if format < 7 then
    return (" | preset format=%s | exact saved identity unknown because formats below 7 do not store an editor slot or saved choice")
      :format(tostring(format))
  end
  entry = entry or {}
  return (" | preset format=%s | saved LocKey='%s' | editor slot='%s' | saved choice='%s' | saved index=%s")
    :format(tostring(format), tostring(entry.label or "not recorded"),
      tostring(entry.slot or "not recorded"), tostring(entry.choice or "not recorded"),
      tostring(entry.index or "not recorded"))
end

helpers.loadClock = function()
  local ok, value = pcall(os.clock)
  return ok and tonumber(value) or 0
end

helpers.logLoadMeasurements = function(result)
  local current = state.load.updateStarted
    and math.max(0, helpers.loadClock() - state.load.updateStarted) or 0
  state.load.longestUpdate = math.max(state.load.longestUpdate, current)
  log(("[MEASURE] Load %s | preset='%s' | elapsed=%.3fs | option checks=%d time=%.6fs | full scans=%d time=%.6fs | dependency polls=%d time=%.6fs fallbacks=%d | choice matching=%.6fs | applied calls=%.6fs | waiting=%.3fs | dependency changes=%d | longest update=%.6fs")
    :format(tostring(result), tostring(state.load.presetName or state.library.selected),
      state.load.elapsed, state.load.optionCalls, state.load.optionsSeconds,
      state.load.scanCalls, state.load.scanSeconds, state.load.targetPolls, state.load.targetPollSeconds,
      state.load.targetFallbacks, state.load.choiceSeconds, state.load.applySeconds,
      state.load.waitSeconds, state.load.structureChanges, state.load.longestUpdate), "info")
end

helpers.releaseFinishedLoadWorkingData = function()
  transition("release")
end

helpers.forceFullLoadWarning = function(preset)
  if preset and preset.importKind == "acu-v2" then
    return "ACU version-2 imports use verified choices only. Numeric fallbacks and cleanup are disabled.", "warning"
  end
  local format = tonumber(preset and preset.format) or 4
  if format >= FORCE_FULL_LOAD_FORMAT_THRESHOLD then
    return "Force Full Load will try saved editor positions. Check the appearance after loading.",
      "warning"
  end
  return "Older preset: added options may change the hair or color. Check the appearance after loading.",
    "critical_warning"
end

helpers.syncForceFullLoadSelection = function()
  local selected = state.load.overrideName or state.library.selected
  if state.load.forceFullPresetName == selected then return end
  local preset = state.load.overridePreset
    or (selected and state.library.presets[selected] or nil)
  local format = tonumber(preset and preset.format) or 4
  local event = eventBuffers.force_selection
  event.hasPreset,event.format,event.threshold,event.selected = preset ~= nil,format,FORCE_FULL_LOAD_FORMAT_THRESHOLD,selected
  transition("force_selection")
  if preset and preset.importKind == "acu-v2" then state.load.forceFull = false end
  if selected then
    log(("[LOAD] Force Full Load selected automatically for '%s': %s (format %s).")
      :format(selected, state.load.forceFull and "on" or "off", tostring(format)), "info")
  end
end

beginLoadPass = function(preset, loadName)
  acuBatch.reset()
  if helpers.appearanceTrace then helpers.appearanceTrace("begin", "load", loadName, preset.format) end
  helpers.auditSection("LOAD PRESET")
  log(("[PRESET] Load requested: name='%s'"):format(tostring(loadName)), "load")
  eventBuffers.begin.loadName = loadName
  transition("begin")
  local values, savedCounts, orderedEntries, savedSlotCounts,
    valueCount, savedEntryByKey = helpers.preparePresetEntries(preset)
  local event = eventBuffers.entries
  event.values,event.savedCounts,event.orderedEntries = values,savedCounts,orderedEntries
  event.savedEntryByKey,event.savedSlotCounts,event.valueCount = savedEntryByKey,savedSlotCounts,valueCount
  transition("entries")
  return values, savedCounts, orderedEntries, savedSlotCounts, valueCount, savedEntryByKey
end

continueLoadPass = function(system, options, preset, values, savedCounts,
    orderedEntries, savedSlotCounts, valueCount, savedEntryByKey)
  return acuBatch.run(system, options, preset)
end

local function performPresetLoad()
  helpers.syncForceFullLoadSelection()
  local loadName = state.load.overrideName or state.library.selected
  local selectedPreset = state.load.overridePreset
  if not selectedPreset and (not state.library.selected
      or not state.library.presets[state.library.selected]) then
    resetLoadState()
    setStatus("load", "Select a preset.", true)
    return
  end
  if not selectedPreset then selectedPreset = hydrateNamedPreset(state.library.selected) end
  if not selectedPreset then
    resetLoadState()
    setStatus("load", "The selected preset could not be read safely.", true)
    return
  end
  if not helpers.presetBodyCompatible(selectedPreset,helpers.editorBody()) then
    resetLoadState()
    setStatus("load","This preset uses a different body type. Select a preset for the current body.",true)
    return
  end
  local optionsStarted = helpers.loadClock()
  local refreshCleanup = state.load.pendingChange
    and state.load.pendingChange.kind ~= "apply"
    and state.load.pendingChange.confirmedAt == nil
  local system, options, optionsError = getOptions(refreshCleanup)
  if helpers.loadProfile then helpers.loadProfile.add("optionTotal",math.max(0,helpers.loadClock()-optionsStarted)) end
  state.load.optionsSeconds = state.load.optionsSeconds
    + math.max(0, helpers.loadClock() - optionsStarted)
  state.load.optionCalls = state.load.optionCalls + 1
  if not options then
    acuBatch.reset()
    if state.load.needsContinue then
      transition("options_missing")
    end
    setStatus("load", "Open a customization screen before loading a preset.", true)
    log("[load] " .. tostring(optionsError), "warn")
    return
  end
  if selectedPreset.format ~= 9 and (selectedPreset.managedByCpm or (tonumber(selectedPreset.format) or 4) >= 5) then
    resetLoadState()
    if helpers.requestPresetUpgradeLoad then helpers.requestPresetUpgradeLoad(loadName)
    else setStatus("load","Automatic preset upgrading is not available yet.",true) end
    return
  end
  if selectedPreset.format~=9 then
    if not state.load.needsContinue or not selectedPreset.runtimeFormat9 then
      selectedPreset.runtimeFormat9=helpers.convertAcuForLoad(selectedPreset,options)
    end
    if not selectedPreset.runtimeFormat9 then
      resetLoadState()
      setStatus("load","This ACU preset could not be converted from the current catalog. Check the Activity Log and installed appearance mods.",true)
      return
    end
    selectedPreset=selectedPreset.runtimeFormat9
  end
  local preset = selectedPreset
  local values, savedCounts, orderedEntries, savedSlotCounts, valueCount, savedEntryByKey
  eventBuffers.load_request.loadName = loadName
  if transition("load_request") == "continue" then
    values = state.load.values
    savedCounts = state.load.savedCounts
    orderedEntries = state.load.orderedEntries
    savedEntryByKey = state.load.savedEntryByKey
    savedSlotCounts = state.load.savedSlotCounts
    valueCount = state.load.valueCount
  else
    if not state.load.overridePreset then
      local historyStarted=helpers.loadClock()
      saveAppearanceHistorySnapshot(options, "Before loading " .. tostring(loadName))
      if helpers.loadProfile then helpers.loadProfile.add("historySeconds",math.max(0,helpers.loadClock()-historyStarted)) end
    end
    values, savedCounts, orderedEntries, savedSlotCounts, valueCount, savedEntryByKey =
      beginLoadPass(preset, loadName)
  end
  local result = continueLoadPass(system, options, preset, values, savedCounts,
    orderedEntries, savedSlotCounts, valueCount, savedEntryByKey)
  if transition("release_gate") == "release" then
    helpers.releaseFinishedLoadWorkingData()
    state.invalidatePreflight()
  end
  return result
end

function loadPreset()
  transition("invocation")
  local started = helpers.loadClock()
  profile.begin(state.load.overrideName or state.library.selected,state.load.elapsed,state.preferences.detailedAppearanceTrace==true)
  helpers.loadProfile=profile.active() and profile or nil
  profile.enter(state.load.elapsed)
  state.load.updateStarted = started
  local previousCameraHold = state.app.presetCameraHold
  transition("camera_enter")
  local ok, result = pcall(performPresetLoad)
  eventBuffers.camera_exit.previous = previousCameraHold
  transition("camera_exit")
  state.load.longestUpdate = math.max(state.load.longestUpdate,
    math.max(0, helpers.loadClock() - started))
  profile.leave(math.max(0,helpers.loadClock()-started))
  if not ok or not state.load.needsContinue or state.load.stalled then
    profile.finish(not ok and "error" or state.load.stalled and "partial" or "returned")
    helpers.loadProfile=nil
  end
  state.load.updateStarted = nil
  if helpers.appearanceTrace and (not ok or not state.load.needsContinue or state.load.stalled) then
    helpers.appearanceTrace("after", "load", not ok and "error" or state.load.stalled and "stalled" or "returned")
  end
  if not ok then acuBatch.reset(); error(result, 0) end
  return result
end

function restoreLastAppearance()
  refreshAppearanceHistory()
  if #state.history.entries > 0 then return restoreAppearanceHistory(1) end
  local preset = readPresetFile(LAST_APPEARANCE_FILE)
  if not preset then
    state.load.recoverySnapshotAvailable = false
    setStatus("load", "No appearance recovery snapshot is available yet.", true)
    return false
  end
  resetLoadState()
  stateModel.prepareRecoveryLoad(state.load, preset, "Appearance Before Last Load")
  loadPreset()
  if state.load.needsContinue then state.load.auto = true end
  return state.load.presetName == state.load.overrideName
end

refreshPreflight = function()
  compareSelectedPreset()
end

helpers.updateAutomaticLoad = function(elapsed, invocationBefore)
  local event = eventBuffers.update
  event.elapsed,event.invocationBefore = elapsed,invocationBefore
  event.hasSelection = (state.library.selected or state.load.overridePreset) and true or false
  local nextAction = transition("update")
  if nextAction == "none" or nextAction == "stop_auto" or nextAction == "wait" then return end
  if nextAction == "timeout" then
    helpers.logLoadMeasurements("safety-limit")
    resetLoadState()
    helpers.releaseFinishedLoadWorkingData()
    state.invalidatePreflight()
    state.load.updateStarted = nil
    state.app.presetCameraHold = false
    local message = "Loading took longer than the safety limit allows. " ..
      "Please report this and include the Activity Log so I can check what happened."
    setStatus("load", message, true)
    helpers.finishTimedOutNativeLoad(message)
    return
  end
  loadPreset()
  eventBuffers.finish_update.closed = not state.app.overlayOpen or not state.app.windowOpen
  if transition("finish_update") == "release_idle" then helpers.releaseIdleMemory() end
end

return {loadPreset=loadPreset,beginLoadPass=beginLoadPass,continueLoadPass=continueLoadPass,
  update=helpers.updateAutomaticLoad,reset=resetLoadState}
end

return {install=install}
