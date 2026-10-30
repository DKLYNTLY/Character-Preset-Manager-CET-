local root="source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/"
package.path=root.."?.lua;"..package.path
require("modules/domain/stage7_sandbox").install(root)
local runtime=require("modules/runtime")
for _,name in ipairs({"constants","state","filesystem","catalog","options","comparison","view_cache","load_engine"})do require("modules/"..name)end
local stateModel=require("modules/domain/state")
local presetCodec=require("modules/domain/preset_codec")
local function literal(value)
  if type(value)=="string"then return '"'..value:gsub('[%z\1-\31\127-\255\\"]',function(c)return string.format("\\%03d",c:byte())end)..'"'end
  if type(value)=="table"then
    local result={};for key,item in pairs(value)do result[#result+1]="["..literal(key).."]="..literal(item)end
    table.sort(result);return "{"..table.concat(result,",").."}"
  end
  if value==nil then return "nil"end
  return tostring(value)
end
local function clone(value)
  if type(value)~="table"then return value end
  local copy={};for key,item in pairs(value)do copy[key]=clone(item)end;return copy
end
local function pack(...)return{n=select("#",...),...}end
local pureCalls={}
local function assertPlain(value, seen)
 local kind=type(value)
 assert(kind=="nil"or kind=="string"or kind=="number"or kind=="boolean"or kind=="table","non-data matching input")
 if kind~="table"then return end
 assert(getmetatable(value)==nil,"game/proxy object reached matching")
 if seen[value]then return end;seen[value]=true
 for key,item in pairs(value)do assertPlain(key,seen);assertPlain(item,seen)end
end
if CPM_MATCHING_OUTPUT then
 for _,name in ipairs({"matching","comparison"})do
  local module=require("modules/domain/"..name)
  for key,original in pairs(module)do
   if type(original)=="function"then
    local identity=name.."."..key
    module[key]=function(...)
     for i=1,select("#",...)do assertPlain(select(i,...),{})end
     pureCalls[identity]=(pureCalls[identity]or 0)+1
     return original(...)
    end
   end
  end
 end
end
local trace,reads,readOrder,calls,options,system,preset,writeMode,changed
local function orderedPairs(value)
  local keys={};for key in pairs(value)do keys[#keys+1]=key end
  table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
  local index=0;return function()index=index+1;local key=keys[index];if key~=nil then return key,value[key]end end
end
local function proxy(data,owner)
  return setmetatable({}, {__index=function(_,key)
    local id=owner.."."..tostring(key);reads[id]=(reads[id]or 0)+1;readOrder[#readOrder+1]=id
    if data.throwField==key then error("unavailable game field",0)end
    return data[key]
  end,__newindex=function(_,key,value)data[key]=value end})
end
local function option(label,index,slot,choices,field)
  field=field or "options"
  local values={};for _,value in ipairs(choices or {"zero","one","two","three"})do
    values[#values+1]=field=="options"and{localizedName=value}or value
  end
  return{info={name=label,uiSlot=slot,[field]=values},currIndex=index or 0,isEditable=true,isActive=true}
end
local function entry(label,index,slot,choice)return{key=label,index=index or 0,slot=slot,choice=choice}end
local watched={
  {runtime,"optionKey"},{runtime,"optionSlot"},{runtime,"stableRuntimeValue"},{runtime,"stableChoiceIdentity"},
  {runtime,"choiceCollectionValue"},{runtime,"optionChoiceIndex"},{runtime,"optionChoiceMatchesIndex"},
  {runtime.helpers,"optionChoiceKey"},{runtime.helpers,"bindOptionCatalog"},{runtime.helpers,"cachedOptionChoices"},
  {runtime.helpers,"preparePresetEntries"},{runtime.helpers,"scanLoadOptions"},{runtime.helpers,"resolveLoadChoice"},
  {runtime.helpers,"beginPendingChange"},{runtime.helpers,"checkPendingChange"},
}
for _,item in ipairs(watched)do
  local target,name=item[1],item[2];local original=target[name]
  target[name]=function(...)calls[name]=(calls[name]or 0)+1;return original(...)end
end
local function reset(case)
  trace,reads,readOrder,calls,options={},{},{},{},{}
  preset=clone(case.preset or {format=8,entries=case.entries or {entry("Eyes",2,"eyes","options:two")}})
  runtime.state.load=stateModel.newLoad(runtime.AUTO_LOAD_TIMING.passInterval)
  runtime.state.app=stateModel.newApp(runtime.NATIVE_READY_STATUS)
  runtime.state.library.selected=case.name
  runtime.state.library.presets={[case.name]=preset}
  runtime.state.editor.activeBodyMorphMenu={InitializeList=function()trace[#trace+1]={"refresh"}end}
  runtime.pairs=orderedPairs
  runtime.LocKeyToString=function(value)return value end
  runtime.NameToString=function(value)return tostring(value)end
  runtime.ToCName=function()return ""end
  runtime.GetLocalizedTextByKey=function()return ""end
  runtime.log=function(message,level)trace[#trace+1]={"log",message,level}end
  runtime.setStatus=function(...)trace[#trace+1]={"status",pack(...)}end
  runtime.helpers.auditSection=function(value)trace[#trace+1]={"audit",value}end
  runtime.helpers.loadClock=function()return 0 end
  runtime.hydrateNamedPreset=function()return preset end
  runtime.state.invalidatePreflight=function()stateModel.invalidatePreflight(runtime.state.load)end
  runtime.state.presetEntryCount=function(model)return #(model.entries or {})end
  for index,data in ipairs(clone(case.options or {option("Eyes",0,"eyes")}))do
    for _,field in ipairs({"definitions","options","morphNames"})do
      for position,value in ipairs(data.info[field]or{})do
        if type(value)=="table"then data.info[field][position]=proxy(value,"choice"..index.."/"..field.."/"..position)end
      end
    end
    data.info=proxy(data.info,"info"..index)
    options[index]=proxy(data,"option"..index)
  end
  writeMode,changed=case.mode,false
  system={ApplyChangeToOption=function(_,live,target)
    local position;for i,value in ipairs(options)do if live==value then position=i end end
    trace[#trace+1]={"write",position,target}
    if writeMode=="fail"then error("write failed",0)end
    if writeMode~="ignore"then live.currIndex=target end
    if not changed and writeMode=="disappear"then live.isActive=false;changed=true end
    if not changed and writeMode=="shape"then
      live.info.options[#live.info.options+1]={localizedName="new-choice"};changed=true
    end
    if not changed and writeMode=="reorder"then
      local array=live.info.options;array[1],array[2]=array[2],array[1];changed=true
    end
  end}
  runtime.Game={GetCharacterCustomizationSystem=function()return system end}
  system.GetUnitedOptions=function()trace[#trace+1]={"getOptions"};return options end
end
local cases={}
local function add(name,entries,available,extra)
  local case=extra or{};case.name=name;case.entries=entries;case.options=available;cases[#cases+1]=case
end
add("vanilla",{entry("Eyes",2,"eyes")},{option("Eyes",0,"eyes")})
add("choice reordered",{entry("Eyes",2,"eyes","options:two")},{option("Eyes",0,"eyes",{"two","one","zero"})})
add("duplicate choice",nil,{option("Eyes",0,"eyes",{"zero","two","two"})})
add("cached unique becomes duplicate",nil,nil,{cacheMutation="duplicate"})
add("cache mutate",nil,nil,{cacheMutation=true})
add("cached duplicate becomes unique",nil,{option("Eyes",0,"eyes",{"zero","two","two"})},{cacheMutation=true})
add("missing choice",nil,{option("Eyes",0,"eyes",{"zero","one"})})
add("choice Unicode",{entry("顔猫",1,"髪","options:é猫")},{option("顔猫",0,"髪",{"zero","é猫"})})
add("missing nonzero",{entry("Missing",2,"absent")},{option("Eyes",0,"eyes")})
add("missing zero",{entry("Missing",0,"absent")},{option("Eyes",0,"eyes")})
add("repeated labels equal",{entry("Repeat",1,"a"),entry("Repeat",2,"b")},{option("Repeat",0,"a"),option("Repeat",0,"b")})
add("repeated labels mismatch",{entry("Repeat",2,"a")},{option("Repeat",0,"a"),option("Repeat",0,"b")})
add("duplicate slots",{entry("Saved",2,"same","options:two")},{option("Live",0,"same"),option("Live2",0,"same")})
add("slot remap",{entry("Old",2,"eyes","options:two")},{option("New",0,"eyes")})
add("force missing choice fallback",{entry("Old",2,"eyes","options:missing")},{option("New",0,"eyes")},{force=true})
add("legacy anchored",{entry("Left",1),entry("Old",2),entry("Right",1)},{option("Left"),option("New"),option("Right")},{force=true,format=4})
add("inactive",nil,{option("Eyes",0,"eyes")},{inactive=true})
add("not editable",nil,{option("Eyes",0,"eyes")},{notEditable=true})
add("unconfirmed saved",nil,nil,{mode="ignore"})
add("unconfirmed cleanup",{entry("Eyes",0,"eyes")},{option("Eyes",0,"eyes"),option("LocKey#11868209119990413348",3,"hair")},{mode="ignore",resetBefore=true})
add("unconfirmed pubic log",{entry("LocKey#13523242420079111419",3,"pubic_hair")},{option("LocKey#13523242420079111419",0,"pubic_hair")},{mode="ignore",format=4})
add("write failure",nil,nil,{mode="fail"})
add("dependent disappears",nil,nil,{mode="disappear"})
add("dependency shape",nil,nil,{mode="shape"})
add("dependency reorder",nil,nil,{mode="reorder"})
add("cleanup extras",{entry("Eyes",2,"eyes")},{option("Eyes",0,"eyes"),option("Hair",3,"hair")},{resetBefore=true})
add("cleanup protected slot",{entry("Old",2,"hair","options:two")},{option("Hair",3,"hair")},{resetBefore=true})
add("cleanup zero slot",{entry("Old",0,"hair")},{option("Hair",3,"hair")},{resetBefore=true})
add("empty",{},{})
add("empty live",{entry("Eyes",2)},{})
add("invalid index",{entry("Eyes",4294967296,"eyes")},{option("Eyes",0,"eyes")})
add("negative index",{entry("Eyes",-1,"eyes")},{option("Eyes",0,"eyes")})
add("numeric string",{entry("Eyes","2","eyes")},{option("Eyes",0,"eyes")})
add("NaN",{entry("Eyes",0/0,"eyes")},{option("Eyes",0,"eyes")})
add("bad slot control",{entry("Eyes",2,"eyes")},{option("Eyes",0,"bad\nslot")})
add("bad slot oversized",{entry("Eyes",2,"eyes")},{option("Eyes",0,string.rep("s",257))})
add("missing info field",nil,{option("Eyes",0,"eyes")},{badField=true})
for _,field in ipairs({"definitions","options","morphNames"})do
 add("choice field "..field,{entry("Eyes",2,"eyes",field..":two")},{option("Eyes",0,"eyes",nil,field)})
end
for _,choice in ipairs({"", "options:","unknown:two","definitions:table: 0x123","options:userdata: 0x123","options:猫"})do
 add("identity "..choice,{entry("Eyes",2,"eyes",choice)},{option("Eyes",0,"eyes")})
end
for format=1,8 do
 local text="# CPM\tformat\t"..format.."\n# CPM\tslot\teyes\n# CPM\tchoice\toptions%3Atwo\nEyes:2\n"
 local model=assert(presetCodec.decodeText(text,"old.preset",false))
 add("legacy format "..format,nil,nil,{preset=model,force=format<7})
end
add("ACU text",nil,nil,{preset=assert(presetCodec.decodeText("Eyes:2\n","acu.preset",false))})
add("ACU JSON",nil,nil,{preset=assert(presetCodec.decodeAcuJson({options={{name="Eyes",value=2}}},false))})
add("readable format 8",nil,nil,{preset=assert(presetCodec.decodeText("# CPM Preset\n# Format: 8\nEyes:2\n# Editor slot: eyes\n# Saved choice: options:two\n","readable.preset",false))})
add("ACU 3.0.0 JSON",nil,nil,{preset=assert(presetCodec.decodeAcuJson({isMaleVO=true,options={{name="Eyes",value=2}}},false))})
add("Uint32 maximum",{entry("Eyes",4294967295,"eyes")},{option("Eyes",0,"eyes")})
local manyChoices={};for i=0,999 do manyChoices[#manyChoices+1]="CCXL_"..i end
add("full pipeline vanilla",{entry("Eyes",2,"eyes")},{option("Eyes",0,"eyes")},{fullPipeline=true})
add("full pipeline unavailable",{entry("Missing",2,"absent")},{option("Eyes",0,"eyes")},{fullPipeline=true})
add("full pipeline CCXL",{entry("Hair",999,"hair","options:CCXL_999")},{option("Hair",0,"hair",manyChoices)},{fullPipeline=true})
add("CCXL many choices",{entry("Hair",999,"hair","options:CCXL_999")},{option("Hair",0,"hair",manyChoices)})
local uncachedChoices={};for i=0,runtime.OPTION_CHOICE_CACHE_LIMIT do uncachedChoices[#uncachedChoices+1]="large_"..i end
add("above choice cache limit",{entry("Eyes",2,"eyes","options:large_2")},{option("Eyes",0,"eyes",uncachedChoices)},{scanOnly=true})
local huge={};for i=1,presetCodec.MAX_PRESET_ENTRIES+1 do huge[i]=option("Large"..i,0,"slot"..i)end
add("oversized live snapshot",{entry("Large1",0,"slot1")},huge,{scanOnly=true})
local eyelashEntries,eyelashOptions={},{}
for i=1,48 do eyelashEntries[i]=entry("Modeled"..i,2);eyelashOptions[i]=option("Modeled"..i,2)end
eyelashEntries[49]=entry("LocKey#13879517178655718515",2,"eyelashes_options","options:UI-Customization-icxrus_softnaturaleyelashes")
eyelashEntries[50]=entry("LocKey#8824472266055663870",2,"eyelash_color")
add("Alina eyelash log identities",eyelashEntries,eyelashOptions)
add("archived unavailable identities",{entry("LocKey#7910919425215809506",101),entry("LocKey#7910918325704181295",101),entry("LocKey#7910917226192553084",101)},{option("Eyes",0,"eyes")},{format=4})
local expected
if not CPM_RECORD_STAGE7 then expected=require("modules/domain/stage7_fixtures")end
local results,allocations,reports={},{},{}
local function run(case)
 reset(case)
 if case.inactive then options[1].isActive=false end
 if case.notEditable then options[1].isEditable=false end
 if case.badField then options[1].info.throwField="definitions"end
 if case.format then preset.format=case.format end
 local comparison=runtime.comparePresetWithCurrent(preset,options)
 local savedCompare=runtime.compareSelectedPreset;runtime.compareSelectedPreset=nil
 runtime.refreshPreflight();runtime.compareSelectedPreset=savedCompare
 local preflight=clone(runtime.state.load.preflight)
 runtime.state.load.forceFull=case.force or false
 runtime.state.load.resetBefore=case.resetBefore or false
 runtime.helpers.bindOptionCatalog(options)
 local probes={}
 if options[1]then
  for _,index in ipairs({-1,0,2,3.5,4294967295,4294967296,"2",0/0})do
   probes[#probes+1]=pack(runtime.helpers.optionChoiceKey(options[1],index),runtime.optionChoiceMatchesIndex(options[1],"options:two",index))
  end
  for _,choice in ipairs({"unknown:two","options:","options:userdata: 0x123"})do probes[#probes+1]=pack(runtime.optionChoiceMatchesIndex(options[1],choice,2))end
  if case.cacheMutation then
   probes[#probes+1]=pack(runtime.optionChoiceIndex(options[1],"options:two"))
   if case.cacheMutation=="duplicate"then options[1].info.options[2].localizedName="two"
   else options[1].info.options[3].localizedName="other"end
   probes[#probes+1]=pack(runtime.optionChoiceIndex(options[1],"options:two"))
  end
 end
 local entries,terminal
 local release=runtime.helpers.releaseFinishedLoadWorkingData
 if case.fullPipeline then
  runtime.state.load.forceFullPresetName=case.name
  runtime.saveAppearanceHistorySnapshot=function()trace[#trace+1]={"history capture"};return true end
  runtime.helpers.releaseFinishedLoadWorkingData=function()
   local load=runtime.state.load
   terminal=clone({unconfirmed=load.unconfirmed,cleanup=load.cleanupSkipped,forced=load.forcedKeys,
    satisfied=load.satisfied,remaining=load.remaining,phase=load.phase,pass=load.pass})
   return release()
  end
  entries=pack(runtime.helpers.preparePresetEntries(preset))
 else entries=pack(runtime.beginLoadPass(preset,case.name))end
 local values,counts,ordered,slots,count,byKey=unpack(entries,1,6)
 if case.scanOnly then
  runtime.helpers.scanLoadOptions(options,counts,slots)
 else
  for pass=1,2000 do
   runtime.state.load.elapsed=(pass-1)*0.25
   if case.fullPipeline then
    runtime.state.app.optionsMemo=nil
    runtime.loadPreset()
   else
    runtime.state.load.pass=pass
    runtime.continueLoadPass(system,options,preset,values,counts,ordered,slots,count,byKey)
   end
   if not runtime.state.load.needsContinue or runtime.state.load.stalled then break end
   assert(pass<2000,"load did not terminate "..case.name)
  end
 end
 runtime.helpers.releaseFinishedLoadWorkingData=release
 local live={};for i,liveOption in ipairs(options)do live[i]={index=liveOption.currIndex,active=liveOption.isActive}end
 local load=runtime.state.load
 local summary={}
 for _,record in ipairs(trace)do if record[1]=="log"and record[2]:find("SUMMARY |",1,true)then summary[#summary+1]=record[2]end end
 return {terminal=terminal,probes=probes,comparison=comparison,preflight=preflight,entries=entries,live=live,trace=trace,reads=reads,readOrder=readOrder,calls=calls,
  summaries=summary,load={remaining=load.remaining,phase=load.phase,choiceStage=load.choiceStage,pass=load.pass,
  satisfied=load.satisfied,unconfirmed=load.unconfirmed,forced=load.forcedKeys,cleanup=load.cleanupSkipped,remaps=load.dependencyRemaps,
  resolved=load.resolvedChoiceIndexes,stalled=load.stalled,scanCalls=load.scanCalls,changes=load.structureChanges},
  cache={builds=runtime.state.app.optionCatalog.builds,hits=runtime.state.app.optionCatalog.hits}}
end
for i,case in ipairs(cases)do
 if CPM_TABLE_PROBE then CPM_TABLE_PROBE.count=0 end
 pureCalls={}
 local actual=run(case)
 local counts={}
 local summary=actual.summaries[#actual.summaries]
 if summary then for key,value in summary:gmatch("(%w+)=(%d+)")do counts[key]=value end end
 local publicTotal,pureTotal,writes=0,0,0
 for _,count in pairs(actual.calls)do publicTotal=publicTotal+count end
 for _,count in pairs(pureCalls)do pureTotal=pureTotal+count end
 for _,event in ipairs(actual.trace)do if event[1]=="write"then writes=writes+1 end end
 reports[i]={case.name,counts.applied or counts.processed or "not emitted",counts.unresolved or "not emitted",
  counts.forced or "not emitted",counts.cleanupUnconfirmed or "not emitted",summary and summary:match("result=([%w-]+)")or"not emitted",
  actual.load.remaining,actual.calls.scanLoadOptions or 0,actual.calls.resolveLoadChoice or 0,
  actual.calls.optionChoiceIndex or 0,writes,publicTotal,pureTotal,actual.cache.builds,actual.cache.hits}
 if CPM_TABLE_PROBE then
  allocations[i]={case.name,CPM_TABLE_PROBE.count}
  if expected then
   assert(expected.allocations and expected.allocations[i][1]==case.name
     and expected.allocations[i][2]==CPM_TABLE_PROBE.count,"table allocation count changed: "..case.name)
  end
 end
 results[i]={case.name,literal(actual)}
 if expected then assert(results[i][1]==expected[i][1]and results[i][2]==expected[i][2],"stage 7 mismatch: "..case.name)end
end
if CPM_RECORD_STAGE7 then
 if CPM_TABLE_PROBE then results.allocations=allocations end
 local file=assert(io.open(root.."modules/domain/stage7_fixtures.lua","wb"));file:write("return ",literal(results),"\n");file:close()
else assert(#expected==#results,"fixture count changed")end
if CPM_ALLOCATION_OUTPUT then
 local file=assert(io.open(CPM_ALLOCATION_OUTPUT,"wb"));file:write(literal(allocations));file:close()
end
if CPM_MATCHING_OUTPUT then
 local file=assert(io.open(CPM_MATCHING_OUTPUT,"wb"))
 for _,row in ipairs(reports)do for i,value in ipairs(row)do row[i]=tostring(value)end;file:write(table.concat(row,"\t"),"\n")end
 file:close()
end
print("Stage 7 baseline comparisons passed: "..#results.."; full ordering, game reads, cache counts, calls, and SUMMARY lines matched.")
