local stateModel = require("modules/domain/state")

local function new(runtime)
  if setfenv then setfenv(1, runtime) end
  local _ENV = runtime
  local job

  local function reset()
    job = nil
  end

  local function phase(name)
    job.phase = name
    job.signature = nil
    job.stableAt = state.load.elapsed
    job.deadline = state.load.elapsed + AUTO_LOAD_TIMING.dependencyTimeout
    job.waiting = false
    state.load.nextInterval = 0
  end

  local function finish(resolved, failed, unstable)
    local completed = job
    local confirmed = 0
    for _, item in ipairs(resolved or {}) do
      local current = item.candidate and tonumber(item.candidate.option.currIndex)
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
    log(("[ACU BATCH] Finished: calls=%d batches=%d resolutions=%d confirmed=%d unresolved=%d result=%s.")
      :format(completed.calls, completed.batches, completed.resolutions, confirmed, remaining,
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
      positions={selectors={},choices={}},attempted={},blocked={},calls=0,batches=0,resolutions=0,
      accountedAt=state.load.elapsed}
    for position, entry in ipairs(preset.entries) do
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
      and tonumber(item.candidate.option.currIndex) ~= item.target
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
    local view = job.phase == "verify" and job.all or job[job.phase]
    local resolved = helpers.resolveAcuPreset(view, options)
    state.load.choiceSeconds = state.load.choiceSeconds + math.max(0, helpers.loadClock() - started)
    job.resolutions = job.resolutions + 1
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
    local written = 0
    if job.phase ~= "verify" then
      local maximum = job.phase == "selectors" and 1 or AUTO_LOAD_TIMING.maximumGroupChanges
      for _, item in ipairs(resolved) do
        local position = job.positions[job.phase][item.position]
        if eligible(item, position) then
          if written > 0 and (written >= maximum or helpers.loadClock() - started >= AUTO_LOAD_TIMING.groupBudgetSeconds) then break end
          local candidate = item.candidate
          local validOk, valid = pcall(function()
            return candidate.option.isActive and candidate.option.isEditable
              and stableRuntimeValue(candidate.option.info.name) == item.entry.key
              and optionKey(candidate.option) == candidate.label
              and optionSlot(candidate.option) == candidate.slot
              and helpers.resolveAcuChoice(candidate.option, item.choice) == item.target
          end)
          if not validOk or not valid then
            job.blocked[position] = true
          else
            job.attempted[position] = true
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
            written = written + 1
            if job.phase == "selectors" then break end
          end
        end
      end
    end
    if written > 0 then
      job.batches = job.batches + 1
      job.deadline = elapsed + AUTO_LOAD_TIMING.dependencyTimeout
      job.signature = nil
      log(("[ACU BATCH] Applied %d verified choices: phase=%s."):format(written, job.phase), "info")
      state.load.nextInterval = 0
      setStatus("load", "Applying verified ACU choices in batches. Waiting for the final check.")
      return
    end
    local parts, allMatching = {}, true
    for _, item in ipairs(resolved) do
      local current = item.candidate and tonumber(item.candidate.option.currIndex)
      local matching = item.status == "resolved" and current == item.target
      if not matching then allMatching = false end
      parts[#parts + 1] = table.concat({tostring(item.position),item.status,tostring(current),
        tostring(item.target),tostring(item.choice)}, "\31")
    end
    local signature = table.concat(parts, "\30")
    if signature ~= job.signature then job.signature = signature; job.stableAt = elapsed end
    local stable = elapsed - job.stableAt >= AUTO_LOAD_TIMING.dependencyStableTime
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
    local ok = pcall(advance, system, options, preset)
    if not ok then
      log("[ACU BATCH] The batch could not be checked safely. Loading has stopped.", "error")
      if job then finish(nil, true)
      else stateModel.markStalled(state.load) end
    end
  end

  return {run=run,reset=reset}
end

return {new=new}
