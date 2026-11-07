local function normalize(preset)
  if type(preset) ~= "table" or type(preset.entries) ~= "table" then return nil end
  if #preset.entries > 4096 then return nil end
  local intents, occurrences = {}, {}
  local format9 = preset.format == 9
  for position, entry in ipairs(preset.entries) do
    local intent = {position=position, slot=entry.slot, savedIndex=entry.index,
      sourceFormat=preset.format, state="Selected", outcome="unresolved"}
    local selection = entry.selection
    if format9 then
      intent.internalName = entry.name ~= "[unavailable]" and entry.name or nil
      intent.label = entry.legacyKey
      if entry.slot == "[unavailable]" then intent.slot = nil end
      intent.state = entry.state
      if entry.kind == "Appearance" then
        selection = {kind="appearance", name=entry.choices and entry.choices[1]}
      elseif entry.kind == "Morph" then
        selection = {kind="morph", morph_name=entry.choices and entry.choices[1]}
      elseif entry.kind == "Legacy label" then
        selection = {kind="legacy-label",label=entry.choices and entry.choices[1]}
      elseif entry.kind == "Switcher" then
        selection = {kind="switcher", names=entry.choices}
      end
    elseif preset.importKind == "acu-v2" then
      intent.internalName = entry.key
    else
      intent.label = entry.key
      occurrences[entry.key] = (occurrences[entry.key] or 0) + 1
      intent.occurrence = occurrences[entry.key]
      local field, value
      if type(entry.choice) == "string" then field, value = entry.choice:match("^([^:]+):(.*)$") end
      if value and value ~= "" then
        if field == "definitions" then selection = {kind="appearance", name=value}
        elseif field == "morphNames" then selection = {kind="morph", morph_name=value}
        elseif field == "options" then selection = {kind="legacy-label", label=value} end
      end
    end
    if intent.state ~= "Selected" and intent.state ~= "Off" then
      intent.outcome, intent.reason = "observe", "The saved record requests no appearance change."
    elseif selection and selection.kind == "appearance" and type(selection.name) == "string" and selection.name ~= "" then
      intent.identity = {kind="appearance", name=selection.name}
    elseif selection and selection.kind == "morph" and type(selection.morph_name) == "string" and selection.morph_name ~= "" then
      intent.identity = {kind="morph", name=selection.morph_name}
    elseif selection and selection.kind == "switcher" and type(selection.names) == "table" and #selection.names > 0 then
      local names = {}
      for index, name in ipairs(selection.names) do
        if type(name) ~= "string" or name == "" then return nil end
        names[index] = name
      end
      intent.identity = {kind="switcher", names=names}
    elseif selection and selection.kind == "legacy-label" then
      intent.identity = {kind="legacy-label", label=selection.label}
    else
      intent.reason = "The saved choice has no supported identity."
    end
    if intent.identity then intent.outcome = "resolve" end
    intents[#intents + 1] = intent
  end
  return intents
end

return {normalize=normalize}
