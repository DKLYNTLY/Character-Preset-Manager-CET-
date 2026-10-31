local function preparePresetEntries(preset)
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

local function classify(valid, hasCandidate, claimed, target, current, savedIndex, liveCount)
  if not valid then return "Invalid", "invalid", false end
  if hasCandidate and not claimed then
    if target == nil then return "Missing", "missing", false end
    if current == target then return "Already matching", "matching", true end
    return "Will change", "changing", true
  end
  if savedIndex == 0 and (liveCount or 0) == 0 then return "Already matching", "matching", false end
  if (liveCount or 0) == 0 then return "Missing", "missing", false end
  return "Repeated or uncertain", "ambiguous", false
end
return {preparePresetEntries=preparePresetEntries,classify=classify}
