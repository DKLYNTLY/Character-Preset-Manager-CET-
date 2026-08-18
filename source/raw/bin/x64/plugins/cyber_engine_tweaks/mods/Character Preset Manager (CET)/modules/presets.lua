local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

function readPresetFile(path, metadataOnly)
  local file = io.open(path, "r")
  if not file then return nil end
  local sizeOk, size = pcall(file.seek, file, "end")
  if not sizeOk or not size or size > MAX_PRESET_BYTES then
    file:close()
    log(("[FILES] Preset rejected because its size is invalid: file='%s' bytes='%s'.")
      :format(path, tostring(size)), "warn")
    return nil
  end
  local rewindOk, rewindResult = pcall(file.seek, file, "set", 0)
  if not rewindOk or rewindResult == nil then file:close(); return nil end
  local entries = {}
  local entryCount = 0
  local metadata = { format = 4, source = "Legacy or ACU-compatible" }
  local lineNumber, malformed, pendingSlot, pendingChoice = 0, 0, nil, nil
  local readableFormatConfirmed = false
  local lastEntry = nil
  for line in file:lines() do
    lineNumber = lineNumber + 1
    if lineNumber > MAX_PRESET_LINES then
      file:close()
      log(("[FILES] Preset rejected because it exceeds %d lines: file='%s'.")
        :format(MAX_PRESET_LINES, path), "warn")
      return nil
    end
    local metadataKey, metadataValue = line:match("^# CPM\t([%a]+)\t(.*)$")
    if metadataKey == "format" then
      metadata.format = tonumber(metadataValue) or 4
    elseif metadataKey == "source" then
      metadata.source = catalogDecode(metadataValue)
    elseif metadataKey == "created" then
      metadata.created = catalogDecode(metadataValue)
    elseif metadataKey == "modified" then
      metadata.modified = catalogDecode(metadataValue)
    elseif metadataKey == "notes" then
      metadata.notes = sanitizeMetadata(catalogDecode(metadataValue), 512)
    elseif metadataKey == "tags" then
      metadata.tags = sanitizeMetadata(catalogDecode(metadataValue), 128)
    elseif not metadataOnly and metadataKey == "slot" then
      local slot = catalogDecode(metadataValue)
      pendingSlot = #slot <= MAX_PRESET_KEY_BYTES and not slot:find("%c")
        and slot or nil
    elseif not metadataOnly and metadataKey == "choice" then
      local choice = catalogDecode(metadataValue)
      pendingChoice = #choice <= MAX_PRESET_KEY_BYTES * 4 and not choice:find("%c")
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
      metadata.source = sanitizeMetadata(readableValue, 128)
    elseif readableFormatConfirmed and readableKey == "Created" then
      metadata.created = sanitizeMetadata(readableValue, 64)
    elseif readableFormatConfirmed and readableKey == "Modified" then
      metadata.modified = sanitizeMetadata(readableValue, 64)
    elseif readableFormatConfirmed and readableKey == "Notes" then
      metadata.notes = sanitizeMetadata(readableValue, 512)
    elseif readableFormatConfirmed and readableKey == "Tags" then
      metadata.tags = sanitizeMetadata(readableValue, 128)
    elseif not metadataOnly and readableFormatConfirmed
        and readableKey == "Editor slot" and lastEntry then
      local slot = sanitizeMetadata(readableValue, MAX_PRESET_KEY_BYTES)
      lastEntry.slot = slot ~= "" and slot or nil
    elseif not metadataOnly and readableFormatConfirmed
        and readableKey == "Saved choice" and lastEntry then
      lastEntry.choice = stableChoiceIdentity(
        sanitizeMetadata(readableValue, MAX_PRESET_KEY_BYTES * 4))
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
        file:close()
        log(("[FILES] Preset rejected at line %d: file='%s' keyBytes=%d index='%s' indexError='%s' entriesBefore=%d.")
          :format(lineNumber, path, #key, tostring(index),
            tostring(indexError or "none"), entryCount), "warn")
        return nil
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
      if malformed <= 20 then
        log(("[FILES] Malformed preset line skipped: file='%s' line=%d content='%s'.")
          :format(path, lineNumber, line), "warn")
      end
    end
  end
  file:close()
  if malformed > 0 then
    log(("[FILES] Preset '%s' contains %d malformed nonblank line%s; valid entries remain loadable.")
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
    entries = not metadataOnly and entries or nil,
    entryCount = entryCount,
    entryCountKnown = true,
    lazy = metadataOnly == true,
  }
end

state.presetEntryCount = function(preset)
  if not preset then return 0 end
  if preset.entries then return #preset.entries end
  return tonumber(preset.entryCount) or 0
end

state.hydratePreset = function(preset, path)
  if not preset then return nil end
  if preset.entries then return preset end
  local loaded = readPresetFile(path)
  if not loaded then return nil end
  local storage = preset.storage
  for key in pairs(preset) do preset[key] = nil end
  for key, value in pairs(loaded) do preset[key] = value end
  preset.storage = storage
  preset.fingerprint = fileFingerprint(path, MAX_PRESET_BYTES)
  preset.lazy = false
  return preset
end

function hydrateNamedPreset(name)
  local preset = name and state.library.presets[name]
  if not preset then return nil end
  return state.hydratePreset(preset, presetPath(name))
end

state.invalidatePreflight = function()
  state.load.preflight = nil
  state.load.preflightDirty = true
  state.load.preflightPresetName = nil
  state.load.preflightTimer = 0
end

function writePresetContents(path, preset)
  return writeFileSafely(path, "w", function(file)
    local format = tonumber(preset.format) or CURRENT_PRESET_FORMAT
    local header = {
      "# Character Preset Manager (CET) preset",
      "# Format: " .. tostring(format),
      "# Source: " .. sanitizeMetadata(preset.source or MOD_NAME, 128),
      "# Created: " .. sanitizeMetadata(preset.created or "", 64),
      "# Modified: " .. sanitizeMetadata(preset.modified or "", 64),
      "# Notes: " .. sanitizeMetadata(preset.notes, 512),
      "# Tags: " .. sanitizeMetadata(preset.tags, 128),
      "#",
      "# Appearance options",
      "# Each main line is OptionKey:SavedNumber.",
      "# Editor slot and Saved choice lines describe the option above them.",
      "",
    }
    for _, line in ipairs(header) do
      if not file:write(line .. "\n") then return false end
    end
    for _, entry in ipairs(preset.entries or {}) do
      if not file:write(("%s:%d\n"):format(
          tostring(entry.key), tonumber(entry.index) or 0)) then return false end
      if entry.slot and entry.slot ~= "" then
        if not file:write("# Editor slot: " ..
            sanitizeMetadata(entry.slot, MAX_PRESET_KEY_BYTES) .. "\n") then return false end
      end
      if entry.choice and entry.choice ~= "" then
        if not file:write("# Saved choice: " ..
            sanitizeMetadata(entry.choice, MAX_PRESET_KEY_BYTES * 4) .. "\n") then return false end
      end
      if not file:write("\n") then return false end
    end
    return file:flush() ~= nil
  end)
end

function writeLinesIfChanged(path, lines, description, maximumBytes)
  local contents = #lines > 0 and (table.concat(lines, "\n") .. "\n") or ""
  if #contents > maximumBytes then return false, false end
  local existing = readBoundedFile(path, maximumBytes)
  if existing == contents then return true, false end
  local result = atomicReplace(path, function(temporary)
    return writeFileSafely(temporary, "wb", function(file)
      return file:write(contents) ~= nil and file:flush() ~= nil
    end)
  end, description)
  return result, result
end

writeConfig = function()
  local result = atomicReplace(CONFIG_FILE, function(temporary)
    return writeFileSafely(temporary, "wb", function(file)
      return file:write(
        "discoveryReminder=" .. tostring(not state.ui.discoveryNoticeIgnored) .. "\n" ..
        "presetSort=" .. (state.library.sortMode == "modified" and "modified" or "name") .. "\n"
      ) ~= nil and file:flush() ~= nil
    end)
  end, "config")
  return result
end

readConfig = function()
  local config = {
    discoveryReminder = true,
    presetSort = "name",
  }
  local file = io.open(CONFIG_FILE, "rb")
  if not file then return config, false end
  local sizeOk, size = pcall(file.seek, file, "end")
  local rewindOk, rewindResult = pcall(file.seek, file, "set", 0)
  if not sizeOk or not size or size > 4096
      or not rewindOk or rewindResult == nil then
    file:close()
    log("[CONFIG] Config is unreadable or exceeds 4 KB; defaults were used.", "warn")
    return config, false
  end
  for line in file:lines() do
    local key, value = line:match("^%s*([%a]+)%s*=%s*([%a]+)%s*$")
    if key == "discoveryReminder" and (value == "true" or value == "false") then
      config.discoveryReminder = value == "true"
    elseif key == "presetSort" and (value == "name" or value == "modified") then
      config.presetSort = value
    elseif line:match("%S") and not line:match("^%s*#") then
      log("[CONFIG] Ignored unsupported config line: " .. tostring(line), "warn")
    end
  end
  file:close()
  return config, true
end

function writePresetPath(path, preset)
  local wrote = atomicReplace(path, function(temporary)
    if not writePresetContents(temporary, preset) then return false end
    return presetsMatch(preset, readPresetFile(temporary))
  end, "preset")
  if wrote then preset.fingerprint = fileFingerprint(path, MAX_PRESET_BYTES) end
  return wrote
end

presetsMatch = function(expected, actual)
  local expectedEntries = expected and expected.entries or {}
  local actualEntries = actual and actual.entries or {}
  if expected and actual and expected.fingerprint and actual.fingerprint then
    return expected.fingerprint == actual.fingerprint
  end
  if state.presetEntryCount(expected) ~= state.presetEntryCount(actual) then return false end
  if (tonumber(expected and expected.format) or 4) >= 5 then
    for _, key in ipairs({ "format", "source", "created", "modified", "notes", "tags" }) do
      if tostring(expected[key] or "") ~= tostring(actual and actual[key] or "") then
        return false
      end
    end
  end
  if not expected or not actual or not expected.entries or not actual.entries then
    return true
  end
  for index, entry in ipairs(expectedEntries) do
    local other = actualEntries[index]
    if not other
        or tostring(entry.key) ~= tostring(other.key)
        or (tonumber(entry.index) or 0) ~= (tonumber(other.index) or 0) then
      return false
    end
    if (tonumber(expected and expected.format) or 4) >= 6
        and tostring(entry.slot or "") ~= tostring(other.slot or "") then return false end
    if (tonumber(expected and expected.format) or 4) >= 7
        and tostring(entry.choice or "") ~= tostring(other.choice or "") then return false end
  end
  return true
end

function readVerifiedPresetCopy(expected, path)
  local copy = readPresetFile(path)
  if not copy or not presetsMatch(expected, copy) then return nil end
  copy.fingerprint = fileFingerprint(path, MAX_PRESET_BYTES)
  return copy
end

function cleanupFailureMessage(paths, cleanedMessage, leftoverMessage)
  return removeFileList(paths) and cleanedMessage or leftoverMessage
end

function uniquePresetCopyName(sourceName)
  local folder = parentFolder(sourceName)
  local leaf = baseName(sourceName)
  for index = 1, 999 do
    local suffix = index == 1 and " Copy" or (" Copy %d"):format(index)
    local candidate = joinFolder(folder, leaf .. suffix)
    if not findPresetCollision(candidate) then return candidate end
  end
  return nil
end

function findExistingFolderName(name, excludeName)
  local lowered = name:lower()
  for existing in pairs(state.library.folders) do
    if existing:lower() == lowered and existing ~= excludeName then return existing end
  end
  return nil
end

function folderNameExists(name)
  return findExistingFolderName(name) ~= nil
end

function uniqueFolderCopyName(sourceName)
  local folder = parentFolder(sourceName)
  local leaf = baseName(sourceName)
  for index = 1, 999 do
    local suffix = index == 1 and " Copy" or (" Copy %d"):format(index)
    local candidate = joinFolder(folder, leaf .. suffix)
    if not folderNameExists(candidate) then return candidate end
  end
  return nil
end

function savePreset(confirmOverwrite)
  helpers.auditSection("CREATE PRESET")
  log(("[PRESET] Create requested: enteredName='%s' overwriteConfirmed=%s")
    :format(tostring(state.library.newName), tostring(confirmOverwrite == true)), "info")
  local _, options, optionsError = getOptions()
  if not options then
    setStatus("create", "Open the character creator, a mirror, or a ripperdoc.", true)
    log("[create] " .. tostring(optionsError), "warn")
    return
  end
  local leafName, nameError = validatedPresetName(state.library.newName)
  if not leafName then setStatus("create", nameError, true); return end
  local name = joinFolder(state.library.selectedFolder, leafName)
  local armedOverwriteName = state.library.pendingOverwriteName
  local armedOverwriteFingerprint = state.library.pendingOverwriteFingerprint
  cancelConfirmations()
  resetLoadState()

  local collision = findPresetCollision(name)
  if collision and collision ~= name then
    state.library.pendingOverwriteName = nil
    setStatus("create", ("\"%s\" conflicts with \"%s\" because Windows treats them as the same name. Enter another name.")
      :format(name, collision), true)
    return
  end
  if collision == name then
    local currentFingerprint = fileFingerprint(presetPath(collision))
    if not currentFingerprint then
      setStatus("create", "The existing preset could not be verified safely.", true)
      return
    end
    if not confirmOverwrite
        or armedOverwriteName ~= name
        or armedOverwriteFingerprint ~= currentFingerprint then
      state.library.pendingOverwriteName = name
      state.library.pendingOverwriteFingerprint = currentFingerprint
      local message = confirmOverwrite and armedOverwriteName == name
        and ("\"%s\" changed after confirmation. Review it and select Confirm Overwrite again.")
          :format(name)
        or ("\"%s\" already exists. Select Confirm Overwrite to replace it.")
          :format(name)
      setStatus("create", message, true)
      return
    end
  end
  state.library.pendingOverwriteName = nil
  state.library.pendingOverwriteFingerprint = nil

  local entries = {}
  local savedOccurrences = {}
  for _, option in ipairs(options) do
    local key = optionKey(option)
    if key and option.isEditable and option.isActive then
      local currentIndex = tonumber(option.currIndex)
      local identity = optionAuditIdentity(
        option,
        key,
        (savedOccurrences[key] or 0) + 1
      )
      if #key > MAX_PRESET_KEY_BYTES then
        log(("[SNAPSHOT] Rejected %s | keyBytes=%d maximum=%d")
          :format(identity, #key, MAX_PRESET_KEY_BYTES), "error")
        setStatus("create",
          ("A character option name is longer than the %d-byte preset limit. Open the Activity Log to see which option caused this.")
            :format(MAX_PRESET_KEY_BYTES),
          true
        )
        return
      end
      if #entries >= MAX_PRESET_ENTRIES then
        log(("[SNAPSHOT] Rejected %s | savedEntries=%d maximum=%d")
          :format(identity, #entries, MAX_PRESET_ENTRIES), "error")
        setStatus("create",
          ("The editor contains more than %d active options. Open the Activity Log for details.")
            :format(MAX_PRESET_ENTRIES),
          true
        )
        return
      end
      local indexError = optionIndexValidationError(currentIndex)
      if indexError then
        log(("[SNAPSHOT] Rejected %s | index=%s reason='%s' nativeMaximum=%d")
          :format(identity, tostring(currentIndex), indexError, MAX_OPTION_INDEX), "error")
        setStatus("create",
          "A character option returned a number that the mod cannot use. Open the Activity Log to see which option caused this.",
          true
        )
        return
      end
      savedOccurrences[key] = (savedOccurrences[key] or 0) + 1
      local slot = optionSlot(option)
      local choice = helpers.optionChoiceKey(option, currentIndex)
      log(("[SNAPSHOT] Saved %s index=%d slot='%s' choice='%s' editable=true active=true")
        :format(optionAuditIdentity(option, key, savedOccurrences[key]),
          currentIndex, tostring(slot or "none"), tostring(choice or "none")), "info")
      table.insert(entries, {
        key = key,
        index = currentIndex,
        slot = slot,
        choice = choice,
      })
    end
  end
  if #entries == 0 then
    setStatus("create", "No editable options were found.", true)
    return
  end

  local previousPreset = state.library.presets[name]
  if previousPreset and not hydrateNamedPreset(name) then
    setStatus("create", "The existing preset could not be read safely before replacement.", true)
    return
  end
  local storage = previousPreset and previousPreset.storage
    or uniqueStorageName(leafName)
  if not storage then
    setStatus("create", "The mod could not create a safe file name for this preset.", true)
    return
  end
  local newPreset = {
    format = CURRENT_PRESET_FORMAT,
    source = MOD_NAME,
    created = previousPreset and previousPreset.created or logTimestamp(),
    modified = logTimestamp(),
    notes = previousPreset and previousPreset.notes or "",
    tags = previousPreset and previousPreset.tags or "",
    entries = entries,
    entryCount = #entries,
    storage = storage,
  }
  local storagePath = PRESET_DIR .. "/" .. storage .. ".preset"
  if not writePresetPath(storagePath, newPreset) then
    setStatus("create", "Could not write " .. storagePath .. ".", true)
    return
  end
  state.library.presets[name] = newPreset
  if not writeCatalog(state.library.presets, state.library.folders, state.library.manualFolders,
      state.library.ignoredPhysicalFolders) then
    local rolledBack = true
    if previousPreset then
      rolledBack = writePresetPath(storagePath, previousPreset)
      state.library.presets[name] = previousPreset
    else
      rolledBack = removeFileList({ storagePath })
      state.library.presets[name] = nil
    end
    setStatus("create", rolledBack
      and "The preset was not saved because its folder could not be recorded."
      or "The folder list could not be saved, and the preset file could not be returned to its earlier state.", true)
    return
  end
  state.library.selected = name
  state.library.presetNotes = newPreset.notes or ""
  state.library.presetTags = newPreset.tags or ""
  invalidateViewCache()
  state.library.renameName = ""
  state.library.newName = ""
  resetLoadState()
  log(("Created preset '%s': format=%d orderedOptions=%d")
    :format(name, CURRENT_PRESET_FORMAT, #entries), "info")
  if writeInventory(state.library.presets, state.library.folders) then
    setStatus("create", ("Saved \"%s\" with %d options.")
      :format(name, #entries), false, "success")
  else
    setStatus("create", ("Saved \"%s\", but the preset file list could not be updated.")
      :format(name), false, "warning")
  end
end

function renamePreset()
  helpers.auditSection("RENAME PRESET")
  if not state.library.selected or not state.library.presets[state.library.selected] then
    setStatus("rename", "Select a preset before renaming it.", true)
    return
  end
  local newLeafName, nameError = validatedPresetName(state.library.renameName)
  if not newLeafName then setStatus("rename", nameError, true); return end
  local old = state.library.selected
  local newName = joinFolder(parentFolder(old), newLeafName)
  if newName == old then setStatus("rename", "The preset already has this name."); return end
  if newName:lower() == old:lower() then
    setStatus("rename", "Preset names cannot differ only by capitalization.", true)
    return
  end
  local collision = findPresetCollision(newName, old)
  if collision then
    setStatus("rename", ("A preset named \"%s\" already exists."):format(collision), true)
    return
  end
  local preset = state.library.presets[old]
  local oldStorage = preset.storage
  local newStorage = joinFolder(parentFolder(oldStorage), newLeafName)
  local oldPath = PRESET_DIR .. "/" .. oldStorage .. ".preset"
  local newPath = PRESET_DIR .. "/" .. newStorage .. ".preset"
  local physicalRenameNeeded = newStorage ~= oldStorage
  if physicalRenameNeeded and fileExists(newPath) then
    setStatus("rename", "A shareable preset file with that name already exists.", true)
    return
  end
  local renamePlan = {
    storage = oldStorage,
    destinationStorage = newStorage,
    name = old,
  }
  if physicalRenameNeeded then
    if not writeTransaction("prepared", "rename", { renamePlan }) then
    setStatus("rename", "The recovery record for this rename could not be created.", true)
      return
    end
    local renamed, renameError = os.rename(oldPath, newPath)
    if not renamed then
      os.remove(TRANSACTION_FILE)
      setStatus("rename", "The shareable preset file could not be renamed: " ..
        tostring(renameError), true)
      return
    end
    preset.storage = newStorage
  end
  state.library.presets[old] = nil
  state.library.presets[newName] = preset
  local persisted = persistVirtualState(state.library.presets, state.library.folders, state.library.manualFolders,
      state.library.ignoredPhysicalFolders)
  local transactionCompleted = persisted and (not physicalRenameNeeded
    or completeTransaction("rename", { renamePlan }))
  if not transactionCompleted then
    state.library.presets[newName] = nil
    state.library.presets[old] = preset
    if physicalRenameNeeded then
      local rolledBack = os.rename(newPath, oldPath) ~= nil
      preset.storage = rolledBack and oldStorage or newStorage
      if not rolledBack then
        local repaired = writeCatalog(state.library.presets, state.library.folders, state.library.manualFolders,
          state.library.ignoredPhysicalFolders)
        setStatus("rename", repaired
          and "The name shown in the mod could not be changed, and the file could not be moved back. The folder list now uses the new file name."
          or "The name shown in the mod could not be changed, the file could not be moved back, and the folder list could not be repaired.", true)
        return
      end
      os.remove(TRANSACTION_FILE)
    end
    if persisted then
      writeCatalog(state.library.presets, state.library.folders, state.library.manualFolders,
        state.library.ignoredPhysicalFolders)
      writeInventory(state.library.presets, state.library.folders)
    end
    setStatus("rename", "The preset could not be renamed because the folder list or recovery record could not be saved.", true)
    return
  end
  state.library.selected = newName
  invalidateViewCache()
  state.library.renameName = ""
  cancelConfirmations()
  resetLoadState()
  setStatus("rename", "Renamed \"" .. old .. "\" to \"" .. newName .. "\".",
    false, "success")
  log(("[PRESET] Display and physical rename completed: '%s' -> '%s' storage='%s'.")
    :format(old, newName, preset.storage), "complete")
end

function movePresetToSelectedFolder()
  clearStatus("folder")
  helpers.auditSection("MOVE PRESET")
  if not state.library.selected or not state.library.presets[state.library.selected] then
    setStatus("folder", "Select a preset before moving it.", true); return
  end
  local old = state.library.selected
  local newName = joinFolder(state.library.selectedFolder, baseName(old))
  if newName == old then
    setStatus("folder", "The preset is already in the selected folder."); return
  end
  local collision = findPresetCollision(newName, old)
  if collision then
    setStatus("folder",
      ("A preset named \"%s\" already exists there."):format(baseName(collision)), true); return
  end
  local preset = state.library.presets[old]
  state.library.presets[old] = nil
  state.library.presets[newName] = preset
  if not persistVirtualState(state.library.presets, state.library.folders, state.library.manualFolders,
      state.library.ignoredPhysicalFolders) then
    state.library.presets[newName] = nil
    state.library.presets[old] = preset
    setStatus("folder",
      "The preset could not be moved because the folder list could not be saved.", true); return
  end
  state.library.selected = newName
  invalidateViewCache()
  cancelConfirmations()
  resetLoadState()
  setStatus("folder",
    ("Moved \"%s\" to %s."):format(baseName(newName),
      state.library.selectedFolder == "" and "All Presets" or state.library.selectedFolder), false, "success")
  log(("[PRESET] Virtual move completed: '%s' -> '%s' storage='%s'.")
    :format(old, newName, preset.storage), "complete")
end

function savePresetMetadata()
  if not state.library.selected or not state.library.presets[state.library.selected] then
    setStatus("rename", "Select a preset before saving its details.", true); return
  end
  local preset = hydrateNamedPreset(state.library.selected)
  if not preset then
    setStatus("rename", "The selected preset could not be read safely.", true)
    return
  end
  local previousNotes, previousTags = preset.notes, preset.tags
  local previousModified, previousFormat = preset.modified, preset.format
  local previousSource = preset.source
  preset.notes = sanitizeMetadata(state.library.presetNotes, 512)
  preset.tags = sanitizeMetadata(state.library.presetTags, 128)
  preset.modified = logTimestamp()
  preset.created = preset.created or preset.modified
  preset.source = MOD_NAME
  preset.format = math.max(CURRENT_PRESET_FORMAT, tonumber(preset.format) or 4)
  if not writePresetPath(presetPath(state.library.selected), preset) then
    preset.notes, preset.tags = previousNotes, previousTags
    preset.modified, preset.format = previousModified, previousFormat
    preset.source = previousSource
    setStatus("rename", "Preset details could not be saved safely.", true)
    return
  end
  state.library.presetNotes = preset.notes
  state.library.presetTags = preset.tags
  invalidateViewCache()
  local inventorySaved = writeInventory(state.library.presets, state.library.folders)
  setStatus("rename", "Saved details for \"" .. state.library.selected .. "\"." ..
    (inventorySaved and "" or " The preset file list could not be updated."),
    false, inventorySaved and "success" or "warning")
end

function duplicatePreset()
  helpers.auditSection("DUPLICATE PRESET")
  if not state.library.selected or not state.library.presets[state.library.selected] then
    setStatus("rename", "Select a preset before duplicating it.", true); return
  end
  local source = state.library.selected
  local destination = uniquePresetCopyName(source)
  if not destination then
    setStatus("rename", "Could not find an available name for the duplicate.", true); return
  end
  local sourcePreset = hydrateNamedPreset(source)
  if not sourcePreset then
    setStatus("rename", "The selected preset could not be read safely.", true)
    return
  end
  local storage = uniqueStorageName(baseName(destination))
  if not storage then
    setStatus("rename", "The mod could not create a safe file name for the copy.", true); return
  end
  local destinationPath = PRESET_DIR .. "/" .. storage .. ".preset"
  if not copyFile(presetPath(source), destinationPath) then
    setStatus("rename", cleanupFailureMessage({ destinationPath },
      "The duplicate could not be written.",
      "The duplicate failed, and its partial file could not be removed."), true); return
  end
  local duplicate = readVerifiedPresetCopy(sourcePreset, destinationPath)
  if not duplicate then
    setStatus("rename", cleanupFailureMessage({ destinationPath },
      "The duplicate could not be verified.",
      "Duplicate verification failed, and its file could not be removed."), true); return
  end
  duplicate.storage = storage
  state.library.presets[destination] = duplicate
  if not persistVirtualState(state.library.presets, state.library.folders, state.library.manualFolders,
      state.library.ignoredPhysicalFolders) then
    state.library.presets[destination] = nil
    setStatus("rename", cleanupFailureMessage({ destinationPath },
      "The copy was removed because the folder list could not be saved.",
      "The folder list could not be saved, and the copied file could not be removed."), true)
    return
  end
  state.library.selected = destination
  invalidateViewCache()
  state.library.renameName = ""
  cancelConfirmations()
  resetLoadState()
  setStatus("rename", ("Duplicated \"%s\" as \"%s\"."):format(source, destination),
    false, "success")
  log(("[PRESET] Duplicate completed: source='%s' destination='%s' storage='%s'.")
    :format(source, destination, storage), "complete")
end

return _ENV
