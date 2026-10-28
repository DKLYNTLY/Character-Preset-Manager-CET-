local paths = require("modules/domain/paths")
local names = require("modules/domain/names")
local parentFolder = paths.parentFolder
local baseName = paths.baseName
local MAX_NOTES_BYTES = 512
local MAX_TAGS_BYTES = 128
local LEGACY_PRESET_FORMAT = 4

local function presetEntryCount(preset)
  if not preset then return 0 end
  if preset.entries then return #preset.entries end
  return tonumber(preset.entryCount) or 0
end

local function dehydratePreset(preset)
  if not preset or not preset.entries then return false end
  preset.entryCount = #preset.entries
  preset.entryCountKnown = true
  preset.entries = nil
  preset.lazy = true
  return true
end

local function mergeHydrated(preset, loaded)
  local storage = preset.storage
  for key in pairs(preset) do preset[key] = nil end
  for key, value in pairs(loaded) do preset[key] = value end
  preset.storage = storage
end

local function mergeMetadata(preset, loaded)
  for _, key in ipairs({
    "format", "source", "created", "modified", "notes", "tags", "favorite",
    "managedByCpm", "presetName", "libraryFolder", "entryCount",
    "entryCountKnown", "metadataLoaded",
  }) do
    preset[key] = loaded[key]
  end
  preset.lazy = true
end

local function headerChange(preset, logicalName, currentFormat)
  if not preset.managedByCpm or (tonumber(preset.format) or LEGACY_PRESET_FORMAT) < currentFormat then return nil end
  local desiredFolder = parentFolder(logicalName)
  local desiredName = baseName(logicalName)
  if preset.libraryFolder == desiredFolder and preset.presetName == desiredName then return nil end
  return {preset = preset, presetName = preset.presetName, libraryFolder = preset.libraryFolder, storage = preset.storage}
end

local function applyHeader(preset, logicalName)
  preset.presetName = baseName(logicalName)
  preset.libraryFolder = parentFolder(logicalName)
end

local function restoreHeader(change)
  change.preset.presetName = change.presetName
  change.preset.libraryFolder = change.libraryFolder
end

local function beginMetadata(preset, notes, tags)
  local previous = {notes=preset.notes, tags=preset.tags, modified=preset.modified, format=preset.format,
    source=preset.source, managedByCpm=preset.managedByCpm, presetName=preset.presetName, libraryFolder=preset.libraryFolder}
  preset.notes = names.sanitizeMetadata(notes, MAX_NOTES_BYTES)
  preset.tags = names.sanitizeMetadata(tags, MAX_TAGS_BYTES)
  return previous
end

local function finishMetadata(preset, logicalName, modified, modName, currentFormat)
  preset.modified = modified
  preset.created = preset.created or preset.modified
  preset.source = modName
  preset.format = math.max(currentFormat, tonumber(preset.format) or LEGACY_PRESET_FORMAT)
  preset.managedByCpm = true
  applyHeader(preset, logicalName)
end

local function restoreMetadata(preset, previous)
  preset.notes, preset.tags = previous.notes, previous.tags
  preset.modified, preset.format = previous.modified, previous.format
  preset.source = previous.source
  preset.managedByCpm, preset.presetName, preset.libraryFolder = previous.managedByCpm, previous.presetName, previous.libraryFolder
end

local function beginFavorite(preset)
  local previous = {favorite=preset.favorite == true, modified=preset.modified, managedByCpm=preset.managedByCpm,
    presetName=preset.presetName, libraryFolder=preset.libraryFolder}
  preset.favorite = not previous.favorite
  return previous
end

local function finishFavorite(preset, name, modified)
  preset.modified = modified
  preset.managedByCpm = true
  applyHeader(preset, name)
end

local function restoreFavorite(preset, previous)
  preset.favorite = previous.favorite
  preset.modified = previous.modified
  preset.managedByCpm, preset.presetName, preset.libraryFolder = previous.managedByCpm, previous.presetName, previous.libraryFolder
end

local function renameTarget(oldName, newLeafName)
  return paths.joinFolder(parentFolder(oldName), newLeafName)
end

local function renameStorageTarget(oldStorage, newLeafName)
  return paths.joinFolder(parentFolder(oldStorage), newLeafName)
end

local function moveTarget(oldName, folder)
  return paths.joinFolder(folder, baseName(oldName))
end

local function newSavedPreset(previousPreset, entries, name, storage, created, modified, currentFormat, modName)
  return {
    format = currentFormat,
    source = modName,
    created = created,
    modified = modified,
    notes = previousPreset and previousPreset.notes or "",
    tags = previousPreset and previousPreset.tags or "",
    favorite = previousPreset and previousPreset.favorite == true,
    managedByCpm = true,
    presetName = baseName(name),
    libraryFolder = parentFolder(name),
    entries = entries,
    entryCount = #entries,
    storage = storage,
  }
end

return {newSavedPreset=newSavedPreset, presetEntryCount=presetEntryCount, dehydratePreset=dehydratePreset, mergeHydrated=mergeHydrated,
  mergeMetadata=mergeMetadata, headerChange=headerChange, applyHeader=applyHeader, restoreHeader=restoreHeader,
  beginMetadata=beginMetadata, finishMetadata=finishMetadata, restoreMetadata=restoreMetadata, beginFavorite=beginFavorite, finishFavorite=finishFavorite, restoreFavorite=restoreFavorite,
  renameTarget=renameTarget, renameStorageTarget=renameStorageTarget, moveTarget=moveTarget}
