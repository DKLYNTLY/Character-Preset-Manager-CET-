local loadStatus = require("modules/domain/load_status")
local intentsModel = require("modules/domain/load_intents")
local resolution = require("modules/domain/load_resolution")
local execution = require("modules/application/load_execution")
local verification = require("modules/application/load_verification")
local stateModel = require("modules/domain/state")
local acu = require("modules/domain/acu_v2")

local function new(runtime)
  if setfenv then setfenv(1, runtime) end
  local _ENV = runtime
  local job, generation = nil, 0
  local selectorProfile=require("modules/adapters/selector_profile").new(log,function()return state.preferences and state.preferences.detailedAppearanceTrace==true end)
  local lastProgress
  local function progress(message)
    if lastProgress ~= message then
      lastProgress = message
      setStatus("load",message)
    end
  end

  local function reset()
    selectorProfile.finish(state.load.elapsed or 0,"reset")
    job = nil; lastProgress = nil
  end

  local function changed(name)
    selectorProfile.event(name or "unnamed",state.load.elapsed or 0)
    generation = generation + 1
  end

  local function resolveRaw(intent, candidates)
    if intent.outcome ~= "resolve" then return {status=intent.outcome} end
    local catalog = {}
    for _, candidate in ipairs(candidates) do
      local matches = intent.internalName and candidate.internalName == intent.internalName
        or not intent.internalName and candidate.label == intent.label
      if matches and (not intent.slot or candidate.slot == intent.slot) then
        local choices, identity = {}, intent.identity
        local key
        if identity.kind == "switcher" then key = acu.switcherIdentity(identity.names)
        elseif identity.kind == "appearance" then key = "definitions:" .. identity.name
        elseif identity.kind == "morph" then key = "morphNames:" .. identity.name
        elseif identity.kind == "legacy-label" then key = "options:" .. identity.label end
        local index
        if identity.kind == "legacy-label" then index = optionChoiceIndex(candidate.option, key)
        else index = helpers.resolveAcuChoice(candidate.option, key) end
        if index ~= nil then choices[1] = {index=index,identity=identity,label=identity.label} end
        catalog[#catalog + 1] = {name=candidate.internalName,label=candidate.label,slot=candidate.slot,
          active=true,editable=true,current=tonumber(candidate.option.currIndex),choices=choices}
      end
    end
    local result = resolution.resolve(intent, catalog)
    if result.position then result.current = catalog[result.position].current end
    return result
  end

  local function resolve(intent,candidates)
    local profile=helpers.loadProfile
    local started=profile and helpers.loadClock()
    local result=resolveRaw(intent,candidates)
    if profile then profile.add("resolves");profile.add("resolveSeconds",math.max(0,helpers.loadClock()-started)) end
    return result
  end

  local function finish()
    local confirmed, delayed, unresolved = 0, 0, 0
    for _, intent in ipairs(job.intents) do
      if intent.outcome == "resolve" or intent.outcome == "unresolved" then
        if job.verified[intent.position] then
          confirmed = confirmed + 1
          if job.verification.delayed[intent.position] then delayed=delayed+1 end
        else
          unresolved = unresolved + 1
          log(("[SHARED LOAD] Unresolved option '%s'."):format(intent.internalName or intent.label or "unknown"), "warn")
        end
      end
    end
    log(("[VERIFY SUMMARY] confirmed=%d confirmed after delay=%d unconfirmed=%d")
      :format(confirmed-delayed,delayed,unresolved),"info")
    local reason = job.machine.stopped
    state.load.remaining = unresolved
    state.load.pendingChange = nil
    if unresolved > 0 or reason ~= "complete" then stateModel.markStalled(state.load)
    else stateModel.completeLoad(state.load) end
    local message, statusKind, resultKind = loadStatus.summary(reason, confirmed, unresolved)
    state.app.nativeLoadSummary = message
    state.app.nativePanelShowDetails = unresolved > 0 or reason ~= "complete"
    log("[SHARED LOAD] " .. message, state.app.nativePanelShowDetails and "warn" or "info")
    helpers.logLoadMeasurements("shared-" .. resultKind)
    reset()
    if state.app.inCustomization then
      local uiStarted=helpers.loadProfile and helpers.loadClock()
      refreshCustomizationUi()
      if helpers.loadProfile then helpers.loadProfile.add("uiSeconds",math.max(0,helpers.loadClock()-uiStarted)) end
      setStatus("load",message,statusKind == "error",statusKind)
    end
  end

  local function advance(system, options, preset, candidates)
    if not state.app.inCustomization then reset(); return end
    if not job then
      local input = preset
      if preset.format == 9 then input = {format=9,entries=preset.format9Rows} end
      local intents = intentsModel.normalize(input)
      if not intents then error("The preset could not be normalized.") end
      local actionable, observed = {}, 0
      for _, intent in ipairs(intents) do
        if intent.outcome == "observe" then
          observed = observed + 1
        else
          intent.position = #actionable + 1
          actionable[#actionable + 1] = intent
        end
      end
      intents = actionable
      log(("[SHARED LOAD] Queued %d choices; retained %d descriptive records in the file.")
        :format(#intents, observed), "info")
      local order, parents, cyclic = resolution.dependencies(intents)
      local checks=verification.new(#intents,generation)
      job = {intents=intents,machine=execution.new(order,parents,120,0),
        verified=checks.verified,verification=checks,verifyCursor=1,writtenLeaves={},detailed=state.preferences and state.preferences.detailedAppearanceTrace==true}
      for _, position in ipairs(cyclic) do
        log(("[SHARED LOAD] Dependency cycle at saved option %d."):format(position),"warn")
      end
    end
    local now = state.load.elapsed
    if job.verifying then
      if not job.verificationReady then
        if generation ~= job.verifyGeneration then
          job.verifyGeneration, job.verifyQuietAt = generation, now
        end
        if now - job.verifyQuietAt < AUTO_LOAD_TIMING.dependencyStableTime then
          if now < job.verifyDeadline then
            state.load.nextInterval = AUTO_LOAD_TIMING.pollInterval
            return
          end
          job.machine.stopped = "unstable"
        end
        job.verificationReady = true
        job.verification.generation=generation
        state.app.optionsMemo = nil
        return
      end
      local function nextRound()
        job.retryQueue=verification.pending(job.verification)
        if #job.retryQueue==0 or now>=job.verifyDeadline or job.machine.stopped~="complete" then
          finish()
          return
        end
        job.retryCursor,job.retryAt=1,now+AUTO_LOAD_TIMING.pollInterval
        state.app.optionsMemo=nil
        state.load.nextInterval=AUTO_LOAD_TIMING.pollInterval
        job.retryPause=true
      end
      if job.verifyInitialDone then
        if verification.invalidate(job.verification,generation) then nextRound();return end
        if now>=job.verifyDeadline then finish();return end
        if job.retryAt and now<job.retryAt then
          state.load.nextInterval=AUTO_LOAD_TIMING.pollInterval
          job.retryPause=true
          return
        end
        job.retryAt=nil
      end
      local position=job.verifyInitialDone and job.retryQueue[job.retryCursor] or job.verifyCursor
      local intent=position and job.intents[position]
      if not intent then
        job.verifyInitialDone=true
        verification.invalidate(job.verification,generation)
        nextRound()
        return
      end
      progress("Checking saved choices.")
      local verifyStarted=helpers.loadProfile and helpers.loadClock()
      local observed=resolve(intent,candidates)
      verification.observe(job.verification,position,observed,job.verifyInitialDone)
      local written=job.writtenLeaves[intent.position]
      if written then
        log(("[CHILD OBSERVED] option='%s' phase=verification written=%s immediate=%s current=%s resolved=%s status=%s")
          :format(tostring(intent.internalName or intent.label),tostring(written.target),tostring(written.immediate),
            tostring(observed.current),tostring(observed.target),tostring(observed.status)),"info")
      end
      if helpers.loadProfile then
        helpers.loadProfile.add("verification")
        helpers.loadProfile.add("verificationSeconds",math.max(0,helpers.loadClock()-verifyStarted))
      end
      if job.verifyInitialDone then job.retryCursor=job.retryCursor+1
      else job.verifyCursor=job.verifyCursor+1 end
      state.load.nextInterval = 0
      return
    end
    local event = {now=now,editorOpen=true,generation=generation}
    local waiting = job.machine.waiting
    if waiting then
      local observed=resolve(job.intents[waiting.position],candidates)
      event.matching = observed.status == "matching"
      selectorProfile.sample(waiting,event,observed)
    else
      local position = job.machine.order[job.machine.cursor or 1]
      if position and job.machine.pending[position] then
        local result = resolve(job.intents[position],candidates)
        event.position,event.status,event.target = position,result.status,result.target
      end
    end
    local action = execution.step(job.machine,event)
    if action.kind == "write" then
      if job.machine.waiting then
        selectorProfile.begin(job.intents,job.machine.parents,action.position,now,generation,action.target)
      end
      progress("Applying saved choices. Dependencies are checked before their colors and styles.")
      job.wroteThisUpdate = true
      local intent = job.intents[action.position]
      local fresh = resolve(intent,candidates)
      local option
      for _, candidate in ipairs(candidates) do
        if (intent.internalName and candidate.internalName == intent.internalName
            or not intent.internalName and candidate.label == intent.label)
            and (not intent.slot or candidate.slot == intent.slot) then
          if option then error("Option identity became ambiguous.") end
          option = candidate.option
        end
      end
      if fresh.status ~= "ready" or fresh.target ~= action.target or not option then
        execution.step(job.machine,{now=now,editorOpen=true,writeFailed=true})
      else
        if job.detailed then
          log(("[SHARED LOAD] Apply '%s' target=%d."):format(intent.internalName or intent.label, action.target),"info")
        end
        local applyStarted=helpers.loadProfile and helpers.loadClock()
        local instant=job.machine.hasChildren[action.position]==true
        local ok
        if instant then ok=pcall(system.ApplyChangeToOption,system,option,action.target,true)
        else ok=pcall(system.ApplyChangeToOption,system,option,action.target) end
        if helpers.loadProfile then
          helpers.loadProfile.add("applies")
          helpers.loadProfile.add("applySeconds",math.max(0,helpers.loadClock()-applyStarted))
        end
        if not instant and job.detailed then
          local readOk,immediate=pcall(function()return tonumber(option.currIndex)end)
          job.writtenLeaves[action.position]={target=action.target,immediate=readOk and immediate or "unavailable"}
          log(("[CHILD OBSERVED] option='%s' phase=after-write target=%s current=%s callSucceeded=%s")
            :format(tostring(intent.internalName or intent.label),tostring(action.target),
              tostring(readOk and immediate or "unavailable"),tostring(ok)),"info")
        end
        if not ok then execution.step(job.machine,{now=now,editorOpen=true,writeFailed=true}) end
        state.app.optionsMemo = nil
      end
    elseif action.kind == "warn" then
      log(("[SHARED LOAD] Skipped saved option %d: %s."):format(action.position,action.reason),"warn")
    elseif action.kind == "finished" then
      selectorProfile.finish(now,action.reason or "finished")
      job.verifying = true
      job.verifyGeneration, job.verifyQuietAt = generation, now
      job.verifyDeadline = now + AUTO_LOAD_TIMING.dependencyTimeout
    elseif action.kind == "refresh" then
      selectorProfile.finish(now,"settled")
      state.app.optionsMemo = nil
    end
    if action.kind == "wait" then
      progress("Waiting for an editor choice to settle before continuing.")
    end
    state.load.nextInterval = action.kind == "wait" and AUTO_LOAD_TIMING.pollInterval or 0
  end

  local function run(system, options, preset)
    local started = helpers.loadClock()
    local ok = pcall(function()
      if not state.app.inCustomization then reset(); return end
      local candidates = helpers.acuCandidates(options)
      if job then job.wroteThisUpdate,job.retryPause = false,false end
      for _ = 1, 8 do
        advance(system,options,preset,candidates)
        if not job or job.wroteThisUpdate or job.retryPause or job.machine.waiting or job.verifying and not job.verificationReady
            or helpers.loadClock() - started >= AUTO_LOAD_TIMING.groupBudgetSeconds then break end
      end
    end)
    if helpers.loadProfile then
      helpers.loadProfile.wait(job and job.machine.waiting and "selector"
        or job and job.verifying and (not job.verificationReady or job.retryPause) and "verification" or nil)
    end
    state.load.choiceSeconds = state.load.choiceSeconds + math.max(0,helpers.loadClock()-started)
    if not ok then
      log("[SHARED LOAD] Loading stopped after an adapter failure.","error")
      if job then
        job.machine.stopped,job.verifying = "failure",true
        finish()
      else stateModel.markStalled(state.load) end
    end
  end

  local function compare(preset, options)
    local intents = intentsModel.normalize({format=9,entries=preset.format9Rows})
    local result = {total=0,matching=0,changing=0,missing=0,ambiguous=0,invalid=0,clearing=0,details={}}
    if not intents then result.invalid=1; result.total=1; return result end
    local candidates = helpers.acuCandidates(options)
    for _, intent in ipairs(intents) do
      if intent.outcome ~= "observe" then
        result.total = result.total + 1
        local found = resolve(intent,candidates)
        local counter,status = "missing","Missing"
        if found.status == "matching" then counter,status="matching","Already matching"
        elseif found.status == "ready" then counter,status="changing","Will change"
        elseif found.status == "ambiguous-option" or found.status == "ambiguous-choice" then
          counter,status="ambiguous","Repeated or uncertain"
        end
        result[counter] = result[counter] + 1
        result.details[#result.details+1] = {label=intent.internalName or intent.label or "Unknown option",
          status=status,current=found.current,target=found.target}
      end
    end
    return result
  end

  return {run=run,reset=reset,changed=changed,compare=compare}
end

return {new=new}
