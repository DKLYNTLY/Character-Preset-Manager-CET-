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
  return filter.visible(preset,body)
end

helpers.presetBody=function(preset)
  return filter.presetBody(preset)
end

helpers.presetBodyLabel=function(_,label)
  return label
end

return _ENV
