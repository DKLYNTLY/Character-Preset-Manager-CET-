local runtime=assert(require("modules/runtime"),"Character Preset Manager runtime did not load")
if setfenv then setfenv(1,runtime) end
local _ENV=runtime
local backupsFactory=require("modules/application/upgrade_backups")
local queueFactory=require("modules/application/preset_migration")
local conversion=require("modules/application/preset_conversion").new(runtime)
local codec=require("modules/domain/preset9_codec")
local fields=require("modules/domain/codecs")
local fileAdapter=require("modules/adapters/files")
local stateModel=require("modules/domain/state")
local root=backupsFactory.ROOT
local journal=backupsFactory.JOURNAL
local requestFile=CONFIG_DIR.."/Upgrade Filesystem Request.txt"
local resultFile=CONFIG_DIR.."/Upgrade Filesystem Result.txt"
local active=false
local started=false
local initialized=false
local disabled=false
local discover=true
local tasks,cursor={},0
local refreshPending,taskErrors={},{}
local randomizing=false
local randomizeElapsed=0
local pendingBody
local taskBatches={}
local batchSequence=0
local pendingLoad
local batch
local guard
local guardCounter=0
local lastMessage
local service
local queue
local recovery
local function clock()return helpers.loadClock()end
local function message(text,kind)
  if text==lastMessage then return end
  lastMessage=text
  setStatus("load",text,kind=="error",kind or "info")
  state.app.nativePanelStatus,state.app.nativePanelStatusError=text,kind=="error"
end
local function read(path,limit)return readBoundedFile(path,limit)end
local function freshBatch()
  batchSequence=batchSequence+1
  return "U"..os.date("%Y%m%d_%H%M%S").."_"..tostring(math.floor(clock()*1000000)).."_"..batchSequence
end
local function exclusive(path,bytes)
  if not guard or not guard.ready then return false end
  if fileExists(path) or fileExists(path..".new") then return false end
  if not fileAdapter.writeBytes(io,path..".new",bytes) then deleteFile(path..".new");return false end
  if not os.rename(path..".new",path) then deleteFile(path..".new");return false end
  return read(path,MAX_PRESET_BYTES)==bytes
end
local filePorts={
  read=read,exists=function(path)return fileExists(path)end,
  fingerprint=function(path)return fileFingerprint(path,MAX_PRESET_BYTES)end,
  newBatch=function()return batch end,create=exclusive,
  readJournal=function(limit)
    if not fileExists(journal) and fileExists(journal..".bak") then
      if not guard or not guard.ready or not os.rename(journal..".bak",journal) then return nil,"recovery failed" end
    end
    if not fileExists(journal) then return nil,"missing" end
    return read(journal,limit)
  end,
  saveJournal=function(text,expected)
    local current=read(journal,MAX_PRESET_BYTES)
    if current~=expected or not guard or not guard.ready then return false end
    return atomicReplace(journal,function(path)
      if read(journal,MAX_PRESET_BYTES)~=expected then return false end
      return fileAdapter.writeBytes(io,path,text)
    end,"upgrade journal")
  end,
  validateReplacement=function(text,record)
    local preset=codec.decode(text,false)
    return preset and preset.format==9 and preset.sourceBody==record.body
  end,
}
service=backupsFactory.new(filePorts)
local function discard(staged)
  if not guard or not guard.ready then return false end
  if not staged or not staged.path or staged.path:sub(1,#root)~=root then return false end
  if fileFingerprint(staged.path,MAX_PRESET_BYTES)~=staged.fingerprint then return not fileExists(staged.path) end
  return deleteFile(staged.path)
end
queue=queueFactory.new({backups=service,converter=conversion,modName=MOD_NAME,clock=clock,timestamp=logTimestamp,
  fingerprint=function(storage)return fileFingerprint(PRESET_DIR.."/"..storage..".preset",MAX_PRESET_BYTES)end,
  stage=function(storage,model)
    local text=codec.encode(model,MOD_NAME)
    if not text then return nil,"The format 9 file could not be encoded." end
    local path=root..batch.."/"..storage..".candidate"
    if not guard or not guard.ready or fileExists(path) or fileExists(path..".new") then
      return nil,"The temporary upgrade destination is not available."
    end
    if not writePresetContents(path..".new",model) then deleteFile(path..".new");return nil,"The temporary upgrade could not be written." end
    local decoded=codec.decode(read(path..".new",MAX_PRESET_BYTES),false)
    if not decoded or codec.encode(decoded,MOD_NAME)~=text or not os.rename(path..".new",path) then
      deleteFile(path..".new");return nil,"The temporary upgrade failed verification."
    end
    return {path=path,fingerprint=fileFingerprint(path,MAX_PRESET_BYTES)}
  end,
  discard=discard,
  install=function(storage,model,expected,staged)
    local text=read(staged.path,MAX_PRESET_BYTES)
    local decoded=text and codec.decode(text,false)
    if not decoded or fileFingerprint(staged.path,MAX_PRESET_BYTES)~=staged.fingerprint
        or codec.encode(decoded,MOD_NAME)~=codec.encode(model,MOD_NAME) then return nil,"The staged upgrade changed. The original was kept." end
    local installing,reason=service.beginInstall(storage,expected)
    if not installing then return nil,reason end
    if not writePresetPath(PRESET_DIR.."/"..storage..".preset",model,expected) then return nil,"The source could not be replaced safely." end
    if fileFingerprint(PRESET_DIR.."/"..storage..".preset",MAX_PRESET_BYTES)~=staged.fingerprint then return false end
    local complete,error=service.recover(storage)
    return complete and complete.phase=="complete",error
  end,
  completed=function(name,model,missing,assumed,sourceFingerprint)
    state.library.presets[name]=model
    if state.library.selected==name then state.library.presetNotes,state.library.presetTags=model.notes,model.tags end
    invalidateViewCache();state.invalidatePreflight()
    writeInventory(state.library.presets,state.library.folders)
    if pendingLoad and pendingLoad.name==name and pendingLoad.fingerprint==sourceFingerprint then pendingLoad.ready=true end
    return true
  end,
  report=function(name,text,kind,missing,assumed)
    log(("[AUTO UPGRADE] %s: %s Current-index mappings=%d; unresolved=%d.")
      :format(name,text,assumed or 0,missing or 0),kind=="error" and "error" or kind=="warning" and "warn" or "info")
    if kind=="error" and pendingLoad and pendingLoad.name==name then pendingLoad=nil end
  end,
  measure=function(name,elapsed)
    if elapsed>0.004 then log(("[AUTO UPGRADE MEASURE] %s: one phase took %.6fs."):format(name,elapsed),"info") end
  end,
})
helpers.presetMigration={rows=queue.rows,assignBody=function(name,body)
  pendingBody={name=name,body=body}
  active=true
  message("Saving the preset body choice.")
  return true
end}
local function checked(storage,phase,backupBatch)
  local key=storage.."|"..phase.."|"..batch.."|"..tostring(backupBatch)
  if not guard or guard.key~=key then
    guardCounter=guardCounter+1
    guard={key=key,id=batch.."_"..guardCounter,storage=storage,phase=phase,batches={batch},position=1,elapsed=0,poll=0}
    if backupBatch and backupBatch~=batch then guard.batches[#guard.batches+1]=backupBatch end
  end
  if guard.ready then return true end
  if guard.failed then return nil,guard.failed end
  if not guard.sent then
    local text="1\t"..guard.id.."\t"..guard.batches[guard.position].."\t"..fields.catalogEncode(storage).."\n"
    if not fileAdapter.writeBytes(io,requestFile,text) then guard.failed="The native filesystem check could not be requested.";return nil,guard.failed end
    guard.sent=true
  end
  if guard.poll<0.05 then return false end
  guard.poll=0
  local result=read(resultFile,4096)
  local id,status
  if result then id,status=result:match("^([%w_-]+)\t([%w-]+)$") end
  if id==guard.id then
    if status~="ready" then guard.failed="A preset or recovery path is redirected or unavailable. The original was kept.";return nil,guard.failed end
    if guard.position<#guard.batches then
      guard.position=guard.position+1;guard.id=guard.id.."x";guard.sent=false
      return false
    end
    guard.ready=true;return true
  end
  if guard.elapsed>15 then guard.failed="The native filesystem check timed out. Restart the game with the updated native plugin.";return nil,guard.failed end
  return false
end
local function rescan()
  tasks={};refreshPending={};taskErrors={}
  for name,source in pairs(state.library.presets) do
    if queueFactory.eligible(source) then tasks[#tasks+1]=name;refreshPending[name]=true end
  end
  local keep={}
  for _,name in ipairs(tasks) do keep[name]=true end
  queue.prune(keep)
  table.sort(tasks);cursor=0;discover=false
end
helpers.schedulePresetMigration=function()
  discover,active=true,true
  if disabled then disabled=false;initialized=false;guard=nil end
end
helpers.startPresetMigration=function()
  started,active=true,true;batch=freshBatch();guard=nil
end
helpers.requestPresetUpgradeLoad=function(name)
  if not queueFactory.eligible(state.library.presets[name]) then message("This preset format cannot be upgraded automatically. Its source was kept.","error");return false end
  if disabled then message("Automatic upgrades are paused because recovery needs attention. Check the Activity Log, then Refresh.","error");return false end
  active=true;discover=true
  pendingLoad={name=name,session=state.appearanceTrace.session,fingerprint=fileFingerprint(presetPath(name),MAX_PRESET_BYTES)}
  message("This preset will load after its automatic upgrade. If its body is unknown, choose it in CET.")
  return true
end
helpers.cancelPresetUpgradeLoad=function()pendingLoad=nil end
helpers.beginPresetMigrationRandomize=function()randomizing=true;randomizeElapsed=0 end
helpers.endPresetMigrationRandomize=function()randomizing=false end
helpers.updatePresetMigration=function(delta)
  if not started or not active or disabled then return end
  if randomizing then
    randomizeElapsed=randomizeElapsed+delta
    if not state.app.inCustomization or randomizeElapsed>15 then randomizing=false end
    if randomizing then return end
  end
  if guard then guard.elapsed=guard.elapsed+delta;guard.poll=guard.poll+delta end
  if pendingLoad and (not state.app.inCustomization or state.library.selected~=pendingLoad.name
      or state.appearanceTrace.session~=pendingLoad.session) then pendingLoad=nil end
  if state.load.auto or state.load.needsContinue or state.load.pendingChange or fileExists(TRANSACTION_FILE) then return end
  if not initialized then
    local ready,reason=checked("__upgrade_check__","bootstrap")
    if ready==nil then disabled=true;message(reason,"error");return end
    if not ready then return end
    local ok,error=service.load()
    if not ok then disabled=true;message(error,"error");return end
    recovery={}
    local latest={}
    for _,record in ipairs(service.records()) do latest[record.storage]=record end
    for _,record in pairs(latest) do recovery[#recovery+1]=record end
    initialized=true;guard=nil
  end
  if recovery and #recovery>0 then
    local record=recovery[#recovery]
    local backupBatch=record.backup:match("^([^/]+)/")
    local ready,reason=checked(record.storage,"recover",backupBatch)
    if ready==nil then message(reason,"error");table.remove(recovery);guard=nil;return end
    if not ready then return end
    local restored,error=service.recover(record.storage)
    if not restored then log("[AUTO UPGRADE RECOVERY] "..record.storage..": "..tostring(error),"error") end
    table.remove(recovery);guard=nil
    return
  elseif recovery then
    recovery=nil
    refreshPresets("upgrade recovery")
    discover=true
  end
  if discover then rescan() end
  if pendingBody then
    local request=pendingBody
    local row
    for _,item in ipairs(queue.rows()) do if item.name==request.name then row=item end end
    if not row or row.phase~="body" then pendingBody=nil;return end
    batch=taskBatches[request.name] or batch
    local backupBatch
    for _,record in ipairs(service.records()) do if record.storage==row.storage then backupBatch=record.backup:match("^([^/]+)/") end end
    local ready,reason=checked(row.storage,"assign",backupBatch)
    if ready==nil then pendingBody=nil;message(reason,"error");return end
    if not ready then return end
    local ok,error=queue.assignBody(request.name,request.body)
    pendingBody=nil;guard=nil
    if not ok then message(error,"error") end
    return
  end
  if not state.app.inCustomization then
    queue.tick({editorOpen=false,busy=false})
    if #tasks==0 then active=false end
    return
  end
  local body=helpers.editorBody()
  if body~="Male" and body~="Female" then return end
  if #tasks>0 then
    if cursor<1 or cursor>#tasks then cursor=1 end
    local name=tasks[cursor]
    local source=state.library.presets[name]
    local storage=source and source.storage or name
    local row
    for _,item in ipairs(queue.rows()) do if item.name==name then row=item;break end end
    if (not row or refreshPending[name]) and not taskErrors[name] then
      refreshPending[name]=nil
      local fingerprint=source and fileFingerprint(presetPath(name),MAX_PRESET_BYTES)
      local fresh=source and readPresetFile(presetPath(name))
      if not fingerprint or not fresh or fileFingerprint(presetPath(name),MAX_PRESET_BYTES)~=fingerprint then
        taskErrors[name]=true;message("An old CPM preset could not be read consistently. Its original was kept.","warning")
      else
        fresh.storage=storage
        if pendingLoad and pendingLoad.name==name and pendingLoad.fingerprint~=fingerprint then pendingLoad=nil end
        if not queueFactory.eligible(fresh) then
          state.library.presets[name]=fresh
          if pendingLoad and pendingLoad.name==name then
            pendingLoad=nil
          end
          table.remove(tasks,cursor)
          if cursor>#tasks then cursor=1 end
          discover=true;invalidateViewCache();return
        end
        local added=queue.enqueue(name,fresh,fingerprint)
        if added or not taskBatches[name] then taskBatches[name]=freshBatch() end
        if not added and row and row.phase=="failed" then queue.retry(name) end
      end
      return
    end
    if not row or taskErrors[name] then
      table.remove(tasks,cursor)
      if cursor>#tasks then cursor=1 end
      return
    end
    batch=taskBatches[name] or batch
    if row.phase~="body" and row.phase~="failed" and row.phase~="complete" and (row.phase=="queued" or row.phase=="finish" or row.body==body) then
      local backupBatch
      for _,record in ipairs(service.records()) do if record.storage==storage then backupBatch=record.backup:match("^([^/]+)/") end end
      local mustCheck=row.phase=="queued" or row.phase=="stage" or row.phase=="install" or not guard or not guard.ready
      if mustCheck then
        local ready,reason=checked(storage,row.phase,backupBatch)
        if ready==nil then queue.reject(name,reason);guard=nil;return end
        if not ready then return end
      end
      local _,options=getOptions(true)
      queue.tick({editorOpen=true,body=body,session=state.appearanceTrace.session,options=options,
        busy=false,allowedStorage=storage})
      if row.phase=="install" then guard=nil end
    else
      cursor=cursor%#tasks+1;guard=nil
    end
  end
  local complete,partial,failed,bodyNeeded,pending=0,0,0,0,0
  for _ in pairs(taskErrors) do failed=failed+1 end
  local seen={}
  for _,row in ipairs(queue.rows()) do
    seen[row.name]=true
    if row.phase=="complete" then complete=complete+1;if (row.missing or 0)>0 then partial=partial+1 end
    elseif row.phase=="failed" then failed=failed+1
    elseif row.phase=="body" then bodyNeeded=bodyNeeded+1
    else pending=pending+1 end
  end
  for _,name in ipairs(tasks) do if not seen[name] and not taskErrors[name] then pending=pending+1 end end
  if pendingLoad and pendingLoad.ready then
    local request=pendingLoad;pendingLoad=nil
    if state.library.selected==request.name and helpers.presetBodyCompatible(state.library.presets[request.name],body) then
      resetLoadState();stateModel.prepareAutomaticLoad(state.load);loadPreset()
      if state.load.needsContinue then state.load.auto=true end
    end
    return
  end
  if complete+failed+bodyNeeded+pending>0 then
    message(("Automatic upgrades: %d complete (%d partial), %d pending, %d failed. %d need a body choice in CET.")
      :format(complete,partial,pending,failed,bodyNeeded),(failed+partial)>0 and "warning" or "info")
  end
  if pending==0 and bodyNeeded==0 then active=false end
end
return _ENV
