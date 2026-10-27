local moduleRoot = "source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/"
package.path = moduleRoot .. "?.lua;" .. package.path
local originalRuntime = package.loaded["modules/runtime"]
local stateModel = require("modules/domain/state")
local operationResult = require("modules/domain/operation_result")
assert(package.loaded["modules/runtime"] == originalRuntime, "state models loaded runtime")
local runtime = require("modules/runtime")
require("modules/constants")
require("modules/state")
require("modules/filesystem")
require("modules/catalog")
require("modules/options")
require("modules/view_cache")
require("modules/presets")
require("modules/load_engine")
local realEvents = require("modules/events")
local realReset = runtime.resetLoadState
local realRelease = runtime.helpers.releaseFinishedLoadWorkingData
local realBegin = runtime.beginLoadPass
local realLoad = runtime.loadPreset
local realInvalidate = runtime.state.invalidatePreflight
local realClearOptions = runtime.helpers.clearOptionCatalog
local realClearScan = runtime.helpers.clearLoadScanTable
local realReleaseIdle = runtime.helpers.releaseIdleMemory
local function literal(value)
  if type(value) == "string" then
    return '"' .. value:gsub('[%z\1-\31\127-\255\\"]', function(c) return string.format("\\%03d",c:byte()) end) .. '"'
  end
  if type(value) == "table" then
    local entries = {}
    for key,item in pairs(value) do entries[#entries+1] = "["..literal(key).."]="..literal(item) end
    table.sort(entries)
    return "{"..table.concat(entries,",").."}"
  end
  if value == nil then return "nil" end
  return tostring(value)
end
local function inputs()
  return {
    passInterval=runtime.AUTO_LOAD_TIMING.passInterval,readyStatus=runtime.NATIVE_READY_STATUS,
    loadName="Fixture",valueCount=17,preset={entries={{key="key",index=2}}},
    values={key=2},savedCounts={key=1},orderedEntries={{key="key",index=2}},
    savedEntryByKey={key={index=2}},savedSlotCounts={slot=1},
    overrideName="Appearance Before Last Load",selectedName="Fixture",
  }
end
local loadFields = {"applyAttempts","applySeconds","auto","autoPasses","autoTimer","batch","choiceSeconds","choiceStage","cleanupAttempts","cleanupSkipped","comparison","dependencyKeys","dependencyRemaps","elapsed","forceFull","forceFullPresetName","forceStructureScan","forcedKeys","lastOptionCount","lastStructureSignature","loggedWarnings","longestUpdate","needsContinue","nextInterval","optionCalls","optionIdentityCache","optionsSeconds","orderedEntries","overrideName","overridePreset","pass","pendingChange","pendingElapsed","phase","preflight","preflightDirty","preflightPresetName","presetName","previousUnresolvedSignature","recoverySnapshotAvailable","remaining","resetBefore","resolvedChoiceIndexes","returnToCleanup","satisfied","savedCounts","savedEntryByKey","savedSlotCounts","scanCalls","scanResult","scanSeconds","stageApplied","stagePending","stalled","structureChanges","targetFallbacks","targetPollSeconds","targetPollingDisabled","targetPolls","unconfirmed","unresolvedRepeatCount","updateStarted","valueCount","values","waitSeconds"}
local appFields = {"inCustomization","loadInvocation","nativeBridge","nativeBridgeRetryTimer","nativeBridgeSequence","nativeBridgeUnavailableLogged","nativeBusy","nativeListRevision","nativeListSelection","nativeLoadSummary","nativePanelShowDetails","nativePanelStatus","nativePanelStatusError","nativeRequestPollTimer","nativeStatus","nativeStatusError","optionCatalog","optionChoiceBindings","optionsMemo","overlayOpen","presetCameraHold","ready","windowOpen"}

local function seed(dirty,resetBefore,parameters)
  local load=stateModel.newLoad(parameters.passInterval)
  local app=stateModel.newApp(parameters.readyStatus)
  if dirty then
    for _,key in ipairs(loadFields) do load[key]={old=key,nested={value="load"}} end
    for _,key in ipairs(appFields) do app[key]={old=key,nested={value="app"}} end
    load.foreignField={value="retained",nested={flag=true}}
    app.foreignField={value="retained"}
  end
  load.resetBefore=resetBefore
  return load,app
end
local operations={}
operations.newLoad=function(load,app,parameters) load=stateModel.newLoad(parameters.passInterval); return load,app end
operations.newApp=function(load,app,parameters) app=stateModel.newApp(parameters.readyStatus); return load,app end
operations.resetLoad=function(load,app,parameters) stateModel.resetLoad(load,parameters.passInterval); return load,app end
operations.releaseLoadWorkingData=function(load,app,parameters) stateModel.releaseLoadWorkingData(load,app); return load,app end
operations.beginLoad=function(load,app,parameters) stateModel.beginLoad(load,parameters.loadName); return load,app end
operations.setLoadEntries=function(load,app,parameters) stateModel.setLoadEntries(load,parameters.values,parameters.savedCounts,parameters.orderedEntries,parameters.savedEntryByKey,parameters.savedSlotCounts,parameters.valueCount); return load,app end
operations.completeLoad=function(load,app,parameters) stateModel.completeLoad(load); return load,app end
operations.stopForUnavailableOptions=function(load,app,parameters) stateModel.stopForUnavailableOptions(load); return load,app end
operations.markStalled=function(load,app,parameters) stateModel.markStalled(load); return load,app end
operations.resetChoiceCaches=function(load,app,parameters) stateModel.resetChoiceCaches(load); return load,app end
operations.clearVisibleTracking=function(load,app,parameters) stateModel.clearVisibleTracking(load); return load,app end
operations.beginApplyAfterCleanup=function(load,app,parameters) stateModel.beginApplyAfterCleanup(load,parameters.valueCount); return load,app end
operations.beginVerification=function(load,app,parameters) stateModel.beginVerification(load,parameters.valueCount); return load,app end
operations.beginCleanup=function(load,app,parameters) stateModel.beginCleanup(load,parameters.valueCount); return load,app end
operations.returnToCleanup=function(load,app,parameters) stateModel.returnToCleanup(load,parameters.valueCount); return load,app end
operations.prepareAutomaticLoad=function(load,app,parameters) stateModel.prepareAutomaticLoad(load); return load,app end
operations.prepareRecoveryLoad=function(load,app,parameters) stateModel.prepareRecoveryLoad(load,parameters.preset,parameters.overrideName); return load,app end
operations.invalidatePreflight=function(load,app,parameters) stateModel.invalidatePreflight(load); return load,app end
operations.clearPreflightForSelection=function(load,app,parameters) stateModel.clearPreflightForSelection(load,parameters.selectedName); return load,app end
operations.stopAutomatic=function(load,app,parameters) stateModel.stopAutomatic(load); return load,app end
operations.finishAutomaticPass=function(load,app,parameters) stateModel.finishAutomaticPass(load); return load,app end
operations.stopAutomaticAtTimeout=function(load,app,parameters) stateModel.stopAutomaticAtTimeout(load); return load,app end
operations.clearOptionCatalog=function(load,app,parameters) stateModel.clearOptionCatalog(app); return load,app end

local cases={}
for _,name in ipairs({
"newLoad","newApp","resetLoad","releaseLoadWorkingData","beginLoad","setLoadEntries","completeLoad","stopForUnavailableOptions","markStalled","resetChoiceCaches","clearVisibleTracking","beginApplyAfterCleanup","beginVerification","beginCleanup","returnToCleanup","prepareAutomaticLoad","prepareRecoveryLoad","invalidatePreflight","clearPreflightForSelection","stopAutomatic","finishAutomaticPass","stopAutomaticAtTimeout","clearOptionCatalog"
}) do
  cases[#cases+1]={name=name,dirty=false,resetBefore=false}
  cases[#cases+1]={name=name,dirty=true,resetBefore=true}
end
local function context(load,app,parameters)
  local log={}
  runtime.state={load=load,app=app,library={selected="Fixture",presets={Fixture=parameters.preset}},
    editor={openPending=false},ui={bindingCache={},fallbackNoticeAcknowledged=false},
    nativeCatalog={available=false},invalidatePreflight=realInvalidate}
  runtime.log=function(message,level) log[#log+1]={message=message,level=level} end
  runtime.setStatus=function(section,message,isError,kind)
    log[#log+1]={section=section,message=message,error=isError,kind=kind}
  end
  runtime.helpers.logLoadMeasurements=function(result) log[#log+1]={measurement=result} end
  runtime.helpers.auditSection=function(section) log[#log+1]={audit=section} end
  runtime.helpers.preparePresetEntries=function()
    return parameters.values,parameters.savedCounts,parameters.orderedEntries,
      parameters.savedSlotCounts,parameters.valueCount,parameters.savedEntryByKey
  end
  runtime.helpers.loadClock=function() return 0 end
  runtime.helpers.syncForceFullLoadSelection=function() end
  runtime.hydrateNamedPreset=function() return parameters.preset end
  runtime.loadPreset=realLoad
  runtime.helpers.releaseFinishedLoadWorkingData=realRelease
  runtime.helpers.updateOverlayRequest=function() end
  runtime.updateAcuImport=function() end
  runtime.updateNativeBridge=function() end
  runtime.helpers.releaseViewCaches=function() end
  runtime.ui={closeDebugPanel=function() end}
  return log
end
local integration={}
integration.resetForward=function(load,app,parameters) return context(load,app,parameters),realReset() end
integration.releaseForward=function(load,app,parameters) return context(load,app,parameters),realRelease() end
integration.invalidateForward=function(load,app,parameters) return context(load,app,parameters),realInvalidate() end
integration.clearOptionsForward=function(load,app,parameters) return context(load,app,parameters),realClearOptions() end
integration.beginForward=function(load,app,parameters)
  local log=context(load,app,parameters)
  realBegin(parameters.preset,parameters.loadName)
  return log
end
integration.noSelection=function(load,app,parameters)
  local log=context(load,app,parameters)
  runtime.state.library.selected=nil;load.overridePreset=nil;load.overrideName=nil
  app.loadInvocation=0;load.optionsSeconds=0;load.longestUpdate=0
  realLoad();return log
end
integration.unreadable=function(load,app,parameters)
  local log=context(load,app,parameters)
  runtime.hydrateNamedPreset=function() return nil end
  load.overridePreset=nil;load.overrideName=nil
  app.loadInvocation=0;load.optionsSeconds=0;load.longestUpdate=0
  realLoad();return log
end
integration.unavailableOptions=function(load,app,parameters)
  local log=context(load,app,parameters)
  runtime.getOptions=function() return nil,nil,"options unavailable" end
  load.overridePreset=nil;load.overrideName=nil;load.needsContinue=true
  app.loadInvocation=0;load.optionsSeconds=0;load.optionCalls=0;load.longestUpdate=0
  realLoad();return log
end
integration.completedBoundary=function(load,app,parameters)
  local log=context(load,app,parameters)
  runtime.getOptions=function() return {},{},nil end
  runtime.continueLoadPass=function()
    stateModel.completeLoad(load);load.pendingChange=nil;return "terminal"
  end
  load.overridePreset=nil;load.overrideName=nil;load.presetName="Fixture"
  load.pass=1;load.valueCount=17;load.needsContinue=true
  app.loadInvocation=0;load.optionsSeconds=0;load.optionCalls=0;load.longestUpdate=0
  realLoad();return log
end
local function updateCase(load,app,parameters,kind)
  local log=context(load,app,parameters)
  app.inCustomization=false;app.overlayOpen=true;app.windowOpen=true;app.loadInvocation=0
  load.auto=true;load.needsContinue=true;load.elapsed=0;load.autoTimer=1
  load.autoPasses=4;load.nextInterval=parameters.passInterval;load.valueCount=10
  load.pendingChange=nil;load.overridePreset=nil
  if kind=="idle" then load.auto=false
  elseif kind=="noContinue" then load.needsContinue=false
  elseif kind=="noSelection" then runtime.state.library.selected=nil
  elseif kind=="timeout" then
    load.elapsed=1000;load.pendingChange={startedAt=0};load.batch={retained=true}
  elseif kind=="finished" then runtime.loadPreset=function() load.needsContinue=false end
  end
  realEvents.onUpdate(0.5)
  return log
end
for _,kind in ipairs({"idle","noContinue","noSelection","timeout","finished"}) do
  integration["update_"..kind]=function(load,app,parameters) return updateCase(load,app,parameters,kind) end
end
integration.idleRelease=function(load,app,parameters)
  local log=context(load,app,parameters)
  load.auto=false;load.needsContinue=false;load.pendingChange=nil
  runtime.state.library.presets={}
  assert(realReleaseIdle()==true)
  return log
end
for _,name in ipairs({"resetForward","releaseForward","invalidateForward","clearOptionsForward",
  "beginForward","noSelection","unreadable","unavailableOptions","completedBoundary",
  "update_idle","update_noContinue","update_noSelection","update_timeout","update_finished","idleRelease"}) do
  cases[#cases+1]={name=name,dirty=true,resetBefore=true,integration=true}
end
integration.clearScanForward=function(load,app,parameters)
  local log=context(load,app,parameters)
  load.scanResult={first=1,[2]={sentinel=true},foreign={nested=true}}
  assert(select("#",realClearScan(load.scanResult))==0)
  return log
end
cases[#cases+1]={name="clearScanForward",dirty=false,resetBefore=false,integration=true}
cases[#cases+1]={name="clearScanForward",dirty=true,resetBefore=true,integration=true}
local function run(case)
  local parameters=inputs()
  local load,app=seed(case.dirty,case.resetBefore,parameters)
  local log
  if case.integration then log=integration[case.name](load,app,parameters)
  else load,app=operations[case.name](load,app,parameters) end
  return {load=load,app=app,log=log}
end
local expected=require("modules/domain/stage3_fixtures")
for index,case in ipairs(cases) do
  assert(literal(run(case))==expected[index],case.name.." fixture "..index.." changed")
end
local function tableSet(value, found)
  if type(value) ~= "table" or found[value] then return found end
  found[value] = true
  for key,item in pairs(value) do tableSet(key,found);tableSet(item,found) end
  return found
end
local function assertIndependent(first,second)
  local firstTables=tableSet(first,{})
  for value in pairs(tableSet(second,{})) do assert(not firstTables[value],"constructor instances share a table") end
end
local firstLoad=stateModel.newLoad(0.225)
local secondLoad=stateModel.newLoad(0.5)
assertIndependent(firstLoad,secondLoad)
assert(firstLoad.nextInterval==0.225 and secondLoad.nextInterval==0.5)
firstLoad.satisfied.changed=true
assert(secondLoad.satisfied.changed==nil)
local firstApp=stateModel.newApp("First")
local secondApp=stateModel.newApp("Second")
assertIndependent(firstApp,secondApp)
assert(firstApp.nativePanelStatus=="First" and secondApp.nativePanelStatus=="Second")
local preserved={sentinel=true}
firstLoad.scanResult=preserved;firstLoad.forceFull=true;firstLoad.preflight=preserved
local originalLoad=firstLoad
stateModel.resetLoad(firstLoad,0.225)
assert(firstLoad==originalLoad and firstLoad.scanResult==preserved and firstLoad.preflight==preserved and firstLoad.forceFull)
assertIndependent(firstLoad,secondLoad)
local parameters=inputs()
local load,app=seed(true,true,parameters)
local originalApp=app
stateModel.releaseLoadWorkingData(load,app)
assert(app==originalApp and load.auto==false and load.scanResult==nil)
stateModel.setLoadEntries(load,parameters.values,parameters.savedCounts,parameters.orderedEntries,
  parameters.savedEntryByKey,parameters.savedSlotCounts,parameters.valueCount)
assert(load.values==parameters.values and load.orderedEntries==parameters.orderedEntries)
stateModel.prepareRecoveryLoad(load,parameters.preset,"Recovery")
assert(load.overridePreset==parameters.preset)
local timeout=run({name="update_timeout",dirty=true,resetBefore=true,integration=true})
assert(timeout.load.auto==false and timeout.load.needsContinue==true)
assert(timeout.load.pendingChange and timeout.load.batch, "timeout behavior was changed")
local warnings={{message="Check the appearance.",details={slot="hair"}}}
local success=operationResult.success("Saved.",warnings)
local secondSuccess=operationResult.success("Saved.",warnings)
assertIndependent(success,secondSuccess)
assertIndependent(success.warnings,warnings)
success.warnings[1].details.slot="eyes"
assert(warnings[1].details.slot=="hair" and secondSuccess.warnings[1].details.slot=="hair")
assert(success.success==true and success.failure==false and success.statusMessage=="Saved.")
local failure=operationResult.failure("Could not save.",{"Try again."})
assert(failure.success==false and failure.failure==true and #failure.warnings==1)
local defaultResult=operationResult.new(false)
assert(defaultResult.statusMessage=="" and #defaultResult.warnings==0)
assertIndependent(defaultResult,operationResult.new(false))
context(stateModel.newLoad(parameters.passInterval),stateModel.newApp(parameters.readyStatus),parameters)
assert(select("#",realReset())==0)
assert(select("#",realRelease())==0)
assert(select("#",realInvalidate())==0)
assert(select("#",realClearOptions())==0)
assert(runtime.cancelLoading == nil, "removed load-cancel entry point is still exported")
print("Stage 3 state fixtures passed: "..#cases)
print("Independent constructors, retained references, legacy return values, and operation results passed.")
print("Timeout fixture preserves auto=false with active continuation, pending choice, and batch.")
return {cases=cases,run=run,literal=literal}
