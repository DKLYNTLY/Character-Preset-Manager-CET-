local MAX_OPTION_INDEX = 4294967295
local DEFINITION_IDENTITY_FIELD = "definitions"
local OPTION_IDENTITY_FIELD = "options"
local MORPH_IDENTITY_FIELD = "morphNames"
local OCCURRENCE_SEPARATOR = "\31"
local DEFAULT_OCCURRENCE = 1

local function isRuntimePointerText(value)
  value = tostring(value or "")
  return value:match("^userdata: 0x%x+$") ~= nil
    or value:match("^table: 0x%x+$") ~= nil
    or value:match("^function: 0x%x+$") ~= nil
    or value:match("^thread: 0x%x+$") ~= nil
end

local function stableChoiceIdentity(choice)
  local field, value = tostring(choice or ""):match("^([%a]+):(.*)$")
  if value == "" or (field ~= DEFINITION_IDENTITY_FIELD and field ~= OPTION_IDENTITY_FIELD
      and field ~= MORPH_IDENTITY_FIELD) then return nil end
  if isRuntimePointerText(value) then return nil end
  return field .. ":" .. value
end

local function occurrenceKeyParts(value)
  local raw = tostring(value or "")
  local key, occurrence = raw:match("^(.-)" .. OCCURRENCE_SEPARATOR .. "(%d+)$")
  return key or raw, tonumber(occurrence) or DEFAULT_OCCURRENCE
end

local function optionIndexValidationError(index)
  if type(index) ~= "number" then return "not numeric" end
  if index ~= math.floor(index) then return "not an integer" end
  if index < 0 then return "below zero" end
  if index > MAX_OPTION_INDEX then return "above the native Uint32 maximum" end
  return nil
end

local function optionIndexIsValid(index)
  return optionIndexValidationError(index) == nil
end

return {
  isRuntimePointerText = isRuntimePointerText,
  stableChoiceIdentity = stableChoiceIdentity,
  occurrenceKeyParts = occurrenceKeyParts,
  optionIndexValidationError = optionIndexValidationError,
  optionIndexIsValid = optionIndexIsValid,
  MAX_OPTION_INDEX = MAX_OPTION_INDEX,
}
