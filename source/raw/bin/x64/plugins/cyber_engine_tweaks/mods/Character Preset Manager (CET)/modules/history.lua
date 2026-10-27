local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime
local stateModel = require("modules/domain/state")
local paths = require("modules/domain/paths")

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
  return {
    format = CURRENT_PRESET_FORMAT,
    source = MOD_NAME .. " appearance history",
    created = timestamp,
    modified = timestamp,
    notes = sanitizeMetadata(action or "Automatic recovery snapshot", 512),
    tags = "appearance history",
    favorite = false,
    managedByCpm = true,
    presetName = "Appearance History",
    libraryFolder = "",
    entries = entries,
    entryCount = #entries,
  }
end

local function sameAppearance(first, second)
  if not first or not second or not first.entries or not second.entries
      or #first.entries ~= #second.entries then return false end
  for index, entry in ipairs(first.entries) do
    local other = second.entries[index]
    if not other or tostring(entry.key) ~= tostring(other.key)
        or tonumber(entry.index) ~= tonumber(other.index)
        or tostring(entry.slot or "") ~= tostring(other.slot or "")
        or tostring(entry.choice or "") ~= tostring(other.choice or "") then
      return false
    end
  end
  return true
end

refreshAppearanceHistory = function()
  state.history.entries = {}
  local limit = APPEARANCE_HISTORY_LIMIT
  for index = 1, limit do
    local path = historyPath(index)
    local preset = readPresetFile(path)
    if preset then
      state.history.entries[#state.history.entries + 1] = {
        index = index,
        path = path,
        preset = preset,
        date = preset.modified or preset.created or "Date unavailable",
        action = preset.notes or "Automatic recovery snapshot",
        count = state.presetEntryCount(preset),
      }
    end
  end
  state.load.recoverySnapshotAvailable = #state.history.entries > 0
    or fileExists(LAST_APPEARANCE_FILE)
  return state.history.entries
end

trimAppearanceHistory = function()
  local limit = APPEARANCE_HISTORY_LIMIT
  for index = limit + 1, 10 do
    local path = historyPath(index)
    if fileExists(path) then deleteFile(path) end
  end
  refreshAppearanceHistory()
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
  for index = limit, 2, -1 do
    local older = readPresetFile(historyPath(index - 1))
    if older and not writePresetPath(historyPath(index), older) then
      log("[APPEARANCE HISTORY] Older entries could not be moved safely to make room for the new recovery copy.", "warn")
      return false
    end
  end
  if not writePresetPath(historyPath(1), preset) then
    log("[APPEARANCE HISTORY] The new recovery copy could not be saved.", "warn")
    return false
  end
  for index = limit + 1, 10 do deleteFile(historyPath(index)) end
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
