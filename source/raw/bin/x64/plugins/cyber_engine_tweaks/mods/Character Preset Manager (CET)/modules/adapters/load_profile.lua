local function new(clock,log)
  local current
  local api={}
  function api.begin(name,elapsed)
    if current then return end
    current={name=tostring(name or "Unknown"),started=clock(),initialElapsed=elapsed or 0,elapsed=elapsed or 0,updates=0,
      reads=0,readSeconds=0,builds=0,visited=0,candidateSeconds=0,resolves=0,resolveSeconds=0,
      arrays=0,elements=0,applies=0,applySeconds=0,selectorWait=0,verifyWait=0,
      verification=0,verificationSeconds=0,longest=0,inCall=false}
  end
  function api.enter(elapsed)
    if not current then return end
    local delta=math.max(0,(elapsed or 0)-current.elapsed)
    if current.wait=="selector" then current.selectorWait=current.selectorWait+delta
    elseif current.wait=="verification" then current.verifyWait=current.verifyWait+delta end
    current.elapsed=elapsed or 0
    current.updates=current.updates+1;current.inCall=true
  end
  function api.add(field,value)
    if current and current.inCall then current[field]=(current[field] or 0)+(value or 1) end
  end
  function api.wait(kind)
    if current then current.wait=kind end
  end
  function api.leave(seconds)
    if current then current.longest=math.max(current.longest,seconds);current.inCall=false end
  end
  function api.finish(reason)
    if not current then return end
    local p=current;current=nil
    log(("[LOAD PROFILE] preset='%s' result=%s | elapsed=%.6fs updates=%d longest=%.6fs | option reads=%d cpu=%.6fs | candidate builds=%d visited=%d cpu=%.6fs | resolutions=%d cpu=%.6fs | choice arrays=%d elements=%d | apply calls=%d cpu=%.6fs | selector wait=%.6fs verification wait=%.6fs | verified checks=%d cpu=%.6fs | CPU fields are nested; waits are observed scheduling intervals, not mesh completion")
      :format(p.name,tostring(reason),math.max(0,p.elapsed-p.initialElapsed),p.updates,p.longest,
        p.reads,p.readSeconds,p.builds,p.visited,p.candidateSeconds,p.resolves,p.resolveSeconds,
        p.arrays,p.elements,p.applies,p.applySeconds,p.selectorWait,p.verifyWait,p.verification,p.verificationSeconds),"info")
  end
  return api
end
return {new=new}
