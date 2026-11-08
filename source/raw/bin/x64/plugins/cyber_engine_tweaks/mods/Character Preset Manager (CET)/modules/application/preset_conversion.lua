local codec9 = require("modules/domain/preset9_codec")
local capture9 = require("modules/adapters/format9_capture")
local function new(runtime)
if setfenv then setfenv(1,runtime) end
local _ENV = runtime
local function indexOptions(options)
  local groups = {}
  for _, option in ipairs(options) do
    local ok,key = pcall(optionKey,option)
    if ok and key then
      local group=groups[key] or {}
      group[#group+1]=option
      groups[key]=group
      local internal=stableRuntimeValue(option.info.name)
      if internal and internal~=key then
        local internalGroup=groups[internal] or {}
        internalGroup[#internalGroup+1]=option
        groups[internal]=internalGroup
      end
    end
  end
  return groups
end

local function captureEntry(entry,groups)
    local candidates={}
    for _, option in ipairs(groups[entry.key] or {}) do
      if not entry.slot or optionSlot(option)==entry.slot then candidates[#candidates+1]=option end
    end
    local row, numeric
    if #candidates==1 then
      local option=candidates[1]
      local target
      if entry.choice and entry.choice~="" then
        target=optionChoiceIndex(option,entry.choice)
      else
        target=tonumber(entry.index)
        numeric=true
      end
      if not optionIndexValidationError(target) then
        local ok,contents=pcall(capture9.capture,{
          Game=Game,ToCName=ToCName,NameToString=NameToString,
        },{{info=option.info,currIndex=target,isActive=true,isEditable=true}})
        if ok and contents then
          local captured=codec9.decode(contents,false)
          if captured and #captured.entries==1 then
            row=captured.format9Rows[1]
            row.legacyKey=entry.key
          end
        end
      end
    end
  return row,numeric
end

local function captureTargets(source, options)
  local groups = indexOptions(options)
  local rows,details,missing,assumed = {},{},0,0
  local counts={}
  for _, entry in ipairs(source.entries or {}) do
    local row,numeric = captureEntry(entry,groups)
    if not row then
      missing=missing+1
      row={slot=entry.slot or "[unavailable]",name=entry.key,state="Not captured",
        active=true,value=tostring(entry.index or 0),reason="No unique current catalog choice could be captured."}
    elseif numeric then assumed=assumed+1 end
    local group=row.slot.."\n"..row.name
    counts[group]=(counts[group] or 0)+1
    row.occurrence=counts[group]
    rows[#rows+1]=row
    local label=row.details and row.details.localizedName
    if not label or label=="" then label=table.concat(row.choices or {}," + ") end
    if not row.choices then label="Not captured" end
    details[#details+1]={key=entry.key,index=entry.index,choice=label,numeric=numeric and row.choices~=nil}
  end
  local preset={format=9,format9Rows=rows,sourceBody="Unknown",sourceVoice="Unknown"}
  local contents=codec9.encode(preset,MOD_NAME)
  if not contents then return nil end
  local decoded=codec9.decode(contents,false)
  if not decoded then return nil end
  return decoded,details,missing,assumed
end

local function catalogSignature(source,options)
  local wanted={}
  for _,entry in ipairs(source.entries or {}) do wanted[entry.key]=true end
  local chunks,bytes={},0
  local function add(value)
    value=tostring(value)
    bytes=bytes+#value+16
    if bytes>MAX_PRESET_BYTES then error("Catalog signature exceeds its limit.") end
    chunks[#chunks+1]=tostring(#value)..":"..value
  end
  local ok=pcall(function()
    add(helpers.editorBody())
    for _,option in ipairs(options) do
      local key=optionKey(option)
      local internal=stableRuntimeValue(option.info.name)
      if wanted[key] or wanted[internal] then
        add(key);add(internal);add(optionSlot(option));add(option.isActive);add(option.isEditable)
        for _,field in ipairs({"definitions","morphNames","options"}) do
          local available,collection=pcall(function()return option.info[field]end)
          add(field)
          if available and collection then
            local count=#collection
            if count>16384 then error("Catalog collection exceeds its limit.") end
            add(count)
            for index=1,count do
              local item=collection[index]
              if field=="options" then
                add(item.localizedName)
                local names=item.names
                add(#names)
                for member=1,#names do add(stableRuntimeValue(names[member])) end
              else
                add(stableRuntimeValue(type(item)=="string" and item
                  or item[field=="definitions" and "name" or "morphName"]))
              end
            end
          else add("unavailable") end
        end
      end
    end
  end)
  return ok and table.concat(chunks) or nil
end

local function start(source)
  return {source=source,position=1,rows={},counts={},details={},missing=0,assumed=0}
end
local function step(job,options)
  local entry=job.source.entries[job.position]
  if not entry then
    local text=codec9.encode({format=9,format9Rows=job.rows,sourceBody="Unknown",sourceVoice="Unknown"},MOD_NAME)
    local preset=text and codec9.decode(text,false)
    return true,preset,job.details,job.missing,job.assumed
  end
  local row,numeric=captureEntry(entry,indexOptions(options))
  if not row then
    job.missing=job.missing+1
    row={slot=entry.slot or "[unavailable]",name=entry.key,state="Not captured",active=true,
      value=tostring(entry.index or 0),reason="No unique current catalog choice could be captured."}
  elseif numeric then job.assumed=job.assumed+1 end
  local key=row.slot.."\n"..row.name
  job.counts[key]=(job.counts[key] or 0)+1;row.occurrence=job.counts[key]
  job.rows[#job.rows+1]=row
  job.position=job.position+1
  return false
end
return {capture=captureTargets,signature=catalogSignature,start=start,step=step}
end
return {new=new}
