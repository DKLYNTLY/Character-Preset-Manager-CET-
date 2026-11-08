local journal = require("modules/domain/upgrade_journal")
local MAX_BYTES = 1048576
local ROOT = "Data/Recovery/Preset Upgrades/"
local function copy(value)
  local result={}
  for key,item in pairs(value) do result[key]=item end
  return result
end
local function new(files)
  local entries,loaded,journalBytes={},false,nil
  local api={}
  local function sourcePath(entry) return "Character Presets/"..entry.storage..".preset" end
  local function backupPath(entry) return ROOT..entry.backup end
  local function find(storage)
    for index=#entries,1,-1 do
      local entry=entries[index]
      if entry.storage==storage then return entry,index end
    end
  end
  local function persist(entry,index)
    local nextEntries={}
    for position,item in ipairs(entries) do nextEntries[position]=copy(item) end
    nextEntries[index or (#nextEntries+1)]=copy(entry)
    local text=journal.encode(nextEntries)
    if not text then return nil,"Upgrade journal exceeds its limits or contains an invalid record." end
    if not files.saveJournal(text,journalBytes) then loaded=false;return nil,"The upgrade journal could not be saved safely." end
    if files.readJournal(journal.MAX_BYTES)~=text then loaded=false;return nil,"The upgrade journal readback failed." end
    journalBytes,entries=text,nextEntries
    return copy(entry)
  end
  local function original(entry)
    local bytes=files.read(backupPath(entry),MAX_BYTES)
    if not bytes or files.fingerprint(backupPath(entry))~=entry.sourceFingerprint then
      return nil,"The original upgrade backup could not be verified."
    end
    return bytes
  end
  function api.load()
    loaded=false
    local bytes,reason=files.readJournal(journal.MAX_BYTES)
    if not bytes then
      if reason~="missing" then return nil,"The upgrade journal could not be read safely." end
      entries,journalBytes,loaded={},nil,true
      return true
    end
    local decoded=journal.decode(bytes)
    if not decoded then return nil,"The upgrade journal is invalid. Original files were left unchanged." end
    entries,journalBytes,loaded=decoded,bytes,true
    return true
  end
  function api.records()
    if not loaded then return nil end
    local result={}
    for index,entry in ipairs(entries) do result[index]=copy(entry) end
    return result
  end
  function api.backup(storage,format,body,expectedFingerprint)
    if not loaded then return nil,"Load the upgrade journal before creating backups." end
    if not journal.validStorage(storage) then return nil,"The preset path is invalid." end
    local probe={storage=storage}
    local source=sourcePath(probe)
    local before=files.fingerprint(source)
    local bytes=files.read(source,MAX_BYTES)
    if not bytes or not before or (expectedFingerprint and expectedFingerprint~=before) or files.fingerprint(source)~=before then return nil,"The source preset changed or could not be read." end
    local entry,index=find(storage)
    if entry and entry.sourceFingerprint~=before then
      if expectedFingerprint~=before then return nil,"The source preset changed after its backup was recorded." end
      entry,index=nil,nil
    end
    if entry then
      if entry.phase~="reserved" then
        local saved,reason=original(entry)
        if not saved or saved~=bytes then return nil,reason or "The backup no longer matches the source." end
        return copy(entry)
      end
    else
      local batch=files.newBatch()
      if type(batch)~="string" or #batch>64 or not batch:match("^[%w_-]+$") then return nil,"The backup batch name is invalid." end
      entry={storage=storage,sourceFingerprint=before,backup=batch.."/"..storage..".preset",
        sourceFormat=format,body=body or "Unknown",phase="reserved",replacementFingerprint=""}
      if files.exists(backupPath(entry)) then return nil,"The backup destination already exists. Nothing was overwritten." end
      local saved,reason=persist(entry)
      if not saved then return nil,reason end
      entry,index=find(storage)
    end
    local destination=backupPath(entry)
    if not files.exists(destination) and not files.create(destination,bytes) then return nil,"The original preset could not be backed up." end
    local saved=files.read(destination,MAX_BYTES)
    if saved~=bytes or files.fingerprint(destination)~=before or files.fingerprint(source)~=before then
      return nil,"The backup readback or source check failed. The original preset was left unchanged."
    end
    local verified=copy(entry);verified.phase="verified"
    return persist(verified,index)
  end
  function api.assignBody(storage,fingerprint,body)
    if not loaded then return nil,"The upgrade journal is not loaded." end
    local entry,index=find(storage)
    if not entry or entry.sourceFingerprint~=fingerprint or files.fingerprint(sourcePath(entry))~=fingerprint then
      return nil,"The source changed. Its body assignment was not saved."
    end
    if body~="Male" and body~="Female" then return nil,"Choose Male or Female." end
    if entry.phase~="reserved" and entry.phase~="verified" then return nil,"This upgrade is already prepared." end
    local changed=copy(entry);changed.body=body
    return persist(changed,index)
  end
  function api.prepare(storage,fingerprint,replacementFingerprint)
    if not loaded then return nil,"The upgrade journal is not loaded." end
    local entry,index=find(storage)
    if not entry or entry.phase~="verified" or entry.sourceFingerprint~=fingerprint
        or entry.body=="Unknown" or files.fingerprint(sourcePath(entry))~=fingerprint then
      return nil,"The verified source and body must still match before preparing an upgrade."
    end
    local bytes,reason=original(entry)
    if not bytes then return nil,reason end
    if files.read(sourcePath(entry),MAX_BYTES)~=bytes then return nil,"The source no longer matches its backup." end
    local changed=copy(entry);changed.phase="prepared";changed.replacementFingerprint=replacementFingerprint
    return persist(changed,index)
  end
  function api.recover(storage)
    if not loaded then return nil,"The upgrade journal is not loaded." end
    local entry,index=find(storage)
    if not entry then return nil,"No upgrade recovery record exists for this preset." end
    if entry.phase=="reserved" then return api.backup(entry.storage,entry.sourceFormat,entry.body) end
    local bytes,reason=original(entry)
    if not bytes then return nil,reason end
    local path=sourcePath(entry)
    if entry.phase=="complete" then
      local current=files.read(path,MAX_BYTES)
      if current and files.fingerprint(path)==entry.replacementFingerprint and files.validateReplacement(current,entry) then
        return copy(entry),"complete"
      end
      return nil,"The completed preset was changed or removed. It was left unchanged."
    end
    if not files.exists(path) then
      if entry.phase~="prepared" then return nil,"The original preset was removed. It was not recreated." end
      if not files.create(path,bytes) then return nil,"The missing original preset could not be restored safely." end
      if files.read(path,MAX_BYTES)~=bytes or files.fingerprint(path)~=entry.sourceFingerprint then
        return nil,"The restored original preset could not be verified."
      end
    end
    local fingerprint=files.fingerprint(path)
    local current=files.read(path,MAX_BYTES)
    if fingerprint==entry.sourceFingerprint and current==bytes then
      local reset=copy(entry);reset.phase="verified";reset.replacementFingerprint=""
      if entry.phase=="verified" then return copy(entry),"original" end
      local saved,error=persist(reset,index)
      return saved,saved and "original" or error
    end
    if entry.replacementFingerprint~="" and fingerprint==entry.replacementFingerprint then
      if not current or not files.validateReplacement(current,entry) then return nil,"The replacement preset failed verification." end
      if entry.phase=="complete" then return copy(entry),"complete" end
      local complete=copy(entry);complete.phase="complete"
      local saved,error=persist(complete,index)
      return saved,saved and "complete" or error
    end
    return nil,"The preset contains an unexpected edit. It was left unchanged."
  end
  return api
end
return {new=new,ROOT=ROOT,JOURNAL=ROOT.."Upgrade Journal.txt",MAX_BYTES=MAX_BYTES}
