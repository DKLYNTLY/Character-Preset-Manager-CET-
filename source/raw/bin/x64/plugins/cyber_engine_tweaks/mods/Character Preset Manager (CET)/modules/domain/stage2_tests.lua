local moduleRoot = "source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/"
package.path = moduleRoot .. "?.lua;" .. package.path
local originalRuntime = package.loaded["modules/runtime"]
local originalGlobals = {}
for key,value in pairs(_G) do originalGlobals[key]=value end
local presetCodec = require("modules/domain/preset_codec")
local configCodec = require("modules/domain/config_codec")
local jsonCodec = require("modules/domain/json")
assert(package.loaded["modules/runtime"] == originalRuntime, "codec loaded runtime")
for key,value in pairs(_G) do assert(originalGlobals[key]==value, "codec changed global "..tostring(key)) end
local runtime = require("modules/runtime")
require("modules/constants")
require("modules/state")
require("modules/filesystem")
require("modules/catalog")
require("modules/options")
require("modules/view_cache")
require("modules/presets")
local function literal(value)
  if type(value) == "string" then
    return '"' .. value:gsub('[%z\1-\31\127-\255\\"]', function(c) return string.format("\\%03d",c:byte()) end) .. '"'
  end
  if type(value) == "table" then
    local entries = {}
    for key, item in pairs(value) do entries[#entries+1] = "[" .. literal(key) .. "]=" .. literal(item) end
    table.sort(entries)
    return "{" .. table.concat(entries, ",") .. "}"
  end
  if value == nil then return "nil" end
  return tostring(value)
end
local function pack(...) return {n=select("#",...),...} end
local cases = {}
local function add(name, kind, text, model, options)
  cases[#cases+1] = {name=name,kind=kind,text=text,model=model,options=options or {}}
end
add("truncated entry", "preset", "Hair:2\nEyes:")
add("truncated identity", "preset", "# CPM Preset\n# Format: 8\nHair:2\n# Saved choice: options:")
add("empty", "preset", "")
add("blank", "preset", " \n\t\n")
add("ACU text", "preset", "Hair:2\nEyes:3\n")
add("duplicate keys", "preset", "Hair:2\nHair:3\n")
add("malformed salvage", "preset", "bad\nHair:2\nno index:x\n")
add("negative index", "preset", "Hair:-1\n")
add("index maximum", "preset", "Hair:4294967295\n")
add("index overflow", "preset", "Hair:4294967296\n")
add("key boundary", "preset", string.rep("k",256)..":0\n")
add("key overflow", "preset", string.rep("k",257)..":0\n")
for format=1,8 do
  local text = "# CPM Preset\n# CPM\tformat\t"..format.."\n# CPM\tsource\tOld%20source\n# CPM\tnotes\tNotes%0Atext\n# CPM\ttags\told%20tag\n# CPM\tfavorite\t1\n# CPM\tslot\thair\n# CPM\tchoice\toptions%3Ablue\nHair:2\n"
  add("legacy "..format,"preset",text)
  add("legacy metadata "..format,"preset",text,nil,{metadataOnly=true})
end
local readable = "# CPM Preset\n# Format: 8\n# Name: Test\n# Source: é猫\n# Created: today\n# Modified: later\n# Notes:  notes  \n# Tags: tag\n# Favorite: Yes\n# Library folder: sub/nested\nHair:2\n# Editor slot: hair\n# Saved choice: options:blue\nHair:3\n# Editor slot: hair2\n# Saved choice: definitions:other\n"
add("format 8","preset",readable)
add("format 8 metadata","preset",readable,nil,{metadataOnly=true})
add("CRLF","preset",readable:gsub("\n","\r\n"))
add("unmanaged readable","preset",readable:gsub("# CPM Preset\n",""))
add("future format","preset",readable:gsub("Format: 8","Format: 9"))
add("late format","preset","Hair:0\n# Format: 8\n# Notes: hidden\n")
add("invalid readable name","preset",readable:gsub("Name: Test","Name: CON"))
add("invalid folder","preset",readable:gsub("sub/nested","../bad"))
add("invalid choice","preset",readable:gsub("options:blue","options:table: 0x123"))
add("line limit","preset",string.rep("\n",runtime.MAX_PRESET_LINES).."Hair:0\n")
add("entry limit","preset",string.rep("Hair:0\n",runtime.MAX_PRESET_ENTRIES))
add("entry overflow","preset",string.rep("Hair:0\n",runtime.MAX_PRESET_ENTRIES+1))
add("malformed log cap","preset",string.rep("bad\n",23).."Hair:0\n")
add("UTF8 BOM","preset","\239\187\191Hair:0\n")
local json = {
  '{"options":[{"name":"Hair","value":2}]}',
  '{"values":[{"optionName":"Eyes","index":"3","isActive":true}],"isMaleVO":false}',
  '[{"key":"Hair","index":1},{"name":"Hair","value":2}]',
  '{"options":[{"name":"Hair","value":0,"is_active":false},{"name":"Eyes","value":1}]}',
  '{"options":[{"name":"Hair","value":-1}]}',
  '{"options":[{"name":"Hair","value":4294967296}]}',
  '{"options":[{"name":"Hair","value":null}]}',
  '{"options":[{"name":"Hair","value":0.5}]}',
  '{"options":[{"name":"\\u0041\\u732b\\uD83D\\uDE00","value":0}]}',
  '{"options":[{"name":"\\uD800","value":0}]}',
  '{"options":[{"name":"\\q","value":0}]}',
  '{"options":[{"name":"Hair","value":01}]}',
  '{"options":[{"name":"Hair","value":1.}]}',
  '{"options":[{"name":"Hair","value":1e2}]}',
  '{"options":[{"name":"Hair","value":0}]} junk',
  '{"options":[{"name":"Hair","value":0},]}',
  '{"options":[]}', '{}', '[null,true,false]', '{', '['
}
for index,text in ipairs(json) do
  add("JSON "..index,"preset",text)
  add("JSON metadata "..index,"preset",text,nil,{metadataOnly=true})
end
add("JSON nesting limit","preset",string.rep("[",18).."0"..string.rep("]",18))
for _,text in ipairs({"", "presetSort=name\n", "presetSort=modified\n", "presetSort=bad\n", "presetSort=modified\npresetSort=name\n", "# comment\n \t\npresetSort=MODIFIED\nunknown=1\n", "historySize=5\nnativePanel=on\nactivityLogDetail=all\n", "presetsort=name\npresetSort = modified\n", "presetSort=modified\r\n"}) do
  add("config "..#cases,"config",text)
end
add("missing preset","preset","Hair:0",nil,{missing=true})
add("missing config","config","",nil,{missing=true})
for _,kind in ipairs({"preset","config"}) do
  add(kind.." oversized",kind,"",nil,{size=runtime.MAX_PRESET_BYTES+1})
  add(kind.." seek failure",kind,"Hair:0",nil,{seekFailure=true})
  add(kind.." rewind failure",kind,"Hair:0",nil,{rewindFailure=true})
end
add("config byte boundary","config",string.rep(" ",16384))
add("config byte overflow","config",string.rep(" ",16385))
local model={format=8,source="é猫",presetName="Test",libraryFolder="sub/nested",created="today",modified="later",notes="line\nnotes",tags="tag",favorite=true,entries={{key="Hair",index=2,slot="hair",choice="options:blue"},{key="Hair",index=3}}}
add("write readable","write",nil,model)
add("write defaults","write",nil,{entries={{key="Hair",index=0}}})
add("write empty","write",nil,{})
add("write invalid folder","write",nil,{libraryFolder="../x",entries={{key="Hair",index=0}}})
add("write invalid index","write",nil,{entries={{key="Hair",index="bad"}}})
for index=1,21 do add("write failure "..index,"write",nil,model,{failWrite=index}) end
add("flush failure","write",nil,model,{flushFailure=true})
add("write open failure","write",nil,model,{missing=true})
for _,value in ipairs({"name","modified","bad",false}) do add("config write "..tostring(value),"configWrite",nil,{presetSort=value}) end

for _,mode in ipairs({"ok","throw"}) do
  add("Unicode encoder "..mode,"preset",'{"options":[{"name":"\\u0041\\u732b\\uD83D\\uDE00","value":0}]}',nil,{unicode=mode})
  add("unpaired surrogate "..mode,"preset",'{"options":[{"name":"\\uD800","value":0}]}',nil,{unicode=mode})
end
for _,token in ipairs({"null","true","false","0","-0","0.0","1e+2","1e-2","1e","+1",".5","01","1.","-1","4294967295","4294967296",'"2"','"bad"'}) do
  add("JSON value "..token,"preset",'{"options":[{"name":"Hair","value":'..token..'}]}')
end
for _,escaped in ipairs({'\\"','\\\\','\\/','\\b','\\f','\\n','\\r','\\t','\\u00','\\uZZZZ','\\u0000','\\uDC00','\\uD800\\u1234'}) do
  add("JSON escape "..escaped,"preset",'{"options":[{"name":"x'..escaped..'y","value":0}]}')
end
add("preset byte boundary","preset","Hair:0\n",nil,{size=runtime.MAX_PRESET_BYTES})
add("preset byte overflow","preset","Hair:0\n",nil,{size=runtime.MAX_PRESET_BYTES+1})
add("readable root folder","preset",readable:gsub("sub/nested","/"))
add("legacy control identity","preset","# CPM\tslot\tbad%00slot\n# CPM\tchoice\toptions%3Ax%0Ay\nHair:0\n")
add("empty JSON read","preset","{}",nil,{readFailure=true})
add("config write failure","configWrite",nil,{presetSort="name"},{failWrite=1})
add("config flush failure","configWrite",nil,{presetSort="name"},{flushFailure=true})
add("config missing writer","configWrite",nil,{presetSort="name"},{missing=true})

add("Unicode preset name","preset",readable:gsub("Name: Test","Name: é猫"))
add("write Unicode","write",nil,{format=8,presetName="é猫",notes="Unicode é猫",entries={{key="Hair",index=0,choice="options:猫"}}})
add("write duplicate identities","write",nil,{format=8,entries={{key="Hair",index=1,slot="hair",choice="options:same"},{key="Hair",index=2,slot="hair",choice="options:same"}}})
add("write field limits","write",nil,{format=8,presetName=string.rep("n",64),notes=string.rep("a",512),tags=string.rep("t",128),entries={{key=string.rep("k",256),index=4294967295,slot=string.rep("s",256),choice="options:"..string.rep("c",1000)}}})
local function run(case)
  local logs, writes, closed = {}, {}, 0
  local position, writeCount = 1,0
  local text = case.text or ""
  local options = case.options
  runtime.utf8 = nil
  if options.unicode == "ok" then
    runtime.utf8 = {char=function(codepoint) return "<"..tostring(codepoint)..">" end}
  elseif options.unicode == "throw" then
    runtime.utf8 = {char=function() error("Unicode conversion failed") end}
  end
  runtime.log = function(message,level) logs[#logs+1]={message,level} end
  runtime.io = {open=function(_,mode)
    if options.missing then return nil end
    if mode == "r" then text = text:gsub("\r\n","\n") end
    return {
      seek=function(_,where)
        if where=="end" then
          if options.seekFailure then error("seek failure",0) end
          position=#text+1; return options.size or #text
        end
        if options.rewindFailure then return nil end
        position=1; return 0
      end,
      read=function(_,count)
        if count=="*a" and options.readFailure then return nil end
        if count=="*a" then local rest=text:sub(position); position=#text+1; return rest end
        if position>#text then return nil end
        local part=text:sub(position,position+count-1);position=position+#part;return part
      end,
      lines=function()
        return function()
          if position>#text then return nil end
          local finish=text:find("\n",position,true)
          local line=text:sub(position,finish and finish-1 or #text)
          position=finish and finish+1 or #text+1
          return line
        end
      end,
      write=function(_,value)
        writeCount=writeCount+1
        if options.failWrite==writeCount then return nil end
        writes[#writes+1]=value;return true
      end,
      flush=function() if options.flushFailure then return nil end; return true end,
      close=function() closed=closed+1;return true end,
    }
  end}
  runtime.atomicReplace=function(path,writer) return writer(path..".tmp") end
  local result
  if case.kind=="preset" then result=pack(runtime.readPresetFile("fixture.preset",options.metadataOnly))
  elseif case.kind=="config" then result=pack(runtime.readConfig())
  elseif case.kind=="write" then result=pack(runtime.writePresetContents("fixture.preset",case.model))
  elseif case.kind=="configWrite" then runtime.state.preferences=case.model;result=pack(runtime.writeConfig()) end
  return {result=result,logs=logs,writes=writes,closed=closed}
end
local expected = require("modules/domain/stage2_fixtures")
for index,case in ipairs(cases) do
  local actual = literal(run(case))
  assert(actual == expected[index],case.name.." fixture "..index.." changed")
end
assert(#cases==#expected,"fixture count changed")
local roundTripCount = 0
for index,case in ipairs(cases) do
  if case.kind == "preset" then
    local before = case.text
    local read = run(case)
    assert(case.text == before and #read.writes == 0, case.name .. " changed during read")
    local preset = read.result[1]
    if preset and preset.entries then
      local rewritten = run({kind="write",model=preset,options={}})
      assert(literal(rewritten) == expected.roundTrips[index], case.name .. " writer round trip changed")
      roundTripCount = roundTripCount + 1
    end
  end
end
for index,contents in ipairs(expected.canonical) do
  local read = run({kind="preset",text=contents,options={}})
  assert(read.result[1], "canonical format 8 fixture rejected")
  local rewritten = run({kind="write",model=read.result[1],options={}})
  assert(table.concat(rewritten.writes) == contents, "canonical format 8 byte mismatch "..index)
end
local firstConfig = configCodec.decode("presetSort=modified\n")
local secondConfig = configCodec.decode("")
assert(firstConfig.presetSort == "modified" and secondConfig.presetSort == "name")
print("Stage 2 adapter fixtures passed: "..#cases)
print("Accepted preset write comparisons passed: "..roundTripCount)
print("Canonical format 8 byte-identical round trips passed: "..#expected.canonical)
print("Preset inputs unchanged after every read; independent config results passed.")
return {cases=cases,run=run,literal=literal}
