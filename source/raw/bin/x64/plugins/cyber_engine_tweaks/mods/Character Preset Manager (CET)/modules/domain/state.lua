local PHASE_APPLY = "apply"
local PHASE_PRECLEANUP = "precleanup"
local PHASE_CLEANUP = "cleanup"
local PHASE_VERIFY = "verify"
local CHOICE_STAGE_MAIN = "main"

local function newLoad(passInterval)
  return {
    presetName = nil,
    overridePreset = nil,
    overrideName = nil,
    pass = 0,
    remaining = 0,
    needsContinue = false,
    stalled = false,
    previousUnresolvedSignature = nil,
    unresolvedRepeatCount = 0,
    satisfied = {},
    values = nil,
    savedCounts = nil,
    orderedEntries = nil,
    savedEntryByKey = nil,
    savedSlotCounts = nil,
    valueCount = 0,
    forcedKeys = {},
    resolvedChoiceIndexes = {},
    applyAttempts = {},
    unconfirmed = {},
    cleanupAttempts = {},
    cleanupSkipped = {},
    loggedWarnings = {},
    optionIdentityCache = {},
    targetPolls = 0,
    targetPollSeconds = 0,
    targetFallbacks = 0,
    pendingChange = nil,
    pendingElapsed = 0,
    phase = PHASE_APPLY,
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
    lastStructureSignature = nil,
    lastOptionCount = nil,
    forceStructureScan = true,
    scanResult = nil,
    targetPollingDisabled = false,
    returnToCleanup = false,
    dependencyKeys = {},
    dependencyRemaps = {},
    nextInterval = passInterval,
    forceFull = false,
    forceFullPresetName = nil,
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
  load.previousUnresolvedSignature = nil
  load.unresolvedRepeatCount = 0
  load.satisfied = {}
  load.values = nil
  load.savedCounts = nil
  load.orderedEntries = nil
  load.savedEntryByKey = nil
  load.savedSlotCounts = nil
  load.valueCount = 0
  load.forcedKeys = {}
  load.resolvedChoiceIndexes = {}
  load.applyAttempts = {}
  load.unconfirmed = {}
  load.cleanupAttempts = {}
  load.cleanupSkipped = {}
  load.loggedWarnings = {}
  load.optionIdentityCache = {}
  load.targetPolls = 0
  load.targetPollSeconds = 0
  load.targetFallbacks = 0
  load.batch = nil
  load.stageApplied = nil
  load.stagePending = nil
  load.choiceStage = nil
  load.pendingChange = nil
  load.pendingElapsed = 0
  load.phase = PHASE_APPLY
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
  load.lastStructureSignature = nil
  load.lastOptionCount = nil
  load.forceStructureScan = true
  load.targetPollingDisabled = false
  load.returnToCleanup = false
  load.dependencyKeys = {}
  load.dependencyRemaps = {}
  load.nextInterval = passInterval
  load.auto = false
  load.autoTimer = 0
  load.autoPasses = 0
  load.resetBefore = false
  return load
end

local function releaseLoadWorkingData(load, app)
  app.optionsMemo = nil
  load.batch = nil
  load.stageApplied = nil
  load.stagePending = nil
  load.choiceStage = nil
  load.overridePreset = nil
  load.values = nil
  load.savedCounts = nil
  load.orderedEntries = nil
  load.savedEntryByKey = nil
  load.savedSlotCounts = nil
  load.satisfied = {}
  load.forcedKeys = {}
  load.resolvedChoiceIndexes = {}
  load.applyAttempts = {}
  load.unconfirmed = {}
  load.cleanupAttempts = {}
  load.cleanupSkipped = {}
  load.loggedWarnings = {}
  load.optionIdentityCache = {}
  load.pendingChange = nil
  load.lastStructureSignature = nil
  load.lastOptionCount = nil
  load.scanResult = nil
  load.dependencyKeys = {}
  load.dependencyRemaps = {}
  load.auto = false
  load.autoTimer = 0
  load.autoPasses = 0
  return load
end

local function beginLoad(load, loadName)
  load.presetName = loadName
  load.pass = 1
  load.previousUnresolvedSignature = nil
  load.unresolvedRepeatCount = 0
  load.satisfied = {}
  load.forcedKeys = {}
  load.resolvedChoiceIndexes = {}
  load.applyAttempts = {}
  load.unconfirmed = {}
  load.cleanupAttempts = {}
  load.cleanupSkipped = {}
  load.phase = load.resetBefore and PHASE_PRECLEANUP or PHASE_APPLY
  load.choiceStage = CHOICE_STAGE_MAIN
  load.stageApplied = {}
  load.stagePending = {}
  load.needsContinue = true
  load.returnToCleanup = false
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
  load.previousUnresolvedSignature = nil
  load.unresolvedRepeatCount = 0
  return load
end

local function stopForUnavailableOptions(load)
  load.batch = nil
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

local function resetChoiceCaches(load)
  load.resolvedChoiceIndexes = {}
  load.optionIdentityCache = {}
  load.dependencyRemaps = {}
  return load
end

local function clearVisibleTracking(load)
  load.applyAttempts = {}
  load.previousUnresolvedSignature = nil
  load.unresolvedRepeatCount = 0
  return load
end

local function beginApplyAfterCleanup(load, valueCount)
  load.phase = PHASE_APPLY
  load.stageApplied = {}
  load.remaining = valueCount
  load.needsContinue = true
  load.previousUnresolvedSignature = nil
  load.unresolvedRepeatCount = 0
  return load
end

local function beginVerification(load, valueCount)
  load.phase = PHASE_VERIFY
  load.returnToCleanup = false
  load.resetBefore = false
  load.remaining = valueCount
  load.needsContinue = true
  return load
end

local function beginCleanup(load, valueCount)
  load.phase = PHASE_CLEANUP
  load.stageApplied = {}
  load.remaining = valueCount
  load.needsContinue = true
  load.previousUnresolvedSignature = nil
  load.unresolvedRepeatCount = 0
  return load
end

local function returnToCleanup(load, valueCount)
  load.phase = PHASE_CLEANUP
  load.stageApplied = {}
  load.returnToCleanup = false
  load.remaining = valueCount
  load.needsContinue = true
  load.previousUnresolvedSignature = nil
  load.unresolvedRepeatCount = 0
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

local function clearPreflightForSelection(load, selectedName)
  load.preflight = nil
  load.preflightDirty = false
  load.preflightPresetName = selectedName
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

local function stopAutomaticAtTimeout(load)
  load.auto = false
  return load
end

local function clearOptionCatalog(app)
  app.optionCatalog = nil
  app.optionChoiceBindings = nil
  app.optionsMemo = nil
  return app
end

local function clearScanCollection(target)
  for key in pairs(target) do target[key] = nil end
  return target
end

return {
  clearScanCollection = clearScanCollection,
  newLoad = newLoad,
  newApp = newApp,
  resetLoad = resetLoad,
  releaseLoadWorkingData = releaseLoadWorkingData,
  beginLoad = beginLoad,
  setLoadEntries = setLoadEntries,
  completeLoad = completeLoad,
  stopForUnavailableOptions = stopForUnavailableOptions,
  markStalled = markStalled,
  resetChoiceCaches = resetChoiceCaches,
  clearVisibleTracking = clearVisibleTracking,
  beginApplyAfterCleanup = beginApplyAfterCleanup,
  beginVerification = beginVerification,
  beginCleanup = beginCleanup,
  returnToCleanup = returnToCleanup,
  prepareAutomaticLoad = prepareAutomaticLoad,
  prepareRecoveryLoad = prepareRecoveryLoad,
  invalidatePreflight = invalidatePreflight,
  clearPreflightForSelection = clearPreflightForSelection,
  stopAutomatic = stopAutomatic,
  finishAutomaticPass = finishAutomaticPass,
  stopAutomaticAtTimeout = stopAutomaticAtTimeout,
  clearOptionCatalog = clearOptionCatalog,
}
