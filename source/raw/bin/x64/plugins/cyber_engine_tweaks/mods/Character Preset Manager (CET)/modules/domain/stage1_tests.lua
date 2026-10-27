local moduleRoot = "source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/"
package.path = moduleRoot .. "?.lua;" .. package.path
local originalRuntime = package.loaded["modules/runtime"]
local paths = require("modules/domain/paths")
local names = require("modules/domain/names")
local identities = require("modules/domain/identities")
local codecs = require("modules/domain/codecs")
assert(package.loaded["modules/runtime"] == originalRuntime, "domain modules loaded runtime")
local state={library={presets={A={},["A Copy"]={},mapped={storage="physical"}},folders={Folder=true,["Folder Copy"]=true}}}
local PRESET_DIR="Character Presets"
local MAX_TREE_DEPTH=12
local function parentFolder(name)
  return paths.parentFolder(name)
end
local function folderDepth(name)
  return paths.folderDepth(name)
end
local function folderAncestorsExpanded(name, expandedFolders)
  return paths.folderAncestorsExpanded(name, expandedFolders)
end
local function folderPath(name)
  return paths.folderPath(name, PRESET_DIR)
end
local function presetPath(name)
  return paths.presetPath(name, state.library.presets, PRESET_DIR)
end
local function baseName(name)
  return paths.baseName(name)
end
local function joinFolder(folder, name)
  return paths.joinFolder(folder, name)
end
local function isInFolderTree(path, folder)
  return paths.isInFolderTree(path, folder)
end
local function addFolderAncestors(folders, folder)
  return paths.addFolderAncestors(folders, folder)
end
local function validRelativePath(value)
  return paths.validRelativePath(value)
end
local function remapFolderTreePath(path, source, destination)
  return paths.remapFolderTreePath(path, source, destination)
end
local function validNativeRelativePath(value)
  return paths.validNativeRelativePath(value, MAX_TREE_DEPTH)
end
local function isFolderBundleFilename(filename)
  return paths.isFolderBundleFilename(filename)
end
local function validTrashFilename(filename)
  return paths.validTrashFilename(filename)
end
local function sanitizeName(value)
  return names.sanitizeName(value)
end
local function sanitizeMetadata(value, maximum)
  return names.sanitizeMetadata(value, maximum)
end
local function validatedPresetName(value)
  return names.validatedPresetName(value)
end
local function validBundlePath(value)
  return paths.validBundlePath(value, validatedPresetName)
end
local function validatedFolderName(value)
  return names.validatedFolderName(value)
end
local function findPresetCollision(name, excludeName)
  return names.findPresetCollision(name, excludeName, state.library.presets)
end
local function uniqueStorageName(leafName, used)
  return names.uniqueStorageName(leafName, used or nil)
end
local function findExistingFolderName(name, excludeName)
  return names.findExistingFolderName(name, excludeName, state.library.folders)
end
local function folderNameExists(name)
  return names.folderNameExists(name, state.library.folders)
end
local function uniquePresetCopyName(sourceName)
  return names.uniquePresetCopyName(sourceName, state.library.presets)
end
local function uniqueFolderCopyName(sourceName)
  return names.uniqueFolderCopyName(sourceName, state.library.folders)
end
local function isRuntimePointerText(value)
  return identities.isRuntimePointerText(value)
end
local function stableChoiceIdentity(choice)
  return identities.stableChoiceIdentity(choice)
end
local function occurrenceKeyParts(value)
  return identities.occurrenceKeyParts(value)
end
local function optionIndexValidationError(index)
  return identities.optionIndexValidationError(index)
end
local function optionIndexIsValid(index)
  return identities.optionIndexIsValid(index)
end
local function catalogEncode(value)
  return codecs.catalogEncode(value)
end
local function catalogDecode(value)
  return codecs.catalogDecode(value)
end
local function encode(value)
  return codecs.backupEncode(value)
end
local function decode(value)
  return codecs.backupDecode(value)
end
local function hexEncode(value)
  return codecs.hexEncode(value)
end
local function hexDecode(value)
  return codecs.hexDecode(value)
end
local function decodeImportField(value) return codecs.catalogDecode(value) end
local function decodeNativeField(value) return codecs.catalogDecode(value) end
local HISTORY_FILE_PREFIX = "Data/Recovery/Appearance History/Appearance "
local function historyPath(index)
  return paths.historyPath(index, HISTORY_FILE_PREFIX)
end
local function supportedFile(path)
  return paths.supportedFile(path)
end
local function cleanField(value)
  return codecs.cleanField(value)
end
local function literal(value)
 if type(value)=="string" then return '"'..value:gsub('[%z\1-\31\127-\255\\"]',function(c) return string.format("\\%03d",c:byte()) end)..'"' end
 if type(value)=="table" then local entries={}; for k,v in pairs(value) do entries[#entries+1]="["..literal(k).."]="..literal(v) end; table.sort(entries); return "{"..table.concat(entries,",").."}" end
 if value==nil then return "nil" end
 return tostring(value)
end
local function capture(fn)
 local function pack(...) return {n=select("#",...),...} end
 local result=pack(pcall(fn)); if not result[1] then return {n=1,[1]="error"} end; return result
end

local fixtures={
{name="parentFolder",run=function() return parentFolder(nil) end,expected={["n"]=1,[1]="error"}},
{name="parentFolder",run=function() return parentFolder(false) end,expected={["n"]=1,[1]="error"}},
{name="parentFolder",run=function() return parentFolder(42) end,expected={["n"]=1,[1]="error"}},
{name="parentFolder",run=function() return parentFolder("") end,expected={["n"]=2,[1]=true,[2]=""}},
{name="parentFolder",run=function() return parentFolder("a/b") end,expected={["n"]=2,[1]=true,[2]="a"}},
{name="parentFolder",run=function() return parentFolder("a//b") end,expected={["n"]=2,[1]=true,[2]="a/"}},
{name="parentFolder",run=function() return parentFolder("a/../b") end,expected={["n"]=2,[1]=true,[2]="a/.."}},
{name="parentFolder",run=function() return parentFolder("/a") end,expected={["n"]=2,[1]=true,[2]=""}},
{name="parentFolder",run=function() return parentFolder("a/") end,expected={["n"]=2,[1]=true,[2]=""}},
{name="parentFolder",run=function() return parentFolder("a\\b") end,expected={["n"]=2,[1]=true,[2]=""}},
{name="parentFolder",run=function() return parentFolder("a:b") end,expected={["n"]=2,[1]=true,[2]=""}},
{name="parentFolder",run=function() return parentFolder("CON") end,expected={["n"]=2,[1]=true,[2]=""}},
{name="parentFolder",run=function() return parentFolder("con.txt") end,expected={["n"]=2,[1]=true,[2]=""}},
{name="parentFolder",run=function() return parentFolder("COM1") end,expected={["n"]=2,[1]=true,[2]=""}},
{name="parentFolder",run=function() return parentFolder("COM0") end,expected={["n"]=2,[1]=true,[2]=""}},
{name="parentFolder",run=function() return parentFolder("LPT9") end,expected={["n"]=2,[1]=true,[2]=""}},
{name="parentFolder",run=function() return parentFolder("NUL") end,expected={["n"]=2,[1]=true,[2]=""}},
{name="parentFolder",run=function() return parentFolder("a.") end,expected={["n"]=2,[1]=true,[2]=""}},
{name="parentFolder",run=function() return parentFolder(" a ") end,expected={["n"]=2,[1]=true,[2]=""}},
{name="parentFolder",run=function() return parentFolder("a\000b") end,expected={["n"]=2,[1]=true,[2]=""}},
{name="parentFolder",run=function() return parentFolder("é猫") end,expected={["n"]=2,[1]=true,[2]=""}},
{name="parentFolder",run=function() return parentFolder(string.rep("a",65)) end,expected={["n"]=2,[1]=true,[2]=""}},
{name="parentFolder",run=function() return parentFolder(string.rep("a/",11).."b") end,expected={["n"]=2,[1]=true,[2]="a/a/a/a/a/a/a/a/a/a/a"}},
{name="parentFolder",run=function() return parentFolder(string.rep("a/",12).."b") end,expected={["n"]=2,[1]=true,[2]="a/a/a/a/a/a/a/a/a/a/a/a"}},
{name="parentFolder",run=function() return parentFolder(string.rep("a",255)) end,expected={["n"]=2,[1]=true,[2]=""}},
{name="parentFolder",run=function() return parentFolder(string.rep("a",256)) end,expected={["n"]=2,[1]=true,[2]=""}},
{name="parentFolder",run=function() return parentFolder("x.preset") end,expected={["n"]=2,[1]=true,[2]=""}},
{name="parentFolder",run=function() return parentFolder(".preset") end,expected={["n"]=2,[1]=true,[2]=""}},
{name="parentFolder",run=function() return parentFolder("CON.preset") end,expected={["n"]=2,[1]=true,[2]=""}},
{name="parentFolder",run=function() return parentFolder("a\000.preset") end,expected={["n"]=2,[1]=true,[2]=""}},
{name="parentFolder",run=function() return parentFolder(string.rep("a",65)..".preset") end,expected={["n"]=2,[1]=true,[2]=""}},
{name="parentFolder",run=function() return parentFolder("x.CPMFOLDER") end,expected={["n"]=2,[1]=true,[2]=""}},
{name="parentFolder",run=function() return parentFolder(".cpmfolder") end,expected={["n"]=2,[1]=true,[2]=""}},
{name="parentFolder",run=function() return parentFolder("a/b.cpmfolder") end,expected={["n"]=2,[1]=true,[2]="a"}},
{name="parentFolder",run=function() return parentFolder("a\000.cpmfolder") end,expected={["n"]=2,[1]=true,[2]=""}},
{name="parentFolder",run=function() return parentFolder(string.rep("a",246)..".cpmfolder") end,expected={["n"]=2,[1]=true,[2]=""}},
{name="folderDepth",run=function() return folderDepth(nil) end,expected={["n"]=2,[1]=true,[2]=0}},
{name="folderDepth",run=function() return folderDepth(false) end,expected={["n"]=2,[1]=true,[2]=0}},
{name="folderDepth",run=function() return folderDepth(42) end,expected={["n"]=2,[1]=true,[2]=0}},
{name="folderDepth",run=function() return folderDepth("") end,expected={["n"]=2,[1]=true,[2]=0}},
{name="folderDepth",run=function() return folderDepth("a/b") end,expected={["n"]=2,[1]=true,[2]=1}},
{name="folderDepth",run=function() return folderDepth("a//b") end,expected={["n"]=2,[1]=true,[2]=2}},
{name="folderDepth",run=function() return folderDepth("a/../b") end,expected={["n"]=2,[1]=true,[2]=2}},
{name="folderDepth",run=function() return folderDepth("/a") end,expected={["n"]=2,[1]=true,[2]=1}},
{name="folderDepth",run=function() return folderDepth("a/") end,expected={["n"]=2,[1]=true,[2]=1}},
{name="folderDepth",run=function() return folderDepth("a\\b") end,expected={["n"]=2,[1]=true,[2]=0}},
{name="folderDepth",run=function() return folderDepth("a:b") end,expected={["n"]=2,[1]=true,[2]=0}},
{name="folderDepth",run=function() return folderDepth("CON") end,expected={["n"]=2,[1]=true,[2]=0}},
{name="folderDepth",run=function() return folderDepth("con.txt") end,expected={["n"]=2,[1]=true,[2]=0}},
{name="folderDepth",run=function() return folderDepth("COM1") end,expected={["n"]=2,[1]=true,[2]=0}},
{name="folderDepth",run=function() return folderDepth("COM0") end,expected={["n"]=2,[1]=true,[2]=0}},
{name="folderDepth",run=function() return folderDepth("LPT9") end,expected={["n"]=2,[1]=true,[2]=0}},
{name="folderDepth",run=function() return folderDepth("NUL") end,expected={["n"]=2,[1]=true,[2]=0}},
{name="folderDepth",run=function() return folderDepth("a.") end,expected={["n"]=2,[1]=true,[2]=0}},
{name="folderDepth",run=function() return folderDepth(" a ") end,expected={["n"]=2,[1]=true,[2]=0}},
{name="folderDepth",run=function() return folderDepth("a\000b") end,expected={["n"]=2,[1]=true,[2]=0}},
{name="folderDepth",run=function() return folderDepth("é猫") end,expected={["n"]=2,[1]=true,[2]=0}},
{name="folderDepth",run=function() return folderDepth(string.rep("a",65)) end,expected={["n"]=2,[1]=true,[2]=0}},
{name="folderDepth",run=function() return folderDepth(string.rep("a/",11).."b") end,expected={["n"]=2,[1]=true,[2]=11}},
{name="folderDepth",run=function() return folderDepth(string.rep("a/",12).."b") end,expected={["n"]=2,[1]=true,[2]=12}},
{name="folderDepth",run=function() return folderDepth(string.rep("a",255)) end,expected={["n"]=2,[1]=true,[2]=0}},
{name="folderDepth",run=function() return folderDepth(string.rep("a",256)) end,expected={["n"]=2,[1]=true,[2]=0}},
{name="folderDepth",run=function() return folderDepth("x.preset") end,expected={["n"]=2,[1]=true,[2]=0}},
{name="folderDepth",run=function() return folderDepth(".preset") end,expected={["n"]=2,[1]=true,[2]=0}},
{name="folderDepth",run=function() return folderDepth("CON.preset") end,expected={["n"]=2,[1]=true,[2]=0}},
{name="folderDepth",run=function() return folderDepth("a\000.preset") end,expected={["n"]=2,[1]=true,[2]=0}},
{name="folderDepth",run=function() return folderDepth(string.rep("a",65)..".preset") end,expected={["n"]=2,[1]=true,[2]=0}},
{name="folderDepth",run=function() return folderDepth("x.CPMFOLDER") end,expected={["n"]=2,[1]=true,[2]=0}},
{name="folderDepth",run=function() return folderDepth(".cpmfolder") end,expected={["n"]=2,[1]=true,[2]=0}},
{name="folderDepth",run=function() return folderDepth("a/b.cpmfolder") end,expected={["n"]=2,[1]=true,[2]=1}},
{name="folderDepth",run=function() return folderDepth("a\000.cpmfolder") end,expected={["n"]=2,[1]=true,[2]=0}},
{name="folderDepth",run=function() return folderDepth(string.rep("a",246)..".cpmfolder") end,expected={["n"]=2,[1]=true,[2]=0}},
{name="folderAncestorsExpanded",run=function() return folderAncestorsExpanded("a/b/c",{a=true,["a/b"]=true}) end,expected={["n"]=2,[1]=true,[2]=true}},
{name="folderAncestorsExpanded",run=function() return folderAncestorsExpanded("a/b/c",{a=true}) end,expected={["n"]=2,[1]=true,[2]=false}},
{name="folderAncestorsExpanded",run=function() return folderAncestorsExpanded(nil,nil) end,expected={["n"]=2,[1]=true,[2]=true}},
{name="folderPath",run=function() return folderPath(nil) end,expected={["n"]=1,[1]="error"}},
{name="folderPath",run=function() return folderPath(false) end,expected={["n"]=1,[1]="error"}},
{name="folderPath",run=function() return folderPath(42) end,expected={["n"]=2,[1]=true,[2]="Character Presets/42"}},
{name="folderPath",run=function() return folderPath("") end,expected={["n"]=2,[1]=true,[2]="Character Presets"}},
{name="folderPath",run=function() return folderPath("a/b") end,expected={["n"]=2,[1]=true,[2]="Character Presets/a/b"}},
{name="folderPath",run=function() return folderPath("a//b") end,expected={["n"]=2,[1]=true,[2]="Character Presets/a//b"}},
{name="folderPath",run=function() return folderPath("a/../b") end,expected={["n"]=2,[1]=true,[2]="Character Presets/a/../b"}},
{name="folderPath",run=function() return folderPath("/a") end,expected={["n"]=2,[1]=true,[2]="Character Presets//a"}},
{name="folderPath",run=function() return folderPath("a/") end,expected={["n"]=2,[1]=true,[2]="Character Presets/a/"}},
{name="folderPath",run=function() return folderPath("a\\b") end,expected={["n"]=2,[1]=true,[2]="Character Presets/a\092b"}},
{name="folderPath",run=function() return folderPath("a:b") end,expected={["n"]=2,[1]=true,[2]="Character Presets/a:b"}},
{name="folderPath",run=function() return folderPath("CON") end,expected={["n"]=2,[1]=true,[2]="Character Presets/CON"}},
{name="folderPath",run=function() return folderPath("con.txt") end,expected={["n"]=2,[1]=true,[2]="Character Presets/con.txt"}},
{name="folderPath",run=function() return folderPath("COM1") end,expected={["n"]=2,[1]=true,[2]="Character Presets/COM1"}},
{name="folderPath",run=function() return folderPath("COM0") end,expected={["n"]=2,[1]=true,[2]="Character Presets/COM0"}},
{name="folderPath",run=function() return folderPath("LPT9") end,expected={["n"]=2,[1]=true,[2]="Character Presets/LPT9"}},
{name="folderPath",run=function() return folderPath("NUL") end,expected={["n"]=2,[1]=true,[2]="Character Presets/NUL"}},
{name="folderPath",run=function() return folderPath("a.") end,expected={["n"]=2,[1]=true,[2]="Character Presets/a."}},
{name="folderPath",run=function() return folderPath(" a ") end,expected={["n"]=2,[1]=true,[2]="Character Presets/ a "}},
{name="folderPath",run=function() return folderPath("a\000b") end,expected={["n"]=2,[1]=true,[2]="Character Presets/a\000b"}},
{name="folderPath",run=function() return folderPath("é猫") end,expected={["n"]=2,[1]=true,[2]="Character Presets/\195\169\231\140\171"}},
{name="folderPath",run=function() return folderPath(string.rep("a",65)) end,expected={["n"]=2,[1]=true,[2]="Character Presets/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}},
{name="folderPath",run=function() return folderPath(string.rep("a/",11).."b") end,expected={["n"]=2,[1]=true,[2]="Character Presets/a/a/a/a/a/a/a/a/a/a/a/b"}},
{name="folderPath",run=function() return folderPath(string.rep("a/",12).."b") end,expected={["n"]=2,[1]=true,[2]="Character Presets/a/a/a/a/a/a/a/a/a/a/a/a/b"}},
{name="folderPath",run=function() return folderPath(string.rep("a",255)) end,expected={["n"]=2,[1]=true,[2]="Character Presets/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}},
{name="folderPath",run=function() return folderPath(string.rep("a",256)) end,expected={["n"]=2,[1]=true,[2]="Character Presets/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}},
{name="folderPath",run=function() return folderPath("x.preset") end,expected={["n"]=2,[1]=true,[2]="Character Presets/x.preset"}},
{name="folderPath",run=function() return folderPath(".preset") end,expected={["n"]=2,[1]=true,[2]="Character Presets/.preset"}},
{name="folderPath",run=function() return folderPath("CON.preset") end,expected={["n"]=2,[1]=true,[2]="Character Presets/CON.preset"}},
{name="folderPath",run=function() return folderPath("a\000.preset") end,expected={["n"]=2,[1]=true,[2]="Character Presets/a\000.preset"}},
{name="folderPath",run=function() return folderPath(string.rep("a",65)..".preset") end,expected={["n"]=2,[1]=true,[2]="Character Presets/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.preset"}},
{name="folderPath",run=function() return folderPath("x.CPMFOLDER") end,expected={["n"]=2,[1]=true,[2]="Character Presets/x.CPMFOLDER"}},
{name="folderPath",run=function() return folderPath(".cpmfolder") end,expected={["n"]=2,[1]=true,[2]="Character Presets/.cpmfolder"}},
{name="folderPath",run=function() return folderPath("a/b.cpmfolder") end,expected={["n"]=2,[1]=true,[2]="Character Presets/a/b.cpmfolder"}},
{name="folderPath",run=function() return folderPath("a\000.cpmfolder") end,expected={["n"]=2,[1]=true,[2]="Character Presets/a\000.cpmfolder"}},
{name="folderPath",run=function() return folderPath(string.rep("a",246)..".cpmfolder") end,expected={["n"]=2,[1]=true,[2]="Character Presets/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.cpmfolder"}},
{name="presetPath",run=function() return presetPath(nil) end,expected={["n"]=1,[1]="error"}},
{name="presetPath",run=function() return presetPath(false) end,expected={["n"]=1,[1]="error"}},
{name="presetPath",run=function() return presetPath(42) end,expected={["n"]=2,[1]=true,[2]="Character Presets/42.preset"}},
{name="presetPath",run=function() return presetPath("") end,expected={["n"]=2,[1]=true,[2]="Character Presets/.preset"}},
{name="presetPath",run=function() return presetPath("a/b") end,expected={["n"]=2,[1]=true,[2]="Character Presets/a/b.preset"}},
{name="presetPath",run=function() return presetPath("a//b") end,expected={["n"]=2,[1]=true,[2]="Character Presets/a//b.preset"}},
{name="presetPath",run=function() return presetPath("a/../b") end,expected={["n"]=2,[1]=true,[2]="Character Presets/a/../b.preset"}},
{name="presetPath",run=function() return presetPath("/a") end,expected={["n"]=2,[1]=true,[2]="Character Presets//a.preset"}},
{name="presetPath",run=function() return presetPath("a/") end,expected={["n"]=2,[1]=true,[2]="Character Presets/a/.preset"}},
{name="presetPath",run=function() return presetPath("a\\b") end,expected={["n"]=2,[1]=true,[2]="Character Presets/a\092b.preset"}},
{name="presetPath",run=function() return presetPath("a:b") end,expected={["n"]=2,[1]=true,[2]="Character Presets/a:b.preset"}},
{name="presetPath",run=function() return presetPath("CON") end,expected={["n"]=2,[1]=true,[2]="Character Presets/CON.preset"}},
{name="presetPath",run=function() return presetPath("con.txt") end,expected={["n"]=2,[1]=true,[2]="Character Presets/con.txt.preset"}},
{name="presetPath",run=function() return presetPath("COM1") end,expected={["n"]=2,[1]=true,[2]="Character Presets/COM1.preset"}},
{name="presetPath",run=function() return presetPath("COM0") end,expected={["n"]=2,[1]=true,[2]="Character Presets/COM0.preset"}},
{name="presetPath",run=function() return presetPath("LPT9") end,expected={["n"]=2,[1]=true,[2]="Character Presets/LPT9.preset"}},
{name="presetPath",run=function() return presetPath("NUL") end,expected={["n"]=2,[1]=true,[2]="Character Presets/NUL.preset"}},
{name="presetPath",run=function() return presetPath("a.") end,expected={["n"]=2,[1]=true,[2]="Character Presets/a..preset"}},
{name="presetPath",run=function() return presetPath(" a ") end,expected={["n"]=2,[1]=true,[2]="Character Presets/ a .preset"}},
{name="presetPath",run=function() return presetPath("a\000b") end,expected={["n"]=2,[1]=true,[2]="Character Presets/a\000b.preset"}},
{name="presetPath",run=function() return presetPath("é猫") end,expected={["n"]=2,[1]=true,[2]="Character Presets/\195\169\231\140\171.preset"}},
{name="presetPath",run=function() return presetPath(string.rep("a",65)) end,expected={["n"]=2,[1]=true,[2]="Character Presets/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.preset"}},
{name="presetPath",run=function() return presetPath(string.rep("a/",11).."b") end,expected={["n"]=2,[1]=true,[2]="Character Presets/a/a/a/a/a/a/a/a/a/a/a/b.preset"}},
{name="presetPath",run=function() return presetPath(string.rep("a/",12).."b") end,expected={["n"]=2,[1]=true,[2]="Character Presets/a/a/a/a/a/a/a/a/a/a/a/a/b.preset"}},
{name="presetPath",run=function() return presetPath(string.rep("a",255)) end,expected={["n"]=2,[1]=true,[2]="Character Presets/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.preset"}},
{name="presetPath",run=function() return presetPath(string.rep("a",256)) end,expected={["n"]=2,[1]=true,[2]="Character Presets/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.preset"}},
{name="presetPath",run=function() return presetPath("x.preset") end,expected={["n"]=2,[1]=true,[2]="Character Presets/x.preset.preset"}},
{name="presetPath",run=function() return presetPath(".preset") end,expected={["n"]=2,[1]=true,[2]="Character Presets/.preset.preset"}},
{name="presetPath",run=function() return presetPath("CON.preset") end,expected={["n"]=2,[1]=true,[2]="Character Presets/CON.preset.preset"}},
{name="presetPath",run=function() return presetPath("a\000.preset") end,expected={["n"]=2,[1]=true,[2]="Character Presets/a\000.preset.preset"}},
{name="presetPath",run=function() return presetPath(string.rep("a",65)..".preset") end,expected={["n"]=2,[1]=true,[2]="Character Presets/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.preset.preset"}},
{name="presetPath",run=function() return presetPath("x.CPMFOLDER") end,expected={["n"]=2,[1]=true,[2]="Character Presets/x.CPMFOLDER.preset"}},
{name="presetPath",run=function() return presetPath(".cpmfolder") end,expected={["n"]=2,[1]=true,[2]="Character Presets/.cpmfolder.preset"}},
{name="presetPath",run=function() return presetPath("a/b.cpmfolder") end,expected={["n"]=2,[1]=true,[2]="Character Presets/a/b.cpmfolder.preset"}},
{name="presetPath",run=function() return presetPath("a\000.cpmfolder") end,expected={["n"]=2,[1]=true,[2]="Character Presets/a\000.cpmfolder.preset"}},
{name="presetPath",run=function() return presetPath(string.rep("a",246)..".cpmfolder") end,expected={["n"]=2,[1]=true,[2]="Character Presets/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.cpmfolder.preset"}},
{name="baseName",run=function() return baseName(nil) end,expected={["n"]=1,[1]="error"}},
{name="baseName",run=function() return baseName(false) end,expected={["n"]=1,[1]="error"}},
{name="baseName",run=function() return baseName(42) end,expected={["n"]=1,[1]="error"}},
{name="baseName",run=function() return baseName("") end,expected={["n"]=2,[1]=true,[2]=""}},
{name="baseName",run=function() return baseName("a/b") end,expected={["n"]=2,[1]=true,[2]="b"}},
{name="baseName",run=function() return baseName("a//b") end,expected={["n"]=2,[1]=true,[2]="b"}},
{name="baseName",run=function() return baseName("a/../b") end,expected={["n"]=2,[1]=true,[2]="b"}},
{name="baseName",run=function() return baseName("/a") end,expected={["n"]=2,[1]=true,[2]="a"}},
{name="baseName",run=function() return baseName("a/") end,expected={["n"]=2,[1]=true,[2]="a/"}},
{name="baseName",run=function() return baseName("a\\b") end,expected={["n"]=2,[1]=true,[2]="a\092b"}},
{name="baseName",run=function() return baseName("a:b") end,expected={["n"]=2,[1]=true,[2]="a:b"}},
{name="baseName",run=function() return baseName("CON") end,expected={["n"]=2,[1]=true,[2]="CON"}},
{name="baseName",run=function() return baseName("con.txt") end,expected={["n"]=2,[1]=true,[2]="con.txt"}},
{name="baseName",run=function() return baseName("COM1") end,expected={["n"]=2,[1]=true,[2]="COM1"}},
{name="baseName",run=function() return baseName("COM0") end,expected={["n"]=2,[1]=true,[2]="COM0"}},
{name="baseName",run=function() return baseName("LPT9") end,expected={["n"]=2,[1]=true,[2]="LPT9"}},
{name="baseName",run=function() return baseName("NUL") end,expected={["n"]=2,[1]=true,[2]="NUL"}},
{name="baseName",run=function() return baseName("a.") end,expected={["n"]=2,[1]=true,[2]="a."}},
{name="baseName",run=function() return baseName(" a ") end,expected={["n"]=2,[1]=true,[2]=" a "}},
{name="baseName",run=function() return baseName("a\000b") end,expected={["n"]=2,[1]=true,[2]="a\000b"}},
{name="baseName",run=function() return baseName("é猫") end,expected={["n"]=2,[1]=true,[2]="\195\169\231\140\171"}},
{name="baseName",run=function() return baseName(string.rep("a",65)) end,expected={["n"]=2,[1]=true,[2]="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}},
{name="baseName",run=function() return baseName(string.rep("a/",11).."b") end,expected={["n"]=2,[1]=true,[2]="b"}},
{name="baseName",run=function() return baseName(string.rep("a/",12).."b") end,expected={["n"]=2,[1]=true,[2]="b"}},
{name="baseName",run=function() return baseName(string.rep("a",255)) end,expected={["n"]=2,[1]=true,[2]="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}},
{name="baseName",run=function() return baseName(string.rep("a",256)) end,expected={["n"]=2,[1]=true,[2]="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}},
{name="baseName",run=function() return baseName("x.preset") end,expected={["n"]=2,[1]=true,[2]="x.preset"}},
{name="baseName",run=function() return baseName(".preset") end,expected={["n"]=2,[1]=true,[2]=".preset"}},
{name="baseName",run=function() return baseName("CON.preset") end,expected={["n"]=2,[1]=true,[2]="CON.preset"}},
{name="baseName",run=function() return baseName("a\000.preset") end,expected={["n"]=2,[1]=true,[2]="a\000.preset"}},
{name="baseName",run=function() return baseName(string.rep("a",65)..".preset") end,expected={["n"]=2,[1]=true,[2]="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.preset"}},
{name="baseName",run=function() return baseName("x.CPMFOLDER") end,expected={["n"]=2,[1]=true,[2]="x.CPMFOLDER"}},
{name="baseName",run=function() return baseName(".cpmfolder") end,expected={["n"]=2,[1]=true,[2]=".cpmfolder"}},
{name="baseName",run=function() return baseName("a/b.cpmfolder") end,expected={["n"]=2,[1]=true,[2]="b.cpmfolder"}},
{name="baseName",run=function() return baseName("a\000.cpmfolder") end,expected={["n"]=2,[1]=true,[2]="a\000.cpmfolder"}},
{name="baseName",run=function() return baseName(string.rep("a",246)..".cpmfolder") end,expected={["n"]=2,[1]=true,[2]="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.cpmfolder"}},
{name="joinFolder",run=function() return joinFolder(nil,"x") end,expected={["n"]=2,[1]=true,[2]="x"}},
{name="joinFolder",run=function() return joinFolder("","x") end,expected={["n"]=2,[1]=true,[2]="x"}},
{name="joinFolder",run=function() return joinFolder("a","b") end,expected={["n"]=2,[1]=true,[2]="a/b"}},
{name="joinFolder",run=function() return joinFolder("a",nil) end,expected={["n"]=1,[1]="error"}},
{name="isInFolderTree",run=function() return isInFolderTree("a/b","a") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="isInFolderTree",run=function() return isInFolderTree("ab","a") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isInFolderTree",run=function() return isInFolderTree("a","a") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="isInFolderTree",run=function() return isInFolderTree("a","") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isInFolderTree",run=function() return isInFolderTree(nil,"a") end,expected={["n"]=1,[1]="error"}},
{name="addFolderAncestors",run=function() return (function() local t={}; addFolderAncestors(t,"a/b/c"); return t end)() end,expected={["n"]=2,[1]=true,[2]={["a"]=true,["a/b"]=true,["a/b/c"]=true}}},
{name="addFolderAncestors",run=function() return (function() local t={}; addFolderAncestors(t,""); return t end)() end,expected={["n"]=2,[1]=true,[2]={}}},
{name="validRelativePath",run=function() return validRelativePath(nil) end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validRelativePath",run=function() return validRelativePath(false) end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validRelativePath",run=function() return validRelativePath(42) end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validRelativePath",run=function() return validRelativePath("") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validRelativePath",run=function() return validRelativePath("a/b") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validRelativePath",run=function() return validRelativePath("a//b") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validRelativePath",run=function() return validRelativePath("a/../b") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validRelativePath",run=function() return validRelativePath("/a") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validRelativePath",run=function() return validRelativePath("a/") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validRelativePath",run=function() return validRelativePath("a\\b") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validRelativePath",run=function() return validRelativePath("a:b") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validRelativePath",run=function() return validRelativePath("CON") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validRelativePath",run=function() return validRelativePath("con.txt") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validRelativePath",run=function() return validRelativePath("COM1") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validRelativePath",run=function() return validRelativePath("COM0") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validRelativePath",run=function() return validRelativePath("LPT9") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validRelativePath",run=function() return validRelativePath("NUL") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validRelativePath",run=function() return validRelativePath("a.") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validRelativePath",run=function() return validRelativePath(" a ") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validRelativePath",run=function() return validRelativePath("a\000b") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validRelativePath",run=function() return validRelativePath("é猫") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validRelativePath",run=function() return validRelativePath(string.rep("a",65)) end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validRelativePath",run=function() return validRelativePath(string.rep("a/",11).."b") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validRelativePath",run=function() return validRelativePath(string.rep("a/",12).."b") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validRelativePath",run=function() return validRelativePath(string.rep("a",255)) end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validRelativePath",run=function() return validRelativePath(string.rep("a",256)) end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validRelativePath",run=function() return validRelativePath("x.preset") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validRelativePath",run=function() return validRelativePath(".preset") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validRelativePath",run=function() return validRelativePath("CON.preset") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validRelativePath",run=function() return validRelativePath("a\000.preset") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validRelativePath",run=function() return validRelativePath(string.rep("a",65)..".preset") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validRelativePath",run=function() return validRelativePath("x.CPMFOLDER") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validRelativePath",run=function() return validRelativePath(".cpmfolder") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validRelativePath",run=function() return validRelativePath("a/b.cpmfolder") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validRelativePath",run=function() return validRelativePath("a\000.cpmfolder") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validRelativePath",run=function() return validRelativePath(string.rep("a",246)..".cpmfolder") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="remapFolderTreePath",run=function() return remapFolderTreePath("a/b","a","z") end,expected={["n"]=2,[1]=true,[2]="z/b"}},
{name="remapFolderTreePath",run=function() return remapFolderTreePath("a","a","z") end,expected={["n"]=2,[1]=true,[2]="z"}},
{name="remapFolderTreePath",run=function() return remapFolderTreePath("ab","a","z") end,expected={["n"]=2,[1]=true,[2]="ab"}},
{name="validBundlePath",run=function() return validBundlePath(nil) end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validBundlePath",run=function() return validBundlePath(false) end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validBundlePath",run=function() return validBundlePath(42) end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validBundlePath",run=function() return validBundlePath("") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validBundlePath",run=function() return validBundlePath("a/b") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validBundlePath",run=function() return validBundlePath("a//b") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validBundlePath",run=function() return validBundlePath("a/../b") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validBundlePath",run=function() return validBundlePath("/a") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validBundlePath",run=function() return validBundlePath("a/") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validBundlePath",run=function() return validBundlePath("a\\b") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validBundlePath",run=function() return validBundlePath("a:b") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validBundlePath",run=function() return validBundlePath("CON") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validBundlePath",run=function() return validBundlePath("con.txt") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validBundlePath",run=function() return validBundlePath("COM1") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validBundlePath",run=function() return validBundlePath("COM0") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validBundlePath",run=function() return validBundlePath("LPT9") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validBundlePath",run=function() return validBundlePath("NUL") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validBundlePath",run=function() return validBundlePath("a.") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validBundlePath",run=function() return validBundlePath(" a ") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validBundlePath",run=function() return validBundlePath("a\000b") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validBundlePath",run=function() return validBundlePath("é猫") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validBundlePath",run=function() return validBundlePath(string.rep("a",65)) end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validBundlePath",run=function() return validBundlePath(string.rep("a/",11).."b") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validBundlePath",run=function() return validBundlePath(string.rep("a/",12).."b") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validBundlePath",run=function() return validBundlePath(string.rep("a",255)) end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validBundlePath",run=function() return validBundlePath(string.rep("a",256)) end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validBundlePath",run=function() return validBundlePath("x.preset") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validBundlePath",run=function() return validBundlePath(".preset") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validBundlePath",run=function() return validBundlePath("CON.preset") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validBundlePath",run=function() return validBundlePath("a\000.preset") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validBundlePath",run=function() return validBundlePath(string.rep("a",65)..".preset") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validBundlePath",run=function() return validBundlePath("x.CPMFOLDER") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validBundlePath",run=function() return validBundlePath(".cpmfolder") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validBundlePath",run=function() return validBundlePath("a/b.cpmfolder") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validBundlePath",run=function() return validBundlePath("a\000.cpmfolder") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validBundlePath",run=function() return validBundlePath(string.rep("a",246)..".cpmfolder") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validNativeRelativePath",run=function() return validNativeRelativePath(nil) end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validNativeRelativePath",run=function() return validNativeRelativePath(false) end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validNativeRelativePath",run=function() return validNativeRelativePath(42) end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validNativeRelativePath",run=function() return validNativeRelativePath("") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validNativeRelativePath",run=function() return validNativeRelativePath("a/b") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validNativeRelativePath",run=function() return validNativeRelativePath("a//b") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validNativeRelativePath",run=function() return validNativeRelativePath("a/../b") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validNativeRelativePath",run=function() return validNativeRelativePath("/a") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validNativeRelativePath",run=function() return validNativeRelativePath("a/") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validNativeRelativePath",run=function() return validNativeRelativePath("a\\b") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validNativeRelativePath",run=function() return validNativeRelativePath("a:b") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validNativeRelativePath",run=function() return validNativeRelativePath("CON") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validNativeRelativePath",run=function() return validNativeRelativePath("con.txt") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validNativeRelativePath",run=function() return validNativeRelativePath("COM1") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validNativeRelativePath",run=function() return validNativeRelativePath("COM0") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validNativeRelativePath",run=function() return validNativeRelativePath("LPT9") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validNativeRelativePath",run=function() return validNativeRelativePath("NUL") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validNativeRelativePath",run=function() return validNativeRelativePath("a.") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validNativeRelativePath",run=function() return validNativeRelativePath(" a ") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validNativeRelativePath",run=function() return validNativeRelativePath("a\000b") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validNativeRelativePath",run=function() return validNativeRelativePath("é猫") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validNativeRelativePath",run=function() return validNativeRelativePath(string.rep("a",65)) end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validNativeRelativePath",run=function() return validNativeRelativePath(string.rep("a/",11).."b") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validNativeRelativePath",run=function() return validNativeRelativePath(string.rep("a/",12).."b") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validNativeRelativePath",run=function() return validNativeRelativePath(string.rep("a",255)) end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validNativeRelativePath",run=function() return validNativeRelativePath(string.rep("a",256)) end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validNativeRelativePath",run=function() return validNativeRelativePath("x.preset") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validNativeRelativePath",run=function() return validNativeRelativePath(".preset") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validNativeRelativePath",run=function() return validNativeRelativePath("CON.preset") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validNativeRelativePath",run=function() return validNativeRelativePath("a\000.preset") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validNativeRelativePath",run=function() return validNativeRelativePath(string.rep("a",65)..".preset") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validNativeRelativePath",run=function() return validNativeRelativePath("x.CPMFOLDER") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validNativeRelativePath",run=function() return validNativeRelativePath(".cpmfolder") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validNativeRelativePath",run=function() return validNativeRelativePath("a/b.cpmfolder") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validNativeRelativePath",run=function() return validNativeRelativePath("a\000.cpmfolder") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validNativeRelativePath",run=function() return validNativeRelativePath(string.rep("a",246)..".cpmfolder") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isFolderBundleFilename",run=function() return isFolderBundleFilename(nil) end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isFolderBundleFilename",run=function() return isFolderBundleFilename(false) end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isFolderBundleFilename",run=function() return isFolderBundleFilename(42) end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isFolderBundleFilename",run=function() return isFolderBundleFilename("") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isFolderBundleFilename",run=function() return isFolderBundleFilename("a/b") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isFolderBundleFilename",run=function() return isFolderBundleFilename("a//b") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isFolderBundleFilename",run=function() return isFolderBundleFilename("a/../b") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isFolderBundleFilename",run=function() return isFolderBundleFilename("/a") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isFolderBundleFilename",run=function() return isFolderBundleFilename("a/") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isFolderBundleFilename",run=function() return isFolderBundleFilename("a\\b") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isFolderBundleFilename",run=function() return isFolderBundleFilename("a:b") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isFolderBundleFilename",run=function() return isFolderBundleFilename("CON") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isFolderBundleFilename",run=function() return isFolderBundleFilename("con.txt") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isFolderBundleFilename",run=function() return isFolderBundleFilename("COM1") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isFolderBundleFilename",run=function() return isFolderBundleFilename("COM0") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isFolderBundleFilename",run=function() return isFolderBundleFilename("LPT9") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isFolderBundleFilename",run=function() return isFolderBundleFilename("NUL") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isFolderBundleFilename",run=function() return isFolderBundleFilename("a.") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isFolderBundleFilename",run=function() return isFolderBundleFilename(" a ") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isFolderBundleFilename",run=function() return isFolderBundleFilename("a\000b") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isFolderBundleFilename",run=function() return isFolderBundleFilename("é猫") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isFolderBundleFilename",run=function() return isFolderBundleFilename(string.rep("a",65)) end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isFolderBundleFilename",run=function() return isFolderBundleFilename(string.rep("a/",11).."b") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isFolderBundleFilename",run=function() return isFolderBundleFilename(string.rep("a/",12).."b") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isFolderBundleFilename",run=function() return isFolderBundleFilename(string.rep("a",255)) end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isFolderBundleFilename",run=function() return isFolderBundleFilename(string.rep("a",256)) end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isFolderBundleFilename",run=function() return isFolderBundleFilename("x.preset") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isFolderBundleFilename",run=function() return isFolderBundleFilename(".preset") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isFolderBundleFilename",run=function() return isFolderBundleFilename("CON.preset") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isFolderBundleFilename",run=function() return isFolderBundleFilename("a\000.preset") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isFolderBundleFilename",run=function() return isFolderBundleFilename(string.rep("a",65)..".preset") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isFolderBundleFilename",run=function() return isFolderBundleFilename("x.CPMFOLDER") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="isFolderBundleFilename",run=function() return isFolderBundleFilename(".cpmfolder") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="isFolderBundleFilename",run=function() return isFolderBundleFilename("a/b.cpmfolder") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isFolderBundleFilename",run=function() return isFolderBundleFilename("a\000.cpmfolder") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isFolderBundleFilename",run=function() return isFolderBundleFilename(string.rep("a",246)..".cpmfolder") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validTrashFilename",run=function() return validTrashFilename(nil) end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validTrashFilename",run=function() return validTrashFilename(false) end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validTrashFilename",run=function() return validTrashFilename(42) end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validTrashFilename",run=function() return validTrashFilename("") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validTrashFilename",run=function() return validTrashFilename("a/b") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validTrashFilename",run=function() return validTrashFilename("a//b") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validTrashFilename",run=function() return validTrashFilename("a/../b") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validTrashFilename",run=function() return validTrashFilename("/a") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validTrashFilename",run=function() return validTrashFilename("a/") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validTrashFilename",run=function() return validTrashFilename("a\\b") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validTrashFilename",run=function() return validTrashFilename("a:b") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validTrashFilename",run=function() return validTrashFilename("CON") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validTrashFilename",run=function() return validTrashFilename("con.txt") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validTrashFilename",run=function() return validTrashFilename("COM1") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validTrashFilename",run=function() return validTrashFilename("COM0") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validTrashFilename",run=function() return validTrashFilename("LPT9") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validTrashFilename",run=function() return validTrashFilename("NUL") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validTrashFilename",run=function() return validTrashFilename("a.") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validTrashFilename",run=function() return validTrashFilename(" a ") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validTrashFilename",run=function() return validTrashFilename("a\000b") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validTrashFilename",run=function() return validTrashFilename("é猫") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validTrashFilename",run=function() return validTrashFilename(string.rep("a",65)) end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validTrashFilename",run=function() return validTrashFilename(string.rep("a/",11).."b") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validTrashFilename",run=function() return validTrashFilename(string.rep("a/",12).."b") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validTrashFilename",run=function() return validTrashFilename(string.rep("a",255)) end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validTrashFilename",run=function() return validTrashFilename(string.rep("a",256)) end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validTrashFilename",run=function() return validTrashFilename("x.preset") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validTrashFilename",run=function() return validTrashFilename(".preset") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validTrashFilename",run=function() return validTrashFilename("CON.preset") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validTrashFilename",run=function() return validTrashFilename("a\000.preset") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="validTrashFilename",run=function() return validTrashFilename(string.rep("a",65)..".preset") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validTrashFilename",run=function() return validTrashFilename("x.CPMFOLDER") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validTrashFilename",run=function() return validTrashFilename(".cpmfolder") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validTrashFilename",run=function() return validTrashFilename("a/b.cpmfolder") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validTrashFilename",run=function() return validTrashFilename("a\000.cpmfolder") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="validTrashFilename",run=function() return validTrashFilename(string.rep("a",246)..".cpmfolder") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="sanitizeName",run=function() return sanitizeName(nil) end,expected={["n"]=2,[1]=true,[2]=""}},
{name="sanitizeName",run=function() return sanitizeName(false) end,expected={["n"]=2,[1]=true,[2]=""}},
{name="sanitizeName",run=function() return sanitizeName(42) end,expected={["n"]=2,[1]=true,[2]="42"}},
{name="sanitizeName",run=function() return sanitizeName("") end,expected={["n"]=2,[1]=true,[2]=""}},
{name="sanitizeName",run=function() return sanitizeName("a/b") end,expected={["n"]=2,[1]=true,[2]="a_b"}},
{name="sanitizeName",run=function() return sanitizeName("a//b") end,expected={["n"]=2,[1]=true,[2]="a__b"}},
{name="sanitizeName",run=function() return sanitizeName("a/../b") end,expected={["n"]=2,[1]=true,[2]="a_.._b"}},
{name="sanitizeName",run=function() return sanitizeName("/a") end,expected={["n"]=2,[1]=true,[2]="_a"}},
{name="sanitizeName",run=function() return sanitizeName("a/") end,expected={["n"]=2,[1]=true,[2]="a_"}},
{name="sanitizeName",run=function() return sanitizeName("a\\b") end,expected={["n"]=2,[1]=true,[2]="a_b"}},
{name="sanitizeName",run=function() return sanitizeName("a:b") end,expected={["n"]=2,[1]=true,[2]="a_b"}},
{name="sanitizeName",run=function() return sanitizeName("CON") end,expected={["n"]=2,[1]=true,[2]="CON"}},
{name="sanitizeName",run=function() return sanitizeName("con.txt") end,expected={["n"]=2,[1]=true,[2]="con.txt"}},
{name="sanitizeName",run=function() return sanitizeName("COM1") end,expected={["n"]=2,[1]=true,[2]="COM1"}},
{name="sanitizeName",run=function() return sanitizeName("COM0") end,expected={["n"]=2,[1]=true,[2]="COM0"}},
{name="sanitizeName",run=function() return sanitizeName("LPT9") end,expected={["n"]=2,[1]=true,[2]="LPT9"}},
{name="sanitizeName",run=function() return sanitizeName("NUL") end,expected={["n"]=2,[1]=true,[2]="NUL"}},
{name="sanitizeName",run=function() return sanitizeName("a.") end,expected={["n"]=2,[1]=true,[2]="a."}},
{name="sanitizeName",run=function() return sanitizeName(" a ") end,expected={["n"]=2,[1]=true,[2]="a"}},
{name="sanitizeName",run=function() return sanitizeName("a\000b") end,expected={["n"]=2,[1]=true,[2]="a_b"}},
{name="sanitizeName",run=function() return sanitizeName("é猫") end,expected={["n"]=2,[1]=true,[2]="\195\169\231\140\171"}},
{name="sanitizeName",run=function() return sanitizeName(string.rep("a",65)) end,expected={["n"]=2,[1]=true,[2]="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}},
{name="sanitizeName",run=function() return sanitizeName(string.rep("a/",11).."b") end,expected={["n"]=2,[1]=true,[2]="a_a_a_a_a_a_a_a_a_a_a_b"}},
{name="sanitizeName",run=function() return sanitizeName(string.rep("a/",12).."b") end,expected={["n"]=2,[1]=true,[2]="a_a_a_a_a_a_a_a_a_a_a_a_b"}},
{name="sanitizeName",run=function() return sanitizeName(string.rep("a",255)) end,expected={["n"]=2,[1]=true,[2]="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}},
{name="sanitizeName",run=function() return sanitizeName(string.rep("a",256)) end,expected={["n"]=2,[1]=true,[2]="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}},
{name="sanitizeName",run=function() return sanitizeName("x.preset") end,expected={["n"]=2,[1]=true,[2]="x.preset"}},
{name="sanitizeName",run=function() return sanitizeName(".preset") end,expected={["n"]=2,[1]=true,[2]=".preset"}},
{name="sanitizeName",run=function() return sanitizeName("CON.preset") end,expected={["n"]=2,[1]=true,[2]="CON.preset"}},
{name="sanitizeName",run=function() return sanitizeName("a\000.preset") end,expected={["n"]=2,[1]=true,[2]="a_.preset"}},
{name="sanitizeName",run=function() return sanitizeName(string.rep("a",65)..".preset") end,expected={["n"]=2,[1]=true,[2]="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}},
{name="sanitizeName",run=function() return sanitizeName("x.CPMFOLDER") end,expected={["n"]=2,[1]=true,[2]="x.CPMFOLDER"}},
{name="sanitizeName",run=function() return sanitizeName(".cpmfolder") end,expected={["n"]=2,[1]=true,[2]=".cpmfolder"}},
{name="sanitizeName",run=function() return sanitizeName("a/b.cpmfolder") end,expected={["n"]=2,[1]=true,[2]="a_b.cpmfolder"}},
{name="sanitizeName",run=function() return sanitizeName("a\000.cpmfolder") end,expected={["n"]=2,[1]=true,[2]="a_.cpmfolder"}},
{name="sanitizeName",run=function() return sanitizeName(string.rep("a",246)..".cpmfolder") end,expected={["n"]=2,[1]=true,[2]="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}},
{name="sanitizeMetadata",run=function() return sanitizeMetadata(nil,3) end,expected={["n"]=2,[1]=true,[2]=""}},
{name="sanitizeMetadata",run=function() return sanitizeMetadata(false,3) end,expected={["n"]=2,[1]=true,[2]=""}},
{name="sanitizeMetadata",run=function() return sanitizeMetadata(42,3) end,expected={["n"]=2,[1]=true,[2]="42"}},
{name="sanitizeMetadata",run=function() return sanitizeMetadata("",3) end,expected={["n"]=2,[1]=true,[2]=""}},
{name="sanitizeMetadata",run=function() return sanitizeMetadata("a/b",3) end,expected={["n"]=2,[1]=true,[2]="a/b"}},
{name="sanitizeMetadata",run=function() return sanitizeMetadata("a//b",3) end,expected={["n"]=2,[1]=true,[2]="a//"}},
{name="sanitizeMetadata",run=function() return sanitizeMetadata("a/../b",3) end,expected={["n"]=2,[1]=true,[2]="a/."}},
{name="sanitizeMetadata",run=function() return sanitizeMetadata("/a",3) end,expected={["n"]=2,[1]=true,[2]="/a"}},
{name="sanitizeMetadata",run=function() return sanitizeMetadata("a/",3) end,expected={["n"]=2,[1]=true,[2]="a/"}},
{name="sanitizeMetadata",run=function() return sanitizeMetadata("a\\b",3) end,expected={["n"]=2,[1]=true,[2]="a\092b"}},
{name="sanitizeMetadata",run=function() return sanitizeMetadata("a:b",3) end,expected={["n"]=2,[1]=true,[2]="a:b"}},
{name="sanitizeMetadata",run=function() return sanitizeMetadata("CON",3) end,expected={["n"]=2,[1]=true,[2]="CON"}},
{name="sanitizeMetadata",run=function() return sanitizeMetadata("con.txt",3) end,expected={["n"]=2,[1]=true,[2]="con"}},
{name="sanitizeMetadata",run=function() return sanitizeMetadata("COM1",3) end,expected={["n"]=2,[1]=true,[2]="COM"}},
{name="sanitizeMetadata",run=function() return sanitizeMetadata("COM0",3) end,expected={["n"]=2,[1]=true,[2]="COM"}},
{name="sanitizeMetadata",run=function() return sanitizeMetadata("LPT9",3) end,expected={["n"]=2,[1]=true,[2]="LPT"}},
{name="sanitizeMetadata",run=function() return sanitizeMetadata("NUL",3) end,expected={["n"]=2,[1]=true,[2]="NUL"}},
{name="sanitizeMetadata",run=function() return sanitizeMetadata("a.",3) end,expected={["n"]=2,[1]=true,[2]="a."}},
{name="sanitizeMetadata",run=function() return sanitizeMetadata(" a ",3) end,expected={["n"]=2,[1]=true,[2]="a"}},
{name="sanitizeMetadata",run=function() return sanitizeMetadata("a\000b",3) end,expected={["n"]=2,[1]=true,[2]="a b"}},
{name="sanitizeMetadata",run=function() return sanitizeMetadata("é猫",3) end,expected={["n"]=2,[1]=true,[2]="\195\169\231"}},
{name="sanitizeMetadata",run=function() return sanitizeMetadata(string.rep("a",65),3) end,expected={["n"]=2,[1]=true,[2]="aaa"}},
{name="validatedPresetName",run=function() return validatedPresetName(nil) end,expected={["n"]=3,[1]=true,[3]="Enter a name."}},
{name="validatedPresetName",run=function() return validatedPresetName(false) end,expected={["n"]=3,[1]=true,[3]="Enter a name."}},
{name="validatedPresetName",run=function() return validatedPresetName(42) end,expected={["n"]=2,[1]=true,[2]="42"}},
{name="validatedPresetName",run=function() return validatedPresetName("") end,expected={["n"]=3,[1]=true,[3]="Enter a name."}},
{name="validatedPresetName",run=function() return validatedPresetName("a/b") end,expected={["n"]=2,[1]=true,[2]="a_b"}},
{name="validatedPresetName",run=function() return validatedPresetName("a//b") end,expected={["n"]=2,[1]=true,[2]="a__b"}},
{name="validatedPresetName",run=function() return validatedPresetName("a/../b") end,expected={["n"]=2,[1]=true,[2]="a_.._b"}},
{name="validatedPresetName",run=function() return validatedPresetName("/a") end,expected={["n"]=2,[1]=true,[2]="_a"}},
{name="validatedPresetName",run=function() return validatedPresetName("a/") end,expected={["n"]=2,[1]=true,[2]="a_"}},
{name="validatedPresetName",run=function() return validatedPresetName("a\\b") end,expected={["n"]=2,[1]=true,[2]="a_b"}},
{name="validatedPresetName",run=function() return validatedPresetName("a:b") end,expected={["n"]=2,[1]=true,[2]="a_b"}},
{name="validatedPresetName",run=function() return validatedPresetName("CON") end,expected={["n"]=3,[1]=true,[3]="\034CON\034 is a reserved Windows name. Enter another name."}},
{name="validatedPresetName",run=function() return validatedPresetName("con.txt") end,expected={["n"]=3,[1]=true,[3]="\034con.txt\034 is a reserved Windows name. Enter another name."}},
{name="validatedPresetName",run=function() return validatedPresetName("COM1") end,expected={["n"]=3,[1]=true,[3]="\034COM1\034 is a reserved Windows name. Enter another name."}},
{name="validatedPresetName",run=function() return validatedPresetName("COM0") end,expected={["n"]=2,[1]=true,[2]="COM0"}},
{name="validatedPresetName",run=function() return validatedPresetName("LPT9") end,expected={["n"]=3,[1]=true,[3]="\034LPT9\034 is a reserved Windows name. Enter another name."}},
{name="validatedPresetName",run=function() return validatedPresetName("NUL") end,expected={["n"]=3,[1]=true,[3]="\034NUL\034 is a reserved Windows name. Enter another name."}},
{name="validatedPresetName",run=function() return validatedPresetName("a.") end,expected={["n"]=3,[1]=true,[3]="Preset names cannot end with a period or space."}},
{name="validatedPresetName",run=function() return validatedPresetName(" a ") end,expected={["n"]=2,[1]=true,[2]="a"}},
{name="validatedPresetName",run=function() return validatedPresetName("a\000b") end,expected={["n"]=2,[1]=true,[2]="a_b"}},
{name="validatedPresetName",run=function() return validatedPresetName("é猫") end,expected={["n"]=2,[1]=true,[2]="\195\169\231\140\171"}},
{name="validatedPresetName",run=function() return validatedPresetName(string.rep("a",65)) end,expected={["n"]=2,[1]=true,[2]="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}},
{name="validatedPresetName",run=function() return validatedPresetName(string.rep("a/",11).."b") end,expected={["n"]=2,[1]=true,[2]="a_a_a_a_a_a_a_a_a_a_a_b"}},
{name="validatedPresetName",run=function() return validatedPresetName(string.rep("a/",12).."b") end,expected={["n"]=2,[1]=true,[2]="a_a_a_a_a_a_a_a_a_a_a_a_b"}},
{name="validatedPresetName",run=function() return validatedPresetName(string.rep("a",255)) end,expected={["n"]=2,[1]=true,[2]="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}},
{name="validatedPresetName",run=function() return validatedPresetName(string.rep("a",256)) end,expected={["n"]=2,[1]=true,[2]="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}},
{name="validatedPresetName",run=function() return validatedPresetName("x.preset") end,expected={["n"]=2,[1]=true,[2]="x.preset"}},
{name="validatedPresetName",run=function() return validatedPresetName(".preset") end,expected={["n"]=2,[1]=true,[2]=".preset"}},
{name="validatedPresetName",run=function() return validatedPresetName("CON.preset") end,expected={["n"]=3,[1]=true,[3]="\034CON.preset\034 is a reserved Windows name. Enter another name."}},
{name="validatedPresetName",run=function() return validatedPresetName("a\000.preset") end,expected={["n"]=2,[1]=true,[2]="a_.preset"}},
{name="validatedPresetName",run=function() return validatedPresetName(string.rep("a",65)..".preset") end,expected={["n"]=2,[1]=true,[2]="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}},
{name="validatedPresetName",run=function() return validatedPresetName("x.CPMFOLDER") end,expected={["n"]=2,[1]=true,[2]="x.CPMFOLDER"}},
{name="validatedPresetName",run=function() return validatedPresetName(".cpmfolder") end,expected={["n"]=2,[1]=true,[2]=".cpmfolder"}},
{name="validatedPresetName",run=function() return validatedPresetName("a/b.cpmfolder") end,expected={["n"]=2,[1]=true,[2]="a_b.cpmfolder"}},
{name="validatedPresetName",run=function() return validatedPresetName("a\000.cpmfolder") end,expected={["n"]=2,[1]=true,[2]="a_.cpmfolder"}},
{name="validatedPresetName",run=function() return validatedPresetName(string.rep("a",246)..".cpmfolder") end,expected={["n"]=2,[1]=true,[2]="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}},
{name="validatedFolderName",run=function() return validatedFolderName(nil) end,expected={["n"]=3,[1]=true,[3]="Enter a name."}},
{name="validatedFolderName",run=function() return validatedFolderName(false) end,expected={["n"]=3,[1]=true,[3]="Enter a name."}},
{name="validatedFolderName",run=function() return validatedFolderName(42) end,expected={["n"]=2,[1]=true,[2]="42"}},
{name="validatedFolderName",run=function() return validatedFolderName("") end,expected={["n"]=3,[1]=true,[3]="Enter a name."}},
{name="validatedFolderName",run=function() return validatedFolderName("a/b") end,expected={["n"]=2,[1]=true,[2]="a_b"}},
{name="validatedFolderName",run=function() return validatedFolderName("a//b") end,expected={["n"]=2,[1]=true,[2]="a__b"}},
{name="validatedFolderName",run=function() return validatedFolderName("a/../b") end,expected={["n"]=2,[1]=true,[2]="a_.._b"}},
{name="validatedFolderName",run=function() return validatedFolderName("/a") end,expected={["n"]=2,[1]=true,[2]="_a"}},
{name="validatedFolderName",run=function() return validatedFolderName("a/") end,expected={["n"]=2,[1]=true,[2]="a_"}},
{name="validatedFolderName",run=function() return validatedFolderName("a\\b") end,expected={["n"]=2,[1]=true,[2]="a_b"}},
{name="validatedFolderName",run=function() return validatedFolderName("a:b") end,expected={["n"]=2,[1]=true,[2]="a_b"}},
{name="validatedFolderName",run=function() return validatedFolderName("CON") end,expected={["n"]=3,[1]=true,[3]="\034CON\034 is a reserved Windows name. Enter another name."}},
{name="validatedFolderName",run=function() return validatedFolderName("con.txt") end,expected={["n"]=3,[1]=true,[3]="\034con.txt\034 is a reserved Windows name. Enter another name."}},
{name="validatedFolderName",run=function() return validatedFolderName("COM1") end,expected={["n"]=3,[1]=true,[3]="\034COM1\034 is a reserved Windows name. Enter another name."}},
{name="validatedFolderName",run=function() return validatedFolderName("COM0") end,expected={["n"]=2,[1]=true,[2]="COM0"}},
{name="validatedFolderName",run=function() return validatedFolderName("LPT9") end,expected={["n"]=3,[1]=true,[3]="\034LPT9\034 is a reserved Windows name. Enter another name."}},
{name="validatedFolderName",run=function() return validatedFolderName("NUL") end,expected={["n"]=3,[1]=true,[3]="\034NUL\034 is a reserved Windows name. Enter another name."}},
{name="validatedFolderName",run=function() return validatedFolderName("a.") end,expected={["n"]=3,[1]=true,[3]="Folder names cannot end with a period or space."}},
{name="validatedFolderName",run=function() return validatedFolderName(" a ") end,expected={["n"]=2,[1]=true,[2]="a"}},
{name="validatedFolderName",run=function() return validatedFolderName("a\000b") end,expected={["n"]=2,[1]=true,[2]="a_b"}},
{name="validatedFolderName",run=function() return validatedFolderName("é猫") end,expected={["n"]=2,[1]=true,[2]="\195\169\231\140\171"}},
{name="validatedFolderName",run=function() return validatedFolderName(string.rep("a",65)) end,expected={["n"]=2,[1]=true,[2]="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}},
{name="validatedFolderName",run=function() return validatedFolderName(string.rep("a/",11).."b") end,expected={["n"]=2,[1]=true,[2]="a_a_a_a_a_a_a_a_a_a_a_b"}},
{name="validatedFolderName",run=function() return validatedFolderName(string.rep("a/",12).."b") end,expected={["n"]=2,[1]=true,[2]="a_a_a_a_a_a_a_a_a_a_a_a_b"}},
{name="validatedFolderName",run=function() return validatedFolderName(string.rep("a",255)) end,expected={["n"]=2,[1]=true,[2]="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}},
{name="validatedFolderName",run=function() return validatedFolderName(string.rep("a",256)) end,expected={["n"]=2,[1]=true,[2]="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}},
{name="validatedFolderName",run=function() return validatedFolderName("x.preset") end,expected={["n"]=2,[1]=true,[2]="x.preset"}},
{name="validatedFolderName",run=function() return validatedFolderName(".preset") end,expected={["n"]=2,[1]=true,[2]=".preset"}},
{name="validatedFolderName",run=function() return validatedFolderName("CON.preset") end,expected={["n"]=3,[1]=true,[3]="\034CON.preset\034 is a reserved Windows name. Enter another name."}},
{name="validatedFolderName",run=function() return validatedFolderName("a\000.preset") end,expected={["n"]=2,[1]=true,[2]="a_.preset"}},
{name="validatedFolderName",run=function() return validatedFolderName(string.rep("a",65)..".preset") end,expected={["n"]=2,[1]=true,[2]="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}},
{name="validatedFolderName",run=function() return validatedFolderName("x.CPMFOLDER") end,expected={["n"]=2,[1]=true,[2]="x.CPMFOLDER"}},
{name="validatedFolderName",run=function() return validatedFolderName(".cpmfolder") end,expected={["n"]=2,[1]=true,[2]=".cpmfolder"}},
{name="validatedFolderName",run=function() return validatedFolderName("a/b.cpmfolder") end,expected={["n"]=2,[1]=true,[2]="a_b.cpmfolder"}},
{name="validatedFolderName",run=function() return validatedFolderName("a\000.cpmfolder") end,expected={["n"]=2,[1]=true,[2]="a_.cpmfolder"}},
{name="validatedFolderName",run=function() return validatedFolderName(string.rep("a",246)..".cpmfolder") end,expected={["n"]=2,[1]=true,[2]="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}},
{name="findPresetCollision",run=function() return findPresetCollision("a") end,expected={["n"]=2,[1]=true,[2]="A"}},
{name="findPresetCollision",run=function() return findPresetCollision("A","A") end,expected={["n"]=2,[1]=true}},
{name="findPresetCollision",run=function() return findPresetCollision("missing") end,expected={["n"]=2,[1]=true}},
{name="uniqueStorageName",run=function() return (function() local used={}; local result=uniqueStorageName("x",used); return result,used end)() end,expected={["n"]=3,[1]=true,[2]="x",[3]={["x.preset"]=true}}},
{name="uniqueStorageName",run=function() return (function() local used={["x.preset"]=true}; local result=uniqueStorageName("x",used); return result,used end)() end,expected={["n"]=3,[1]=true,[2]="x 2",[3]={["x 2.preset"]=true,["x.preset"]=true}}},
{name="uniqueStorageName",run=function() return (function() local used={[string.rep("a",64)..".preset"]=true}; local result=uniqueStorageName(string.rep("a",64),used); return result,used end)() end,expected={["n"]=3,[1]=true,[2]="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa 2",[3]={["aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa 2.preset"]=true,["aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.preset"]=true}}},
{name="findExistingFolderName",run=function() return findExistingFolderName("folder") end,expected={["n"]=2,[1]=true,[2]="Folder"}},
{name="findExistingFolderName",run=function() return findExistingFolderName("Folder","Folder") end,expected={["n"]=2,[1]=true}},
{name="findExistingFolderName",run=function() return findExistingFolderName("missing") end,expected={["n"]=2,[1]=true}},
{name="folderNameExists",run=function() return folderNameExists("folder") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="folderNameExists",run=function() return folderNameExists("missing") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="uniquePresetCopyName",run=function() return uniquePresetCopyName("A") end,expected={["n"]=2,[1]=true,[2]="A Copy 2"}},
{name="uniquePresetCopyName",run=function() return uniquePresetCopyName("sub/A") end,expected={["n"]=2,[1]=true,[2]="sub/A Copy"}},
{name="uniqueFolderCopyName",run=function() return uniqueFolderCopyName("Folder") end,expected={["n"]=2,[1]=true,[2]="Folder Copy 2"}},
{name="uniqueFolderCopyName",run=function() return uniqueFolderCopyName("sub/Folder") end,expected={["n"]=2,[1]=true,[2]="sub/Folder Copy"}},
{name="isRuntimePointerText",run=function() return isRuntimePointerText(nil) end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isRuntimePointerText",run=function() return isRuntimePointerText(false) end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isRuntimePointerText",run=function() return isRuntimePointerText(42) end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isRuntimePointerText",run=function() return isRuntimePointerText("") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isRuntimePointerText",run=function() return isRuntimePointerText("a/b") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isRuntimePointerText",run=function() return isRuntimePointerText("a//b") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isRuntimePointerText",run=function() return isRuntimePointerText("a/../b") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isRuntimePointerText",run=function() return isRuntimePointerText("/a") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isRuntimePointerText",run=function() return isRuntimePointerText("a/") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isRuntimePointerText",run=function() return isRuntimePointerText("a\\b") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isRuntimePointerText",run=function() return isRuntimePointerText("a:b") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isRuntimePointerText",run=function() return isRuntimePointerText("CON") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isRuntimePointerText",run=function() return isRuntimePointerText("con.txt") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isRuntimePointerText",run=function() return isRuntimePointerText("COM1") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isRuntimePointerText",run=function() return isRuntimePointerText("COM0") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isRuntimePointerText",run=function() return isRuntimePointerText("LPT9") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isRuntimePointerText",run=function() return isRuntimePointerText("NUL") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isRuntimePointerText",run=function() return isRuntimePointerText("a.") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isRuntimePointerText",run=function() return isRuntimePointerText(" a ") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isRuntimePointerText",run=function() return isRuntimePointerText("a\000b") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isRuntimePointerText",run=function() return isRuntimePointerText("é猫") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isRuntimePointerText",run=function() return isRuntimePointerText(string.rep("a",65)) end,expected={["n"]=2,[1]=true,[2]=false}},
{name="isRuntimePointerText",run=function() return isRuntimePointerText("userdata: 0xABC") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="isRuntimePointerText",run=function() return isRuntimePointerText("table: 0x123") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="isRuntimePointerText",run=function() return isRuntimePointerText("function: 0xff") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="isRuntimePointerText",run=function() return isRuntimePointerText("thread: 0x1") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="stableChoiceIdentity",run=function() return stableChoiceIdentity(nil) end,expected={["n"]=2,[1]=true}},
{name="stableChoiceIdentity",run=function() return stableChoiceIdentity(false) end,expected={["n"]=2,[1]=true}},
{name="stableChoiceIdentity",run=function() return stableChoiceIdentity(42) end,expected={["n"]=2,[1]=true}},
{name="stableChoiceIdentity",run=function() return stableChoiceIdentity("") end,expected={["n"]=2,[1]=true}},
{name="stableChoiceIdentity",run=function() return stableChoiceIdentity("a/b") end,expected={["n"]=2,[1]=true}},
{name="stableChoiceIdentity",run=function() return stableChoiceIdentity("a//b") end,expected={["n"]=2,[1]=true}},
{name="stableChoiceIdentity",run=function() return stableChoiceIdentity("a/../b") end,expected={["n"]=2,[1]=true}},
{name="stableChoiceIdentity",run=function() return stableChoiceIdentity("/a") end,expected={["n"]=2,[1]=true}},
{name="stableChoiceIdentity",run=function() return stableChoiceIdentity("a/") end,expected={["n"]=2,[1]=true}},
{name="stableChoiceIdentity",run=function() return stableChoiceIdentity("a\\b") end,expected={["n"]=2,[1]=true}},
{name="stableChoiceIdentity",run=function() return stableChoiceIdentity("a:b") end,expected={["n"]=2,[1]=true}},
{name="stableChoiceIdentity",run=function() return stableChoiceIdentity("CON") end,expected={["n"]=2,[1]=true}},
{name="stableChoiceIdentity",run=function() return stableChoiceIdentity("con.txt") end,expected={["n"]=2,[1]=true}},
{name="stableChoiceIdentity",run=function() return stableChoiceIdentity("COM1") end,expected={["n"]=2,[1]=true}},
{name="stableChoiceIdentity",run=function() return stableChoiceIdentity("COM0") end,expected={["n"]=2,[1]=true}},
{name="stableChoiceIdentity",run=function() return stableChoiceIdentity("LPT9") end,expected={["n"]=2,[1]=true}},
{name="stableChoiceIdentity",run=function() return stableChoiceIdentity("NUL") end,expected={["n"]=2,[1]=true}},
{name="stableChoiceIdentity",run=function() return stableChoiceIdentity("a.") end,expected={["n"]=2,[1]=true}},
{name="stableChoiceIdentity",run=function() return stableChoiceIdentity(" a ") end,expected={["n"]=2,[1]=true}},
{name="stableChoiceIdentity",run=function() return stableChoiceIdentity("a\000b") end,expected={["n"]=2,[1]=true}},
{name="stableChoiceIdentity",run=function() return stableChoiceIdentity("é猫") end,expected={["n"]=2,[1]=true}},
{name="stableChoiceIdentity",run=function() return stableChoiceIdentity(string.rep("a",65)) end,expected={["n"]=2,[1]=true}},
{name="stableChoiceIdentity",run=function() return stableChoiceIdentity("definitions:a") end,expected={["n"]=2,[1]=true,[2]="definitions:a"}},
{name="stableChoiceIdentity",run=function() return stableChoiceIdentity("definitions:a") end,expected={["n"]=2,[1]=true,[2]="definitions:a"}},
{name="stableChoiceIdentity",run=function() return stableChoiceIdentity("options:a:b") end,expected={["n"]=2,[1]=true,[2]="options:a:b"}},
{name="stableChoiceIdentity",run=function() return stableChoiceIdentity("morphNames:猫") end,expected={["n"]=2,[1]=true,[2]="morphNames:\231\140\171"}},
{name="stableChoiceIdentity",run=function() return stableChoiceIdentity("options:") end,expected={["n"]=2,[1]=true}},
{name="stableChoiceIdentity",run=function() return stableChoiceIdentity("other:a") end,expected={["n"]=2,[1]=true}},
{name="stableChoiceIdentity",run=function() return stableChoiceIdentity("definitions:table: 0x123") end,expected={["n"]=2,[1]=true}},
{name="occurrenceKeyParts",run=function() return occurrenceKeyParts(nil) end,expected={["n"]=3,[1]=true,[2]="",[3]=1}},
{name="occurrenceKeyParts",run=function() return occurrenceKeyParts("x\0312") end,expected={["n"]=3,[1]=true,[2]="x",[3]=2}},
{name="occurrenceKeyParts",run=function() return occurrenceKeyParts("x\0310") end,expected={["n"]=3,[1]=true,[2]="x",[3]=0}},
{name="occurrenceKeyParts",run=function() return occurrenceKeyParts("x\031bad") end,expected={["n"]=3,[1]=true,[2]="x\031bad",[3]=1}},
{name="occurrenceKeyParts",run=function() return occurrenceKeyParts("x\0312\0313") end,expected={["n"]=3,[1]=true,[2]="x\0312",[3]=3}},
{name="optionIndexValidationError",run=function() return optionIndexValidationError(nil) end,expected={["n"]=2,[1]=true,[2]="not numeric"}},
{name="optionIndexValidationError",run=function() return optionIndexValidationError("1") end,expected={["n"]=2,[1]=true,[2]="not numeric"}},
{name="optionIndexValidationError",run=function() return optionIndexValidationError(0) end,expected={["n"]=2,[1]=true}},
{name="optionIndexValidationError",run=function() return optionIndexValidationError(-1) end,expected={["n"]=2,[1]=true,[2]="below zero"}},
{name="optionIndexValidationError",run=function() return optionIndexValidationError(1.5) end,expected={["n"]=2,[1]=true,[2]="not an integer"}},
{name="optionIndexValidationError",run=function() return optionIndexValidationError(65536) end,expected={["n"]=2,[1]=true}},
{name="optionIndexValidationError",run=function() return optionIndexValidationError(4294967295) end,expected={["n"]=2,[1]=true}},
{name="optionIndexValidationError",run=function() return optionIndexValidationError(4294967296) end,expected={["n"]=2,[1]=true,[2]="above the native Uint32 maximum"}},
{name="optionIndexValidationError",run=function() return optionIndexValidationError(0/0) end,expected={["n"]=2,[1]=true,[2]="not an integer"}},
{name="optionIndexValidationError",run=function() return optionIndexValidationError(math.huge) end,expected={["n"]=2,[1]=true,[2]="above the native Uint32 maximum"}},
{name="optionIndexIsValid",run=function() return optionIndexIsValid(nil) end,expected={["n"]=2,[1]=true,[2]=false}},
{name="optionIndexIsValid",run=function() return optionIndexIsValid("1") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="optionIndexIsValid",run=function() return optionIndexIsValid(0) end,expected={["n"]=2,[1]=true,[2]=true}},
{name="optionIndexIsValid",run=function() return optionIndexIsValid(-1) end,expected={["n"]=2,[1]=true,[2]=false}},
{name="optionIndexIsValid",run=function() return optionIndexIsValid(1.5) end,expected={["n"]=2,[1]=true,[2]=false}},
{name="optionIndexIsValid",run=function() return optionIndexIsValid(65536) end,expected={["n"]=2,[1]=true,[2]=true}},
{name="optionIndexIsValid",run=function() return optionIndexIsValid(4294967295) end,expected={["n"]=2,[1]=true,[2]=true}},
{name="optionIndexIsValid",run=function() return optionIndexIsValid(4294967296) end,expected={["n"]=2,[1]=true,[2]=false}},
{name="optionIndexIsValid",run=function() return optionIndexIsValid(0/0) end,expected={["n"]=2,[1]=true,[2]=false}},
{name="optionIndexIsValid",run=function() return optionIndexIsValid(math.huge) end,expected={["n"]=2,[1]=true,[2]=false}},
{name="catalogEncode",run=function() return catalogEncode(nil) end,expected={["n"]=2,[1]=true,[2]=""}},
{name="catalogEncode",run=function() return catalogEncode(false) end,expected={["n"]=2,[1]=true,[2]=""}},
{name="catalogEncode",run=function() return catalogEncode(42) end,expected={["n"]=2,[1]=true,[2]="42"}},
{name="catalogEncode",run=function() return catalogEncode("") end,expected={["n"]=2,[1]=true,[2]=""}},
{name="catalogEncode",run=function() return catalogEncode("a/b") end,expected={["n"]=2,[1]=true,[2]="a/b"}},
{name="catalogEncode",run=function() return catalogEncode("a//b") end,expected={["n"]=2,[1]=true,[2]="a//b"}},
{name="catalogEncode",run=function() return catalogEncode("a/../b") end,expected={["n"]=2,[1]=true,[2]="a/../b"}},
{name="catalogEncode",run=function() return catalogEncode("/a") end,expected={["n"]=2,[1]=true,[2]="/a"}},
{name="catalogEncode",run=function() return catalogEncode("a/") end,expected={["n"]=2,[1]=true,[2]="a/"}},
{name="catalogEncode",run=function() return catalogEncode("a\\b") end,expected={["n"]=2,[1]=true,[2]="a%5Cb"}},
{name="catalogEncode",run=function() return catalogEncode("a:b") end,expected={["n"]=2,[1]=true,[2]="a%3Ab"}},
{name="catalogEncode",run=function() return catalogEncode("CON") end,expected={["n"]=2,[1]=true,[2]="CON"}},
{name="catalogEncode",run=function() return catalogEncode("con.txt") end,expected={["n"]=2,[1]=true,[2]="con.txt"}},
{name="catalogEncode",run=function() return catalogEncode("COM1") end,expected={["n"]=2,[1]=true,[2]="COM1"}},
{name="catalogEncode",run=function() return catalogEncode("COM0") end,expected={["n"]=2,[1]=true,[2]="COM0"}},
{name="catalogEncode",run=function() return catalogEncode("LPT9") end,expected={["n"]=2,[1]=true,[2]="LPT9"}},
{name="catalogEncode",run=function() return catalogEncode("NUL") end,expected={["n"]=2,[1]=true,[2]="NUL"}},
{name="catalogEncode",run=function() return catalogEncode("a.") end,expected={["n"]=2,[1]=true,[2]="a."}},
{name="catalogEncode",run=function() return catalogEncode(" a ") end,expected={["n"]=2,[1]=true,[2]="%20a%20"}},
{name="catalogEncode",run=function() return catalogEncode("a\000b") end,expected={["n"]=2,[1]=true,[2]="a%00b"}},
{name="catalogEncode",run=function() return catalogEncode("é猫") end,expected={["n"]=2,[1]=true,[2]="%C3%A9%E7%8C%AB"}},
{name="catalogEncode",run=function() return catalogEncode(string.rep("a",65)) end,expected={["n"]=2,[1]=true,[2]="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}},
{name="catalogEncode",run=function() return catalogEncode("%00%FF%GG%2%") end,expected={["n"]=2,[1]=true,[2]="%2500%25FF%25GG%252%25"}},
{name="catalogEncode",run=function() return catalogEncode("00ff0A") end,expected={["n"]=2,[1]=true,[2]="00ff0A"}},
{name="catalogEncode",run=function() return catalogEncode("0") end,expected={["n"]=2,[1]=true,[2]="0"}},
{name="catalogEncode",run=function() return catalogEncode("GG") end,expected={["n"]=2,[1]=true,[2]="GG"}},
{name="catalogEncode",run=function() return catalogEncode("a\000\n猫") end,expected={["n"]=2,[1]=true,[2]="a%00%0A%E7%8C%AB"}},
{name="catalogDecode",run=function() return catalogDecode(nil) end,expected={["n"]=2,[1]=true,[2]=""}},
{name="catalogDecode",run=function() return catalogDecode(false) end,expected={["n"]=2,[1]=true,[2]=""}},
{name="catalogDecode",run=function() return catalogDecode(42) end,expected={["n"]=2,[1]=true,[2]="42"}},
{name="catalogDecode",run=function() return catalogDecode("") end,expected={["n"]=2,[1]=true,[2]=""}},
{name="catalogDecode",run=function() return catalogDecode("a/b") end,expected={["n"]=2,[1]=true,[2]="a/b"}},
{name="catalogDecode",run=function() return catalogDecode("a//b") end,expected={["n"]=2,[1]=true,[2]="a//b"}},
{name="catalogDecode",run=function() return catalogDecode("a/../b") end,expected={["n"]=2,[1]=true,[2]="a/../b"}},
{name="catalogDecode",run=function() return catalogDecode("/a") end,expected={["n"]=2,[1]=true,[2]="/a"}},
{name="catalogDecode",run=function() return catalogDecode("a/") end,expected={["n"]=2,[1]=true,[2]="a/"}},
{name="catalogDecode",run=function() return catalogDecode("a\\b") end,expected={["n"]=2,[1]=true,[2]="a\092b"}},
{name="catalogDecode",run=function() return catalogDecode("a:b") end,expected={["n"]=2,[1]=true,[2]="a:b"}},
{name="catalogDecode",run=function() return catalogDecode("CON") end,expected={["n"]=2,[1]=true,[2]="CON"}},
{name="catalogDecode",run=function() return catalogDecode("con.txt") end,expected={["n"]=2,[1]=true,[2]="con.txt"}},
{name="catalogDecode",run=function() return catalogDecode("COM1") end,expected={["n"]=2,[1]=true,[2]="COM1"}},
{name="catalogDecode",run=function() return catalogDecode("COM0") end,expected={["n"]=2,[1]=true,[2]="COM0"}},
{name="catalogDecode",run=function() return catalogDecode("LPT9") end,expected={["n"]=2,[1]=true,[2]="LPT9"}},
{name="catalogDecode",run=function() return catalogDecode("NUL") end,expected={["n"]=2,[1]=true,[2]="NUL"}},
{name="catalogDecode",run=function() return catalogDecode("a.") end,expected={["n"]=2,[1]=true,[2]="a."}},
{name="catalogDecode",run=function() return catalogDecode(" a ") end,expected={["n"]=2,[1]=true,[2]=" a "}},
{name="catalogDecode",run=function() return catalogDecode("a\000b") end,expected={["n"]=2,[1]=true,[2]="a\000b"}},
{name="catalogDecode",run=function() return catalogDecode("é猫") end,expected={["n"]=2,[1]=true,[2]="\195\169\231\140\171"}},
{name="catalogDecode",run=function() return catalogDecode(string.rep("a",65)) end,expected={["n"]=2,[1]=true,[2]="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}},
{name="catalogDecode",run=function() return catalogDecode("%00%FF%GG%2%") end,expected={["n"]=2,[1]=true,[2]="\000\255%GG%2%"}},
{name="catalogDecode",run=function() return catalogDecode("00ff0A") end,expected={["n"]=2,[1]=true,[2]="00ff0A"}},
{name="catalogDecode",run=function() return catalogDecode("0") end,expected={["n"]=2,[1]=true,[2]="0"}},
{name="catalogDecode",run=function() return catalogDecode("GG") end,expected={["n"]=2,[1]=true,[2]="GG"}},
{name="catalogDecode",run=function() return catalogDecode("a\000\n猫") end,expected={["n"]=2,[1]=true,[2]="a\000\010\231\140\171"}},
{name="encode",run=function() return encode(nil) end,expected={["n"]=2,[1]=true,[2]=""}},
{name="encode",run=function() return encode(false) end,expected={["n"]=2,[1]=true,[2]=""}},
{name="encode",run=function() return encode(42) end,expected={["n"]=2,[1]=true,[2]="3432"}},
{name="encode",run=function() return encode("") end,expected={["n"]=2,[1]=true,[2]=""}},
{name="encode",run=function() return encode("a/b") end,expected={["n"]=2,[1]=true,[2]="612F62"}},
{name="encode",run=function() return encode("a//b") end,expected={["n"]=2,[1]=true,[2]="612F2F62"}},
{name="encode",run=function() return encode("a/../b") end,expected={["n"]=2,[1]=true,[2]="612F2E2E2F62"}},
{name="encode",run=function() return encode("/a") end,expected={["n"]=2,[1]=true,[2]="2F61"}},
{name="encode",run=function() return encode("a/") end,expected={["n"]=2,[1]=true,[2]="612F"}},
{name="encode",run=function() return encode("a\\b") end,expected={["n"]=2,[1]=true,[2]="615C62"}},
{name="encode",run=function() return encode("a:b") end,expected={["n"]=2,[1]=true,[2]="613A62"}},
{name="encode",run=function() return encode("CON") end,expected={["n"]=2,[1]=true,[2]="434F4E"}},
{name="encode",run=function() return encode("con.txt") end,expected={["n"]=2,[1]=true,[2]="636F6E2E747874"}},
{name="encode",run=function() return encode("COM1") end,expected={["n"]=2,[1]=true,[2]="434F4D31"}},
{name="encode",run=function() return encode("COM0") end,expected={["n"]=2,[1]=true,[2]="434F4D30"}},
{name="encode",run=function() return encode("LPT9") end,expected={["n"]=2,[1]=true,[2]="4C505439"}},
{name="encode",run=function() return encode("NUL") end,expected={["n"]=2,[1]=true,[2]="4E554C"}},
{name="encode",run=function() return encode("a.") end,expected={["n"]=2,[1]=true,[2]="612E"}},
{name="encode",run=function() return encode(" a ") end,expected={["n"]=2,[1]=true,[2]="206120"}},
{name="encode",run=function() return encode("a\000b") end,expected={["n"]=2,[1]=true,[2]="610062"}},
{name="encode",run=function() return encode("é猫") end,expected={["n"]=2,[1]=true,[2]="C3A9E78CAB"}},
{name="encode",run=function() return encode(string.rep("a",65)) end,expected={["n"]=2,[1]=true,[2]="6161616161616161616161616161616161616161616161616161616161616161616161616161616161616161616161616161616161616161616161616161616161"}},
{name="encode",run=function() return encode("%00%FF%GG%2%") end,expected={["n"]=2,[1]=true,[2]="253030254646254747253225"}},
{name="encode",run=function() return encode("00ff0A") end,expected={["n"]=2,[1]=true,[2]="303066663041"}},
{name="encode",run=function() return encode("0") end,expected={["n"]=2,[1]=true,[2]="30"}},
{name="encode",run=function() return encode("GG") end,expected={["n"]=2,[1]=true,[2]="4747"}},
{name="encode",run=function() return encode("a\000\n猫") end,expected={["n"]=2,[1]=true,[2]="61000AE78CAB"}},
{name="decode",run=function() return decode(nil) end,expected={["n"]=2,[1]=true}},
{name="decode",run=function() return decode(false) end,expected={["n"]=2,[1]=true}},
{name="decode",run=function() return decode(42) end,expected={["n"]=2,[1]=true}},
{name="decode",run=function() return decode("") end,expected={["n"]=2,[1]=true,[2]=""}},
{name="decode",run=function() return decode("a/b") end,expected={["n"]=2,[1]=true}},
{name="decode",run=function() return decode("a//b") end,expected={["n"]=2,[1]=true}},
{name="decode",run=function() return decode("a/../b") end,expected={["n"]=2,[1]=true}},
{name="decode",run=function() return decode("/a") end,expected={["n"]=2,[1]=true}},
{name="decode",run=function() return decode("a/") end,expected={["n"]=2,[1]=true}},
{name="decode",run=function() return decode("a\\b") end,expected={["n"]=2,[1]=true}},
{name="decode",run=function() return decode("a:b") end,expected={["n"]=2,[1]=true}},
{name="decode",run=function() return decode("CON") end,expected={["n"]=2,[1]=true}},
{name="decode",run=function() return decode("con.txt") end,expected={["n"]=2,[1]=true}},
{name="decode",run=function() return decode("COM1") end,expected={["n"]=2,[1]=true}},
{name="decode",run=function() return decode("COM0") end,expected={["n"]=2,[1]=true}},
{name="decode",run=function() return decode("LPT9") end,expected={["n"]=2,[1]=true}},
{name="decode",run=function() return decode("NUL") end,expected={["n"]=2,[1]=true}},
{name="decode",run=function() return decode("a.") end,expected={["n"]=2,[1]=true}},
{name="decode",run=function() return decode(" a ") end,expected={["n"]=2,[1]=true}},
{name="decode",run=function() return decode("a\000b") end,expected={["n"]=2,[1]=true}},
{name="decode",run=function() return decode("é猫") end,expected={["n"]=2,[1]=true}},
{name="decode",run=function() return decode(string.rep("a",65)) end,expected={["n"]=2,[1]=true}},
{name="decode",run=function() return decode("%00%FF%GG%2%") end,expected={["n"]=2,[1]=true}},
{name="decode",run=function() return decode("00ff0A") end,expected={["n"]=2,[1]=true,[2]="\000\255\010"}},
{name="decode",run=function() return decode("0") end,expected={["n"]=2,[1]=true}},
{name="decode",run=function() return decode("GG") end,expected={["n"]=2,[1]=true}},
{name="decode",run=function() return decode("a\000\n猫") end,expected={["n"]=2,[1]=true}},
{name="hexEncode",run=function() return hexEncode(nil) end,expected={["n"]=1,[1]="error"}},
{name="hexEncode",run=function() return hexEncode(false) end,expected={["n"]=1,[1]="error"}},
{name="hexEncode",run=function() return hexEncode(42) end,expected={["n"]=1,[1]="error"}},
{name="hexEncode",run=function() return hexEncode("") end,expected={["n"]=2,[1]=true,[2]=""}},
{name="hexEncode",run=function() return hexEncode("a/b") end,expected={["n"]=2,[1]=true,[2]="612F62"}},
{name="hexEncode",run=function() return hexEncode("a//b") end,expected={["n"]=2,[1]=true,[2]="612F2F62"}},
{name="hexEncode",run=function() return hexEncode("a/../b") end,expected={["n"]=2,[1]=true,[2]="612F2E2E2F62"}},
{name="hexEncode",run=function() return hexEncode("/a") end,expected={["n"]=2,[1]=true,[2]="2F61"}},
{name="hexEncode",run=function() return hexEncode("a/") end,expected={["n"]=2,[1]=true,[2]="612F"}},
{name="hexEncode",run=function() return hexEncode("a\\b") end,expected={["n"]=2,[1]=true,[2]="615C62"}},
{name="hexEncode",run=function() return hexEncode("a:b") end,expected={["n"]=2,[1]=true,[2]="613A62"}},
{name="hexEncode",run=function() return hexEncode("CON") end,expected={["n"]=2,[1]=true,[2]="434F4E"}},
{name="hexEncode",run=function() return hexEncode("con.txt") end,expected={["n"]=2,[1]=true,[2]="636F6E2E747874"}},
{name="hexEncode",run=function() return hexEncode("COM1") end,expected={["n"]=2,[1]=true,[2]="434F4D31"}},
{name="hexEncode",run=function() return hexEncode("COM0") end,expected={["n"]=2,[1]=true,[2]="434F4D30"}},
{name="hexEncode",run=function() return hexEncode("LPT9") end,expected={["n"]=2,[1]=true,[2]="4C505439"}},
{name="hexEncode",run=function() return hexEncode("NUL") end,expected={["n"]=2,[1]=true,[2]="4E554C"}},
{name="hexEncode",run=function() return hexEncode("a.") end,expected={["n"]=2,[1]=true,[2]="612E"}},
{name="hexEncode",run=function() return hexEncode(" a ") end,expected={["n"]=2,[1]=true,[2]="206120"}},
{name="hexEncode",run=function() return hexEncode("a\000b") end,expected={["n"]=2,[1]=true,[2]="610062"}},
{name="hexEncode",run=function() return hexEncode("é猫") end,expected={["n"]=2,[1]=true,[2]="C3A9E78CAB"}},
{name="hexEncode",run=function() return hexEncode(string.rep("a",65)) end,expected={["n"]=2,[1]=true,[2]="6161616161616161616161616161616161616161616161616161616161616161616161616161616161616161616161616161616161616161616161616161616161"}},
{name="hexEncode",run=function() return hexEncode("%00%FF%GG%2%") end,expected={["n"]=2,[1]=true,[2]="253030254646254747253225"}},
{name="hexEncode",run=function() return hexEncode("00ff0A") end,expected={["n"]=2,[1]=true,[2]="303066663041"}},
{name="hexEncode",run=function() return hexEncode("0") end,expected={["n"]=2,[1]=true,[2]="30"}},
{name="hexEncode",run=function() return hexEncode("GG") end,expected={["n"]=2,[1]=true,[2]="4747"}},
{name="hexEncode",run=function() return hexEncode("a\000\n猫") end,expected={["n"]=2,[1]=true,[2]="61000AE78CAB"}},
{name="hexDecode",run=function() return hexDecode(nil) end,expected={["n"]=1,[1]="error"}},
{name="hexDecode",run=function() return hexDecode(false) end,expected={["n"]=1,[1]="error"}},
{name="hexDecode",run=function() return hexDecode(42) end,expected={["n"]=1,[1]="error"}},
{name="hexDecode",run=function() return hexDecode("") end,expected={["n"]=2,[1]=true}},
{name="hexDecode",run=function() return hexDecode("a/b") end,expected={["n"]=2,[1]=true}},
{name="hexDecode",run=function() return hexDecode("a//b") end,expected={["n"]=2,[1]=true}},
{name="hexDecode",run=function() return hexDecode("a/../b") end,expected={["n"]=2,[1]=true}},
{name="hexDecode",run=function() return hexDecode("/a") end,expected={["n"]=2,[1]=true}},
{name="hexDecode",run=function() return hexDecode("a/") end,expected={["n"]=2,[1]=true}},
{name="hexDecode",run=function() return hexDecode("a\\b") end,expected={["n"]=2,[1]=true}},
{name="hexDecode",run=function() return hexDecode("a:b") end,expected={["n"]=2,[1]=true}},
{name="hexDecode",run=function() return hexDecode("CON") end,expected={["n"]=2,[1]=true}},
{name="hexDecode",run=function() return hexDecode("con.txt") end,expected={["n"]=2,[1]=true}},
{name="hexDecode",run=function() return hexDecode("COM1") end,expected={["n"]=2,[1]=true}},
{name="hexDecode",run=function() return hexDecode("COM0") end,expected={["n"]=2,[1]=true}},
{name="hexDecode",run=function() return hexDecode("LPT9") end,expected={["n"]=2,[1]=true}},
{name="hexDecode",run=function() return hexDecode("NUL") end,expected={["n"]=2,[1]=true}},
{name="hexDecode",run=function() return hexDecode("a.") end,expected={["n"]=2,[1]=true}},
{name="hexDecode",run=function() return hexDecode(" a ") end,expected={["n"]=2,[1]=true}},
{name="hexDecode",run=function() return hexDecode("a\000b") end,expected={["n"]=2,[1]=true}},
{name="hexDecode",run=function() return hexDecode("é猫") end,expected={["n"]=2,[1]=true}},
{name="hexDecode",run=function() return hexDecode(string.rep("a",65)) end,expected={["n"]=2,[1]=true}},
{name="hexDecode",run=function() return hexDecode("%00%FF%GG%2%") end,expected={["n"]=2,[1]=true}},
{name="hexDecode",run=function() return hexDecode("00ff0A") end,expected={["n"]=2,[1]=true,[2]="\000\255\010"}},
{name="hexDecode",run=function() return hexDecode("0") end,expected={["n"]=2,[1]=true}},
{name="hexDecode",run=function() return hexDecode("GG") end,expected={["n"]=2,[1]=true}},
{name="hexDecode",run=function() return hexDecode("a\000\n猫") end,expected={["n"]=2,[1]=true}},
{name="decodeImportField",run=function() return decodeImportField(nil) end,expected={["n"]=2,[1]=true,[2]=""}},
{name="decodeImportField",run=function() return decodeImportField(false) end,expected={["n"]=2,[1]=true,[2]=""}},
{name="decodeImportField",run=function() return decodeImportField(42) end,expected={["n"]=2,[1]=true,[2]="42"}},
{name="decodeImportField",run=function() return decodeImportField("") end,expected={["n"]=2,[1]=true,[2]=""}},
{name="decodeImportField",run=function() return decodeImportField("a/b") end,expected={["n"]=2,[1]=true,[2]="a/b"}},
{name="decodeImportField",run=function() return decodeImportField("a//b") end,expected={["n"]=2,[1]=true,[2]="a//b"}},
{name="decodeImportField",run=function() return decodeImportField("a/../b") end,expected={["n"]=2,[1]=true,[2]="a/../b"}},
{name="decodeImportField",run=function() return decodeImportField("/a") end,expected={["n"]=2,[1]=true,[2]="/a"}},
{name="decodeImportField",run=function() return decodeImportField("a/") end,expected={["n"]=2,[1]=true,[2]="a/"}},
{name="decodeImportField",run=function() return decodeImportField("a\\b") end,expected={["n"]=2,[1]=true,[2]="a\092b"}},
{name="decodeImportField",run=function() return decodeImportField("a:b") end,expected={["n"]=2,[1]=true,[2]="a:b"}},
{name="decodeImportField",run=function() return decodeImportField("CON") end,expected={["n"]=2,[1]=true,[2]="CON"}},
{name="decodeImportField",run=function() return decodeImportField("con.txt") end,expected={["n"]=2,[1]=true,[2]="con.txt"}},
{name="decodeImportField",run=function() return decodeImportField("COM1") end,expected={["n"]=2,[1]=true,[2]="COM1"}},
{name="decodeImportField",run=function() return decodeImportField("COM0") end,expected={["n"]=2,[1]=true,[2]="COM0"}},
{name="decodeImportField",run=function() return decodeImportField("LPT9") end,expected={["n"]=2,[1]=true,[2]="LPT9"}},
{name="decodeImportField",run=function() return decodeImportField("NUL") end,expected={["n"]=2,[1]=true,[2]="NUL"}},
{name="decodeImportField",run=function() return decodeImportField("a.") end,expected={["n"]=2,[1]=true,[2]="a."}},
{name="decodeImportField",run=function() return decodeImportField(" a ") end,expected={["n"]=2,[1]=true,[2]=" a "}},
{name="decodeImportField",run=function() return decodeImportField("a\000b") end,expected={["n"]=2,[1]=true,[2]="a\000b"}},
{name="decodeImportField",run=function() return decodeImportField("é猫") end,expected={["n"]=2,[1]=true,[2]="\195\169\231\140\171"}},
{name="decodeImportField",run=function() return decodeImportField(string.rep("a",65)) end,expected={["n"]=2,[1]=true,[2]="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}},
{name="decodeImportField",run=function() return decodeImportField("%00%FF%GG%2%") end,expected={["n"]=2,[1]=true,[2]="\000\255%GG%2%"}},
{name="decodeImportField",run=function() return decodeImportField("00ff0A") end,expected={["n"]=2,[1]=true,[2]="00ff0A"}},
{name="decodeImportField",run=function() return decodeImportField("0") end,expected={["n"]=2,[1]=true,[2]="0"}},
{name="decodeImportField",run=function() return decodeImportField("GG") end,expected={["n"]=2,[1]=true,[2]="GG"}},
{name="decodeImportField",run=function() return decodeImportField("a\000\n猫") end,expected={["n"]=2,[1]=true,[2]="a\000\010\231\140\171"}},
{name="decodeNativeField",run=function() return decodeNativeField(nil) end,expected={["n"]=2,[1]=true,[2]=""}},
{name="decodeNativeField",run=function() return decodeNativeField(false) end,expected={["n"]=2,[1]=true,[2]=""}},
{name="decodeNativeField",run=function() return decodeNativeField(42) end,expected={["n"]=2,[1]=true,[2]="42"}},
{name="decodeNativeField",run=function() return decodeNativeField("") end,expected={["n"]=2,[1]=true,[2]=""}},
{name="decodeNativeField",run=function() return decodeNativeField("a/b") end,expected={["n"]=2,[1]=true,[2]="a/b"}},
{name="decodeNativeField",run=function() return decodeNativeField("a//b") end,expected={["n"]=2,[1]=true,[2]="a//b"}},
{name="decodeNativeField",run=function() return decodeNativeField("a/../b") end,expected={["n"]=2,[1]=true,[2]="a/../b"}},
{name="decodeNativeField",run=function() return decodeNativeField("/a") end,expected={["n"]=2,[1]=true,[2]="/a"}},
{name="decodeNativeField",run=function() return decodeNativeField("a/") end,expected={["n"]=2,[1]=true,[2]="a/"}},
{name="decodeNativeField",run=function() return decodeNativeField("a\\b") end,expected={["n"]=2,[1]=true,[2]="a\092b"}},
{name="decodeNativeField",run=function() return decodeNativeField("a:b") end,expected={["n"]=2,[1]=true,[2]="a:b"}},
{name="decodeNativeField",run=function() return decodeNativeField("CON") end,expected={["n"]=2,[1]=true,[2]="CON"}},
{name="decodeNativeField",run=function() return decodeNativeField("con.txt") end,expected={["n"]=2,[1]=true,[2]="con.txt"}},
{name="decodeNativeField",run=function() return decodeNativeField("COM1") end,expected={["n"]=2,[1]=true,[2]="COM1"}},
{name="decodeNativeField",run=function() return decodeNativeField("COM0") end,expected={["n"]=2,[1]=true,[2]="COM0"}},
{name="decodeNativeField",run=function() return decodeNativeField("LPT9") end,expected={["n"]=2,[1]=true,[2]="LPT9"}},
{name="decodeNativeField",run=function() return decodeNativeField("NUL") end,expected={["n"]=2,[1]=true,[2]="NUL"}},
{name="decodeNativeField",run=function() return decodeNativeField("a.") end,expected={["n"]=2,[1]=true,[2]="a."}},
{name="decodeNativeField",run=function() return decodeNativeField(" a ") end,expected={["n"]=2,[1]=true,[2]=" a "}},
{name="decodeNativeField",run=function() return decodeNativeField("a\000b") end,expected={["n"]=2,[1]=true,[2]="a\000b"}},
{name="decodeNativeField",run=function() return decodeNativeField("é猫") end,expected={["n"]=2,[1]=true,[2]="\195\169\231\140\171"}},
{name="decodeNativeField",run=function() return decodeNativeField(string.rep("a",65)) end,expected={["n"]=2,[1]=true,[2]="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}},
{name="decodeNativeField",run=function() return decodeNativeField("%00%FF%GG%2%") end,expected={["n"]=2,[1]=true,[2]="\000\255%GG%2%"}},
{name="decodeNativeField",run=function() return decodeNativeField("00ff0A") end,expected={["n"]=2,[1]=true,[2]="00ff0A"}},
{name="decodeNativeField",run=function() return decodeNativeField("0") end,expected={["n"]=2,[1]=true,[2]="0"}},
{name="decodeNativeField",run=function() return decodeNativeField("GG") end,expected={["n"]=2,[1]=true,[2]="GG"}},
{name="decodeNativeField",run=function() return decodeNativeField("a\000\n猫") end,expected={["n"]=2,[1]=true,[2]="a\000\010\231\140\171"}},
{name="historyPath",run=function() return historyPath(nil) end,expected={["n"]=2,[1]=true,[2]="Data/Recovery/Appearance History/Appearance nil.preset"}},
{name="historyPath",run=function() return historyPath(0) end,expected={["n"]=2,[1]=true,[2]="Data/Recovery/Appearance History/Appearance 0.preset"}},
{name="historyPath",run=function() return historyPath(1) end,expected={["n"]=2,[1]=true,[2]="Data/Recovery/Appearance History/Appearance 1.preset"}},
{name="historyPath",run=function() return historyPath(-1) end,expected={["n"]=2,[1]=true,[2]="Data/Recovery/Appearance History/Appearance -1.preset"}},
{name="historyPath",run=function() return historyPath("x") end,expected={["n"]=2,[1]=true,[2]="Data/Recovery/Appearance History/Appearance x.preset"}},
{name="supportedFile",run=function() return supportedFile(nil) end,expected={["n"]=1,[1]="error"}},
{name="supportedFile",run=function() return supportedFile("x.PRESET") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="supportedFile",run=function() return supportedFile("x.cpmfolder") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="supportedFile",run=function() return supportedFile("x.cpmbackup") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="supportedFile",run=function() return supportedFile("x.txt") end,expected={["n"]=2,[1]=true,[2]=false}},
{name="supportedFile",run=function() return supportedFile(".preset") end,expected={["n"]=2,[1]=true,[2]=true}},
{name="cleanField",run=function() return cleanField(nil) end,expected={["n"]=3,[1]=true,[2]="",[3]=0}},
{name="cleanField",run=function() return cleanField(false) end,expected={["n"]=3,[1]=true,[2]="",[3]=0}},
{name="cleanField",run=function() return cleanField("a\nb\000c") end,expected={["n"]=3,[1]=true,[2]="a b c",[3]=2}},
{name="cleanField",run=function() return cleanField("é猫") end,expected={["n"]=3,[1]=true,[2]="\195\169\231\140\171",[3]=0}},
}
for i,f in ipairs(fixtures) do assert(literal(capture(f.run))==literal(f.expected),f.name.." fixture "..i) end
print("Domain fixtures passed: 833")

local bytes = {}
for byte = 0, 255 do bytes[#bytes + 1] = string.char(byte) end
local binary = table.concat(bytes)
assert(codecs.backupDecode(codecs.backupEncode(binary)) == binary)
assert(codecs.hexDecode(codecs.hexEncode(binary)) == binary)
assert(codecs.catalogDecode(codecs.catalogEncode(binary)) == binary)
assert(codecs.backupDecode("") == "" and codecs.hexDecode("") == nil)
local reserved = {}
for index = 1, 9999 do
  local suffix = index == 1 and "" or (" %d"):format(index)
  reserved[("x" .. suffix .. ".preset"):lower()] = true
end
assert(names.uniqueStorageName("x", reserved) == nil)
local copies = {}
for index = 1, 999 do
  local suffix = index == 1 and " Copy" or (" Copy %d"):format(index)
  copies["X" .. suffix] = true
end
assert(names.uniquePresetCopyName("x", copies) == nil)
assert(names.uniqueFolderCopyName("x", copies) == nil)
assert(identities.stableChoiceIdentity("options:same") == identities.stableChoiceIdentity("options:same"))
assert(identities.occurrenceKeyParts("same\0312") == "same")
local runtime = require("modules/runtime")
runtime.state = state
require("modules/constants")
require("modules/filesystem")
require("modules/catalog")
require("modules/presets")
require("modules/folders")
require("modules/options")
require("modules/view_cache")
runtime.state = state
parentFolder = runtime.parentFolder
folderDepth = runtime.folderDepth
folderAncestorsExpanded = runtime.folderAncestorsExpanded
folderPath = runtime.folderPath
presetPath = runtime.presetPath
baseName = runtime.baseName
joinFolder = runtime.joinFolder
isInFolderTree = runtime.isInFolderTree
addFolderAncestors = runtime.addFolderAncestors
validRelativePath = runtime.validRelativePath
remapFolderTreePath = runtime.remapFolderTreePath
isFolderBundleFilename = runtime.isFolderBundleFilename
sanitizeName = runtime.sanitizeName
sanitizeMetadata = runtime.sanitizeMetadata
validatedPresetName = runtime.validatedPresetName
validatedFolderName = runtime.validatedFolderName
findPresetCollision = runtime.findPresetCollision
uniqueStorageName = runtime.uniqueStorageName
findExistingFolderName = runtime.findExistingFolderName
folderNameExists = runtime.folderNameExists
uniquePresetCopyName = runtime.uniquePresetCopyName
uniqueFolderCopyName = runtime.uniqueFolderCopyName
isRuntimePointerText = runtime.isRuntimePointerText
stableChoiceIdentity = runtime.stableChoiceIdentity
occurrenceKeyParts = runtime.occurrenceKeyParts
optionIndexValidationError = runtime.optionIndexValidationError
optionIndexIsValid = runtime.optionIndexIsValid
catalogEncode = runtime.catalogEncode
catalogDecode = runtime.catalogDecode
for i, fixture in ipairs(fixtures) do
  assert(literal(capture(fixture.run)) == literal(fixture.expected), "compatibility " .. fixture.name .. " fixture " .. i)
end
print("Compatibility fixture pass completed; binary round trips and naming exhaustion passed.")

local listingCalls = 0
runtime.storageFilenamesInUse = function()
  listingCalls = listingCalls + 1
  return {["x.preset"] = true}
end
assert(runtime.uniqueStorageName("x") == "x 2" and listingCalls == 1)
assert(runtime.uniqueStorageName("x", {}) == "x" and listingCalls == 1)
runtime.storageFilenamesInUse = function() return nil end
assert(runtime.uniqueStorageName("x") == nil)
print("Storage-name adapter fallback checks passed.")
