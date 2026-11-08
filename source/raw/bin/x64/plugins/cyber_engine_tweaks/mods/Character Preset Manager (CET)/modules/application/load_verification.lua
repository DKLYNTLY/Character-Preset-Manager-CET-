local function new(count,generation)
  return {count=count,generation=generation,verified={},delayed={},pending={},samples={},results={}}
end

local function invalidate(state,generation)
  if state.generation==generation then return false end
  state.generation=generation
  for position=1,state.count do
    state.verified[position],state.delayed[position],state.samples[position]=nil,nil,nil
    state.pending[position]=true
  end
  return true
end

local function observe(state,position,result,retry)
  state.results[position]={status=result.status,target=result.target,current=result.current}
  state.verified[position],state.delayed[position]=nil,nil
  if result.status=="matching" then
    if not retry then
      state.verified[position],state.pending[position]=true,nil
      return
    end
    local sample=state.samples[position]
    local count=sample and sample.target==result.target and sample.count+1 or 1
    state.samples[position]={target=result.target,count=count}
    if count>=2 then
      state.verified[position],state.delayed[position],state.pending[position]=true,true,nil
    else state.pending[position]=true end
  else
    state.samples[position]=nil
    state.pending[position]=result.status=="ready" or nil
  end
end

local function pending(state)
  local positions={}
  for position=1,state.count do
    if state.pending[position] then positions[#positions+1]=position end
  end
  return positions
end

return {new=new,invalidate=invalidate,observe=observe,pending=pending}
