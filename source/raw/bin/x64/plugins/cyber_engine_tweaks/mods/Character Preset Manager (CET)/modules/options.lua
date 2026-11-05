local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime
local stateModel = require("modules/domain/state")
local identities = require("modules/domain/identities")
local matching = require("modules/domain/matching")
local acuV2 = require("modules/domain/acu_v2")

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
  return matching.validSlot(slot, MAX_PRESET_KEY_BYTES)
end

function isRuntimePointerText(value)
  return identities.isRuntimePointerText(value)
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
  return identities.stableChoiceIdentity(choice)
end

local function collectionIdentity(collection, field, index, member)
  local ok, value = pcall(function()
    if collection == nil then return nil end
    local item = collection[index + 1]
    if item == nil then return nil end
    if member then return item[member] end
    local identityMember = field == "definitions" and "name"
      or field == "morphNames" and "morphName" or nil
    if identityMember and type(item) ~= "string" then return item[identityMember] end
    return item
  end)
  return ok and stableRuntimeValue(value) or nil
end

function choiceCollectionValue(info, field, index, member)
  local ok, collection = pcall(function() return info and info[field] end)
  if not ok then return nil end
  return collectionIdentity(collection, field, index, member)
end

helpers.optionChoiceKey = function(option, index)
  if not option or not option.info or not matching.choiceIndexValid(index, MAX_OPTION_INDEX) then return nil end
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

helpers.clearOptionCatalog = function()
  stateModel.clearOptionCatalog(state.app)
end

helpers.bindOptionCatalog = function(options)
  local previous = state.app.optionCatalog or { entries = {}, builds = 0, hits = 0 }
  local entries, occurrences = {}, {}
  local bindings = setmetatable({}, { __mode = "k" })
  for _, option in ipairs(options) do
    local label = optionKey(option)
    if label and option.isEditable and option.isActive then
      local slot = optionSlot(option) or ""
      local group = matching.catalogGroup(label, slot)
      occurrences[group] = (occurrences[group] or 0) + 1
      local key = group .. ":" .. tostring(occurrences[group])
      local entry = previous.entries[key] or { label = label, slot = slot, fields = {} }
      entries[key] = entry
      bindings[option] = { entry = entry, checked = {} }
    end
  end
  previous.entries = entries
  state.app.optionCatalog = previous
  state.app.optionChoiceBindings = bindings
end

helpers.cachedOptionChoices = function(option, field, size, collection)
  local binding = state.app.optionChoiceBindings and state.app.optionChoiceBindings[option]
  if not binding or size > OPTION_CHOICE_CACHE_LIMIT then return nil end
  local cached = binding.entry.fields[field]
  if binding.checked[field] and cached and cached.size == size then
    state.app.optionCatalog.hits = state.app.optionCatalog.hits + 1
    return cached
  end
  if not collection then
    local ok, source = pcall(function() return option.info[field] end)
    if not ok or not source then return nil end
    collection = source
  end
  local values, indexes = {}, {}
  local same = cached and cached.size == size
  local member = field == "options" and "localizedName" or nil
  for index = 0, size - 1 do
    local value = collectionIdentity(collection, field, index, member)
    values[index + 1] = value or false
    if not cached or cached.values[index + 1] ~= values[index + 1] then same = false end
  end
  if not same then
    matching.choiceIndexes(values, indexes)
    cached = { size = size, values = values, indexes = indexes }
    binding.entry.fields[field] = cached
    state.app.optionCatalog.builds = state.app.optionCatalog.builds + 1
  end
  binding.checked[field] = true
  return cached
end

helpers.refreshOptionCatalog = function()
  if state.load.auto or state.load.needsContinue or state.load.pendingChange then
    setStatus("load", "Wait for loading to finish before refreshing options.")
    return false
  end
  helpers.clearOptionCatalog()
  local _, options = getOptions(true)
  if not options then
    setStatus("load", "Open a character editor before refreshing options.", true)
    return false
  end
  local count = 0
  for _ in pairs(state.app.optionCatalog.entries) do count = count + 1 end
  state.invalidatePreflight()
  setStatus("load", ("Refreshed %d editor options. Saved choices will be checked when you load or compare a preset."):format(count))
  return true
end

function optionChoiceIndex(option, choice)
  choice = stableChoiceIdentity(choice)
  local field, wanted = matching.choiceParts(choice)
  if not option or not option.info or wanted == ""
      or not matching.choiceSource(field) then
    return nil
  end
  local member = field == "options" and "localizedName" or nil
  local sizeOk, size, collection = pcall(function()
    local source = option.info[field] or {}
    return #source, source
  end)
  if not sizeOk or type(size) ~= "number" or size > MAX_OPTION_INDEX then return nil end
  local cached = helpers.cachedOptionChoices(option, field, size, collection)
  if cached then
    local index = cached.indexes[wanted]
    if type(index) ~= "number" then return nil end
    if choiceCollectionValue(option.info, field, index, member) == wanted then return index end
    local binding = state.app.optionChoiceBindings[option]
    binding.checked[field] = nil
    cached = helpers.cachedOptionChoices(option, field, size)
    index = cached and cached.indexes[wanted]
    return matching.numericChoiceIndex(index)
  end
  local match = nil
  for index = 0, size - 1 do
    local value = collectionIdentity(collection, field, index, member)
    if value == wanted then
      local duplicate
      match, duplicate = matching.matchChoice(match, index, value, wanted)
      if duplicate then return nil end
    end
  end
  return match
end

function optionChoiceMatchesIndex(option, choice, index)
  choice = stableChoiceIdentity(choice)
  local field, wanted = matching.choiceParts(choice)
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
  return "Custom/CCXL option (no display name)"
end

function optionAuditIdentity(option, key, occurrence)
  return ("%s | LocKey=%s | occurrence=%s")
    :format(helpers.optionDisplayName(option, key), tostring(key or "unknown"),
      tostring(occurrence or 1))
end

function optionIndexValidationError(index)
  return identities.optionIndexValidationError(index)
end

function optionIndexIsValid(index)
  return identities.optionIndexIsValid(index)
end

assert(optionIndexIsValid(0)
  and optionIndexIsValid(65535)
  and optionIndexIsValid(65536)
  and optionIndexIsValid(4294967295)
  and not optionIndexIsValid(-1)
  and not optionIndexIsValid(4294967296),
  MOD_NAME .. " option-index validation contract failed")

function occurrenceKeyParts(value)
  return identities.occurrenceKeyParts(value)
end

function refreshCustomizationUi()
  local menu = state.editor.activeBodyMorphMenu
  if not menu then
    log("Editor controls were not refreshed because no characterCreationBodyMorphMenu screen is open", "warn")
    return false
  end
  local ok, refreshError = pcall(function()
    menu:InitializeList()
  end)
  if not ok then
    log("UI refresh failed: " .. tostring(refreshError), "error")
    return false
  end
  log("[UI] Refreshed the editor's visible controls using the loaded preset values.", "info")
  return true
end

function getOptions(forceRefresh)
  if not forceRefresh and state.app.optionsMemo then
    local memo = state.app.optionsMemo
    return memo.system, memo.options, memo.error
  end
  local systemOk, system = pcall(Game.GetCharacterCustomizationSystem)
  if not systemOk or not system then
    local message = "The character editor is not available"
    helpers.clearOptionCatalog()
    state.app.optionsMemo = { error = message }
    return nil, nil, message
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
    local message = "Character options have not loaded yet"
    helpers.clearOptionCatalog()
    state.app.optionsMemo = { error = message }
    return nil, nil, message
  end
  helpers.bindOptionCatalog(options)
  state.app.optionsMemo = { system = system, options = options }
  return system, options
end



helpers.acuCandidates = function(options)
  local live, occurrences = {}, {}
  for position, option in ipairs(options or {}) do
    if option and option.isEditable and option.isActive then
      local label = optionKey(option)
      local nameOk, internalName = pcall(function() return stableRuntimeValue(option.info.name) end)
      internalName = nameOk and matching.validSlot(internalName, MAX_PRESET_KEY_BYTES) or nil
      if label and internalName then
        occurrences[label] = (occurrences[label] or 0) + 1
        live[#live + 1] = {option=option,label=label,internalName=internalName,position=position,
          occurrence=occurrences[label],key=matching.occurrenceKey(label, occurrences[label]),
          slot=optionSlot(option)}
      end
    end
  end
  return live
end

helpers.resolveAcuPreset = function(preset, options)
  return acuV2.resolve(preset.entries, helpers.acuCandidates(options), helpers.resolveAcuChoice)
end

helpers.resolveAcuChoice = function(option, choice)
  local field, wanted = matching.choiceParts(choice)
  local sourceField = field == "switcher" and "options" or field
  if sourceField ~= "options" and sourceField ~= "definitions" and sourceField ~= "morphNames" then return nil end
  local sourceOk, collection = pcall(function() return option.info[sourceField] end)
  if not sourceOk or collection == nil then return nil end
  local sizeOk, size = pcall(function() return #collection end)
  if not sizeOk or not identities.optionIndexIsValid(size) then return nil end
  if field == "switcher" then
    local found
    for index = 0, size - 1 do
      local namesOk, identity = pcall(function()
        local source = collection[index + 1].names
        local count = #source
        if not identities.optionIndexIsValid(count) or count > 1024 then return nil end
        local names = {}
        for position = 1, count do
          local name = stableRuntimeValue(source[position])
          if not name then return nil end
          names[position] = name
        end
        return acuV2.switcherIdentity(names)
      end)
      if namesOk and identity == choice then
        if found ~= nil then return nil end
        found = index
      end
    end
    return found
  end
  local found
  local member = field == "definitions" and "name" or field == "morphNames" and "morphName" or "localizedName"
  for index = 0, size - 1 do
    local valueOk, value = pcall(function()
      local item = collection[index + 1]
      return type(item) == "string" and item or item[member]
    end)
    if valueOk and stableRuntimeValue(value) == wanted then
      if found ~= nil then return nil end
      found = index
    end
  end
  return found
end

return _ENV
