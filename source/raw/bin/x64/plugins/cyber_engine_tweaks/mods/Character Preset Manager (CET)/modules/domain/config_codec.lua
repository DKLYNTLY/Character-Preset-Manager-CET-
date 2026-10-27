local MAX_CONFIG_BYTES = 16384
local DEFAULT_PRESET_SORT = "name"
local MODIFIED_PRESET_SORT = "modified"
local RETIRED_SETTINGS = {
  discoveryReminder = true,
  clothingWarning = true,
  activityLogDetail = true,
  nativePanel = true,
  historySize = true,
  saveBeforeHistoryRestore = true,
  comparisonDetails = true,
  missingWarnings = true,
  cetFallback = true,
}

local function defaultConfig()
  return { presetSort = DEFAULT_PRESET_SORT }
end

local function newDecoder()
  local config = defaultConfig()
  local function readLine(line)
    local key, value = line:match("^%s*([%a%d]+)%s*=%s*([%a%d]+)%s*$")
    if key == "presetSort" and (value == DEFAULT_PRESET_SORT or value == MODIFIED_PRESET_SORT) then
      config.presetSort = value
    elseif RETIRED_SETTINGS[key] then
    elseif line:match("%S") and not line:match("^%s*#") then
      return "[CONFIG] Ignored unsupported config line: " .. tostring(line), "warn"
    end
  end
  return { config = config, readLine = readLine }
end

local function encode(preferences)
  return "presetSort=" .. tostring(preferences.presetSort) .. "\n"
end

local function decode(contents)
  local decoder = newDecoder()
  local diagnostics = {}
  local position = 1
  while position <= #contents do
    local newline = contents:find("\n", position, true)
    local line = contents:sub(position, newline and newline - 1 or #contents)
    position = newline and newline + 1 or #contents + 1
    local message, level = decoder.readLine(line)
    if message then diagnostics[#diagnostics + 1] = {message = message, level = level} end
  end
  return decoder.config, diagnostics
end

return {
  defaultConfig = defaultConfig,
  decode = decode,
  encode = encode,
  MAX_CONFIG_BYTES = MAX_CONFIG_BYTES,
}
