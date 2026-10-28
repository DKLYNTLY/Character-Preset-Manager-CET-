local paths = require("modules/domain/paths")
local names = require("modules/domain/names")
local codecs = require("modules/domain/codecs")
local catalogEncode, catalogDecode = codecs.catalogEncode, codecs.catalogDecode
local parentFolder = paths.parentFolder
local isFolderBundleFilename = paths.isFolderBundleFilename
local function validBundlePath(value) return paths.validBundlePath(value, names.validatedPresetName) end
local function newInspector()
  return {bundle = {folders = {}, folderNames = {}, presets = {}, presetNames = {}}, lineNumber = 0}
end

local function inspectLine(context, line, maximumPresetBytes, maximumPresets)
  local bundle = context.bundle
    line = line:gsub("\r$", "")
    if line ~= "" then
      context.lineNumber = context.lineNumber + 1
      if context.lineNumber == 1 then
        if line ~= "CPMFOLDER\t1" then
          return "invalid_header"
        end
      else
        local root = line:match("^ROOT\t([^\t]+)$")
        local folder = line:match("^F\t([^\t]+)$")
        local name, encoded = line:match("^P\t([^\t]+)\t([%x]+)$")
        if root then
          root = catalogDecode(root)
          if bundle.root or not validBundlePath(root) or parentFolder(root) ~= "" then
            return "invalid_root"
          end
          bundle.root = root
        elseif folder then
          folder = catalogDecode(folder)
          if not validBundlePath(folder) then
            return "invalid_folder"
          end
          if bundle.folderNames[folder:lower()] then
            return "duplicate_folder"
          end
          bundle.folderNames[folder:lower()] = true
          bundle.folders[folder] = true
        elseif name then
          name = catalogDecode(name)
          if not validBundlePath(name) or #encoded % 2 ~= 0
              or #encoded > maximumPresetBytes * 2
              or #bundle.presets >= maximumPresets then
            return "invalid_preset"
          end
          if bundle.presetNames[name:lower()] then
            return "duplicate_preset"
          end
          bundle.presetNames[name:lower()] = true
          table.insert(bundle.presets, { name = name })
        else
          return "line"
        end
      end
    end
end

local function finishInspection(bundle)
  if not bundle.root or #bundle.presets == 0 then return nil end
  bundle.folderNames = nil
  bundle.presetNames = nil
  return bundle
end

local function header(root)
  return "CPMFOLDER\t1\nROOT\t" .. catalogEncode(root) .. "\n"
end
local function folderLine(folder) return "F\t" .. catalogEncode(folder) .. "\n" end
local function presetPrefix(name) return "P\t" .. catalogEncode(name) .. "\t" end

local function decodeRegistry(contents, maximumLines)
  local imported = {}
  local lineCount = 0
  for line in (contents .. "\n"):gmatch("(.-)\n") do
    if line ~= "" then
      lineCount = lineCount + 1
      if lineCount > maximumLines then return nil, false end
      local encodedName, fingerprint, encodedRoot =
        line:match("^B\t([^\t]+)\t(2:%d+:%d+:%d+)\t([^\t]+)$")
      if not encodedName then
        encodedName, fingerprint, encodedRoot =
          line:match("^B\t([^\t]+)\t(%d+:%d+)\t([^\t]+)$")
      end
      if not encodedName then
        encodedName, fingerprint = line:match("^B\t([^\t]+)\t(2:%d+:%d+:%d+)$")
      end
      if not encodedName then
        encodedName, fingerprint = line:match("^B\t([^\t]+)\t(%d+:%d+)$")
      end
      local filename = encodedName and catalogDecode(encodedName) or nil
      local root = encodedRoot and catalogDecode(encodedRoot) or nil
      if not isFolderBundleFilename(filename)
          or (root ~= nil and not validBundlePath(root)) then return nil, false end
      imported[filename:lower()] = {
        filename = filename,
        fingerprint = fingerprint,
        root = root,
      }
    end
  end
  return imported, true
end

local function encodeRegistry(imported)
  local lines = {}
  for _, item in pairs(imported or {}) do
    if not isFolderBundleFilename(item.filename)
        or type(item.fingerprint) ~= "string"
        or (not item.fingerprint:match("^%d+:%d+$")
          and not item.fingerprint:match("^2:%d+:%d+:%d+$")) then return nil end
    local line = "B\t" .. catalogEncode(item.filename) .. "\t" .. item.fingerprint
    if item.root ~= nil then
      if not validBundlePath(item.root) then return nil end
      line = line .. "\t" .. catalogEncode(item.root)
    end
    table.insert(lines, line)
  end
  table.sort(lines, function(a, b) return a:lower() < b:lower() end)
  return lines
end

local function folderPresetNames(presets,folder)
  local selected={}
  for name in pairs(presets)do
    if paths.isInFolderTree(parentFolder(name),folder)then table.insert(selected,name)end
  end
  table.sort(selected,function(a,b)return a:lower()<b:lower()end)
  return selected
end
local function nestedFolders(folders,folder)
  local nested={}
  for candidate in pairs(folders)do
    if candidate~=folder and paths.isInFolderTree(candidate,folder)then
      table.insert(nested,candidate:sub(#folder+2))
    end
  end
  table.sort(nested,function(a,b)return a:lower()<b:lower()end)
  return nested
end
local function selectionFolders(selected)
  local map, folders = {}, {}
  for _, name in ipairs(selected) do paths.addFolderAncestors(map, parentFolder(name)) end
  map[""] = nil
  for folder in pairs(map) do table.insert(folders, folder) end
  table.sort(folders, function(a,b) return a:lower() < b:lower() end)
  return folders
end
local function exportCandidate(label,index,presetDirectory,extension)
  local stem = "Character Preset Manager Folder - " .. paths.baseName(label)
  local suffix = index == 1 and "" or (" Copy %d"):format(index)
  return presetDirectory.."/"..stem..suffix..extension
end
return {exportCandidate=exportCandidate,newInspector=newInspector, inspectLine=inspectLine, finishInspection=finishInspection,
  header=header, folderLine=folderLine, presetPrefix=presetPrefix, decodeRegistry=decodeRegistry,
  encodeRegistry=encodeRegistry, folderPresetNames=folderPresetNames,nestedFolders=nestedFolders, selectionFolders=selectionFolders}
