local function newLoad(passInterval)
  return {
    presetName = nil,
    overridePreset = nil,
    overrideName = nil,
    pass = 0,
    remaining = 0,
    needsContinue = false,
    stalled = false,
    values = nil,
    savedCounts = nil,
    orderedEntries = nil,
    savedEntryByKey = nil,
    savedSlotCounts = nil,
    valueCount = 0,
    loggedWarnings = {},
    optionIdentityCache = {},
    targetPolls = 0,
    targetPollSeconds = 0,
    targetFallbacks = 0,
    pendingChange = nil,
    pendingElapsed = 0,
    elapsed = 0,
    optionsSeconds = 0,
    scanCalls = 0,
    longestUpdate = 0,
    scanSeconds = 0,
    choiceSeconds = 0,
    applySeconds = 0,
    waitSeconds = 0,
    optionCalls = 0,
    structureChanges = 0,
    nextInterval = passInterval,
    resetBefore = false,
    auto = false,
    autoTimer = 0,
    autoPasses = 0,
    preflight = nil,
    preflightDirty = true,
    preflightPresetName = nil,
    recoverySnapshotAvailable = nil,
    comparison = nil,
  }
end

local function newApp(readyStatus)
  return {
    overlayOpen = false,
    windowOpen = true,
    ready = false,
    inCustomization = false,
    optionsMemo = nil,
    loadInvocation = 0,
    nativeBridge = nil,
    nativeBridgeSequence = 0,
    nativeBridgeUnavailableLogged = false,
    nativeBridgeRetryTimer = 0,
    nativeBusy = nil,
    nativeStatus = nil,
    nativeStatusError = nil,
    nativePanelStatus = readyStatus,
    nativePanelStatusError = false,
    nativePanelShowDetails = false,
    nativeLoadSummary = nil,
    nativeListRevision = -1,
    nativeListSelection = nil,
    nativeRequestPollTimer = 0,
  }
end

local function resetLoad(load, passInterval)
  load.presetName = nil
  load.overridePreset = nil
  load.overrideName = nil
  load.pass = 0
  load.remaining = 0
  load.needsContinue = false
  load.stalled = false
  load.values = nil
  load.savedCounts = nil
  load.orderedEntries = nil
  load.savedEntryByKey = nil
  load.savedSlotCounts = nil
  load.valueCount = 0
  load.loggedWarnings = {}
  load.optionIdentityCache = {}
  load.targetPolls = 0
  load.targetPollSeconds = 0
  load.targetFallbacks = 0
  load.pendingChange = nil
  load.pendingElapsed = 0
  load.elapsed = 0
  load.optionsSeconds = 0
  load.scanCalls = 0
  load.longestUpdate = 0
  load.scanSeconds = 0
  load.choiceSeconds = 0
  load.applySeconds = 0
  load.waitSeconds = 0
  load.optionCalls = 0
  load.structureChanges = 0
  load.nextInterval = passInterval
  load.auto = false
  load.autoTimer = 0
  load.autoPasses = 0
  load.resetBefore = false
  return load
end

local function releaseLoadWorkingData(load, app)
  app.optionsMemo = nil
  load.overridePreset = nil
  load.values = nil
  load.savedCounts = nil
  load.orderedEntries = nil
  load.savedEntryByKey = nil
  load.savedSlotCounts = nil
  load.loggedWarnings = {}
  load.optionIdentityCache = {}
  load.pendingChange = nil
  load.auto = false
  load.autoTimer = 0
  load.autoPasses = 0
  return load
end

local function beginLoad(load, loadName)
  load.presetName = loadName
  load.pass = 1
  load.needsContinue = true
  return load
end

local function setLoadEntries(load, values, savedCounts, orderedEntries, savedEntryByKey, savedSlotCounts, valueCount)
  load.values = values
  load.savedCounts = savedCounts
  load.orderedEntries = orderedEntries
  load.savedEntryByKey = savedEntryByKey
  load.savedSlotCounts = savedSlotCounts
  load.valueCount = valueCount
  return load
end

local function completeLoad(load)
  load.needsContinue = false
  load.stalled = false
  return load
end

local function stopForUnavailableOptions(load)
  load.pendingChange = nil
  load.needsContinue = false
  load.auto = false
  load.stalled = true
  return load
end

local function markStalled(load)
  load.needsContinue = false
  load.stalled = true
  return load
end

local function prepareAutomaticLoad(load)
  load.autoTimer = 0
  load.autoPasses = 0
  load.resetBefore = true
  return load
end

local function prepareRecoveryLoad(load, preset, overrideName)
  load.overridePreset = preset
  load.overrideName = overrideName
  load.autoTimer = 0
  load.autoPasses = 0
  load.resetBefore = true
  return load
end

local function invalidatePreflight(load)
  load.preflight = nil
  load.preflightDirty = true
  load.preflightPresetName = nil
  return load
end

local function stopAutomatic(load)
  load.auto = false
  load.autoTimer = 0
  load.autoPasses = 0
  return load
end

local function finishAutomaticPass(load)
  load.auto = false
  load.autoPasses = 0
  return load
end

local function clearOptionCatalog(app)
  app.optionCatalog = nil
  app.optionChoiceBindings = nil
  app.optionsMemo = nil
  return app
end

return {
  newLoad = newLoad,
  newApp = newApp,
  resetLoad = resetLoad,
  releaseLoadWorkingData = releaseLoadWorkingData,
  beginLoad = beginLoad,
  setLoadEntries = setLoadEntries,
  completeLoad = completeLoad,
  stopForUnavailableOptions = stopForUnavailableOptions,
  markStalled = markStalled,

  prepareAutomaticLoad = prepareAutomaticLoad,
  prepareRecoveryLoad = prepareRecoveryLoad,
  invalidatePreflight = invalidatePreflight,

  stopAutomatic = stopAutomatic,
  finishAutomaticPass = finishAutomaticPass,

  clearOptionCatalog = clearOptionCatalog,
}
