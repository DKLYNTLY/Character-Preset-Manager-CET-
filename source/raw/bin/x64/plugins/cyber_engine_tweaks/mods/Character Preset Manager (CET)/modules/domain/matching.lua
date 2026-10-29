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
local function unavailableReason(choiceUnavailable, countMatches, indexIsValid)
  if choiceUnavailable then return "choice" end
  if not countMatches then return "ambiguous" end
  if not indexIsValid then return "invalid" end
end
local function disposition(current, target, satisfied, unconfirmed)
  if current == target then return "matching" end
  if satisfied and unconfirmed then return "unconfirmed" end
  if satisfied then return "reverted" end
  return "pending"
end
local function keepRemap(remap, satisfied, label, occurrence, position, slot, slotOccurrence, current, activeSlotCounts)
  return remap and satisfied
    and label == remap.label and occurrence == remap.occurrence
    and position == remap.position and slot == remap.slot
    and slotOccurrence == remap.slotOccurrence and current == remap.target
    and (not remap.slot or (activeSlotCounts[remap.slot] or 0) == remap.slotCount)
end
local function cleanupNeeded(key, occurrence, savedCount, savedSlotEntry, current, keep, skipped, stageApplied)
  local extraByLabel = occurrence > (savedCount or 0)
  local clearSlotReplacement = savedSlotEntry and tonumber(savedSlotEntry.index) == 0
  return key and extraByLabel and (not savedSlotEntry or clearSlotReplacement)
    and current ~= 0 and not keep and not skipped and not stageApplied
end
local function longSettleText(text)
  text = text:lower()
  return text:find("hair", 1, true) ~= nil or text:find("beard", 1, true) ~= nil
    or text:find("cyberware", 1, true) ~= nil or text:find("_switcher", 1, true) ~= nil
    or text:find("heterochromia", 1, true) ~= nil or text:find("makeuplips_type", 1, true) ~= nil
end
local function secondaryText(text)
  text = text:lower()
  for _,word in ipairs({"color", "colour", "tint", "intensity", "opacity", "_part_", "_size"}) do
    if text:find(word, 1, true) then return true end
  end
  return false
end
local function anchoredPosition(previousLive, previousSaved, nextLive, nextSaved, savedTarget)
  return previousLive == previousSaved and nextLive == nextSaved and savedTarget == nil
end
local function canApplyEntry(entry, slot, liveCount, savedCount)
  return liveCount == savedCount and (not entry.slot or entry.slot == slot)
end
local function sameOptionIdentity(pending, label, occurrence, slot)
  return label == pending.label and occurrence == pending.occurrence and slot == pending.slot
end
local function sameRemapIdentity(remap, label, occurrence, position, slot, slotOccurrence, activeSlotCounts)
  return label == remap.label and occurrence == remap.occurrence
    and position == remap.position and slot == remap.slot and slotOccurrence == remap.slotOccurrence
    and (not remap.slot or (activeSlotCounts[remap.slot] or 0) == remap.slotCount)
end
local function completionResult(cleanupSkipped, unconfirmed)
  if cleanupSkipped > 0 or unconfirmed > 0 then return "complete-with-warning", "warn" end
  return "complete", "complete"
end
return {validSlot=validSlot,occurrenceKey=occurrenceKey,catalogGroup=catalogGroup,choiceParts=choiceParts,
  choiceSource=choiceSource,choiceIndexValid=choiceIndexValid,choiceIndexes=choiceIndexes,
  numericChoiceIndex=numericChoiceIndex,matchChoice=matchChoice,countsMatch=countsMatch,
  unavailableReason=unavailableReason,disposition=disposition,keepRemap=keepRemap,cleanupNeeded=cleanupNeeded,
  longSettleText=longSettleText,secondaryText=secondaryText,anchoredPosition=anchoredPosition,
  completionResult=completionResult,canApplyEntry=canApplyEntry,
  sameOptionIdentity=sameOptionIdentity,sameRemapIdentity=sameRemapIdentity,stableChoiceIdentity=identities.stableChoiceIdentity,
  occurrenceKeyParts=identities.occurrenceKeyParts,optionIndexIsValid=identities.optionIndexIsValid,
  optionIndexValidationError=identities.optionIndexValidationError,isRuntimePointerText=identities.isRuntimePointerText}
