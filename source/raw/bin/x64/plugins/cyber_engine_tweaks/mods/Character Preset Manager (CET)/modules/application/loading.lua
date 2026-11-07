local stateModel = require("modules/domain/state")
local actions = {}
local function action(name)
  local result = actions[name]
  if not result then result = {name}; actions[name] = result end
  return result
end
for _,name in ipairs({"begin","continue","load","none","release","release_idle","reset","stop_auto","timeout","wait"}) do action(name) end
local fields = {
  ["update"] = {"auto","elapsed","pendingChange","pendingElapsed","needsContinue","autoTimer","nextInterval","autoPasses","valueCount"},
  ["load_request"] = {"presetName","pass"},
  ["release_gate"] = {"presetName","needsContinue","pendingChange"},
  ["force_selection"] = {"forceFull","forceFullPresetName"},
  ["camera_enter"] = {},
  ["camera_exit"] = {},
  ["invocation"] = {},
  ["reset"] = {},
  ["begin"] = {"resetBefore","presetName","pass","previousUnresolvedSignature","unresolvedRepeatCount","satisfied","forcedKeys","resolvedChoiceIndexes","applyAttempts","unconfirmed","cleanupAttempts","cleanupSkipped","phase","choiceStage","stageApplied","stagePending","needsContinue","returnToCleanup","pendingChange","batch"},
  ["entries"] = {"values","savedCounts","orderedEntries","savedEntryByKey","savedSlotCounts","valueCount"},
  ["release"] = {"batch","stageApplied","stagePending","choiceStage","overridePreset","values","savedCounts","orderedEntries","savedEntryByKey","savedSlotCounts","satisfied","forcedKeys","resolvedChoiceIndexes","applyAttempts","unconfirmed","cleanupAttempts","cleanupSkipped","loggedWarnings","optionIdentityCache","pendingChange","lastStructureSignature","lastOptionCount","scanResult","dependencyKeys","dependencyRemaps","auto","autoTimer","autoPasses"},
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
handlers.begin=function(state,event)stateModel.beginLoad(state,event.loadName);return actions.none end
handlers.entries=function(state,event)
  stateModel.setLoadEntries(state,event.values,event.savedCounts,event.orderedEntries,event.savedEntryByKey,event.savedSlotCounts,event.valueCount)
  return actions.none
end
handlers.release=function(state,event)stateModel.releaseLoadWorkingData(state,event.app);return actions.none end
handlers.options_missing=function(state)stateModel.stopForUnavailableOptions(state);return actions.none end
handlers.camera_enter=function(state)state.presetCameraHold=true;return actions.none end
handlers.camera_exit=function(state,event)state.presetCameraHold=event.previous;return actions.none end
handlers.invocation=function(state)state.loadInvocation=state.loadInvocation+1;return actions.none end
handlers.reset=function()return actions.reset end
appFields.update={"loadInvocation"}
fields.finish_update={"needsContinue","auto","autoTimer","autoPasses"}
handlers.finish_update=function(state,event)
  if state.needsContinue then return actions.none end
  stateModel.finishAutomaticPass(state)
  return event.closed and actions.release_idle or actions.none
end
local function transition(state,event)return state,handlers[event.kind](state,event)end
return {transition=transition,fields=fields,appFields=appFields,actions=actions}
