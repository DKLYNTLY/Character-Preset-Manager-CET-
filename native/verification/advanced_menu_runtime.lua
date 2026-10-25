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

local files, writes, statuses = {}, {}, {}
local sequence = 0
local response
runtime.writeFileSafely = function(path, mode, writer)
  return writer({ write = function(self, value)
    files[path] = value
    writes[#writes + 1] = value
    return true
  end })
end
runtime.readBoundedFile = function(path) return files[path] end
runtime.refreshAppearanceHistory = function() end
state.app.ready = true
state.app.overlayOpen = false
state.app.nativeBridgeSequence = 0
state.app.nativeRequestPollTimer = 0
state.app.nativeBridge = {
  HasPanels = function() return false end,
  SetBusy = function(self, busy, message) statuses[#statuses + 1] = message end,
  GetRequestSequence = function() return sequence end,
  GetRequestAction = function() return "open_advanced" end,
  GetRequestPayload = function() return "" end,
  Respond = function(self, seq, kind, message) response = message end,
}
local function request()
  sequence = sequence + 1
  runtime.updateNativeBridge(1)
end
local requestPath = runtime.CONFIG_DIR .. "/CET Overlay Request.txt"
local resultPath = runtime.CONFIG_DIR .. "/CET Overlay Result.txt"
request()
assert(state.app.windowOpen and files[requestPath]:match("\topen$"))
local id = files[requestPath]:match("^([^\t]+)")
local count = #writes
request()
assert(#writes == count, "duplicate click sent another request")
files[resultPath] = id .. "\tsent"
helpers.updateOverlayRequest(0.1)
assert(#writes == count, "sent request repeated before confirmation")
events.onOverlayOpen()
assert(files[requestPath] == id .. "\tcancel", "overlay event did not cancel the request")
count = #writes
request()
assert(#writes == count, "already-open CET was toggled closed")
state.app.overlayOpen = false
request()
helpers.updateOverlayRequest(3)
assert(files[requestPath]:match("\tcancel$") and statuses[#statuses]:find("Press your CET binding",1,true))
count = #writes
helpers.updateOverlayRequest(3)
assert(#writes == count, "opening was retried after timeout")
request()
id = files[requestPath]:match("^([^\t]+)")
files[resultPath] = id .. "\tbinding-unavailable"
helpers.updateOverlayRequest(0)
assert(files[requestPath] == id .. "\tcancel")
print("Advanced menu runtime test: OK")
