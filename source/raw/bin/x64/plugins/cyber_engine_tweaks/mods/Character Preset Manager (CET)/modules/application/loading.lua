local stateModel = require("modules/domain/state")
local PHASE_APPLY = "apply"
local PHASE_PRECLEANUP = "precleanup"
local PHASE_CLEANUP = "cleanup"
local PHASE_VERIFY = "verify"
local CHOICE_STAGE_MAIN = "main"
local CHOICE_STAGE_SECONDARY = "secondary"
local CHOICE_STAGE_VERIFY = "verify"
local CHANGE_APPLY = "apply"
local CHANGE_PRECLEANUP = "precleanup"
local actions = {}
local function action(name)
  local result = actions[name]
  if not result then result = {name}; actions[name] = result end
  return result
end
for _,name in ipairs({"none","load","timeout","stop_auto","wait","read","identity_fallback","shape_fallback","wait_disappeared","wait_reached","settled","unconfirmed","group_wait","group_ready","group_break","group_empty","group_staged","group_written","secondary","verify","verify_remaining","precleanup_changed","cleanup_changed","cleanup","apply","continue","begin","release","stopped","begin_cleanup","return_cleanup","final_verify","reset","dependency_pending","dependency_between","release_idle","empty"}) do action(name) end
local fields = {
  ["update"] = {"auto","elapsed","pendingChange","pendingElapsed","needsContinue","autoTimer","nextInterval","autoPasses","valueCount"},
  ["pending_identity"] = {"pendingChange","targetPollingDisabled","resolvedChoiceIndexes","optionIdentityCache","dependencyRemaps"},
  ["pending"] = {"pendingChange","elapsed","nextInterval","pendingElapsed","waitSeconds","forceStructureScan","satisfied","unconfirmed","forcedKeys","phase","returnToCleanup","cleanupSkipped"},
  ["poll_gate"] = {"pendingChange","forceFull","targetPollingDisabled"},
  ["poll_begin"] = {"targetPolls"},
  ["poll_fallback"] = {"targetFallbacks","targetPollingDisabled","resolvedChoiceIndexes","optionIdentityCache","dependencyRemaps"},
  ["poll_result"] = {"pendingChange","elapsed","nextInterval","pendingElapsed"},
  ["attempt"] = {},
  ["begin_pending"] = {"pendingChange","elapsed","pendingElapsed","nextInterval","forceStructureScan","needsContinue","previousUnresolvedSignature","unresolvedRepeatCount","lastStructureSignature"},
  ["group_begin"] = {"batch","pendingChange","elapsed","waitSeconds"},
  ["group_finish"] = {"batch","pendingChange","elapsed","waitSeconds","nextInterval"},
  ["group_budget"] = {},
  ["group_invalid"] = {"forceStructureScan","needsContinue","nextInterval"},
  ["group_values"] = {"values"},
  ["group_append"] = {"pendingChange","stageApplied"},
  ["group_finish_write"] = {"stagePending","batch","elapsed","nextInterval","needsContinue"},
  ["choice_stage"] = {"choiceStage","stageApplied","needsContinue"},
  ["pass_gate"] = {"nextInterval","phase","remaining","needsContinue","returnToCleanup"},
  ["load_request"] = {"presetName","pass"},
  ["release_gate"] = {"presetName","needsContinue","pendingChange"},
  ["force_selection"] = {"forceFull","forceFullPresetName"},
  ["count_remaining"] = {"remaining"},
  ["unresolved"] = {"previousUnresolvedSignature","unresolvedRepeatCount","needsContinue","stalled","auto"},
  ["finish_pass"] = {"phase","resetBefore","returnToCleanup","stageApplied","remaining","needsContinue","previousUnresolvedSignature","unresolvedRepeatCount"},
  ["complete"] = {"cleanupSkipped","unconfirmed","values","needsContinue","stalled","previousUnresolvedSignature","unresolvedRepeatCount"},
  ["visible"] = {"satisfied","unconfirmed","applyAttempts","previousUnresolvedSignature","unresolvedRepeatCount"},
  ["camera_enter"] = {},
  ["camera_exit"] = {},
  ["invocation"] = {},
  ["reset"] = {},
  ["begin"] = {"resetBefore","presetName","pass","previousUnresolvedSignature","unresolvedRepeatCount","satisfied","forcedKeys","resolvedChoiceIndexes","applyAttempts","unconfirmed","cleanupAttempts","cleanupSkipped","phase","choiceStage","stageApplied","stagePending","needsContinue","returnToCleanup","pendingChange","batch"},
  ["entries"] = {"values","savedCounts","orderedEntries","savedEntryByKey","savedSlotCounts","valueCount"},
  ["release"] = {"batch","stageApplied","stagePending","choiceStage","overridePreset","values","savedCounts","orderedEntries","savedEntryByKey","savedSlotCounts","satisfied","forcedKeys","resolvedChoiceIndexes","applyAttempts","unconfirmed","cleanupAttempts","cleanupSkipped","loggedWarnings","optionIdentityCache","pendingChange","lastStructureSignature","lastOptionCount","scanResult","dependencyKeys","dependencyRemaps","auto","autoTimer","autoPasses"},
  ["stall"] = {"needsContinue","stalled"},
  ["apply_after_cleanup"] = {"phase","stageApplied","remaining","needsContinue","previousUnresolvedSignature","unresolvedRepeatCount"},
  ["verify_after_cleanup"] = {"phase","returnToCleanup","resetBefore","remaining","needsContinue"},
  ["options_missing"] = {"batch","pendingChange","needsContinue","auto","stalled"},
}
local appFields = {
  ["release"] = {"optionsMemo"},
  ["camera_enter"] = {"presetCameraHold"},
  ["camera_exit"] = {"presetCameraHold"},
  ["invocation"] = {"loadInvocation"},
}
local handlers = {}
handlers.update = function(state,event)
  if not state.auto or state.loadInvocation ~= event.invocationBefore then return actions.none end
  state.elapsed = state.elapsed + event.elapsed
  if state.pendingChange then state.pendingElapsed = math.max(0,state.elapsed-state.pendingChange.startedAt) end
  if not state.needsContinue then stateModel.stopAutomatic(state);return actions.stop_auto end
  state.autoTimer = state.autoTimer + event.elapsed
  if state.autoTimer < state.nextInterval then return actions.wait end
  state.autoTimer = 0
  if not event.hasSelection then stateModel.stopAutomatic(state);return actions.stop_auto end
  state.autoPasses = state.autoPasses + 1
  local maximumSeconds = math.max(event.limits.minimumSeconds,
    (tonumber(state.valueCount) or 0)*event.limits.secondsPerOption+event.safetyMargin)
  if state.elapsed > maximumSeconds then return actions.timeout end
  return actions.load
end
handlers.pending_identity = function(state,event)
  local pending = state.pendingChange
  if event.present and (event.label ~= pending.label or event.occurrence ~= pending.occurrence or event.slot ~= pending.slot) then
    state.targetPollingDisabled = true;stateModel.resetChoiceCaches(state);return actions.identity_fallback
  elseif event.present and event.shape ~= pending.choiceShape and not pending.choiceStructureChanged then
    state.targetPollingDisabled = true;stateModel.resetChoiceCaches(state)
    pending.longSettle = true;pending.choiceStructureChanged = true;return actions.shape_fallback
  end
  return actions.none
end
handlers.pending = function(state,event)
  local pending = event.pending or state.pendingChange
  local disappeared = not event.present
  local reached = not pending.choiceStructureChanged and event.current == pending.target
  if event.signature ~= pending.structureSignature then pending.longSettle = true end
  if disappeared then pending.longSettle = true end
  if reached or disappeared then
    if pending.longSettle then
      if pending.confirmedAt == nil or pending.confirmedSignature ~= event.signature then
        pending.confirmedAt = state.elapsed;pending.confirmedSignature = event.signature
        pending.confirmedDisappeared = disappeared;state.nextInterval = event.timing.pollInterval
        return disappeared and actions.wait_disappeared or actions.wait_reached
      end
      if state.elapsed-pending.confirmedAt < event.timing.dependencyStableTime then
        state.nextInterval = event.timing.pollInterval;return actions.wait
      end
    end
    state.waited = math.max(0,state.elapsed-pending.startedAt)
    state.waitSeconds = state.waitSeconds+state.waited
    state.pendingElapsed = state.waited;state.pendingChange = nil
    state.nextInterval = event.timing.passInterval;state.forceStructureScan = true
    if pending.kind == CHANGE_APPLY then
      state.satisfied[pending.trackingKey] = true;state.unconfirmed[pending.trackingKey] = nil
      if pending.forced then state.forcedKeys[pending.trackingKey] = true end
    elseif pending.kind == CHANGE_PRECLEANUP then state.phase = PHASE_PRECLEANUP
    else state.phase = PHASE_VERIFY;state.returnToCleanup = true end
    return actions.settled
  end
  if state.elapsed-pending.attemptStartedAt < event.timing.dependencyTimeout then
    state.nextInterval = event.timing.pollInterval
    state.pendingElapsed = math.max(0,state.elapsed-pending.startedAt);return actions.wait
  end
  state.waited = math.max(0,state.elapsed-pending.startedAt)
  state.waitSeconds = state.waitSeconds+state.waited
  state.pendingChange = nil;state.nextInterval = event.timing.passInterval;state.forceStructureScan = true
  if pending.kind ~= CHANGE_APPLY then
    state.cleanupSkipped[pending.trackingKey] = true
    if pending.kind == CHANGE_PRECLEANUP then state.phase = PHASE_PRECLEANUP
    else state.phase = PHASE_VERIFY;state.returnToCleanup = true end
  else
    state.satisfied[pending.trackingKey] = true;state.unconfirmed[pending.trackingKey] = true
    if pending.forced then state.forcedKeys[pending.trackingKey] = true end
  end
  return actions.unconfirmed
end
handlers.poll_gate = function(state,event)
  local pending = state.pendingChange
  if not pending or not pending.longSettle or state.forceFull or state.targetPollingDisabled
      or not pending.position or pending.confirmedDisappeared or not pending.confirmedAt then return actions.none end
  return actions.read
end
handlers.poll_begin = function(state)state.targetPolls=state.targetPolls+1;return actions.none end
handlers.poll_fallback = function(state)
  state.targetFallbacks=state.targetFallbacks+1;state.targetPollingDisabled=true
  stateModel.resetChoiceCaches(state);return actions.none
end
handlers.poll_result = function(state,event)
  local pending=event.pending or state.pendingChange
  if event.current~=pending.target or state.elapsed-pending.confirmedAt>=event.timing.dependencyStableTime then return actions.none end
  state.nextInterval=event.timing.pollInterval;state.pendingElapsed=math.max(0,state.elapsed-pending.startedAt)
  return actions.wait
end
handlers.attempt = function(state,event)
  local attempts=event.attempts
  attempts[event.key]=(attempts[event.key]or 0)+1;return actions.none
end
handlers.begin_pending = function(state,event)
  state.pendingChange={kind=event.changeKind,trackingKey=event.key,optionKey=event.optionKey,
    position=event.position,label=event.label,occurrence=event.occurrence,slot=event.slot,choiceShape=event.shape,
    target=event.target,previous=event.current,identity=event.identity,startedAt=state.elapsed,
    attemptStartedAt=state.elapsed,structureSignature=state.lastStructureSignature,confirmedAt=nil,
    confirmedSignature=nil,confirmedDisappeared=false,longSettle=event.longSettle}
  state.pendingElapsed=0;state.nextInterval=event.timing.pollInterval;state.forceStructureScan=true
  state.needsContinue=true;state.previousUnresolvedSignature=nil;state.unresolvedRepeatCount=0
  return actions.none
end
handlers.group_begin = function(state,event)
  local group=state.batch
  state.waiting={};state.groupWaitSeconds=state.waitSeconds
  state.accountedAt=group.accountedAt or(group[1]and group[1].startedAt)or state.elapsed
  if group.stage and event.structureChanged then group.settleUntil=math.min(group.deadline,state.elapsed+event.timing.dependencyStableTime)end
  state.batch=nil;return actions.none
end
handlers.group_finish = function(state,event)
  local group,waiting=event.group,event.waiting
  state.pendingChange=nil
  state.waitSeconds=event.waitSeconds+math.max(0,state.elapsed-event.accountedAt)
  local settling=group.stage and state.elapsed<group.settleUntil
  if #waiting>0 or settling then
    waiting.stage=group.stage;waiting.settleUntil=group.settleUntil;waiting.deadline=group.deadline
    waiting.accountedAt=state.elapsed;state.batch=waiting;state.nextInterval=event.timing.pollInterval
    return actions.group_wait
  end
  state.nextInterval=0;return actions.group_ready
end
handlers.group_budget = function(state,event)
  if event.count>=event.timing.maximumGroupChanges or(event.seconds and event.seconds>=event.timing.groupBudgetSeconds)then return actions.group_break end
  return actions.none
end
handlers.group_invalid = function(state)
  state.forceStructureScan=true;state.needsContinue=true;state.nextInterval=0;return actions.none
end
handlers.group_values = function(state,event)
  if event.changeKind==CHANGE_APPLY then state.values[event.key]=event.target end;return actions.none
end
handlers.group_append = function(state,event)
  state.stageApplied[event.key]=true;state.pendingChange=nil;return actions.none
end
handlers.group_finish_write = function(state,event)
  if #event.group==0 then
    if #state.stagePending==0 then return actions.group_empty end
    local pending=state.stagePending;state.stagePending={};pending.stage=true
    pending.accountedAt=state.elapsed;pending.settleUntil=state.elapsed+event.timing.dependencyStableTime
    pending.deadline=state.elapsed+event.timing.dependencyTimeout;state.batch=pending
    state.nextInterval=event.timing.pollInterval;state.needsContinue=true;return actions.group_staged
  end
  for _,pending in ipairs(event.group)do state.stagePending[#state.stagePending+1]=pending end
  state.nextInterval=0;state.needsContinue=true;return actions.group_written
end
handlers.choice_stage = function(state)
  state.stageApplied={}
  if state.choiceStage==CHOICE_STAGE_MAIN then state.choiceStage=CHOICE_STAGE_SECONDARY;state.needsContinue=true;return actions.secondary end
  state.choiceStage=CHOICE_STAGE_VERIFY;state.needsContinue=true;return actions.verify
end
handlers.pass_gate = function(state,event)
  state.nextInterval=0
  if(event.pendingResult=="settled"or event.pendingResult=="unconfirmed")and state.phase==PHASE_VERIFY then
    state.remaining=event.valueCount;state.needsContinue=true;return actions.verify_remaining
  end
  if state.phase==PHASE_PRECLEANUP and event.structureChanged then
    state.remaining=event.valueCount;state.needsContinue=true;return actions.precleanup_changed
  end
  if state.phase==PHASE_CLEANUP and event.structureChanged then
    state.phase=PHASE_VERIFY;state.returnToCleanup=true;state.remaining=event.valueCount;state.needsContinue=true
    return actions.cleanup_changed
  end
  if state.phase==PHASE_PRECLEANUP or state.phase==PHASE_CLEANUP then return actions.cleanup end
  return actions.apply
end
handlers.load_request=function(state,event)
  if state.presetName==event.loadName then state.pass=state.pass+1;return actions.continue end
  return actions.begin
end
handlers.release_gate=function(state)
  if state.presetName and not state.needsContinue and not state.pendingChange then return actions.release end
  return actions.none
end
handlers.force_selection=function(state,event)
  state.forceFull=event.hasPreset and event.format<event.threshold;state.forceFullPresetName=event.selected
  return actions.none
end
handlers.count_remaining=function(state,event)state.remaining=event.remaining;return actions.none end
handlers.unresolved=function(state,event)
  if state.previousUnresolvedSignature==event.signature then state.unresolvedRepeatCount=state.unresolvedRepeatCount+1
  else state.previousUnresolvedSignature=event.signature;state.unresolvedRepeatCount=1 end
  if state.unresolvedRepeatCount>=event.stallPasses then stateModel.markStalled(state);return actions.stopped end
  state.needsContinue=true;return actions.continue
end
handlers.finish_pass=function(state,event)
  if state.phase==PHASE_APPLY and state.resetBefore then stateModel.beginCleanup(state,event.valueCount);return actions.begin_cleanup end
  if state.phase==PHASE_VERIFY and state.returnToCleanup then stateModel.returnToCleanup(state,event.valueCount);return actions.return_cleanup end
  return actions.final_verify
end
handlers.complete=function(state)
  local skipped,unconfirmed=0,0
  for _ in pairs(state.cleanupSkipped)do skipped=skipped+1 end
  for key in pairs(state.unconfirmed)do if state.values[key]~=nil then unconfirmed=unconfirmed+1 end end
  state.cleanupCount=skipped;state.unconfirmedCount=unconfirmed;stateModel.completeLoad(state);return actions.none
end
handlers.visible=function(state,event)
  for key in pairs(event.activeKeySet)do if not state.unconfirmed[key]then state.satisfied[key]=nil end end
  stateModel.clearVisibleTracking(state);return actions.none
end
handlers.begin=function(state,event)stateModel.beginLoad(state,event.loadName);return actions.none end
handlers.entries=function(state,event)
  stateModel.setLoadEntries(state,event.values,event.savedCounts,event.orderedEntries,event.savedEntryByKey,event.savedSlotCounts,event.valueCount)
  return actions.none
end
handlers.release=function(state,event)stateModel.releaseLoadWorkingData(state,event.app);return actions.none end
handlers.stall=function(state)stateModel.markStalled(state);return actions.none end
handlers.apply_after_cleanup=function(state,event)stateModel.beginApplyAfterCleanup(state,event.valueCount);return actions.none end
handlers.verify_after_cleanup=function(state,event)stateModel.beginVerification(state,event.valueCount);return actions.none end
handlers.options_missing=function(state)stateModel.stopForUnavailableOptions(state);return actions.none end
handlers.camera_enter=function(state)state.presetCameraHold=true;return actions.none end
handlers.camera_exit=function(state,event)state.presetCameraHold=event.previous;return actions.none end
handlers.invocation=function(state)state.loadInvocation=state.loadInvocation+1;return actions.none end
handlers.reset=function()return actions.reset end
fields.choice_gate={"choiceStage"}
fields.group_member={"pendingChange"}
fields.group_collect={}
fields.scan_begin={"lastOptionCount","forceStructureScan","batch","pendingChange","forceFull","phase"}
fields.scan_dependency={"lastStructureSignature","structureChanges","resolvedChoiceIndexes","optionIdentityCache","dependencyRemaps","pendingChange","dependencyKeys"}
fields.scan_finish={"lastStructureSignature","lastOptionCount"}
handlers.choice_gate=function(state)
  return state.choiceStage==CHOICE_STAGE_VERIFY and actions.verify or actions.apply
end
handlers.group_member=function(state,event)state.pendingChange=event.pending;return actions.none end
handlers.group_collect=function(state,event)
  if event.result=="waiting"then event.waiting[#event.waiting+1]=event.pending end
  return actions.none
end
handlers.scan_begin=function(state,event)
  state.rebuildSignature=state.lastOptionCount==nil or state.lastOptionCount~=event.optionCount
    or state.forceStructureScan or state.batch~=nil or(state.pendingChange and state.pendingChange.longSettle)
  state.forceStructureScan=false
  state.fullExposure=state.forceFull or state.batch~=nil or state.phase==PHASE_PRECLEANUP or state.phase==PHASE_CLEANUP
  return actions.none
end
handlers.scan_dependency=function(state,event)
  if event.rebuild and state.lastStructureSignature and state.lastStructureSignature~=event.signature then
    state.structureChanges=state.structureChanges+1;stateModel.resetChoiceCaches(state)
    local pending=state.pendingChange
    if pending then
      pending.longSettle=true;state.dependencyKeys[pending.trackingKey]=true;return actions.dependency_pending
    end
    return actions.dependency_between
  end
  return actions.none
end
handlers.scan_finish=function(state,event)
  if event.rebuild then state.lastStructureSignature=event.signature end
  state.lastOptionCount=event.optionCount;return actions.none
end
appFields.update={"loadInvocation"}
fields.finish_update={"needsContinue","auto","autoTimer","autoPasses"}
handlers.finish_update=function(state,event)
  if state.needsContinue then return actions.none end
  stateModel.finishAutomaticPass(state)
  return event.closed and actions.release_idle or actions.none
end
fields.pass_start={"stalled","needsContinue"}
handlers.pass_start=function(state,event)
  state.stalled=false
  if event.valueCount==0 then state.needsContinue=false;return actions.empty end
  return actions.none
end
local function transition(state,event)return state,handlers[event.kind](state,event)end
return {transition=transition,fields=fields,appFields=appFields,actions=actions}
