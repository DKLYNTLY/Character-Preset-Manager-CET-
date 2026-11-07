local HEADER = "# CPM Preset\n# Format: 9\n"
local MAX_BYTES = 1048576
local MAX_ENTRIES = 4096

local function validText(value, limit)
  return type(value) == "string" and #value > 0 and #value <= limit
    and not value:find("%c")
end

local function encode(entries, body, voice)
  if body ~= nil and body ~= "Male" and body ~= "Female" and body ~= "Unknown" then return nil end
  if #entries == 0 or #entries > MAX_ENTRIES then return nil end
  local lines = { HEADER:sub(1, -2) }
  if body then lines[#lines + 1] = "# Source body: " .. body end
  if voice ~= nil then
    if voice ~= "Male" and voice ~= "Female" and voice ~= "Unknown" then return nil end
    lines[#lines + 1] = "# Source voice: " .. voice
  end
  local headerCount = #lines
  local seen = {}
  for _, entry in ipairs(entries) do
    if not validText(entry.slot, 256) or not validText(entry.name, 256) then return nil end
    local occurrence = entry.occurrence
    if occurrence ~= nil and (type(occurrence) ~= "number" or occurrence < 1
        or occurrence > MAX_ENTRIES or occurrence ~= math.floor(occurrence)) then return nil end
    local key = entry.slot .. "\n" .. entry.name .. "\n" .. tostring(occurrence or 1)
    if seen[key] then return nil end
    seen[key] = true
    local state = entry.state
    if state ~= "Selected" and state ~= "Off" then
      if state ~= "Inactive" and state ~= "Not captured"
          and state ~= "Unverified" and state ~= "Read only" then return nil end
      if entry.kind or entry.choices or entry.details then return nil end
      local reason, editable = entry.reason or "", entry.editable
      if reason ~= "" and not validText(reason, 1024) then return nil end
      if editable ~= nil and type(editable) ~= "boolean" then return nil end
      local active = entry.active
      if active ~= nil and type(active) ~= "boolean" then return nil end
      local value, sourceKind = entry.value or "", entry.sourceKind or ""
      if value ~= "" and (type(value) ~= "string" or not value:match("^%d+$")
          or #value > 10 or tonumber(value) > 4294967295) then return nil end
      if sourceKind ~= "" and not validText(sourceKind, 256) then return nil end
      lines[#lines + 1] = table.concat({"Roster", entry.slot, entry.name, occurrence or "",
        state, active == nil and "" or tostring(active), value, sourceKind, editable == nil and "" or tostring(editable), reason}, "\t")
    else
      lines[#lines + 1] = "Editor slot: " .. entry.slot
      lines[#lines + 1] = "Option name: " .. entry.name
      if occurrence then lines[#lines + 1] = "Option occurrence: " .. occurrence end
      lines[#lines + 1] = "Selection state: " .. state
      local kind, choices = entry.kind, entry.choices
      if kind ~= "Appearance" and kind ~= "Morph" and kind ~= "Switcher" and kind ~= "Legacy label" and kind ~= "Legacy index" then return nil end
      if type(choices) ~= "table" or #choices == 0
          or (kind ~= "Switcher" and #choices ~= 1) then return nil end
      lines[#lines + 1] = "Identity kind: " .. kind
      local bytes = 0
      for _, choice in ipairs(choices) do
        if not validText(choice, 1024) then return nil end
        bytes = bytes + #choice + 1
        if bytes > 1025 then return nil end
        lines[#lines + 1] = "Choice identity: " .. choice
      end
      for _, field in ipairs({"active", "editable", "value"}) do
        local value = entry[field]
        if value ~= nil then
          if field == "value" then
            if type(value) ~= "string" or not value:match("^%d+$") or #value > 10
                or tonumber(value) > 4294967295 then return nil end
          elseif type(value) ~= "boolean" then return nil end
          lines[#lines + 1] = "Source " .. field .. ": " .. tostring(value)
        end
      end
      for _, field in ipairs({"legacyKey", "legacyChoice"}) do
        local value = entry[field]
        if value then
          if not validText(value, field == "legacyKey" and 256 or 1024) then return nil end
          lines[#lines + 1] = (field == "legacyKey" and "Option label: " or "Legacy choice: ") .. value
        end
      end
      local details = entry.details
      if details then
        if type(details) ~= "table" then return nil end
        if details.localizedName ~= nil then
          local label = details.localizedName
          if label ~= "" and not validText(label, 1024) then return nil end
          lines[#lines + 1] = "Localized name: " .. label
        end
        for _, field in ipairs(details.unavailable or {}) do
          if not validText(field, 256) then return nil end
          lines[#lines + 1] = "Detail unavailable: " .. field
        end
        for _, tag in ipairs(details.tags or {}) do
          if not validText(tag, 1024) then return nil end
          lines[#lines + 1] = "Appearance tag: " .. tag
        end
        for _, action in ipairs(details.actions or {}) do
          if type(action.kind) ~= "number" or action.kind < 0 or action.kind > 4294967295
              or action.kind ~= math.floor(action.kind)
              or (action.params ~= "" and not validText(action.params, 1024))
              or type(action.immediate) ~= "boolean" or type(action.uiSlot) ~= "boolean" then return nil end
          lines[#lines + 1] = table.concat({"Action", action.kind, tostring(action.immediate),
            tostring(action.uiSlot), action.params}, "\t")
        end
      end
      lines[#lines + 1] = ""
    end
  end
  for index = headerCount + 1, #lines do
    if lines[index] ~= "" then lines[index] = "# " .. lines[index] end
  end
  local text = table.concat(lines, "\n") .. "\n"
  if #text > MAX_BYTES then return nil end
  return text
end

local function decode(text)
  if type(text) ~= "string" or #text > MAX_BYTES or text:sub(-1) ~= "\n" then return nil end
  text = text:gsub("\r\n", "\n")
  if text:sub(1, #HEADER) ~= HEADER then return nil end
  local entries, entry, body, voice = {}, {}, nil, nil
  for line in text:sub(#HEADER + 1):gmatch("([^\n]*)\n") do
    local bodyLine = (line:sub(1, 15) == "# Source body: " or line:sub(1, 16) == "# Source voice: ")
    if not bodyLine and line ~= "" then
      if line:sub(1, 2) ~= "# " then return nil end
      line = line:sub(3)
    end
    local field, value = line:match("^([%a ]+): (.*)$")
    if bodyLine then
      if line:sub(1, 15) == "# Source body: " and not body then body = line:sub(16)
      elseif line:sub(1, 16) == "# Source voice: " and not voice then voice = line:sub(17)
      else return nil end
    elseif line:sub(1, 7) == "Roster\t" then
      local slot, name, occurrence, state, active, value, sourceKind, editable, reason =
        line:match("^Roster\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)$")
      if not slot or next(entry) or (active ~= "" and active ~= "true" and active ~= "false") then return nil end
      local row = {slot=slot, name=name, occurrence=tonumber(occurrence), state=state,
        value=value ~= "" and value or nil, sourceKind=sourceKind ~= "" and sourceKind or nil}
      if editable ~= "" and editable ~= "true" and editable ~= "false" then return nil end
      if editable ~= "" then row.editable = editable == "true" end
      row.reason = reason ~= "" and reason or nil
      if active ~= "" then row.active = active == "true" end
      entries[#entries + 1] = row
      if #entries > MAX_ENTRIES then return nil end
    elseif line:sub(1, 7) == "Action\t" then
      local kind, immediate, uiSlot, params = line:match("^Action\t(%d+)\t(%a+)\t(%a+)\t(.*)$")
      if not kind or (immediate ~= "true" and immediate ~= "false")
          or (uiSlot ~= "true" and uiSlot ~= "false") then return nil end
      entry.details = entry.details or {}
      entry.details.actions = entry.details.actions or {}
      entry.details.actions[#entry.details.actions + 1] = {kind=tonumber(kind),
        immediate=immediate == "true", uiSlot=uiSlot == "true", params=params}
    elseif field == "Option label" then
      entry.legacyKey = value
    elseif field == "Legacy choice" then
      entry.legacyChoice = value
    elseif field == "Source active" or field == "Source editable" then
      if value ~= "true" and value ~= "false" then return nil end
      entry[field:sub(8)] = value == "true"
    elseif field == "Source value" then
      entry.value = value
    elseif field == "Detail unavailable" then
      entry.details = entry.details or {}
      entry.details.unavailable = entry.details.unavailable or {}
      entry.details.unavailable[#entry.details.unavailable + 1] = value
    elseif field == "Localized name" then
      entry.details = entry.details or {}
      entry.details.localizedName = value
    elseif field == "Appearance tag" then
      entry.details = entry.details or {}
      entry.details.tags = entry.details.tags or {}
      entry.details.tags[#entry.details.tags + 1] = value
    elseif field == "Editor slot" and not entry.slot then
      entry.slot = value
    elseif field == "Option name" and not entry.name then
      entry.name = value
    elseif field == "Option occurrence" and not entry.occurrence and value:match("^%d+$") then
      entry.occurrence = tonumber(value)
    elseif field == "Selection state" and not entry.state then
      entry.state = value
    elseif field == "Identity kind" and not entry.kind then
      entry.kind = value
    elseif field == "Choice identity" then
      entry.choices = entry.choices or {}
      entry.choices[#entry.choices + 1] = value
    elseif line == "" then
      entries[#entries + 1] = entry
      entry = {}
      if #entries > MAX_ENTRIES then return nil end
    else
      return nil
    end
  end
  if encode(entries, body, voice) ~= text then return nil end
  return entries, body, voice
end

return { encode = encode, decode = decode }
