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
  state.load.nextInterval = kind == "apply" and AUTO_LOAD_TIMING.pollInterval
    or AUTO_LOAD_TIMING.passInterval
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
    state.load.nextInterval = pending.kind == "apply"
      and AUTO_LOAD_TIMING.pollInterval or AUTO_LOAD_TIMING.passInterval
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
    local saved = state.load.savedEntryByKey and state.load.savedEntryByKey[key]
    if candidate and saved and saved.choice then
      target = optionChoiceIndex(candidate.option, saved.choice)
    end
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
        and (tonumber(candidate.option.currIndex) or 0) == remap.target
        and (not remap.choice or optionChoiceIndex(candidate.option, remap.choice) == remap.target) then
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


return _ENV
