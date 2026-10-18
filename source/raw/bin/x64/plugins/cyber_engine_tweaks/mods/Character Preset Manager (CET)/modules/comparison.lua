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


return _ENV
