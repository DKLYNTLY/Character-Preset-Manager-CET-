local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

state.logLoadOnce = function(key, message, level)
  key = tostring(key or message)
  if state.loadLoggedWarnings[key] then return end
  state.loadLoggedWarnings[key] = true
  log(message, level)
end

state.loadOptionIdentity = function(option, key, occurrence)
  local cacheKey = tostring(key or "unknown") .. "\31" .. tostring(occurrence or 1)
  local identity = state.loadOptionIdentityCache[cacheKey]
  if not identity then
    identity = optionAuditIdentity(option, key, occurrence)
    state.loadOptionIdentityCache[cacheKey] = identity
  end
  return identity
end

function savedEntryAuditIdentity(entry)
  local preset = state.presets[state.loadPresetName or state.selected]
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

helpers.scanLoadOptions = function(options, relevantLabels, relevantSlots)
  local started = helpers.loadClock()
  relevantLabels = relevantLabels or {}
  relevantSlots = relevantSlots or {}
  local result = {
    exposed = {},
    activeExposed = {},
    activeByKey = {},
    activeKeySet = {},
    activeCounts = {},
    exposedBySlot = {},
    activeSlotCounts = {},
    structureChanged = false,
  }
  local occurrences, activeSlotCounts, signatureParts = {}, result.activeSlotCounts, {}
  local fullExposure = state.forceFullLoad or state.loadPhase == "cleanup"
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
    local pending = state.loadPendingChange
    local choiceShape = label and (relevantLabels[label]
      or (pending and pending.label == label))
        and helpers.loadChoiceShape(option) or "not-checked"
    local pendingOption = state.loadPendingChange
    local includeOption = key and (fullExposure or relevantLabels[label]
      or (slot and relevantSlots[slot])
      or (pendingOption and pendingOption.label == label))
    if includeOption then
      local exposedOption = {
        option = option,
        position = position,
        label = label,
        key = key,
        occurrence = occurrence,
        slot = slot,
        slotOccurrence = slotOccurrence,
        choiceShape = choiceShape,
      }
      result.exposed[#result.exposed + 1] = exposedOption
      result.activeKeySet[key] = true
      result.activeByKey[key] = exposedOption
      result.activeExposed[#result.activeExposed + 1] = exposedOption
      if slot then
        result.exposedBySlot[slot .. "\31" .. tostring(slotOccurrence)] = exposedOption
      end
    end
    signatureParts[position] = table.concat({
      tostring(label or ""), tostring(occurrence or 0), tostring(slot or ""),
      tostring(slotOccurrence or 0), editable and "1" or "0", active and "1" or "0",
    }, "\29")
  end
  result.signature = table.concat(signatureParts, "\30")
  local previousSignature = state.loadLastStructureSignature
  if previousSignature and previousSignature ~= result.signature then
    result.structureChanged = true
    state.loadStructureChanges = state.loadStructureChanges + 1
    state.loadResolvedChoiceIndexes = {}
    state.loadOptionIdentityCache = {}
    state.loadDependencyRemaps = {}
    local pending = state.loadPendingChange
    if pending then
      pending.longSettle = true
      state.loadDependencyKeys[pending.trackingKey] = true
      log(("DEPENDENCY | The editor option list changed after %s '%s'; waiting for it to settle.")
        :format(pending.kind, pending.identity), "info")
    else
      log(("DEPENDENCY | The editor option list changed between checks; %d options are now exposed.")
        :format(#options), "info")
    end
  end
  state.loadLastStructureSignature = result.signature
  state.loadScanSeconds = state.loadScanSeconds + math.max(0, helpers.loadClock() - started)
  return result
end

helpers.resolveLoadChoice = function(option, choice, cachedIndex)
  local started = helpers.loadClock()
  local resolved = cachedIndex
  if resolved == nil or not optionChoiceMatchesIndex(option, choice, resolved) then
    resolved = optionChoiceIndex(option, choice)
  end
  state.loadChoiceSeconds = state.loadChoiceSeconds
    + math.max(0, helpers.loadClock() - started)
  return resolved
end

helpers.loadOptionNeedsLongSettle = function(exposedOption, trackingKey)
  if state.loadDependencyKeys[trackingKey] then return true end
  local text = table.concat({
    tostring(exposedOption.label or ""),
    tostring(exposedOption.slot or ""),
    helpers.optionDisplayName(exposedOption.option, exposedOption.label),
  }, " "):lower()
  return text:find("hair", 1, true) ~= nil or text:find("beard", 1, true) ~= nil
end

helpers.pollPendingOption = function(options)
  local pending = state.loadPendingChange
  if not pending or not pending.longSettle or state.forceFullLoad
      or state.loadTargetPollingDisabled or not pending.position
      or pending.confirmedDisappeared or not pending.confirmedAt then
    return "full"
  end
  local started = helpers.loadClock()
  state.loadTargetPolls = state.loadTargetPolls + 1
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
  state.loadTargetPollSeconds = state.loadTargetPollSeconds
    + math.max(0, helpers.loadClock() - started)
  if not valid then
    state.loadTargetFallbacks = state.loadTargetFallbacks + 1
    state.loadTargetPollingDisabled = true
    state.loadResolvedChoiceIndexes = {}
    state.loadOptionIdentityCache = {}
    state.loadDependencyRemaps = {}
    log(("[FALLBACK] A dependency no longer matches its saved position; normal full checks will be used for the rest of this load: %s")
      :format(pending.identity), "warn")
    return "fallback"
  end
  local current = tonumber(candidate.currIndex) or 0
  if current ~= pending.target
      or state.loadElapsed - pending.confirmedAt
        >= AUTO_LOAD_TIMING.dependencyStableTime then
    return "full"
  end
  state.loadNextInterval = AUTO_LOAD_TIMING.pollInterval
  state.loadPendingElapsed = math.max(0, state.loadElapsed - pending.startedAt)
  return "waiting"
end

helpers.beginPendingChange = function(system, exposedOption, target, kind, trackingKey, current)
  local attempts = kind == "cleanup" and state.loadCleanupAttempts
    or state.loadApplyAttempts
  local started = helpers.loadClock()
  local ok, applyError = pcall(
    system.ApplyChangeToOption, system, exposedOption.option, target)
  state.loadApplySeconds = state.loadApplySeconds
    + math.max(0, helpers.loadClock() - started)
  if not ok then return false, applyError end
  attempts[trackingKey] = (attempts[trackingKey] or 0) + 1
  local longSettle = helpers.loadOptionNeedsLongSettle(exposedOption, trackingKey)
  exposedOption.choiceShape = helpers.loadChoiceShape(exposedOption.option)
  local identity = state.loadOptionIdentity(
    exposedOption.option, exposedOption.label, exposedOption.occurrence)
  if kind == "apply" then
    identity = identity .. savedEntryAuditIdentity(
      state.loadSavedEntryByKey and state.loadSavedEntryByKey[trackingKey])
  end
  state.loadPendingChange = {
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
    startedAt = state.loadElapsed,
    attemptStartedAt = state.loadElapsed,
    structureSignature = state.loadLastStructureSignature,
    confirmedAt = nil,
    confirmedSignature = nil,
    confirmedDisappeared = false,
    longSettle = longSettle,
  }
  state.loadPendingElapsed = 0
  state.loadNextInterval = AUTO_LOAD_TIMING.interval
  state.loadNeedsContinue = true
  state.previousUnresolvedSignature = nil
  state.unresolvedRepeatCount = 0
  return true
end

helpers.clearVisibleLoadSatisfaction = function(scan)
  for key in pairs(scan.activeKeySet) do
    if not state.loadUnconfirmed[key] then state.loadSatisfied[key] = nil end
  end
  state.loadApplyAttempts = {}
  state.previousUnresolvedSignature = nil
  state.unresolvedRepeatCount = 0
end

helpers.checkPendingChange = function(system, scan)
  local pending = state.loadPendingChange
  if not pending then return "none" end
  local candidate = scan.activeByKey[pending.optionKey]
  if candidate and (candidate.label ~= pending.label
      or candidate.occurrence ~= pending.occurrence
      or candidate.slot ~= pending.slot) then
    candidate = nil
    state.loadTargetPollingDisabled = true
    state.loadResolvedChoiceIndexes = {}
    state.loadOptionIdentityCache = {}
    state.loadDependencyRemaps = {}
    log(("[FALLBACK] Live option identity changed while waiting for %s; normal full checks will be used for the rest of this load: %s")
      :format(pending.kind, pending.identity), "warn")
  elseif candidate and candidate.choiceShape ~= pending.choiceShape then
    if not pending.choiceStructureChanged then
      state.loadTargetPollingDisabled = true
      state.loadResolvedChoiceIndexes = {}
      state.loadOptionIdentityCache = {}
      state.loadDependencyRemaps = {}
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
        pending.confirmedAt = state.loadElapsed
        pending.confirmedSignature = scan.signature
        pending.confirmedDisappeared = disappeared
        state.loadNextInterval = AUTO_LOAD_TIMING.pollInterval
        setStatus("load", disappeared
          and "A dependent option was replaced. Waiting for the editor to settle."
          or "The option changed. Waiting for dependent options to settle.")
        return "waiting"
      end
      if state.loadElapsed - pending.confirmedAt
          < AUTO_LOAD_TIMING.dependencyStableTime then
        state.loadNextInterval = AUTO_LOAD_TIMING.pollInterval
        return "waiting"
      end
    end
    local waited = math.max(0, state.loadElapsed - pending.startedAt)
    state.loadWaitSeconds = state.loadWaitSeconds + waited
    state.loadPendingElapsed = waited
    state.loadPendingChange = nil
    state.loadNextInterval = AUTO_LOAD_TIMING.interval
    if pending.kind == "apply" then
      state.loadSatisfied[pending.trackingKey] = true
      state.loadUnconfirmed[pending.trackingKey] = nil
      if pending.forced then state.loadForcedKeys[pending.trackingKey] = true end
    else
      state.loadPhase = "verify"
      state.loadReturnToCleanup = true
      helpers.clearVisibleLoadSatisfaction(scan)
    end
    log(("SETTLED | %s | %s | target=%s | result=%s | currIndex wait=%.3fs | structureChanged=%s")
      :format(pending.kind, pending.identity, tostring(pending.target),
        disappeared and "dependent option disappeared" or "value confirmed",
        waited, tostring(structureChanged)), "info")
    return "settled"
  end
  local sinceAttempt = state.loadElapsed - pending.attemptStartedAt
  if pending.longSettle and sinceAttempt < AUTO_LOAD_TIMING.dependencyTimeout then
    state.loadNextInterval = AUTO_LOAD_TIMING.interval
    state.loadPendingElapsed = math.max(0, state.loadElapsed - pending.startedAt)
    return "waiting"
  end
  local waited = math.max(0, state.loadElapsed - pending.startedAt)
  state.loadWaitSeconds = state.loadWaitSeconds + waited
  state.loadPendingChange = nil
  state.loadNextInterval = AUTO_LOAD_TIMING.interval
  if pending.kind == "cleanup" then
    state.loadCleanupSkipped[pending.trackingKey] = true
    state.loadPhase = "verify"
    state.loadReturnToCleanup = true
    helpers.clearVisibleLoadSatisfaction(scan)
    state.logLoadOnce("cleanup-not-confirmed:" .. pending.trackingKey,
      ("[UNCONFIRMED] The game did not expose whether a remaining option cleared after %.3fs. It was not applied again: %s")
        :format(waited, pending.identity), "warn")
  else
    state.loadSatisfied[pending.trackingKey] = true
    state.loadUnconfirmed[pending.trackingKey] = true
    if pending.forced then state.loadForcedKeys[pending.trackingKey] = true end
    state.logLoadOnce("apply-not-confirmed:" .. pending.trackingKey,
      ("[UNCONFIRMED] The game did not update currIndex after %.3fs. The option was applied once and was not repeated: %s targetIndex=%s")
        :format(waited, pending.identity, tostring(pending.target)), "warn")
  end
  return "unconfirmed"
end

helpers.logLoadMeasurements = function(result)
  log(("[MEASURE] Load %s | preset='%s' | elapsed=%.3fs | option checks=%d time=%.6fs | full scans=%.6fs | dependency polls=%d time=%.6fs fallbacks=%d | choice matching=%.6fs | applied calls=%.6fs | waiting=%.3fs | dependency changes=%d")
    :format(tostring(result), tostring(state.loadPresetName or state.selected),
      state.loadElapsed, state.loadOptionCalls, state.loadOptionsSeconds,
      state.loadScanSeconds, state.loadTargetPolls, state.loadTargetPollSeconds,
      state.loadTargetFallbacks, state.loadChoiceSeconds, state.loadApplySeconds,
      state.loadWaitSeconds, state.loadStructureChanges), "info")
end

beginLoadPass = function(preset)
  helpers.auditSection("LOAD PRESET")
  log(("[PRESET] Load requested: name='%s'"):format(tostring(state.selected)), "load")
  state.loadPresetName = state.selected
  state.loadPass = 1
  state.previousUnresolvedSignature = nil
  state.unresolvedRepeatCount = 0
  state.loadSatisfied = {}
  state.loadForcedKeys = {}
  state.loadResolvedChoiceIndexes = {}
  state.loadApplyAttempts = {}
  state.loadUnconfirmed = {}
  state.loadCleanupAttempts = {}
  state.loadCleanupSkipped = {}
  state.loadPhase = "apply"
  state.loadReturnToCleanup = false
  local values, savedCounts, orderedEntries, savedSlotCounts, valueCount, savedEntryByKey = {}, {}, {}, {}, 0, {}
  for _, entry in ipairs(preset.entries or {}) do
    local label = tostring(entry.key or "")
    if label ~= "" then
      savedCounts[label] = (savedCounts[label] or 0) + 1
      local savedKey = label .. "\31" .. tostring(savedCounts[label])
      values[savedKey] = tonumber(entry.index) or 0
      local slot = tostring(entry.slot or "")
      local slotOccurrence = nil
      if slot ~= "" then
        savedSlotCounts[slot] = (savedSlotCounts[slot] or 0) + 1
        slotOccurrence = savedSlotCounts[slot]
      end
      table.insert(orderedEntries, {
        key = savedKey,
        label = label,
        index = tonumber(entry.index) or 0,
        slot = slot ~= "" and slot or nil,
        slotOccurrence = slotOccurrence,
        choice = entry.choice,
        position = #orderedEntries + 1,
      })
      savedEntryByKey[savedKey] = orderedEntries[#orderedEntries]
      valueCount = valueCount + 1
    end
  end
  state.loadValues = values
  state.loadSavedCounts = savedCounts
  state.loadOrderedEntries = orderedEntries
  state.loadSavedEntryByKey = savedEntryByKey
  state.loadSavedSlotCounts = savedSlotCounts
  state.loadValueCount = valueCount
  return values, savedCounts, orderedEntries, savedSlotCounts, valueCount, savedEntryByKey
end

continueLoadPass = function(system, options, preset, values, savedCounts,
    orderedEntries, savedSlotCounts, valueCount, savedEntryByKey)
  state.loadStalled = false
  if valueCount == 0 then setStatus("load", "The preset contains no saved options.", true); return end

  if state.loadPass == 1 then
    log(("Preset='%s' | saved=%d options | editor exposes=%d options | format=%s")
      :format(state.selected, valueCount, #options, tostring(preset.format or 1)),
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
      and state.loadPhase == "verify" then
    state.loadRemaining = valueCount
    state.loadNeedsContinue = true
    setStatus("load", "A remaining option was cleared. Verifying the preset again.")
    return
  end

  if state.loadPhase == "cleanup" and scan.structureChanged then
    state.loadPhase = "verify"
    state.loadReturnToCleanup = true
    state.loadRemaining = valueCount
    state.loadNeedsContinue = true
    helpers.clearVisibleLoadSatisfaction(scan)
    log("CLEANUP | The editor structure changed before cleanup. Verifying the preset again before clearing anything.", "info")
    setStatus("load",
      "The editor changed before cleanup. Checking the preset again first.")
    return
  end

  if state.loadPhase == "cleanup" then
    for _, exposedOption in ipairs(exposed) do
      local label = exposedOption.label
      local occurrence = exposedOption.occurrence
      local cleanupKey = exposedOption.key
      local current = tonumber(exposedOption.option.currIndex) or 0
      local remap = cleanupKey and state.loadDependencyRemaps[cleanupKey] or nil
      local keepRemap = remap and state.loadSatisfied[remap.savedKey]
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
        state.loadDependencyRemaps[cleanupKey] = nil
      end
      if cleanupKey and occurrence > (savedCounts[label] or 0)
          and current ~= 0 and not keepRemap
          and not state.loadCleanupSkipped[cleanupKey] then
        local ok, clearError = helpers.beginPendingChange(
          system, exposedOption, 0, "cleanup", cleanupKey, current)
        if not ok then
          state.resetBeforeLoad = false
          state.loadNeedsContinue = false
          state.loadStalled = true
          log(("FAILED | pass=%d | %s | index %d -> 0 | reset leftover | %s")
            :format(state.loadPass,
              state.loadOptionIdentity(exposedOption.option, label, occurrence),
              current, tostring(clearError)), "error")
          setStatus("load",
            "Loading stopped because a remaining option could not be cleared safely. Close the editor without confirming, reopen it, and retry.",
            true)
          helpers.logLoadMeasurements("cleanup-failed")
        else
          log(("CHANGE | pass=%d | %s | index %d -> 0 | post-apply leftover cleanup")
            :format(state.loadPass,
              state.loadOptionIdentity(exposedOption.option, label, occurrence),
              current), "info")
          setStatus("load", "Clearing one remaining option. Waiting for the editor.")
        end
        return
      end
    end
    state.loadPhase = "verify"
    state.loadReturnToCleanup = false
    state.resetBeforeLoad = false
    state.loadRemaining = valueCount
    state.loadNeedsContinue = true
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
      local cachedIndex = state.loadResolvedChoiceIndexes[key]
      local resolvedIndex = helpers.resolveLoadChoice(
        exposedOption.option, savedEntry.choice, cachedIndex)
      if resolvedIndex ~= nil then
        state.loadResolvedChoiceIndexes[key] = resolvedIndex
        wanted = resolvedIndex
        values[key] = resolvedIndex
      end
    end
    local countMatches = label
      and (savedCounts[label] or 0) == (activeCounts[label] or 0)
    if wanted ~= nil and countMatches and optionIndexIsValid(wanted)
        and ((tonumber(exposedOption.option.currIndex) or 0) == wanted
          or (state.loadSatisfied[key] and state.loadUnconfirmed[key])) then
      satisfiedBefore = satisfiedBefore + 1
    end
  end
  for key in pairs(values) do
    if not activeKeySet[key] and state.loadSatisfied[key] then
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
        option, savedEntry.choice, state.loadResolvedChoiceIndexes[key])
      if resolvedIndex == nil then
        state.loadResolvedChoiceIndexes[key] = nil
        choiceUnavailable = true
      else
        state.loadResolvedChoiceIndexes[key] = resolvedIndex
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
        state.loadSatisfied[key] = true
        state.loadUnconfirmed[key] = nil
        applied = applied + 1
      elseif state.loadSatisfied[key] and state.loadUnconfirmed[key] then
        applied = applied + 1
      elseif state.loadSatisfied[key] then
        deferred[key] = true
        missing = missing + 1
        unresolved["reverted:" .. tostring(key)] = true
      else
        if savedEntry and savedEntry.choice and wanted ~= savedEntry.index then
          log(("CHOICE REMAP | pass=%d | %s | savedIndex=%s currentIndex=%s choice='%s'")
            :format(state.loadPass,
              state.loadOptionIdentity(option, label, exposedOption.occurrence),
              tostring(savedEntry.index), tostring(wanted), tostring(savedEntry.choice)),
            "info")
        end
        local ok, applyError = helpers.beginPendingChange(
          system, exposedOption, wanted, "apply", key, current)
        if ok then
          state.loadRemaining = math.max(0, valueCount - satisfiedBefore - 1)
          log(("CHANGE | pass=%d | %s | index %s -> %s")
            :format(state.loadPass,
              state.loadOptionIdentity(option, label, exposedOption.occurrence),
              tostring(current), tostring(wanted)), "info")
          setStatus("load", ("Applied one option. Waiting for the editor; %d %s remain%s to be checked.")
            :format(state.loadRemaining,
              state.loadRemaining == 1 and "option" or "options",
              state.loadRemaining == 1 and "s" or ""))
        else
          state.loadNeedsContinue = false
          state.loadStalled = true
          log(("FAILED | pass=%d | %s | target index %s | %s")
            :format(state.loadPass,
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
    if wanted == 0 and not activeKeySet[key] and not state.loadSatisfied[key] then
      state.loadSatisfied[key] = true
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
          state.loadResolvedChoiceIndexes[savedKey])
        if target ~= nil and optionIndexIsValid(target) then
          state.loadResolvedChoiceIndexes[savedKey] = target
          seen[savedKey] = true
          claimedOptions[candidate.option] = true
          state.loadDependencyRemaps[candidate.key] = {
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
            state.loadSatisfied[savedKey] = true
            state.loadUnconfirmed[savedKey] = nil
            applied = applied + 1
          elseif state.loadSatisfied[savedKey] and state.loadUnconfirmed[savedKey] then
            applied = applied + 1
          elseif state.loadSatisfied[savedKey] then
            deferred[savedKey] = true
            missing = missing + 1
            unresolved["reverted-remap:" .. tostring(savedKey)] = true
          else
            state.loadDependencyKeys[savedKey] = true
            local ok, applyError = helpers.beginPendingChange(
              system, candidate, target, "apply", savedKey, current)
            if ok then
              state.loadRemaining = math.max(0, valueCount - satisfiedBefore - 1)
              log(("DEPENDENCY REMAP | pass=%d | saved LocKey='%s' disappeared | uiSlot='%s' and saved choice='%s' matched %s | index %s -> %s")
                :format(state.loadPass, entry.label, entry.slot, entry.choice,
                  optionAuditIdentity(candidate.option, candidate.label,
                    candidate.occurrence), tostring(current), tostring(target)), "info")
              setStatus("load",
                "A hairstyle-dependent option was replaced. Its saved choice was matched safely; waiting for the editor.")
            else
              state.loadNeedsContinue = false
              state.loadStalled = true
              log(("DEPENDENCY REMAP FAILED | pass=%d | saved LocKey='%s' | uiSlot='%s' target index %s | %s")
                :format(state.loadPass, entry.label, entry.slot, tostring(target),
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
  if state.forceFullLoad then
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
            state.loadDependencyRemaps[candidate.key] = {
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
              state.loadSatisfied[savedKey] = true
              state.loadUnconfirmed[savedKey] = nil
              state.loadForcedKeys[savedKey] = true
            elseif state.loadSatisfied[savedKey] and state.loadUnconfirmed[savedKey] then
              state.loadForcedKeys[savedKey] = true
            elseif state.loadSatisfied[savedKey] then
              state.loadForcedKeys[savedKey] = nil
              deferred[savedKey] = true
              missing = missing + 1
              unresolved["reverted-force:" .. tostring(savedKey)] = true
            else
              local ok, applyError = helpers.beginPendingChange(
                system, candidate, target, "apply", savedKey, current)
              if ok then
                state.loadPendingChange.forced = true
                state.loadRemaining = math.max(0, valueCount - satisfiedBefore - 1)
                log(("FORCED | pass=%d | saved LocKey='%s' unavailable | %s fallback -> %s | index %s -> %s")
                  :format(state.loadPass, entry.label, method,
                    optionAuditIdentity(candidate.option, candidate.label, candidate.occurrence),
                    tostring(current), tostring(target)), "warn")
                setStatus("load",
                  "Applied one unmatched option using Force Full Load. Waiting for the editor.")
                return
              else
                state.loadForcedKeys[savedKey] = nil
                log(("FORCE FAILED | pass=%d | saved LocKey='%s' | %s fallback target index %s | %s")
                  :format(state.loadPass, entry.label, method, tostring(target),
                    tostring(applyError)), "error")
                state.loadNeedsContinue = false
                state.loadStalled = true
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

  for key in pairs(deferred) do state.loadSatisfied[key] = nil end

  local forced = 0
  for key in pairs(values) do
    if not seen[key] then
      if state.loadSatisfied[key] then
        applied = applied + 1
        if state.loadForcedKeys[key] then forced = forced + 1 end
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
    elseif state.loadForcedKeys[key] then
      applied = applied + 1
      forced = forced + 1
    end
  end
  state.loadRemaining = missing + ambiguous + invalid
  if state.loadRemaining > 0 then
    local signature = unresolvedSignature(unresolved)
    if state.previousUnresolvedSignature == signature then
      state.unresolvedRepeatCount = state.unresolvedRepeatCount + 1
    else
      state.previousUnresolvedSignature = signature
      state.unresolvedRepeatCount = 1
    end
    if state.unresolvedRepeatCount >= STALL_CONFIRMATION_PASSES then
      state.loadNeedsContinue = false
      state.loadStalled = true
      refreshCustomizationUi()
      log(("SUMMARY | preset='%s' | applied=%d | unresolved=%d | passes=%d | result=stopped")
        :format(state.selected, applied, state.loadRemaining, state.loadPass), "warn")
      log(("Load stalled: preset='%s' pass=%d unresolved=%d signature='%s'")
        :format(state.selected, state.loadPass, state.loadRemaining, signature), "warn")
      helpers.logLoadMeasurements("stopped")
      setStatus("load", (
        "Loading stopped because %d of %d options were still missing after %d checks. " ..
        "Adding, removing, updating, or changing the order of CCXL mods can move or rename options. " ..
        "Check your option mods. Correct the appearance if needed, then save the preset again."
      ):format(state.loadRemaining, valueCount, STALL_CONFIRMATION_PASSES))
    else
      state.loadNeedsContinue = true
      setStatus("load", ("Pass %d complete: %d of %d applied, %d remaining. Continuing automatically.")
        :format(state.loadPass, applied, valueCount, state.loadRemaining))
    end
  else
    if state.loadPhase == "apply" and state.resetBeforeLoad then
      state.loadPhase = "cleanup"
      state.loadRemaining = valueCount
      state.loadNeedsContinue = true
      state.previousUnresolvedSignature = nil
      state.unresolvedRepeatCount = 0
      log("APPLY | Saved preset options were processed. Checking for genuine leftovers next.", "info")
      setStatus("load", "Preset options applied. Checking for remaining options.")
      return
    end
    if state.loadPhase == "verify" and state.loadReturnToCleanup then
      state.loadPhase = "cleanup"
      state.loadReturnToCleanup = false
      state.loadRemaining = valueCount
      state.loadNeedsContinue = true
      state.previousUnresolvedSignature = nil
      state.unresolvedRepeatCount = 0
      log("VERIFY | Post-cleanup preset check finished. Checking for another leftover option.", "info")
      setStatus("load", "Preset checked. Looking for another remaining option.")
      return
    end
    local cleanupSkipped = 0
    for _ in pairs(state.loadCleanupSkipped) do cleanupSkipped = cleanupSkipped + 1 end
    local unconfirmed = 0
    for key in pairs(state.loadUnconfirmed) do
      if values[key] ~= nil then unconfirmed = unconfirmed + 1 end
    end
    state.loadNeedsContinue = false
    state.loadStalled = false
    state.previousUnresolvedSignature = nil
    state.unresolvedRepeatCount = 0
    refreshCustomizationUi()
    log(("SUMMARY | preset='%s' | processed=%d | confirmed=%d | unconfirmed=%d | forced=%d | cleanupUnconfirmed=%d | failed=0 | unavailable=0 | ambiguous=0 | passes=%d | result=%s")
      :format(state.selected, applied, math.max(0, applied - unconfirmed), unconfirmed,
        forced, cleanupSkipped, state.loadPass,
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
      ):format(valueCount, state.loadPass, state.loadPass == 1 and "" or "es", forced,
        forced == 1 and "" or "s"), false, "success")
    else
      setStatus("load", ("Preset fully applied: %d options applied in %d pass%s.")
        :format(valueCount, state.loadPass, state.loadPass == 1 and "" or "es"),
        false, "success")
    end
  end
end

function loadPreset()
  if not state.selected or not state.presets[state.selected] then
    resetLoadState()
    setStatus("load", "Select a preset.", true)
    return
  end
  local selectedPreset = hydrateNamedPreset(state.selected)
  if not selectedPreset then
    resetLoadState()
    setStatus("load", "The selected preset could not be read safely.", true)
    return
  end
  local optionsStarted = helpers.loadClock()
  local system, options, optionsError = getOptions()
  state.loadOptionsSeconds = state.loadOptionsSeconds
    + math.max(0, helpers.loadClock() - optionsStarted)
  state.loadOptionCalls = state.loadOptionCalls + 1
  if not options then
    setStatus("load", "Open a customization screen before loading a preset.", true)
    log("[load] " .. tostring(optionsError), "warn")
    return
  end
  if state.loadPresetName ~= state.selected then refreshPreflight() end

  local preset = selectedPreset
  local values, savedCounts, orderedEntries, savedSlotCounts, valueCount, savedEntryByKey
  if state.loadPresetName == state.selected then
    state.loadPass = state.loadPass + 1
    values = state.loadValues
    savedCounts = state.loadSavedCounts
    orderedEntries = state.loadOrderedEntries
    savedEntryByKey = state.loadSavedEntryByKey
    savedSlotCounts = state.loadSavedSlotCounts
    valueCount = state.loadValueCount
  else
    values, savedCounts, orderedEntries, savedSlotCounts, valueCount, savedEntryByKey =
      beginLoadPass(preset)
  end
  return continueLoadPass(system, options, preset, values, savedCounts,
    orderedEntries, savedSlotCounts, valueCount, savedEntryByKey)
end

refreshPreflight = function()
  state.preflight = nil
  state.preflightDirty = false
  state.preflightPresetName = state.selected
  local preset = state.selected and state.presets[state.selected]
  if not preset then return end
  local wasLazy = not preset.entries
  preset = hydrateNamedPreset(state.selected)
  if not preset then return end
  if wasLazy then
    state.presetNotes = preset.notes or ""
    state.presetTags = preset.tags or ""
    writeInventory(state.presets, state.folders)
  end
  local _, options = getOptions()
  state.inCustomization = options ~= nil
  if not options then return end
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
          and (state.forceFullLoad
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
  state.preflight = {
    total = state.presetEntryCount(preset),
    available = available,
    unavailable = unavailable,
    ambiguous = ambiguous,
    invalid = invalid,
  }
end

function cancelLoading()
  local name = state.loadPresetName or state.selected
  if state.loadPresetName then helpers.logLoadMeasurements("canceled") end
  resetLoadState()
  setStatus("load", name and ("Loading canceled for \"" .. name .. "\".")
    or "Loading canceled.")
end

return _ENV
