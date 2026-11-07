local function sameIdentity(left, right)
  if not left or not right or left.kind ~= right.kind then return false end
  if left.kind == "switcher" then
    if type(left.names) ~= "table" or type(right.names) ~= "table"
        or #left.names ~= #right.names then return false end
    for index, name in ipairs(left.names) do
      if name ~= right.names[index] then return false end
    end
    return #left.names > 0
  end
  if left.kind == "legacy-label" then return left.label ~= nil and left.label == right.label end
  return left.name ~= nil and left.name == right.name
end

local function resolve(intent, catalog)
  if intent.outcome ~= "resolve" then return {status=intent.outcome, reason=intent.reason} end
  local matched
  for position, option in ipairs(catalog) do
    local sameOption = intent.internalName and option.name == intent.internalName
      or not intent.internalName and intent.label and option.label == intent.label
    if sameOption and (not intent.slot or option.slot == intent.slot) then
      if matched then return {status="ambiguous-option"} end
      matched = {option=option, position=position}
    end
  end
  if not matched then return {status="missing-option"} end
  local option = matched.option
  if not option.active or not option.editable then return {status="unavailable-option"} end
  local target
  for _, choice in ipairs(option.choices or {}) do
    local identity = intent.identity.kind == "legacy-label"
      and {kind="legacy-label", label=choice.label} or choice.identity
    if sameIdentity(intent.identity, identity) then
      if target ~= nil then return {status="ambiguous-choice"} end
      target = choice.index
    end
  end
  if target == nil then return {status="missing-choice"} end
  return {status=option.current == target and "matching" or "ready",
    position=matched.position, target=target}
end

local function dependencies(intents)
  local named, parents = {}, {}
  for position, intent in ipairs(intents) do
    if intent.internalName then
      local group = named[intent.internalName] or {}
      group[#group + 1] = position
      named[intent.internalName] = group
    end
    parents[position] = {}
  end
  for position, intent in ipairs(intents) do
    if intent.outcome == "resolve" and intent.identity and intent.identity.kind == "switcher" then
      for _, name in ipairs(intent.identity.names) do
        for _, child in ipairs(named[name] or {}) do
          if child ~= position and intents[child].outcome == "resolve" then
            parents[child][position] = true
          end
        end
      end
    end
  end
  local ordered, emitted = {}, {}
  for _ = 1, #intents do
    local progressed = false
    for position in ipairs(intents) do
      if not emitted[position] then
        local blocked = false
        for parent in pairs(parents[position]) do
          if not emitted[parent] then blocked = true end
        end
        if not blocked then
          emitted[position] = true
          ordered[#ordered + 1] = position
          progressed = true
        end
      end
    end
    if not progressed then break end
  end
  local cyclic = {}
  for position in ipairs(intents) do if not emitted[position] then cyclic[#cyclic + 1] = position end end
  return ordered, parents, cyclic
end

return {resolve=resolve, dependencies=dependencies}
