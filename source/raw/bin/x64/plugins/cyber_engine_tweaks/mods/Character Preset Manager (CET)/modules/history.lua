local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime
local stateModel = require("modules/domain/state")
local paths = require("modules/domain/paths")
local appearanceHistory = require("modules/domain/appearance_history")
local preset9 = require("modules/domain/preset9_codec")
local records9 = require("modules/domain/format9_codec")
local files = require("modules/adapters/files")

local function historyPath(index)
  return paths.historyPath(index, HISTORY_FILE_PREFIX)
end

local function snapshotFromOptions(options, action)
  local started=helpers.loadProfile and helpers.loadClock()
  local ok, captured, _, canonical = pcall(helpers.capturePreset9, options)
  if helpers.loadProfile then helpers.loadProfile.add("historyCapture",math.max(0,helpers.loadClock()-started)) end
  if not ok or not captured then return nil end
  local timestamp = logTimestamp()
  local preset = appearanceHistory.snapshot(captured.entries,action,timestamp,CURRENT_PRESET_FORMAT,MOD_NAME)
  preset.format9Rows = captured.format9Rows
  preset.sourceBody, preset.sourceVoice = captured.sourceBody, captured.sourceVoice
  return preset,canonical
end

local function sameAppearance(first,second)
  return appearanceHistory.sameAppearance(first,second)
end

local function preparationSignature(options)
  local parts,bytes={},0
  local function add(value)
    local text=type(value)..":"..tostring(value)
    bytes=bytes+#text+16
    if bytes>MAX_PRESET_BYTES then error("Undo state check exceeds its limit.") end
    parts[#parts+1]=#text..":"..text
  end
  local function read(callback)
    local ok,value=pcall(callback)
    if ok then return value end
  end
  add(#options)
  for _,option in ipairs(options) do
    local info=read(function()return option.info end)
    add(read(function()return stableRuntimeValue(info.name)end))
    add(read(function()return stableRuntimeValue(info.uiSlot)end))
    local index=read(function()return tonumber(option.currIndex)end)
    local active=read(function()return option.isActive end)
    local editable=read(function()return option.isEditable end)
    add(index);add(active);add(editable)
    if active and editable and optionIndexIsValid(index) then
      for _,field in ipairs({"definitions","morphNames","options"}) do
        local collection=read(function()return info[field]end)
        local count=read(function()return #collection end)
        add(field);add(count)
        if count and index<count then
          local item=read(function()return collection[index+1]end)
          if field=="options" then
            local names=read(function()return item.names end)
            local members=read(function()return #names end)
            add(members)
            if members and members<=512 then
              for member=1,members do add(read(function()return stableRuntimeValue(names[member])end))end
            end
          else
            add(read(function()return stableRuntimeValue(type(item)=="string" and item or item[field=="definitions" and "name" or "morphName"])end))
          end
        end
      end
    end
  end
  return table.concat(parts)
end

local preparation=require("modules/application/undo_preparation").new({
  signature=preparationSignature,
  capture=snapshotFromOptions,
  previous=function()
    local started=helpers.loadProfile and helpers.loadClock()
    local bytes=readBoundedFile(LAST_APPEARANCE_FILE,MAX_PRESET_BYTES)
    local previous
    if bytes then
      local header=bytes:sub(1,64):gsub("\r\n","\n")
      if header:sub(1,25)=="# CPM Preset\n# Format: 9\n" then previous=preset9.decode(bytes,false)
      else previous=readPresetFile(LAST_APPEARANCE_FILE) end
    elseif fileExists(LAST_APPEARANCE_FILE) then
      return nil,nil,"The previous Undo file could not be read. Loading stopped."
    end
    if helpers.loadProfile then helpers.loadProfile.add("historyNewest",math.max(0,helpers.loadClock()-started))end
    return previous,bytes or false
  end,
  same=function(first,second,canonical)
    local started=helpers.loadProfile and helpers.loadClock()
    local identical
    if canonical and second.format==9 then
      identical=canonical==records9.encode(second.format9Rows,second.sourceBody,second.sourceVoice)
    else identical=sameAppearance(first,second) end
    if helpers.loadProfile then helpers.loadProfile.add("historyCompare",math.max(0,helpers.loadClock()-started))end
    if identical then log("[APPEARANCE HISTORY] Skipped an identical recovery snapshot.","info")end
    return identical
  end,
  encode=function(preset)
    local contents=preset9.encode(preset,MOD_NAME)
    local decoded=contents and preset9.decode(contents,false)
    if decoded then return {contents=contents,preset=decoded}end
  end,
  write=function(prepared,expected)
    local function unchanged()
      if expected==false then return not fileExists(LAST_APPEARANCE_FILE)end
      return readBoundedFile(LAST_APPEARANCE_FILE,MAX_PRESET_BYTES)==expected
    end
    if not unchanged() then return false end
    local started=helpers.loadProfile and helpers.loadClock()
    local written=atomicReplace(LAST_APPEARANCE_FILE,function(temporary)
      if not unchanged() then return false end
      local wrote=files.writeFileSafely(io,temporary,"w",function(file)
        return file:write(prepared.contents)~=nil and file:flush()~=nil
      end)
      if not wrote then return false end
      local actual=readBoundedFile(temporary,MAX_PRESET_BYTES)
      return actual and actual:gsub("\r\n","\n")==prepared.contents and unchanged()
    end,"undo snapshot")
    if written then prepared.preset.fingerprint=fileFingerprint(LAST_APPEARANCE_FILE,MAX_PRESET_BYTES)end
    if helpers.loadProfile then helpers.loadProfile.add("historyNewWrite",math.max(0,helpers.loadClock()-started))end
    return written
  end,
  installed=function(preset)
    state.history.entries={appearanceHistory.entry(1,LAST_APPEARANCE_FILE,preset,state.presetEntryCount(preset))}
    state.load.recoverySnapshotAvailable=true
    log(("[APPEARANCE HISTORY] Saved '%s' with %d options."):format(tostring(preset.notes),#preset.entries),"info")
  end,
  ready=function(prepared,expected)
    local actual=readBoundedFile(LAST_APPEARANCE_FILE,MAX_PRESET_BYTES)
    if prepared then return actual and actual:gsub("\r\n","\n")==prepared.contents end
    return actual==expected
  end,
})

helpers.beginUndoPreparation=function(options,action,context)
  local ok,job,reason=pcall(preparation.begin,options,action,context)
  if not ok then return nil,"Undo preparation failed. Loading stopped." end
  return job,reason
end

helpers.stepUndoPreparation=function(job,options,context)
  local ok,status,reason=pcall(preparation.step,job,options,context)
  if not ok then return "error","Undo preparation failed. Loading stopped." end
  return status,reason
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
  if not options or not saveAppearanceHistorySnapshot(options, "Before undoing last load") then
    setStatus("load","Undo stopped because the current appearance could not be saved safely.",true)
    return false
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
