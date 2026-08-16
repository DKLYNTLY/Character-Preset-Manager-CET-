local initPath = assert(arg[1], "init.lua path is required")

local events = {}
function registerForEvent(name, callback) events[name] = callback end
function registerHotkey() end
function registerInput() end

local function enumTable()
  return setmetatable({}, { __index = function() return 0 end })
end

ImGuiCol = enumTable()
ImGuiCond = enumTable()
ImGuiStyleVar = enumTable()
ImGuiWindowFlags = enumTable()
local drawnLabels = {}
ImGui = setmetatable({}, { __index = function(_, name)
  if name == "Begin" or name == "CollapsingHeader" or name == "TreeNodeEx" then
    return function(label)
      if label then drawnLabels[tostring(label)] = true end
      return true
    end
  end
  if name == "InputTextWithHint" then
    return function(_, _, value) return value end
  end
  if name == "GetContentRegionAvail" then return function() return 390 end end
  if name == "GetWindowHeight" then return function() return 700 end end
  if name == "GetWindowWidth" then return function() return 420 end end
  if name == "GetFontSize" then return function() return 14 end end
  if name == "GetCursorPosX" then return function() return 0 end end
  if name == "CalcTextSize" then
    return function(value) return #tostring(value or "") * 7 end
  end
  if name == "GetDisplaySize" then return function() return 1920, 1080 end end
  if name == "GetMainViewport" then
    return function()
      return { WorkPos = { x = 0, y = 0 }, WorkSize = { x = 1920, y = 1080 } }
    end
  end
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

dir = function() return {} end
Observe = function() end
Override = function() end
ToCName = function() return "" end
LocKeyToString = function(value) return tostring(value) end
NameToString = function(value) return tostring(value) end
GetLocalizedTextByKey = function(value) return tostring(value) end

local extra = {
  currIndex = 5,
  isEditable = true,
  isActive = true,
  info = { name = "extra" },
}
local saved = {
  currIndex = 0,
  isEditable = true,
  isActive = true,
  info = { name = "saved" },
}
local extraAttempts = 0
local system = {}
function system:GetUnitedOptions() return { extra, saved } end
function system:ApplyChangeToOption(option, index)
  if option == extra then
    extraAttempts = extraAttempts + 1
  else
    option.currIndex = index
  end
end
Game = { GetCharacterCustomizationSystem = function() return system end }

assert(loadfile(initPath))()

local function upvalue(callback, wanted)
  for index = 1, 100 do
    local name, value = debug.getupvalue(callback, index)
    if not name then break end
    if name == wanted then return value end
  end
  error("missing upvalue: " .. wanted)
end

local update = assert(events.onUpdate, "onUpdate event was not registered")
local state = upvalue(update, "state")
local loadPreset = upvalue(update, "loadPreset")

state.selected = "fixture"
state.presets.fixture = {
  storage = "fixture",
  format = 8,
  entries = { { key = "saved", index = 2 } },
}
state.resetBeforeLoad = true

for _ = 1, 8 do
  loadPreset()
  if not state.loadNeedsContinue and saved.currIndex == 2 then break end
end

assert(extraAttempts == 3,
  "cleanup did not stop after three attempts: " .. tostring(extraAttempts))
assert(saved.currIndex == 2,
  "the saved option was never applied: " .. tostring(saved.currIndex))
assert(state.loadNeedsContinue == false, "the loader did not finish")

state.overlayOpen = true
state.windowOpen = true
state.ready = true
state.initialWindowPlacementPending = false
state.windowPositionCached = true
state.cachedWindowX = 1480
state.cachedWindowY = 40
state.cachedDisplayWidth = 1920
state.settingsOpen = true
state.helpOpen = true
state.debugOpen = true
for key in pairs(state.openSections) do state.openSections[key] = true end
for key in pairs(state.openSubsections) do state.openSubsections[key] = true end

local drawOk, drawError = pcall(events.onDraw)
assert(drawOk, "menu draw failed: " .. tostring(drawError))
for _, section in ipairs({
  "APPEARANCE EDITOR", "LOAD PRESET", "SAVE PRESET", "FOLDERS",
  "RENAME & COPY", "DELETE & RESTORE",
}) do
  local found = false
  for label in pairs(drawnLabels) do
    if label:find(section, 1, true) then found = true; break end
  end
  assert(found, "menu section was not drawn: " .. section)
end
print("Loader behavior smoke test: OK")
print("All-panel menu smoke test: OK")
