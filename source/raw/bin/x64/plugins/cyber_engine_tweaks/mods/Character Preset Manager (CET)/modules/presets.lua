local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

presetTypeName = function(preset)
  local format = tonumber(preset and preset.format) or 4
  return (format == 7 or format == 8) and "CPM" or "ACU"
end

state.presetEntryCount = function(preset)
  if not preset then return 0 end
  if preset.entries then return #preset.entries end
  return tonumber(preset.entryCount) or 0
end

state.dehydratePreset = function(preset)
  if not preset or not preset.entries then return false end
  preset.entryCount = #preset.entries
  preset.entryCountKnown = true
  preset.entries = nil
  preset.lazy = true
  return true
end

state.invalidatePreflight = function()
  state.load.comparison = nil
  state.load.preflight = nil
  state.load.preflightDirty = true
  state.load.preflightPresetName = nil
end


return _ENV
