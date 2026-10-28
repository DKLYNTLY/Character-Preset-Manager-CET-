local paths = require("modules/domain/paths")
local codecs = require("modules/domain/codecs")
local libraryModel = require("modules/domain/library")
local validRelativePath = paths.validRelativePath
local catalogEncode, catalogDecode = codecs.catalogEncode, codecs.catalogDecode

local function decodeCatalogLine(line)
  local kind, first, second = line:match("^([PFX])\t([^\t]+)\t?([^\t]*)$")
  first = catalogDecode(first)
  second = catalogDecode(second)
  if kind == "P" and validRelativePath(first) and validRelativePath(second) then return kind, first, second, true end
  if (kind == "F" or kind == "X") and validRelativePath(first) then return kind, first, second, true end
  return nil, nil, nil, not line:match("%S")
end

local function encodeCatalog(presets, folders, manualFolders, ignoredPhysicalFolders, maximumLines, maximumBytes)
  local lines = {}
  for logicalName, preset in pairs(presets or {}) do
    if preset.storage and validRelativePath(preset.storage)
        and validRelativePath(logicalName) then
      table.insert(lines, "P\t" .. catalogEncode(preset.storage) .. "\t" ..
        catalogEncode(logicalName))
    end
  end
  for folder in pairs(folders or {}) do
    if not (manualFolders or {})[folder] and validRelativePath(folder) then
      table.insert(lines, "F\t" .. catalogEncode(folder))
    end
  end
  for folder in pairs(ignoredPhysicalFolders or {}) do
    if validRelativePath(folder) then
      table.insert(lines, "X\t" .. catalogEncode(folder))
    end
  end
  table.sort(lines, function(a, b) return a:lower() < b:lower() end)
  if #lines > maximumLines then
    return nil, "lines"
  end
  local catalogBytes = 0
  for _, line in ipairs(lines) do catalogBytes = catalogBytes + #line + 1 end
  if catalogBytes > maximumBytes then
    return nil, "bytes"
  end
  return lines
end

local function decodeInventory(contents, maximumLines, maximumEntries)
  local presets, folders = {}, {}
  local lineCount = 0
  for line in (contents .. "\n"):gmatch("(.-)\n") do
    if line ~= "" then
      lineCount = lineCount + 1
      if lineCount > maximumLines then
        return {}, {}, false, "lines"
      end
      local encodedName, count, format, encodedModified, fingerprint =
        line:match("^P2\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]*)\t([^\t]+)$")
      local kind, name = line:match("^([PF]):(.*)$")
      if encodedName then
        name = catalogDecode(encodedName)
        local entryCount = count ~= "-" and tonumber(count) or nil
        local presetFormat = format ~= "-" and tonumber(format) or nil
        if not validRelativePath(name)
            or (count ~= "-" and not entryCount)
            or (format ~= "-" and not presetFormat)
            or (entryCount and (entryCount < 1 or entryCount > maximumEntries))
            or (presetFormat and presetFormat < 1)
            or (fingerprint ~= "-" and not fingerprint:match("^2:%d+:%d+:%d+$")) then
          return {}, {}, false, "preset"
        end
        presets[name] = {
          entryCount = entryCount or 0,
          entryCountKnown = entryCount ~= nil,
          format = presetFormat,
          modified = catalogDecode(encodedModified),
          fingerprint = fingerprint ~= "-" and fingerprint or nil,
          metadataLoaded = false,
          lazy = true,
        }
      elseif kind == "P" and validRelativePath(name) then
        presets[name] = true
      elseif kind == "F" and validRelativePath(name) then
        folders[name] = true
      else
        return {}, {}, false, "line"
      end
    end
  end
  return presets, folders, true
end

local function encodeInventory(presets, folders)
  local lines = {}
  for name, preset in pairs(presets or {}) do
    local count = preset and preset.entryCountKnown == true
      and libraryModel.presetEntryCount(preset) or nil
    local format = tonumber(preset and preset.format)
    table.insert(lines, "P2\t" .. catalogEncode(name) .. "\t" ..
      (count and tostring(count) or "-") .. "\t" ..
      (format and tostring(format) or "-") .. "\t" ..
      catalogEncode(preset and preset.modified or "") .. "\t" ..
      tostring(preset and preset.fingerprint or "-"))
  end
  for name in pairs(folders or {}) do table.insert(lines, "F:" .. name) end
  table.sort(lines, function(a, b) return a:lower() < b:lower() end)
  return lines
end

return {decodeCatalogLine=decodeCatalogLine, encodeCatalog=encodeCatalog, decodeInventory=decodeInventory, encodeInventory=encodeInventory}
