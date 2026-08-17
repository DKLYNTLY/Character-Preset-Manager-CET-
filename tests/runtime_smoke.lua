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
local keepSavedStale = false
local applicationOrder = {}
local savedAttempts = 0
local customOptions = nil
local applyHook = nil
local system = {}
function system:GetUnitedOptions()
  if customOptions then return customOptions end
  if extraVisible then return { extra, saved } end
  return { saved }
end
function system:ApplyChangeToOption(option, index)
  if applyHook then applyHook(option, index); return end
  applicationOrder[#applicationOrder + 1] = option == extra and "extra" or "saved"
  if option == extra then
    extraAttempts = extraAttempts + 1
  else
    savedAttempts = savedAttempts + 1
    if not keepSavedStale then option.currIndex = index end
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
local helpers = upvalue(loadPreset, "helpers")

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
assert(state.loadLastStructureSignature ~= nil,
  "the compact option-structure signature was not retained")

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
assert(extraAttempts == 1,
  "unconfirmed cleanup was applied more than once: " .. tostring(extraAttempts))
assert(saved.currIndex == 2,
  "preset verification did not preserve the saved option")
assert(state.loadNeedsContinue == false, "the timed cleanup fixture did not finish")

resetLoadState()
saved.currIndex = 0
saved.info.name = "eye color"
savedAttempts = 0
extraVisible = false
keepExtraVisible = false
keepSavedStale = true
state.selected = "stale currIndex fixture"
state.presets["stale currIndex fixture"] = {
  storage = "stale currIndex fixture",
  format = 8,
  entries = { { key = "eye color", index = 2 } },
}
state.resetBeforeLoad = true
local originalScanLoadOptions = helpers.scanLoadOptions
local staleFullScans = 0
helpers.scanLoadOptions = function(...)
  staleFullScans = staleFullScans + 1
  return originalScanLoadOptions(...)
end
loadPreset()
state.autoLoad = state.loadNeedsContinue
for _ = 1, 100 do
  update(0.05)
  if not state.autoLoad and not state.loadNeedsContinue then break end
end
assert(savedAttempts == 1,
  "stale currIndex caused the same option to be applied repeatedly")
assert(state.loadUnconfirmed["eye color\31" .. "1"] == true,
  "stale currIndex was not retained as an unconfirmed result")
assert(state.loadStatus:find("could not be confirmed", 1, true) ~= nil,
  "the final status claimed an unconfirmed option was fully applied")
assert(state.loadNeedsContinue == false,
  "the stale currIndex fixture did not finish")
assert(state.loadTargetPolls == 0,
  "an ordinary option used dependency-only targeted polling")
assert(staleFullScans == state.loadOptionCalls,
  "an ordinary option check skipped the fresh full scan")
helpers.scanLoadOptions = originalScanLoadOptions
keepSavedStale = false
saved.info.name = "hairstyle"

local movedOrdinary = {
  currIndex = 0,
  isEditable = true,
  isActive = true,
  info = { name = "eye color" },
}
local insertedOption = {
  currIndex = 0,
  isEditable = true,
  isActive = true,
  info = { name = "inserted option" },
}
customOptions = { movedOrdinary }
applyHook = function(option, index)
  option.currIndex = index
  customOptions = { insertedOption, movedOrdinary }
end
resetLoadState()
state.selected = "targeted fallback fixture"
state.presets["targeted fallback fixture"] = {
  storage = "targeted fallback fixture",
  format = 8,
  entries = { { key = "eye color", index = 1 } },
}
state.resetBeforeLoad = false
loadPreset()
state.autoLoad = state.loadNeedsContinue
for _ = 1, 100 do
  update(0.05)
  if not state.autoLoad and not state.loadNeedsContinue then break end
end
assert(movedOrdinary.currIndex == 1 and state.loadNeedsContinue == false,
  "the full-scan fallback did not finish a moved ordinary option")
assert(state.loadTargetFallbacks == 0 and state.loadTargetPollingDisabled == false,
  "an ordinary position change entered dependency-only targeted polling")
applyHook = nil
customOptions = nil

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

customOptions = { saved }
resetLoadState()
saved.currIndex = 2
state.selected = "hidden zero fixture"
state.presets["hidden zero fixture"] = {
  storage = "hidden zero fixture",
  format = 8,
  entries = {
    { key = "hairstyle", index = 2 },
    { key = "hidden child", index = 0 },
  },
}
state.resetBeforeLoad = true
loadPreset()
state.autoLoad = state.loadNeedsContinue
for _ = 1, 100 do
  update(0.05)
  if not state.autoLoad and not state.loadNeedsContinue then break end
end
assert(state.preflight.available == 2 and state.preflight.unavailable == 0,
  "a hidden option already saved as zero was reported as unavailable")
assert(state.loadSatisfied["hidden child\31" .. "1"] == true,
  "a hidden option already saved as zero was not treated as clear")
assert(state.loadNeedsContinue == false,
  "the hidden zero fixture did not finish")

local originalLoadChoiceShape = helpers.loadChoiceShape
local choiceShapeCalls = 0
local largestReducedExposure = 0
helpers.loadChoiceShape = function(option)
  choiceShapeCalls = choiceShapeCalls + 1
  return originalLoadChoiceShape(option)
end
originalScanLoadOptions = helpers.scanLoadOptions
helpers.scanLoadOptions = function(...)
  local scan = originalScanLoadOptions(...)
  largestReducedExposure = math.max(largestReducedExposure, #scan.exposed)
  return scan
end
customOptions = { saved }
for index = 1, 200 do
  customOptions[#customOptions + 1] = {
    currIndex = 0,
    isEditable = true,
    isActive = true,
    info = { name = "irrelevant " .. tostring(index) },
  }
end
resetLoadState()
saved.currIndex = 2
state.selected = "large scan fixture"
state.presets["large scan fixture"] = {
  storage = "large scan fixture",
  format = 8,
  entries = { { key = "hairstyle", index = 2 } },
}
state.resetBeforeLoad = false
loadPreset()
state.autoLoad = state.loadNeedsContinue
for _ = 1, 100 do
  update(0.05)
  if not state.autoLoad and not state.loadNeedsContinue then break end
end
assert(choiceShapeCalls < 20,
  "polling inspected every irrelevant option choice structure")
assert(largestReducedExposure < 10,
  "normal loading built temporary records for every irrelevant option")
assert(state.loadNeedsContinue == false,
  "the large scan fixture did not finish")
helpers.loadChoiceShape = originalLoadChoiceShape
helpers.scanLoadOptions = originalScanLoadOptions

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

local dependencyHair = {
  currIndex = 0,
  isEditable = true,
  isActive = true,
  info = {
    name = "hairstyle",
    uiSlot = "hair style",
    definitions = { "hair zero", "hair one", "hair two" },
  },
}
local oldHairColor = {
  currIndex = 0,
  isEditable = true,
  isActive = true,
  info = {
    name = "old hair color",
    uiSlot = "hair color",
    definitions = { "black", "purple", "red" },
  },
}
local newHairColor = {
  currIndex = 0,
  isEditable = true,
  isActive = true,
  info = {
    name = "new hair color",
    uiSlot = "hair color",
    definitions = { "black", "purple", "red" },
  },
}
customOptions = { dependencyHair, oldHairColor }
applyHook = function(option, index)
  option.currIndex = index
  if option == dependencyHair then customOptions = { dependencyHair, newHairColor } end
end
resetLoadState()
state.selected = "dependency replacement fixture"
state.presets["dependency replacement fixture"] = {
  storage = "dependency replacement fixture",
  format = 8,
  entries = {
    {
      key = "hairstyle",
      index = 2,
      slot = "hair style",
      choice = "definitions:hair two",
    },
    {
      key = "old hair color",
      index = 1,
      slot = "hair color",
      choice = "definitions:purple",
    },
  },
}
state.resetBeforeLoad = true
loadPreset()
state.autoLoad = state.loadNeedsContinue
for _ = 1, 150 do
  update(0.05)
  if not state.autoLoad and not state.loadNeedsContinue then break end
end
assert(newHairColor.currIndex == 1,
  "a renamed hairstyle-dependent option was not matched by slot and saved choice")
assert(state.loadNeedsContinue == false and state.loadStalled == false,
  "the safely remapped dependency fixture did not finish")
assert(state.preflight.available == 2 and state.preflight.unavailable == 0,
  "the option check did not recognize a safe dependency replacement")
assert(state.loadTargetPolls > 0,
  "dependency stability waiting did not use targeted checks between full scans")
for _, remap in pairs(state.loadDependencyRemaps) do
  assert(remap.option == nil,
    "dependency protection retained a live option object")
end

dependencyHair.currIndex = 0
oldHairColor.currIndex = 0
newHairColor.currIndex = 0
customOptions = { dependencyHair, oldHairColor }
resetLoadState()
state.forceFullLoad = true
state.selected = "dependency replacement full scan fixture"
state.presets["dependency replacement full scan fixture"] = {
  storage = "dependency replacement full scan fixture",
  format = 8,
  entries = state.presets["dependency replacement fixture"].entries,
}
state.resetBeforeLoad = true
loadPreset()
state.autoLoad = state.loadNeedsContinue
for _ = 1, 150 do
  update(0.05)
  if not state.autoLoad and not state.loadNeedsContinue then break end
end
assert(newHairColor.currIndex == 1,
  "full scanning produced a different dependency replacement result")
assert(state.loadNeedsContinue == false and state.loadStalled == false,
  "the full-scan dependency fixture did not finish")
assert(state.loadTargetPolls == 0,
  "Force Full Load did not keep dependency polling disabled")
state.forceFullLoad = false
applyHook = nil
customOptions = nil

local legacyBefore = {
  currIndex = 0,
  isEditable = true,
  isActive = true,
  info = { name = "legacy before" },
}
local legacyHairColor = {
  currIndex = 0,
  isEditable = true,
  isActive = true,
  info = { name = "renamed legacy hair color" },
}
local legacyAfter = {
  currIndex = 0,
  isEditable = true,
  isActive = true,
  info = { name = "legacy after" },
}
customOptions = { legacyBefore, legacyHairColor, legacyAfter }
applyHook = function(option, index) option.currIndex = index end
for _, format in ipairs({ 4, 5, 6 }) do
  resetLoadState()
  legacyHairColor.currIndex = 0
  state.forceFullLoad = true
  local name = "legacy forced hair color format " .. tostring(format)
  state.selected = name
  state.presets[name] = {
    storage = name,
    format = format,
    entries = {
      { key = "legacy before", index = 0 },
      { key = "old legacy hair color", index = 5 },
      { key = "legacy after", index = 0 },
    },
  }
  state.resetBeforeLoad = true
  loadPreset()
  state.autoLoad = state.loadNeedsContinue
  for _ = 1, 150 do
    update(0.05)
    if not state.autoLoad and not state.loadNeedsContinue then break end
  end
  assert(legacyHairColor.currIndex == 5,
    "cleanup removed a format " .. tostring(format)
      .. " hair color applied by Force Full Load")
  assert(state.loadNeedsContinue == false and state.loadStalled == false,
    "the protected format " .. tostring(format)
      .. " Force Full Load fixture did not finish")
  assert(state.loadForcedKeys["old legacy hair color\31" .. "1"] == true,
    "the protected format " .. tostring(format)
      .. " replacement was not reported as forced")
  for _, remap in pairs(state.loadDependencyRemaps) do
    assert(remap.option == nil,
      "legacy cleanup protection retained a live option object")
  end
end
state.forceFullLoad = false
applyHook = nil
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
