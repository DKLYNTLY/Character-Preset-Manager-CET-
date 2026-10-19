local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

local function isAcuStorage(storage)
  storage = tostring(storage or ""):gsub("\\", "/")
  return storage:sub(1, 12):lower() == "acu presets/"
end

local function isNamedDangerousOption(key)
  key = tostring(key or "")
  if key:match("^LocKey#%d+$") then return false end
  local normalized = key:lower():gsub("[^a-z0-9]", "")
  return normalized:find("lockeyes", 1, true) ~= nil
    or normalized:find("lockeye", 1, true) ~= nil
    or normalized:find("eyelock", 1, true) ~= nil
    or normalized:find("eyeslock", 1, true) ~= nil
end

logAcuDangerousOptions = function(preset, options, presetName)
  if not preset or not preset.entries or not isAcuStorage(preset.storage) then return 0 end
  local safeKeys, blockedKeys = {}, {}
  for _, option in ipairs(options or {}) do
    local key = optionKey(option)
    if key then
      if option.isEditable and option.isActive then
        safeKeys[key] = true
      else
        local reasons = {}
        if not option.isEditable then reasons[#reasons + 1] = "not editable" end
        if not option.isActive then reasons[#reasons + 1] = "not active" end
        blockedKeys[key] = table.concat(reasons, " and ")
      end
    end
  end
  local acu = state.acuImport
  acu.dangerousLogged = acu.dangerousLogged or {}
  local fingerprint = tostring(preset.fingerprint or preset.storage or "")
  local found = 0
  for _, entry in ipairs(preset.entries) do
    local reason = nil
    if isNamedDangerousOption(entry.key) then
      reason = "internal eye-lock field"
    elseif not safeKeys[entry.key] then
      reason = blockedKeys[entry.key]
    end
    if reason then
      found = found + 1
      local identity = table.concat({ fingerprint, tostring(entry.key), reason }, "\31")
      if not acu.dangerousLogged[identity] then
        acu.dangerousLogged[identity] = true
        log(("[ACU SAFETY] Dangerous option found in imported preset '%s': option='%s' reason='%s'. The preset remains imported and unchanged; this warning does not change loading.")
          :format(tostring(presetName or preset.storage), tostring(entry.key), reason), "warn")
      end
    end
  end
  return found
end


return _ENV
