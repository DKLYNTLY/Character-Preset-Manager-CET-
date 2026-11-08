local names = require("modules/domain/names")
local MAX_ACTION_BYTES = 512

local function sameAppearance(first, second)
  if first and second and first.format == 9 and second.format == 9 then
    return require("modules/domain/preset9_codec").sameAppearance(first, second)
  end
  if not first or not second or not first.entries or not second.entries
      or #first.entries ~= #second.entries then return false end
  for index, entry in ipairs(first.entries) do
    local other = second.entries[index]
    if not other or tostring(entry.key) ~= tostring(other.key)
        or tonumber(entry.index) ~= tonumber(other.index)
        or tostring(entry.slot or "") ~= tostring(other.slot or "")
        or tostring(entry.choice or "") ~= tostring(other.choice or "") then
      return false
    end
  end
  return true
end

local function snapshot(entries,action,timestamp,currentFormat,modName)
  return {
    format = currentFormat,
    source = modName .. " appearance history",
    created = timestamp,
    modified = timestamp,
    notes = names.sanitizeMetadata(action or "Automatic recovery snapshot", MAX_ACTION_BYTES),
    tags = "appearance history",
    favorite = false,
    managedByCpm = true,
    presetName = "Appearance History",
    libraryFolder = "",
    entries = entries,
    entryCount = #entries,
  }
end

local function entry(index,path,preset,count)
  return {index=index,path=path,preset=preset,date=preset.modified or preset.created or "Date unavailable",
    action=preset.notes or "Automatic recovery snapshot",count=count}
end
return {sameAppearance=sameAppearance,snapshot=snapshot,entry=entry}
