local paths = require("modules/domain/paths")
local codecs = require("modules/domain/codecs")
local validRelativePath = paths.validRelativePath
local validTrashFilename = paths.validTrashFilename
local catalogEncode = codecs.catalogEncode
local catalogDecode = codecs.catalogDecode
local MAX_GROUP_ID_BYTES = 256

local function trashCatalogLines(trash, groups, maximumLines)
  local lines = {}
  for filename, item in pairs(trash or {}) do
    if not validTrashFilename(filename)
        or not validRelativePath(item.original or "") then return nil end
    table.insert(lines, "P\t" .. catalogEncode(filename) .. "\t" ..
      catalogEncode(item.original) .. "\t" .. catalogEncode(item.group or ""))
  end
  for groupId, group in pairs(groups or {}) do
    if type(groupId) ~= "string" or groupId == "" or #groupId > MAX_GROUP_ID_BYTES
        or not validRelativePath(group.root or "") then return nil end
    table.insert(lines, "G\t" .. catalogEncode(groupId) .. "\t" ..
      catalogEncode(group.root))
    for folder in pairs(group.folders or {}) do
      if not validRelativePath(folder) then return nil end
      table.insert(lines, "F\t" .. catalogEncode(groupId) .. "\t" ..
        catalogEncode(folder))
    end
    for folder in pairs(group.manualFolders or {}) do
      if not validRelativePath(folder) then return nil end
      table.insert(lines, "M\t" .. catalogEncode(groupId) .. "\t" ..
        catalogEncode(folder))
    end
  end
  table.sort(lines, function(a, b) return a:lower() < b:lower() end)
  if #lines > maximumLines then return nil end
  return lines
end

local function decode(contents, maximumLines)
  local originals, groups = {}, {}
  local lineCount = 0
  for line in (contents .. "\n"):gmatch("(.-)\n") do
    if line ~= "" then
      lineCount = lineCount + 1
      if lineCount > maximumLines then return nil, nil, false end
      local kind, first, second, third = line:match("^([PGFM])\t([^\t]+)\t([^\t]+)\t?(.*)$")
      if kind == "P" then
        local filename = catalogDecode(first)
        local original = catalogDecode(second)
        local group = third ~= "" and catalogDecode(third) or nil
        if not validTrashFilename(filename) or not validRelativePath(original)
            or (group and #group > MAX_GROUP_ID_BYTES) then return nil, nil, false end
        originals[filename] = { original = original, group = group }
      elseif kind == "G" then
        local groupId, root = catalogDecode(first), catalogDecode(second)
        if groupId == "" or #groupId > MAX_GROUP_ID_BYTES or not validRelativePath(root) then
          return nil, nil, false
        end
        groups[groupId] = groups[groupId] or { root = root, folders = {}, manualFolders = {} }
        groups[groupId].root = root
      elseif kind == "F" or kind == "M" then
        local groupId, folder = catalogDecode(first), catalogDecode(second)
        if groupId == "" or #groupId > MAX_GROUP_ID_BYTES or not validRelativePath(folder) then
          return nil, nil, false
        end
        groups[groupId] = groups[groupId] or {
          root = folder, folders = {}, manualFolders = {},
        }
        groups[groupId].manualFolders = groups[groupId].manualFolders or {}
        if kind == "M" then
          groups[groupId].manualFolders[folder] = true
        else
          groups[groupId].folders[folder] = true
        end
      else return nil, nil, false end
    end
  end
  for groupId, group in pairs(groups) do
    if not group.root or group.root == "" then groups[groupId] = nil end
  end
  for _, item in pairs(originals) do
    if item.group and not groups[item.group] then return nil, nil, false end
  end
  return originals, groups, true
end

return {encode = trashCatalogLines, decode = decode, MAX_GROUP_ID_BYTES = MAX_GROUP_ID_BYTES}
