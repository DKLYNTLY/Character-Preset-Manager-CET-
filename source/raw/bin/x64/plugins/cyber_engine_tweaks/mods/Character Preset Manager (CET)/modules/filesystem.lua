local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime
local stateModel = require("modules/domain/state")
local names = require("modules/domain/names")
local paths = require("modules/domain/paths")
local fileAdapter = require("modules/adapters/files")
local storage = require("modules/application/storage")

local filePorts = {}
filePorts.exists = function(path) return fileExists(path) end
filePorts.rename = function(source, destination) return fileAdapter.rename(os, source, destination) end
filePorts.delete = function(path) return fileAdapter.delete(os, path) end
filePorts.entries = function(path, depth) return safeDirectoryEntries(path, depth) end
filePorts.read = function(path, maximumBytes) return readBoundedFile(path, maximumBytes) end
filePorts.atomicReplace = function(path, writer, description) return atomicReplace(path, writer, description) end
filePorts.writeBytes = function(path, contents) return fileAdapter.writeBytes(io, path, contents) end


function fileExists(path)
  return fileAdapter.fileExists(io, path)
end

function isFolderBundleFilename(filename)
  return paths.isFolderBundleFilename(filename)
end

function fileFingerprint(path, maximumBytes)
  return fileAdapter.fileFingerprint(io, path, maximumBytes, MAX_PRESET_BYTES, FILE_COPY_CHUNK_SIZE)
end

function cancelConfirmations()
  state.library.pendingOverwriteName = nil
  state.library.pendingOverwriteFingerprint = nil
  state.trash.pendingDeleteName = nil
  state.trash.pendingDeleteFingerprint = nil
  state.trash.nativePendingDeleteName = nil
  state.trash.nativePendingDeleteFingerprint = nil
  state.library.pendingRemoveFolder = nil
  state.trash.pendingEmpty = false
  state.trash.pendingBulkAction = nil
  state.trash.pendingBulkFingerprint = nil
  state.backup.pendingDeleteFile = nil
  state.backup.pendingDeleteFingerprint = nil
  state.history.pendingClear = false
end

function resetLoadState()
  stateModel.resetLoad(state.load, AUTO_LOAD_TIMING.passInterval)
end

function cloneMap(source)
  local copy = {}
  for key, value in pairs(source or {}) do copy[key] = value end
  return copy
end

function safeDirectoryEntries(path, depth)
  return fileAdapter.safeDirectoryEntries(dir, path, depth, MAX_TREE_DEPTH)
end

function directoryTreeContainsFiles(path, depth)
  return fileAdapter.directoryTreeContainsFiles(filePorts, path, depth)
end

function removeEmptyDirectoryTree(path, depth)
  return fileAdapter.removeEmptyDirectoryTree(filePorts, path, depth)
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
    local removed, removeError = deleteFile(LOG_ARCHIVE_DIR .. "/" .. oldest)
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
    or tostring(message):find("[editor diagnostic]", 1, true) == 1
  if technical and level ~= "error" then return end
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
  return names.sanitizeName(value)
end

function sanitizeMetadata(value, maximum)
  return names.sanitizeMetadata(value, maximum)
end

function validatedPresetName(value)
  return names.validatedPresetName(value)
end

writeFileSafely = function(path, mode, writerFn)
  return fileAdapter.writeFileSafely(io, path, mode, writerFn)
end

function atomicReplace(path, writeTemporary, description)
  return fileAdapter.run(storage.atomicReplace, log, filePorts, path, writeTemporary, description)
end

function readBoundedFile(path, maximumBytes)
  return fileAdapter.readBoundedFile(io, path, maximumBytes)
end

function copyFile(source, destination)
  local result, diagnostic = fileAdapter.copyFile(io, source, destination, FILE_COPY_CHUNK_SIZE)
  log(diagnostic.message, diagnostic.level)
  return result
end

function removeFileList(paths)
  return fileAdapter.removeFileList(filePorts, paths)
end

function renameFile(source, destination)
  return fileAdapter.rename(os, source, destination)
end

function deleteFile(path)
  return fileAdapter.delete(os, path)
end

return _ENV
