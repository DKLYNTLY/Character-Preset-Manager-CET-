local function copy(value)
  if type(value)~="table" then return value end
  local result={}
  for key,item in pairs(value) do result[key]=copy(item) end
  return result
end

local function new(maximum)
  local entries,used={},0
  local function get(key,fingerprint)
    local entry=entries[key]
    if not fingerprint or not entry or entry.fingerprint~=fingerprint then return nil end
    return copy(entry.preset)
  end
  local function put(key,fingerprint,preset,cost)
    if not fingerprint or not preset or preset.format~=9 or type(cost)~="number"
        or cost<0 or cost>maximum then return end
    if entries[key] then used=used-entries[key].cost;entries[key]=nil end
    if used+cost>maximum then entries={};used=0 end
    entries[key]={fingerprint=fingerprint,preset=copy(preset),cost=cost}
    used=used+cost
  end
  local function retain(seen)
    for key,entry in pairs(entries) do
      if not seen[key] then used=used-entry.cost;entries[key]=nil end
    end
  end
  return {get=get,put=put,retain=retain}
end

return {new=new}
