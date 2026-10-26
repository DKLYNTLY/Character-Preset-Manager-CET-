local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
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

helpers.clearOptionCatalog = function()
  state.app.optionCatalog = nil
  state.app.optionChoiceBindings = nil
  state.app.optionsMemo = nil
end

helpers.bindOptionCatalog = function(options)
  local previous = state.app.optionCatalog or { entries = {}, builds = 0, hits = 0, queue = {}, cursor = 1 }
  local entries, occurrences = {}, {}
  local bindings = setmetatable({}, { __mode = "k" })
  for _, option in ipairs(options) do
    local label = optionKey(option)
    if label then
      local slot = optionSlot(option) or ""
      local group = tostring(#label) .. ":" .. label .. tostring(#slot) .. ":" .. slot
      occurrences[group] = (occurrences[group] or 0) + 1
      local key = group .. ":" .. tostring(occurrences[group])
      local entry = previous.entries[key]
      if not entry then
        entry = { label = label, slot = slot, fields = {}, checked = {}, missing = {}, epoch = 0 }
        local ok, link, controller = pcall(function()
          return NameToString(option.info.link), option.info.linkController
        end)
        entry.link = ok and tostring(link or "") or ""
        entry.linkController = ok and controller == true or false
        if entry.link == "None" then entry.link = "" end
        previous.queue[#previous.queue + 1] = { entry = entry, option = option, epoch = entry.epoch }
      end
      entries[key] = entry
      bindings[option] = { entry = entry,
        checked = state.app.optionCacheHooksReady and entry.checked or {},
        missing = state.app.optionCacheHooksReady and entry.missing or {} }
    end
  end
  if previous.cursor == 1 and previous.builds == 0 then
    local active, inactive = {}, {}
    for _, job in ipairs(previous.queue) do
      local queue = job.option.isEditable and job.option.isActive and active or inactive
      queue[#queue + 1] = job
    end
    for _, job in ipairs(inactive) do active[#active + 1] = job end
    previous.queue = active
  end
  previous.entries = entries
  state.app.optionCatalog = previous
  state.app.optionChoiceBindings = bindings
end

helpers.cachedOptionChoices = function(option, field, size)
  local binding = state.app.optionChoiceBindings and state.app.optionChoiceBindings[option]
  if not binding or size > OPTION_CHOICE_CACHE_LIMIT then return nil end
  local cached = binding.entry.fields[field]
  if binding.checked[field] and cached and cached.size == size then
    state.app.optionCatalog.hits = state.app.optionCatalog.hits + 1
    return cached
  end
  local values, indexes = {}, {}
  local same = cached and cached.size == size
  local member = field == "options" and "localizedName" or nil
  for index = 0, size - 1 do
    local value = choiceCollectionValue(option.info, field, index, member)
    values[index + 1] = value or false
    if not cached or cached.values[index + 1] ~= values[index + 1] then same = false end
  end
  if not same then
    for position, value in ipairs(values) do
      if value then
        if indexes[value] ~= nil then indexes[value] = false
        else indexes[value] = position - 1 end
      end
    end
    cached = { size = size, values = values, indexes = indexes }
    binding.entry.fields[field] = cached
    state.app.optionCatalog.builds = state.app.optionCatalog.builds + 1
  end
  binding.checked[field] = true
  return cached
end

helpers.isOffChoice = function(value)
  value = tostring(value or ""):lower()
  return value == "off" or value == "common-off" or value == "none" or value == "common-none"
end

helpers.optionProfile = function(option)
  local binding = state.app.optionChoiceBindings and state.app.optionChoiceBindings[option]
  return binding and binding.entry or nil
end

helpers.cleanupOptionTarget = function(option)
  local profile = helpers.optionProfile(option)
  if profile and profile.offIndex ~= nil then
    if profile.offIndex == 0 or helpers.isOffChoice(choiceCollectionValue(
        option.info, "options", profile.offIndex, "localizedName")) then return profile.offIndex end
    profile.offIndex = nil
    profile.fields.options = nil
  end
  local ok, size = pcall(function() return #(option.info.options or {}) end)
  local target = 0
  if ok and size <= OPTION_CHOICE_CACHE_LIMIT then
    local cached = helpers.cachedOptionChoices(option, "options", size)
    if cached then
      for position, value in ipairs(cached.values) do
        if helpers.isOffChoice(value) then target = position - 1; break end
      end
    else
      for index = 0, size - 1 do
        if helpers.isOffChoice(choiceCollectionValue(option.info, "options", index, "localizedName")) then
          target = index
          break
        end
      end
    end
  end
  if profile then profile.offIndex = target end
  return target
end

helpers.invalidateOptionCatalogEntry = function(option)
  local catalog = state.app.optionCatalog
  if not catalog or not option then return end
  local label, slot = optionKey(option), optionSlot(option) or ""
  for _, entry in pairs(catalog.entries) do
    if entry.label == label and entry.slot == slot then
      entry.fields = {}
      entry.checked = {}
      entry.missing = {}
      entry.offIndex = nil
      entry.epoch = entry.epoch + 1
      catalog.queue[#catalog.queue + 1] = { entry = entry, option = option, epoch = entry.epoch }
    end
  end
end

helpers.warmOptionCatalog = function()
  if not state.app.inCustomization or state.load.auto or state.load.needsContinue then return end
  if not state.app.optionCatalog then getOptions(); return end
  local catalog = state.app.optionCatalog
  local started = helpers.loadClock()
  local steps = 0
  while steps < 64 and helpers.loadClock() - started < 0.002 do
    local job = catalog.queue[catalog.cursor]
    if not job then
      catalog.queue = {}
      catalog.cursor = 1
      return
    end
    local entry = job.entry
    local field = ({ "options", "definitions", "morphNames" })[job.field or 1]
    if job.epoch ~= entry.epoch or not field then
      catalog.queue[catalog.cursor] = false
      catalog.cursor = catalog.cursor + 1
    elseif entry.fields[field] then
      job.values = nil
      job.field = (job.field or 1) + 1
    else
      if not job.values then
        local ok, size = pcall(function() return #(job.option.info[field] or {}) end)
        job.size = ok and tonumber(size) or 0
        job.values, job.indexes, job.effects = {}, {}, {}
        job.position = 0
      end
      if job.size > OPTION_CHOICE_CACHE_LIMIT then
        job.values = nil
        job.field = (job.field or 1) + 1
      elseif job.position >= job.size then
        entry.fields[field] = { size = job.size, values = job.values,
          indexes = job.indexes, effects = job.effects }
        entry.checked[field] = true
        catalog.builds = catalog.builds + 1
        job.values = nil
        job.field = (job.field or 1) + 1
      else
        local index = job.position
        local member = field == "options" and "localizedName" or nil
        local value = choiceCollectionValue(job.option.info, field, index, member)
        job.values[index + 1] = value or false
        if value then
          if job.indexes[value] ~= nil then job.indexes[value] = false
          else job.indexes[value] = index end
        end
        local ok, actions = pcall(function() return job.option.info[field][index + 1].actions end)
        if ok and type(actions) == "table" then
          local effects = {}
          for _, action in ipairs(actions) do
            effects[#effects + 1] = { kind = tostring(action.type), params = tostring(action.params),
              immediate = action.applyImmediately == true, slot = action.applyToUISlot == true }
          end
          job.effects[index + 1] = effects
        end
        job.position = index + 1
      end
    end
    steps = steps + 1
  end
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
  local field, wanted = tostring(choice or ""):match("^([%a]+):(.*)$")
  if not option or not option.info or wanted == ""
      or (field ~= "definitions" and field ~= "options" and field ~= "morphNames") then
    return nil
  end
  local member = field == "options" and "localizedName" or nil
  local sizeOk, size = pcall(function() return #(option.info[field] or {}) end)
  if not sizeOk or type(size) ~= "number" or size > MAX_OPTION_INDEX then return nil end
  local cached = helpers.cachedOptionChoices(option, field, size)
  if cached then
    local index = cached.indexes[wanted]
    if type(index) ~= "number" then
      local binding = state.app.optionChoiceBindings[option]
      binding.missing = binding.missing or {}
      if binding.missing[choice] then return nil end
      binding.missing[choice] = true
      binding.checked[field] = nil
      cached = helpers.cachedOptionChoices(option, field, size)
      index = cached.indexes[wanted]
      if type(index) ~= "number" then return nil end
    end
    if choiceCollectionValue(option.info, field, index, member) == wanted then return index end
    local binding = state.app.optionChoiceBindings[option]
    binding.checked[field] = nil
    cached = helpers.cachedOptionChoices(option, field, size)
    index = cached.indexes[wanted]
    return type(index) == "number" and index or nil
  end
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
  return "Custom/CCXL option (no display name)"
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

function occurrenceKeyParts(value)
  local raw = tostring(value or "")
  local key, occurrence = raw:match("^(.-)\31(%d+)$")
  return key or raw, tonumber(occurrence) or 1
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

return _ENV
