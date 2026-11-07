local runtime=assert(require("modules/runtime"),"Character Preset Manager runtime did not load")
if setfenv then setfenv(1,runtime) end
local _ENV=runtime
local filter=require("modules/domain/body_filter")

helpers.editorBody=function()
  if not state.app.inCustomization then return "Unknown" end
  local ok,value=pcall(function()
    return Game.GetCharacterCustomizationSystem():GetState():IsBodyGenderMale()
  end)
  if not ok or type(value)~="boolean" then return "Unknown" end
  return value and "Male" or "Female"
end

helpers.presetVisibleForBody=function(preset,body)
  if state.preferences.presetBodyFilter=="all" then return true end
  return filter.visible(preset,body)
end

helpers.presetBodyCompatible=function(preset,body)
  local source=filter.presetBody(preset)
  return source=="Unknown" or body=="Unknown" or source==body
end

helpers.setPresetBodyFilter=function(mode)
  local previous=state.preferences.presetBodyFilter
  state.preferences.presetBodyFilter=mode=="all" and "all" or "body"
  if not writeConfig() then
    state.preferences.presetBodyFilter=previous
    state.status.settings="The preset visibility setting could not be saved."
    return
  end
  invalidateViewCache()
  state.status.settings="Preset visibility saved."
end

helpers.presetBody=function(preset)
  return filter.presetBody(preset)
end

helpers.presetBodyLabel=function(_,label)
  return label
end

return _ENV
