local runtime = assert(require("modules/runtime"), "Character Preset Manager runtime did not load")
if setfenv then setfenv(1,runtime) end
local _ENV = runtime
local identityConversions=setmetatable({}, {__mode="k"})

local function legacyCpm(preset)
  return require("modules/application/preset_migration").eligible(preset)
end

local conversion = require("modules/application/preset_conversion").new(runtime)
local captureTargets = conversion.capture
local catalogSignature = conversion.signature

helpers.convertAcuForLoad=function(source,options)
  if source.importKind=="acu-v2" then
    local cached=identityConversions[source]
    if source.fingerprint and cached and cached.fingerprint==source.fingerprint then
      return cached.preset
    end
    local rows={}
    for _,entry in ipairs(source.entries or {}) do
      local selection=entry.selection or {}
      local row={name=entry.key,state="Selected",slot=entry.slot,value=tostring(entry.index or 0)}
      if selection.kind=="appearance" then row.kind,row.choices="Appearance",{selection.name}
      elseif selection.kind=="morph" then row.kind,row.choices="Morph",{selection.morph_name}
      elseif selection.kind=="switcher" then row.kind,row.choices="Switcher",selection.names
      else row.state="Not captured" end
      rows[#rows+1]=row
    end
    local converted={format=9,format9Rows=rows,entries=source.entries,sourceBody=helpers.presetBody(source)}
    if source.fingerprint then identityConversions[source]={fingerprint=source.fingerprint,preset=converted} end
    return converted
  end
  local signature=source.fingerprint and catalogSignature(source,options)
  local cached=identityConversions[source]
  if signature and cached and cached.fingerprint==source.fingerprint and cached.signature==signature then
    return cached.preset
  end
  local captured,_,missing,assumed=captureTargets(source,options)
  if captured and signature then
    identityConversions[source]={fingerprint=source.fingerprint,signature=signature,preset=captured}
  end
  if captured then
    log(("[ACU UPGRADE] Prepared %d choices for the format 9 loader; %d current-index mappings; %d unavailable.")
      :format(#captured.entries,assumed,missing),"info")
  end
  return captured
end

helpers.canUpgradePreset9 = legacyCpm

helpers.getPresetUpgrade = function() return nil end
helpers.cancelPresetUpgrade = function()
  if helpers.cancelPresetUpgradeLoad then helpers.cancelPresetUpgradeLoad() end
end
local function requestUpgrade()
  if helpers.schedulePresetMigration then helpers.schedulePresetMigration() end
  setStatus("load","Older CPM presets upgrade automatically after a verified backup. Choose missing body types in CET.")
end
helpers.previewPresetUpgrade=requestUpgrade
helpers.confirmPresetUpgrade=requestUpgrade
return _ENV
