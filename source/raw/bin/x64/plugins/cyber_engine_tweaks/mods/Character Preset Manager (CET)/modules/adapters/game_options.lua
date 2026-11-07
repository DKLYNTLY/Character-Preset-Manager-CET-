local loading = require("modules/application/loading")

local function install(runtime)
if setfenv then setfenv(1,runtime) end
local _ENV = runtime
local stateModel = require("modules/domain/state")
local acuBatch = require("modules/adapters/shared_load_adapter").new(runtime)
helpers.compareFormat9 = acuBatch.compare
helpers.noteAcuBatchChange = acuBatch.changed
local matching = require("modules/domain/matching")
local AUTO_LOAD_SAFETY_MARGIN = 10
local control = {}
local eventBuffers = {}
local emptyFields = {}
for kind in pairs(loading.fields) do
  eventBuffers[kind] = {kind=kind,timing=AUTO_LOAD_TIMING,limits=AUTO_LOAD_LIMITS,safetyMargin=AUTO_LOAD_SAFETY_MARGIN,
    stallPasses=STALL_CONFIRMATION_PASSES}
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
for _,field in ipairs({"waiting","groupWaitSeconds","accountedAt","waited","rebuildSignature","fullExposure","cleanupCount","unconfirmedCount"}) do
  control[field] = false
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
    if field == "scanResult" then control[field] = nil else control[field] = state.load[field] end
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
  elseif kind == "group_finish" or kind == "group_finish_write" then
    eventBuffers[kind].group,eventBuffers[kind].waiting = nil,nil
    control.waiting,control.groupWaitSeconds,control.accountedAt = nil,nil,nil
  elseif kind == "visible" then eventBuffers.visible.activeKeySet = nil
  elseif kind == "group_member" or kind == "group_collect" or kind == "pending" or kind == "poll_result" then
    eventBuffers[kind].pending,eventBuffers[kind].waiting = nil,nil
  elseif kind == "attempt" then eventBuffers.attempt.attempts = nil
  end
  if kind == "release" then releaseControl() end
  return actions[1]
end
local oldReset = resetLoadState
resetLoadState = function()
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
  stateModel.clearScanCollection(target)
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
  local optionCount = #options
  eventBuffers.scan_begin.optionCount = optionCount
  transition("scan_begin")
  local rebuildSignature,fullExposure = control.rebuildSignature,control.fullExposure
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
      key = matching.occurrenceKey(label, occurrence)
      if slot then
        activeSlotCounts[slot] = (activeSlotCounts[slot] or 0) + 1
        slotOccurrence = activeSlotCounts[slot]
      end
    end
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
      exposedOption.choiceShape = helpers.loadChoiceShape(option)
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
  local dependency = eventBuffers.scan_dependency
  dependency.rebuild,dependency.signature = rebuildSignature,result.signature
  local dependencyAction = transition("scan_dependency")
  if dependencyAction ~= "none" then
    result.structureChanged = true
    local pending = state.load.pendingChange
    if pending then
      log(("DEPENDENCY | The editor option list changed after %s '%s'; waiting for it to settle.")
        :format(pending.kind, pending.identity), "info")
    else
      log(("DEPENDENCY | The editor option list changed between checks; %d options are now exposed.")
        :format(#options), "info")
    end
  end
  local finish = eventBuffers.scan_finish
  finish.rebuild,finish.signature,finish.optionCount = rebuildSignature,result.signature,optionCount
  transition("scan_finish")
  state.load.scanCalls = state.load.scanCalls + 1
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
  }, " ")
  return matching.longSettleText(text)
end

helpers.pollPendingOption = function(options)
  local pending = state.load.pendingChange
  if transition("poll_gate") ~= "read" then return "full" end
  local started = helpers.loadClock()
  transition("poll_begin")
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
    transition("poll_fallback")
    log(("[FALLBACK] A dependency no longer matches its saved position; normal full checks will be used for the rest of this load: %s")
      :format(pending.identity), "warn")
    return "fallback"
  end
  local current = tonumber(candidate.currIndex) or 0
  eventBuffers.poll_result.pending,eventBuffers.poll_result.current = pending,current
  if transition("poll_result") == "wait" then return "waiting" end
  return "full"
end

helpers.beginPendingChange = function(system, exposedOption, target, kind, trackingKey, current)
  local attempts = kind == "apply" and state.load.applyAttempts or state.load.cleanupAttempts
  local started = helpers.loadClock()
  if helpers.appearanceTrace then
    helpers.appearanceTrace("compare", { slot = exposedOption.slot, label = exposedOption.label,
      occurrence = exposedOption.occurrence, kind = kind, target = target, trackingKey = trackingKey },
      exposedOption.option, "before-write")
  end
  local ok, applyError = pcall(
    system.ApplyChangeToOption, system, exposedOption.option, target)
  state.load.applySeconds = state.load.applySeconds
    + math.max(0, helpers.loadClock() - started)
  if not ok then return false, applyError end
  state.app.optionsMemo = nil
  eventBuffers.attempt.attempts = attempts
  eventBuffers.attempt.changeKind = kind
  eventBuffers.attempt.key = trackingKey
  transition("attempt")
  local longSettle = helpers.loadOptionNeedsLongSettle(exposedOption, trackingKey)
  exposedOption.choiceShape = helpers.loadChoiceShape(exposedOption.option)
  local identity = state.loadOptionIdentity(
    exposedOption.option, exposedOption.label, exposedOption.occurrence)
  if kind == "apply" then
    identity = identity .. savedEntryAuditIdentity(
      state.load.savedEntryByKey and state.load.savedEntryByKey[trackingKey])
  end
  local event = eventBuffers.begin_pending
  event.changeKind,event.key,event.optionKey = kind,trackingKey,exposedOption.key
  event.position,event.label,event.occurrence = exposedOption.position,exposedOption.label,exposedOption.occurrence
  event.slot,event.shape = exposedOption.slot,exposedOption.choiceShape
  event.target,event.current,event.identity,event.longSettle = target,current,identity,longSettle
  transition("begin_pending")
  return true
end

helpers.clearVisibleLoadSatisfaction = function(scan)
  eventBuffers.visible.activeKeySet = scan.activeKeySet
  transition("visible")
end

helpers.checkPendingChange = function(system, scan)
  local pending = state.load.pendingChange
  if not pending then return "none" end
  local candidate = scan.activeByKey[pending.optionKey]
  local identityEvent = eventBuffers.pending_identity
  identityEvent.present = candidate ~= nil
  identityEvent.label = candidate and candidate.label
  identityEvent.occurrence = candidate and candidate.occurrence
  identityEvent.slot = candidate and candidate.slot
  identityEvent.shape = candidate and candidate.choiceShape
  local identityAction = transition("pending_identity")
  if identityAction == "identity_fallback" then
    candidate = nil
    log(("[FALLBACK] Live option identity changed while waiting for %s; normal full checks will be used for the rest of this load: %s")
      :format(pending.kind, pending.identity), "warn")
  elseif identityAction == "shape_fallback" then
    log(("[FALLBACK] Choice structure changed while waiting for %s; the result will require manual confirmation: %s")
      :format(pending.kind, pending.identity), "warn")
  end
  if candidate then pending.position = candidate.position end
  local current = candidate and (tonumber(candidate.option.currIndex) or 0) or nil
  local disappeared = candidate == nil
  local structureChanged = scan.signature ~= pending.structureSignature
  local event = eventBuffers.pending
  event.pending,event.present,event.current,event.signature = pending,not disappeared,current,scan.signature
  local nextAction = transition("pending")
  if helpers.appearanceTrace then
    helpers.appearanceTrace("compare", pending, candidate and candidate.option, nextAction)
  end
  if nextAction == "wait_disappeared" or nextAction == "wait_reached" then
    setStatus("load", disappeared
      and "A linked option changed. Waiting for the editor to finish updating."
      or "The choice changed. Waiting for linked options to update.")
    return "waiting"
  end
  if nextAction == "wait" then return "waiting" end
  local waited = control.waited
  if nextAction == "settled" then
    if pending.kind ~= "apply" and pending.kind ~= "precleanup" then helpers.clearVisibleLoadSatisfaction(scan) end
    log(("SETTLED | %s | %s | target=%s | result=%s | currIndex wait=%.3fs | structureChanged=%s")
      :format(pending.kind, pending.identity, tostring(pending.target),
        disappeared and "dependent option disappeared" or "value confirmed", waited, tostring(structureChanged)), "info")
    return "settled"
  end
  if pending.kind ~= "apply" then
    if pending.kind ~= "precleanup" then helpers.clearVisibleLoadSatisfaction(scan) end
    state.logLoadOnce("cleanup-not-confirmed:" .. pending.trackingKey,
      ("[UNCONFIRMED] The game did not expose whether a remaining option cleared after %.3fs. It was not applied again: %s")
        :format(waited, pending.identity), "warn")
  else
    state.logLoadOnce("apply-not-confirmed:" .. pending.trackingKey,
      ("[UNCONFIRMED] The game did not report the new choice (currIndex) after %.3fs. The choice was applied once and was not repeated: %s targetIndex=%s reportedIndex=%s editorSlot='%s'")
        :format(waited, pending.identity, tostring(pending.target),tostring(current),tostring(pending.slot or "unknown")), "warn")
  end
  return "unconfirmed"
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
      local key = matching.occurrenceKey(label, occurrences[label])
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
        and matching.sameRemapIdentity(remap, candidate.label, candidate.occurrence, candidate.position,
          candidate.slot, candidate.slotOccurrence, activeSlotCounts)
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

helpers.confirmLoadGroup = function(system, scan)
  local group = state.load.batch
  if not group then return end
  eventBuffers.group_begin.structureChanged = scan.structureChanged
  transition("group_begin")
  local waiting,waitSeconds,accountedAt = control.waiting,control.groupWaitSeconds,control.accountedAt
  for _, pending in ipairs(group) do
    eventBuffers.group_member.pending = pending
    transition("group_member")
    local result = helpers.checkPendingChange(system, scan)
    eventBuffers.group_collect.pending,eventBuffers.group_collect.result,eventBuffers.group_collect.waiting = pending,result,waiting
    transition("group_collect")
  end
  local finish = eventBuffers.group_finish
  finish.group,finish.waiting,finish.waitSeconds,finish.accountedAt = group,waiting,waitSeconds,accountedAt
  if transition("group_finish") == "group_wait" then return "waiting" end
end

helpers.isSecondaryLoadOption = function(candidate)
  local text = table.concat({ tostring(candidate.label or ""),
    tostring(candidate.slot or ""),
    helpers.optionDisplayName(candidate.option, candidate.label) }, " ")
  return matching.secondaryText(text)
end

helpers.applyLoadGroup = function(system, options, scan)
  if transition("choice_gate") == "verify" then return false end
  local prepared = {}
  for _, candidate in ipairs(scan.exposed) do
    local key = candidate.key
    local entry = state.load.savedEntryByKey[key]
    if entry and not state.load.satisfied[key] and not state.load.stageApplied[key]
        and helpers.isSecondaryLoadOption(candidate) == (state.load.choiceStage == "secondary")
        and matching.canApplyEntry(entry, candidate.slot,
          scan.activeCounts[candidate.label], state.load.savedCounts[candidate.label]) then
      local target = state.load.values[key]
      if entry.choice then
        target = helpers.resolveLoadChoice(candidate.option, entry.choice,
          state.load.resolvedChoiceIndexes[key])
        state.load.resolvedChoiceIndexes[key] = target
      end
      if target ~= nil and optionIndexIsValid(target)
          and (tonumber(candidate.option.currIndex) or 0) ~= target then
        prepared[#prepared + 1] = { candidate = candidate, target = target,
          kind = "apply", choice = entry.choice }
      end
    end
  end
  if helpers.writeLoadGroup(system, options, prepared) then return true end
  local nextStage = transition("choice_stage")
  if nextStage == "secondary" then
    setStatus("load", "Main choices checked. Applying colors and linked details.")
  else
    setStatus("load", "Colors and linked details checked. Verifying the preset.")
  end
  return true
end

helpers.writeLoadGroup = function(system, options, prepared)
  local group = {}
  local started = helpers.loadClock()
  for _, change in ipairs(prepared) do
    local budget = eventBuffers.group_budget
    budget.count,budget.seconds = #group,nil
    if transition("group_budget") == "group_break" then break end
    budget.seconds = helpers.loadClock() - started
    if transition("group_budget") == "group_break" then break end
    local candidate = change.candidate
    local option = options[candidate.position]
    if #options ~= state.load.lastOptionCount or option ~= candidate.option
        or not option.isEditable or not option.isActive
        or optionKey(option) ~= candidate.label or optionSlot(option) ~= candidate.slot
        or helpers.loadChoiceShape(option) ~= candidate.choiceShape
        or (change.choice and not optionChoiceMatchesIndex(
          option, change.choice, change.target)) then
      transition("group_invalid")
      if #group == 0 then return true end
      break
    end
    local ok, reason = helpers.beginPendingChange(system, candidate, change.target,
      change.kind, candidate.key, tonumber(option.currIndex) or 0)
    if not ok then
      transition("stall")
      log("FAILED | A prepared choice could not be applied: " .. tostring(reason), "error")
      setStatus("load", "Loading stopped because a choice could not be changed safely. Close the editor without confirming, then reopen it and try again.", true)
      return true
    end
    local valuesEvent = eventBuffers.group_values
    valuesEvent.changeKind,valuesEvent.key,valuesEvent.target = change.kind,candidate.key,change.target
    transition("group_values")
    log(("CHANGE | pass=%d | %s | target=%s")
      :format(state.load.pass, state.load.pendingChange.identity, tostring(change.target)), "info")
    group[#group + 1] = state.load.pendingChange
    eventBuffers.group_append.key = candidate.key
    transition("group_append")
  end
  eventBuffers.group_finish_write.group = group
  local nextAction = transition("group_finish_write")
  if nextAction == "group_empty" then return false end
  if nextAction == "group_staged" then
    setStatus("load", "Stage applied. Waiting for the editor to finish updating.")
    return true
  end
  local stage = state.load.phase == "precleanup" and "Clearing old choices"
    or state.load.phase == "cleanup" and "Clearing remaining old choices"
    or state.load.choiceStage == "secondary" and "Applying colors and linked details"
    or "Applying main choices"
  setStatus("load", stage .. ".")
  return true
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
    setStatus("load", "Open the CET menu and review Upgrade to Format 9 before loading this CPM preset.", true)
    return
  end
  if selectedPreset.format~=9 then
    if not state.load.needsContinue or not selectedPreset.runtimeFormat9 then
      selectedPreset.runtimeFormat9=helpers.convertAcuForLoad(selectedPreset,options)
    end
    if not selectedPreset.runtimeFormat9 then
      resetLoadState()
      setStatus("load","This ACU preset could not be converted from the current catalog. Open CET to review its upgrade.",true)
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
      saveAppearanceHistorySnapshot(options, "Before loading " .. tostring(loadName))
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
  state.load.updateStarted = started
  local previousCameraHold = state.app.presetCameraHold
  transition("camera_enter")
  local ok, result = pcall(performPresetLoad)
  eventBuffers.camera_exit.previous = previousCameraHold
  transition("camera_exit")
  state.load.longestUpdate = math.max(state.load.longestUpdate,
    math.max(0, helpers.loadClock() - started))
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
