local moduleRoot = "source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/"
package.path = moduleRoot .. "?.lua;" .. package.path
require("modules/domain/stage6_sandbox").install(moduleRoot)
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
require("modules/bundles")
require("modules/backup")
require("modules/history")

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
    load = runtime.state.load, trash=runtime.state.trash, history=runtime.state.history, backup=runtime.state.backup, bulkSelected = runtime.state.trash.bulkSelected})
end

local stateModel = require("modules/domain/state")
local initialLibrary = clone(runtime.state.library)
local initialCache = clone(runtime.state.cache)
local initialStatus = clone(runtime.state.status)
local initialTrash=clone(runtime.state.trash)
local initialHistory=clone(runtime.state.history)
local initialBackup=clone(runtime.state.backup)
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
  runtime.state.trash=clone(initialTrash)
  runtime.state.history=clone(initialHistory)
  runtime.state.backup=clone(initialBackup)
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
local function upvalue(fn,wanted,visited)
  visited=visited or {};if visited[fn] then return end;visited[fn]=true
  for index=1,100 do
    local name,value=debug.getupvalue(fn,index)
    if not name then break end
    if name==wanted then return value end
    if type(value)=="function" then local found=upvalue(value,wanted,visited);if found then return found end end
  end
end
local inspectBundle=assert(upvalue(runtime.viewSelectedFolderBundleContents,"inspectFolderBundle"))
local importBundle=assert(upvalue(runtime.importAvailableFolderBundles,"importFolderBundle"))
local readBackup=assert(upvalue(runtime.importLibraryBackup,"readBackup"))
local readImported=assert(upvalue(runtime.importAvailableFolderBundles,"readImportedBundles"))
local sameAppearance=assert(upvalue(runtime.saveAppearanceHistorySnapshot,"sameAppearance"))
local cases={}
local function add(name,setup,fn,initial)
  cases[#cases+1]={name=name,setup=setup or function()seed(preset)end,fn=fn,initial=initial or baseFiles(preset)}
end
local oldContext=context
local limitNames={"MAX_PRESET_BYTES","MAX_FOLDER_BUNDLE_BYTES","MAX_FOLDER_BUNDLE_PRESETS","MAX_LIBRARY_BACKUP_BYTES","MAX_CATALOG_BYTES","MAX_CATALOG_LINES"}
local originalLimits={}
for _,name in ipairs(limitNames)do originalLimits[name]=runtime[name]end
context=function(initial)
  oldContext(initial)
  for name,value in pairs(originalLimits)do runtime[name]=value end
  runtime.state.load.recoverySnapshotAvailable=false
  runtime.loadPreset=function()trace[#trace+1]={"loadPreset"};runtime.state.load.needsContinue=true end
end
local codecBytes=require("modules/domain/codecs")
local bundlePath=runtime.PRESET_DIR.."/input.cpmfolder"
local backupPath=runtime.PRESET_DIR.."/input.cpmbackup"
local function bundleText(name,contents,root)
  return "CPMFOLDER\t1\nROOT\t"..codecBytes.catalogEncode(root or "Shared").."\nF\tNested\nP\t"..codecBytes.catalogEncode(name or "Nested/A").."\t"..codecBytes.hexEncode(contents or presetBytes(preset)).."\n"
end
local function backupText(name,contents)
  return "CPMBACKUP\t1\nCONFIG\t"..codecBytes.backupEncode("presetSort=modified\n").."\nF\tFolder\nP\t"..codecBytes.catalogEncode(name or "Folder/A").."\t"..codecBytes.backupEncode(contents or presetBytes(preset)).."\n"
end
local function withArchive(path,text)
  local initial=baseFiles(preset);initial[path]=text;return initial
end
add("export folder",nil,runtime.exportSelectedFolderBundle)
add("export selected",function()seed(preset);runtime.state.trash.bulkSelected["Folder/A"]=true;runtime.state.trash.bulkSelectionDirty=true end,runtime.exportSelectedBulkPresetBundle)
add("export backup",nil,runtime.exportLibraryBackup)
add("import bundle",nil,function()return importBundle(bundlePath,runtime.fileFingerprint(bundlePath,runtime.MAX_FOLDER_BUNDLE_BYTES),{})end,withArchive(bundlePath,bundleText()))
add("import bundle all",nil,runtime.importAvailableFolderBundles,withArchive(bundlePath,bundleText()))
add("import bundle collision",function()seed(preset);runtime.state.library.folders.Shared=true end,runtime.importAvailableFolderBundles,withArchive(bundlePath,bundleText()))
add("restore backup",function()seed(preset);runtime.state.backup.selectedFile=backupPath end,runtime.importLibraryBackup,withArchive(backupPath,backupText()))
add("delete backup request",function()seed(preset);runtime.state.backup.selectedFile=backupPath end,runtime.deleteSelectedLibraryBackup,withArchive(backupPath,backupText()))
add("delete backup confirmed",function()
  seed(preset);runtime.state.backup.selectedFile=backupPath
  runtime.state.backup.pendingDeleteFile=backupPath;runtime.state.backup.pendingDeleteFingerprint=runtime.fileFingerprint(backupPath,runtime.MAX_LIBRARY_BACKUP_BYTES)
end,runtime.deleteSelectedLibraryBackup,withArchive(backupPath,backupText()))
add("trash single request",nil,runtime.trashPreset)
add("trash single confirmed",function()
  seed(preset);runtime.state.trash.pendingDeleteName="Folder/A"
  runtime.state.trash.pendingDeleteFingerprint=runtime.fileFingerprint(runtime.PRESET_DIR.."/A.preset")
end,runtime.trashPreset)
add("trash bulk",function()seed(preset);runtime.requestBulkTrash({"Folder/A"},"Folder")end,function()return runtime.requestBulkTrash({"Folder/A"},"Folder")end)
local trashPath=runtime.TRASH_DIR.."/A.preset"
local function trashSetup()
  seed(preset);runtime.state.library.presets={}
  runtime.state.trash.items={["A.preset"]={original="Folder/A",group="group",preset=clone(preset)}}
  runtime.state.trash.groups={group={root="Folder",folders={Folder=true,["Folder/Nested"]=true},manualFolders={Folder=true}}}
end
add("restore single",trashSetup,function()return runtime.restoreTrashPreset("A.preset")end,{[trashPath]=presetBytes(preset)})
add("restore group",trashSetup,function()return runtime.restoreTrashGroup("group")end,{[trashPath]=presetBytes(preset)})
add("restore collision",function()trashSetup();runtime.state.library.presets["Folder/A"]=clone(preset)end,function()return runtime.restoreTrashGroup("group")end,{[trashPath]=presetBytes(preset),[runtime.PRESET_DIR.."/A.preset"]=presetBytes(preset)})
add("empty Trash request",trashSetup,runtime.emptyTrash,{[trashPath]=presetBytes(preset)})
add("empty Trash confirmed",function()trashSetup();runtime.state.trash.pendingEmpty=true end,runtime.emptyTrash,{[trashPath]=presetBytes(preset)})
add("trash bundle",function()seed(preset);runtime.state.library.selectedBundleFile="input.cpmfolder" end,runtime.trashSelectedFolderBundle,withArchive(bundlePath,bundleText()))
add("restore trashed bundle",function()seed(preset);runtime.state.trash.bundles["input.cpmfolder"]=true end,function()return runtime.restoreTrashBundle("input.cpmfolder")end,{[runtime.TRASH_DIR.."/input.cpmfolder"]=bundleText()})
for _,n in ipairs({0,2,5,8,11})do
  local initial=baseFiles(preset)
  for index=1,n do local model=clone(preset);model.entries[1].index=index;initial[runtime.HISTORY_FILE_PREFIX..index..".preset"]=presetBytes(model)end
  add("history refresh "..n,nil,runtime.refreshAppearanceHistory,initial)
  add("history trim "..n,nil,runtime.trimAppearanceHistory,initial)
  add("history save "..n,nil,function()return runtime.saveAppearanceHistorySnapshot({{key="Hair",currIndex=31,isEditable=true,isActive=true}},"Test history é猫")end,initial)
  add("history clear "..n,function()seed(preset);runtime.state.history.pendingClear=true end,function()return runtime.clearAppearanceHistory(true)end,initial)
end
add("history same appearance",nil,function()return sameAppearance(preset,clone(preset)),sameAppearance(preset,{entries={}})end)
add("history restore",nil,function()runtime.refreshAppearanceHistory();return runtime.restoreAppearanceHistory(1)end,{[runtime.HISTORY_FILE_PREFIX.."1.preset"]=presetBytes(preset)})
for _,text in ipairs({"","CPMFOLDER\t2\n",bundleText(),bundleText("é猫", "Hair:2\n","Legacy"),bundleText().."P\tNested/A\t4141\n",bundleText().."F\tnested\n",bundleText():sub(1,-8),"CPMFOLDER\t1\nROOT\tShared\n",bundleText():gsub("\n","\r\n")})do
  add("bundle inspect "..#cases,nil,function()return inspectBundle(bundlePath)end,withArchive(bundlePath,text))
  add("bundle install corpus "..#cases,nil,runtime.importAvailableFolderBundles,withArchive(bundlePath,text))
end
for _,text in ipairs({"","CPMBACKUP\t2\n",backupText(),backupText("é猫","Hair:2\n"),backupText().."P\tFolder/A\t4141\n",backupText():sub(1,-7),"CPMBACKUP\t1\nCONFIG\t\n",backupText():gsub("\n","\r\n"),"CPMBACKUP\t1\nCONFIG\tGG\nCONFIG\t\nP\tA\t486169723A320A\n"})do
  add("backup inspect "..#cases,nil,function()return readBackup(backupPath)end,withArchive(backupPath,text))
  add("backup restore corpus "..#cases,function()seed(preset);runtime.state.backup.selectedFile=backupPath end,runtime.importLibraryBackup,withArchive(backupPath,text))
end
for _,name in ipairs({"../evil","/absolute","C:/absolute","Nested/../evil","CON","NUL.txt","trailing.","Nested\\bad"})do
  add("bundle hostile "..name,nil,function()return inspectBundle(bundlePath)end,withArchive(bundlePath,bundleText(name)))
  add("backup hostile "..name,nil,function()return readBackup(backupPath)end,withArchive(backupPath,backupText(name)))
end
for _,limit in ipairs({"MAX_FOLDER_BUNDLE_BYTES","MAX_FOLDER_BUNDLE_PRESETS","MAX_PRESET_BYTES"})do
  add("bundle limit "..limit,function()seed(preset);runtime[limit]=1 end,function()return inspectBundle(bundlePath)end,withArchive(bundlePath,bundleText()))
end
for _,limit in ipairs({"MAX_LIBRARY_BACKUP_BYTES","MAX_PRESET_BYTES"})do
  add("backup limit "..limit,function()seed(preset);runtime[limit]=1 end,function()return readBackup(backupPath)end,withArchive(backupPath,backupText()))
end
for _,text in ipairs({"","B\tinput.cpmfolder\t1:2\n","B\tinput.cpmfolder\t1:2\tShared\n","B\tinput.cpmfolder\t2:1:2:3\tShared\n","bad\n"})do
  local initial=baseFiles(preset);initial[runtime.IMPORTED_BUNDLES_FILE]=text
  add("old import registry "..#cases,nil,readImported,initial)
end
for _,text in ipairs({"P\tA.preset\tFolder/A\t\n","G\tgroup\tFolder\nF\tgroup\tFolder\nM\tgroup\tFolder\nP\tA.preset\tFolder/A\tgroup\n","P\t../bad.preset\tA\t\n"})do
  add("old Trash catalog "..#cases,nil,function()return runtime.refreshTrash()end,{[trashPath]=presetBytes(preset),[runtime.TRASH_CATALOG_FILE]=text})
end
local second=clone(preset);second.storage="B";second.presetName="B";second.libraryFolder="Folder/Nested";second.entries[1].index=3
local many=baseFiles(preset);many[runtime.PRESET_DIR.."/B.preset"]=presetBytes(second)
local function seedMany()
  seed(preset);runtime.state.library.presets["Folder/Nested/B"]=clone(second)
end
add("trash bulk several",function()seedMany();runtime.requestBulkTrash({"Folder/A","Folder/Nested/B"},"Folder")end,function()return runtime.requestBulkTrash({"Folder/A","Folder/Nested/B"},"Folder")end,many)
local manyTrash={[trashPath]=presetBytes(preset),[runtime.TRASH_DIR.."/B.preset"]=presetBytes(second)}
local function setupManyTrash()
  trashSetup();runtime.state.trash.items["B.preset"]={original="Folder/Nested/B",group="group",preset=clone(second)}
end
add("restore group several",setupManyTrash,function()return runtime.restoreTrashGroup("group")end,manyTrash)
add("empty Trash several",function()setupManyTrash();runtime.state.trash.pendingEmpty=true end,runtime.emptyTrash,manyTrash)
add("empty group restore",function()trashSetup();runtime.state.trash.items={}end,function()return runtime.restoreTrashGroup("group")end,{})
add("bundle preset count limit",function()seed(preset);runtime.MAX_FOLDER_BUNDLE_PRESETS=1 end,function()return inspectBundle(bundlePath)end,withArchive(bundlePath,bundleText().."P\tB\t486169723A320A\n"))
add("skip legacy imported bundle",function()
  seed(preset);runtime.state.library.folders.Shared=true
  local _,legacyFingerprint=runtime.fileFingerprint(bundlePath,runtime.MAX_FOLDER_BUNDLE_BYTES)
  files[runtime.IMPORTED_BUNDLES_FILE]="B\tinput.cpmfolder\t"..legacyFingerprint.."\tShared\n"
end,runtime.importAvailableFolderBundles,withArchive(bundlePath,bundleText()))

local fixtures,failureRuns,interruptions={},{writes=0,rename=0,delete=0,other=0},0
local pairedRuns=0
local pairedCases={["restore backup"]=true,["import bundle"]=true,["trash bulk several"]=true,["restore group several"]=true,["history save 5"]=true,["empty Trash several"]=true}
local function record(name,value)fixtures[#fixtures+1]={name,value}end
local function runCase(case,fail,secondFailure)
  context(case.initial);case.setup();trace,logs,step={},{},0;failure=fail
  failures=secondFailure and {[secondFailure]=true}or nil
  return snapshot(case.fn)
end
local function isStep(kind)return kind~="log" and kind~="timestamp" and kind~="setStatus" and kind~="clearStatus" and kind~="cancelConfirmations" and kind~="resetLoadState" and kind~="loadPreset" end
local interruptedCases={["trash single confirmed"]=true,["trash bulk"]=true,["restore single"]=true,["restore group"]=true,["restore backup"]=true,["import bundle"]=true}
interruptedCases["trash bulk several"]=true
interruptedCases["restore group several"]=true
for _,case in ipairs(cases)do
  local successful=runCase(case)
  local model=assert(loadstring("return "..successful))()
  assert(model.returns[1],"operation threw: "..case.name.." "..tostring(model.returns[2]))
  record(case.name,successful)
  local total=step;local steps={}
  for _,entry in ipairs(trace)do if isStep(entry[1])then steps[#steps+1]=entry end end
  assert(#steps==total,"step accounting "..case.name)
  local branches={}
  for fail=1,total do
    record(case.name.." failure "..fail,runCase(case,fail))
    local k=steps[fail][1];local category=(k=="write" or k=="open" or k=="flush" or k=="close")and"writes"or k=="rename"and"rename"or k=="delete"and"delete"or"other"
    failureRuns[category]=failureRuns[category]+1
    if pairedCases[case.name]then
      local later,signature,ordinal={},{},0
      for _,entry in ipairs(trace)do
        if isStep(entry[1])then
          ordinal=ordinal+1
          if ordinal>fail and (entry[1]=="write"or entry[1]=="rename"or entry[1]=="delete")then later[#later+1]=ordinal;signature[#signature+1]=entry end
        end
      end
      local key=literal(signature)
      if not branches[key]then
        branches[key]=true
        for _,secondFailure in ipairs(later)do
          record(case.name.." paired "..fail.."/"..secondFailure,runCase(case,fail,secondFailure));pairedRuns=pairedRuns+1
        end
      end
    end
    if interruptedCases[case.name] and (k=="write" or k=="rename" or k=="delete" or k=="open")then
      context(case.initial);case.setup();trace,logs,step={},{},0;stopAfter=fail
      case.fn();assert(stoppedSnapshot,"interruption missed "..case.name.." "..fail)
      local stoppedFiles=clone(stoppedSnapshot)
      context(stoppedFiles)
      runtime.state.app.ready=false
      failure,stopAfter=nil,nil;trace,logs,step={},{},0
      record(case.name.." interruption "..fail,snapshot(function()
        local ok,originals,assignments,folders,manual=runtime.recoverTransaction()
        if ok then runtime.refreshPresets("startup",assignments,folders,manual);runtime.refreshTrash(originals)end
        return ok
      end));interruptions=interruptions+1
    end
  end
end

local fixturePath=moduleRoot.."modules/domain/stage6_fixtures.lua"
if CPM_RECORD_STAGE6 then
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
  print("Recorded original stage 6 fixtures: "..#fixtures)
else
  local expected=dofile(fixturePath)
  assert(#expected==#fixtures,"stage 6 fixture count changed")
  for index,entry in ipairs(fixtures)do
    assert(literal(entry)==literal(expected[index]),"stage 6 fixture mismatch "..index.." "..entry[1])
  end
  print("Stage 6 baseline comparisons passed: "..#fixtures)
end

print("Stage 6 injected failures: "..literal(failureRuns).."; interruption recoveries: "..interruptions)
print("Stage 6 paired failure cases: "..pairedRuns)
local function compareImported(original, imported)
  assert(literal(imported.entries)==literal(original.entries))
  for _,field in ipairs({"notes","tags","favorite","format","created","modified","presetName"})do
    assert(imported[field]==original[field],field)
  end
end
context(many);seedMany()
local originalLibrary=clone(runtime.state.library.presets)
runtime.exportSelectedFolderBundle()
local exported=runtime.PRESET_DIR.."/Character Preset Manager Folder - Folder.cpmfolder"
local importedRoot=assert(importBundle(exported,runtime.fileFingerprint(exported,runtime.MAX_FOLDER_BUNDLE_BYTES),{}))
for name,model in pairs(originalLibrary)do
  compareImported(model,assert(runtime.state.library.presets[importedRoot..name:sub(#"Folder"+1)]))
end
assert(runtime.state.library.folders[importedRoot.."/Nested"])
print("Folder round trip: both presets, entries and metadata identical; nested folder retained; collision root remapped.")
context(many);seedMany()
local originalLibrary=clone(runtime.state.library.presets)
assert(runtime.exportLibraryBackup())
local exportedBackup=runtime.PRESET_DIR.."/Character Preset Manager Library Backup.cpmbackup"
runtime.state.backup.selectedFile=exportedBackup
assert(runtime.importLibraryBackup())
for name,model in pairs(originalLibrary)do
  compareImported(model,assert(runtime.state.library.presets["Imported Library/"..name]))
end
assert(runtime.state.library.folders["Imported Library/Other"] and runtime.state.library.folders["Imported Library/Folder/Nested"])
print("Backup round trip: both presets, entries and metadata identical; nested/empty folders retained; collision root remapped.")
