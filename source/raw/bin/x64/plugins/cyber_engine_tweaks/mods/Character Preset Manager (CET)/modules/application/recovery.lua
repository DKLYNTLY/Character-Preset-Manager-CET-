local journalCodec = require("modules/domain/journal_codec")

local function diagnostic(report, message, level)
  return report({message = message, level = level})
end

local function completeTransaction(files, operation, plans, transactionFile)
  if not files.writeTransaction("committed", operation, plans) then return false end
  return files.delete(transactionFile) ~= nil or not files.exists(transactionFile)
end

local function recoverTransaction(report, files, transaction, transactionError, settings)
  if not transaction then
    if transactionError ~= "missing" then
      diagnostic(report, "[RECOVERY] The saved action record is invalid. Preset scanning has stopped.", "error")
      return false, {}, {}, {}, {}
    end
    return true, {}, {}, {}, {}
  end
  if transaction.phase == "committed" then
    local removed = files.delete(settings.transactionFile) ~= nil or not files.exists(settings.transactionFile)
    diagnostic(report, removed and "[RECOVERY] Completed transaction journal cleanup."
      or "[RECOVERY] The action finished safely, but its saved record could not be removed. Cleanup will try again at the next startup.",
      removed and "info" or "warn")
    return true, {}, {}, {}, {}
  end
  local recoveredOriginals, recoveredAssignments, recovered = {}, {}, true
  for _, plan in ipairs(transaction.plans) do
    local rollbackSource, rollbackDestination, trashPath = journalCodec.rollbackPaths(
      plan, transaction.operation, settings.presetDirectory, settings.trashDirectory)
    if files.exists(rollbackSource) and not files.exists(rollbackDestination) then
      if not files.rename(rollbackSource, rollbackDestination) then recovered = false end
    elseif not files.exists(rollbackSource) and not files.exists(rollbackDestination) then
      recovered = false
    end
    if trashPath and files.exists(trashPath) then
      recoveredOriginals[plan.trashFilename] = { original = plan.name }
    end
    if transaction.operation == "trash" or transaction.operation == "rename" then
      recoveredAssignments[plan.storage] = plan.name
    end
  end
  if recovered then files.delete(settings.transactionFile) end
  diagnostic(report, "[RECOVERY] Unfinished " .. transaction.operation .. " transaction " ..
    (recovered and "was rolled back." or "could not be fully rolled back; it will be retried."),
    recovered and "warn" or "error")
  return recovered, recoveredOriginals, recoveredAssignments,
    transaction.recoveryFolders, transaction.recoveryManualFolders
end

return {completeTransaction = completeTransaction, recoverTransaction = recoverTransaction}
