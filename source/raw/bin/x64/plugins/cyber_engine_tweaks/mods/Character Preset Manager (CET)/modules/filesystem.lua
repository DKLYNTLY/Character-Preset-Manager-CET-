local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

function fileExists(path)
  local file = io.open(path, "rb")
  if not file then return false end
  file:close()
  return true
end

function isFolderBundleFilename(filename)
  return type(filename) == "string" and filename ~= ""
    and #filename <= 255 and not filename:find("/", 1, true)
    and not filename:find("\\", 1, true) and not filename:find("%c")
    and filename:lower():sub(-#FOLDER_BUNDLE_EXTENSION) == FOLDER_BUNDLE_EXTENSION
end

function fileFingerprint(path, maximumBytes)
  local file = io.open(path, "rb")
  if not file then return nil end
  local sizeOk, fileSize = pcall(file.seek, file, "end")
  local rewindOk, rewindResult = pcall(file.seek, file, "set", 0)
  if not sizeOk or not fileSize or fileSize > (maximumBytes or MAX_PRESET_BYTES)
      or not rewindOk or rewindResult == nil then
    file:close()
    return nil
  end
  local hash, secondHash, bytesRead = 0, 0, 0
  local ok = pcall(function()
    while true do
      local chunk = file:read(FILE_COPY_CHUNK_SIZE)
      if not chunk then break end
      bytesRead = bytesRead + #chunk
      for index = 1, #chunk do
        local byte = chunk:byte(index)
        hash = (hash * 131 + byte) % 2147483647
        secondHash = (secondHash * 137 + byte) % 2147483629
      end
    end
  end)
  local closeOk, closeResult = pcall(file.close, file)
  if not ok or bytesRead ~= fileSize
      or not closeOk or closeResult == nil then return nil end
  local legacy = tostring(bytesRead) .. ":" .. tostring(hash)
  return "2:" .. legacy .. ":" .. tostring(secondHash), legacy
end

function cancelConfirmations()
  state.library.pendingOverwriteName = nil
  state.library.pendingOverwriteFingerprint = nil
  state.trash.pendingDeleteName = nil
  state.trash.pendingDeleteFingerprint = nil
  state.library.pendingRemoveFolder = nil
  state.trash.pendingEmpty = false
  state.trash.pendingBulkAction = nil
  state.trash.pendingBulkFingerprint = nil
  state.backup.pendingDeleteFile = nil
  state.backup.pendingDeleteFingerprint = nil
end

function resetLoadState()
  state.load.presetName = nil
  state.load.overridePreset = nil
  state.load.overrideName = nil
  state.load.pass = 0
  state.load.remaining = 0
  state.load.needsContinue = false
  state.load.stalled = false
  state.load.previousUnresolvedSignature = nil
  state.load.unresolvedRepeatCount = 0
  state.load.satisfied = {}
  state.load.values = nil
  state.load.savedCounts = nil
  state.load.orderedEntries = nil
  state.load.savedEntryByKey = nil
  state.load.savedSlotCounts = nil
  state.load.valueCount = 0
  state.load.forcedKeys = {}
  state.load.resolvedChoiceIndexes = {}
  state.load.applyAttempts = {}
  state.load.unconfirmed = {}
  state.load.cleanupAttempts = {}
  state.load.cleanupSkipped = {}
  state.load.loggedWarnings = {}
  state.load.optionIdentityCache = {}
  state.load.targetPolls = 0
  state.load.targetPollSeconds = 0
  state.load.targetFallbacks = 0
  state.load.pendingChange = nil
  state.load.pendingElapsed = 0
  state.load.phase = "apply"
  state.load.elapsed = 0
  state.load.optionsSeconds = 0
  state.load.scanSeconds = 0
  state.load.choiceSeconds = 0
  state.load.applySeconds = 0
  state.load.waitSeconds = 0
  state.load.optionCalls = 0
  state.load.structureChanges = 0
  state.load.lastStructureSignature = nil
  state.load.lastOptionCount = nil
  state.load.forceStructureScan = true
  state.load.targetPollingDisabled = false
  state.load.returnToCleanup = false
  state.load.dependencyKeys = {}
  state.load.dependencyRemaps = {}
  state.load.nextInterval = AUTO_LOAD_TIMING.passInterval
  state.load.auto = false
  state.load.autoTimer = 0
  state.load.autoPasses = 0
  state.load.resetBefore = false
  state.load.nativeWarningPreset = nil
end

function cloneMap(source)
  local copy = {}
  for key, value in pairs(source or {}) do copy[key] = value end
  return copy
end

function safeDirectoryEntries(path, depth)
  if (tonumber(depth) or 0) > MAX_TREE_DEPTH then
    return nil, "folder nesting exceeds the safety limit"
  end
  local ok, entries = pcall(dir, path)
  if not ok or type(entries) ~= "table" then
    return nil, "folder could not be listed safely"
  end
  local validated = {}
  for _, entry in pairs(entries) do
    if type(entry) ~= "table"
        or type(entry.name) ~= "string"
        or (entry.type ~= "file" and entry.type ~= "directory")
        or entry.name == ""
        or entry.name == "."
        or entry.name == ".."
        or entry.name:find("/", 1, true)
        or entry.name:find("\\", 1, true)
        or entry.name:find("%c") then
      return nil, "folder contains an invalid directory entry"
    end
    table.insert(validated, entry)
  end
  table.sort(validated, function(a, b) return a.name:lower() < b.name:lower() end)
  return validated
end

function directoryTreeContainsFiles(path, depth)
  local entries = safeDirectoryEntries(path, depth)
  if not entries then return nil end
  for _, entry in ipairs(entries) do
    if entry.type == "directory" then
      local containsFiles = directoryTreeContainsFiles(path .. "/" .. entry.name, depth + 1)
      if containsFiles == nil or containsFiles then return containsFiles end
    else
      return true
    end
  end
  return false
end

function removeEmptyDirectoryTree(path, depth)
  local entries = safeDirectoryEntries(path, depth)
  if not entries then return false end
  for _, entry in ipairs(entries) do
    if entry.type ~= "directory"
        or not removeEmptyDirectoryTree(path .. "/" .. entry.name, depth + 1) then
      return false
    end
  end
  return os.remove(path) ~= nil
end

function logTimestamp()
  local ok, value = pcall(os.date, "%Y-%m-%d %H:%M:%S")
  if ok and value then return value end
  return "unknown-time"
end

helpers = {}


activityLogFile = nil

closeActivityLog = function()
  if not activityLogFile then return true end
  local file = activityLogFile
  activityLogFile = nil
  local flushOk, flushResult = pcall(file.flush, file)
  local closeOk, closeResult = pcall(file.close, file)
  return flushOk and flushResult ~= nil and closeOk and closeResult ~= nil
end

function writeLog(message, level)
  if not activityLogFile then activityLogFile = io.open(LOG_FILE, "a") end
  local file = activityLogFile
  if not file then return false end
  activitySequence = activitySequence + 1
  local wrote, writeResult = pcall(file.write, file,
    ("[%s] [#%04d] [%s] %s\n"):format(
      logTimestamp(),
      activitySequence,
      tostring(level or "info"):upper(),
      tostring(message)
    ))
  if not wrote or writeResult == nil then
    closeActivityLog()
    return false
  end
  local normalizedLevel = tostring(level or "info"):lower()
  if normalizedLevel:find("error", 1, true)
      or normalizedLevel:find("warn", 1, true)
      or normalizedLevel == "complete" then
    local flushOk, flushResult = pcall(file.flush, file)
    if not flushOk or flushResult == nil then
      closeActivityLog()
      return false
    end
  end
  return true
end

helpers.pruneLogArchives = function()
  local listOk, files = pcall(dir, LOG_ARCHIVE_DIR)
  if not listOk or type(files) ~= "table" then
    return 0, "dated activity-log archives could not be listed"
  end

  local archives = {}
  for _, entry in pairs(files) do
    local filename = type(entry) == "table" and entry.name or tostring(entry)
    if filename
        and filename:sub(1, #LOG_ARCHIVE_PREFIX) == LOG_ARCHIVE_PREFIX
        and filename:match("%.txt$") then
      table.insert(archives, filename)
    end
  end
  table.sort(archives)

  local deleted = 0
  while #archives > LOG_ARCHIVE_LIMIT do
    local oldest = table.remove(archives, 1)
    local removed, removeError = os.remove(LOG_ARCHIVE_DIR .. "/" .. oldest)
    if not removed then
      return deleted, ("oldest activity-log archive could not be deleted: %s")
        :format(tostring(removeError))
    end
    deleted = deleted + 1
  end
  return deleted, nil
end

helpers.archiveLogForNewSession = function()
  closeActivityLog()
  local file = io.open(LOG_FILE, "rb")
  if not file then return true, nil end
  local sizeOk, size = pcall(file.seek, file, "end")
  if not sizeOk or not size then file:close(); return false, "the existing activity log could not be measured" end
  if size > 0 then
    local rewindOk, rewindResult = pcall(file.seek, file, "set", 0)
    if not rewindOk or rewindResult == nil then file:close(); return false, "the existing activity log could not be rewound" end
    local dateOk, timestamp = pcall(os.date, "%Y-%m-%d_%H-%M-%S")
    if not dateOk or not timestamp then timestamp = "unknown-date" end

    local archiveName = LOG_ARCHIVE_DIR .. "/" ..
      LOG_ARCHIVE_PREFIX .. tostring(timestamp) .. ".txt"
    local suffix = 2
    while suffix <= 9999 do
      local existing = io.open(archiveName, "rb")
      if not existing then break end
      existing:close()
      archiveName = LOG_ARCHIVE_DIR .. "/" ..
        LOG_ARCHIVE_PREFIX .. tostring(timestamp) ..
        ("-%d.txt"):format(suffix)
      suffix = suffix + 1
    end
    if suffix > 9999 and fileExists(archiveName) then
      file:close()
      return false, "a unique dated activity-log archive name could not be found"
    end

    local archivedBytes = 0
    local archived, archiveFailure = writeFileSafely(archiveName, "wb", function(archive)
      while true do
        local chunk = file:read(FILE_COPY_CHUNK_SIZE)
        if not chunk then break end
        if not archive:write(chunk) then return false end
        archivedBytes = archivedBytes + #chunk
      end
      return archivedBytes == size and archive:flush() ~= nil
    end)
    file:close()
    if not archived then
      return false, archiveFailure == "open"
        and "the dated activity-log archive could not be created"
        or "the dated activity-log archive could not be written"
    end

    local deleted, pruneError = helpers.pruneLogArchives()

    if not writeFileSafely(LOG_FILE, "w", function() return true end) then
      return false, "the activity log could not be cleared"
    end
    return true, archiveName, pruneError, deleted
  end

  file:close()
  if not writeFileSafely(LOG_FILE, "w", function() return true end) then
    return false, "the empty activity log could not be refreshed"
  end
  return true, nil
end

log = function(message, level)
  level = level or "info"
  local technical = tostring(message):find("[PERFORMANCE]", 1, true) == 1
    or tostring(message):find("[MEASURE]", 1, true) == 1
    or tostring(message):find("[editor diagnostic]", 1, true) == 1
  if technical and state and state.preferences
      and state.preferences.activityLogDetail ~= "technical"
      and level ~= "error" then return end
  writeLog(message, level)
end

helpers.auditSection = function(title)
  log(("---------------- %s ----------------"):format(tostring(title)), "info")
end

function setStatus(section, message, isError, kind)
  local effectiveError = isError == true
  local sectionStatus = state.status.sections[section]
  sectionStatus.message = message
  sectionStatus.error = effectiveError
  state.status.kinds[section] = kind or (effectiveError and "error" or "info")
  if section == "load" then
    local transient = message:find("Applied one option.", 1, true) == 1
      or message:find("Cleared a remaining option.", 1, true) == 1
      or message:find("Cleanup complete.", 1, true) == 1
      or message:find("Recent changes were applied.", 1, true) == 1
      or message:find("The editor options changed.", 1, true) == 1
      or message:find("Pass ", 1, true) == 1
    if transient and not effectiveError then return end
    local level = "load"
    if effectiveError then
      level = "load error"
    elseif kind == "success" then
      level = "complete"
    end
    log(message, level)
  else
    log(("[%s] %s"):format(section, message), isError and "error" or "info")
  end
end

function clearStatus(section)
  local sectionStatus = state.status.sections[section]
  sectionStatus.message = ""
  sectionStatus.error = false
  state.status.kinds[section] = nil
end

helpers.clearSectionStatuses = function()
  for _, section in ipairs(STATUS_SECTIONS) do
    clearStatus(section)
  end
  state.status.lastLoggedFolder = nil
end

function sanitizeName(value)
  value = tostring(value or "")
  value = value:gsub("^%s+", ""):gsub("%s+$", "")
  value = value:gsub("[<>:\"/\\|%?%*%c]", "_")
  return value:sub(1, 64)
end

function sanitizeMetadata(value, maximum)
  value = tostring(value or ""):gsub("[%c]", " ")
  value = value:gsub("^%s+", ""):gsub("%s+$", "")
  return value:sub(1, maximum)
end

function validatedPresetName(value)
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

writeFileSafely = function(path, mode, writerFn)
  local file = io.open(path, mode)
  if not file then return false, "open" end
  local wrote, writeResult = pcall(writerFn, file)
  local closed, closeResult = pcall(file.close, file)
  if not wrote or writeResult ~= true or not closed or closeResult == nil then
    return false, "write"
  end
  return true
end

function atomicReplace(path, writeTemporary, description)
  local temporary = path .. ".tmp"
  local backup = path .. ".bak"

  if not fileExists(path) and fileExists(backup) then
    local recovered, recoverError = os.rename(backup, path)
    log(("[FILES] Recovery attempted: backup='%s' target='%s' success=%s error=%s")
      :format(backup, path, tostring(recovered ~= nil), tostring(recoverError)),
      recovered and "info" or "error")
    if not recovered then return false end
  end
  os.remove(temporary)
  if not writeTemporary(temporary) then
    os.remove(temporary)
    log(("[FILES] Could not write temporary %s '%s'."):format(description, temporary), "error")
    return false
  end
  if os.rename(temporary, path) then
    os.remove(backup)
    return true
  end

  os.remove(backup)
  local movedOriginal = os.rename(path, backup)
  if not movedOriginal then
    os.remove(temporary)
    return false
  end
  if not os.rename(temporary, path) then
    local restored, restoreError = os.rename(backup, path)
    if restored then
      os.remove(temporary)
    else
      log(("[FILES] Could not restore backup after replacing %s: backup='%s' target='%s' temporary='%s' error=%s")
        :format(description, backup, path, temporary, tostring(restoreError)), "error")
    end
    return false
  end
  os.remove(backup)
  return true
end

function readBoundedFile(path, maximumBytes)
  local file = io.open(path, "rb")
  if not file then return nil, "missing" end
  local sizeOk, size = pcall(file.seek, file, "end")
  local rewindOk, rewindResult = pcall(file.seek, file, "set", 0)
  if not sizeOk or not size or size > maximumBytes
      or not rewindOk or rewindResult == nil then
    file:close()
    return nil, "size"
  end
  local readOk, contents = pcall(file.read, file, "*a")
  local closeOk, closeResult = pcall(file.close, file)
  if not readOk or type(contents) ~= "string" or not closeOk or closeResult == nil then
    return nil, "read"
  end
  return contents
end

function copyFile(source, destination)
  local input = io.open(source, "rb")
  if not input then
    log(("[FILES] Copy failed: could not open source='%s'."):format(source), "error")
    return false
  end
  local sizeOk, sourceSize = pcall(input.seek, input, "end")
  local rewindOk, rewindResult = pcall(input.seek, input, "set", 0)
  if not sizeOk or not sourceSize or not rewindOk or rewindResult == nil then
    input:close()
    log(("[FILES] Copy failed: could not measure source='%s'."):format(source), "error")
    return false
  end
  local output = io.open(destination, "wb")
  if not output then
    input:close()
    log(("[FILES] Copy failed: could not open destination='%s'."):format(destination), "error")
    return false
  end
  local copiedBytes = 0
  local writeOk, writeResult = pcall(function()
    while true do
      local chunk = input:read(FILE_COPY_CHUNK_SIZE)
      if not chunk then break end
      if not output:write(chunk) then return false end
      copiedBytes = copiedBytes + #chunk
    end
    return copiedBytes == sourceSize and output:flush() ~= nil
  end)
  local inputCloseOk, inputCloseResult = pcall(input.close, input)
  local closeOk, closeResult = pcall(output.close, output)
  local copied = writeOk and writeResult == true
    and inputCloseOk and inputCloseResult ~= nil
    and closeOk and closeResult ~= nil
  log(("[FILES] Copy source='%s' destination='%s' bytes=%d success=%s.")
    :format(source, destination, copiedBytes, tostring(copied)), copied and "info" or "error")
  return copied
end

function removeFileList(paths)
  local success = true
  for _, path in ipairs(paths or {}) do
    if fileExists(path) and not os.remove(path) then success = false end
  end
  return success
end

return _ENV
