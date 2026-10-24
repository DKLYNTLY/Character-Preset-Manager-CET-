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

runtime.saveAppearanceHistorySnapshot = function() return true end
runtime.refreshCustomizationUi = function() return true end
runtime.updateAcuImport = function() end
runtime.updateNativeBridge = function() end
state.app.ready = true
state.app.overlayOpen = true
state.app.windowOpen = true
state.app.inCustomization = true
local values = { cyberware_switcher = 10, cyberware_2_switcher = 2 }
local elapsed, pending = 0, {}
local changes, reads = {}, 0
local visibleCyberware = true
function system:GetUnitedOptions()
  reads = reads + 1
  local rows = {}
  for _, slot in ipairs({ "cyberware_switcher", "cyberware_2_switcher" }) do
    rows[#rows + 1] = {
      currIndex = values[slot], isEditable = true, isActive = true,
      info = { name = slot, uiSlot = slot, options = {
        { localizedName = "Common-Off" }, { localizedName = "On" },
      } },
    }
  end
  return rows
end
function system:ApplyChangeToOption(target, index)
  local slot = target.info.uiSlot
  assert(pending[slot] == nil, "the same option was changed before cyberware settled")
  pending[slot] = { value = index, due = elapsed + 0.15 }
  changes[slot] = (changes[slot] or 0) + 1
end
state.app.optionsMemo = nil
runtime.getOptions()
runtime.getOptions()
assert(reads == 1, "same-frame reads were not cached")
events.onUpdate(0)
runtime.getOptions()
assert(reads == 2, "a new update reused the old option list")
state.library.selected = "clear cyberware"
state.library.presets[state.library.selected] = {
  format = 8, entries = {
    { key = "cyberware_switcher", slot = "cyberware_switcher", slotOccurrence = 1,
      index = 0, choice = "options:Common-Off" },
    { key = "cyberware_2_switcher", slot = "cyberware_2_switcher", slotOccurrence = 1,
      index = 0, choice = "options:Common-Off" },
  },
}
runtime.loadPreset()
assert(state.load.needsContinue, "the loader finished before delayed changes settled")
assert(visibleCyberware, "the delayed game model applied cyberware instantly")
state.load.auto = state.load.needsContinue
for _ = 1, 200 do
  elapsed = elapsed + 0.05
  for slot, change in pairs(pending) do
    if elapsed >= change.due then
      values[slot] = change.value
      pending[slot] = nil
    end
  end
  visibleCyberware = values.cyberware_switcher ~= 0 or values.cyberware_2_switcher ~= 0
  events.onUpdate(0.05)
  if not state.load.auto and not state.load.needsContinue then break end
end
assert(not visibleCyberware, "old cyberware remained when the load finished")
assert(values.cyberware_switcher == 0 and values.cyberware_2_switcher == 0)
assert(changes.cyberware_switcher == 1 and changes.cyberware_2_switcher == 1,
  "cyberware was applied more than once")
assert(not state.load.needsContinue and not state.load.stalled, "cyberware load did not finish")
assert(next(state.load.unconfirmed) == nil, "fresh cyberware values were not confirmed")
assert(runtime.helpers.loadOptionNeedsLongSettle({label="Cyberware",slot="cyberware_switcher"},"cyberware"))
assert(not runtime.helpers.loadOptionNeedsLongSettle({label="Eye color",slot="eyes_color"},"color"),
  "ordinary colors were slowed down")
runtime.resetLoadState()
state.app.optionsMemo = nil
for _, entry in ipairs(state.library.presets[state.library.selected].entries) do
  entry.index = 1
  entry.choice = "options:On"
end
runtime.loadPreset()
state.load.auto = state.load.needsContinue
for _ = 1, 200 do
  elapsed = elapsed + 0.05
  for slot, change in pairs(pending) do
    if elapsed >= change.due then
      values[slot] = change.value
      pending[slot] = nil
    end
  end
  visibleCyberware = values.cyberware_switcher ~= 0 or values.cyberware_2_switcher ~= 0
  events.onUpdate(0.05)
  if not state.load.auto and not state.load.needsContinue then break end
end
assert(visibleCyberware and values.cyberware_switcher == 1 and values.cyberware_2_switcher == 1,
  "saved cyberware was cleared instead of loaded")
assert(changes.cyberware_switcher == 2 and changes.cyberware_2_switcher == 2,
  "saved cyberware was applied more than once")
assert(not state.load.needsContinue and not state.load.stalled)
print("Appearance load runtime test: OK")
