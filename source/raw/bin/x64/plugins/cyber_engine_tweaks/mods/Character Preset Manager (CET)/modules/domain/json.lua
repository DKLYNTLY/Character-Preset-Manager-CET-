local MAX_JSON_DEPTH = 16
local HEXADECIMAL_RADIX = 16
local CONTROL_CHARACTER_LIMIT = 32
local LEADING_SURROGATE_MIN = 0xD800
local LEADING_SURROGATE_MAX = 0xDBFF
local TRAILING_SURROGATE_MIN = 0xDC00
local TRAILING_SURROGATE_MAX = 0xDFFF
local SURROGATE_BASE = 0x10000
local SURROGATE_RANGE = 0x400
local UNICODE_ESCAPE_WIDTH = 6
local UNICODE_DIGIT_COUNT = 4
local ESCAPED_CHARACTERS = {
  ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b",
  f = "\f", n = "\n", r = "\r", t = "\t",
}

local function decode(contents, encodeCodepoint)
  local position, length = 1, #contents
  local function skipSpace()
    while position <= length and contents:sub(position, position):match("%s") do
      position = position + 1
    end
  end
  local parseValue
  local function parseString()
    if contents:sub(position, position) ~= '"' then return nil, false end
    position = position + 1
    local parts = {}
    while position <= length do
      local character = contents:sub(position, position)
      if character == '"' then
        position = position + 1
        return table.concat(parts), true
      end
      if character == "\\" then
        local escaped = contents:sub(position + 1, position + 1)
        local replacements = ESCAPED_CHARACTERS
        if replacements[escaped] then
          parts[#parts + 1] = replacements[escaped]
          position = position + 2
        elseif escaped == "u" then
          local hexadecimal = contents:sub(position + 2, position + 5)
          local codepoint = #hexadecimal == UNICODE_DIGIT_COUNT and tonumber(hexadecimal, HEXADECIMAL_RADIX) or nil
          if not codepoint then return nil, false end
          position = position + UNICODE_ESCAPE_WIDTH
          if codepoint >= LEADING_SURROGATE_MIN and codepoint <= LEADING_SURROGATE_MAX
              and contents:sub(position, position + 1) == "\\u" then
            local trailing = tonumber(contents:sub(position + 2, position + 5), HEXADECIMAL_RADIX)
            if trailing and trailing >= TRAILING_SURROGATE_MIN and trailing <= TRAILING_SURROGATE_MAX then
              codepoint = SURROGATE_BASE + (codepoint - LEADING_SURROGATE_MIN) * SURROGATE_RANGE
                + trailing - TRAILING_SURROGATE_MIN
              position = position + UNICODE_ESCAPE_WIDTH
            end
          end
          local encodedOk, encoded = encodeCodepoint(codepoint)
          if encodedOk then
            parts[#parts + 1] = encoded
          else
            parts[#parts + 1] = "?"
          end
        else
          return nil, false
        end
      else
        if character:byte() < CONTROL_CHARACTER_LIMIT then return nil, false end
        parts[#parts + 1] = character
        position = position + 1
      end
    end
    return nil, false
  end
  local function parseNumber()
    local remaining = contents:sub(position)
    local token = remaining:match("^-?%d+%.?%d*[eE]?[+-]?%d*")
    if not token or token == "" then return nil, false end
    local value = tonumber(token)
    if not value then return nil, false end
    position = position + #token
    return value, true
  end
  local function parseArray(depth)
    position = position + 1
    local result = {}
    skipSpace()
    if contents:sub(position, position) == "]" then
      position = position + 1
      return result, true
    end
    while position <= length do
      local value, ok = parseValue(depth + 1)
      if not ok then return nil, false end
      result[#result + 1] = value
      skipSpace()
      local separator = contents:sub(position, position)
      if separator == "]" then
        position = position + 1
        return result, true
      end
      if separator ~= "," then return nil, false end
      position = position + 1
      skipSpace()
    end
    return nil, false
  end
  local function parseObject(depth)
    position = position + 1
    local result = {}
    skipSpace()
    if contents:sub(position, position) == "}" then
      position = position + 1
      return result, true
    end
    while position <= length do
      local key, keyOk = parseString()
      if not keyOk then return nil, false end
      skipSpace()
      if contents:sub(position, position) ~= ":" then return nil, false end
      position = position + 1
      local value, valueOk = parseValue(depth + 1)
      if not valueOk then return nil, false end
      result[key] = value
      skipSpace()
      local separator = contents:sub(position, position)
      if separator == "}" then
        position = position + 1
        return result, true
      end
      if separator ~= "," then return nil, false end
      position = position + 1
      skipSpace()
    end
    return nil, false
  end
  parseValue = function(depth)
    if depth > MAX_JSON_DEPTH then return nil, false end
    skipSpace()
    local character = contents:sub(position, position)
    if character == '"' then return parseString() end
    if character == "{" then return parseObject(depth) end
    if character == "[" then return parseArray(depth) end
    if contents:sub(position, position + 3) == "true" then
      position = position + 4
      return true, true
    end
    if contents:sub(position, position + 4) == "false" then
      position = position + 5
      return false, true
    end
    if contents:sub(position, position + 3) == "null" then
      position = position + 4
      return false, true
    end
    return parseNumber()
  end
  local result, ok = parseValue(0)
  skipSpace()
  if not ok or position <= length then return nil end
  return result
end

return { decode = decode }
