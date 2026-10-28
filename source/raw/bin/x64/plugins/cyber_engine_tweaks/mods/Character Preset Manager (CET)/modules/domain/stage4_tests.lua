local moduleRoot = "source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/"
package.path = moduleRoot .. "?.lua;" .. package.path
local originalCoroutine = coroutine
coroutine = nil
if not CPM_RECORD_STAGE4 then
  local originalRuntime = package.loaded["modules/runtime"]
  local originalGlobals = {}
  for key, value in pairs(_G) do originalGlobals[key] = value end
  for _, name in ipairs({"domain/journal_codec", "domain/trash_codec", "application/storage", "application/recovery", "adapters/files"}) do
    assert(type(require("modules/" .. name)) == "table", "module did not return a table: " .. name)
  end
  assert(package.loaded["modules/runtime"] == originalRuntime, "storage modules loaded the shared runtime")
  for key, value in pairs(_G) do assert(originalGlobals[key] == value, "storage modules wrote global " .. key) end
end
local runtime = require("modules/runtime")
require("modules/constants")
require("modules/state")
require("modules/filesystem")
require("modules/catalog")
require("modules/presets")
require("modules/trash")
require("modules/folders")
require("modules/view_cache")

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
local function upvalue(fn, wanted, visited)
  visited = visited or {}
  if visited[fn] then return end
  visited[fn] = true
  for i = 1, 100 do
    local name, value = debug.getupvalue(fn, i)
    if not name then break end
    if name == wanted then return value end
    if type(value) == "function" then
      local found = upvalue(value, wanted, visited)
      if found then return found end
    end
  end
end
local writeTrashCatalog = assert(upvalue(runtime.refreshTrash, "writeTrashCatalog"))
local readTrashCatalog = assert(upvalue(runtime.refreshTrash, "readTrashCatalog"))
local readTransaction = assert(upvalue(runtime.recoverTransaction, "readTransaction"))
local trashCatalogLines = assert(upvalue(writeTrashCatalog, "trashCatalogLines"))
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
  return literal({returns = result, files = files, trace = trace, logs = logs})
end
local cases = {}
local function add(name, initial, fn, replacement, extraFailures)
  cases[#cases + 1] = {name = name, initial = initial, fn = fn, windows = replacement, failures = extraFailures}
end
local function writeBytes(path)
  return runtime.writeFileSafely(path, "wb", function(file)
    return file:write("new\000é\n") ~= nil and file:flush() ~= nil
  end)
end
for _, initial in ipairs({{}, {target = "old"}, {["target.bak"] = "backup"},
    {target = "old", ["target.tmp"] = "leftover", ["target.bak"] = "stale"},
    {["target.tmp"] = "leftover"}}) do
  for _, replacement in ipairs({true, false}) do
    add("atomic " .. #cases, initial, function() return runtime.atomicReplace("target", writeBytes, "fixture") end, replacement)
  end
end
add("safe writer", {}, function() return writeBytes("target") end)
add("exists", {target = "old"}, function() return runtime.fileExists("target") end)
add("exists missing", {}, function() return runtime.fileExists("target") end)
add("writer false", {}, function() return runtime.writeFileSafely("target", "wb", function() return false end) end)
add("writer nil", {}, function() return runtime.writeFileSafely("target", "wb", function() end) end)
add("writer throw", {}, function() return runtime.writeFileSafely("target", "wb", function() error("writer failure") end) end)
add("bounded", {target = "old\000é\n"}, function() return runtime.readBoundedFile("target", 16) end)
add("bounded missing", {}, function() return runtime.readBoundedFile("target", 16) end)
add("bounded oversized", {target = "12345"}, function() return runtime.readBoundedFile("target", 4) end)
add("fingerprint", {target = "old\000é\n"}, function() return runtime.fileFingerprint("target", 16) end)
add("copy", {source = "old\000é\n", destination = "previous"}, function() return runtime.copyFile("source", "destination") end)
add("copy chunks", {source = string.rep("x", runtime.FILE_COPY_CHUNK_SIZE + 1)}, function() return runtime.copyFile("source", "destination") end)
add("remove list", {a = "A", b = "B"}, function() return runtime.removeFileList({"a", "missing", "b"}) end)
add("rename primitive", {a = "A", b = "B"}, function() return (runtime.renameFile or runtime.os.rename)("a", "b") end, false)
add("delete primitive", {a = "A"}, function() return (runtime.deleteFile or runtime.os.remove)("a") end)
for _, entries in ipairs({{}, {{name="child",type="directory"}}, {{name="file",type="file"}},
    {{name="..",type="directory"}}, {{name="a/b",type="file"}}, {{name="bad",type="unknown"}}, {"bad"}}) do
  add("directory " .. #cases, {root="",["root/child"]=""}, function()
    runtime.dir = function(path)
      local success = event("list", path); after()
      if not success then return nil end
      return path == "root" and entries or {}
    end
    return pack(runtime.safeDirectoryEntries("root", 0)), runtime.directoryTreeContainsFiles("root",0),
      runtime.removeEmptyDirectoryTree("root",0)
  end)
end
add("directory depth", {}, function() return runtime.safeDirectoryEntries("root", runtime.MAX_TREE_DEPTH + 1) end)
add("lines write", {target = "previous"}, function() return runtime.writeLinesIfChanged("target", {"a", "é"}, "lines", 40) end)
add("lines equal", {target = "a\né\n"}, function() return runtime.writeLinesIfChanged("target", {"a", "é"}, "lines", 40) end)
add("lines oversized", {}, function() return runtime.writeLinesIfChanged("target", {"12345"}, "lines", 4) end)
local plans = {
  {storage = "Folder/A", trashFilename = "A.preset", name = "Logical/é"},
  {storage = "B", trashFilename = "B.preset", name = "Logical/B"},
  recoveryFolders = {Logical = true}, recoveryManualFolders = {Logical = true},
}
for _, operation in ipairs({"trash", "restore", "rename"}) do
  local operationPlans = clone(plans)
  if operation == "rename" then
    for _, p in ipairs(operationPlans) do p.destinationStorage = "New/" .. p.storage end
  end
  for _, phase in ipairs({"prepared", "committed"}) do
    add("journal write " .. operation .. phase, {}, function() return runtime.writeTransaction(phase, operation, operationPlans) end)
    reset({}); assert(runtime.writeTransaction(phase, operation, operationPlans))
    local journal = assert(files[runtime.TRANSACTION_FILE])
    add("legacy journal " .. operation .. phase, {[runtime.TRANSACTION_FILE] = journal}, readTransaction)
    for _, diskState in ipairs({"before", "after", "both", "neither", "mixed"}) do
      local initial = {[runtime.TRANSACTION_FILE] = journal}
      for i, p in ipairs(operationPlans) do
        local source = runtime.PRESET_DIR .. "/" .. p.storage .. ".preset"
        local destination = operation == "rename" and (runtime.PRESET_DIR .. "/" .. p.destinationStorage .. ".preset")
          or (runtime.TRASH_DIR .. "/" .. p.trashFilename)
        if operation == "restore" then source, destination = destination, source end
        if diskState == "before" or diskState == "both" or (diskState == "mixed" and i == 1) then initial[source] = "original" .. i end
        if diskState == "after" or diskState == "both" or (diskState == "mixed" and i == 2) then initial[destination] = "changed" .. i end
      end
      add("recover " .. operation .. phase .. diskState, initial, runtime.recoverTransaction)
    end
    add("journal complete " .. operation .. phase, {[runtime.TRANSACTION_FILE] = journal}, function() return runtime.completeTransaction(operation, operationPlans) end)
  end
end
for _, text in ipairs({"", "V\t2\n", "H\tprepared\ttrash\n", "V\t1\nH\tunknown\ttrash\nP\tA\tA.preset\tA\n",
    "V\t1\nH\tprepared\ttrash\nP\t../A\tA.preset\tA\n", "V\t1\r\nH\tprepared\ttrash\r\nP\tA\tA.preset\tA\r\n",
    "H\tprepared\ttrash\nP\tA\tA.preset\tA\n", "V\t1\nH\tprepared\trename\nP\tA\tA.preset\tA\n"}) do
  add("journal malformed " .. #cases, {[runtime.TRANSACTION_FILE] = text}, runtime.recoverTransaction)
end
add("journal missing", {}, runtime.recoverTransaction)
add("journal backup only", {[runtime.TRANSACTION_FILE .. ".bak"] = "V\t1\nH\tprepared\ttrash\nP\tA\tA.preset\tA\n"}, runtime.recoverTransaction)
local trash = {["é.preset"] = {original = "Folder/é", group = "group"}}
local groups = {group = {root = "Folder", folders = {Folder = true}, manualFolders = {Folder = true}}}
add("trash write", {}, function() return writeTrashCatalog(trash, groups) end)
reset({}); assert(writeTrashCatalog(trash, groups)); local trashText = files[runtime.TRASH_CATALOG_FILE]
for _, text in ipairs({trashText, "", "invalid\n", "P\tA.preset\tA\tmissing\n", "P\t../A.preset\tA\t\n",
    "P\tA.preset\tA\t\nP\tA.preset\tB\t\n", "F\tgroup\tFolder\nM\tgroup\tFolder\n",
    "P\tCON.preset\tCON\t\n", "G\tgroup\tFolder\r\n"}) do
  add("trash read " .. #cases, {[runtime.TRASH_CATALOG_FILE] = text}, readTrashCatalog)
end
add("trash missing", {}, readTrashCatalog)
add("trash invalid encode", {}, function() return trashCatalogLines({["../bad.preset"] = {original = "A"}}, {}) end)
add("trash too long group", {}, function() return trashCatalogLines({}, {[string.rep("a",257)] = {root = "A"}}) end)
local function withLimit(name, limit, operation)
  local original = runtime[name]
  runtime[name] = limit
  local result = pack(pcall(operation))
  runtime[name] = original
  if not result[1] then error(result[2], 0) end
  return unpack(result, 2, result.n)
end
for _, limit in ipairs({2,3}) do
  add("journal line limit " .. limit, {}, function()
    return withLimit("MAX_TRANSACTION_LINES", limit, function()
      return runtime.writeTransaction("prepared", "trash", {plans[1]})
    end)
  end)
  add("journal read limit " .. limit, {[runtime.TRANSACTION_FILE]="V\t1\nH\tprepared\ttrash\nP\tA\tA.preset\tA\n"}, function()
    return withLimit("MAX_TRANSACTION_LINES", limit, readTransaction)
  end)
end
for _, limit in ipairs({3,4}) do
  add("trash line limit " .. limit, {}, function()
    return withLimit("MAX_CATALOG_LINES", limit, function() return writeTrashCatalog(trash,groups) end)
  end)
  add("trash read limit " .. limit, {[runtime.TRASH_CATALOG_FILE]=trashText}, function()
    return withLimit("MAX_CATALOG_LINES", limit, readTrashCatalog)
  end)
end

local atomicVariants = {}
for _, case in ipairs(cases) do
  if case.name:sub(1, 7) == "atomic " then
    reset(case.initial, nil, nil, case.windows)
    snapshot(case.fn)
    local normalSteps = step
    for first = 1, normalSteps do
      reset(case.initial, first, nil, case.windows)
      snapshot(case.fn)
      local failedSteps = step
      for second = first + 1, failedSteps do
        atomicVariants[#atomicVariants + 1] = {
          name = case.name .. " double " .. first .. "/" .. second,
          initial = case.initial, fn = case.fn, windows = case.windows,
          failures = {[first] = true, [second] = true}, noSweep = true,
        }
      end
    end
  end
end
for _, case in ipairs(atomicVariants) do cases[#cases + 1] = case end

local fixtures, count, failureCount, interruptedCount = {}, 0, 0, 0
local function record(name, value)
  count = count + 1
  fixtures[#fixtures + 1] = {name, value}
end
for _, case in ipairs(cases) do
  reset(case.initial, nil, nil, case.windows, case.failures)
  local result = snapshot(case.fn)
  if case.name:match("^legacy journal ") then assert(literal(files) == literal(case.initial), "legacy journal read changed files") end
  local successSteps = step
  record(case.name, result)
  for failing = 1, case.noSweep and 0 or successSteps do
    reset(case.initial, failing, nil, case.windows, case.failures)
    record(case.name .. " failure " .. failing, snapshot(case.fn))
    failureCount = failureCount + 1
    reset(case.initial, nil, nil, case.windows, {[failing] = "throw"})
    record(case.name .. " exception " .. failing, snapshot(case.fn))
    failureCount = failureCount + 1
  end
end

local workflowFunctions = {
  rename = runtime.renamePreset,
  trash = runtime.trashPreset,
  restore = function() return runtime.restoreTrashPreset("A.preset") end,
  groupRestore = function() return runtime.restoreTrashGroup("group") end,
  bulkTrash = function() return runtime.requestBulkTrash({"Folder/A", "Folder/B"}, "Folder") end,
  folderRelocation = runtime.removeVirtualFolder,
}
local realReadPreset = runtime.readPresetFile
local presetText = "# CPM Preset\n# Format: 8\n# Name: A\nHair:2\n"
local function orderedPairs(items)
  local keys = {}
  for key in pairs(items) do keys[#keys + 1] = key end
  table.sort(keys, function(a,b) return tostring(a) < tostring(b) end)
  local index = 0
  return function()
    index = index + 1
    local key = keys[index]
    if key ~= nil then return key, items[key] end
  end
end
local function workflowContext(kind)
  runtime.pairs = orderedPairs
  runtime.state.library.presets = {
    ["Folder/A"] = {storage = "A", entryCountKnown = false},
    ["Folder/B"] = {storage = "B", entryCountKnown = false},
  }
  runtime.state.library.selected = "Folder/A"
  runtime.state.library.renameName = "Renamed"
  runtime.state.library.folders = {Folder = true}
  runtime.state.library.manualFolders = {}
  runtime.state.library.ignoredPhysicalFolders = {}
  runtime.state.trash.items, runtime.state.trash.groups, runtime.state.trash.bundles = {}, {}, {}
  runtime.invalidateViewCache = function() end
  runtime.invalidatePresetAndTrashCaches = function() end
  runtime.ensureViewCache = function() end
  runtime.state.cache.presetNames = {"Folder/A", "Folder/B"}
  runtime.state.trash.bulkSelected = {}
  runtime.state.library.selectedFolder = "Folder"
  runtime.state.library.pendingRemoveFolder = nil
  if kind == "folderRelocation" then
    runtime.state.library.manualFolders.Folder = true
    runtime.state.library.pendingRemoveFolder = "Folder"
    runtime.state.library.presets["Folder/A"].storage = "Folder/A"
    runtime.state.library.presets["Folder/B"].storage = "Folder/B"
  end
  runtime.dir = function(path)
    local entries = {}
    for file in pairs(files) do
      if file:sub(1,#path+1) == path .. "/" and not file:sub(#path+2):find("/",1,true) then
        entries[#entries+1] = {name=file:sub(#path+2),type="file"}
      end
    end
    table.sort(entries,function(a,b) return a.name < b.name end)
    return entries
  end
  runtime.readPresetFile = function(path) return files[path] and {entries={{key="Hair",index=2}},entryCount=1,entryCountKnown=false} or nil end
  if kind == "restore" or kind == "groupRestore" then
    runtime.state.library.presets = {}
    runtime.state.trash.items = {
      ["A.preset"] = {original = "Folder/A", group = "group", preset = {entryCountKnown=false}},
      ["B.preset"] = {original = "Folder/B", group = "group", preset = {entryCountKnown=false}},
    }
    runtime.state.trash.groups.group = {root="Folder",folders={Folder=true},manualFolders={}}
  end
  if kind == "trash" then
    runtime.state.trash.pendingDeleteName = "Folder/A"
    runtime.state.trash.pendingDeleteFingerprint = runtime.fileFingerprint(runtime.PRESET_DIR .. "/A.preset")
  elseif kind == "bulkTrash" then
    runtime.requestBulkTrash({"Folder/A", "Folder/B"}, "Folder")
  end
  trace, logs, step = {}, {}, 0
end
for _, kind in ipairs({"rename", "trash", "restore", "groupRestore", "bulkTrash", "folderRelocation"}) do
  local initial = {}
  local directory = (kind == "restore" or kind == "groupRestore") and runtime.TRASH_DIR or runtime.PRESET_DIR
  if kind == "folderRelocation" then directory = directory .. "/Folder" end
  initial[directory .. "/A.preset"], initial[directory .. "/B.preset"] = presetText, presetText
  reset(initial); workflowContext(kind)
  local completed = snapshot(workflowFunctions[kind])
  local completedResult = assert(loadstring("return " .. completed))()
  assert(completedResult.returns[1], "workflow failed: " .. kind)
  record("workflow " .. kind, completed)
  local totalSteps = step
  assert(totalSteps > 10, "workflow did not reach storage: " .. kind)
  for interrupted = 1, totalSteps do
    reset(initial); workflowContext(kind); stopAfter = interrupted
    workflowFunctions[kind]()
    assert(stoppedSnapshot, "stop missed " .. kind .. " " .. interrupted)
    files = stoppedSnapshot
    stopAfter, failure = nil, nil
    local stoppedFiles = clone(files)
    trace, logs, step = {}, {}, 0
    local recovery = snapshot(runtime.recoverTransaction)
    record("interrupt " .. kind .. " " .. interrupted, literal({stopped=stoppedFiles,recovery=recovery}))
    interruptedCount = interruptedCount + 1
  end
  for failing = 1, totalSteps do
    reset(initial); workflowContext(kind); failure = failing
    record("workflow failure " .. kind .. " " .. failing, snapshot(workflowFunctions[kind]))
    failureCount = failureCount + 1
  end
end
runtime.readPresetFile = realReadPreset

local fixturePath = moduleRoot .. "modules/domain/stage4_fixtures.lua"
if CPM_RECORD_STAGE4 then
  local file = assert(io.open(fixturePath, "wb"))
  file:write("return {\n")
  for _, entry in ipairs(fixtures) do
    local encoded = literal(entry):gsub(string.rep("x", 128) .. "x*", function(run)
      return '" .. string.rep("x", ' .. #run .. ') .. "'
    end)
    file:write("  ", encoded, ",\n")
  end
  assert(file:write("}\n")); assert(file:close())
  print("Recorded original stage 4 fixtures: " .. #fixtures)
else
  local expected = dofile(fixturePath)
  assert(#fixtures == #expected, "fixture count changed")
  for index, entry in ipairs(fixtures) do
    assert(literal(entry) == literal(expected[index]), "fixture mismatch " .. index .. " " .. entry[1])
  end
  print("Stage 4 baseline comparisons passed: " .. #fixtures)
end
print("Injected failures: " .. failureCount .. "; journaled workflow interruptions and recovery: " .. interruptedCount)
print("Paired atomic failure cases: " .. #atomicVariants .. "; legacy journal reads leave all bytes unchanged.")
if not CPM_RECORD_STAGE4 then
  local fileAdapter = require("modules/adapters/files")
  local result = pack(fileAdapter.run(function(report)
    report({message="checkpoint",level="warn"})
    return nil, false, nil
  end, function(message, level) assert(message=="checkpoint" and level=="warn") end))
  assert(result.n==3 and result[1]==nil and result[2]==false and result[3]==nil)
  print("Explicit module boundaries and diagnostic checkpoint return values passed.")
end
assert(coroutine == nil, "test requires CET-style missing coroutine library")
coroutine = originalCoroutine
print("CET-style missing coroutine library regression passed.")
