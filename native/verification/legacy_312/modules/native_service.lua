local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

nativeService = {
  available = false,
  session = 0,
  pending = {},
  pendingCount = 0,
  timer = 0,
  lastPolled = 0,
  reason = "Install all Character Preset Manager files, including the RED4ext plugin, then restart the game.",
}

local function call(name, ...)
  local ok, method = pcall(function() return Game and Game[name] end)
  if not ok or type(method) ~= "function" then return nil end
  local succeeded, value = pcall(method, ...)
  if not succeeded then return nil end
  return value
end

local function decode(value)
  if type(value) ~= "string" or #value > 2162688 or not json or not json.decode then return nil end
  local ok, result = pcall(json.decode, value)
  return ok and type(result) == "table" and result or nil
end

function nativeService.close()
  if nativeService.session ~= 0 then call("CPMNativeClose", nativeService.session) end
  nativeService.session = 0
  nativeService.pending = {}
  nativeService.pendingCount = 0
  nativeService.available = false
  nativeService.timer = 0
  nativeService.lastPolled = 0
  nativeService.reason = "Install all Character Preset Manager files, including the RED4ext plugin, then restart the game."
end

function nativeService.connect()
  nativeService.close()
  local status = decode(call("CPMNativeStatus"))
  if not status or status.available ~= true then return false, nativeService.reason end
  if status.protocol ~= 1 or status.version ~= VERSION then
    nativeService.reason = "The installed Character Preset Manager files do not match. Install the complete " .. VERSION .. " package and restart the game."
    return false, nativeService.reason
  end
  local session = tonumber(call("CPMNativeBegin"))
  if not session or session <= 0 then return false, nativeService.reason end
  nativeService.session = session
  nativeService.available = true
  nativeService.changes = status.changes
  nativeService.reason = ""
  return true
end

function nativeService.status()
  return decode(call("CPMNativeStatus"))
end

function nativeService.submit(action, payload, callback)
  if not nativeService.available or nativeService.session == 0 then return nil, nativeService.reason end
  if nativeService.pendingCount >= 16 then return nil, "Wait for the current preset actions to finish." end
  payload = payload or {}
  local encoded = "{}"
  if next(payload) ~= nil then
    local ok, value = pcall(json.encode, payload)
    if not ok or type(value) ~= "string" or #value > 2097152 then
      return nil, "The preset request could not be prepared within the size limit."
    end
    encoded = value
  end
  local response = decode(call("CPMNativeSubmit", nativeService.session, action, encoded))
  if not response or response.accepted ~= true or response.session ~= nativeService.session
      or type(response.operation) ~= "number" then
    return nil, response and response.error or "The native preset service did not accept the action."
  end
  nativeService.pending[response.operation] = {
    session = nativeService.session,
    action = action,
    callback = callback,
    completed = 0,
    total = 0,
  }
  nativeService.pendingCount = nativeService.pendingCount + 1
  return response.operation
end

function nativeService.cancel(operation)
  local pending = nativeService.pending[operation]
  if not pending or pending.session ~= nativeService.session then return false end
  local result = decode(call("CPMNativeCancel", nativeService.session, operation))
  return result and result.accepted == true, result and result.error
end

function nativeService.endAppearance(operation)
  local result = decode(call("CPMNativeEndAppearance", nativeService.session, operation))
  return result and result.accepted == true, result and result.error
end

function nativeService.update(elapsed)
  if not nativeService.available or nativeService.pendingCount == 0 then return end
  nativeService.timer = nativeService.timer + math.max(0, tonumber(elapsed) or 0)
  if nativeService.timer < 0.05 then return end
  nativeService.timer = 0
  local checked = 0
  local ids = {}
  for id in pairs(nativeService.pending) do ids[#ids + 1] = id end
  table.sort(ids)
  local start = 1
  for index, id in ipairs(ids) do
    if id > nativeService.lastPolled then start = index; break end
  end
  for index = 1, #ids do
    local id = ids[(start + index - 2) % #ids + 1]
    local pending = nativeService.pending[id]
    if pending then
      checked = checked + 1
      nativeService.lastPolled = id
      local result = decode(call("CPMNativePoll", pending.session, id, true))
      local finished = result and (result.status == "complete" or result.status == "failed" or result.status == "canceled")
      local current = result and result.accepted == true and result.session == nativeService.session
        and pending.session == nativeService.session and result.operation == id
      if not current or finished then
        nativeService.pending[id] = nil
        nativeService.pendingCount = nativeService.pendingCount - 1
        if pending.callback and pending.session == nativeService.session then
          local status = current and result.status or "failed"
          local value = current and result.result or {error = "That preset action is no longer current. Refresh and try again."}
          local ok, errorText = pcall(pending.callback, status, value, id)
          if not ok then log("[NATIVE SERVICE] The completed action could not update its interface: " .. tostring(errorText), "error") end
        end
      else
        pending.completed = tonumber(result.completed) or 0
        pending.total = tonumber(result.total) or 0
      end
      if checked >= 4 then break end
    end
  end
end

return _ENV
