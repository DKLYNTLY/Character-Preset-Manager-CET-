local paths = require("modules/domain/paths")
local MAX_NAME_BYTES = 64
local MAX_STORAGE_CANDIDATES = 9999
local MAX_COPY_CANDIDATES = 999
local PRESET_EXTENSION = ".preset"
local FIRST_COPY_SUFFIX = " Copy"
local NUMBERED_COPY_SUFFIX = " Copy %d"
local NUMBERED_STORAGE_SUFFIX = " %d"

local function sanitizeName(value)
  value = tostring(value or "")
  value = value:gsub("^%s+", ""):gsub("%s+$", "")
  value = value:gsub("[<>:\"/\\|%?%*%c]", "_")
  return value:sub(1, MAX_NAME_BYTES)
end

local function sanitizeMetadata(value, maximum)
  value = tostring(value or ""):gsub("[%c]", " ")
  value = value:gsub("^%s+", ""):gsub("%s+$", "")
  return value:sub(1, maximum)
end

local function validatedPresetName(value)
  local raw = tostring(value or "")
  local name = sanitizeName(raw)
  if name == "" then return nil, "Enter a name." end
  if name:match("[%. ]$") then
    return nil, "Preset names cannot end with a period or space."
  end

  local deviceName = (name:match("^([^%.]+)") or name):upper()
  if deviceName == "CON" or deviceName == "PRN"
      or deviceName == "AUX" or deviceName == "NUL"
      or deviceName:match("^COM[1-9]$")
      or deviceName:match("^LPT[1-9]$") then
    return nil, ("\"%s\" is a reserved Windows name. Enter another name.")
      :format(name)
  end
  return name
end

local function validatedFolderName(value)
  local name, nameError = validatedPresetName(value)
  if not name then
    nameError = nameError:gsub("Preset names", "Folder names")
      :gsub("preset name", "folder name")
      :gsub("filename", "folder name")
    return nil, nameError
  end
  return name
end

local function findPresetCollision(name, excludeName, presets)
  local lowered = name:lower()
  for existing in pairs(presets) do
    if existing:lower() == lowered and existing ~= excludeName then
      return existing
    end
  end
  return nil
end

local function uniqueStorageName(leafName, used)
  if not used then return nil end
  for index = 1, MAX_STORAGE_CANDIDATES do
    local suffix = index == 1 and "" or (NUMBERED_STORAGE_SUFFIX):format(index)
    local candidate = leafName:sub(1, MAX_NAME_BYTES - #suffix) .. suffix
    local filename = (candidate .. PRESET_EXTENSION):lower()
    if not used[filename] then
      used[filename] = true
      return candidate
    end
  end
  return nil
end

local function findExistingFolderName(name, excludeName, folders)
  local lowered = name:lower()
  for existing in pairs(folders) do
    if existing:lower() == lowered and existing ~= excludeName then return existing end
  end
  return nil
end

local function folderNameExists(name, folders)
  return findExistingFolderName(name, nil, folders) ~= nil
end

local function uniquePresetCopyName(sourceName, presets)
  local folder = paths.parentFolder(sourceName)
  local leaf = paths.baseName(sourceName)
  for index = 1, MAX_COPY_CANDIDATES do
    local suffix = index == 1 and FIRST_COPY_SUFFIX or (NUMBERED_COPY_SUFFIX):format(index)
    local candidate = paths.joinFolder(folder, leaf .. suffix)
    if not findPresetCollision(candidate, nil, presets) then return candidate end
  end
  return nil
end

local function uniqueFolderCopyName(sourceName, folders)
  local folder = paths.parentFolder(sourceName)
  local leaf = paths.baseName(sourceName)
  for index = 1, MAX_COPY_CANDIDATES do
    local suffix = index == 1 and FIRST_COPY_SUFFIX or (NUMBERED_COPY_SUFFIX):format(index)
    local candidate = paths.joinFolder(folder, leaf .. suffix)
    if not folderNameExists(candidate, folders) then return candidate end
  end
  return nil
end

return {
  sanitizeName = sanitizeName,
  sanitizeMetadata = sanitizeMetadata,
  validatedPresetName = validatedPresetName,
  validatedFolderName = validatedFolderName,
  findPresetCollision = findPresetCollision,
  uniqueStorageName = uniqueStorageName,
  findExistingFolderName = findExistingFolderName,
  folderNameExists = folderNameExists,
  uniquePresetCopyName = uniquePresetCopyName,
  uniqueFolderCopyName = uniqueFolderCopyName,
}
