local initPath = assert(arg[1], "init.lua path is required")

local events = {}
function registerForEvent(name, callback) events[name] = callback end
local hotkeys = {}
function registerHotkey(name) hotkeys[name] = true end
function registerInput() end
function Observe() end
function Override() end
function ToCName() return "" end
function LocKeyToString(value) return tostring(value) end
function NameToString(value) return tostring(value) end
function GetLocalizedTextByKey(value) return tostring(value) end
function dir() return {} end

local function enumTable()
  return setmetatable({}, { __index = function() return 0 end })
end
ImGuiCol = enumTable()
ImGuiCond = enumTable()
ImGuiStyleVar = enumTable()
ImGuiWindowFlags = enumTable()
ImGui = setmetatable({}, { __index = function()
  return function() return false end
end })
bit32 = { bor = function() return 0 end }

local nullFile = {}
function nullFile:write() return true end
function nullFile:flush() return true end
function nullFile:close() return true end
function nullFile:seek() return 0 end
function nullFile:read() return nil end
io.open = function() return nullFile end

local option = {
  currIndex = 0,
  isEditable = true,
  isActive = true,
  info = { name = "eye color" },
}
local options = { option }
local optionCalls = 0
local system = {}
function system:GetUnitedOptions()
  optionCalls = optionCalls + 1
  return options
end
function system:ApplyChangeToOption(target, index)
  target.currIndex = index
end
Game = {
  GetCharacterCustomizationSystem = function() return system end,
  GetPlayer = function() return nil end,
  GetScriptableSystemsContainer = function()
    return { Get = function() return nil end }
  end,
}

assert(loadfile(initPath))()
local runtime = require("modules/runtime")
local state = runtime.state
local helpers = runtime.helpers
if arg[2] == "uncached" then
  helpers.cachedOptionChoices = function() return nil end
end

runtime.saveAppearanceHistorySnapshot = function() return true end
runtime.refreshCustomizationUi = function() return true end
runtime.updateAcuImport = function() end
runtime.updateNativeBridge = function() end
state.app.ready = true
state.app.overlayOpen = true
state.app.windowOpen = true
state.app.inCustomization = true

local originalGetOptions = runtime.getOptions
local reads, scans, writes, peak, simulatedClock = 0, 0, 0, 0, 0
local values, rows, entries = {}, {}, {}
local closed, failWrite, mutate, cost = false, false, false, 0
local beforeScan = helpers.scanLoadOptions
if beforeScan then
  helpers.scanLoadOptions = function(...)
    scans = scans + 1
    return beforeScan(...)
  end
end
helpers.loadClock = function() return simulatedClock end
local lastOptions
function system:GetUnitedOptions()
  reads = reads + 1
  if closed then return nil end
  local result = {}
  for _, row in ipairs(rows) do
    result[#result + 1] = {
      currIndex = values[row], isEditable = true, isActive = true,
      info = { name = row, uiSlot = row, options = {
        { localizedName = "First" }, { localizedName = "Second" },
      } },
    }
  end
  lastOptions = result
  return result
end
function system:ApplyChangeToOption(target, index)
  if failWrite then error("fixture write failed") end
  local slot = target.info.uiSlot
  writes = writes + 1
  simulatedClock = simulatedClock + cost
  values[slot] = index
  if mutate then
    lastOptions[2].isActive = false
    table.remove(rows, 2)
    mutate = false
  end
end
local function start(count)
  runtime.resetLoadState()
  state.app.optionsMemo = nil
  reads, scans, writes, peak, simulatedClock = 0, 0, 0, 0, 0
  values, rows, entries = {}, {}, {}
  closed, failWrite, mutate, cost = false, false, false, 0
  for i = 1, count do
    local slot = "selector_" .. tostring(i)
    rows[i], values[slot] = slot, 0
    entries[i] = { key = slot, slot = slot, index = 1, choice = "options:Second" }
  end
  state.library.selected = "group fixture"
  state.library.presets[state.library.selected] = { format = 8, entries = entries }
end
local ticks = 0
local function tick(first)
  local before = writes
  if first then runtime.loadPreset(); state.load.auto = state.load.needsContinue
  else events.onUpdate(1 / 60) end
  peak = math.max(peak, writes - before)
  ticks = ticks + 1
end
local function finish()
  for i = 1, 20000 do
    if not state.load.needsContinue then break end
    tick(false)
  end
end
start(96)
ticks = 0
tick(true)
finish()
assert(not state.load.needsContinue and not state.load.stalled, "independent load did not finish")
assert(writes == 96, "unchanged or confirmed choices were applied again")
for _, slot in ipairs(rows) do assert(values[slot] == 1, "saved choice was missed") end
print(("BENCHMARK %s | options=96 | simulated=%.3fs | reads=%d | scans=%d | peakWrites=%d")
  :format(arg[2] or "current", (ticks - 1) / 60, reads, scans, peak))
if arg[2] then
  start(96)
  state.load.resetBefore = true
  ticks = 0
  tick(true)
  finish()
  assert(writes == 96 and not state.load.stalled and not state.load.needsContinue,
    "full load with cleanup did not finish")
  print(("BENCHMARK %s | with cleanup | simulated=%.3fs | reads=%d | scans=%d | peakWrites=%d")
    :format(arg[2], (ticks - 1) / 60, reads, scans, peak))
  return
end
assert(peak <= 4, "more than four choices were applied in one update")
assert(reads <= 27 and scans <= 27, "ordinary choices still trigger per-choice full reads or scans")
assert(ticks < 35, "ordinary choices still wait between groups")
start(8)
state.load.pass = 1
local bridgeStarted = false
runtime.updateNativeBridge = function()
  if bridgeStarted then return end
  bridgeStarted = true
  runtime.loadPreset()
  state.load.auto = state.load.needsContinue
end
events.onUpdate(1 / 60)
assert(writes == 4, "simple-menu load applied two groups in one update")
runtime.updateNativeBridge = function() end
finish()
assert(writes == 8 and not state.load.stalled)
start(0)
tick(true)
assert(not state.load.needsContinue, "empty preset left loading active")
start(10)
cost = 0.003
tick(true)
assert(writes == 2, "four-millisecond budget did not yield after expensive writes")
finish()
assert(writes == 10 and not state.load.stalled)
start(8)
tick(true)
assert(writes == 4 and state.load.batch, "first group was not bounded")
runtime.cancelLoading()
for i = 1, 20 do tick(false) end
assert(writes == 4 and not state.load.batch and not state.load.pendingChange,
  "cancel left prepared choices running")
start(8)
tick(true)
closed = true
tick(false)
assert(not state.load.needsContinue and state.load.stalled and not state.load.batch,
  "editor closure left group work pending")
start(8)
failWrite = true
tick(true)
assert(state.load.stalled and not state.load.needsContinue, "write failure did not stop loading")
start(8)
mutate = true
tick(true)
finish()
assert(values.selector_3 == 1 and values.selector_8 == 1, "changed option list lost remaining choices")
assert(values.selector_2 == 0 and state.load.stalled, "inactive queued selector was applied")
start(8)
tick(true)
rows[#rows + 1] = "new_linked_option"
values.new_linked_option = 0
tick(false)
assert(state.load.pendingChange and state.load.pendingChange.longSettle,
  "an unexpected structure change did not pause group confirmation")
finish()
assert(writes == 8 and not state.load.stalled and not state.load.needsContinue,
  "group confirmation lost or repeated work after an unexpected structure change")
start(1)
entries[2] = { key = "selector_1", index = 1 }
tick(true)
finish()
assert(writes == 0 and state.load.stalled, "ambiguous labels were applied")
start(1)
entries[1].choice = "options:Missing"
tick(true)
finish()
assert(writes == 0 and state.load.stalled, "missing saved choice was replaced by an index")
start(8)
for _, slot in ipairs(rows) do values[slot] = 1 end
tick(true)
finish()
assert(writes == 0, "matching choices were rewritten")
print("Loading groups runtime test: OK")
