local function new(report)
  local active
  local api={}
  local function clean(value)
    return tostring(value or "Unknown"):gsub("[%c|']"," "):sub(1,256)
  end
  function api.finish(now,result)
    if not active then return end
    local item=active;active=nil
    report(("[SELECTOR OBSERVED] option='%s' target=%s first matching=%s | states=[%s] | callbacks=[%s] | bounded observations; identities are resolved by the existing loader")
      :format(item.name,clean(item.target),item.firstMatching and ("%.6fs"):format(item.firstMatching) or "not observed",
        table.concat(item.states,"; "),table.concat(item.events,"; ")),"info")
    report(("[SELECTOR PROFILE] option='%s' position=%d result=%s | elapsed=%.6fs checks=%d mismatch checks=%d callback resets=%d mismatch resets=%d | last observed quiet=%.6fs | saved dependents=%d [%s] | callback counts do not prove mesh completion")
      :format(item.name,item.position,clean(result),math.max(0,now-item.started),item.checks,
        item.mismatches,item.callbackResets,item.mismatchResets,math.max(0,now-item.quietAt),
        item.childCount,table.concat(item.children,", ")),"info")
  end
  function api.begin(intents,parents,position,now,generation,target)
    api.finish(now,"superseded")
    local intent=intents[position] or {}
    local children,count={},0
    for child=1,#intents do
      if (parents[child] or {})[position] then
        count=count+1
        if #children<32 then
          local entry=intents[child]
          children[#children+1]=clean(entry.internalName or entry.label).."#"..child
        end
      end
    end
    if count>#children then children[#children+1]="additional dependents omitted" end
    active={name=clean(intent.internalName or intent.label),position=position,started=now,
      quietAt=now,generation=generation,checks=0,mismatches=0,callbackResets=0,mismatchResets=0,
      children=children,childCount=count,target=target,states={},events={},lastState=nil}
  end
  function api.event(name,now)
    if not active or #active.events>=16 then return end
    active.events[#active.events+1]=("%.6f:%s"):format(math.max(0,now-active.started),clean(name))
  end
  function api.sample(waiting,event,observed)
    if not active or active.position~=waiting.position then return end
    if observed then
      local state=clean(observed.status).." current="..clean(observed.current).." resolved="..clean(observed.target)
      if state~=active.lastState and #active.states<16 then
        active.states[#active.states+1]=("%.6f:%s"):format(math.max(0,event.now-active.started),state)
      end
      active.lastState=state
    end
    if event.matching and not active.firstMatching then active.firstMatching=math.max(0,event.now-active.started) end
    active.checks=active.checks+1
    if not event.matching then active.mismatches=active.mismatches+1 end
    if event.generation~=waiting.generation then active.callbackResets=active.callbackResets+1 end
    if not event.matching then active.mismatchResets=active.mismatchResets+1 end
    if not event.matching or event.generation~=waiting.generation then active.quietAt=event.now end
  end
  return api
end
return {new=new}
