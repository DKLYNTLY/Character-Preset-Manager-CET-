local names = require("modules/domain/names")
local paths = require("modules/domain/paths")
local identities = require("modules/domain/identities")
local codecs = require("modules/domain/codecs")
local MAX_PRESET_ENTRIES = 4096
local PRESET_LINES_PER_ENTRY = 4
local PRESET_HEADER_LINE_ALLOWANCE = 64
local MAX_PRESET_LINES = MAX_PRESET_ENTRIES * PRESET_LINES_PER_ENTRY + PRESET_HEADER_LINE_ALLOWANCE
local MAX_PRESET_KEY_BYTES = 256
local CURRENT_PRESET_FORMAT = 8
local LEGACY_PRESET_FORMAT = 4
local MAX_NOTES_BYTES = 512
local MAX_TAGS_BYTES = 128
local MAX_NAME_BYTES = 64
local MAX_SOURCE_BYTES = 128
local MAX_TIMESTAMP_BYTES = 64
local CHOICE_IDENTITY_BYTE_MULTIPLIER = 4
local MALFORMED_LINE_LOG_LIMIT = 20
local sanitizeMetadata = names.sanitizeMetadata
local validatedPresetName = names.validatedPresetName
local validRelativePath = paths.validRelativePath
local stableChoiceIdentity = identities.stableChoiceIdentity
local optionIndexValidationError = identities.optionIndexValidationError
local catalogDecode = codecs.catalogDecode

local function newTextDecoder(path, metadataOnly)
  local diagnostics = {}
  local function addDiagnostic(message, level)
    diagnostics[#diagnostics + 1] = { message = message, level = level }
  end
  local entries = {}
  local entryCount = 0
  local metadata = { format = LEGACY_PRESET_FORMAT, source = "Legacy or ACU-compatible" }
  local lineNumber, malformed, pendingSlot, pendingChoice = 0, 0, nil, nil
  local readableFormatConfirmed = false
  local lastEntry = nil
  local function readLine(line)
    lineNumber = lineNumber + 1
    if lineNumber > MAX_PRESET_LINES then
      addDiagnostic(("[FILES] Preset rejected because it exceeds %d lines: file='%s'.")
        :format(MAX_PRESET_LINES, path), "warn")
      return false
    end
    if line == "# CPM Preset"
        or line == "# Character Preset Manager (CET) preset" then
      metadata.managedByCpm = true
    end
    local metadataKey, metadataValue = line:match("^# CPM\t([%a]+)\t(.*)$")
    if metadataKey then metadata.managedByCpm = true end
    if metadataKey == "format" then
      metadata.format = tonumber(metadataValue) or LEGACY_PRESET_FORMAT
    elseif metadataKey == "source" then
      metadata.source = catalogDecode(metadataValue)
    elseif metadataKey == "created" then
      metadata.created = catalogDecode(metadataValue)
    elseif metadataKey == "modified" then
      metadata.modified = catalogDecode(metadataValue)
    elseif metadataKey == "notes" then
      metadata.notes = sanitizeMetadata(catalogDecode(metadataValue), MAX_NOTES_BYTES)
    elseif metadataKey == "tags" then
      metadata.tags = sanitizeMetadata(catalogDecode(metadataValue), MAX_TAGS_BYTES)
    elseif metadataKey == "favorite" then
      metadata.favorite = metadataValue == "true" or metadataValue == "1"
    elseif not metadataOnly and metadataKey == "slot" then
      local slot = catalogDecode(metadataValue)
      pendingSlot = #slot <= MAX_PRESET_KEY_BYTES and not slot:find("%c")
        and slot or nil
    elseif not metadataOnly and metadataKey == "choice" then
      local choice = catalogDecode(metadataValue)
      pendingChoice = #choice <= MAX_PRESET_KEY_BYTES * CHOICE_IDENTITY_BYTE_MULTIPLIER and not choice:find("%c")
        and stableChoiceIdentity(choice) or nil
    end
    local readableKey, readableValue = line:match("^# ([%a ]+):%s?(.*)$")
    if readableKey == "Format" and entryCount == 0 then
      local readableFormat = tonumber(readableValue)
      if readableFormat and readableFormat >= CURRENT_PRESET_FORMAT then
        metadata.format = readableFormat
        readableFormatConfirmed = true
      end
    elseif readableFormatConfirmed and readableKey == "Source" then
      metadata.source = sanitizeMetadata(readableValue, MAX_SOURCE_BYTES)
    elseif readableFormatConfirmed and readableKey == "Created" then
      metadata.created = sanitizeMetadata(readableValue, MAX_TIMESTAMP_BYTES)
    elseif readableFormatConfirmed and readableKey == "Modified" then
      metadata.modified = sanitizeMetadata(readableValue, MAX_TIMESTAMP_BYTES)
    elseif readableFormatConfirmed and readableKey == "Notes" then
      metadata.notes = sanitizeMetadata(readableValue, MAX_NOTES_BYTES)
    elseif readableFormatConfirmed and readableKey == "Tags" then
      metadata.tags = sanitizeMetadata(readableValue, MAX_TAGS_BYTES)
    elseif readableFormatConfirmed and readableKey == "Favorite" then
      local favorite = tostring(readableValue):lower()
      metadata.favorite = favorite == "yes" or favorite == "true" or favorite == "on"
    elseif readableFormatConfirmed and readableKey == "Name"
        and metadata.managedByCpm then
      local name = sanitizeMetadata(readableValue, MAX_NAME_BYTES)
      local validated = validatedPresetName(name)
      if validated == name then metadata.presetName = name end
    elseif readableFormatConfirmed and readableKey == "Library folder"
        and metadata.managedByCpm then
      local folder = sanitizeMetadata(readableValue, MAX_PRESET_KEY_BYTES * CHOICE_IDENTITY_BYTE_MULTIPLIER)
      if folder == "/" then folder = "" end
      if folder == "" or validRelativePath(folder) then
        metadata.libraryFolder = folder
      end
    elseif not metadataOnly and readableFormatConfirmed
        and readableKey == "Editor slot" and lastEntry then
      local slot = sanitizeMetadata(readableValue, MAX_PRESET_KEY_BYTES)
      lastEntry.slot = slot ~= "" and slot or nil
    elseif not metadataOnly and readableFormatConfirmed
        and readableKey == "Saved choice" and lastEntry then
      lastEntry.choice = stableChoiceIdentity(
        sanitizeMetadata(readableValue, MAX_PRESET_KEY_BYTES * CHOICE_IDENTITY_BYTE_MULTIPLIER))
    end
    local key, index = nil, nil
    if not line:match("^#") then
      key, index = line:match("^%s*(.-):(-?%d+)%s*$")
    end
    local numericIndex = tonumber(index)
    if key and key ~= "" then
      local indexError = optionIndexValidationError(numericIndex)
      if #key > MAX_PRESET_KEY_BYTES
          or indexError
          or entryCount >= MAX_PRESET_ENTRIES then
          addDiagnostic(("[FILES] Preset rejected at line %d: file='%s' keyBytes=%d index='%s' indexError='%s' entriesBefore=%d.")
          :format(lineNumber, path, #key, tostring(index),
            tostring(indexError or "none"), entryCount), "warn")
        return false
      end
      entryCount = entryCount + 1
      if not metadataOnly then
        lastEntry = {
          key = key,
          index = numericIndex,
          slot = pendingSlot,
          choice = pendingChoice,
        }
        table.insert(entries, lastEntry)
      else
        lastEntry = nil
      end
      pendingSlot, pendingChoice = nil, nil
    elseif not metadataKey and line:match("%S") and not line:match("^#") then
      malformed = malformed + 1
      if malformed <= MALFORMED_LINE_LOG_LIMIT then
        addDiagnostic(("[FILES] Malformed preset line skipped: file='%s' line=%d content='%s'.")
          :format(path, lineNumber, line), "warn")
      end
    end
    return true
  end
  local function finish()
    if malformed > 0 then
      addDiagnostic(("[FILES] Preset '%s' contains %d malformed nonblank line%s; valid entries remain loadable.")
        :format(path, malformed, malformed == 1 and "" or "s"), "warn")
    end
    if entryCount == 0 then return nil end
    return {
      format = metadata.format,
      source = metadata.source,
      created = metadata.created,
      modified = metadata.modified,
      notes = metadata.notes or "",
      tags = metadata.tags or "",
      favorite = metadata.favorite == true,
      managedByCpm = metadata.managedByCpm == true,
      presetName = metadata.presetName,
      libraryFolder = metadata.libraryFolder,
      entries = not metadataOnly and entries or nil,
      entryCount = entryCount,
      entryCountKnown = true,
      metadataLoaded = true,
      lazy = metadataOnly == true,
    }
  end
  return { readLine = readLine, finish = finish, diagnostics = diagnostics }
end

local function decodeAcuJson(decoded, metadataOnly)
  local options = decoded.options or decoded.values
  if type(options) ~= "table" and #decoded > 0 then options = decoded end
  if type(options) ~= "table" then return nil end
  local entries = {}
  for _, option in ipairs(options) do
    if type(option) == "table" then
      local key = option.name or option.optionName or option.key
      local index = option.value
      if index == nil then index = option.index end
      local active = option.is_active
      if active == nil then active = option.isActive end
      local numericIndex = tonumber(index)
      if active ~= false and type(key) == "string" and key ~= ""
          and #key <= MAX_PRESET_KEY_BYTES
          and not optionIndexValidationError(numericIndex) then
        if #entries >= MAX_PRESET_ENTRIES then return nil end
        entries[#entries + 1] = { key = key, index = numericIndex }
      end
    end
  end
  if #entries == 0 then return nil end
  local style = decoded.isMaleVO ~= nil and "3.0.0" or "3.0.1 or newer"
  return {
    format = LEGACY_PRESET_FORMAT,
    source = "ACU " .. style .. " JSON preset",
    notes = "",
    tags = "ACU",
    favorite = false,
    managedByCpm = false,
    entries = not metadataOnly and entries or nil,
    entryCount = #entries,
    entryCountKnown = true,
    metadataLoaded = true,
    lazy = metadataOnly == true,
  }
end

local function encode(preset, modName)
  local format = tonumber(preset.format) or CURRENT_PRESET_FORMAT
  local libraryFolder = tostring(preset.libraryFolder or "")
  if libraryFolder ~= "" and not validRelativePath(libraryFolder) then
    libraryFolder = ""
  end
  local header = {
    "# CPM Preset",
    "# Format: " .. tostring(format),
    "# Name: " .. sanitizeMetadata(preset.presetName, MAX_NAME_BYTES),
    "# Source: " .. sanitizeMetadata(preset.source or modName, MAX_SOURCE_BYTES),
    "# Created: " .. sanitizeMetadata(preset.created or "", MAX_TIMESTAMP_BYTES),
    "# Modified: " .. sanitizeMetadata(preset.modified or "", MAX_TIMESTAMP_BYTES),
    "# Notes: " .. sanitizeMetadata(preset.notes, MAX_NOTES_BYTES),
    "# Tags: " .. sanitizeMetadata(preset.tags, MAX_TAGS_BYTES),
    "# Favorite: " .. (preset.favorite == true and "Yes" or "No"),
    "# Library folder: " .. (libraryFolder ~= "" and libraryFolder or "/"),
    "#",
    "# Appearance options",
    "# Each main line gives an option key and its saved number.",
    "# Editor slot and Saved choice describe the line above them.",
    "",
  }
  local chunks = {}
  local function append(chunk) chunks[#chunks + 1] = chunk end
  for _, line in ipairs(header) do append(line .. "\n") end
  for _, entry in ipairs(preset.entries or {}) do
    append(("%s:%d\n"):format(tostring(entry.key), tonumber(entry.index) or 0))
    if entry.slot and entry.slot ~= "" then
      append("# Editor slot: " .. sanitizeMetadata(entry.slot, MAX_PRESET_KEY_BYTES) .. "\n")
    end
    if entry.choice and entry.choice ~= "" then
      append("# Saved choice: " .. sanitizeMetadata(entry.choice, MAX_PRESET_KEY_BYTES * CHOICE_IDENTITY_BYTE_MULTIPLIER) .. "\n")
    end
    append("\n")
  end
  return table.concat(chunks), chunks
end

local function stringLines(contents)
  local position = 1
  return function()
    if position > #contents then return nil end
    local newline = contents:find("\n", position, true)
    local line = contents:sub(position, newline and newline - 1 or #contents)
    position = newline and newline + 1 or #contents + 1
    return line
  end
end

local function decodeText(contents, path, metadataOnly)
  local decoder = newTextDecoder(path, metadataOnly)
  for line in stringLines(contents) do
    if not decoder.readLine(line) then return nil, decoder.diagnostics end
  end
  return decoder.finish(), decoder.diagnostics
end

return {
  decodeText = decodeText,
  decodeAcuJson = decodeAcuJson,
  encode = encode,
  MAX_PRESET_ENTRIES = MAX_PRESET_ENTRIES,
  MAX_PRESET_LINES = MAX_PRESET_LINES,
  MAX_PRESET_KEY_BYTES = MAX_PRESET_KEY_BYTES,
  CURRENT_PRESET_FORMAT = CURRENT_PRESET_FORMAT,
}
