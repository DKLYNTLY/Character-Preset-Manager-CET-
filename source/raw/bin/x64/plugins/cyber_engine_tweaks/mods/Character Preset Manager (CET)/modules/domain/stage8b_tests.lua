local root="source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/"
package.path=root.."?.lua;"..package.path
require("modules/domain/stage9_sandbox").install(root)
require("modules/constants")
local productionGroupLimit=require("modules/runtime").AUTO_LOAD_TIMING.maximumGroupChanges
local file=assert(io.open(root.."modules/domain/stage7_tests.lua","rb"))
local source=file:read("*a");file:close()
local prefix=source:sub(1,assert(source:find("local cases={}",1,true))-1)
local kit=assert(loadstring(prefix..[[
return {reset=reset,clone=clone,option=option,literal=literal,observe=function()return trace,reads,readOrder,calls,options,system end}
]]))()
local runtime=require("modules/runtime")
runtime.AUTO_LOAD_TIMING.maximumGroupChanges=productionGroupLimit
local codec=require("modules/domain/preset_codec")
local stateModel=require("modules/domain/state")
local fixture=require("modules/domain/stage8b_fixtures")
local PREVIEW_COMMIT_SECONDS=0.10
local UPDATE_SECONDS=0.05
local MAXIMUM_UPDATES=10000
local RECORDED_GROUP_LIMIT=4
local OBSERVED_ALINA_HAIR_INDEX=170
local OFF_CHOICE_INDEX=0
local EARLIER_CYBERWARE_INDEX=24
local EARLIER_PIERCINGS_INDEX=1
local FINAL_PIERCINGS_INDEX=12
local geometry={cyberware_switcher=true,piercings=true,nipple_piercings=true,mch_hair_switcher=true,hairstyle=true}
local unavailable={['LocKey#13879517178655718515']=true,['LocKey#8824472266055663870']=true}
local presets={}
local slots,bySlot={},{}
for _,name in ipairs({"Alina","ss/ddd","ss/ss"})do
 local preset=assert(codec.decodeText(fixture.presets[name],name));presets[name]=preset
 for _,entry in ipairs(preset.entries)do
  if not unavailable[entry.key]then
   if not bySlot[entry.slot]then
    bySlot[entry.slot]={slot=entry.slot,key=entry.key,maximum=entry.index};slots[#slots+1]=bySlot[entry.slot]
   end
   bySlot[entry.slot].maximum=math.max(bySlot[entry.slot].maximum,entry.index)
  end
 end
end
local function run(label,requests,collision)
 local available={}
 for _,slot in ipairs(slots)do
  local choices={};for i=0,slot.maximum do choices[i+1]="unknown:"..i end
  available[#available+1]=kit.option(slot.key,0,slot.slot,choices)
 end
 kit.reset({name=label,preset=presets.Alina,options=available})
 local trace,_,_,_,options,system=kit.observe()
 local byLiveSlot={};for _,option in ipairs(options)do byLiveSlot[option.info.uiSlot]=option end
 local clock,pending,visible=0,nil,{}
 local summaries={}
 local oldLog=runtime.log
 runtime.log=function(message,level)
  oldLog(message,level)
  if message:find("SUMMARY |",1,true)then summaries[#summaries+1]=message end
 end
 runtime.hydrateNamedPreset=function(name)return runtime.state.library.presets[name]end
 runtime.saveAppearanceHistorySnapshot=function()return true end
 runtime.state.app.inCustomization=true
 runtime.state.app.overlayOpen=true
 local function record(...)trace[#trace+1]={...}end
 local function singleton(target)local set={};if target~=0 then set[target]=true end;return set end
 local function commit()
  if pending and clock>=pending.at then
   for slot,target in pairs(pending.changes)do
    visible[slot]=singleton(target)
    if pending.collision then for index in pairs(pending.before[slot]or{})do visible[slot][index]=true end end
   end
   record("preview commit",pending.collision,kit.clone(visible));pending=nil
  end
 end
 local apply=system.ApplyChangeToOption
 system.ApplyChangeToOption=function(self,option,target)
  apply(self,option,target)
  local slot=option.info.uiSlot
  if geometry[slot]then
   commit()
   if not pending then pending={at=clock+PREVIEW_COMMIT_SECONDS,before=kit.clone(visible),changes={}}end
   if next(pending.changes)~=nil and collision then pending.collision=true end
   pending.changes[slot]=target
   record("preview request",clock,slot,target)
  end
 end
 local function advance(delta)
  clock=clock+delta;commit();runtime.state.app.optionsMemo=nil
  if runtime.state.load.auto then runtime.helpers.updateAutomaticLoad(delta,runtime.state.app.loadInvocation)end
 end
 for _,request in ipairs(requests)do
  local name=request[1];local preset=presets[name]
  for _,entry in ipairs(preset.entries)do
   local option=byLiveSlot[entry.slot]
   if option and not unavailable[entry.key]then
    option.info.name=entry.key
    if entry.choice then
     local wanted=entry.choice:sub(#"options:"+1)
     local target=name=="Alina"and entry.slot=="hairstyle"and OBSERVED_ALINA_HAIR_INDEX or entry.index
     for index,value in ipairs(option.info.options)do
      if value.localizedName==wanted then value.localizedName="unknown:"..index end
     end
     option.info.options[target+1]={localizedName=wanted}
    end
   end
  end
  runtime.state.library.presets[name]=preset;runtime.state.library.selected=name
  runtime.state.app.nativeLoadSummary=nil;runtime.state.app.nativePanelShowDetails=false
  runtime.resetLoadState();stateModel.prepareAutomaticLoad(runtime.state.load);runtime.loadPreset()
  if runtime.state.load.needsContinue then runtime.state.load.auto=true end
  local updates=0
  while runtime.state.load.auto and updates<MAXIMUM_UPDATES do advance(UPDATE_SECONDS);updates=updates+1 end
  assert(not runtime.state.load.auto,"load did not terminate")
  advance(PREVIEW_COMMIT_SECONDS)
  record("load finished",name,clock,updates,kit.clone(visible))
  advance(request[2])
 end
 local cyberware=byLiveSlot.cyberware_switcher.currIndex
 local piercings=byLiveSlot.piercings.currIndex
 assert(cyberware==OFF_CHOICE_INDEX and piercings==FINAL_PIERCINGS_INDEX,"data matching failed")
 assert(#summaries==#requests,"missing terminal summary")
 for index,request in ipairs(requests)do
  local summary=summaries[index]
  if request[1]=="Alina"then assert(summary:find("applied=48 | unresolved=2",1,true),summary)
  else assert(summary:find("processed=59 | confirmed=59 | unconfirmed=0 | forced=0 | cleanupUnconfirmed=0",1,true),summary)end
 end
 local stale=visible.cyberware_switcher and visible.cyberware_switcher[EARLIER_CYBERWARE_INDEX]
 local stalePiercing=visible.piercings and visible.piercings[EARLIER_PIERCINGS_INDEX]
 local allGeometryMatches=true
 for slot in pairs(geometry)do
  local target=byLiveSlot[slot].currIndex
  if kit.literal(visible[slot]or{})~=kit.literal(singleton(target))then allGeometryMatches=false end
 end
 record("final",cyberware,piercings,kit.clone(visible))
 if CPM_STAGE8B_REPORT then
  local output=assert(io.open(CPM_STAGE8B_REPORT..label..".lua","wb"));output:write("return ",kit.literal({trace=trace,summaries=summaries,visible=visible,cyberware=cyberware,piercings=piercings}));output:close()
 end
 return not stale and not stalePiercing and allGeometryMatches
end
assert(run("observed-order-data-only",fixture.requests,false),"ordinary data-only replay failed")
local original=runtime.AUTO_LOAD_TIMING.maximumGroupChanges
runtime.AUTO_LOAD_TIMING.maximumGroupChanges=RECORDED_GROUP_LIMIT
assert(not run("conditional-collision-baseline",fixture.requests,true),"conditional fake did not expose the overlapping-write failure")
runtime.AUTO_LOAD_TIMING.maximumGroupChanges=original
assert(run("conditional-collision-current",fixture.requests,true),"preview contains an old cyberware/piercing choice in the conditional collision model")
assert(run("single-load",{{"ss/ss",0}},true),"single load failed")
assert(run("paused-pair",{{"ss/ddd",5},{"ss/ss",0}},true),"paused pair failed")
print("Part B: data-only logged sequence passes; conditional collision fails with batches of four and passes with the current batch limit; single load and paused pair pass.")
