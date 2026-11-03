local function install(runtime)
  local state = runtime.state
  local trace = state.appearanceTrace
  local timing = runtime.AUTO_LOAD_TIMING
  local function clean(value)
    return tostring(value == nil and "unknown" or value):gsub("[%c|]", " "):sub(1, 512)
  end
  local function emit(kind, fields)
    runtime.log(kind .. " | " .. fields, "info")
  end
  local function context(item)
    return "id=" .. item.id .. " editorSession=" .. item.session
  end
  local function choice(option, index)
    return option and runtime.helpers.optionChoiceKey(option, index) or nil
  end
  local function snapshot(item, phase, supplied)
    local options = supplied
    if not options then
      local system = runtime.Game.GetCharacterCustomizationSystem()
      if not system then return nil end
      local empty = runtime.ToCName({})
      options = system:GetUnitedOptions(true, true, true, empty, empty, empty)
    end
    if type(options) ~= "table" or #options == 0 then return nil end
    local rows, occurrences = {}, {}
    for position, option in ipairs(options) do
      if position > 512 then
        emit("APPEARANCE TRACE", context(item) .. " phase=" .. phase .. " detail=option-limit")
        return nil
      end
      local label = runtime.optionKey(option)
      local slot = runtime.optionSlot(option)
      local index = tonumber(option.currIndex)
      local key = label or "missing-key"
      occurrences[key] = (occurrences[key] or 0) + 1
      local fields = "slot=" .. clean(slot) .. " label=" .. clean(label)
        .. " occurrence=" .. occurrences[key] .. " index=" .. clean(index)
        .. " choice=" .. clean(choice(option, index))
        .. " active=" .. tostring(option.isActive == true)
        .. " editable=" .. tostring(option.isEditable == true)
      rows[#rows + 1] = fields
      if phase ~= "poll" and item.snapshots < 6 then
        emit("OPTION STATE", context(item) .. " phase=" .. phase .. " " .. fields)
        if phase == "save-source" and (not label or not option.isActive or not option.isEditable) then
          local reason = not label and "missing-key" or not option.isActive and "inactive" or "not-editable"
          emit("SAVE OMITTED", context(item) .. " slot=" .. clean(slot) .. " reason=" .. reason)
        end
      end
    end
    if phase ~= "poll" then item.snapshots = item.snapshots + 1 end
    return table.concat(rows, "\n")
  end
  local function finish(item, result)
    emit("APPEARANCE TRACE END", context(item) .. " result=" .. result)
    trace.items[item.action] = nil
  end
  local api = {}
  function api.begin(action, name, format)
    local previous = trace.items[action]
    if previous then finish(previous, "superseded") end
    trace.sequence = trace.sequence + 1
    local item = { id = trace.sequence, session = trace.session, action = action,
      snapshots = 0, elapsed = 0, poll = 0, events = 0, comparisons = {}, comparisonCount = 0 }
    item.waitingRandomize = action == "randomize"
    trace.items[action] = item
    emit("APPEARANCE TRACE", context(item) .. " action=" .. action .. " phase=before preset=" .. clean(name) .. " format=" .. clean(format))
    snapshot(item, "before")
    if action == "randomize" then
      local menu = state.editor.activeBodyMorphMenu
      local ok, locks = pcall(function() return menu:CPMRandomizerLocksForTrace() end)
      locks = ok and tostring(locks) or "category=unknown locked=unknown"
      local count = 0
      for fields in locks:gmatch("[^;]+") do
        if count >= 32 then break end
        emit("RANDOMIZER LOCK", context(item) .. " " .. clean(fields))
        count = count + 1
      end
    end
  end
  function api.source(options)
    local item = trace.items.save
    if item then snapshot(item, "save-source", options) end
  end
  function api.after(action, outcome)
    local item = trace.items[action]
    if not item or item.polling then return end
    emit("APPEARANCE TRACE", context(item) .. " action=" .. action .. " phase=after outcome=" .. clean(outcome))
    item.signature = snapshot(item, "after")
    item.polling = true
    item.stable = 0
  end
  function api.compare(pending, option, outcome)
    local item = trace.items.load
    if not item or item.comparisonCount >= 512 then return end
    local index = option and tonumber(option.currIndex)
    local observed = choice(option, index)
    local entry = state.load.savedEntryByKey and state.load.savedEntryByKey[pending.trackingKey]
    local fields = "slot=" .. clean(pending.slot) .. " label=" .. clean(pending.label)
      .. " occurrence=" .. clean(pending.occurrence) .. " kind=" .. clean(pending.kind)
      .. " savedChoice=" .. clean(pending.acuChoice or pending.savedChoice or (entry and entry.choice)) .. " resolvedTarget=" .. clean(pending.target)
      .. " observedIndex=" .. clean(index) .. " observedChoice=" .. clean(observed)
      .. " outcome=" .. clean(outcome)
    if item.comparisons[fields] then return end
    item.comparisons[fields] = true
    item.comparisonCount = item.comparisonCount + 1
    emit("LOAD COMPARE", context(item) .. " " .. fields)
  end
  function api.event(name)
    for _, item in pairs(trace.items) do
      if name == "OnRandomizeComplete" then item.waitingRandomize = false end
      if item.events < 32 then
        emit("APPEARANCE EVENT", context(item) .. " event=" .. clean(name))
        item.events = item.events + 1
      end
    end
  end
  function api.lifecycle(name)
    if name == "creator-initialize" then trace.session = trace.session + 1 end
    emit("EDITOR LIFECYCLE", "editorSession=" .. trace.session .. " event=" .. clean(name))
    if name == "creator-uninitialize" or name == "shutdown" then
      for _, item in pairs(trace.items) do finish(item, "editor-closed") end
    end
  end
  function api.update(delta)
    for _, item in pairs(trace.items) do
      if item.polling then
        local elapsed = math.max(0, tonumber(delta) or 0)
        item.elapsed = item.elapsed + elapsed
        item.poll = item.poll + elapsed
        if item.elapsed >= timing.dependencyTimeout then
          snapshot(item, "final")
          finish(item, "timeout")
        elseif item.poll >= timing.pollInterval then
          local interval = item.poll
          item.poll = 0
          local signature = snapshot(item, "poll")
          if signature and signature == item.signature then item.stable = item.stable + interval
          else item.stable = 0 end
          item.signature = signature
          if not item.waitingRandomize and item.stable >= timing.dependencyStableTime then
            snapshot(item, "final")
            finish(item, "stable-data")
          end
        end
      end
    end
  end
  runtime.helpers.appearanceTrace = function(method, ...)
    local ok, failure = pcall(api[method], ...)
    if not ok then
      trace.items = {}
      if not trace.failed then
        trace.failed = true
        pcall(emit, "APPEARANCE TRACE", "detail=read-failed reason=" .. clean(failure))
      end
    end
  end
end

return { install = install }
