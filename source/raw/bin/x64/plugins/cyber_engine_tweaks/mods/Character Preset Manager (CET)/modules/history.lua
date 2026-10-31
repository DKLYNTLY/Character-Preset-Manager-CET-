local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime
local stateModel = require("modules/domain/state")
local paths = require("modules/domain/paths")
local appearanceHistory = require("modules/domain/appearance_history")

local function historyPath(index)
  return paths.historyPath(index, HISTORY_FILE_PREFIX)
end

local function snapshotFromOptions(options, action)
  local entries = {}
  for _, option in ipairs(options or {}) do
    local key = optionKey(option)
    if key and option.isEditable and option.isActive then
      local currentIndex = tonumber(option.currIndex)
      if #key > MAX_PRESET_KEY_BYTES or #entries >= MAX_PRESET_ENTRIES
          or optionIndexValidationError(currentIndex) then return nil end
      entries[#entries + 1] = {
        key = key,
        index = currentIndex,
        slot = optionSlot(option),
        choice = helpers.optionChoiceKey(option, currentIndex),
      }
    end
  end
  if #entries == 0 then return nil end
  local timestamp = logTimestamp()
  return appearanceHistory.snapshot(entries,action,timestamp,CURRENT_PRESET_FORMAT,MOD_NAME)
end

local function sameAppearance(first,second)
  return appearanceHistory.sameAppearance(first,second)
end

refreshAppearanceHistory = function()
  state.history.entries = {}
  local limit = APPEARANCE_HISTORY_LIMIT
  for index = 1, limit do
    local path = historyPath(index)
    local preset = readPresetFile(path)
    if preset then
      state.history.entries[#state.history.entries + 1] = appearanceHistory.entry(index,path,preset,state.presetEntryCount(preset))
    end
  end
  state.load.recoverySnapshotAvailable = #state.history.entries > 0
    or fileExists(LAST_APPEARANCE_FILE)
  return state.history.entries
end

saveAppearanceHistorySnapshot = function(options, action)
  local preset = snapshotFromOptions(options, action)
  if not preset then
    log("[APPEARANCE HISTORY] The current appearance could not be read safely, so no recovery copy was saved.", "warn")
    return false
  end
  local newest = readPresetFile(historyPath(1))
  if newest and sameAppearance(preset, newest) then
    log("[APPEARANCE HISTORY] Skipped an identical recovery snapshot.", "info")
    return true
  end
  local limit = APPEARANCE_HISTORY_LIMIT
  for _, rotation in ipairs(appearanceHistory.rotation(limit)) do
    local index = rotation.destination
    local older = readPresetFile(historyPath(rotation.source))
    if older and not writePresetPath(historyPath(index), older) then
      log("[APPEARANCE HISTORY] Older entries could not be moved safely to make room for the new recovery copy.", "warn")
      return false
    end
  end
  if not writePresetPath(historyPath(1), preset) then
    log("[APPEARANCE HISTORY] The new recovery copy could not be saved.", "warn")
    return false
  end
  for _, index in ipairs(appearanceHistory.trimIndices(limit)) do deleteFile(historyPath(index)) end
  writePresetPath(LAST_APPEARANCE_FILE, preset)
  refreshAppearanceHistory()
  log(("[APPEARANCE HISTORY] Saved '%s' with %d options.")
    :format(tostring(action), #preset.entries), "info")
  return true
end

restoreAppearanceHistory = function(index)
  index = tonumber(index)
  local entry = index and state.history.entries[index]
  if not entry or not entry.preset then
    setStatus("load", "That recovery appearance is no longer available.", true)
    return false
  end
  local preset = entry.preset
  local _, options = getOptions()
  if options then
    saveAppearanceHistorySnapshot(options, "Before restoring appearance history")
  end
  resetLoadState()
  stateModel.prepareRecoveryLoad(state.load, preset, "Appearance History " .. tostring(index))
  loadPreset()
  if state.load.needsContinue then state.load.auto = true end
  return true
end

clearAppearanceHistory = function(confirm)
  if not confirm or not state.history.pendingClear then
    state.history.pendingClear = true
    return false, "Select Clear Appearance History again to confirm."
  end
  local removed = true
  for index = 1, 10 do
    local path = historyPath(index)
    if fileExists(path) and not deleteFile(path) then removed = false end
  end
  if fileExists(LAST_APPEARANCE_FILE) and not deleteFile(LAST_APPEARANCE_FILE) then
    removed = false
  end
  state.history.pendingClear = false
  refreshAppearanceHistory()
  return removed, removed and "Appearance history cleared."
    or "Some saved recovery appearances could not be deleted."
end

return _ENV
