local function presetBody(preset)
  if not preset then return "Unknown" end
  if preset.sourceBody=="Male" or preset.sourceBody=="Female" then return preset.sourceBody end
  if preset.detectedBody=="Male" or preset.detectedBody=="Female" then return preset.detectedBody end
  local metadata=preset.importMetadata
  if metadata and type(metadata.isMale)=="boolean" then return metadata.isMale and "Male" or "Female" end
  return "Unknown"
end

local function detect(preset)
  local female,male=false,false
  for _,entry in ipairs(preset.entries or {}) do
    if entry.slot=="breast" or entry.key=="breast" or entry.key=="LocKey#14444638123505366956" then female=true end
    if entry.slot=="beard" or entry.key=="beard" or entry.key=="LocKey#7487713073032863221" then male=true end
  end
  if female==male then return "Unknown" end
  return male and "Male" or "Female"
end

local function visible(preset,body)
  local source=presetBody(preset)
  return (body=="Male" or body=="Female") and source==body
end

return {presetBody=presetBody,visible=visible,detect=detect}
