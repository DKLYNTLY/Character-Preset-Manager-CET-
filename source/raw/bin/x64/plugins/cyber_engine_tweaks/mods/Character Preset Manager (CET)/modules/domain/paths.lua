local LIBRARY_BACKUP_EXTENSION = ".cpmbackup"
local FOLDER_BUNDLE_EXTENSION = ".cpmfolder"
local PRESET_EXTENSION = ".preset"
local MAX_FILENAME_BYTES = 255
local MAX_TRASH_FILENAME_BYTES = 71

local function parentFolder(name)
  return name:match("^(.*)/[^/]+$") or ""
end

local function folderDepth(name)
  local depth = 0
  for _ in tostring(name or ""):gmatch("/") do depth = depth + 1 end
  return depth
end

local function folderAncestorsExpanded(name, expandedFolders)
  local current = parentFolder(tostring(name or ""))
  while current ~= "" do
    if not (expandedFolders or {})[current] then return false end
    current = parentFolder(current)
  end
  return true
end

local function folderPath(name, presetDirectory)
  return name == "" and presetDirectory or (presetDirectory .. "/" .. name)
end

local function presetPath(name, presets, presetDirectory)
  local preset = presets[name]
  local storage = preset and preset.storage or name
  return presetDirectory .. "/" .. storage .. PRESET_EXTENSION
end

local function baseName(name)
  return name:match("([^/]+)$") or name
end

local function joinFolder(folder, name)
  if not folder or folder == "" then return name end
  return folder .. "/" .. name
end

local function isInFolderTree(path, folder)
  return path == folder or path:sub(1, #folder + 1) == folder .. "/"
end

local function addFolderAncestors(folders, folder)
  local current = folder
  while current and current ~= "" do
    folders[current] = true
    current = parentFolder(current)
  end
end

local function validRelativePath(value)
  if type(value) ~= "string" or value == ""
      or value:sub(1, 1) == "/" or value:sub(-1) == "/"
      or value:find("//", 1, true) or value:find("\\", 1, true) then
    return false
  end
  for part in value:gmatch("[^/]+") do
    if part == "." or part == ".." or part == "" then return false end
  end
  return true
end

local function remapFolderTreePath(path, source, destination)
  if path == source then return destination end
  if path:sub(1, #source + 1) == source .. "/" then
    return destination .. path:sub(#source + 1)
  end
  return path
end

local function validBundlePath(value, validatePresetName)
  if not validRelativePath(value) then return false end
  for part in value:gmatch("[^/]+") do
    local validated = validatePresetName(part)
    if validated ~= part then return false end
  end
  return true
end

local function validNativeRelativePath(value, maximumDepth)
  if not validRelativePath(value) then return false end
  local depth = 0
  for part in value:gmatch("[^/]+") do
    depth = depth + 1
    if depth > maximumDepth or #part > MAX_FILENAME_BYTES or part:find("[<>:\"\\|%?%*%c]")
        or part:match("[%. ]$") then return false end
  end
  return depth > 0
end

local function isFolderBundleFilename(filename)
  return type(filename) == "string" and filename ~= ""
    and #filename <= MAX_FILENAME_BYTES and not filename:find("/", 1, true)
    and not filename:find("\\", 1, true) and not filename:find("%c")
    and filename:lower():sub(-#FOLDER_BUNDLE_EXTENSION) == FOLDER_BUNDLE_EXTENSION
end

local function validTrashFilename(filename)
  return type(filename) == "string" and #filename > #PRESET_EXTENSION and #filename <= MAX_TRASH_FILENAME_BYTES
    and filename:find("/", 1, true) == nil and filename:find("\\", 1, true) == nil
    and filename:lower():sub(-#PRESET_EXTENSION) == PRESET_EXTENSION
end

local function historyPath(index, historyFilePrefix)
  return historyFilePrefix .. tostring(index) .. PRESET_EXTENSION
end

local function supportedFile(path)
  local lowered = path:lower()
  return lowered:sub(-#PRESET_EXTENSION) == PRESET_EXTENSION
    or lowered:sub(-#FOLDER_BUNDLE_EXTENSION) == FOLDER_BUNDLE_EXTENSION
    or lowered:sub(-#LIBRARY_BACKUP_EXTENSION) == LIBRARY_BACKUP_EXTENSION
end

return {
  supportedFile = supportedFile,
  historyPath = historyPath,
  parentFolder = parentFolder,
  folderDepth = folderDepth,
  folderAncestorsExpanded = folderAncestorsExpanded,
  folderPath = folderPath,
  presetPath = presetPath,
  baseName = baseName,
  joinFolder = joinFolder,
  isInFolderTree = isInFolderTree,
  addFolderAncestors = addFolderAncestors,
  validRelativePath = validRelativePath,
  remapFolderTreePath = remapFolderTreePath,
  validBundlePath = validBundlePath,
  validNativeRelativePath = validNativeRelativePath,
  isFolderBundleFilename = isFolderBundleFilename,
  validTrashFilename = validTrashFilename,
  FOLDER_BUNDLE_EXTENSION = FOLDER_BUNDLE_EXTENSION,
}
