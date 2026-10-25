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
local values = { cyberware_switcher = 10, cyberware_2_switcher = 2 }
local elapsed, pendingValue, pendingSlot, due = 0, nil, nil, nil
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
  assert(pendingSlot == nil, "another option was changed before cyberware settled")
  pendingSlot, pendingValue, due = target.info.uiSlot, index, elapsed + 0.15
  changes[pendingSlot] = (changes[pendingSlot] or 0) + 1
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
local sawLongSettle = false
state.load.auto = state.load.needsContinue
for _ = 1, 200 do
  elapsed = elapsed + 0.05
  if due and elapsed >= due then
    values[pendingSlot] = pendingValue
    visibleCyberware = values.cyberware_switcher ~= 0 or values.cyberware_2_switcher ~= 0
    pendingSlot, pendingValue, due = nil, nil, nil
  end
  events.onUpdate(0.05)
  if state.load.pendingChange then
    assert(state.load.pendingChange.longSettle, "cyberware was treated as an instant change")
    sawLongSettle = true
  end
  if not state.load.auto and not state.load.needsContinue then break end
end
assert(sawLongSettle, "cyberware never waited for the editor to settle")
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
  if due and elapsed >= due then
    values[pendingSlot] = pendingValue
    visibleCyberware = values.cyberware_switcher ~= 0 or values.cyberware_2_switcher ~= 0
    pendingSlot, pendingValue, due = nil, nil, nil
  end
  events.onUpdate(0.05)
  if not state.load.auto and not state.load.needsContinue then break end
end
assert(visibleCyberware and values.cyberware_switcher == 1 and values.cyberware_2_switcher == 1,
  "saved cyberware was cleared instead of loaded")
assert(changes.cyberware_switcher == 2 and changes.cyberware_2_switcher == 2,
  "saved cyberware was applied more than once")
assert(not state.load.needsContinue and not state.load.stalled)
runtime.resetLoadState()
local hair = { hairstyle = 1, hair_color = 1 }
local hairPending, hairDue, hairTarget
local hairWrites = {}
local editorClosed = false
function system:GetUnitedOptions()
  if editorClosed then return nil end
  local rows = {}
  for _, slot in ipairs({ "hairstyle", "hair_color" }) do
    rows[#rows + 1] = {
      currIndex = hair[slot], isEditable = true, isActive = true,
      info = { name = slot, uiSlot = slot, options = {
        { localizedName = "First" }, { localizedName = "Second" },
      } },
    }
  end
  return rows
end
function system:ApplyChangeToOption(target, index)
  assert(not hairPending, "a linked choice was changed before the hair update finished")
  hairPending, hairTarget, hairDue = target.info.uiSlot, index, elapsed + 0.15
  hairWrites[hairPending] = (hairWrites[hairPending] or 0) + 1
end
state.library.selected = "linked hair"
state.library.presets[state.library.selected] = { format = 8, entries = {
  { key = "hairstyle", slot = "hairstyle", slotOccurrence = 1, index = 0, choice = "options:First" },
  { key = "hair_color", slot = "hair_color", slotOccurrence = 1, index = 0, choice = "options:First" },
} }
runtime.loadPreset()
state.load.auto = state.load.needsContinue
for _ = 1, 300 do
  elapsed = elapsed + 0.05
  if hairDue and elapsed >= hairDue then
    hair[hairPending] = hairTarget
    if hairPending == "hairstyle" then hair.hair_color = 1 end
    hairPending, hairDue, hairTarget = nil, nil, nil
  end
  events.onUpdate(0.05)
  if not state.load.auto and not state.load.needsContinue then break end
end
assert(hair.hairstyle == 0 and hair.hair_color == 0, "linked hair appearance did not finish")
assert(hairWrites.hairstyle == 1 and hairWrites.hair_color == 1, "hair changes were repeated")
assert(not state.load.stalled and next(state.load.unconfirmed) == nil)
runtime.resetLoadState()
hair.hairstyle, hair.hair_color = 1, 1
runtime.loadPreset()
state.load.auto = state.load.needsContinue
for _ = 1, 30 do
  elapsed = elapsed + 0.05
  events.onUpdate(0.05)
  if state.load.pendingChange then break end
end
assert(state.load.pendingChange, "no pending hair change to test editor closure")
editorClosed = true
events.onUpdate(0.05)
assert(not state.load.needsContinue and state.load.stalled and not state.load.pendingChange,
  "editor closure left a pending load")
runtime.resetLoadState()
assert(not state.load.auto and not state.load.batch and not state.load.pendingChange,
  "cancelling did not release the load state")
editorClosed = false
state.app.optionsMemo = nil
hairPending, hairDue, hairTarget = nil, nil, nil
local unconfirmedWrites = {}
function system:ApplyChangeToOption(target, index)
  local slot = target.info.uiSlot
  unconfirmedWrites[slot] = (unconfirmedWrites[slot] or 0) + 1
end
runtime.loadPreset()
state.load.auto = state.load.needsContinue
for _ = 1, 300 do
  events.onUpdate(0.05)
  if not state.load.auto and not state.load.needsContinue then break end
end
assert(unconfirmedWrites.hairstyle == 1 and unconfirmedWrites.hair_color == 1,
  "unexpected unconfirmed writes: hair=" .. tostring(unconfirmedWrites.hairstyle) ..
    " color=" .. tostring(unconfirmedWrites.hair_color))
assert(state.app.nativeLoadSummary:find("could not be confirmed", 1, true),
  "unconfirmed hair changes were reported as fully confirmed")
print("Appearance load runtime test: OK")
