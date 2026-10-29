local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime
local matching = require("modules/domain/matching")
local comparison = require("modules/domain/comparison")

helpers.preparePresetEntries = function(preset)
  return comparison.preparePresetEntries(preset)
end

local function liveAppearanceIndex(options)
  local counts, slotCounts, byKey, bySlot, ordered = {}, {}, {}, {}, {}
  for position, option in ipairs(options or {}) do
    local label = optionKey(option)
    if label and option.isEditable and option.isActive then
      counts[label] = (counts[label] or 0) + 1
      local key = matching.occurrenceKey(label, counts[label])
      local slot = optionSlot(option)
      local slotOccurrence = nil
      if slot then
        slotCounts[slot] = (slotCounts[slot] or 0) + 1
        slotOccurrence = slotCounts[slot]
      end
      local item = {
        option = option,
        key = key,
        label = label,
        occurrence = counts[label],
        slot = slot,
        slotOccurrence = slotOccurrence,
        position = position,
      }
      byKey[key] = item
      if slot then bySlot[matching.occurrenceKey(slot, slotOccurrence)] = item end
      ordered[#ordered + 1] = item
    end
  end
  return counts, slotCounts, byKey, bySlot, ordered
end

comparePresetWithCurrent = function(preset, options)
  local _, savedCounts, entries, savedSlotCounts = helpers.preparePresetEntries(preset)
  local liveCounts, liveSlotCounts, byKey, bySlot, liveEntries = liveAppearanceIndex(options)
  local result = {
    total = #entries,
    matching = 0,
    changing = 0,
    missing = 0,
    ambiguous = 0,
    invalid = 0,
    clearing = 0,
    details = {},
  }
  local claimed = {}
  for _, entry in ipairs(entries) do
    local candidate = nil
    if matching.countsMatch(liveCounts[entry.label], savedCounts[entry.label]) then
      candidate = byKey[entry.key]
    end
    if not candidate and entry.slot
        and matching.countsMatch(liveSlotCounts[entry.slot], savedSlotCounts[entry.slot]) then
      candidate = bySlot[entry.slot .. "\31" .. tostring(entry.slotOccurrence)]
    end
    local status, current = nil, candidate and tonumber(candidate.option.currIndex) or nil
    local valid = optionIndexIsValid(entry.index)
    local target = entry.index
    if valid and candidate and not claimed[candidate.key] and entry.choice then
      target = optionChoiceIndex(candidate.option, entry.choice)
    end
    local counter, claim
    status, counter, claim = comparison.classify(valid, candidate ~= nil,
      candidate and claimed[candidate.key], target, current, entry.index, liveCounts[entry.label])
    result[counter] = result[counter] + 1
    if claim then claimed[candidate.key] = true end
    result.details[#result.details + 1] = {
      label = entry.label,
      slot = entry.slot,
      status = status,
      current = current,
      target = entry.index,
    }
  end
  for _, live in ipairs(liveEntries) do
    if live.occurrence > (savedCounts[live.label] or 0)
        and (tonumber(live.option.currIndex) or 0) ~= 0 then
      result.clearing = result.clearing + 1
      result.details[#result.details + 1] = {
        label = live.label,
        slot = live.slot,
        status = "Will clear",
        current = tonumber(live.option.currIndex) or 0,
        target = 0,
      }
    end
  end
  return result
end

compareSelectedPreset = function()
  local name = state.library.selected
  local preset = name and hydrateNamedPreset(name)
  local _, options = getOptions()
  if not preset or not options then
    state.load.comparison = nil
    return nil
  end
  local result = comparePresetWithCurrent(preset, options)
  state.load.comparison = result
  state.load.preflight = {
    total = result.total,
    available = result.matching + result.changing,
    unavailable = result.missing,
    ambiguous = result.ambiguous,
    invalid = result.invalid,
  }
  state.load.preflightDirty = false
  state.load.preflightPresetName = name
  return result
end

return _ENV
