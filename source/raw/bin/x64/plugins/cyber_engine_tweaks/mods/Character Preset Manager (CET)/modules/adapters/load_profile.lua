local function new(clock,log)
  local current
  local api={}
  local categories={"optionTotal","readSeconds","candidateSeconds","resolveSeconds","applySeconds","historySeconds","uiSeconds"}
  function api.begin(name,elapsed)
    if current then return end
    current={name=tostring(name or "Unknown"),started=clock(),initialElapsed=elapsed or 0,elapsed=elapsed or 0,updates=0,
      reads=0,readSeconds=0,builds=0,visited=0,candidateSeconds=0,resolves=0,resolveSeconds=0,
      arrays=0,elements=0,applies=0,applySeconds=0,selectorWait=0,verifyWait=0,
      verification=0,verificationSeconds=0,longest=0,inCall=false,updateTimes={},maxTimes={},slow=0,slowLogged=0}
  end
  function api.enter(elapsed)
    if not current then return end
    local delta=math.max(0,(elapsed or 0)-current.elapsed)
    if current.wait=="selector" then current.selectorWait=current.selectorWait+delta
    elseif current.wait=="verification" then current.verifyWait=current.verifyWait+delta end
    current.elapsed=elapsed or 0
    current.updates=current.updates+1;current.inCall=true;current.updateTimes={}
  end
  function api.add(field,value)
    if current and current.inCall then
      current[field]=(current[field] or 0)+(value or 1)
      current.updateTimes[field]=(current.updateTimes[field] or 0)+(value or 1)
    end
  end
  function api.wait(kind)
    if current then current.wait=kind end
  end
  function api.leave(seconds)
    if not current then return end
    local p=current
    p.longest=math.max(p.longest,seconds);p.inCall=false
    for _,field in ipairs(categories) do p.maxTimes[field]=math.max(p.maxTimes[field] or 0,p.updateTimes[field] or 0) end
    if seconds>=0.05 then
      p.slow=p.slow+1
      if p.slowLogged<16 then
        p.slowLogged=p.slowLogged+1
        local t=p.updateTimes
        log(("[LOAD STALL] preset='%s' update=%d cpu=%.6fs | option access=%.6fs engine read=%.6fs candidates=%.6fs resolution=%.6fs writes=%.6fs history=%.6fs ui=%.6fs | nested timings; not GPU or whole-frame duration")
          :format(p.name,p.updates,seconds,t.optionTotal or 0,t.readSeconds or 0,t.candidateSeconds or 0,
            t.resolveSeconds or 0,t.applySeconds or 0,t.historySeconds or 0,t.uiSeconds or 0),"info")
      end
    end
  end
  function api.finish(reason)
    if not current then return end
    local p=current;current=nil
    local t=p.maxTimes
    log(("[LOAD STALL SUMMARY] preset='%s' slow updates=%d printed=%d | maxima: option access=%.6fs engine read=%.6fs candidates=%.6fs resolution=%.6fs writes=%.6fs history=%.6fs ui=%.6fs | each maximum may come from a different update")
      :format(p.name,p.slow,p.slowLogged,t.optionTotal or 0,t.readSeconds or 0,t.candidateSeconds or 0,
        t.resolveSeconds or 0,t.applySeconds or 0,t.historySeconds or 0,t.uiSeconds or 0),"info")
    log(("[LOAD PROFILE] preset='%s' result=%s | elapsed=%.6fs updates=%d longest=%.6fs | option reads=%d cpu=%.6fs | candidate builds=%d visited=%d cpu=%.6fs | resolutions=%d cpu=%.6fs | choice arrays=%d elements=%d | apply calls=%d cpu=%.6fs | selector wait=%.6fs verification wait=%.6fs | verified checks=%d cpu=%.6fs | CPU fields are nested; waits are observed scheduling intervals, not mesh completion")
      :format(p.name,tostring(reason),math.max(0,p.elapsed-p.initialElapsed),p.updates,p.longest,
        p.reads,p.readSeconds,p.builds,p.visited,p.candidateSeconds,p.resolves,p.resolveSeconds,
        p.arrays,p.elements,p.applies,p.applySeconds,p.selectorWait,p.verifyWait,p.verification,p.verificationSeconds),"info")
  end
  return api
end
return {new=new}
