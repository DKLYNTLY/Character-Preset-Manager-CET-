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
  local started=helpers.loadProfile and helpers.loadClock()
  local ok, captured = pcall(helpers.capturePreset9, options)
  if helpers.loadProfile then helpers.loadProfile.add("historyCapture",math.max(0,helpers.loadClock()-started)) end
  if not ok or not captured then return nil end
  local timestamp = logTimestamp()
  local preset = appearanceHistory.snapshot(captured.entries,action,timestamp,CURRENT_PRESET_FORMAT,MOD_NAME)
  preset.format9Rows = captured.format9Rows
  preset.sourceBody, preset.sourceVoice = captured.sourceBody, captured.sourceVoice
  return preset
end

local function sameAppearance(first,second)
  return appearanceHistory.sameAppearance(first,second)
end

refreshAppearanceHistory = function()
  state.history.entries = {}
  local path=LAST_APPEARANCE_FILE
  local preset=readPresetFile(path)
  if not preset and not fileExists(path) then
    path=historyPath(1)
    preset=readPresetFile(path)
  end
  if preset then
    state.history.entries[1]=appearanceHistory.entry(1,path,preset,state.presetEntryCount(preset))
  end
  state.load.recoverySnapshotAvailable=#state.history.entries>0
  return state.history.entries
end

saveAppearanceHistorySnapshot = function(options, action)
  local preset = snapshotFromOptions(options, action)
  if not preset then
    log("[APPEARANCE HISTORY] The current appearance could not be read safely, so no recovery copy was saved.", "warn")
    return false
  end
  local started=helpers.loadProfile and helpers.loadClock()
  local newest = readPresetFile(LAST_APPEARANCE_FILE)
  if helpers.loadProfile then helpers.loadProfile.add("historyNewest",math.max(0,helpers.loadClock()-started)) end
  started=helpers.loadProfile and helpers.loadClock()
  local identical=newest and sameAppearance(preset,newest)
  if helpers.loadProfile then helpers.loadProfile.add("historyCompare",math.max(0,helpers.loadClock()-started)) end
  if identical then
    log("[APPEARANCE HISTORY] Skipped an identical recovery snapshot.", "info")
    return true
  end
  started=helpers.loadProfile and helpers.loadClock()
  local written=writePresetPath(LAST_APPEARANCE_FILE,preset)
  if helpers.loadProfile then helpers.loadProfile.add("historyNewWrite",math.max(0,helpers.loadClock()-started)) end
  if not written then
    log("[APPEARANCE HISTORY] The undo snapshot could not be saved. The previous copy was kept.","warn")
    return false
  end
  state.history.entries={appearanceHistory.entry(1,LAST_APPEARANCE_FILE,preset,state.presetEntryCount(preset))}
  state.load.recoverySnapshotAvailable=true
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
    saveAppearanceHistorySnapshot(options, "Before undoing last load")
  end
  resetLoadState()
  stateModel.prepareRecoveryLoad(state.load, preset, "Undo Last Load")
  loadPreset()
  if state.load.needsContinue then state.load.auto = true end
  return true
end

clearAppearanceHistory = function()
  return false,"The history list was removed. Undo Last Load uses one recovery snapshot."
end

return _ENV
