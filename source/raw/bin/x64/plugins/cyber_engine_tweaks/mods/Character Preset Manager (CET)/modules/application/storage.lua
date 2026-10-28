local TEMPORARY_SUFFIX = ".tmp"
local BACKUP_SUFFIX = ".bak"

local function diagnostic(report, message, level)
  return report({message = message, level = level})
end

local function atomicReplace(report, files, path, writeTemporary, description)
  local temporary = path .. TEMPORARY_SUFFIX
  local backup = path .. BACKUP_SUFFIX

  if not files.exists(path) and files.exists(backup) then
    local recovered, recoverError = files.rename(backup, path)
    diagnostic(report, ("[FILES] Recovery attempted: backup='%s' target='%s' success=%s error=%s")
      :format(backup, path, tostring(recovered ~= nil), tostring(recoverError)),
      recovered and "info" or "error")
    if not recovered then return false end
  end
  files.delete(temporary)
  if not writeTemporary(temporary) then
    files.delete(temporary)
    diagnostic(report, ("[FILES] Could not write temporary %s '%s'."):format(description, temporary), "error")
    return false
  end
  if files.rename(temporary, path) then
    files.delete(backup)
    return true
  end

  files.delete(backup)
  local movedOriginal = files.rename(path, backup)
  if not movedOriginal then
    files.delete(temporary)
    return false
  end
  if not files.rename(temporary, path) then
    local restored, restoreError = files.rename(backup, path)
    if restored then
      files.delete(temporary)
    else
      diagnostic(report, ("[FILES] Could not restore backup after replacing %s: backup='%s' target='%s' temporary='%s' error=%s")
        :format(description, backup, path, temporary, tostring(restoreError)), "error")
    end
    return false
  end
  files.delete(backup)
  return true
end

local function writeLinesIfChanged(files, path, lines, description, maximumBytes)
  local contents = #lines > 0 and (table.concat(lines, "\n") .. "\n") or ""
  if #contents > maximumBytes then return false, false end
  local existing = files.read(path, maximumBytes)
  if existing == contents then return true, false end
  local result = files.atomicReplace(path, function(temporary)
    return files.writeBytes(temporary, contents)
  end, description)
  return result, result
end

return {atomicReplace = atomicReplace, writeLinesIfChanged = writeLinesIfChanged,
  TEMPORARY_SUFFIX = TEMPORARY_SUFFIX, BACKUP_SUFFIX = BACKUP_SUFFIX}
