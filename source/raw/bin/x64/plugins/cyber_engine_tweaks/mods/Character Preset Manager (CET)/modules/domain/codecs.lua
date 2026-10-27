local HEXADECIMAL_RADIX = 16
local HEXADECIMAL_BYTE_WIDTH = 2
local HEXADECIMAL_BYTE_FORMAT = "%02X"
local PERCENT_BYTE_FORMAT = "%%%02X"
local function decodeHexadecimalBytes(value)
  return (value:gsub("(%x%x)", function(pair)
    return string.char(tonumber(pair, HEXADECIMAL_RADIX))
  end))
end

local function catalogEncode(value)
  return (tostring(value or ""):gsub("([^%w%-%._/])", function(character)
    return (PERCENT_BYTE_FORMAT):format(character:byte())
  end))
end

local function catalogDecode(value)
  return (tostring(value or ""):gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, HEXADECIMAL_RADIX))
  end))
end

local function hexEncode(value)
  return (value:gsub(".", function(character)
    return (HEXADECIMAL_BYTE_FORMAT):format(character:byte())
  end))
end

local function hexDecode(value)
  if #value % HEXADECIMAL_BYTE_WIDTH ~= 0 or not value:match("^%x+$") then return nil end
  return decodeHexadecimalBytes(value)
end

local function backupEncode(value)
  return hexEncode(tostring(value or ""))
end

local function backupDecode(value)
  if type(value) ~= "string" or #value % HEXADECIMAL_BYTE_WIDTH ~= 0
      or (value ~= "" and not value:match("^%x+$")) then return nil end
  return decodeHexadecimalBytes(value)
end

local function cleanField(value)
  return tostring(value or ""):gsub("[%c]", " ")
end

return {
  cleanField = cleanField,
  catalogEncode = catalogEncode,
  catalogDecode = catalogDecode,
  hexEncode = hexEncode,
  hexDecode = hexDecode,
  backupEncode = backupEncode,
  backupDecode = backupDecode,
}
