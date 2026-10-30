local root="source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/"
package.path=root.."?.lua;"..package.path
require("modules/domain/stage9_sandbox").install(root)
require("modules/constants")
local runtime=require("modules/runtime")
local productionGroupLimit=runtime.AUTO_LOAD_TIMING.maximumGroupChanges
CPM_STAGE8_GATE="modules/domain/stage9_sandbox"
local file=assert(io.open(root.."modules/domain/stage8_tests.lua","rb"))
local source=file:read("*a");file:close()
source=source:sub(1,assert(source:find("local expected",1,true))-1)
local harness=assert(loadstring(source.."return {run=run,cases=cases,literal=kit.literal}"))()
runtime.AUTO_LOAD_TIMING.maximumGroupChanges=productionGroupLimit
local baseline=require("modules/domain/stage8_fixtures")
assert(#harness.cases==#baseline)
for index,case in ipairs(harness.cases)do
 local previous=assert(loadstring("return "..baseline[index][2]))()
 local current=harness.run(case)
 for _,field in ipairs({"indices","auto","needsContinue","cameraBlocked","nativeBusy","derivedBusy","remaining","ready","scanRetained"})do
  assert(harness.literal(previous.final[field])==harness.literal(current.final[field]),case.name.." final "..field.." changed")
 end
 assert(previous.final.status.error==current.final.status.error,case.name.." error classification changed")
 local function summaries(trace)
  local result={}
  for _,item in ipairs(trace)do
   if item[1]=="log"and item[2]:find("SUMMARY |",1,true)then
    local counts={}
    for key,value in item[2]:gmatch("(%w+)=([%w%-]+)")do if key~="passes"then counts[key]=value end end
    result[#result+1]=counts
   end
  end
  return result
 end
 assert(harness.literal(summaries(previous.trace))==harness.literal(summaries(current.trace)),case.name.." SUMMARY classification/counts changed")
end
print("Part B: all 46 current-budget loader scenarios retain baseline final choices, terminal flags, busy/camera release, error classification and cache retention.")
