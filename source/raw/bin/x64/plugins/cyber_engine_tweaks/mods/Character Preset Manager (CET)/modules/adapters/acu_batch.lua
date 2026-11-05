local stateModel = require("modules/domain/state")
local acuV2 = require("modules/domain/acu_v2")

local function new(runtime)
  if setfenv then setfenv(1, runtime) end
  local _ENV = runtime
  local job

  local function reset()
    job = nil
  end

  local function phase(name)
    job.phase = name
    job.cache = {}
    job.cursor = 1
    job.quietSignature = nil
    job.deadline = state.load.elapsed + AUTO_LOAD_TIMING.dependencyTimeout
    job.waiting = false
    state.load.nextInterval = 0
  end

  local function finish(resolved, failed, unstable)
    local completed = job
    local confirmed = 0
    for _, item in ipairs(resolved or {}) do
      local current = item.candidate and item.candidate.current
      if item.status == "resolved" and current == item.target then
        confirmed = confirmed + 1
      else
        state.logLoadOnce("acu-batch:" .. tostring(item.position),
          ("[SKIPPED] ACU choice '%s' could not be confirmed by its saved identity. No numeric fallback was used.")
            :format(item.entry.key), "warn")
      end
    end
    local total = #completed.all.entries
    local remaining = total - confirmed
    state.load.remaining = remaining
    state.load.pendingChange = nil
    if failed or unstable or remaining > 0 then stateModel.markStalled(state.load)
    else stateModel.completeLoad(state.load) end
    local message = ("Confirmed %d of %d ACU choices. %d remain unresolved."):format(confirmed, total, remaining)
    if failed then message = "ACU loading stopped because a batch could not be applied. Check the Activity Log."
    elseif unstable then message = message .. " The editor did not settle before the final check."
    elseif remaining == 0 then message = ("Confirmed all %d ACU choices."):format(total) end
    state.app.nativeLoadSummary = message
    state.app.nativePanelShowDetails = failed or unstable or remaining > 0
    log(("[ACU BATCH] Finished: calls=%d batches=%d entryChecks=%d choiceScans=%d slices=%d longestSlice=%.6fs confirmed=%d unresolved=%d result=%s.")
      :format(completed.calls, completed.batches, completed.resolutions, completed.choiceScans,
        completed.slices, completed.longestSlice, confirmed, remaining,
        failed and "failed" or unstable and "unstable" or remaining > 0 and "partial" or "complete"),
      state.app.nativePanelShowDetails and "warn" or "info")
    helpers.logLoadMeasurements(state.app.nativePanelShowDetails and "acu-partial" or "acu-complete")
    reset()
    if state.app.inCustomization then refreshCustomizationUi() end
    if failed then setStatus("load", message, true)
    else setStatus("load", message, false, state.app.nativePanelShowDetails and "warning" or "success") end
  end

  local function start(preset)
    job = {all={entries=preset.entries},selectors={entries={}},choices={entries={}},
      positions={selectors={},choices={}},attempted={},blocked={},written={},counts={},calls=0,batches=0,resolutions=0,
      generation=0,choiceScans=0,slices=0,longestSlice=0,
      accountedAt=state.load.elapsed}
    for position, entry in ipairs(preset.entries) do
      job.counts[entry.key] = (job.counts[entry.key] or 0) + 1
      local group = entry.selection and entry.selection.kind == "switcher" and "selectors" or "choices"
      job[group].entries[#job[group].entries + 1] = entry
      job.positions[group][#job[group].entries] = position
    end
    phase(#job.selectors.entries > 0 and "selectors" or "choices")
    log(("[ACU BATCH] Started: selectors=%d other choices=%d. No cleanup is scheduled.")
      :format(#job.selectors.entries, #job.choices.entries), "info")
  end

  local function eligible(item, position)
    return item.status == "resolved" and not job.attempted[position] and not job.blocked[position]
      and item.candidate.current ~= item.target
  end

  local function binding(group)
    if #group ~= 1 then return tostring(#group) end
    local value = group[1]
    return table.concat({value.internalName,value.label,value.key,tostring(value.slot),tostring(value.position)}, "\31")
  end

  local function plain(item, group)
    return {entry=item.entry,status=item.status,target=item.target,choice=item.choice,
      binding=binding(group),observed=#group == 1 and group[1].current or nil,
      generation=job.generation}
  end

  local function bind(item, group, position)
    local result = {entry=item.entry,position=position,status=item.status,target=item.target,choice=item.choice}
    if #group > 1 then result.status = "ambiguous"
    elseif item.status == "resolved" then
      if #group == 1 and item.binding == binding(group) then result.candidate = group[1]
      else result.status = "missing" end
    end
    return result
  end

  local function refresh(item, group, position)
    if job.attempted[position] then return false end
    local current = #group == 1 and group[1].current or nil
    return item.binding ~= binding(group) or item.observed ~= current
      or item.status ~= "resolved" and #group == 1 and item.generation ~= job.generation
  end

  local function advance(system, options, preset)
    if not state.app.inCustomization then
      stateModel.stopForUnavailableOptions(state.load)
      reset()
      return
    end
    if not job then start(preset) end
    local elapsed = state.load.elapsed
    if job.waiting then state.load.waitSeconds = state.load.waitSeconds + math.max(0, elapsed - job.accountedAt) end
    job.accountedAt = elapsed
    job.waiting = false
    local started = helpers.loadClock()
    job.slices = job.slices + 1
    local groups, parts = {}, {tostring(job.generation)}
    for _, candidate in ipairs(helpers.acuCandidates(options)) do
      candidate.current = tonumber(candidate.option.currIndex)
      local group = groups[candidate.internalName] or {}
      group[#group + 1] = candidate
      groups[candidate.internalName] = group
      parts[#parts + 1] = table.concat({candidate.internalName,candidate.key,tostring(candidate.slot),
        tostring(candidate.position),tostring(candidate.current)}, "\31")
    end
    local quietSignature = table.concat(parts, "\30")
    if quietSignature ~= job.quietSignature then
      job.quietSignature = quietSignature
      job.quietAt = elapsed
      if job.phase == "verify" then job.cache = {}; job.cursor = 1 end
    end
    local view = job.phase == "verify" and job.all or job[job.phase]
    if job.phase ~= "verify" then
      for index = 1, job.cursor - 1 do
        local entry = view.entries[index]
        local position = job.positions[job.phase][index]
        if refresh(job.cache[index], groups[entry.key] or {}, position) then
          job.cache[index] = nil
          job.cursor = index
          break
        end
      end
    end
    local visits, scanned = 0, false
    while job.cursor <= #view.entries and visits < 8 do
      local index = job.cursor
      local entry = view.entries[index]
      local position = job.phase == "verify" and index or job.positions[job.phase][index]
      local group = groups[entry.key] or {}
      local stored = job.cache[index]
      if stored and job.phase ~= "verify" and refresh(stored, group, position) then stored = nil end
      local item, fresh
      if stored then
        item = bind(stored, group, index)
      elseif job.phase ~= "verify" and job.written[position] then
        job.cache[index] = job.written[position]
        item = bind(job.cache[index], group, index)
      else
        fresh = true
        if job.counts[entry.key] > 1 then
          item = {entry=entry,position=index,status="ambiguous"}
        else
          item = acuV2.resolve({entry}, group, function(option, choice)
            scanned = true
            job.choiceScans = job.choiceScans + 1
            return helpers.resolveAcuChoice(option, choice)
          end)[1]
          item.position = index
        end
        job.resolutions = job.resolutions + 1
        job.cache[index] = plain(item, group)
      end
      job.cursor = index + 1
      visits = visits + 1
      if fresh and job.phase ~= "verify" and eligible(item, position) then
        local candidate = item.candidate
        local validOk, valid = pcall(function()
          return candidate.option.isActive and candidate.option.isEditable
            and stableRuntimeValue(candidate.option.info.name) == item.entry.key
            and optionKey(candidate.option) == candidate.label and optionSlot(candidate.option) == candidate.slot
        end)
        if not validOk or not valid then
          job.blocked[position] = true
        else
          job.attempted[position] = true
          job.written[position] = job.cache[index]
          if helpers.appearanceTrace then
            helpers.appearanceTrace("compare", {slot=candidate.slot,label=item.entry.key,
              kind="acu-batch",target=item.target,savedChoice=item.choice}, candidate.option, "before-write")
          end
          local applyStarted = helpers.loadClock()
          local ok = pcall(system.ApplyChangeToOption, system, candidate.option, item.target)
          state.load.applySeconds = state.load.applySeconds + math.max(0, helpers.loadClock() - applyStarted)
          state.app.optionsMemo = nil
          job.calls = job.calls + 1
          if not ok then
            log("[ACU BATCH] The game rejected an option write. Loading has stopped.", "error")
            finish(nil, true)
            return
          end
          job.batches = job.batches + 1
          job.deadline = elapsed + AUTO_LOAD_TIMING.dependencyTimeout
          log(("[ACU BATCH] Applied 1 verified choice: phase=%s."):format(job.phase), "info")
          state.load.nextInterval = 0
          setStatus("load", "Applying verified ACU choices in small steps. Waiting for the final check.")
          return
        end
      end
      if scanned or helpers.loadClock() - started >= AUTO_LOAD_TIMING.groupBudgetSeconds then break end
    end
    if job.cursor <= #view.entries then state.load.nextInterval = 0; return end
    local resolved = {}
    for index, entry in ipairs(view.entries) do
      resolved[index] = bind(job.cache[index], groups[entry.key] or {}, index)
    end
    if job.phase == "verify" then
      local nextPhase
      for _, item in ipairs(resolved) do
        if eligible(item, item.position) then
          if item.entry.selection.kind == "switcher" then nextPhase = "selectors"; break end
          nextPhase = "choices"
        end
      end
      if nextPhase then phase(nextPhase); return end
    end
    local allMatching = true
    for _, item in ipairs(resolved) do
      if item.status ~= "resolved" or item.candidate.current ~= item.target then allMatching = false end
    end
    local stable = elapsed - job.quietAt >= AUTO_LOAD_TIMING.dependencyStableTime
    local ready = job.calls == 0 or allMatching and stable or elapsed >= job.deadline
    if ready then
      if job.phase == "selectors" then phase("choices")
      elseif job.phase == "choices" then phase("verify")
      else finish(resolved, false, job.calls > 0 and not stable) end
      return
    end
    job.waiting = true
    state.load.nextInterval = AUTO_LOAD_TIMING.pollInterval
    setStatus("load", "Waiting for the ACU batch to settle before checking its results.")
  end

  local function run(system, options, preset)
    local started = helpers.loadClock()
    local appliedBefore = state.load.applySeconds
    local ok = pcall(advance, system, options, preset)
    if job then
      local seconds = math.max(0, helpers.loadClock() - started)
      state.load.choiceSeconds = state.load.choiceSeconds + math.max(0, seconds - (state.load.applySeconds - appliedBefore))
      job.longestSlice = math.max(job.longestSlice, seconds)
    end
    if not ok then
      log("[ACU BATCH] The batch could not be checked safely. Loading has stopped.", "error")
      if job then finish(nil, true)
      else stateModel.markStalled(state.load) end
    end
  end

  local function changed()
    if job then job.generation = job.generation + 1 end
  end

  return {run=run,reset=reset,changed=changed}
end

return {new=new}
