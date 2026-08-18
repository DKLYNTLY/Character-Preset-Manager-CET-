local runtime = require("modules.runtime") or CPMRuntime
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

function optionKey(option)
  if not option or not option.info then return nil end
  local ok, key = pcall(LocKeyToString, option.info.name)
  if not ok or not key or key == "" then return nil end
  return tostring(key)
end

function optionSlot(option)
  if not option or not option.info then return nil end
  local ok, slot = pcall(function()
    local value = option.info.uiSlot
    if value == nil then return nil end
    if NameToString then return NameToString(value) end
    return tostring(value)
  end)
  slot = ok and tostring(slot or "") or ""
  if slot == "" or #slot > MAX_PRESET_KEY_BYTES or slot:find("%c") then return nil end
  return slot
end

function isRuntimePointerText(value)
  value = tostring(value or "")
  return value:match("^userdata: 0x%x+$") ~= nil
    or value:match("^table: 0x%x+$") ~= nil
    or value:match("^function: 0x%x+$") ~= nil
    or value:match("^thread: 0x%x+$") ~= nil
end

function stableRuntimeValue(value)
  if value == nil then return nil end
  if type(value) == "string" then
    if value == "" or isRuntimePointerText(value) then
      return nil
    end
    return value
  end
  local nameOk, name = pcall(function()
    if NameToString then return NameToString(value) end
    return nil
  end)
  local nameText = nameOk and name and tostring(name) or ""
  if nameText ~= "" and not isRuntimePointerText(nameText) then return nameText end
  local textOk, text = pcall(tostring, value)
  text = textOk and tostring(text or "") or ""
  if isRuntimePointerText(text) then return nil end
  return text ~= "" and text or nil
end

function stableChoiceIdentity(choice)
  local field, value = tostring(choice or ""):match("^([%a]+):(.*)$")
  if value == "" or (field ~= "definitions" and field ~= "options"
      and field ~= "morphNames") then return nil end
  if isRuntimePointerText(value) then return nil end
  return field .. ":" .. value
end

function choiceCollectionValue(info, field, index, member)
  local ok, value = pcall(function()
    local collection = info and info[field]
    if collection == nil then return nil end
    local item = collection[index + 1]
    if item == nil then return nil end
    return member and item[member] or item
  end)
  return ok and stableRuntimeValue(value) or nil
end

helpers.optionChoiceKey = function(option, index)
  if not option or not option.info or type(index) ~= "number"
      or index ~= math.floor(index) or index < 0 or index > MAX_OPTION_INDEX then return nil end
  for _, source in ipairs({
    { "definitions", nil },
    { "options", "localizedName" },
    { "morphNames", nil },
  }) do
    local value = choiceCollectionValue(option.info, source[1], index, source[2])
    if value then return source[1] .. ":" .. value end
  end
  return nil
end

function optionChoiceIndex(option, choice)
  choice = stableChoiceIdentity(choice)
  local field, wanted = tostring(choice or ""):match("^([%a]+):(.*)$")
  if not option or not option.info or wanted == ""
      or (field ~= "definitions" and field ~= "options" and field ~= "morphNames") then
    return nil
  end
  local member = field == "options" and "localizedName" or nil
  local sizeOk, size = pcall(function() return #(option.info[field] or {}) end)
  if not sizeOk or type(size) ~= "number" or size > MAX_OPTION_INDEX then return nil end
  local match = nil
  for index = 0, size - 1 do
    if choiceCollectionValue(option.info, field, index, member) == wanted then
      if match ~= nil then return nil end
      match = index
    end
  end
  return match
end

function optionChoiceMatchesIndex(option, choice, index)
  choice = stableChoiceIdentity(choice)
  local field, wanted = tostring(choice or ""):match("^([%a]+):(.*)$")
  index = tonumber(index)
  if not option or not option.info or wanted == "" or not index
      or index ~= math.floor(index) or index < 0 or index > MAX_OPTION_INDEX then
    return false
  end
  local member = field == "options" and "localizedName" or nil
  return choiceCollectionValue(option.info, field, index, member) == wanted
end

helpers.optionDisplayName = function(option, key)
  local candidates = {}
  if option and option.info then
    table.insert(candidates, option.info.name)
    local localizedNameOk, localizedName = pcall(function()
      return option.info.localizedName
    end)
    if localizedNameOk and localizedName then table.insert(candidates, localizedName) end
  end
  if key and key ~= "" then
    local nameOk, cname = pcall(ToCName, { tostring(key) })
    if nameOk then table.insert(candidates, cname) end
  end

  for _, candidate in ipairs(candidates) do
    local ok, value = pcall(function()
      if Game and Game.GetLocalizedTextByKey then
        return Game.GetLocalizedTextByKey(candidate)
      end
      if GetLocalizedTextByKey then return GetLocalizedTextByKey(candidate) end
      return nil
    end)
    value = ok and tostring(value or "") or ""
    if value ~= "" and value ~= tostring(key or "") and not value:find("LocKey", 1, true) then
      return value
    end
  end
  return "Custom/CCXL option (no localization provided)"
end

function optionAuditIdentity(option, key, occurrence)
  return ("%s | LocKey=%s | occurrence=%s")
    :format(helpers.optionDisplayName(option, key), tostring(key or "unknown"),
      tostring(occurrence or 1))
end

function optionIndexValidationError(index)
  if type(index) ~= "number" then return "not numeric" end
  if index ~= math.floor(index) then return "not an integer" end
  if index < 0 then return "below zero" end
  if index > MAX_OPTION_INDEX then return "above the native Uint32 maximum" end
  return nil
end

function optionIndexIsValid(index)
  return optionIndexValidationError(index) == nil
end

assert(optionIndexIsValid(0)
  and optionIndexIsValid(65535)
  and optionIndexIsValid(65536)
  and optionIndexIsValid(4294967295)
  and not optionIndexIsValid(-1)
  and not optionIndexIsValid(4294967296),
  MOD_NAME .. " option-index validation contract failed")

helpers.ignoreDiscoveryNotice = function()
  state.discoveryNoticeIgnored = true
  state.discoveryNoticePending = false
  state.discoveryNoticeLayout = nil
  local saved = writeConfig and writeConfig()
  log(saved and "[UI] Discovery reminder disabled by the user."
    or "[UI] Discovery reminder disabled for this session; config could not be saved.",
    saved and "info" or "warn")
  return saved == true
end

helpers.restoreDiscoveryNotice = function()
  state.discoveryNoticeIgnored = false
  state.discoveryNoticeLayout = nil
  local saved = writeConfig and writeConfig()
  log(saved and "[UI] Discovery reminder restored by the user."
    or "[UI] Discovery reminder restored for this session; config could not be saved.",
    saved and "info" or "warn")
  return saved == true
end

function occurrenceKeyParts(value)
  local raw = tostring(value or "")
  local key, occurrence = raw:match("^(.-)\31(%d+)$")
  return key or raw, tonumber(occurrence) or 1
end

function refreshCustomizationUi()
  local menu = state.activeBodyMorphMenu
  if not menu then
    log("UI refresh skipped: no active characterCreationBodyMorphMenu controller", "warn")
    return false
  end
  local ok, refreshError = pcall(function()
    menu:InitializeList()
  end)
  if not ok then
    log("UI refresh failed: " .. tostring(refreshError), "error")
    return false
  end
  log("[UI] Rebuilt the visible customization list from applied preset values.", "info")
  return true
end

function getOptions()
  local systemOk, system = pcall(Game.GetCharacterCustomizationSystem)
  if not systemOk or not system then
    return nil, nil, "Character customization system is unavailable"
  end
  local ok, options = pcall(function()
    if not emptyCustomizationName then emptyCustomizationName = ToCName({}) end
    return system:GetUnitedOptions(
      true,
      true,
      true,
      emptyCustomizationName,
      emptyCustomizationName,
      emptyCustomizationName
    )
  end)
  if not ok or type(options) ~= "table" or next(options) == nil then
    return nil, nil, "Customization options haven't loaded yet"
  end
  return system, options
end

return _ENV
