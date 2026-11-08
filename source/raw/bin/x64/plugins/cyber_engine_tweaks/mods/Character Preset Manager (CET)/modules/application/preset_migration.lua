local filter = require("modules/domain/body_filter")
local library = require("modules/domain/library")
local codec = require("modules/domain/preset9_codec")
local journal = require("modules/domain/upgrade_journal")
local function clone(value)
  if type(value)~="table" then return value end
  local result={}
  for key,item in pairs(value) do result[key]=clone(item) end
  return result
end
local function eligible(source)
  local format=source and tonumber(source.format)
  return source and source.managedByCpm==true and not source.importKind and format
    and format>=1 and format<=8 and format==math.floor(format)
end
local function sourceBody(source)
  local explicit=source.sourceBody
  local detected=filter.detect(source)
  if explicit=="Male" or explicit=="Female" then
    if detected~="Unknown" and explicit~=detected then return "Unknown" end
    return explicit
  end
  return detected
end
local function new(ports)
  local items,order,cursor={}, {},0
  local api={}
  local function discard(item)
    if item.staged and ports.discard then
      local ok,removed=pcall(ports.discard,item.staged)
      if (not ok or removed==false) and ports.report then ports.report(item.name,"A temporary upgrade file needs cleanup.","warning") end
    end
  end
  local function fail(item,message)
    discard(item)
    item.phase,item.message="failed",tostring(message)
    item.job,item.model,item.staged,item.signature=nil,nil,nil,nil
    if ports.report then ports.report(item.name,item.message,"error") end
  end
  local function reset(item)
    discard(item)
    item.phase,item.job,item.model,item.staged,item.signature="queued",nil,nil,nil,nil
    item.session=nil
  end
  function api.enqueue(name,source,fingerprint)
    if not eligible(source) then return false end
    if not journal.validStorage(source.storage or name) or type(source.entries)~="table" or #source.entries>4096 then return false end
    if type(fingerprint)~="string" or fingerprint=="" then return false end
    local previous=items[name]
    if previous and previous.fingerprint==fingerprint and previous.phase~="complete" then return false end
    if previous then discard(previous) else order[#order+1]=name end
    local savedSource=clone(source);savedSource.format=tonumber(source.format)
    items[name]={name=name,storage=source.storage or name,source=savedSource,fingerprint=fingerprint,
      body=sourceBody(source),phase="queued",restarts=0}
    return true
  end
  function api.prune(keep)
    local retained={}
    for _,name in ipairs(order) do
      if keep[name] then retained[#retained+1]=name
      else discard(items[name]);items[name]=nil end
    end
    order=retained;cursor=0
  end
  function api.rows()
    local result={}
    for _,name in ipairs(order) do
      local item=items[name]
      result[#result+1]={name=name,storage=item.storage,phase=item.phase,body=item.body,
        fingerprint=item.fingerprint,message=item.message,missing=item.missing,assumed=item.assumed}
    end
    return result
  end
  function api.assignBody(name,body)
    local item=items[name]
    if not item or item.phase~="body" then return nil,"This preset is not waiting for a body type." end
    local record,reason=ports.backups.assignBody(item.storage,item.fingerprint,body)
    if not record then fail(item,reason);return nil,reason end
    item.body,item.phase=record.body,"catalog"
    return true
  end
  function api.reject(name,message)
    if items[name] then fail(items[name],message) end
  end
  function api.retry(name)
    local item=items[name]
    if item and item.phase=="failed" then reset(item);item.restarts=0;return true end
    return false
  end
  local function unchanged(item)
    if ports.fingerprint(item.storage)~=item.fingerprint then
      fail(item,"The source preset changed. Refresh before upgrading it.")
      return false
    end
    return true
  end
  local function advance(item,context)
    if not unchanged(item) then return end
    if item.phase=="queued" then
      for _,record in ipairs(ports.backups.records() or {}) do
        if record.storage==item.storage and record.sourceFingerprint==item.fingerprint and (record.phase=="prepared" or record.phase=="installing") then
          local recovered,reason=ports.backups.recover(item.storage)
          if not recovered then fail(item,reason);return end
          break
        end
      end
      local record,reason=ports.backups.backup(item.storage,item.source.format,item.body,item.fingerprint)
      if not record then fail(item,reason);return end
      item.body=record.body
      item.phase=item.body=="Unknown" and "body" or "catalog"
      return
    end
    if item.phase=="body" or item.body~=context.body then return end
    if not context.options or #context.options==0 then return end
    if item.phase=="catalog" then
      local signature=ports.converter.signature(item.source,context.options)
      if not signature then fail(item,"The customization catalog could not be checked safely.");return end
      item.signature,item.session=signature,context.session
      item.job=ports.converter.start(item.source)
      item.phase="convert"
    elseif item.phase=="convert" then
      local done,preset,_,missing,assumed=ports.converter.step(item.job,context.options)
      if not done then return end
      if not preset or not preset.entries or #preset.entries==0 then
        fail(item,"No actionable choices could be upgraded. The original preset was kept.");return
      end
      local note=("Automatically upgraded from CPM format %d."):format(item.source.format)
      local notes=tostring(item.source.notes or "")
      if not notes:find(note,1,true) then notes=notes=="" and note or notes.." | "..note end
      if #notes>512 then fail(item,"The upgrade note would exceed the notes limit. The original preset was kept.");return end
      local now=ports.timestamp()
      local model=library.newSavedPreset(item.source,preset.entries,item.name,item.storage,
        item.source.created or now,now,9,ports.modName)
      model.format9Rows,model.sourceBody=preset.format9Rows,item.body
      model.sourceVoice=(item.source.sourceVoice=="Male" or item.source.sourceVoice=="Female") and item.source.sourceVoice or "Unknown"
      model.notes=notes
      local text=codec.encode(model,ports.modName)
      local decoded=text and codec.decode(text,false)
      if not decoded or #decoded.format9Rows~=#item.source.entries or decoded.sourceBody~=item.body
          or decoded.notes~=notes or codec.encode(decoded,ports.modName)~=text then
        fail(item,"The upgraded preset failed its round-trip check. The original was kept.");return
      end
      item.model,item.missing,item.assumed=model,missing,assumed
      item.job=nil;item.phase="check"
    elseif item.phase=="check" then
      if ports.converter.signature(item.source,context.options)~=item.signature then
        item.restarts=item.restarts+1
        if item.restarts>3 then fail(item,"The customization catalog keeps changing. Refresh when the editor is ready.")
        else reset(item) end
        return
      end
      item.phase="stage"
    elseif item.phase=="stage" then
      local staged,reason=ports.stage(item.storage,item.model,item.fingerprint)
      if not staged or type(staged.fingerprint)~="string" then fail(item,reason or "The upgrade could not be staged.");return end
      item.staged=staged;item.phase="prepare"
    elseif item.phase=="prepare" then
      local record,reason=ports.backups.prepare(item.storage,item.fingerprint,item.staged.fingerprint)
      if not record then fail(item,reason);return end
      item.phase="install"
    elseif item.phase=="install" then
      if ports.converter.signature(item.source,context.options)~=item.signature then reset(item);return end
      local ok,reason=ports.install(item.storage,item.model,item.fingerprint,item.staged)
      if not ok then fail(item,reason or "The upgraded preset could not replace its source safely.");return end
      item.phase="finish"
    end
  end
  function api.tick(context)
    if context.busy then return false end
    if not context.editorOpen then
      for _,item in pairs(items) do
        if item.session and item.phase~="finish" and item.phase~="complete" and item.phase~="failed" then reset(item) end
      end
      return false
    end
    if context.body~="Male" and context.body~="Female" then return false end
    local count=#order
    if count==0 then return false end
    local started=ports.clock()
    for _=1,count do
      cursor=cursor%count+1
      local item=items[order[cursor]]
      if (not context.allowedStorage or item.storage==context.allowedStorage)
          and item.phase~="complete" and item.phase~="failed" and item.phase~="body"
          and (item.phase=="queued" or item.phase=="finish" or item.body==context.body) then
        if item.session and item.phase~="finish" and item.session~=context.session then reset(item) end
        local ok,reason=pcall(function()
          if item.phase=="finish" then
            local record,message=ports.backups.recover(item.storage)
            if not record or record.phase~="complete" then fail(item,message or "The installed upgrade could not be verified.");return end
            if ports.completed and ports.completed(item.name,item.model,item.missing,item.assumed,item.fingerprint)==false then
              fail(item,"The preset was upgraded, but the library needs a refresh.");return
            end
            discard(item)
            item.phase="complete"
            item.message=item.missing>0 and "Upgraded with unresolved choices." or "Upgraded to format 9."
            if ports.report then ports.report(item.name,item.message,item.missing>0 and "warning" or "success",item.missing,item.assumed) end
            item.source,item.job,item.model,item.staged,item.signature=nil,nil,nil,nil,nil
          else advance(item,context) end
        end)
        if not ok then fail(item,reason) end
        local elapsed=math.max(0,ports.clock()-started)
        if ports.measure then ports.measure(item.name,elapsed) end
        return true
      end
      if ports.clock()-started>=0.004 then break end
    end
    return false
  end
  return api
end
return {new=new,eligible=eligible,sourceBody=sourceBody}
