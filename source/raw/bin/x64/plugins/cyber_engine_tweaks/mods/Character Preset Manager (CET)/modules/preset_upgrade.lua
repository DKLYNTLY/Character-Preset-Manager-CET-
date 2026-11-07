local runtime = assert(require("modules/runtime"), "Character Preset Manager runtime did not load")
if setfenv then setfenv(1,runtime) end
local _ENV = runtime
local codec9 = require("modules/domain/preset9_codec")
local capture9 = require("modules/adapters/format9_capture")
local library = require("modules/domain/library")
local preview

local function legacyCpm(preset)
  return preset and preset.format ~= 9
    and (preset.managedByCpm or (tonumber(preset.format) or 4) >= 5)
end

local function captureTargets(source, options)
  local groups = {}
  for _, option in ipairs(options) do
    local ok,key = pcall(optionKey,option)
    if ok and key then
      local group=groups[key] or {}
      group[#group+1]=option
      groups[key]=group
    end
  end
  local rows,details,missing,assumed = {},{},0,0
  local counts={}
  for _, entry in ipairs(source.entries or {}) do
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

helpers.canUpgradePreset9 = legacyCpm

helpers.getPresetUpgrade = function()
  if preview and (not state.app.inCustomization or preview.sourceName~=state.library.selected) then preview=nil end
  return preview
end

helpers.cancelPresetUpgrade = function() preview=nil end

helpers.previewPresetUpgrade = function()
  preview=nil
  if not state.app.inCustomization or state.load.auto or state.load.needsContinue or state.load.pendingChange then
    setStatus("load","Open the editor and finish the current load before previewing an upgrade.",true)
    return
  end
  local sourceName=state.library.selected
  local source=sourceName and hydrateNamedPreset(sourceName)
  if not legacyCpm(source) then setStatus("load","Select an older CPM preset to upgrade.",true); return end
  local path=presetPath(sourceName)
  local fingerprint=fileFingerprint(path,MAX_PRESET_BYTES)
  if not fingerprint then setStatus("load","The source preset could not be checked safely.",true); return end
  local _,options=getOptions(true)
  if not options then setStatus("load","The live customization catalog could not be read.",true); return end
  local ok,preset,details,missing,assumed=pcall(captureTargets,source,options)
  if not ok or not preset then
    setStatus("load","No restorable choices could be prepared for this upgrade.",true); return
  end
  local context=helpers.capturePreset9(options)
  preview={sourceName=sourceName,fingerprint=fingerprint,preset=preset,details=details,missing=missing,
    assumed=assumed,newName=baseName(sourceName).." - Format 9",catalogBody=context and context.sourceBody,
    canonical=codec9.encode(preset,MOD_NAME)}
  setStatus("load","Review the proposed choices, then save a new format 9 copy.")
end

helpers.confirmPresetUpgrade = function()
  local request=helpers.getPresetUpgrade()
  if not request or state.load.auto or state.load.needsContinue or state.load.pendingChange then return end
  local name,reason=validatedPresetName(request.newName)
  if not name then setStatus("load",reason,true); return end
  if findPresetCollision(name) or fileExists(PRESET_DIR.."/"..name..".preset") then
    setStatus("load","Choose a new name for the upgraded copy. The original preset will be kept.",true); return
  end
  local source=hydrateNamedPreset(request.sourceName)
  if not source or fileFingerprint(presetPath(request.sourceName),MAX_PRESET_BYTES)~=request.fingerprint then
    preview=nil
    setStatus("load","The source changed. Preview the upgrade again before saving.",true); return
  end
  local _,options=getOptions(true)
  if not options then setStatus("load","Reopen the editor and preview the upgrade again.",true); return end
  local ok,captured=pcall(captureTargets,source,options)
  local context=helpers.capturePreset9(options)
  if not ok or not captured or codec9.encode(captured,MOD_NAME)~=request.canonical
      or (context and context.sourceBody)~=request.catalogBody then
    preview=nil
    setStatus("load","The catalog or body changed. Review a fresh upgrade preview before saving.",true); return
  end
  local storage=uniqueStorageName(name)
  if storage~=name then setStatus("load","Choose another name for the format 9 copy.",true); return end
  local timestamp=logTimestamp()
  local preset=library.newSavedPreset(source,captured.entries,name,storage,timestamp,timestamp,9,MOD_NAME)
  preset.format9Rows=captured.format9Rows
  preset.sourceBody,preset.sourceVoice="Unknown","Unknown"
  local path=PRESET_DIR.."/"..storage..".preset"
  if not writePresetPath(path,preset,false) then setStatus("load","The format 9 copy could not be saved safely.",true); return end
  state.library.presets[name]=preset
  if not writeCatalog(state.library.presets,state.library.folders,state.library.manualFolders,state.library.ignoredPhysicalFolders) then
    state.library.presets[name]=nil
    local removed=removeFileList({path})
    setStatus("load",removed and "The folder list could not be saved, so the upgrade was cancelled."
      or "The folder list could not be saved. The new copy remains on disk for recovery.",true)
    return
  end
  state.library.selected=name
  state.library.presetNotes,state.library.presetTags=preset.notes,preset.tags
  invalidateViewCache()
  writeInventory(state.library.presets,state.library.folders)
  preview=nil
  log(("[UPGRADE] Saved '%s' from '%s'. %d choices used the current catalog at the saved index; %d could not be captured.")
    :format(name,request.sourceName,request.assumed,request.missing),"info")
  setStatus("load","Saved the format 9 copy. Load it to check the appearance.",false,
    request.missing>0 and "warning" or "success")
end

return _ENV
