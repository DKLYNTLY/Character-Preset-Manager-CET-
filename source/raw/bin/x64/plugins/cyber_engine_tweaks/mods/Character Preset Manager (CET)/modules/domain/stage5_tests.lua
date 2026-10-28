local moduleRoot = "source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/"
package.path = moduleRoot .. "?.lua;" .. package.path
require("modules/domain/stage5_sandbox").install(moduleRoot)
local runtime = require("modules/runtime")
require("modules/constants")
require("modules/state")
require("modules/filesystem")
require("modules/catalog")
require("modules/presets")
require("modules/trash")
require("modules/folders")
require("modules/view_cache")
require("modules/options")
require("modules/native_bridge")

local function literal(value)
  if type(value) == "string" then
    return '"' .. value:gsub('[%z\1-\31\127-\255\\"]', function(c)
      return string.format("\\%03d", c:byte())
    end) .. '"'
  end
  if type(value) == "table" then
    local entries = {}
    for key, item in pairs(value) do entries[#entries + 1] = "[" .. literal(key) .. "]=" .. literal(item) end
    table.sort(entries)
    return "{" .. table.concat(entries, ",") .. "}"
  end
  if value == nil then return "nil" end
  return tostring(value)
end

local function pack(...) return {n = select("#", ...), ...} end
local function clone(t)
  if type(t) ~= "table" then return t end
  local result = {}
  for k, v in pairs(t) do result[k] = clone(v) end
  return result
end
local logs, files, trace, failure, stopAfter, step, windows, failures, stoppedSnapshot
local function event(kind, ...)
  step = step + 1
  trace[#trace + 1] = {kind, ...}
  if (failures or {})[step] == "throw" then error("injected " .. kind, 0) end
  if failure == step or (failures or {})[step] then return false end
  return true
end
local function after()
  if stopAfter == step then stoppedSnapshot = clone(files) end
end
local function fakeOpen(path, mode)
  local ok = event("open", path, mode)
  if not ok or (mode:sub(1, 1) == "r" and files[path] == nil) then after(); return nil, "open failed" end
  if mode:sub(1, 1) == "w" then files[path] = "" end
  local position = 0
  local handle = {}
  function handle:seek(whence, offset)
    local success = event("seek", path, whence, offset)
    if not success then after(); return nil, "seek failed" end
    position = whence == "end" and #files[path] or (offset or 0)
    after(); return position
  end
  function handle:read(amount)
    local success = event("read", path, amount)
    if not success then after(); return nil, "read failed" end
    local text = files[path] or ""
    if amount == "*a" then
      local result = text:sub(position + 1); position = #text; after(); return result
    end
    if position >= #text then after(); return nil end
    local result = text:sub(position + 1, position + amount)
    position = position + #result; after(); return result
  end
  function handle:lines()
    return function()
      local success = event("line", path)
      if not success then return nil end
      local contents = files[path] or ""
      if position >= #contents then return nil end
      local ending = contents:find("\n", position + 1, true)
      local line = contents:sub(position + 1, ending and ending - 1 or #contents)
      position = ending or #contents
      return line
    end
  end
  function handle:write(...)
    local contents = table.concat({...})
    local success = event("write", path, contents)
    if not success then after(); return nil, "write failed" end
    files[path] = (files[path] or ""):sub(1, position) .. contents
    position = position + #contents; after(); return self
  end
  function handle:flush()
    local success = event("flush", path); after()
    if success then return true end
    return nil, "flush failed"
  end
  function handle:close()
    local success = event("close", path); after()
    if success then return true end
    return nil, "close failed"
  end
  after(); return handle
end
local function fakeRename(source, destination)
  local success = event("rename", source, destination)
  if not success or not files[source] or (windows and files[destination] ~= nil) then
    after(); return nil, "rename failed"
  end
  files[destination], files[source] = files[source], nil
  after(); return true
end
local function fakeRemove(path)
  local success = event("delete", path)
  if not success or files[path] == nil then after(); return nil, "delete failed" end
  files[path] = nil; after(); return true
end
local function reset(initial, fail, stop, replacement, extraFailures)
  files, trace, logs = clone(initial or {}), {}, {}
  step, failure, stopAfter, windows, failures = 0, fail, stop, replacement ~= false, extraFailures
  stoppedSnapshot = nil
  runtime.io = {open = fakeOpen}
  runtime.os = {rename = fakeRename, remove = fakeRemove}
  runtime.log = function(message, level)
    logs[#logs + 1] = {message, level}
    trace[#trace + 1] = {"log", message, level}
  end
  runtime.state.trash.groups = {}
end
for _, name in ipairs({"resetLoadState", "cancelConfirmations", "setStatus", "clearStatus"}) do
  local original = runtime[name]
  runtime[name] = function(...)
    trace[#trace + 1] = {name, ...}
    return original(...)
  end
end
local function snapshot(fn)
  local result = pack(pcall(fn))
  if result[1] == false then
    result[2] = tostring(result[2]):gsub("^.-:%d+: ", "")
  end
  return literal({returns = result, files = files, trace = trace, logs = logs,
    library = runtime.state.library, cache = runtime.state.cache, status = runtime.state.status,
    load = runtime.state.load, bulkSelected = runtime.state.trash.bulkSelected})
end

local stateModel = require("modules/domain/state")
local initialLibrary = clone(runtime.state.library)
local initialCache = clone(runtime.state.cache)
local initialStatus = clone(runtime.state.status)
local function orderedPairs(items)
  local keys = {}
  for key in pairs(items) do keys[#keys+1] = key end
  table.sort(keys, function(a,b) return tostring(a) < tostring(b) end)
  local index = 0
  return function()
    index = index + 1
    local key = keys[index]
    if key ~= nil then return key, items[key] end
  end
end
local function context(initial)
  reset(initial)
  runtime.pairs = orderedPairs
  runtime.state.library = clone(initialLibrary)
  runtime.state.cache = clone(initialCache)
  runtime.state.status = clone(initialStatus)
  runtime.state.preferences = {presetSort="name"}
  runtime.state.load = stateModel.newLoad(runtime.AUTO_LOAD_TIMING.passInterval)
  runtime.state.app.ready = true
  runtime.state.trash.bulkSelected = {}
  runtime.state.trash.pendingEmpty = false
  runtime.state.backup.pendingDeleteFile = nil
  runtime.state.history.pendingClear = false
  runtime.state.invalidatePreflight = function() stateModel.invalidatePreflight(runtime.state.load) end
  runtime.state.invalidateTrashViewCache = function() runtime.state.trash.viewDirty = true end
  runtime.logTimestamp = function()
    trace[#trace+1]={"timestamp",literal(runtime.state.library.presets)}
    return "2026-10-27 12:34:56"
  end
  runtime.verifiedNativeFileCatalog = function() return nil end
  runtime.dir = function(path)
    local success = event("list",path)
    if not success then return nil end
    local entries, used = {}, {}
    for file in pairs(files) do
      if file:sub(1,#path+1) == path.."/" then
        local rest=file:sub(#path+2)
        local child=rest:match("^([^/]+)/")
        local name=child or rest
        if not used[name] then
          used[name]=true
          entries[#entries+1]={name=name,type=child and "directory" or "file"}
        end
      end
    end
    table.sort(entries,function(a,b) return a.name:lower()<b.name:lower() end)
    return entries
  end
  runtime.getOptions = function()
    return true, {{key="Hair",currIndex=2,isEditable=true,isActive=true}}
  end
  runtime.optionKey = function(option) return option.key end
  runtime.optionSlot = function() return "hair" end
  runtime.helpers.optionChoiceKey = function() return "options:hair" end
  runtime.optionAuditIdentity = function(_,key,index) return key.."#"..index end
end
local preset = {
  format=8, source="Character Preset Manager (CET)", created="2026-01-01 00:00:00",
  modified="2026-01-02 00:00:00", notes="old notes",tags="old tag",favorite=false,
  managedByCpm=true,presetName="A",libraryFolder="Folder",storage="A",
  entries={{key="Hair",index=2,slot="hair",choice="options:hair"}},entryCount=1,
}
local codec=require("modules/domain/preset_codec")
local function presetBytes(model)
  local _,chunks=codec.encode(model,runtime.MOD_NAME)
  return table.concat(chunks)
end
local function baseFiles(model)
  return {[runtime.PRESET_DIR.."/"..model.storage..".preset"]=presetBytes(model)}
end
local function seed(model)
  runtime.state.library.presets["Folder/A"]=clone(model)
  runtime.state.library.selected="Folder/A"
  runtime.state.library.selectedFolder="Folder"
  runtime.state.library.folders={Folder=true,["Folder/Nested"]=true,Other=true}
  runtime.state.library.presetNotes="  new\nnotes é猫  "
  runtime.state.library.presetTags="  new\ttag  "
  runtime.state.library.folderName="Created"
  runtime.state.library.folderRenameName="Renamed"
  runtime.state.library.renameName="Renamed"
  runtime.state.library.newName="New"
  runtime.state.cache.viewDirty=true
end
local cases={}
local function add(name,setup,operation,initial)
  cases[#cases+1]={name=name,setup=setup or function()end,fn=operation,initial=initial or baseFiles(preset)}
end
local function setup() seed(preset) end
add("save",setup,function() return runtime.savePreset(false) end)
add("overwrite request",function() setup();runtime.state.library.newName="A" end,function() return runtime.savePreset(false) end)
add("overwrite confirmed",function()
  setup();runtime.state.library.newName="A";runtime.state.library.pendingOverwriteName="Folder/A"
  runtime.state.library.pendingOverwriteFingerprint=runtime.fileFingerprint(runtime.PRESET_DIR.."/A.preset")
end,function() return runtime.savePreset(true) end)
add("overwrite changed",function()
  setup();runtime.state.library.newName="A";runtime.state.library.pendingOverwriteName="Folder/A"
  runtime.state.library.pendingOverwriteFingerprint="changed"
end,function() return runtime.savePreset(true) end)
add("metadata",setup,runtime.savePresetMetadata)
add("favorite add",setup,runtime.toggleSelectedPresetFavorite)
add("favorite remove",function()setup();runtime.state.library.presets["Folder/A"].favorite=true end,runtime.toggleSelectedPresetFavorite)
add("rename preset",setup,runtime.renamePreset)
add("move preset",function()setup();runtime.state.library.selectedFolder="Other" end,runtime.movePresetToSelectedFolder)
add("duplicate preset",setup,runtime.duplicatePreset)
add("create folder",setup,runtime.createFolder)
add("rename folder",setup,runtime.renameFolder)
add("duplicate folder",setup,runtime.duplicateFolder)
add("remove folder request",setup,runtime.removeVirtualFolder)
add("remove folder confirmed",function()setup();runtime.state.library.pendingRemoveFolder="Folder" end,runtime.removeVirtualFolder)
add("bulk move",function()setup();runtime.state.trash.bulkSelected["Folder/A"]=true;runtime.state.trash.bulkSelectionDirty=true;runtime.state.trash.bulkTargetFolder="Other" end,runtime.moveSelectedBulkPresetsToFolder)
local physical=clone(preset);physical.storage="Folder/A"
add("remove imported folder",function()seed(physical);runtime.state.library.manualFolders.Folder=true;runtime.state.library.pendingRemoveFolder="Folder" end,runtime.removeVirtualFolder,baseFiles(physical))
local legacy=clone(preset);legacy.format=4;legacy.managedByCpm=false;legacy.created=nil;legacy.notes=nil;legacy.tags=nil
for _,action in ipairs({"metadata","favorite","duplicate","move"}) do
  local fn=action=="metadata" and runtime.savePresetMetadata or action=="favorite" and runtime.toggleSelectedPresetFavorite or action=="duplicate" and runtime.duplicatePreset or runtime.movePresetToSelectedFolder
  add("legacy "..action,function()seed(legacy);runtime.state.library.selectedFolder="Other" end,fn,baseFiles(legacy))
end
for _,name in ipairs({"a","A","Renamed","CON","NUL.txt","name.","name ","é猫","..","a/b",string.rep("é",33)}) do
  add("rename target "..name,function()setup();runtime.state.library.renameName=name end,runtime.renamePreset)
  add("folder target "..name,function()setup();runtime.state.library.folderRenameName=name end,runtime.renameFolder)
end
add("case collision save",function()setup();runtime.state.library.newName="a" end,function() return runtime.savePreset(false) end)
add("preset duplicate collision",function()setup();runtime.state.library.presets["Folder/A Copy"]={storage="taken"} end,runtime.duplicatePreset)
add("folder duplicate collision",function()setup();runtime.state.library.folders["Folder Copy"]=true end,runtime.duplicateFolder)
add("move collision",function()setup();runtime.state.library.selectedFolder="Other";runtime.state.library.presets["Other/a"]={storage="taken"} end,runtime.movePresetToSelectedFolder)
add("rename folder collision",function()setup();runtime.state.library.folders["renamed"]=true end,runtime.renameFolder)
add("create folder collision",function()setup();runtime.state.library.folders["Folder/created"]=true end,runtime.createFolder)
for _,mode in ipairs({"name","modified","invalid"}) do
  add("sort preference "..mode,setup,function()return runtime.setPresetSortPreference(mode),runtime.readConfig()end)
  for _,query in ipairs({""," a ","TAG","notes","Folder","猫","missing"}) do
    add("view "..mode.." "..query,function()
      setup();runtime.state.library.sortMode=mode;runtime.state.library.searchText=query
      runtime.state.library.presets["Other/z"]={tags="猫",modified="bad",notes="notes"}
      runtime.state.library.presets["Other/B"]={tags="tag",modified="2026-12-31 23:59:59"}
      runtime.state.library.presets["Folder/Nested/b"]={tags="tag",modified="2026-12-31 23:59:59"}
    end,function()return runtime.helpers.sortedPresetNames(),runtime.sortedFolderNames(),runtime.helpers.filteredPresetNames(),runtime.helpers.presetsInFolder("Folder") end)
  end
end
for _,text in ipairs({"","P\tA\tFolder/A\nF\tFolder\nX\tIgnored\n","P\tA\tFirst\nP\tA\tSecond\n",
    "F\tCON\n","F\t../bad\n","unknown\n"," \n\n","P\tA\tFolder/A\r\n","F:Old\n",
    "P\tA\tFolder/A\nF\tFolder/Nested\n","P\tA\tFolder/A\nP\tB\tfolder/a\n"}) do
  local initial=baseFiles(preset);initial[runtime.CATALOG_FILE]=text
  add("catalog read "..#cases,setup,runtime.helpers.readCatalog,initial)
  add("scan catalog "..#cases,setup,function()return runtime.refreshPresets("external")end,initial)
end
for _,text in ipairs({"","P:Folder/A\nF:Folder\n","P2\tFolder/A\t1\t8\t2026-01-02%2000%3A00%3A00\t-\nF:Folder\n",
    "P2\tFolder/A\t-\t-\t\t-\n","P:CON\n","P:../bad\n","invalid\n","P2\tA\t99999999\t8\t\t-\n"}) do
  local initial=baseFiles(preset);initial[runtime.INVENTORY_FILE]=text
  add("inventory read "..#cases,setup,runtime.helpers.readInventory,initial)
  add("startup inventory "..#cases,setup,function()return runtime.refreshPresets("startup")end,initial)
end
add("catalog write",function()setup();runtime.state.library.ignoredPhysicalFolders.Ignored=true;runtime.state.library.manualFolders.Folder=true end,function()
  local l=runtime.state.library;return runtime.writeCatalog(l.presets,l.folders,l.manualFolders,l.ignoredPhysicalFolders),runtime.writeInventory(l.presets,l.folders)
end)
add("header nochange",setup,function()return runtime.state.updatePresetLibraryFolder(runtime.state.library.presets["Folder/A"],"Folder/A")end)
add("header change",setup,function()return runtime.state.updatePresetLibraryFolder(runtime.state.library.presets["Folder/A"],"Other/Renamed")end)
add("oversized metadata",function()setup();runtime.state.library.presetNotes=string.rep("é",300);runtime.state.library.presetTags=string.rep("猫",60)end,runtime.savePresetMetadata)
add("nested rename folder",function()
  setup();runtime.state.library.selectedFolder="Folder/Nested"
  runtime.state.library.presets["Folder/Nested/A"]=runtime.state.library.presets["Folder/A"]
  runtime.state.library.presets["Folder/A"]=nil;runtime.state.library.selected="Folder/Nested/A"
  runtime.state.library.manualFolders["Folder/Nested"]=true
end,runtime.renameFolder)
local second=clone(preset);second.storage="B";second.presetName="a"
local both=baseFiles(preset);both[runtime.PRESET_DIR.."/B.preset"]=presetBytes(second)
add("scan duplicate identities",setup,function()return runtime.refreshPresets("external")end,both)
add("duplicate storage identities",function()
  setup();runtime.state.library.presets["Other/A"]=clone(preset)
end,function()return runtime.persistVirtualState(runtime.state.library.presets,runtime.state.library.folders,{}, {})end)
add("empty selection",function()setup();runtime.state.library.selected=nil end,function()return runtime.toggleSelectedPresetFavorite(),runtime.savePresetMetadata(),runtime.renamePreset(),runtime.duplicatePreset()end)

local fixtures,failuresRun={},{writes=0,rename=0,delete=0,other=0}
local pairedRuns=0
local pairedOperations={
  save=true,["overwrite confirmed"]=true,metadata=true,["favorite add"]=true,["rename preset"]=true,
  ["move preset"]=true,["duplicate preset"]=true,["create folder"]=true,["rename folder"]=true,
  ["duplicate folder"]=true,["remove folder confirmed"]=true,["remove imported folder"]=true,["bulk move"]=true,
}
local function record(name,value)fixtures[#fixtures+1]={name,value}end
local function runCase(case,fail,secondFailure)
  context(case.initial);case.setup();trace,logs,step={},{},0;failure=fail
  failures=secondFailure and {[secondFailure]=true} or nil
  return snapshot(case.fn)
end
for _,case in ipairs(cases) do
  local success=runCase(case)
  local result=assert(loadstring("return "..success))()
  assert(result.returns[1],"baseline operation errored: "..case.name.." "..tostring(result.returns[2]))
  record(case.name,success)
  local steps={};local index=0
  for _,entry in ipairs(trace) do
    if entry[1]~="log" and entry[1]~="resetLoadState" and entry[1]~="cancelConfirmations" and entry[1]~="setStatus" and entry[1]~="clearStatus" and entry[1]~="timestamp" then
      index=index+1;steps[index]=entry[1]
    end
  end
  assert(index==step,"trace step count differs: "..case.name)
  local branches={}
  for failing=1,step do
    local kind=steps[failing]
    record(case.name.." failure "..failing,runCase(case,failing))
    local category=(kind=="write" or kind=="open" or kind=="flush" or kind=="close") and "writes" or kind=="rename" and "rename" or kind=="delete" and "delete" or "other"
    failuresRun[category]=failuresRun[category]+1
    if pairedOperations[case.name] then
      local later,signature={},{}
      local ordinal=0
      for _,entry in ipairs(trace)do
        if entry[1]~="log" and entry[1]~="resetLoadState" and entry[1]~="cancelConfirmations" and entry[1]~="setStatus" and entry[1]~="clearStatus" and entry[1]~="timestamp" then
          ordinal=ordinal+1
          if ordinal>failing and (entry[1]=="write" or entry[1]=="rename" or entry[1]=="delete") then
            later[#later+1]=ordinal;signature[#signature+1]=entry
          end
        end
      end
      local key=literal(signature)
      if not branches[key] then
        branches[key]=true
        for _,second in ipairs(later)do
          record(case.name.." paired failure "..failing.."/"..second,runCase(case,failing,second))
          pairedRuns=pairedRuns+1
        end
      end
    end
  end
end
local fixturePath=moduleRoot.."modules/domain/stage5_fixtures.lua"
if CPM_RECORD_STAGE5 then
  local file=assert(io.open(fixturePath,"wb"))
  assert(file:write([=[local function literal(value)
  if type(value) == "string" then
    return '"' .. value:gsub('[%z\1-\31\127-\255\\"]', function(c)
      return string.format("\\%03d", c:byte())
    end) .. '"'
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
local pool = {}
]=]))
  local pool, definitions = {}, {}
  local function pooled(value)
    local key=literal(value)
    if type(value)~="table" and (type(value)~="string" or #key<80) then return key end
    if pool[key] then return "pool["..pool[key].."]" end
    local expression=key
    if type(value)=="table" then
      local keys,parts={},{}
      for k in pairs(value)do keys[#keys+1]=k end
      table.sort(keys,function(a,b)return literal(a)<literal(b)end)
      for _,k in ipairs(keys)do parts[#parts+1]="["..literal(k).."]="..pooled(value[k])end
      expression="{"..table.concat(parts,",").."}"
    end
    local index=#definitions+1
    pool[key]=index;definitions[index]="pool["..index.."]="..expression.."\n"
    return "pool["..index.."]"
  end
  local rows={}
  for _,entry in ipairs(fixtures)do
    local model=assert(loadstring("return "..entry[2]))()
    rows[#rows+1]="  {"..literal(entry[1])..",literal("..pooled(model)..")},\n"
  end
  for _,line in ipairs(definitions)do assert(file:write(line))end
  assert(file:write("return {\n"))
  for _,line in ipairs(rows)do assert(file:write(line))end
  assert(file:write("}\n"));assert(file:close())
  print("Recorded original stage 5 fixtures: "..#fixtures)
else
  local expected=dofile(fixturePath)
  assert(#expected==#fixtures,"stage 5 fixture count changed")
  for index,entry in ipairs(fixtures)do
    assert(literal(entry)==literal(expected[index]),"stage 5 fixture mismatch "..index.." "..entry[1])
  end
  print("Stage 5 baseline comparisons passed: "..#fixtures)
end
print("Failure injection counts: "..literal(failuresRun))
print("Paired mutation/rollback failure cases: "..pairedRuns)
if not CPM_RECORD_STAGE5 then
  local model=require("modules/domain/library")
  local folderModel=require("modules/domain/folders")
  local source=clone(preset)
  local change=model.headerChange(source,"Other/New",8)
  assert(change.preset==source,"header change lost original preset identity")
  local library={presets={["Folder/A"]=source},folders={Folder=true},manualFolders={},ignoredPhysicalFolders={}}
  local mapped,folders=folderModel.renameContents(library,"Folder","Other")
  assert(mapped["Other/A"]==source and library.presets["Folder/A"]==source and library.folders.Folder)
  assert(folders.Other and not folders.Folder)
  local entries={{key="Hair",index=2}}
  assert(model.newSavedPreset(nil,entries,"A","A","created","modified",8,"CPM").entries==entries)
  print("Preset identity, map ownership, and retained entry references passed.")
end
