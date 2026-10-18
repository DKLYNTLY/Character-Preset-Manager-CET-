local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

nativeAppearance = {loadId = nil, pending = nil, sequence = 0, canceled = false}

function nativeAppearance.snapshot(options)
  if type(options) ~= "table" or #options > 4096 then
    return nil, "The editor's appearance options could not be read within the size limit."
  end
  local snapshot = {}
  local bytes = 0
  for position, option in ipairs(options) do
    local copied = {
      key = optionKey(option) or "", slot = optionSlot(option) or "",
      currIndex = tonumber(option.currIndex) or 0,
      isActive = option.isActive == true, isEditable = option.isEditable == true,
      choices = {},
    }
    if not optionIndexIsValid(copied.currIndex) then
      return nil, "An editor choice has an invalid number. Close and reopen the editor."
    end
    bytes = bytes + #copied.key + #copied.slot + 128
    for _, field in ipairs({"definitions", "options", "morphNames"}) do
      local ok, count = pcall(function() return #(option.info and option.info[field] or {}) end)
      if not ok or type(count) ~= "number" or count > 65536 then
        return nil, "An editor option's choices could not be read within the size limit."
      end
      if count > 0 then
        local choices = {}
        for index = 0, count - 1 do
          local value = choiceCollectionValue(option.info, field, index,
            field == "options" and "localizedName" or nil) or ""
          bytes = bytes + #value + 4
          if bytes > 1048576 then
            return nil, "The editor's appearance choices exceed the size limit for one request."
          end
          choices[index + 1] = value
        end
        copied.choices[field] = choices
      end
    end
    if bytes > 1048576 then return nil, "The editor's appearance choices exceed the size limit for one request." end
    snapshot[position] = copied
  end
  return snapshot
end

function nativeAppearance.sameSnapshot(left, right)
  if #left ~= #right then return false end
  for index, a in ipairs(left) do
    local b = right[index]
    if a.key ~= b.key or a.slot ~= b.slot or a.currIndex ~= b.currIndex
        or a.isActive ~= b.isActive or a.isEditable ~= b.isEditable then return false end
    for _, field in ipairs({"definitions", "options", "morphNames"}) do
      local first, second = a.choices[field] or {}, b.choices[field] or {}
      if #first ~= #second then return false end
      for choice, value in ipairs(first) do
        if value ~= second[choice] then return false end
      end
    end
  end
  return true
end

function nativeAppearance.finish()
  if nativeAppearance.pending then return false end
  if nativeAppearance.loadId and nativeAppearance.session == nativeService.session then
    local ended = nativeService.endAppearance(nativeAppearance.loadId)
    if not ended and nativeService.available then return false end
  end
  nativeAppearance.loadId = nil
  nativeAppearance.preset = nil
  nativeAppearance.canceled = false
  return true
end

function nativeAppearance.cancel()
  nativeAppearance.canceled = true
  if nativeAppearance.pending then
    nativeService.cancel(nativeAppearance.pending)
    return
  end
  nativeAppearance.finish()
end

function nativeAppearance.close()
  if nativeAppearance.session == nativeService.session then
    nativeAppearance.cancel()
    return
  end
  nativeAppearance.sequence = nativeAppearance.sequence + 1
  nativeAppearance.pending = nil
  nativeAppearance.loadId = nil
  nativeAppearance.preset = nil
  nativeAppearance.canceled = false
end

local function request(action, options, loadState, callback)
  if nativeAppearance.pending or nativeAppearance.canceled then
    return nil, "Wait for the current appearance request to finish."
  end
  local snapshot, snapshotError = nativeAppearance.snapshot(options)
  if not snapshot then return nil, snapshotError end
  local copiedState = {}
  for _, key in ipairs({"phase", "forceFull", "resetBefore", "returnToCleanup", "satisfied",
      "unconfirmed", "forcedKeys", "cleanupSkipped", "dependencyRemaps", "remaining",
      "needsContinue", "stalled", "previousUnresolvedSignature", "unresolvedRepeatCount"}) do
    copiedState[key] = loadState[key]
  end
  nativeAppearance.sequence = nativeAppearance.sequence + 1
  local sequence, session = nativeAppearance.sequence, nativeService.session
  local operation, errorText = nativeService.submit(action, {
    preset = nativeAppearance.preset, options = snapshot, state = copiedState,
    loadId = nativeAppearance.loadId, snapshot = sequence,
  }, function(status, result, id)
    if sequence ~= nativeAppearance.sequence or session ~= nativeService.session then return end
    nativeAppearance.pending = nil
    if action == "plan_load" and status == "complete" then nativeAppearance.loadId = id end
    if nativeAppearance.canceled then
      nativeAppearance.finish()
      callback("canceled")
      return
    end
    if status ~= "complete" or type(result) ~= "table" or result.loadId ~= nativeAppearance.loadId
        or result.snapshot ~= sequence then
      nativeAppearance.finish()
      callback("failed", result and result.error or "The appearance request could not finish safely.")
      return
    end
    if not state.app.inCustomization then
      nativeAppearance.finish()
      callback("canceled")
      return
    end
    local system, current, optionError = getOptions(true)
    local fresh, freshError
    if system and current then fresh, freshError = nativeAppearance.snapshot(current) end
    if not fresh then
      nativeAppearance.finish()
      callback("failed", freshError or optionError or "The current appearance could not be checked.")
      return
    end
    if not nativeAppearance.sameSnapshot(snapshot, fresh) then
      callback("stale")
      return
    end
    callback("ready", result, system, current)
  end)
  if operation then nativeAppearance.pending = operation end
  return operation, errorText
end

function nativeAppearance.start(preset, options, loadState, callback)
  if nativeAppearance.loadId or nativeAppearance.pending then
    return nil, "Finish or cancel the current appearance load first."
  end
  nativeAppearance.canceled = false
  local ok, copied = pcall(function() return json.decode(json.encode(preset)) end)
  if not ok or type(copied) ~= "table" then return nil, "The preset could not be prepared for loading." end
  nativeAppearance.preset = copied
  nativeAppearance.session = nativeService.session
  local operation, errorText = request("plan_load", options, loadState, callback)
  if not operation then nativeAppearance.preset = nil end
  return operation, errorText
end

function nativeAppearance.next(options, loadState, callback)
  if not nativeAppearance.loadId then return nil, "Start an appearance load before continuing it." end
  return request("load_step", options, loadState, callback)
end

return _ENV
