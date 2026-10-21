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

assert(not hotkeys.vanilla_character_presets_toggle, "the removed toggle binding was registered")
assert(runtime.events.toggleWindow == nil, "the removed toggle handler is still present")

local randomizations, settingsOpened = 0, 0
local menu = {
  CPMCanRandomize = function() return true end,
  CPMRandomize = function() randomizations = randomizations + 1; return true end,
  CPMRandomizeSettings = function() settingsOpened = settingsOpened + 1; return true end,
  CPMUpdateRandomizerControls = function() end,
}
runtime.resetLoadState()
state.app.inCustomization = true
state.app.overlayOpen = false
state.editor.activeBodyMorphMenu = menu
assert(runtime.canRunAppearanceRandomizer(), "ready editor was rejected")
assert(runtime.runAppearanceRandomizer(false) == "status")
assert(randomizations == 1, "Randomize did not reach the game controller")
assert(runtime.runAppearanceRandomizer(true) == "status")
assert(settingsOpened == 1, "settings did not reach the game controller")

for _, field in ipairs({ "auto", "needsContinue", "pendingChange" }) do
  state.load[field] = true
  assert(not runtime.canRunAppearanceRandomizer(), field .. " allowed randomization")
  assert(runtime.runAppearanceRandomizer(false) == "error")
  assert(runtime.runAppearanceRandomizer(true) == "error")
  state.load[field] = nil
end
assert(randomizations == 1 and settingsOpened == 1, "busy actions reached the controller")
state.app.inCustomization = false
assert(runtime.runAppearanceRandomizer(false) == "error", "closed editor allowed randomization")
state.app.inCustomization = true
state.editor.activeBodyMorphMenu = {}
assert(runtime.runAppearanceRandomizer(false) == "error", "missing REDscript hooks were not guarded")
state.editor.activeBodyMorphMenu = menu
menu.CPMCanRandomize = function() return false end
assert(runtime.runAppearanceRandomizer(true) == "error", "game input guard was ignored")
menu.CPMCanRandomize = function() return true end
local original = menu.CPMRandomize
menu.CPMRandomize = function() error("controller unavailable") end
assert(runtime.runAppearanceRandomizer(false) == "error", "controller failure escaped")
menu.CPMRandomize = original

state.app.overlayOpen = true
assert(runtime.runAppearanceRandomizer(true) == "status")
assert(settingsOpened == 1, "settings opened beneath the CET overlay")
assert(state.editor.pendingRandomizeSettings == menu)
events.onOverlayClose()
assert(settingsOpened == 2, "closing CET did not open the queued settings")
assert(state.editor.pendingRandomizeSettings == nil, "settings request was not consumed")
events.onOverlayClose()
assert(settingsOpened == 2, "settings request ran twice")
state.app.overlayOpen = true
runtime.runAppearanceRandomizer(true)
state.editor.activeBodyMorphMenu = {}
events.onOverlayClose()
assert(settingsOpened == 2, "queued settings ran on a different screen")
assert(state.editor.pendingRandomizeSettings == nil)
state.editor.activeBodyMorphMenu = menu
state.app.overlayOpen = true
runtime.runAppearanceRandomizer(true)
state.load.auto = true
events.onOverlayClose()
assert(settingsOpened == 2, "queued settings bypassed the load guard")
state.load.auto = false

local sequence, action, response = 0, "", nil
state.app.ready = true
state.app.nativeBridgeSequence = 0
state.app.nativeBridge = {
  SetBusy = function(_, busy) assert(type(busy) == "boolean", "bridge busy state is not a boolean") end,
  HasPanels = function() return false end,
  GetRequestSequence = function() return sequence end,
  GetRequestAction = function() return action end,
  GetRequestPayload = function() return "" end,
  Respond = function(_, _, kind, _, busy)
    assert(type(busy) == "boolean", "response busy state is not a boolean")
    response = kind
  end,
}
for _, requested in ipairs({ "randomize", "randomize_settings" }) do
  sequence = sequence + 1
  action = requested
  runtime.updateNativeBridge(1)
  assert(response == "status", "simple-menu action was not routed: " .. requested)
end
assert(randomizations == 2 and settingsOpened == 3, "simple-menu actions used a different path")
state.load.pendingChange = {}
runtime.updateNativeBridge(1)
state.load.pendingChange = nil
print("Randomizer runtime smoke test: OK")
