local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

helpers.preparePresetEntries = function(preset)
  local values, savedCounts, orderedEntries = {}, {}, {}
  local savedSlotCounts, savedEntryByKey = {}, {}
  for _, entry in ipairs((preset and preset.entries) or {}) do
    local label = tostring(entry.key or "")
    if label ~= "" then
      savedCounts[label] = (savedCounts[label] or 0) + 1
      local savedKey = label .. "\31" .. tostring(savedCounts[label])
      local slot = tostring(entry.slot or "")
      local slotOccurrence = nil
      if slot ~= "" then
        savedSlotCounts[slot] = (savedSlotCounts[slot] or 0) + 1
        slotOccurrence = savedSlotCounts[slot]
      end
      local prepared = {
        key = savedKey,
        label = label,
        index = tonumber(entry.index) or 0,
        slot = slot ~= "" and slot or nil,
        slotOccurrence = slotOccurrence,
        choice = entry.choice,
        position = #orderedEntries + 1,
      }
      values[savedKey] = prepared.index
      orderedEntries[#orderedEntries + 1] = prepared
      savedEntryByKey[savedKey] = prepared
    end
  end
  return values, savedCounts, orderedEntries, savedSlotCounts,
    #orderedEntries, savedEntryByKey
end

local function liveAppearanceIndex(options)
  local counts, slotCounts, byKey, bySlot, ordered = {}, {}, {}, {}, {}
  for position, option in ipairs(options or {}) do
    local label = optionKey(option)
    if label and option.isEditable and option.isActive then
      counts[label] = (counts[label] or 0) + 1
      local key = label .. "\31" .. tostring(counts[label])
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
      if slot then bySlot[slot .. "\31" .. tostring(slotOccurrence)] = item end
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
    if (liveCounts[entry.label] or 0) == (savedCounts[entry.label] or 0) then
      candidate = byKey[entry.key]
    end
    if not candidate and entry.slot
        and (liveSlotCounts[entry.slot] or 0) == (savedSlotCounts[entry.slot] or 0) then
      candidate = bySlot[entry.slot .. "\31" .. tostring(entry.slotOccurrence)]
    end
    local status, current = nil, candidate and tonumber(candidate.option.currIndex) or nil
    if not optionIndexIsValid(entry.index) then
      status = "Invalid"
      result.invalid = result.invalid + 1
    elseif candidate and not claimed[candidate.key] then
      local target = entry.index
      if entry.choice then target = optionChoiceIndex(candidate.option, entry.choice) end
      if target == nil then
        status = "Missing"
        result.missing = result.missing + 1
      elseif current == target then
        status = "Already matching"
        result.matching = result.matching + 1
        claimed[candidate.key] = true
      else
        status = "Will change"
        result.changing = result.changing + 1
        claimed[candidate.key] = true
      end
    elseif entry.index == 0 and (liveCounts[entry.label] or 0) == 0 then
      status = "Already matching"
      result.matching = result.matching + 1
    elseif (liveCounts[entry.label] or 0) == 0 then
      status = "Missing"
      result.missing = result.missing + 1
    else
      status = "Repeated or uncertain"
      result.ambiguous = result.ambiguous + 1
    end
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
