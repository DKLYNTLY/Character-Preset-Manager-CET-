local identities = require("modules/domain/identities")
local OCCURRENCE_SEPARATOR = "\31"
local CHOICE_OPTIONS = "options"
local CHOICE_DEFINITIONS = "definitions"
local CHOICE_MORPHS = "morphNames"

local function validSlot(slot, maximumBytes)
  if slot == "" or #slot > maximumBytes or slot:find("%c") then return nil end
  return slot
end
local function occurrenceKey(label, occurrence)
  return label .. OCCURRENCE_SEPARATOR .. tostring(occurrence)
end
local function catalogGroup(label, slot)
  return tostring(#label) .. ":" .. label .. tostring(#slot) .. ":" .. slot
end
local function choiceParts(choice)
  return tostring(choice or ""):match("^([%a]+):(.*)$")
end
local function choiceSource(field)
  return field == CHOICE_DEFINITIONS or field == CHOICE_OPTIONS or field == CHOICE_MORPHS
end
local function choiceIndexValid(index, maximumIndex)
  return type(index) == "number" and index == math.floor(index) and index >= 0 and index <= maximumIndex
end
local function choiceIndexes(values, indexes)
  for position, value in ipairs(values) do
    if value then
      if indexes[value] ~= nil then indexes[value] = false
      else indexes[value] = position - 1 end
    end
  end
end
local function numericChoiceIndex(index)
  return type(index) == "number" and index or nil
end
local function matchChoice(previous, index, value, wanted)
  if value == wanted then
    if previous ~= nil then return nil, true end
    return index, false
  end
  return previous, false
end
local function countsMatch(savedCount, liveCount)
  return (savedCount or 0) == (liveCount or 0)
end

return {validSlot=validSlot,occurrenceKey=occurrenceKey,catalogGroup=catalogGroup,choiceParts=choiceParts,
  choiceSource=choiceSource,choiceIndexValid=choiceIndexValid,choiceIndexes=choiceIndexes,
  numericChoiceIndex=numericChoiceIndex,matchChoice=matchChoice,countsMatch=countsMatch,

  stableChoiceIdentity=identities.stableChoiceIdentity,
  occurrenceKeyParts=identities.occurrenceKeyParts,optionIndexIsValid=identities.optionIndexIsValid,
  optionIndexValidationError=identities.optionIndexValidationError,isRuntimePointerText=identities.isRuntimePointerText}
