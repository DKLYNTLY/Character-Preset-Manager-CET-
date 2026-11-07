local function presetBody(preset)
  if not preset then return "Unknown" end
  if preset.sourceBody=="Male" or preset.sourceBody=="Female" then return preset.sourceBody end
  local metadata=preset.importMetadata
  if metadata and type(metadata.isMale)=="boolean" then return metadata.isMale and "Male" or "Female" end
  return "Unknown"
end

local function visible(preset,body)
  local source=presetBody(preset)
  return body=="Unknown" or source=="Unknown" or body==source
end

return {presetBody=presetBody,visible=visible}
