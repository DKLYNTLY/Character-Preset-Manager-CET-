local paths = require("modules/domain/paths")
local names = require("modules/domain/names")
local codecs = require("modules/domain/codecs")
local catalogEncode, catalogDecode = codecs.catalogEncode, codecs.catalogDecode
local validRelativePath = paths.validRelativePath
local decode = codecs.backupDecode

local function newReader() return {backup={folders={},presets={},names={}},lineNumber=0} end
local function readLine(context, line, maximumPresetBytes)
  local backup = context.backup
    line = line:gsub("\r$", "")
    context.lineNumber = context.lineNumber + 1
    if context.lineNumber == 1 then
      if line ~= "CPMBACKUP\t1" then return "invalid_header" end
    else
      local configValue = line:match("^CONFIG\t(.*)$")
      local folderValue = line:match("^F\t([^\t]+)$")
      local nameValue, contentsValue = line:match("^P\t([^\t]+)\t([%x]+)$")
      if configValue then
        if backup.config ~= nil then return "duplicate_config" end
        backup.config = decode(configValue)
      elseif folderValue then
        local folder = catalogDecode(folderValue)
        if not validRelativePath(folder) then return "unsafe_folder" end
        backup.folders[folder] = true
      elseif nameValue then
        local name = catalogDecode(nameValue)
        local contents = decode(contentsValue)
        if not validRelativePath(name) or not contents or #contents > maximumPresetBytes
            or backup.names[name:lower()] then
          return "invalid_preset"
        end
        backup.names[name:lower()] = true
        table.insert(backup.presets, { name = name, contents = contents })
      elseif line ~= "" then
        return "line"
      end
    end
end

local function newVerifier(expectedNames, expectedFolders)
  local expectedPresetMap, expectedFolderMap = {}, {}
  for _, name in ipairs(expectedNames) do expectedPresetMap[name:lower()] = true end
  for _, folder in ipairs(expectedFolders) do expectedFolderMap[folder:lower()] = true end
  return {expectedPresetMap=expectedPresetMap, expectedFolderMap=expectedFolderMap,
    lineNumber=0,presetCount=0,folderCount=0,sawConfig=false,seenPresets={},seenFolders={}}
end

local function verifyLine(context,line,maximumPresetBytes)
    line = line:gsub("\r$", "")
    context.lineNumber = context.lineNumber + 1
    if context.lineNumber == 1 then
      if line ~= "CPMBACKUP\t1" then
        return "invalid_header"
      end
    else
      local configValue = line:match("^CONFIG\t(.*)$")
      local folderValue = line:match("^F\t([^\t]+)$")
      local nameValue, contentsStart = line:match("^P\t([^\t]+)\t()")
      if configValue then
        if context.sawConfig or decode(configValue) == nil then
          return "invalid_config"
        end
        context.sawConfig = true
      elseif folderValue then
        local folder = catalogDecode(folderValue)
        local lowered = folder and folder:lower() or ""
        if not context.expectedFolderMap[lowered] or context.seenFolders[lowered] then
          return "unexpected_folder"
        end
        context.seenFolders[lowered] = true
        context.folderCount = context.folderCount + 1
      elseif nameValue then
        local name = catalogDecode(nameValue)
        local lowered = name and name:lower() or ""
        local contentsLength = #line - contentsStart + 1
        if not context.expectedPresetMap[lowered] or context.seenPresets[lowered]
            or contentsLength == 0 or contentsLength % 2 ~= 0
            or contentsLength > maximumPresetBytes * 2
            or line:find("[^%x]", contentsStart) then
          return "unexpected_preset"
        end
        context.seenPresets[lowered] = true
        context.presetCount = context.presetCount + 1
      elseif line ~= "" then
        return "line"
      end
    end
end

local function chooseImportRoot(folders, presets)
  local base = "Imported Library"
  for index = 1, 999 do
    local root = index == 1 and base or (base .. " Copy " .. index)
    if not names.folderNameExists(root,folders) and not names.findPresetCollision(root,nil,presets) then return root end
  end
  return nil
end
local function header() return "CPMBACKUP\t1" end
local function configLine(contents) return "CONFIG\t" .. codecs.backupEncode(contents) end
local function folderLine(folder) return "F\t" .. catalogEncode(folder) end
local function presetPrefix(name) return "P\t" .. catalogEncode(name) .. "\t" end
local function needsImportRoot(backup,folders,presets)
  for folder in pairs(backup.folders)do if names.folderNameExists(folder,folders)then return true end end
  for _,item in ipairs(backup.presets)do if names.findPresetCollision(item.name,nil,presets)then return true end end
  return false
end
local function exportCandidate(index,presetDirectory,extension)
  local suffix=index==1 and "" or (" Copy %d"):format(index)
  return presetDirectory.."/Character Preset Manager Library Backup"..suffix..extension
end

return {needsImportRoot=needsImportRoot,exportCandidate=exportCandidate,newReader=newReader, readLine=readLine, newVerifier=newVerifier, verifyLine=verifyLine,
  chooseImportRoot=chooseImportRoot, header=header, configLine=configLine, folderLine=folderLine, presetPrefix=presetPrefix}
