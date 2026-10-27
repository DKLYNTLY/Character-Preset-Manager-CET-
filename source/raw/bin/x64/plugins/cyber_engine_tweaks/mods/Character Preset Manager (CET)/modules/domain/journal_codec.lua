local paths = require("modules/domain/paths")
local codecs = require("modules/domain/codecs")
local validRelativePath = paths.validRelativePath
local validTrashFilename = paths.validTrashFilename
local catalogEncode = codecs.catalogEncode
local catalogDecode = codecs.catalogDecode

local function encode(phase, operation, plans, maximumLines)
  local lines = { "V\t1", "H\t" .. phase .. "\t" .. operation }
  for _, plan in ipairs(plans or {}) do
    if operation == "rename" then
      if not validRelativePath(plan.storage or "")
          or not validRelativePath(plan.destinationStorage or "")
          or not validRelativePath(plan.name or "") then return nil end
      table.insert(lines, "R\t" .. catalogEncode(plan.storage) .. "\t" ..
        catalogEncode(plan.destinationStorage) .. "\t" .. catalogEncode(plan.name))
    else
      if not validRelativePath(plan.storage or "")
          or not validTrashFilename(plan.trashFilename)
          or not validRelativePath(plan.recoveryName or plan.name or "") then return nil end
      table.insert(lines, "P\t" .. catalogEncode(plan.storage) .. "\t" ..
        catalogEncode(plan.trashFilename) .. "\t" ..
        catalogEncode(plan.recoveryName or plan.name))
    end
  end
  for folder in pairs((plans or {}).recoveryFolders or {}) do
    if not validRelativePath(folder) then return nil end
    table.insert(lines, "D\t" .. catalogEncode(folder) .. "\t" ..
      ((plans.recoveryManualFolders or {})[folder] and "1" or "0"))
  end
  if #lines > maximumLines then return nil end
  return lines
end

local function decodeLegacy(contents, maximumLines)
  local transaction = { plans = {}, recoveryFolders = {}, recoveryManualFolders = {} }
  local lineCount = 0
  for line in (contents .. "\n"):gmatch("(.-)\n") do
    if line ~= "" then
      lineCount = lineCount + 1
      if lineCount > maximumLines then return nil, "invalid" end
      local phase, operation = line:match("^H\t([^\t]+)\t([^\t]+)$")
      if phase then
        transaction.phase, transaction.operation = phase, operation
      else
        local storage, filename, name = line:match("^P\t([^\t]+)\t([^\t]+)\t([^\t]+)$")
        if storage then
          storage, filename, name = catalogDecode(storage), catalogDecode(filename), catalogDecode(name)
          if not validRelativePath(storage) or not validTrashFilename(filename)
              or not validRelativePath(name) then return nil, "invalid" end
          table.insert(transaction.plans, {
            storage = storage, trashFilename = filename, name = name,
          })
        else
          local oldStorage, newStorage, name = line:match("^R\t([^\t]+)\t([^\t]+)\t([^\t]+)$")
          if oldStorage then
            oldStorage, newStorage, name = catalogDecode(oldStorage),
              catalogDecode(newStorage), catalogDecode(name)
            if not validRelativePath(oldStorage) or not validRelativePath(newStorage)
                or not validRelativePath(name) then return nil, "invalid" end
            table.insert(transaction.plans, {
              storage = oldStorage, destinationStorage = newStorage, name = name,
            })
          else
            local folder, manual = line:match("^D\t([^\t]+)\t([01])$")
            if folder then
              folder = catalogDecode(folder)
              if not validRelativePath(folder) then return nil, "invalid" end
              transaction.recoveryFolders[folder] = true
              if manual == "1" then transaction.recoveryManualFolders[folder] = true end
            elseif line ~= "V\t1" then
              return nil, "invalid"
            end
          end
        end
      end
    end
  end
  if (transaction.phase ~= "prepared" and transaction.phase ~= "committed")
      or (transaction.operation ~= "trash" and transaction.operation ~= "restore"
        and transaction.operation ~= "rename")
      or #transaction.plans == 0 then return nil, "invalid" end
  return transaction
end

local PRESET_EXTENSION = ".preset"

local function rollbackPaths(plan, operation, presetDirectory, trashDirectory)
  local mainPath = presetDirectory .. "/" .. plan.storage .. PRESET_EXTENSION
  local trashPath = plan.trashFilename and (trashDirectory .. "/" .. plan.trashFilename) or nil
  local renamedPath = plan.destinationStorage
    and (presetDirectory .. "/" .. plan.destinationStorage .. PRESET_EXTENSION) or nil
  local source = operation == "trash" and trashPath
    or operation == "restore" and mainPath or renamedPath
  local destination = operation == "trash" and mainPath
    or operation == "restore" and trashPath or mainPath
  return source, destination, trashPath
end

return {encode = encode, decodeLegacy = decodeLegacy, rollbackPaths = rollbackPaths}
