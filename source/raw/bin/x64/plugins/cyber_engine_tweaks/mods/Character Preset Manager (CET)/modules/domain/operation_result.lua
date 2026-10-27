local function copyTable(source, copies)
  if type(source) ~= "table" then return source end
  if copies[source] then return copies[source] end
  local copy = {}
  copies[source] = copy
  for key, value in pairs(source) do copy[copyTable(key, copies)] = copyTable(value, copies) end
  return copy
end

local function new(isSuccess, statusMessage, warnings)
  return {
    success = isSuccess == true,
    failure = isSuccess ~= true,
    warnings = copyTable(warnings or {}, {}),
    statusMessage = tostring(statusMessage or ""),
  }
end

local function success(statusMessage, warnings)
  return new(true, statusMessage, warnings)
end

local function failure(statusMessage, warnings)
  return new(false, statusMessage, warnings)
end

return {
  new = new,
  success = success,
  failure = failure,
}
