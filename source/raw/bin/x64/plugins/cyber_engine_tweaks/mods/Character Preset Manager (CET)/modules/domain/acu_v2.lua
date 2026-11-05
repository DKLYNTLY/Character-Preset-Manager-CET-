local json = require("modules/domain/json")
local identities = require("modules/domain/identities")
local limits = require("modules/domain/preset_codec")

local function text(value, maximum, empty)
  return type(value) == "string" and #value <= maximum
    and (empty or value ~= "") and not value:find("%c")
end

local function array(value)
  if type(value) ~= "table" then return false end
  local count = 0
  for key in pairs(value) do
    if type(key) ~= "number" or key < 1 or key ~= math.floor(key) then return false end
    count = count + 1
  end
  return count == #value
end

local function appearance(value)
  if type(value) ~= "table" or value.kind ~= "appearance"
      or not text(value.name, 1024) then return false end
  local details = value.details
  if type(details) ~= "table" or not text(details.localized_name, 1024, true)
      or not array(details.tags) or not array(details.actions) then return false end
  for _, tag in ipairs(details.tags) do if not text(tag, 1024) then return false end end
  for _, action in ipairs(details.actions) do
    if type(action) ~= "table" or not identities.optionIndexIsValid(action.kind)
        or not text(action.params, 1024, true)
        or type(action.apply_immediately) ~= "boolean"
        or type(action.apply_to_ui_slot) ~= "boolean" then return false end
  end
  return true
end

local function selection(value, index)
  if type(value) ~= "table" or not text(value.kind, 256) then return false end
  if value.kind == "appearance" then return appearance(value) end
  if value.kind == "morph" then
    return text(value.localized_name, 1024, true) and text(value.morph_name, 1024)
  end
  if value.kind == "switcher" then
    if not text(value.localized_name, 1024, true) or not array(value.names) then return false end
    for _, name in ipairs(value.names) do if not text(name, 1024) then return false end end
  elseif value.kind == "indexed_appearance" then
    if not identities.optionIndexIsValid(value.index) or value.index ~= index
        or not array(value.catalog) or value.index >= #value.catalog then return false end
    for _, item in ipairs(value.catalog) do if not appearance(item) then return false end end
  end
  return true
end

local function envelope(contents)
  local start = contents:find("%S")
  if not start then return nil end
  local finish = contents:find("\n", start, true)
  local header = contents:sub(start, finish and finish - 1 or #contents):gsub("\r$", "")
  if header ~= "// ACU-PRESET" and not header:match("^// ACU%-PRESET%s") then return nil end
  return finish and contents:sub(finish + 1) or "", header
end

local function strictBody(body)
  local chunks, position, start = {}, 1, 1
  while position <= #body do
    local character = body:sub(position, position)
    if character == '"' then
      position = position + 1
      while position <= #body do
        local value = body:sub(position, position)
        if value == "\\" then position = position + 2
        elseif value == '"' then position = position + 1; break
        else position = position + 1 end
      end
    elseif body:sub(position, position + 3) == "null" then
      chunks[#chunks + 1] = body:sub(start, position - 1)
      chunks[#chunks + 1] = '{"__acu_null__":true}'
      position = position + 4
      start = position
    elseif character:match("[%d%-]") then
      local token = body:sub(position):match("^[^%s,%]%}]+")
      local mantissa, exponent = token:match("^(.-)[eE](.*)$")
      mantissa = mantissa or token
      if exponent and not exponent:match("^[%+%-]?%d+$") then return nil end
      if not mantissa:match("^%-?%d+$") and not mantissa:match("^%-?%d+%.%d+$") then return nil end
      if mantissa:match("^%-?0%d") then return nil end
      position = position + #token
    else
      if character:match("%s") and not character:match("[ \t\r\n]") then return nil end
      position = position + 1
    end
  end
  chunks[#chunks + 1] = body:sub(start)
  return table.concat(chunks)
end

local function decode(body, header, metadataOnly, encodeCodepoint)
  if not body:match("^%s*{") then return nil, "The ACU preset body is not a JSON object." end
  body = strictBody(body)
  if not body then return nil, "The ACU preset JSON contains an invalid value." end
  local lossy = false
  local decoded = json.decode(body, function(codepoint)
    if codepoint >= 0xD800 and codepoint <= 0xDFFF or codepoint > 0x10FFFF then
      lossy = true
      return false, nil
    end
    local ok, encoded = encodeCodepoint(codepoint)
    if not ok then lossy = true end
    return ok, encoded
  end)
  if type(decoded) ~= "table" then return nil, "The ACU preset JSON could not be read." end
  if decoded.version ~= 2 then return nil, "This ACU preset version is not supported. Only version 2 can be read." end
  if lossy then return nil, "The ACU preset contains Unicode text that could not be read exactly." end
  if not text(decoded.name, 1024) or not text(decoded.game_version, 256)
      or not text(decoded.game_hash, 256) or type(decoded.is_male) ~= "boolean"
      or type(decoded.is_male_vo) ~= "boolean" or not array(decoded.options) then
    return nil, "The ACU preset has invalid required fields."
  end
  local entries, count = {}, 0
  for _, option in ipairs(decoded.options) do
    if type(option) ~= "table" or not text(option.name, limits.MAX_PRESET_KEY_BYTES)
        or type(option.value) ~= "string" or not option.value:match("^%d+$")
        or not identities.optionIndexIsValid(tonumber(option.value))
        or type(option.is_active) ~= "boolean"
        or not selection(option.selection, tonumber(option.value)) then
      return nil, "The ACU preset contains an invalid option or choice identity."
    end
    if option.is_active and option.selection.kind ~= "unset" then
      count = count + 1
      if count > limits.MAX_PRESET_ENTRIES then return nil, "The ACU preset contains too many active options." end
      if not metadataOnly then
        entries[#entries + 1] = {key=option.name,index=tonumber(option.value),selection=option.selection}
      end
    end
  end
  if count == 0 then return nil, "The ACU preset contains no active choices." end
  return {format=4,source="ACU version-2 JSON preset",notes="",tags="ACU",favorite=false,
    managedByCpm=false,importKind="acu-v2",entryCount=count,entryCountKnown=true,
    metadataLoaded=true,lazy=metadataOnly == true,entries=not metadataOnly and entries or nil,
    importMetadata={header=header,name=decoded.name,gameVersion=decoded.game_version,
      gameHash=decoded.game_hash,isMale=decoded.is_male,isMaleVoice=decoded.is_male_vo}}
end

local function switcherIdentity(names)
  if not array(names) or #names == 0 then return nil end
  local parts, size = {"switcher:"}, 9
  for _, name in ipairs(names) do
    if not text(name, 1024) then return nil end
    local part = tostring(#name) .. ":" .. name
    size = size + #part
    if size > 1024 then return nil end
    parts[#parts + 1] = part
  end
  return table.concat(parts)
end

local function resolve(entries, live, choiceIndex)
  local results, savedCounts, liveByName = {}, {}, {}
  for _, entry in ipairs(entries or {}) do savedCounts[entry.key] = (savedCounts[entry.key] or 0) + 1 end
  for _, candidate in ipairs(live) do
    local name = candidate.internalName or candidate.label
    local group = liveByName[name] or {}
    group[#group + 1] = candidate
    liveByName[name] = group
  end
  for position, entry in ipairs(entries or {}) do
    local result = {entry=entry,position=position,status="missing"}
    local group = liveByName[entry.key] or {}
    if savedCounts[entry.key] > 1 or #group > 1 then
      result.status = "ambiguous"
    elseif #group == 1 then
      local saved = entry.selection or {}
      local choice
      if saved.kind == "appearance" then choice = "definitions:" .. saved.name
      elseif saved.kind == "morph" then choice = "morphNames:" .. saved.morph_name
      elseif saved.kind == "switcher" then choice = switcherIdentity(saved.names) end
      if choice then
        local target = choiceIndex(group[1].option, choice)
        if target ~= nil then
          result.candidate,result.target,result.choice = group[1],target,choice
          result.status = "resolved"
        end
      end
    end
    results[#results + 1] = result
  end
  return results
end

return {envelope=envelope,decode=decode,resolve=resolve,switcherIdentity=switcherIdentity}
