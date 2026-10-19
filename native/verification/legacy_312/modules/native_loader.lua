local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

local function stop(message, failed)
  state.load.needsContinue = false
  state.load.auto = false
  state.load.stalled = failed == true
  nativeAppearance.finish()
  state.app.nativeLoadSummary = message
  state.app.nativePanelShowDetails = true
  setStatus("load", message, failed == true, failed and "error" or "warning")
end

helpers.continueNativeLoad = function(system, options, preset, values, savedCounts,
    orderedEntries, savedSlotCounts, valueCount, savedEntryByKey)
  if nativeAppearance.pending then return end
  if not nativeService.available then stop(nativeService.reason, true); return end
  if valueCount == 0 then stop("The preset contains no saved options.", true); return end
  state.load.stalled = false
  if helpers.pollPendingOption(options) == "waiting" then return end
  local scan = helpers.scanLoadOptions(options, savedCounts, savedSlotCounts)
  local pendingResult = helpers.checkPendingChange(system, scan)
  if pendingResult == "waiting" then return end
  if pendingResult == "failed" then nativeAppearance.finish(); return end
  if (pendingResult == "settled" or pendingResult == "unconfirmed")
      and state.load.phase == "verify" then
    state.load.remaining = valueCount
    state.load.needsContinue = true
    setStatus("load", "A remaining option was cleared. Verifying the preset again.")
    return
  end
  if state.load.phase == "precleanup" and scan.structureChanged then
    state.load.remaining = valueCount
    state.load.needsContinue = true
    setStatus("load", "The editor changed while old options were cleared. Checking again.")
    return
  end
  if state.load.phase == "cleanup" and scan.structureChanged then
    state.load.phase = "verify"
    state.load.returnToCleanup = true
    state.load.remaining = valueCount
    state.load.needsContinue = true
    helpers.clearVisibleLoadSatisfaction(scan)
    setStatus("load", "The editor changed before cleanup. Checking the preset again first.")
    return
  end
  local loadValues = state.load.values
  local function completed(status, result, liveSystem, liveOptions)
    if state.load.values ~= loadValues then nativeAppearance.finish(); return end
    if status == "stale" then
      state.load.forceStructureScan = true
      state.load.needsContinue = true
      setStatus("load", "The editor changed. Checking its current choices before continuing.")
      return
    end
    if status == "canceled" then stop("Loading canceled. Choices already applied remain visible.", false); return end
    if status ~= "ready" then stop(tostring(result or "The appearance could not be loaded safely."), true); return end
    if type(result.state) ~= "table" then stop("The appearance plan could not be read safely.", true); return end
    for _, key in ipairs({"phase", "forceFull", "resetBefore", "returnToCleanup", "satisfied",
        "unconfirmed", "forcedKeys", "cleanupSkipped", "dependencyRemaps", "remaining",
        "needsContinue", "stalled", "previousUnresolvedSignature", "unresolvedRepeatCount"}) do
      state.load[key] = result.state[key]
    end
    for _, detail in ipairs(result.details or {}) do
      state.logLoadOnce("native:" .. tostring(detail.key) .. ":" .. tostring(detail.reason),
        "[SKIPPED] " .. tostring(detail.label) .. ": " .. tostring(detail.reason), "warn")
    end
    if result.outcome == "change" then
      local change = result.change
      local freshScan = helpers.scanLoadOptions(liveOptions, savedCounts, savedSlotCounts)
      local candidate = change and freshScan.activeByKey[change.key]
      if not candidate or candidate.position ~= change.position or candidate.label ~= change.label
          or (candidate.slot or "") ~= (change.slot or "") or candidate.occurrence ~= change.occurrence
          or tonumber(candidate.option.currIndex) ~= change.current or not optionIndexIsValid(change.target)
          or (change.kind ~= "apply" and change.kind ~= "precleanup" and change.kind ~= "cleanup")
          or (change.kind == "apply" and values[change.trackingKey] == nil)
          or (change.kind ~= "apply" and change.trackingKey ~= candidate.key) then
        stop("The planned choice no longer matches the editor. Refresh and try again.", true)
        return
      end
      local applied, errorText = helpers.beginPendingChange(liveSystem, candidate,
        change.target, change.kind, change.trackingKey, change.current)
      if not applied then
        log("[LOAD] The editor rejected a planned choice: " .. tostring(errorText), "error")
        stop("The editor could not apply a choice. See the Activity Log for details.", true)
        return
      end
      state.load.pendingChange.forced = change.forced == true
      state.load.needsContinue = true
      setStatus("load", "Applying a saved choice and waiting for the editor to settle.")
      return
    end
    if result.outcome == "continue" then
      state.load.needsContinue = true
      setStatus("load", "Checking the remaining appearance choices.")
      return
    end
    if result.outcome ~= "complete" and result.outcome ~= "partial" and result.outcome ~= "failed" then
      stop("The appearance plan returned an unknown result. Loading stopped.", true)
      return
    end
    if not state.load.stalled then helpers.finalVerifyUnconfirmed() end
    local unconfirmed, cleanup = 0, 0
    for key in pairs(state.load.unconfirmed or {}) do
      if values[key] ~= nil then unconfirmed = unconfirmed + 1 end
    end
    for _ in pairs(state.load.cleanupSkipped or {}) do cleanup = cleanup + 1 end
    local remaining = tonumber(result.remaining) or state.load.remaining or 0
    local applied = math.min(valueCount, tonumber(result.applied) or 0)
    local failed = result.outcome == "failed"
    local partial = remaining > 0 or unconfirmed > 0 or cleanup > 0
    local message
    if failed then
      message = "Load failed. The saved choices could not be matched safely. See the Activity Log."
    elseif partial then
      message = ("Partially loaded. %d of %d choices processed; %d could not be matched or confirmed. See the Activity Log.")
        :format(applied, valueCount, remaining + unconfirmed + cleanup)
    elseif (tonumber(result.forced) or 0) > 0 then
      message = ("Loaded %d choices. %d used less certain matching; check the appearance.")
        :format(valueCount, result.forced)
    else
      message = ("Loaded %d choices. All saved choices were confirmed."):format(valueCount)
    end
    state.load.needsContinue = false
    state.load.auto = false
    nativeAppearance.finish()
    state.app.nativeLoadSummary = message
    state.app.nativePanelShowDetails = failed or partial or (tonumber(result.forced) or 0) > 0
    setStatus("load", message, failed, failed and "error" or partial and "warning" or "success")
    log("[LOAD RESULT] " .. message, failed and "error" or partial and "warn" or "complete")
    refreshCustomizationUi()
    helpers.logLoadMeasurements(failed and "failed" or partial and "partial" or "complete")
    helpers.releaseFinishedLoadWorkingData()
    state.invalidatePreflight()
  end
  state.load.needsContinue = true
  local operation, errorText
  if nativeAppearance.loadId then
    operation, errorText = nativeAppearance.next(options, state.load, completed)
  else
    operation, errorText = nativeAppearance.start(preset, options, state.load, completed)
  end
  if not operation then stop(errorText or "The appearance request could not be started.", true) end
end

return _ENV
