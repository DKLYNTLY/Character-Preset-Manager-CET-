local root="source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/"
package.path=root.."?.lua;"..package.path
require("modules/domain/stage9_sandbox").install(root)
local file=assert(io.open(root.."modules/domain/stage7_tests.lua","rb"))
local source=file:read("*a");file:close()
local prefix=source:sub(1,assert(source:find("local cases={}",1,true))-1)
local kit=assert(loadstring(prefix..[[
return {reset=reset,clone=clone,literal=literal,pack=pack,observe=function()return trace end}
]]))()
local runtime=require("modules/runtime")
require("modules/editor")
local events=require("modules/events")
local model=require("modules/domain/state")
local initialEditor=kit.clone(runtime.state.editor)
local initialUi=kit.clone(runtime.state.ui)
local initialStatus=kit.clone(runtime.state.status)
local realReset=runtime.resetLoadState
local realStatus=runtime.setStatus
local results,profiles={},{}
local cases={"gameplay launch","ordinary mirror","new-game creator","no controller","puppet unavailable",
 "watchdog below","watchdog exact","watchdog above","watchdog negative","redirected but not ready",
 "accept","cancel","close","launch failure","hotkey failure","shutdown open","CET reload",
 "already pending","hooks unavailable","customization already active","disable no player","disable player error",
 "disable no active set","disable set error","disable no equipment","disable queue failure","already disabled",
 "restore no player","restore player error","restore no equipment","restore queue failure","restore without retry",
 "refresh enter","refresh leave","close active load","camera idle","camera guard","camera auto","camera continue",
 "camera outside editor","hotkey released","controller initialize","observer init failure","observer exit failure",
 "both controller observers fail","pause registration failure","puppet registration failure"}
local function run(name)
 kit.reset({name=name});local trace=kit.observe()
 runtime.state.editor=kit.clone(initialEditor);runtime.state.ui=kit.clone(initialUi);runtime.state.status=kit.clone(initialStatus)
 runtime.state.nativeCatalog.available=false
 local function record(...)trace[#trace+1]={...}end
 local flags={customization=false,active=true}
 local hooks,registrations={},{}
 local player={};local system={};local menus={};local scenario={};local controller={};local menu={}
 local ids={[player]="player",[system]="equipment",[menus]="menus",[scenario]="scenario",[controller]="controller",[menu]="body-morph"}
 local function observed(value)
  if ids[value]then return "GAME:"..ids[value]end
  if type(value)~="table"then assert(type(value)~="function");return value end
  local copy={};for key,item in pairs(value)do copy[observed(key)]=observed(item)end;return copy
 end
 local function snapshot(label)
  record("snapshot",label,observed(runtime.state.load),observed(runtime.state.app),observed(runtime.state.editor),observed(runtime.state.status),observed(runtime.state.ui))
 end
 runtime.getOptions=function()
  record("getOptions")
  if flags.queryError then error("options unavailable",0)end
  return system,flags.customization and {}or nil
 end
 runtime.Game.GetPlayer=function()
  record("GetPlayer")
  if flags.playerError then error("player unavailable",0)end
  if not flags.noPlayer then return player end
 end
 runtime.Game.GetScriptableSystemsContainer=function()
  record("GetSystems")
  return {Get=function(_,key)record("GetSystem",key);if not flags.noEquipment then return system end end}
 end
 runtime.EquipmentSystem={GetActiveWardrobeSetID=function(owner)
  assert(owner==player);record("GetWardrobeSet")
  if flags.setError then error("wardrobe unavailable",0)end
  if flags.noSet then return nil end
  return flags.active and 0 or -1
 end}
 runtime.gameWardrobeClothingSetIndex={INVALID=-1}
 runtime.QuestDisableWardrobeSetRequest={new=function()record("newDisable");return{kind="disable"}end}
 runtime.QuestRestoreWardrobeSetRequest={new=function()record("newRestore");return{kind="restore"}end}
 system.QueueRequest=function(_,request)
  assert(request.owner==player);record("QueueRequest",request.kind,request.blockReequipping,
   runtime.state.editor.openPending,runtime.state.app.inCustomization,runtime.state.editor.wardrobeTemporarilyDisabled)
  if flags.queueError==request.kind then error(request.kind.." failed",0)end
 end
 controller.SpawnMenuInstanceEvent=function(self,event)
  assert(self==controller);record("SpawnMenu",event)
  if flags.launchError then error("launch failed",0)end
 end
 scenario.SwitchToScenario=function(self,target)assert(self==scenario);record("SwitchScenario",target);return "redirected"end
 scenario.GetMenusState=function()
  record("GetMenusState")
  if flags.puppetError then error("puppet unavailable",0)end
  return menus
 end
 menus.OpenMenu=function(_,target,data)
  record("OpenMenu",target,kit.clone(data))
 end
 runtime.MorphMenuUserData={new=function()record("MorphMenuUserData");return{}end}
 runtime.gameuiCharacterCustomizationEditTag={NewGame="NewGame"}
 local function register(kind,class,method,callback)
  record(kind,class,method);registrations[#registrations+1]={kind,class,method}
  if (name=="observer init failure"and class=="characterCreationBodyMorphMenu"and method=="OnInitialize")
   or(name=="observer exit failure"and class=="characterCreationBodyMorphMenu"and method=="OnUninitialize")
   or(name=="both controller observers fail"and class=="gameuiInGameMenuGameController")
   or(name=="pause registration failure"and class=="MenuScenario_PauseMenu")
   or(name=="puppet registration failure"and method=="OnCCOPuppetReady")then error("registration unavailable",0)end
  hooks[class.."."..method]=callback
 end
 runtime.Observe=function(...)return register("Observe",...)end
 runtime.Override=function(...)return register("Override",...)end
 runtime.helpers.archiveLogForNewSession=function()return true end
 runtime.readConfig=function()return{presetSort="name"},true end
 runtime.writeConfig=function()record("writeConfig");return true end
 runtime.fileExists=function()return true end
 runtime.recoverTransaction=function()return true end
 runtime.refreshPresets=function()record("refreshPresets")end
 runtime.refreshTrash=function()record("refreshTrash")end
 runtime.initializeAcuImport=function()record("initializeAcuImport")end
 runtime.initializeNativeBridge=function()record("initializeNativeBridge")end
 runtime.refreshAppearanceHistory=function()record("refreshHistory")end
 runtime.connectNativeBridgeForMenu=function(value)assert(value==menu);record("connectBridge")end
 runtime.helpers.clearOptionCatalog=function()record("clearCatalog");runtime.state.app.optionsMemo=nil end
 runtime.helpers.logLoadMeasurements=function(value)record("measure",value)end
 runtime.helpers.finishOverlayRequest=function()record("finishOverlay")end
 runtime.helpers.updateOverlayRequest=function(value)record("overlayUpdate",value)end
 runtime.updateAcuImport=function(value)record("acuUpdate",value)end
 runtime.updateNativeBridge=function(value)record("bridgeUpdate",value)end
 runtime.cancelConfirmations=function()record("clearConfirmations")end
 runtime.closeActivityLog=function()record("closeLog")end
 runtime.helpers.auditSection=function(value)record("audit",value)end
 runtime.state.invalidatePreflight=function()record("invalidatePreflight");model.invalidatePreflight(runtime.state.load)end
 runtime.resetLoadState=function()record("resetLoad");return realReset()end
 runtime.setStatus=realStatus
 events.onInit()
 local function invoke(class,method,...)
  local fn=assert(hooks[class.."."..method],class.."."..method)
  local before=CPM_TABLE_PROBE and CPM_TABLE_PROBE.count
  local output=kit.pack(fn(...));record("return",class,method,output)
  if before and method=="RequestCameraChange"then profiles[#profiles+1]={name,"camera",CPM_TABLE_PROBE.count-before}end
 end
 local function capture(method)invoke("gameuiInGameMenuGameController",method or "RegisterGlobalBlackboards",controller)end
 local function open()flags.customization=true;invoke("characterCreationBodyMorphMenu","OnInitialize",menu)end
 local function close(reason)record("exit",reason);flags.customization=false;invoke("characterCreationBodyMorphMenu","OnUninitialize")end
 local function launch()capture();events.openEditor(true)end
 local function pause()invoke("MenuScenario_PauseMenu","OnEnterScenario",scenario,"previous","userdata",function(...)record("originalPause",...);return "original"end)end
 local function puppet()invoke("MenuScenario_CharacterCustomizationMirror","OnCCOPuppetReady",scenario,function(...)record("originalPuppet",...);return "fallback"end)end
 local updates=0
 local function update(delta)
  local before=CPM_TABLE_PROBE and CPM_TABLE_PROBE.count
  events.onUpdate(delta);updates=updates+1
  if before then profiles[#profiles+1]={name,"update",CPM_TABLE_PROBE.count-before}end
 end
 if name=="gameplay launch"then launch();pause();puppet();open()
 elseif name=="ordinary mirror"then pause();puppet();open()
 elseif name=="new-game creator"then invoke("MenuScenario_CharacterCustomization","OnEnterScenario");open();invoke("MenuScenario_CharacterCustomization","OnLeaveScenario");close(name)
 elseif name=="no controller"then events.openEditor(true)
 elseif name=="puppet unavailable"then flags.puppetError=true;puppet()
 elseif name:find("watchdog",1,true)then
  launch();update(name=="watchdog below"and 4.999 or name=="watchdog exact"and 5 or name=="watchdog above"and 5.001 or -1)
 elseif name=="redirected but not ready"then launch();pause();update(6)
 elseif name=="accept"or name=="cancel"or name=="close"then open();close(name)
 elseif name=="launch failure"then flags.launchError=true;launch()
 elseif name=="hotkey failure"then capture();flags.queryError=true;events.openEditor(true)
 elseif name=="shutdown open"or name=="CET reload"then
  open();events.onShutdown();snapshot("shutdown")
  if name=="CET reload"then
   runtime.state.editor=kit.clone(initialEditor);runtime.state.app=model.newApp(runtime.NATIVE_READY_STATUS)
   runtime.state.load=model.newLoad(runtime.AUTO_LOAD_TIMING.passInterval);flags.customization=false;events.onInit()
  end
 elseif name=="already pending"then runtime.state.editor.openPending=true;events.openEditor(true)
 elseif name=="hooks unavailable"then runtime.state.editor.hooksAvailable=false;events.openEditor(true)
 elseif name=="customization already active"then flags.customization=true;capture();events.openEditor(true)
 elseif name:find("disable",1,true)==1 or name=="already disabled"then
  flags.noPlayer=name=="disable no player";flags.playerError=name=="disable player error"
  flags.noSet=name=="disable no active set";flags.setError=name=="disable set error"
  flags.noEquipment=name=="disable no equipment";flags.queueError=name=="disable queue failure"and"disable"or nil
  runtime.state.editor.wardrobeTemporarilyDisabled=name=="already disabled"
  record("disableReturn",runtime.temporarilyDisableWardrobe())
 elseif name:find("restore",1,true)==1 then
  open();flags.noPlayer=name=="restore no player";flags.playerError=name=="restore player error"
  flags.noEquipment=name=="restore no equipment"or name=="restore without retry"
  flags.queueError=name=="restore queue failure"and"restore"or nil
  close(name);snapshot("after failed restoration")
  for i=1,20 do update(1)end
 elseif name=="refresh enter"or name=="refresh leave"then
  if name=="refresh leave"then open()else flags.customization=true end
  if name=="refresh leave"then flags.customization=false end
  runtime.state.load.presetName="Active";runtime.state.load.needsContinue=true;runtime.state.load.pendingChange={key="pending"}
  runtime.refreshEditorState()
 elseif name=="close active load"then
  open();runtime.state.load.presetName="Active";runtime.state.load.needsContinue=true;runtime.state.load.pendingChange={key="pending"};close(name)
 elseif name:find("camera",1,true)==1 then
  runtime.state.app.inCustomization=name~="camera outside editor"
  runtime.state.app.presetCameraHold=name=="camera guard"or name=="camera outside editor"
  runtime.state.load.auto=name=="camera auto";runtime.state.load.needsContinue=name=="camera continue"
  for i=1,20 do invoke("BaseCharacterCreationController","RequestCameraChange",{},"eyes",i%2==0,function(...)record("originalCamera",...)end)end
 elseif name=="hotkey released"then events.openEditor(false)
 elseif name=="controller initialize"then capture("OnInitialize")end
 snapshot("final")
 local function normalize(value,seen)
  if ids[value]then return "GAME:"..ids[value]end
  if type(value)~="table"then assert(type(value)~="function");return value end
  seen=seen or{};assert(not seen[value],"cyclic state");seen[value]=true
  local copy={};for key,item in pairs(value)do copy[normalize(key,seen)]=normalize(item,seen)end
  seen[value]=nil;return copy
 end
 return {trace=normalize(trace),registrations=registrations,updates=updates,scenario=normalize(scenario),editor=normalize(runtime.state.editor)}
end
for _,name in ipairs(cases)do results[#results+1]={name,kit.literal(run(name))}end
if CPM_RECORD_STAGE9 then
 if CPM_TABLE_PROBE then results.perFrame=profiles end
 local output=assert(io.open(root.."modules/domain/stage9_fixtures.lua","wb"));output:write("return ",kit.literal(results),"\n");output:close()
else
 local expected=require("modules/domain/stage9_fixtures");assert(#expected==#results)
 for index,result in ipairs(results)do assert(kit.literal(expected[index])==kit.literal(result),"stage 9 differs: "..result[1])end
 if CPM_TABLE_PROBE then assert(kit.literal(expected.perFrame)==kit.literal(profiles),"stage 9 per-frame constructor counts changed")end
end
print("Stage 9 lifecycle scenarios passed: "..#results.."; ordered effects, logs, registrations, state and update counts match.")

local editor=require("modules/application/editor")
assert(editor.classify(true)=="character_creator" and editor.classify(false)=="mirror")
assert(editor.launchGate(true,false)=="pending" and editor.launchGate(false,false)=="unsupported")
assert(editor.launchTarget(true,false)=="active" and editor.launchTarget(false,false)=="unavailable")
local initial=editor.plan("opened")
local time,waiting=editor.watchdog(1,1,5)
assert(time==2 and #waiting==0)
local threshold,expired=editor.watchdog(4,1,5)
assert(threshold==5 and expired[1]=="stopOpening")
assert(editor.plan("opened")==initial and editor.plan("closed")~=initial)
assert(editor.cameraBlocked(true,true,false,false) and not editor.cameraBlocked(false,true,true,true))
assert(not editor.shouldMeasure("preset",false,false))
print("Headless lifecycle gates, retained action lists, exact watchdog boundary and camera scope passed.")
