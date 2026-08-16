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
  info = { name = "hairstyle" },
}
local extraAttempts = 0
local extraVisible = true
local keepExtraVisible = false
local applicationOrder = {}
local customOptions = nil
local system = {}
function system:GetUnitedOptions()
  if customOptions then return customOptions end
  if extraVisible then return { extra, saved } end
  return { saved }
end
function system:ApplyChangeToOption(option, index)
  applicationOrder[#applicationOrder + 1] = option == extra and "extra" or "saved"
  if option == extra then
    extraAttempts = extraAttempts + 1
  else
    option.currIndex = index
    if not keepExtraVisible then extraVisible = false end
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
local resetLoadState = upvalue(loadPreset, "resetLoadState")

state.selected = "fixture"
state.presets.fixture = {
  storage = "fixture",
  format = 8,
  entries = { { key = "hairstyle", index = 2 } },
}
state.resetBeforeLoad = true
loadPreset()
state.autoLoad = state.loadNeedsContinue

for _ = 1, 100 do
  update(0.05)
  if not state.autoLoad and not state.loadNeedsContinue then break end
end

assert(saved.currIndex == 2,
  "the saved option was never applied: " .. tostring(saved.currIndex))
assert(extraAttempts == 0,
  "a dependent child option was cleared before it disappeared: " .. tostring(extraAttempts))
assert(state.loadNeedsContinue == false, "the loader did not finish")
assert(state.loadStructureChanges > 0,
  "the dependent option disappearance was not measured")
assert(state.loadMetadataDisabled == true,
  "metadata reuse was not disabled after an option-structure change")
for _, descriptor in ipairs(state.loadLastStructureDescriptors) do
  assert(descriptor.option == nil,
    "structure measurement retained a live option object")
end

resetLoadState()
saved.currIndex = 0
extra.currIndex = 5
extraAttempts = 0
extraVisible = true
keepExtraVisible = true
applicationOrder = {}
state.selected = "persistent fixture"
state.presets["persistent fixture"] = {
  storage = "persistent fixture",
  format = 8,
  entries = { { key = "hairstyle", index = 2 } },
}
state.resetBeforeLoad = true
loadPreset()
state.autoLoad = state.loadNeedsContinue

for _ = 1, 200 do
  update(0.05)
  if not state.autoLoad and not state.loadNeedsContinue then break end
end

assert(applicationOrder[1] == "saved",
  "leftover cleanup ran before the saved preset option")
assert(extraAttempts == 3,
  "timed cleanup did not stop after three real attempts: " .. tostring(extraAttempts))
assert(saved.currIndex == 2,
  "preset verification did not preserve the saved option")
assert(state.loadNeedsContinue == false, "the timed cleanup fixture did not finish")
assert(state.loadMetadataHits > 0,
  "stable option metadata was never reused")
assert(state.loadMetadataDisabled == false,
  "stable option metadata was disabled without a structural difference")
for _, descriptor in ipairs(state.loadMetadataCache.descriptors) do
  assert(descriptor.option == nil,
    "the metadata cache retained a live option object")
end

keepExtraVisible = false
extraVisible = false
saved.info.definitions = { "hair zero", "hair one", "hair two" }
for _, format in ipairs({ 4, 7 }) do
  resetLoadState()
  saved.currIndex = 0
  local name = "format " .. tostring(format)
  state.selected = name
  state.presets[name] = {
    storage = name,
    format = format,
    entries = {
      {
        key = "hairstyle",
        index = 2,
        choice = format == 7 and "definitions:hair two" or nil,
      },
    },
  }
  state.resetBeforeLoad = true
  loadPreset()
  state.autoLoad = state.loadNeedsContinue
  for _ = 1, 100 do
    update(0.05)
    if not state.autoLoad and not state.loadNeedsContinue then break end
  end
  assert(saved.currIndex == 2,
    "format " .. tostring(format) .. " preset did not load")
  assert(state.loadNeedsContinue == false,
    "format " .. tostring(format) .. " preset did not finish")
end

local repeatedA = {
  currIndex = 0,
  isEditable = true,
  isActive = true,
  info = { name = "tattoo", uiSlot = "tattoo a" },
}
local repeatedB = {
  currIndex = 0,
  isEditable = true,
  isActive = true,
  info = { name = "tattoo", uiSlot = "tattoo b" },
}
customOptions = { repeatedA, repeatedB }
resetLoadState()
state.selected = "repeated fixture"
state.presets["repeated fixture"] = {
  storage = "repeated fixture",
  format = 8,
  entries = {
    { key = "tattoo", index = 1, slot = "tattoo a" },
    { key = "tattoo", index = 2, slot = "tattoo b" },
  },
}
state.resetBeforeLoad = true
loadPreset()
state.autoLoad = state.loadNeedsContinue
for _ = 1, 100 do
  update(0.05)
  if not state.autoLoad and not state.loadNeedsContinue then break end
end
assert(repeatedA.currIndex == 1 and repeatedB.currIndex == 2,
  "repeated option occurrences were not applied independently")
assert(state.loadNeedsContinue == false,
  "the repeated option fixture did not finish")
customOptions = nil

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
