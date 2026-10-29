local root="source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/"
package.path=root.."?.lua;"..package.path
local gate=CPM_STAGE8_GATE or "modules/domain/stage8_sandbox"
require(gate).install(root)
local file=assert(io.open(root.."modules/domain/stage7_tests.lua","rb"));local source=file:read("*a");file:close()
local prefix=source:sub(1,assert(source:find("local cases={}",1,true))-1)
local kit=assert(loadstring(prefix..[[
return {pack=pack,reset=reset,option=option,entry=entry,literal=literal,clone=clone,
 observe=function()return trace,reads,readOrder,calls,options,system,preset end}
]]))()
local machineCalls,machineTrace=0,{}
if CPM_VALIDATE_MACHINE then
 local machine=require("modules/application/loading")
 local original=machine.transition
 local function plain(value,seen)
  local kind=type(value)
  assert(kind=="nil"or kind=="boolean"or kind=="string"or kind=="number"or kind=="table","non-data machine value")
  if kind~="table"then return end
  assert(getmetatable(value)==nil,"game/proxy object entered the machine")
  if seen[value]then return end;seen[value]=true
  for key,item in pairs(value)do plain(key,seen);plain(item,seen)end
 end
 machine.transition=function(state,event)
  plain(state,{});plain(event,{})
  local nextState,actions=original(state,event)
  plain(nextState,{});plain(actions,{})
  assert(nextState==state,"transition replaced its caller-owned state")
  assert(#actions==1 and type(actions[1])=="string","invalid machine action list")
  machineCalls=machineCalls+1
  machineTrace[#machineTrace+1]={event.kind,actions[1]}
  return nextState,actions
 end
end
local runtime=require("modules/runtime")
local stateModel=require("modules/domain/state")
require("modules/native_bridge")
local events=require("modules/events")
local realUpdate=runtime.updateNativeBridge
local realStatus=runtime.setStatus
local realReset=runtime.resetLoadState
local initialStatus=kit.clone(runtime.state.status)
local function find(fn,key,visited)
 visited=visited or{};if visited[fn]then return end;visited[fn]=true
 for i=1,100 do local name,value=debug.getupvalue(fn,i);if not name then break end
  if name==key then return value end
  if type(value)=="function"then local found=find(value,key,visited);if found then return found end end
 end
end
local nativeStart=assert(find(realUpdate,"startSelectedLoad"))
local frameAllocations={}
local cases={}
local function add(name,extra)local case=extra or{};case.name=name;cases[#cases+1]=case end
add("normal full load")
add("counter map replaced inside write",{mapReplacement=true})
add("editor closes inside option observation",{observationClose=true})
add("choice shape changes during settle",{timedShape=true})
add("option label changes during settle",{timedLabel=true})
add("option slot changes during settle",{timedSlot=true})
add("option disappears during settle",{timedInactive=true})
add("single remap and fast polling",{directRemap=true})
add("target poll identity fallback",{directRemap=true,pollFallback=true})
add("unset camera guard",{cameraNil=true})
add("ten-option grouped load",{many=true})
add("ten-option delayed groups",{many=true,delay=0.30})
add("exhausted group time budget",{cpuStep=0.005})
add("choice structure changed",{mode="shape"})
add("dependent option disappears",{mode="disappear"})
add("choices reordered after write",{mode="reorder"})
add("timeout immediately below threshold",{boundaryElapsed=59.94})
add("timeout exactly at threshold",{boundaryElapsed=59.95})
add("timeout above threshold",{boundaryElapsed=59.96})
add("delayed several passes",{delay=0.30})
add("unavailable and repeated unresolved",{missing=true})
add("failed write",{mode="fail"})
add("failure after earlier accepted write",{failWriteAt=3})
add("write never confirmed",{mode="ignore"})
add("automatic timeout",{mode="ignore",timeout=true})
add("editor closed mid-load",{exit="editor",delay=0.3})
add("shutdown mid-load",{exit="shutdown",delay=0.3})
add("CET reload mid-load",{exit="reload",delay=0.3})
add("game read unavailable",{noOptions=true})
add("options disappear during load",{loseOptions=true})
add("no selection during update",{noSelection=true})
add("no selected preset",{noPreset=true})
add("unreadable selected preset",{unreadable=true})
add("empty preset",{empty=true})
add("idle update",{idle=true})
add("editor-open timeout",{idle=true,openTimeout=true})
for _,menu in ipairs({"cet","native"})do
 for _,phase in ipairs({"precleanup","apply","cleanup","settle"})do
  add("supersede "..menu.." during "..phase,{supersede=phase,menu=menu,delay=0.15})
 end
end
add("native request invocation guard",{bridgeRequest=true})
add("preexisting camera guard",{cameraHold=true})
local function run(case)
 local e,o=kit.entry,kit.option
 local entries={e("Eyes",2,"eyes","options:two"),e("SkinColor",1,"skin_color","options:one")}
 local available={o("Eyes",0,"eyes"),o("SkinColor",0,"skin_color"),o("Hair",3,"hair")}
 if case.many then
  entries,available={},{}
  for i=1,10 do entries[i]=e("Option"..i,2,"slot"..i,"options:two");available[i]=o("Option"..i,0,"slot"..i)end
  available[#available+1]=o("Hair",3,"hair")
 end
 if case.directRemap then entries={e("SavedHair",2,"hair","options:two")}end
 if case.missing then entries[#entries+1]=e("Missing",4,"absent")end
 if case.empty then entries={}end
 kit.reset({name=case.name,entries=entries,options=available,mode=case.mode})
 local trace,reads,readOrder,calls,options,system,preset=kit.observe()
 local clockCalls=0
 runtime.helpers.loadClock=function()clockCalls=clockCalls+1;return case.cpuStep and clockCalls*case.cpuStep or 0 end
 runtime.state.status=kit.clone(initialStatus)
 runtime.setStatus=function(...)trace[#trace+1]={"setStatus",...};return realStatus(...)end
 runtime.resetLoadState=realReset
 runtime.helpers.archiveLogForNewSession=function()return true end
 runtime.readConfig=function()return{presetSort="name"},true end
 runtime.writeConfig=function()trace[#trace+1]={"writeConfig"};return true end
 runtime.fileExists=function()return false end
 runtime.recoverTransaction=function()return true end
 runtime.refreshPresets=function()trace[#trace+1]={"scan"}end
 runtime.refreshTrash=function()end
 runtime.initializeAcuImport=function()end
 runtime.initializeNativeBridge=function()return true end
 runtime.refreshAppearanceHistory=function()end
 runtime.refreshEditorState=function()end
 runtime.connectNativeBridgeForMenu=function()return true end
 runtime.temporarilyDisableWardrobe=function()end
 runtime.restoreTemporarilyDisabledWardrobe=function()trace[#trace+1]={"restoreWardrobe"}end
 runtime.cancelConfirmations=function()trace[#trace+1]={"clearConfirmations"}end
 runtime.closeActivityLog=function()trace[#trace+1]={"closeLog"}end
 runtime.setEditorOpenStatus=function(...)trace[#trace+1]={"editorStatus",...}end
 runtime.updateAcuImport=function()end
 runtime.hydrateNamedPreset=function(name)if case.unreadable then return nil end;return runtime.state.library.presets[name]end
 runtime.saveAppearanceHistorySnapshot=function()trace[#trace+1]={"history"};return true end
 runtime.state.dehydratePreset=function()end
 runtime.ui={closeDebugPanel=function()end}
 local hooks={}
 runtime.Observe=function(class,method,fn)hooks[class.."."..method]=fn end
 runtime.Override=runtime.Observe
 local sequence=0
 local bridge={HasPanels=function()return false end,GetRequestSequence=function()return sequence end,
  GetRequestAction=function()return "load"end,GetRequestPayload=function()return "Second"end,
  SetBusy=function(_,...)trace[#trace+1]={"SetBusy",...}end,
  Respond=function(_,...)trace[#trace+1]={"Respond",...}end}
 local function attach()
  runtime.state.app.nativeBridge=bridge
  runtime.state.app.overlayOpen=true;runtime.state.app.windowOpen=true
 end
 attach();events.onInit()
 local open=assert(hooks["characterCreationBodyMorphMenu.OnInitialize"])
 local close=assert(hooks["characterCreationBodyMorphMenu.OnUninitialize"])
 local camera=assert(hooks["BaseCharacterCreationController.RequestCameraChange"])
 local menu={InitializeList=function()trace[#trace+1]={"refresh"}end,CPMUpdateRandomizerControls=function()end}
 open(menu)
 runtime.state.app.presetCameraHold=case.cameraHold or false
 if case.cameraNil then runtime.state.app.presetCameraHold=nil end
 local second=kit.clone(preset);second.entries={e("Eyes",1,"eyes","options:one"),e("SkinColor",2,"skin_color","options:two")}
 runtime.state.library.presets.Second=second
 local updateCalls,loadCalls,clock,queue=0,0,0,{}
 local loader=runtime.loadPreset
 runtime.loadPreset=function(...)loadCalls=loadCalls+1;return loader(...)end
 local mapReplaced,observationClosed=false,false
 local getter=getmetatable(options[3]).__index
 getmetatable(options[3]).__index=function(object,key)
  if case.observationClose and not observationClosed and key=="currIndex"
      and runtime.state.load.pendingChange then observationClosed=true;close()end
  return getter(object,key)
 end
 local begin=runtime.helpers.beginPendingChange
 if case.mapReplacement then
  runtime.helpers.beginPendingChange=function(...)
   local result=kit.pack(begin(...))
   trace[#trace+1]={"attempt maps",kit.clone(runtime.state.load.applyAttempts),kit.clone(runtime.state.load.cleanupAttempts)}
   return unpack(result,1,result.n)
  end
 end
 local writeOrdinal=0
 local write=system.ApplyChangeToOption
 system.ApplyChangeToOption=function(self,live,target)
  trace[#trace+1]={"cameraDuringWrite",runtime.state.app.presetCameraHold}
  local current=live.currIndex
  writeOrdinal=writeOrdinal+1
  if writeOrdinal==case.failWriteAt then trace[#trace+1]={"injected write failure",target};error("write failed",0)end
  write(self,live,target)
  if case.mapReplacement and not mapReplaced then
   runtime.state.load.applyAttempts={};runtime.state.load.cleanupAttempts={};mapReplaced=true
  end
  if case.delay then live.currIndex=current;queue[#queue+1]={at=clock+case.delay,option=live,target=target}end
 end
 if case.noOptions then system.GetUnitedOptions=function()return nil end end
 local function start(name,menuKind)
  runtime.state.library.selected=name
  trace[#trace+1]={"start",name,menuKind or "cet"}
  if menuKind=="native"then nativeStart();return end
  if not runtime.state.load.needsContinue then runtime.resetLoadState()end
  runtime.state.load.autoTimer=0;runtime.state.load.autoPasses=0;runtime.state.load.resetBefore=true
  runtime.loadPreset()
  if runtime.state.load.needsContinue then runtime.state.load.auto=true end
 end
 local snapshots,frameCalls={},{}
 local function sample(label)
  local load,app=runtime.state.load,runtime.state.app
  local wrapped=false
  camera(nil,"eyes",false,function()wrapped=true end)
  local indices={};for i,option in ipairs(options)do indices[i]=option.currIndex end
  snapshots[#snapshots+1]={label=label,time=clock,phase=load.phase,stage=load.choiceStage,
   auto=load.auto,needsContinue=load.needsContinue,pending=kit.clone(load.pendingChange),batch=kit.clone(load.batch),
   remaining=load.remaining,pass=load.pass,values=kit.clone(load.values),satisfied=kit.clone(load.satisfied),
   unconfirmed=kit.clone(load.unconfirmed),cleanup=kit.clone(load.cleanupSkipped),
   scanRetained=load.scanResult~=nil,stagePending=kit.clone(load.stagePending),
   cameraHold=app.presetCameraHold,cameraBlocked=not wrapped,nativeBusy=app.nativeBusy,
   derivedBusy=load.auto or load.needsContinue or load.pendingChange~=nil,ready=app.ready,
   pendingGameWrites=#queue,indices=indices,status=kit.clone(runtime.state.status.sections.load)}
 end
 if case.noPreset then runtime.state.library.selected=nil;runtime.loadPreset()
 elseif not case.idle then start(case.name)end
 if case.openTimeout then runtime.state.editor.openPending=true end
 sample("start")
 local changed,finished=false,false
 for frame=1,1600 do
  local load=runtime.state.load
  if case.supersede and not changed and ((case.supersede=="settle"and(load.batch or load.pendingChange))or(load.phase==case.supersede))then
   start("Second",case.menu);changed=true;sample("superseded")
  end
  if frame==2 then
   if case.timedShape then local choices=options[3].info.options;choices[#choices+1]={localizedName="extra"}end
   if case.timedLabel then options[3].info.name="ChangedHair"end
   if case.timedSlot then options[3].info.uiSlot="changed_hair"end
   if case.timedInactive then options[3].isActive=false end
  end
  if case.pollFallback and not changed and load.pendingChange and load.pendingChange.confirmedAt then
   options[load.pendingChange.position].info.name="ChangedHair";changed=true
  end
  if frame==2 and case.bridgeRequest then sequence=1 end
  if frame==2 and case.loseOptions then system.GetUnitedOptions=function()return nil end end
  if frame==2 and case.noSelection then runtime.state.library.selected=nil end
  if frame==2 and case.timeout then load.elapsed=1000 end
  if frame==2 and case.boundaryElapsed then load.elapsed=case.boundaryElapsed end
  if frame==2 and case.exit then
   if case.exit=="editor"then close();sample("editor closed");open(menu);sample("editor reopened")
   else
    events.onShutdown();sample("shutdown")
    if case.exit=="reload"then
     runtime.state.load=stateModel.newLoad(runtime.AUTO_LOAD_TIMING.passInterval)
     runtime.state.app=stateModel.newApp(runtime.NATIVE_READY_STATUS)
     attach();events.onInit();open(menu);sample("reload")
    end
   end
   finished=true;break
  end
  clock=clock+(case.openTimeout and 6 or 0.05)
  for i=#queue,1,-1 do if queue[i].at<=clock then queue[i].option.currIndex=queue[i].target;table.remove(queue,i)end end
  local allocationsBefore=CPM_TABLE_PROBE and CPM_TABLE_PROBE.count
  local clocksBefore,loadsBefore,readsBefore,traceBefore=clockCalls,loadCalls,#readOrder,#trace
  events.onUpdate(case.openTimeout and 6 or 0.05);updateCalls=updateCalls+1
  frameCalls[#frameCalls+1]={clockCalls-clocksBefore,loadCalls-loadsBefore,#readOrder-readsBefore,#trace-traceBefore}
  if CPM_TABLE_PROBE then frameAllocations[#frameAllocations+1]=CPM_TABLE_PROBE.count-allocationsBefore end
  sample("update "..frame)
  if not runtime.state.load.auto then finished=true;break end
 end
 assert(finished,"scripted scenario did not finish: "..case.name)
 if case.supersede then assert(changed,"supersede phase was not reached: "..case.name)end
 realUpdate(0.05);sample("bridge after exit")
 runtime.loadPreset=loader
 runtime.helpers.beginPendingChange=begin
 local ids={[system]="system",[bridge]="bridge"}
 for index,option in ipairs(options)do ids[option]="option:"..index end
 local function normalized(value)
  if ids[value]then return "GAME:"..ids[value]end
  if type(value)~="table"then assert(type(value)~="function","function in observable state");return value end
  local copy={}
  local metadata=getmetatable(value)
  if metadata then assert(metadata.__mode=="k","unknown game reference");copy.TEST_WEAK_MODE="k"end
  for key,item in pairs(value)do copy[normalized(key)]=normalized(item)end
  return copy
 end
 return {frameCalls=frameCalls,finalLoad=normalized(runtime.state.load),finalApp=normalized(runtime.state.app),trace=trace,reads=reads,readOrder=readOrder,calls=calls,snapshots=snapshots,
  updates=updateCalls,loads=loadCalls,clockCalls=clockCalls,final=kit.clone(snapshots[#snapshots])}
end
local expected
if not CPM_RECORD_STAGE8 then expected=require("modules/domain/stage8_fixtures")end
local actual,reports,allocations={},{},{}
for i,case in ipairs(cases)do
 machineCalls,machineTrace,frameAllocations=0,{},{}
 if CPM_TABLE_PROBE then CPM_TABLE_PROBE.count=0 end
 local result=run(case)
 if CPM_TABLE_PROBE then
  allocations[i]={case.name,CPM_TABLE_PROBE.count,frameAllocations}
  if expected then assert(expected.allocations and expected.allocations[i][1]==case.name
    and expected.allocations[i][2]==CPM_TABLE_PROBE.count
    and kit.literal(expected.allocations[i][3])==kit.literal(frameAllocations),"stage 8 allocation count changed: "..case.name)end
 end
 reports[i]={name=case.name,updates=result.updates,loads=result.loads,clockCalls=result.clockCalls,calls=result.calls,final=result.final,
  machineCalls=machineCalls,machineActions=machineTrace,states=result.snapshots,trace=result.trace,
  finalState={load=result.finalLoad,app=result.finalApp},frameCalls=result.frameCalls}
 actual[i]={case.name,kit.literal(result)}
 if expected and CPM_STAGE8_DEBUG and expected[i][2]~=actual[i][2]then
  local file=assert(io.open("C:/Users/Diamo/AppData/Local/Temp/CPM-stage8-expected.txt","wb"));file:write(expected[i][2]);file:close()
  file=assert(io.open("C:/Users/Diamo/AppData/Local/Temp/CPM-stage8-actual.txt","wb"));file:write(actual[i][2]);file:close()
 end
 if expected then assert(expected[i][1]==case.name and expected[i][2]==actual[i][2],"stage 8 differs: "..case.name)end
end
if CPM_RECORD_STAGE8 then
 if CPM_TABLE_PROBE then actual.allocations=allocations end
 local file=assert(io.open(root.."modules/domain/stage8_fixtures.lua","wb"));file:write("return ",kit.literal(actual),"\n");file:close()
else assert(#expected==#actual,"stage 8 fixture count changed")end
if CPM_STAGE8_REPORT then
 local file=assert(io.open(CPM_STAGE8_REPORT,"wb"));file:write("return ",kit.literal(reports));file:close()
end
if CPM_ALLOCATION_OUTPUT then
 local file=assert(io.open(CPM_ALLOCATION_OUTPUT,"wb"));file:write("return ",kit.literal(allocations));file:close()
end
print("Stage 8 timed scenarios passed: "..#actual.."; actions, logs, states, reads and OnUpdate/load counts match.")

local machine=require("modules/application/loading")
local first=stateModel.newLoad(runtime.AUTO_LOAD_TIMING.passInterval)
local second=stateModel.newLoad(runtime.AUTO_LOAD_TIMING.passInterval)
first.resetBefore=true
local changed,actions=machine.transition(first,{kind="begin",loadName="First"})
assert(changed==first and actions[1]=="none"and first.phase=="precleanup")
machine.transition(second,{kind="begin",loadName="Second"})
assert(second.phase=="apply"and first.phase=="precleanup"and first.satisfied~=second.satisfied)
machine.transition(first,{kind="begin_pending",changeKind="apply",key="Eyes",optionKey="Eyes",position=1,
 label="Eyes",occurrence=1,slot="eyes",shape="options:3",target=2,current=0,identity="Eyes",longSettle=false,
 timing=runtime.AUTO_LOAD_TIMING})
assert(first.pendingChange and second.pendingChange==nil)
machine.transition(second,{kind="choice_stage"})
assert(second.choiceStage=="secondary"and first.choiceStage=="main")
first.elapsed=0.5
local _,settled=machine.transition(first,{kind="pending",present=true,current=2,signature=first.lastStructureSignature,
 timing=runtime.AUTO_LOAD_TIMING})
assert(settled[1]=="settled"and first.pendingChange==nil and first.satisfied.Eyes and not second.satisfied.Eyes)
local _,reset=machine.transition(first,{kind="reset"})
assert(reset[1]=="reset")
stateModel.resetLoad(first,runtime.AUTO_LOAD_TIMING.passInterval)
assert(first.presetName==nil and second.presetName=="Second")
assert(actions[1]=="none"and settled[1]=="settled")
print("Headless state/action isolation and compatibility reset action passed.")
