local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

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

helpers.loadChoiceShape = function(option)
  local parts = {}
  for _, field in ipairs({ "definitions", "options", "morphNames" }) do
    local ok, size = pcall(function()
      return option and option.info and #(option.info[field] or {}) or 0
    end)
    parts[#parts + 1] = field .. ":" .. tostring(ok and tonumber(size) or "?")
  end
  return table.concat(parts, ",")
end

helpers.clearLoadScanTable = function(target)
  for key in pairs(target) do target[key] = nil end
end

helpers.scanLoadOptions = function(options, relevantLabels, relevantSlots)
  local started = helpers.loadClock()
  relevantLabels = relevantLabels or {}
  relevantSlots = relevantSlots or {}
  local result = state.load.scanResult
  if not result then
    result = {
      exposed = {},
      activeExposed = {},
      activeByKey = {},
      activeKeySet = {},
      activeCounts = {},
      exposedBySlot = {},
      activeSlotCounts = {},
      occurrences = {},
      signatureParts = {},
      records = {},
    }
    state.load.scanResult = result
  end
  helpers.clearLoadScanTable(result.exposed)
  helpers.clearLoadScanTable(result.activeExposed)
  helpers.clearLoadScanTable(result.activeByKey)
  helpers.clearLoadScanTable(result.activeKeySet)
  helpers.clearLoadScanTable(result.activeCounts)
  helpers.clearLoadScanTable(result.exposedBySlot)
  helpers.clearLoadScanTable(result.activeSlotCounts)
  helpers.clearLoadScanTable(result.occurrences)
  result.structureChanged = false
  local occurrences = result.occurrences
  local activeSlotCounts = result.activeSlotCounts
  local signatureParts = result.signatureParts
  local pendingChange = state.load.pendingChange
  local optionCount = #options
  local rebuildSignature = state.load.lastOptionCount == nil
    or state.load.lastOptionCount ~= optionCount
    or state.load.forceStructureScan
    or (pendingChange and pendingChange.longSettle)
  state.load.forceStructureScan = false
  local fullExposure = state.load.forceFull or state.load.phase == "precleanup"
    or state.load.phase == "cleanup"
  for position, option in ipairs(options) do
    local label = optionKey(option)
    local slot = optionSlot(option)
    local editable = option and option.isEditable and true or false
    local active = option and option.isActive and true or false
    local occurrence, key, slotOccurrence
    if label and editable and active then
      occurrences[label] = (occurrences[label] or 0) + 1
      occurrence = occurrences[label]
      result.activeCounts[label] = occurrence
      key = label .. "\31" .. tostring(occurrence)
      if slot then
        activeSlotCounts[slot] = (activeSlotCounts[slot] or 0) + 1
        slotOccurrence = activeSlotCounts[slot]
      end
    end
    local pending = state.load.pendingChange
    local choiceShape = label and (relevantLabels[label]
      or (pending and pending.label == label))
        and helpers.loadChoiceShape(option) or "not-checked"
    local pendingOption = state.load.pendingChange
    local includeOption = key and (fullExposure or relevantLabels[label]
      or (slot and relevantSlots[slot])
      or (pendingOption and pendingOption.label == label))
    if includeOption then
      local exposedIndex = #result.exposed + 1
      local exposedOption = result.records[exposedIndex]
      if not exposedOption then
        exposedOption = {}
        result.records[exposedIndex] = exposedOption
      end
      exposedOption.option = option
      exposedOption.position = position
      exposedOption.label = label
      exposedOption.key = key
      exposedOption.occurrence = occurrence
      exposedOption.slot = slot
      exposedOption.slotOccurrence = slotOccurrence
      exposedOption.choiceShape = choiceShape
      result.exposed[#result.exposed + 1] = exposedOption
      result.activeKeySet[key] = true
      result.activeByKey[key] = exposedOption
      result.activeExposed[#result.activeExposed + 1] = exposedOption
      if slot then
        result.exposedBySlot[slot .. "\31" .. tostring(slotOccurrence)] = exposedOption
      end
    end
    if rebuildSignature then
      signatureParts[position] = table.concat({
        tostring(label or ""), tostring(occurrence or 0), tostring(slot or ""),
        tostring(slotOccurrence or 0), editable and "1" or "0", active and "1" or "0",
      }, "\29")
    end
  end
  if rebuildSignature then
    for position = optionCount + 1, #signatureParts do signatureParts[position] = nil end
    result.signature = table.concat(signatureParts, "\30")
  else
    result.signature = state.load.lastStructureSignature
  end
  local previousSignature = state.load.lastStructureSignature
  if rebuildSignature and previousSignature and previousSignature ~= result.signature then
    result.structureChanged = true
    state.load.structureChanges = state.load.structureChanges + 1
    state.load.resolvedChoiceIndexes = {}
    state.load.optionIdentityCache = {}
    state.load.dependencyRemaps = {}
    local pending = state.load.pendingChange
    if pending then
      pending.longSettle = true
      state.load.dependencyKeys[pending.trackingKey] = true
      log(("DEPENDENCY | The editor option list changed after %s '%s'; waiting for it to settle.")
        :format(pending.kind, pending.identity), "info")
    else
      log(("DEPENDENCY | The editor option list changed between checks; %d options are now exposed.")
        :format(#options), "info")
    end
  end
  if rebuildSignature then state.load.lastStructureSignature = result.signature end
  state.load.lastOptionCount = optionCount
  state.load.scanSeconds = state.load.scanSeconds + math.max(0, helpers.loadClock() - started)
  return result
end

helpers.resolveLoadChoice = function(option, choice, cachedIndex)
  local started = helpers.loadClock()
  local resolved = cachedIndex
  if resolved == nil or not optionChoiceMatchesIndex(option, choice, resolved) then
    resolved = optionChoiceIndex(option, choice)
  end
  state.load.choiceSeconds = state.load.choiceSeconds
    + math.max(0, helpers.loadClock() - started)
  return resolved
end

helpers.loadOptionNeedsLongSettle = function(exposedOption, trackingKey)
  if state.load.dependencyKeys[trackingKey] then return true end
  local text = table.concat({
    tostring(exposedOption.label or ""),
    tostring(exposedOption.slot or ""),
    helpers.optionDisplayName(exposedOption.option, exposedOption.label),
  }, " "):lower()
  return text:find("hair", 1, true) ~= nil or text:find("beard", 1, true) ~= nil
end

helpers.pollPendingOption = function(options)
  local pending = state.load.pendingChange
  if not pending or not pending.longSettle or state.load.forceFull
      or state.load.targetPollingDisabled or not pending.position
      or pending.confirmedDisappeared or not pending.confirmedAt then
    return "full"
  end
  local started = helpers.loadClock()
  state.load.targetPolls = state.load.targetPolls + 1
  local candidate = options[pending.position]
  local valid = candidate ~= nil
    and optionKey(candidate) == pending.label
    and candidate.isEditable and candidate.isActive
    and optionSlot(candidate) == pending.slot
  local occurrence = 0
  if valid then
    for position = 1, pending.position do
      local option = options[position]
      if option and option.isEditable and option.isActive
          and optionKey(option) == pending.label then
        occurrence = occurrence + 1
      end
    end
    valid = occurrence == pending.occurrence
      and helpers.loadChoiceShape(candidate) == pending.choiceShape
  end
  state.load.targetPollSeconds = state.load.targetPollSeconds
    + math.max(0, helpers.loadClock() - started)
  if not valid then
    state.load.targetFallbacks = state.load.targetFallbacks + 1
    state.load.targetPollingDisabled = true
    state.load.resolvedChoiceIndexes = {}
    state.load.optionIdentityCache = {}
    state.load.dependencyRemaps = {}
    log(("[FALLBACK] A dependency no longer matches its saved position; normal full checks will be used for the rest of this load: %s")
      :format(pending.identity), "warn")
    return "fallback"
  end
  local current = tonumber(candidate.currIndex) or 0
  if current ~= pending.target
      or state.load.elapsed - pending.confirmedAt
        >= AUTO_LOAD_TIMING.dependencyStableTime then
    return "full"
  end
  state.load.nextInterval = AUTO_LOAD_TIMING.pollInterval
  state.load.pendingElapsed = math.max(0, state.load.elapsed - pending.startedAt)
  return "waiting"
end

helpers.beginPendingChange = function(system, exposedOption, target, kind, trackingKey, current)
  local attempts = kind == "apply" and state.load.applyAttempts
    or state.load.cleanupAttempts
  local started = helpers.loadClock()
  local ok, applyError = pcall(
    system.ApplyChangeToOption, system, exposedOption.option, target)
  state.load.applySeconds = state.load.applySeconds
    + math.max(0, helpers.loadClock() - started)
  if not ok then return false, applyError end
  attempts[trackingKey] = (attempts[trackingKey] or 0) + 1
  local longSettle = kind ~= "apply"
    or helpers.loadOptionNeedsLongSettle(exposedOption, trackingKey)
  exposedOption.choiceShape = helpers.loadChoiceShape(exposedOption.option)
  local identity = state.loadOptionIdentity(
    exposedOption.option, exposedOption.label, exposedOption.occurrence)
  if kind == "apply" then
    identity = identity .. savedEntryAuditIdentity(
      state.load.savedEntryByKey and state.load.savedEntryByKey[trackingKey])
  end
  state.load.pendingChange = {
    kind = kind,
    trackingKey = trackingKey,
    optionKey = exposedOption.key,
    position = exposedOption.position,
    label = exposedOption.label,
    occurrence = exposedOption.occurrence,
    slot = exposedOption.slot,
    choiceShape = exposedOption.choiceShape,
    target = target,
    previous = current,
    identity = identity,
    startedAt = state.load.elapsed,
    attemptStartedAt = state.load.elapsed,
    structureSignature = state.load.lastStructureSignature,
    confirmedAt = nil,
    confirmedSignature = nil,
    confirmedDisappeared = false,
    longSettle = longSettle,
  }
  state.load.pendingElapsed = 0
  state.load.nextInterval = AUTO_LOAD_TIMING.pollInterval
  state.load.forceStructureScan = true
  state.load.needsContinue = true
  state.load.previousUnresolvedSignature = nil
  state.load.unresolvedRepeatCount = 0
  return true
end

helpers.clearVisibleLoadSatisfaction = function(scan)
  for key in pairs(scan.activeKeySet) do
    if not state.load.unconfirmed[key] then state.load.satisfied[key] = nil end
  end
  state.load.applyAttempts = {}
  state.load.previousUnresolvedSignature = nil
  state.load.unresolvedRepeatCount = 0
end

helpers.checkPendingChange = function(system, scan)
  local pending = state.load.pendingChange
  if not pending then return "none" end
  local candidate = scan.activeByKey[pending.optionKey]
  if candidate and (candidate.label ~= pending.label
      or candidate.occurrence ~= pending.occurrence
      or candidate.slot ~= pending.slot) then
    candidate = nil
    state.load.targetPollingDisabled = true
    state.load.resolvedChoiceIndexes = {}
    state.load.optionIdentityCache = {}
    state.load.dependencyRemaps = {}
    log(("[FALLBACK] Live option identity changed while waiting for %s; normal full checks will be used for the rest of this load: %s")
      :format(pending.kind, pending.identity), "warn")
  elseif candidate and candidate.choiceShape ~= pending.choiceShape then
    if not pending.choiceStructureChanged then
      state.load.targetPollingDisabled = true
      state.load.resolvedChoiceIndexes = {}
      state.load.optionIdentityCache = {}
      state.load.dependencyRemaps = {}
      pending.longSettle = true
      pending.choiceStructureChanged = true
      log(("[FALLBACK] Choice structure changed while waiting for %s; the result will require manual confirmation: %s")
        :format(pending.kind, pending.identity), "warn")
    end
  end
  if candidate then pending.position = candidate.position end
  local current = candidate and (tonumber(candidate.option.currIndex) or 0) or nil
  local disappeared = candidate == nil
  local reached = not pending.choiceStructureChanged and current == pending.target
  local structureChanged = scan.signature ~= pending.structureSignature
  if structureChanged then pending.longSettle = true end
  if disappeared then pending.longSettle = true end
  if reached or disappeared then
    if pending.longSettle then
      if pending.confirmedAt == nil
          or pending.confirmedSignature ~= scan.signature then
        pending.confirmedAt = state.load.elapsed
        pending.confirmedSignature = scan.signature
        pending.confirmedDisappeared = disappeared
        state.load.nextInterval = AUTO_LOAD_TIMING.pollInterval
        setStatus("load", disappeared
          and "A dependent option was replaced. Waiting for the editor to settle."
          or "The option changed. Waiting for dependent options to settle.")
        return "waiting"
      end
      if state.load.elapsed - pending.confirmedAt
          < AUTO_LOAD_TIMING.dependencyStableTime then
        state.load.nextInterval = AUTO_LOAD_TIMING.pollInterval
        return "waiting"
      end
    end
    local waited = math.max(0, state.load.elapsed - pending.startedAt)
    state.load.waitSeconds = state.load.waitSeconds + waited
    state.load.pendingElapsed = waited
    state.load.pendingChange = nil
    state.load.nextInterval = AUTO_LOAD_TIMING.passInterval
    state.load.forceStructureScan = true
    if pending.kind == "apply" then
      state.load.satisfied[pending.trackingKey] = true
      state.load.unconfirmed[pending.trackingKey] = nil
      if pending.forced then state.load.forcedKeys[pending.trackingKey] = true end
    elseif pending.kind == "precleanup" then
      state.load.phase = "precleanup"
    else
      state.load.phase = "verify"
      state.load.returnToCleanup = true
      helpers.clearVisibleLoadSatisfaction(scan)
    end
    log(("SETTLED | %s | %s | target=%s | result=%s | currIndex wait=%.3fs | structureChanged=%s")
      :format(pending.kind, pending.identity, tostring(pending.target),
        disappeared and "dependent option disappeared" or "value confirmed",
        waited, tostring(structureChanged)), "info")
    return "settled"
  end
  local sinceAttempt = state.load.elapsed - pending.attemptStartedAt
  if pending.longSettle and sinceAttempt < AUTO_LOAD_TIMING.dependencyTimeout then
    state.load.nextInterval = AUTO_LOAD_TIMING.pollInterval
    state.load.pendingElapsed = math.max(0, state.load.elapsed - pending.startedAt)
    return "waiting"
  end
  local waited = math.max(0, state.load.elapsed - pending.startedAt)
  state.load.waitSeconds = state.load.waitSeconds + waited
  state.load.pendingChange = nil
  state.load.nextInterval = AUTO_LOAD_TIMING.passInterval
  state.load.forceStructureScan = true
  if pending.kind ~= "apply" then
    state.load.cleanupSkipped[pending.trackingKey] = true
    if pending.kind == "precleanup" then
      state.load.phase = "precleanup"
    else
      state.load.phase = "verify"
      state.load.returnToCleanup = true
      helpers.clearVisibleLoadSatisfaction(scan)
    end
    state.logLoadOnce("cleanup-not-confirmed:" .. pending.trackingKey,
      ("[UNCONFIRMED] The game did not expose whether a remaining option cleared after %.3fs. It was not applied again: %s")
        :format(waited, pending.identity), "warn")
  else
    state.load.satisfied[pending.trackingKey] = true
    state.load.unconfirmed[pending.trackingKey] = true
    if pending.forced then state.load.forcedKeys[pending.trackingKey] = true end
    state.logLoadOnce("apply-not-confirmed:" .. pending.trackingKey,
      ("[UNCONFIRMED] The game did not update currIndex after %.3fs. The option was applied once and was not repeated: %s targetIndex=%s")
        :format(waited, pending.identity, tostring(pending.target)), "warn")
  end
  return "unconfirmed"
end

helpers.logLoadMeasurements = function(result)
  log(("[MEASURE] Load %s | preset='%s' | elapsed=%.3fs | option checks=%d time=%.6fs | full scans=%.6fs | dependency polls=%d time=%.6fs fallbacks=%d | choice matching=%.6fs | applied calls=%.6fs | waiting=%.3fs | dependency changes=%d")
    :format(tostring(result), tostring(state.load.presetName or state.library.selected),
      state.load.elapsed, state.load.optionCalls, state.load.optionsSeconds,
      state.load.scanSeconds, state.load.targetPolls, state.load.targetPollSeconds,
      state.load.targetFallbacks, state.load.choiceSeconds, state.load.applySeconds,
      state.load.waitSeconds, state.load.structureChanges), "info")
end

helpers.releaseFinishedLoadWorkingData = function()
  state.app.optionsMemo = nil
  state.load.overridePreset = nil
  state.load.values = nil
  state.load.savedCounts = nil
  state.load.orderedEntries = nil
  state.load.savedEntryByKey = nil
  state.load.savedSlotCounts = nil
  state.load.satisfied = {}
  state.load.forcedKeys = {}
  state.load.resolvedChoiceIndexes = {}
  state.load.applyAttempts = {}
  state.load.unconfirmed = {}
  state.load.cleanupAttempts = {}
  state.load.cleanupSkipped = {}
  state.load.loggedWarnings = {}
  state.load.optionIdentityCache = {}
  state.load.pendingChange = nil
  state.load.lastStructureSignature = nil
  state.load.lastOptionCount = nil
  state.load.scanResult = nil
  state.load.dependencyKeys = {}
  state.load.dependencyRemaps = {}
  state.load.auto = false
  state.load.autoTimer = 0
  state.load.autoPasses = 0
end

helpers.forceFullLoadWarning = function(preset)
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
  state.load.forceFull = preset ~= nil
    and format < FORCE_FULL_LOAD_FORMAT_THRESHOLD
  state.load.forceFullPresetName = selected
  if selected then
    log(("[LOAD] Force Full Load selected automatically for '%s': %s (format %s).")
      :format(selected, state.load.forceFull and "on" or "off", tostring(format)), "info")
  end
end

helpers.finalVerifyUnconfirmed = function()
  if next(state.load.unconfirmed) == nil then return 0 end
  local optionsStarted = helpers.loadClock()
  local _, options, optionsError = getOptions(true)
  state.load.optionsSeconds = state.load.optionsSeconds
    + math.max(0, helpers.loadClock() - optionsStarted)
  state.load.optionCalls = state.load.optionCalls + 1
  if not options then
    log("FINAL CONFIRMATION | Fresh option check unavailable: " ..
      tostring(optionsError), "warn")
    return 0
  end

  local occurrences, slotOccurrences = {}, {}
  local activeCounts, activeSlotCounts, candidates = {}, {}, {}
  for position, option in ipairs(options) do
    local label = optionKey(option)
    local slot = optionSlot(option)
    if label and option.isEditable and option.isActive then
      occurrences[label] = (occurrences[label] or 0) + 1
      activeCounts[label] = occurrences[label]
      local slotOccurrence = nil
      if slot then
        slotOccurrences[slot] = (slotOccurrences[slot] or 0) + 1
        activeSlotCounts[slot] = slotOccurrences[slot]
        slotOccurrence = slotOccurrences[slot]
      end
      local key = label .. "\31" .. tostring(occurrences[label])
      candidates[key] = {
        option = option,
        position = position,
        label = label,
        occurrence = occurrences[label],
        slot = slot,
        slotOccurrence = slotOccurrence,
      }
    end
  end

  local cleared = 0
  for key in pairs(state.load.unconfirmed) do
    local candidate = candidates[key]
    local label = candidate and candidate.label or nil
    local target = state.load.values and state.load.values[key] or nil
    if candidate and target ~= nil
        and (activeCounts[label] or 0) == ((state.load.savedCounts or {})[label] or 0)
        and (tonumber(candidate.option.currIndex) or 0) == target then
      state.load.unconfirmed[key] = nil
      cleared = cleared + 1
      log(("FINAL CONFIRMATION | %s now matches target index=%s.")
        :format(state.loadOptionIdentity(candidate.option, label, candidate.occurrence),
          tostring(target)), "info")
    end
  end

  for liveKey, remap in pairs(state.load.dependencyRemaps) do
    local savedKey = remap and remap.savedKey
    local candidate = candidates[liveKey]
    if savedKey and state.load.unconfirmed[savedKey] and candidate
        and candidate.label == remap.label
        and candidate.occurrence == remap.occurrence
        and candidate.position == remap.position
        and candidate.slot == remap.slot
        and candidate.slotOccurrence == remap.slotOccurrence
        and (not remap.slot
          or (activeSlotCounts[remap.slot] or 0) == remap.slotCount)
        and (tonumber(candidate.option.currIndex) or 0) == remap.target then
      state.load.unconfirmed[savedKey] = nil
      cleared = cleared + 1
      log(("FINAL CONFIRMATION | %s now matches remapped target index=%s.")
        :format(state.loadOptionIdentity(candidate.option, candidate.label,
          candidate.occurrence), tostring(remap.target)), "info")
    end
  end
  return cleared
end

beginLoadPass = function(preset, loadName)
  helpers.auditSection("LOAD PRESET")
  log(("[PRESET] Load requested: name='%s'"):format(tostring(loadName)), "load")
  state.load.presetName = loadName
  state.load.pass = 1
  state.load.previousUnresolvedSignature = nil
  state.load.unresolvedRepeatCount = 0
  state.load.satisfied = {}
  state.load.forcedKeys = {}
  state.load.resolvedChoiceIndexes = {}
  state.load.applyAttempts = {}
  state.load.unconfirmed = {}
  state.load.cleanupAttempts = {}
  state.load.cleanupSkipped = {}
  state.load.phase = state.load.resetBefore and "precleanup" or "apply"
  state.load.returnToCleanup = false
  local values, savedCounts, orderedEntries, savedSlotCounts,
    valueCount, savedEntryByKey = helpers.preparePresetEntries(preset)
  state.load.values = values
  state.load.savedCounts = savedCounts
  state.load.orderedEntries = orderedEntries
  state.load.savedEntryByKey = savedEntryByKey
  state.load.savedSlotCounts = savedSlotCounts
  state.load.valueCount = valueCount
  return values, savedCounts, orderedEntries, savedSlotCounts, valueCount, savedEntryByKey
end

continueLoadPass = function(system, options, preset, values, savedCounts,
    orderedEntries, savedSlotCounts, valueCount, savedEntryByKey)
  state.load.stalled = false
  if valueCount == 0 then setStatus("load", "The preset contains no saved options.", true); return end

  if state.load.pass == 1 then
    log(("Preset='%s' | saved=%d options | editor exposes=%d options | format=%s")
      :format(state.load.presetName or state.library.selected,
        valueCount, #options, tostring(preset.format or 1)),
      "load")
  end

  local applied, missing, ambiguous, invalid = 0, 0, 0, 0
  local deferred = {}
  local unresolved = {}
  local seen = {}
  if helpers.pollPendingOption(options) == "waiting" then return end
  local scan = helpers.scanLoadOptions(options, savedCounts, savedSlotCounts)
  local exposed = scan.exposed
  local activeKeySet = scan.activeKeySet
  local activeCounts = scan.activeCounts
  local activeExposed = scan.activeExposed
  local exposedBySlot = scan.exposedBySlot
  local activeSlotCounts = scan.activeSlotCounts

  local pendingResult = helpers.checkPendingChange(system, scan)
  if pendingResult == "waiting" or pendingResult == "failed" then return end
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
    log("PRECLEANUP | The editor structure changed while old dependent options were being cleared. Checking the updated option list.", "info")
    setStatus("load", "The editor changed while old options were cleared. Checking again.")
    return
  end

  if state.load.phase == "cleanup" and scan.structureChanged then
    state.load.phase = "verify"
    state.load.returnToCleanup = true
    state.load.remaining = valueCount
    state.load.needsContinue = true
    helpers.clearVisibleLoadSatisfaction(scan)
    log("CLEANUP | The editor structure changed before cleanup. Verifying the preset again before clearing anything.", "info")
    setStatus("load",
      "The editor changed before cleanup. Checking the preset again first.")
    return
  end

  if state.load.phase == "precleanup" or state.load.phase == "cleanup" then
    local isPrecleanup = state.load.phase == "precleanup"
    local savedEntryBySlot = {}
    for _, entry in ipairs(orderedEntries or {}) do
      if entry.slot and entry.slotOccurrence then
        savedEntryBySlot[entry.slot .. "\31" .. tostring(entry.slotOccurrence)] = entry
      end
    end
    for _, exposedOption in ipairs(exposed) do
      local label = exposedOption.label
      local occurrence = exposedOption.occurrence
      local cleanupKey = exposedOption.key
      local current = tonumber(exposedOption.option.currIndex) or 0
      local remap = cleanupKey and state.load.dependencyRemaps[cleanupKey] or nil
      local keepRemap = remap and state.load.satisfied[remap.savedKey]
        and exposedOption.label == remap.label
        and exposedOption.occurrence == remap.occurrence
        and exposedOption.position == remap.position
        and exposedOption.slot == remap.slot
        and exposedOption.slotOccurrence == remap.slotOccurrence
        and current == remap.target
        and (not remap.slot
          or (activeSlotCounts[remap.slot] or 0) == remap.slotCount)
        and (not remap.choice or optionChoiceMatchesIndex(
          exposedOption.option, remap.choice, remap.target))
      if remap and not keepRemap then
        state.load.dependencyRemaps[cleanupKey] = nil
      end
      local savedSlotEntry = nil
      if exposedOption.slot and exposedOption.slotOccurrence
          and (activeSlotCounts[exposedOption.slot] or 0)
            == (savedSlotCounts[exposedOption.slot] or 0) then
        savedSlotEntry = savedEntryBySlot[exposedOption.slot .. "\31" ..
          tostring(exposedOption.slotOccurrence)]
      end
      local extraByLabel = occurrence > (savedCounts[label] or 0)
      local clearSlotReplacement = savedSlotEntry
        and tonumber(savedSlotEntry.index) == 0
      if cleanupKey and extraByLabel
          and (not savedSlotEntry or clearSlotReplacement)
          and current ~= 0 and not keepRemap
          and not state.load.cleanupSkipped[cleanupKey] then
        local ok, clearError = helpers.beginPendingChange(
          system, exposedOption, 0, isPrecleanup and "precleanup" or "cleanup",
          cleanupKey, current)
        if not ok then
          state.load.resetBefore = false
          state.load.needsContinue = false
          state.load.stalled = true
          log(("FAILED | pass=%d | %s | index %d -> 0 | reset leftover | %s")
            :format(state.load.pass,
              state.loadOptionIdentity(exposedOption.option, label, occurrence),
              current, tostring(clearError)), "error")
          setStatus("load",
            "Loading stopped because a remaining option could not be cleared safely. Close the editor without confirming, reopen it, and retry.",
            true)
          helpers.logLoadMeasurements("cleanup-failed")
        else
          log(("CHANGE | pass=%d | %s | index %d -> 0 | %s")
            :format(state.load.pass,
              state.loadOptionIdentity(exposedOption.option, label, occurrence),
              current, isPrecleanup and "pre-apply dependent cleanup"
                or "post-apply leftover cleanup"), "info")
          setStatus("load", isPrecleanup
            and "Clearing an old dependent option before applying the preset."
            or "Clearing one remaining option. Waiting for the editor.")
        end
        return
      end
    end
    if isPrecleanup then
      state.load.phase = "apply"
      state.load.remaining = valueCount
      state.load.needsContinue = true
      state.load.previousUnresolvedSignature = nil
      state.load.unresolvedRepeatCount = 0
      log("PRECLEANUP | Old exposed dependent options were cleared before applying the preset.", "info")
      setStatus("load", "Old dependent options cleared. Applying the preset.")
      return
    end
    state.load.phase = "verify"
    state.load.returnToCleanup = false
    state.load.resetBefore = false
    state.load.remaining = valueCount
    state.load.needsContinue = true
    helpers.clearVisibleLoadSatisfaction(scan)
    log("CLEANUP | No additional exposed leftover options require resetting. Verifying the preset.", "info")
    setStatus("load", "Cleanup complete. Verifying the preset again.")
    return
  end

  local satisfiedBefore = 0
  for _, exposedOption in ipairs(exposed) do
    local key = exposedOption.key
    local label = exposedOption.label
    local wanted = key and values[key] or nil
    local savedEntry = key and savedEntryByKey[key] or nil
    if wanted ~= nil and savedEntry and savedEntry.choice then
      local cachedIndex = state.load.resolvedChoiceIndexes[key]
      local resolvedIndex = helpers.resolveLoadChoice(
        exposedOption.option, savedEntry.choice, cachedIndex)
      if resolvedIndex ~= nil then
        state.load.resolvedChoiceIndexes[key] = resolvedIndex
        wanted = resolvedIndex
        values[key] = resolvedIndex
      end
    end
    local countMatches = label
      and (savedCounts[label] or 0) == (activeCounts[label] or 0)
    if wanted ~= nil and countMatches and optionIndexIsValid(wanted)
        and ((tonumber(exposedOption.option.currIndex) or 0) == wanted
          or (state.load.satisfied[key] and state.load.unconfirmed[key])) then
      satisfiedBefore = satisfiedBefore + 1
    end
  end
  for key in pairs(values) do
    if not activeKeySet[key] and state.load.satisfied[key] then
      satisfiedBefore = satisfiedBefore + 1
    end
  end

  for i = 1, #exposed do
    local exposedOption = exposed[i]
    local option = exposedOption.option
    local label = exposedOption.label
    local key = exposedOption.key
    local wanted = key and values[key] or nil
    local savedEntry = key and savedEntryByKey[key] or nil
    local choiceUnavailable = false
    if wanted ~= nil and savedEntry and savedEntry.choice then
      local resolvedIndex = helpers.resolveLoadChoice(
        option, savedEntry.choice, state.load.resolvedChoiceIndexes[key])
      if resolvedIndex == nil then
        state.load.resolvedChoiceIndexes[key] = nil
        choiceUnavailable = true
      else
        state.load.resolvedChoiceIndexes[key] = resolvedIndex
        wanted = resolvedIndex
        values[key] = resolvedIndex
      end
    end
    local countMatches = label
      and (savedCounts[label] or 0) == (activeCounts[label] or 0)
    local indexIsValid = wanted == nil or optionIndexIsValid(wanted)
    if wanted ~= nil then
      seen[key] = true
      if choiceUnavailable then
        missing = missing + 1
        unresolved["unavailable-choice:" .. tostring(key)] = true
        state.logLoadOnce("unavailable-choice:" .. tostring(key),
          ("[SKIPPED] Saved choice is no longer exposed for %s choice='%s'")
            :format(state.loadOptionIdentity(option, label, exposedOption.occurrence),
              tostring(savedEntry.choice)), "warn")
      elseif not countMatches then
        ambiguous = ambiguous + 1
        unresolved["ambiguous:" .. tostring(key)] = true
        state.logLoadOnce("ambiguous:" .. tostring(key),
          ("[SKIPPED] Ambiguous repeated option: %s savedCount=%d exposedCount=%d")
            :format(
              state.loadOptionIdentity(option, label, exposedOption.occurrence),
              savedCounts[label] or 0,
              activeCounts[label] or 0
            ), "warn")
      elseif not indexIsValid then
        invalid = invalid + 1
        unresolved["invalid-index:" .. tostring(key)] = true
        state.logLoadOnce("invalid-index:" .. tostring(key),
          ("[SKIPPED] Saved index is outside the supported native range: %s targetIndex=%s")
            :format(state.loadOptionIdentity(option, label, exposedOption.occurrence),
              tostring(wanted)), "warn")
      end
    end
    if wanted ~= nil and not choiceUnavailable and countMatches and indexIsValid
        and option.isEditable and option.isActive then
      local current = tonumber(option.currIndex) or 0
      if current == wanted then
        state.load.satisfied[key] = true
        state.load.unconfirmed[key] = nil
        applied = applied + 1
      elseif state.load.satisfied[key] and state.load.unconfirmed[key] then
        applied = applied + 1
      elseif state.load.satisfied[key] then
        deferred[key] = true
        missing = missing + 1
        unresolved["reverted:" .. tostring(key)] = true
      else
        if savedEntry and savedEntry.choice and wanted ~= savedEntry.index then
          log(("CHOICE REMAP | pass=%d | %s | savedIndex=%s currentIndex=%s choice='%s'")
            :format(state.load.pass,
              state.loadOptionIdentity(option, label, exposedOption.occurrence),
              tostring(savedEntry.index), tostring(wanted), tostring(savedEntry.choice)),
            "info")
        end
        local ok, applyError = helpers.beginPendingChange(
          system, exposedOption, wanted, "apply", key, current)
        if ok then
          state.load.remaining = math.max(0, valueCount - satisfiedBefore - 1)
          log(("CHANGE | pass=%d | %s | index %s -> %s")
            :format(state.load.pass,
              state.loadOptionIdentity(option, label, exposedOption.occurrence),
              tostring(current), tostring(wanted)), "info")
          setStatus("load", ("Applied one option. Waiting for the editor; %d %s remain%s to be checked.")
            :format(state.load.remaining,
              state.load.remaining == 1 and "option" or "options",
              state.load.remaining == 1 and "s" or ""))
        else
          state.load.needsContinue = false
          state.load.stalled = true
          log(("FAILED | pass=%d | %s | target index %s | %s")
            :format(state.load.pass,
              state.loadOptionIdentity(option, label, exposedOption.occurrence),
              tostring(wanted), tostring(applyError)), "error")
          setStatus("load",
            "Loading stopped because an option could not be applied safely. " ..
            "Close the editor without confirming, reopen it, and retry.",
            true
          )
          helpers.logLoadMeasurements("apply-failed")
        end
        return
      end
    end
  end
  for key, wanted in pairs(values) do
    if wanted == 0 and not activeKeySet[key] and not state.load.satisfied[key] then
      state.load.satisfied[key] = true
      local hiddenLabel, hiddenOccurrence = occurrenceKeyParts(key)
      log(("VERIFY | %s | target index=0 | already clear because the dependent option is hidden")
        :format(optionAuditIdentity(nil, hiddenLabel, hiddenOccurrence)), "info")
    end
  end
  local claimedOptions = {}
  for _, exposedOption in ipairs(exposed) do
    if exposedOption.key and values[exposedOption.key] ~= nil then
      claimedOptions[exposedOption.option] = true
    end
  end
  for _, entry in ipairs(orderedEntries or {}) do
    local savedKey = entry.key
    if not seen[savedKey]
        and entry.slot and entry.choice
        and (savedSlotCounts[entry.slot] or 0) == (activeSlotCounts[entry.slot] or 0) then
      local slotKey = entry.slot .. "\31" .. tostring(entry.slotOccurrence or 1)
      local candidate = exposedBySlot[slotKey]
      if candidate and candidate.option.isEditable and candidate.option.isActive
          and not claimedOptions[candidate.option] then
        local target = helpers.resolveLoadChoice(candidate.option, entry.choice,
          state.load.resolvedChoiceIndexes[savedKey])
        if target ~= nil and optionIndexIsValid(target) then
          state.load.resolvedChoiceIndexes[savedKey] = target
          seen[savedKey] = true
          claimedOptions[candidate.option] = true
          state.load.dependencyRemaps[candidate.key] = {
            savedKey = savedKey,
            label = candidate.label,
            occurrence = candidate.occurrence,
            position = candidate.position,
            slot = candidate.slot,
            slotOccurrence = candidate.slotOccurrence,
            slotCount = savedSlotCounts[entry.slot] or 0,
            choice = entry.choice,
            target = target,
          }
          local current = tonumber(candidate.option.currIndex) or 0
          if current == target then
            state.load.satisfied[savedKey] = true
            state.load.unconfirmed[savedKey] = nil
            applied = applied + 1
          elseif state.load.satisfied[savedKey] and state.load.unconfirmed[savedKey] then
            applied = applied + 1
          elseif state.load.satisfied[savedKey] then
            deferred[savedKey] = true
            missing = missing + 1
            unresolved["reverted-remap:" .. tostring(savedKey)] = true
          else
            state.load.dependencyKeys[savedKey] = true
            local ok, applyError = helpers.beginPendingChange(
              system, candidate, target, "apply", savedKey, current)
            if ok then
              state.load.remaining = math.max(0, valueCount - satisfiedBefore - 1)
              log(("DEPENDENCY REMAP | pass=%d | saved LocKey='%s' disappeared | uiSlot='%s' and saved choice='%s' matched %s | index %s -> %s")
                :format(state.load.pass, entry.label, entry.slot, entry.choice,
                  optionAuditIdentity(candidate.option, candidate.label,
                    candidate.occurrence), tostring(current), tostring(target)), "info")
              setStatus("load",
                "A hairstyle-dependent option was replaced. Its saved choice was matched safely; waiting for the editor.")
            else
              state.load.needsContinue = false
              state.load.stalled = true
              log(("DEPENDENCY REMAP FAILED | pass=%d | saved LocKey='%s' | uiSlot='%s' target index %s | %s")
                :format(state.load.pass, entry.label, entry.slot, tostring(target),
                  tostring(applyError)), "error")
              helpers.logLoadMeasurements("dependency-remap-failed")
              setStatus("load",
                "Loading stopped because a replaced hairstyle-dependent option could not be applied safely. Close the editor without confirming, reopen it, and retry.",
                true)
            end
            return
          end
        end
      end
    end
  end
  if state.load.forceFull then
    for _, entry in ipairs(orderedEntries or {}) do
      local savedKey = entry.key
      if not seen[savedKey]
          and optionIndexIsValid(entry.index) then
        local candidate = nil
        local method = nil
        if entry.slot
            and (savedSlotCounts[entry.slot] or 0) == (activeSlotCounts[entry.slot] or 0) then
          local slotKey = entry.slot .. "\31" .. tostring(entry.slotOccurrence or 1)
          candidate = exposedBySlot[slotKey]
          method = "uiSlot"
        elseif not entry.slot and entry.position and entry.position > 1
            and entry.position < #(orderedEntries or {}) then
          local previousEntry = orderedEntries[entry.position - 1]
          local nextEntry = orderedEntries[entry.position + 1]
          local positioned = activeExposed[entry.position]
          if positioned and activeExposed[entry.position - 1]
              and activeExposed[entry.position + 1]
              and activeExposed[entry.position - 1].key == previousEntry.key
              and activeExposed[entry.position + 1].key == nextEntry.key
              and values[positioned.key] == nil then
            candidate = positioned
            method = "anchored legacy position"
          end
        end
        if candidate and candidate.option.isEditable and candidate.option.isActive
            and not claimedOptions[candidate.option] then
          local target = entry.choice and helpers.resolveLoadChoice(
            candidate.option, entry.choice, nil)
            or entry.index
          if target ~= nil and optionIndexIsValid(target) then
            seen[savedKey] = true
            claimedOptions[candidate.option] = true
            state.load.dependencyRemaps[candidate.key] = {
              savedKey = savedKey,
              label = candidate.label,
              occurrence = candidate.occurrence,
              position = candidate.position,
              slot = candidate.slot,
              slotOccurrence = candidate.slotOccurrence,
              slotCount = candidate.slot
                and (activeSlotCounts[candidate.slot] or 0) or 0,
              choice = entry.choice,
              target = target,
            }
            local current = tonumber(candidate.option.currIndex) or 0
            if current == target then
              state.load.satisfied[savedKey] = true
              state.load.unconfirmed[savedKey] = nil
              state.load.forcedKeys[savedKey] = true
            elseif state.load.satisfied[savedKey] and state.load.unconfirmed[savedKey] then
              state.load.forcedKeys[savedKey] = true
            elseif state.load.satisfied[savedKey] then
              state.load.forcedKeys[savedKey] = nil
              deferred[savedKey] = true
              missing = missing + 1
              unresolved["reverted-force:" .. tostring(savedKey)] = true
            else
              local ok, applyError = helpers.beginPendingChange(
                system, candidate, target, "apply", savedKey, current)
              if ok then
                state.load.pendingChange.forced = true
                state.load.remaining = math.max(0, valueCount - satisfiedBefore - 1)
                log(("FORCED | pass=%d | saved LocKey='%s' unavailable | %s fallback -> %s | index %s -> %s")
                  :format(state.load.pass, entry.label, method,
                    optionAuditIdentity(candidate.option, candidate.label, candidate.occurrence),
                    tostring(current), tostring(target)), "warn")
                setStatus("load",
                  "Applied one unmatched option using Force Full Load. Waiting for the editor.")
                return
              else
                state.load.forcedKeys[savedKey] = nil
                log(("FORCE FAILED | pass=%d | saved LocKey='%s' | %s fallback target index %s | %s")
                  :format(state.load.pass, entry.label, method, tostring(target),
                    tostring(applyError)), "error")
                state.load.needsContinue = false
                state.load.stalled = true
                helpers.logLoadMeasurements("force-failed")
                setStatus("load",
                  "Loading stopped because Force Full Load could not apply an option safely. Close the editor without confirming, reopen it, and retry.",
                  true)
                return
              end
            end
          elseif entry.choice then
            state.logLoadOnce("force-choice:" .. tostring(savedKey),
              ("[SKIPPED] Force Full Load found the selector but not its saved choice: LocKey='%s' choice='%s'.")
                :format(entry.label, tostring(entry.choice)), "warn")
          end
        end
      end
    end
  end

  for key in pairs(deferred) do state.load.satisfied[key] = nil end

  local forced = 0
  for key in pairs(values) do
    if not seen[key] then
      if state.load.satisfied[key] then
        applied = applied + 1
        if state.load.forcedKeys[key] then forced = forced + 1 end
        local hiddenLabel, hiddenOccurrence = occurrenceKeyParts(key)
        log(("VERIFY | %s | target index=%s | applied, then hidden by dependency")
          :format(optionAuditIdentity(nil, hiddenLabel, hiddenOccurrence),
            tostring(values[key])), "info")
      else
        missing = missing + 1
        unresolved["unavailable:" .. tostring(key)] = true
        local missingLabel, missingOccurrence = occurrenceKeyParts(key)
        state.logLoadOnce("unavailable:" .. tostring(key),
          ("[SKIPPED] Saved option unavailable in current editor/body setup: %s targetIndex=%s")
            :format(state.loadOptionIdentity(nil, missingLabel, missingOccurrence),
              tostring(values[key])), "warn")
      end
    elseif state.load.forcedKeys[key] then
      applied = applied + 1
      forced = forced + 1
    end
  end
  state.load.remaining = missing + ambiguous + invalid
  if state.load.remaining > 0 then
    local signature = unresolvedSignature(unresolved)
    if state.load.previousUnresolvedSignature == signature then
      state.load.unresolvedRepeatCount = state.load.unresolvedRepeatCount + 1
    else
      state.load.previousUnresolvedSignature = signature
      state.load.unresolvedRepeatCount = 1
    end
    if state.load.unresolvedRepeatCount >= STALL_CONFIRMATION_PASSES then
      state.load.needsContinue = false
      state.load.stalled = true
      refreshCustomizationUi()
      log(("SUMMARY | preset='%s' | applied=%d | unresolved=%d | passes=%d | result=stopped")
        :format(state.load.presetName or state.library.selected,
          applied, state.load.remaining, state.load.pass), "warn")
      log(("Load stalled: preset='%s' pass=%d unresolved=%d signature='%s'")
        :format(state.load.presetName or state.library.selected,
          state.load.pass, state.load.remaining, signature), "warn")
      helpers.logLoadMeasurements("stopped")
      setStatus("load", (
        "Loading stopped because %d of %d options were still missing after %d checks. " ..
        "Adding, removing, updating, or changing the order of CCXL mods can move or rename options. " ..
        "Check your option mods. Correct the appearance if needed, then save the preset again."
      ):format(state.load.remaining, valueCount, STALL_CONFIRMATION_PASSES))
    else
      state.load.needsContinue = true
      setStatus("load", ("Pass %d complete: %d of %d applied, %d remaining. Continuing automatically.")
        :format(state.load.pass, applied, valueCount, state.load.remaining))
    end
  else
    if state.load.phase == "apply" and state.load.resetBefore then
      state.load.phase = "cleanup"
      state.load.remaining = valueCount
      state.load.needsContinue = true
      state.load.previousUnresolvedSignature = nil
      state.load.unresolvedRepeatCount = 0
      log("APPLY | Saved preset options were processed. Checking for genuine leftovers next.", "info")
      setStatus("load", "Preset options applied. Checking for remaining options.")
      return
    end
    if state.load.phase == "verify" and state.load.returnToCleanup then
      state.load.phase = "cleanup"
      state.load.returnToCleanup = false
      state.load.remaining = valueCount
      state.load.needsContinue = true
      state.load.previousUnresolvedSignature = nil
      state.load.unresolvedRepeatCount = 0
      log("VERIFY | Post-cleanup preset check finished. Checking for another leftover option.", "info")
      setStatus("load", "Preset checked. Looking for another remaining option.")
      return
    end
    helpers.finalVerifyUnconfirmed()
    local cleanupSkipped = 0
    for _ in pairs(state.load.cleanupSkipped) do cleanupSkipped = cleanupSkipped + 1 end
    local unconfirmed = 0
    for key in pairs(state.load.unconfirmed) do
      if values[key] ~= nil then unconfirmed = unconfirmed + 1 end
    end
    state.load.needsContinue = false
    state.load.stalled = false
    state.load.previousUnresolvedSignature = nil
    state.load.unresolvedRepeatCount = 0
    refreshCustomizationUi()
    log(("SUMMARY | preset='%s' | processed=%d | confirmed=%d | unconfirmed=%d | forced=%d | cleanupUnconfirmed=%d | failed=0 | unavailable=0 | ambiguous=0 | passes=%d | result=%s")
      :format(state.load.presetName or state.library.selected,
        applied, math.max(0, applied - unconfirmed), unconfirmed,
        forced, cleanupSkipped, state.load.pass,
        (cleanupSkipped > 0 or unconfirmed > 0) and "complete-with-warning" or "complete"),
      (cleanupSkipped > 0 or unconfirmed > 0) and "warn" or "complete")
    helpers.logLoadMeasurements("complete")
    if cleanupSkipped > 0 or unconfirmed > 0 then
      local details = {}
      if unconfirmed > 0 then
        details[#details + 1] = ("%d saved option%s could not be confirmed")
          :format(unconfirmed, unconfirmed == 1 and "" or "s")
      end
      if cleanupSkipped > 0 then
        details[#details + 1] = ("%d remaining option%s could not be confirmed as cleared")
          :format(cleanupSkipped, cleanupSkipped == 1 and "" or "s")
      end
      setStatus("load", "Preset load finished, but " .. table.concat(details, " and ") ..
        ". Check the appearance and Activity Log before confirming the editor.",
        false, "warning")
    elseif forced > 0 then
      setStatus("load", (
        "Preset fully applied: %d options applied in %d pass%s. Force Full Load matched %d option%s. " ..
        "Check the hair, hair color, and other forced options."
      ):format(valueCount, state.load.pass, state.load.pass == 1 and "" or "es", forced,
        forced == 1 and "" or "s"), false, "success")
    else
      setStatus("load", ("Preset fully applied: %d options applied in %d pass%s.")
        :format(valueCount, state.load.pass, state.load.pass == 1 and "" or "es"),
        false, "success")
    end
  end
end

function loadPreset()
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
  local optionsStarted = helpers.loadClock()
  local refreshCleanup = state.load.pendingChange
    and state.load.pendingChange.kind ~= "apply"
  local system, options, optionsError = getOptions(refreshCleanup)
  state.load.optionsSeconds = state.load.optionsSeconds
    + math.max(0, helpers.loadClock() - optionsStarted)
  state.load.optionCalls = state.load.optionCalls + 1
  if not options then
    setStatus("load", "Open a customization screen before loading a preset.", true)
    log("[load] " .. tostring(optionsError), "warn")
    return
  end
  local preset = selectedPreset
  local values, savedCounts, orderedEntries, savedSlotCounts, valueCount, savedEntryByKey
  if state.load.presetName == loadName then
    state.load.pass = state.load.pass + 1
    values = state.load.values
    savedCounts = state.load.savedCounts
    orderedEntries = state.load.orderedEntries
    savedEntryByKey = state.load.savedEntryByKey
    savedSlotCounts = state.load.savedSlotCounts
    valueCount = state.load.valueCount
  else
    if not state.load.overridePreset then
      saveAppearanceHistorySnapshot(options, "Before loading " .. tostring(loadName))
    end
    values, savedCounts, orderedEntries, savedSlotCounts, valueCount, savedEntryByKey =
      beginLoadPass(preset, loadName)
  end
  local result = continueLoadPass(system, options, preset, values, savedCounts,
    orderedEntries, savedSlotCounts, valueCount, savedEntryByKey)
  if state.load.presetName and not state.load.needsContinue
      and not state.load.pendingChange then
    helpers.releaseFinishedLoadWorkingData()
    state.invalidatePreflight()
  end
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
  state.load.overridePreset = preset
  state.load.overrideName = "Appearance Before Last Load"
  state.load.autoTimer = 0
  state.load.autoPasses = 0
  state.load.resetBefore = true
  loadPreset()
  if state.load.needsContinue then state.load.auto = true end
  return state.load.presetName == state.load.overrideName
end

refreshPreflight = function()
  if compareSelectedPreset then
    compareSelectedPreset()
    return
  end
  local preflightStarted = helpers.loadClock()
  helpers.syncForceFullLoadSelection()
  state.load.preflight = nil
  state.load.preflightDirty = false
  state.load.preflightPresetName = state.library.selected
  local preset = state.library.selected and state.library.presets[state.library.selected]
  if not preset then return end
  local wasLazy = not preset.entries
  preset = hydrateNamedPreset(state.library.selected)
  if not preset then return end
  if wasLazy then
    state.library.presetNotes = preset.notes or ""
    state.library.presetTags = preset.tags or ""
    writeInventory(state.library.presets, state.library.folders)
  end
  local optionsStarted = helpers.loadClock()
  local _, options = getOptions()
  local optionsSeconds = math.max(0, helpers.loadClock() - optionsStarted)
  state.app.inCustomization = options ~= nil
  if not options then
    if optionsSeconds >= SLOW_PREFLIGHT_SECONDS then
      log(("[PERFORMANCE] Appearance option retrieval took %.3f seconds while checking '%s'.")
        :format(optionsSeconds, tostring(state.library.selected)), "warn")
    end
    return
  end
  local matchingStarted = helpers.loadClock()
  local savedCounts, savedSlotCounts = {}, {}
  for _, entry in ipairs(preset.entries or {}) do
    savedCounts[entry.key] = (savedCounts[entry.key] or 0) + 1
    local slot = tostring(entry.slot or "")
    if slot ~= "" then savedSlotCounts[slot] = (savedSlotCounts[slot] or 0) + 1 end
  end
  local exposedCounts, exposedByLabel, exposedBySlot = {}, {}, {}
  local activeSlotCounts = {}
  for _, option in ipairs(options) do
    local key = optionKey(option)
    if key and option.isEditable and option.isActive then
      exposedCounts[key] = (exposedCounts[key] or 0) + 1
      exposedByLabel[key] = exposedByLabel[key] or {}
      table.insert(exposedByLabel[key], option)
      local slot = optionSlot(option)
      if slot then
        activeSlotCounts[slot] = (activeSlotCounts[slot] or 0) + 1
        exposedBySlot[slot] = exposedBySlot[slot] or {}
        table.insert(exposedBySlot[slot], option)
      end
    end
  end
  local available, unavailable, ambiguous, invalid = 0, 0, 0, 0
  local savedOccurrences, savedSlotOccurrences, claimedOptions = {}, {}, {}
  for _, entry in ipairs(preset.entries or {}) do
    local key = entry.key
    savedOccurrences[key] = (savedOccurrences[key] or 0) + 1
    local candidate = nil
    if (exposedCounts[key] or 0) == (savedCounts[key] or 0) then
      candidate = (exposedByLabel[key] or {})[savedOccurrences[key]]
    end
    local slot = tostring(entry.slot or "")
    if slot ~= "" then
      savedSlotOccurrences[slot] = (savedSlotOccurrences[slot] or 0) + 1
    end
    if not candidate and slot ~= ""
        and (savedSlotCounts[slot] or 0) == (activeSlotCounts[slot] or 0) then
      local slotCandidate = (exposedBySlot[slot] or {})[savedSlotOccurrences[slot]]
      if slotCandidate and not claimedOptions[slotCandidate]
          and (state.load.forceFull
            or (entry.choice and optionChoiceIndex(slotCandidate, entry.choice) ~= nil)) then
        candidate = slotCandidate
      end
    end
    if not optionIndexIsValid(tonumber(entry.index)) then
      invalid = invalid + 1
    elseif candidate and not claimedOptions[candidate] then
      if entry.choice and optionChoiceIndex(candidate, entry.choice) == nil then
        unavailable = unavailable + 1
      else
        available = available + 1
        claimedOptions[candidate] = true
      end
    elseif tonumber(entry.index) == 0 and (exposedCounts[key] or 0) == 0 then
      available = available + 1
    elseif (exposedCounts[key] or 0) == 0 then
      unavailable = unavailable + 1
    else
      ambiguous = ambiguous + 1
    end
  end
  state.load.preflight = {
    total = state.presetEntryCount(preset),
    available = available,
    unavailable = unavailable,
    ambiguous = ambiguous,
    invalid = invalid,
  }
  local totalSeconds = math.max(0, helpers.loadClock() - preflightStarted)
  if totalSeconds >= SLOW_PREFLIGHT_SECONDS then
    local matchingSeconds = math.max(0, helpers.loadClock() - matchingStarted)
    log(("[PERFORMANCE] Preset option check took %.3f seconds: appearance options=%.3f matching=%.3f preset='%s' liveOptions=%d savedOptions=%d.")
      :format(totalSeconds, optionsSeconds, matchingSeconds,
        tostring(state.library.selected), #options, #(preset.entries or {})), "warn")
  end
end

function cancelLoading()
  local name = state.load.presetName or state.library.selected
  if state.load.presetName then helpers.logLoadMeasurements("canceled") end
  resetLoadState()
  setStatus("load", name and ("Loading canceled for \"" .. name .. "\".")
    or "Loading canceled.")
end

return _ENV
