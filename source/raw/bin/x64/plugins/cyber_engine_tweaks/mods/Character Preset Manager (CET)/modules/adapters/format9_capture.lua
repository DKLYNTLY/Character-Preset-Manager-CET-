local codec = require("modules/domain/format9_codec")
local identities = require("modules/domain/identities")

local function capture(runtime, liveOptions)
  local function read(callback)
    local ok, value = pcall(callback)
    if ok then return value end
  end
  local function name(value)
    if value == nil then return nil end
    if type(value) ~= "string" then
      value = read(function() return runtime.NameToString(value) end)
    end
    if type(value) == "string" and value ~= "" and not identities.isRuntimePointerText(value)
        and #value <= 1024 and not value:find("%c") then return value end
  end
  local function choice(source, item)
    if source == "options" then
      local names = item.names
      if #names == 0 or #names > 512 then return nil end
      local result = {}
      for index = 1, #names do
        local member = name(names[index])
        if not member then return nil end
        result[index] = member
      end
      return result
    end
    local member = source == "definitions" and "name" or "morphName"
    local value = name(type(item) == "string" and item or item[member])
    return value and {value}
  end
  local function details(item, optionName, isAppearance)
    local result = {unavailable={}}
    local label = read(function() return item.localizedName end)
    if type(label) == "string" and #label <= 1024 and not label:find("%c") then
      result.localizedName = label
    else result.unavailable[#result.unavailable + 1] = "localized_name" end
    if not isAppearance then return result end
    local tags = read(function()
      local source, captured = item.tags.tags, {}
      if #source > 4096 then return nil end
      for index = 1, #source do
        local tag = name(source[index])
        if not tag then return nil end
        captured[index] = tag
      end
      return captured
    end)
    if tags then result.tags = tags
    else result.unavailable[#result.unavailable + 1] = "tags" end
    local function report(index, field, reason)
      if runtime.log then
        pcall(runtime.log, ("[FORMAT 9 CAPTURE] option=%s action=%d field=%s reason=%s")
          :format(optionName, index, field, reason), "warn")
      end
    end
    local actions = read(function()
      local source = read(function() return item.actions end)
      local count = read(function() return #source end)
      if not identities.optionIndexIsValid(count) or count > 4096 then
        report(0, "actions", "collection unavailable or too large")
        return nil
      end
      local captured = {}
      for index = 1, count do
        local action = read(function() return source[index] end)
        local values, valid = {}, true
        for _, field in ipairs({"type", "params", "applyImmediately", "applyToUISlot"}) do
          local ok, value = pcall(function() return action[field] end)
          local accepted = ok
          if field == "type" then
            local converted = read(function()
              if type(value) == "number" then return value end
              local names = {Activate=0, Deactivate=1, EquipItem=2, UnequipItem=3, Refresh=4}
              return names[value.value]
            end)
            accepted = accepted and identities.optionIndexIsValid(converted)
            values.kind = converted
          elseif field == "params" then
            accepted = accepted and type(value) == "string" and #value <= 1024 and not value:find("%c")
            values.params = value
          else
            accepted = accepted and type(value) == "boolean"
            values[field] = value
          end
          if not accepted then
            report(index, field, ok and ("unsupported " .. type(value)) or "field read failed")
            valid = false
          end
        end
        if not valid then return nil end
        captured[index] = {kind=values.kind, params=values.params,
          immediate=values.applyImmediately, uiSlot=values.applyToUISlot}
      end
      return captured
    end)
    if actions then result.actions = actions
    else result.unavailable[#result.unavailable + 1] = "actions" end
    return result
  end
  local sources = {{"definitions", "Appearance"}, {"morphNames", "Morph"}, {"options", "Switcher"}}
  local options = liveOptions or read(function()
    local system = runtime.Game.GetCharacterCustomizationSystem()
    local empty = runtime.ToCName({})
    return system:GetUnitedOptions(true, true, true, empty, empty, empty)
  end)
  if type(options) ~= "table" then return nil, "The character editor is not available." end
  local entries, keys = {}, {}
  for _, option in ipairs(options) do
    local info = read(function() return option.info end)
    local slot = read(function() return name(info.uiSlot) end)
    local internal = read(function() return name(info.name) end)
    slot = slot and #slot <= 256 and slot or nil
    internal = internal and #internal <= 256 and internal or nil
    local active = read(function() return option.isActive end)
    local editable = read(function() return option.isEditable end)
    local row = {slot=slot or "[unavailable]", name=internal or "[unavailable]", state="Not captured", reason="No supported unique choice identity."}
    local current = read(function() return option.currIndex end)
    if identities.optionIndexIsValid(current) then row.value = ("%.0f"):format(current) end
    row.active, row.editable = active, editable
    local key = row.slot .. "\n" .. row.name
    keys[key] = (keys[key] or 0) + 1
    row.occurrence = keys[key]
    if active == false then
      row.state, row.reason = "Inactive", "Inactive option. Choice was not captured."
    elseif editable == false then
      row.state, row.reason = "Not captured", "Option is not editable."
    elseif active == true and editable == true and slot and internal then
      if identities.optionIndexIsValid(current) then
        for _, source in ipairs(sources) do
          local entry = read(function()
            local collection = info[source[1]]
            local size = #collection
            if size > 4096 or current >= size then return nil end
            local selected = choice(source[1], collection[current + 1])
            if not selected then return nil end
            local matches = 0
            local fingerprint = table.concat(selected, "\n")
            for index = 1, size do
              local candidate = choice(source[1], collection[index])
              if not candidate then return nil end
              if table.concat(candidate, "\n") == fingerprint then matches = matches + 1 end
            end
            if matches ~= 1 then return nil end
            local selectedItem = collection[current + 1]
            local capturedDetails = details(selectedItem, internal, source[1] == "definitions")
            if source[1] ~= "definitions" then
              capturedDetails.tags, capturedDetails.actions = nil, nil
              local missing = {}
              if capturedDetails.localizedName == nil then missing[1] = "localized_name" end
              capturedDetails.unavailable = missing
            end
            local state = source[1] == "options" and capturedDetails.localizedName == "Common-Off"
              and "Off" or "Selected"
            return {slot=slot, name=internal, state=state, kind=source[2],
              choices=selected, details=capturedDetails}
          end)
          if entry then
            row.state, row.kind, row.choices = entry.state, entry.kind, entry.choices
            row.reason, row.details = nil, entry.details
            break
          end
        end
      end
    end
    entries[#entries + 1] = row
  end
  for _, entry in ipairs(entries) do
    if keys[entry.slot .. "\n" .. entry.name] > 1 and (entry.state == "Selected" or entry.state == "Off") then
      entry.state, entry.kind, entry.choices = "Not captured", nil, nil
      entry.reason, entry.details = "Duplicate option identity.", nil
    end
  end
  local missing = 0
  for _, entry in ipairs(entries) do
    if entry.state == "Not captured" then missing = missing + 1 end
  end
  local function gender(method)
    local value = read(function()
      local state = runtime.Game.GetCharacterCustomizationSystem():GetState()
      return state[method](state)
    end)
    if type(value) ~= "boolean" then return "Unknown" end
    return value and "Male" or "Female"
  end
  local encodeStarted=runtime.profile and runtime.clock()
  local text = codec.encode(entries, gender("IsBodyGenderMale"), gender("IsBrainGenderMale"))
  if runtime.profile then runtime.profile.add("historyEncode",math.max(0,runtime.clock()-encodeStarted)) end
  if not text then return nil, "No usable format 9 snapshot could be written." end
  return text, #entries, missing
end

return {capture=capture}
