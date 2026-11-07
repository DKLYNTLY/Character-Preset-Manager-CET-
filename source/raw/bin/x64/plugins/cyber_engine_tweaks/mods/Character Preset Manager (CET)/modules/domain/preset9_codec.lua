local records = require("modules/domain/format9_codec")
local names = require("modules/domain/names")
local paths = require("modules/domain/paths")
local HEADER = "# CPM Preset\n# Format: 9\n"
local fields = {
  {"Name","presetName",64}, {"Source","source",128}, {"Created","created",64},
  {"Modified","modified",64}, {"Notes","notes",512}, {"Tags","tags",128},
  {"Favorite","favorite"}, {"Library folder","libraryFolder",1024},
}

local function legacyRows(entries)
  local rows, counts = {}, {}
  for _, entry in ipairs(entries or {}) do
    local slot = entry.slot or "[unavailable]"
    local group = slot .. "\n" .. tostring(entry.key)
    counts[group] = (counts[group] or 0) + 1
    local row = {slot=slot,name="[unavailable]",occurrence=counts[group],state="Selected",
      legacyKey=entry.key,legacyChoice=entry.choice,value=tostring(entry.index or 0),
      kind="Legacy index",choices={tostring(entry.index or 0)}}
    local field, value
    if type(entry.choice) == "string" then field,value=entry.choice:match("^([^:]+):(.*)$") end
    if value and value ~= "" then
      if field == "definitions" then row.kind,row.choices="Appearance",{value}
      elseif field == "morphNames" then row.kind,row.choices="Morph",{value}
      elseif field == "options" then row.kind,row.choices="Legacy label",{value} end
    end
    rows[#rows+1] = row
  end
  return rows
end

local function encode(preset, modName)
  local rows = preset.format9Rows or legacyRows(preset.entries)
  local body,voice = preset.sourceBody or "Unknown",preset.sourceVoice or "Unknown"
  local text = records.encode(rows,body,voice)
  if not text then return nil end
  local header = {HEADER:sub(1,-2)}
  for _, field in ipairs(fields) do
    local value = preset[field[2]]
    if field[2] == "favorite" then value=value == true and "Yes" or "No"
    elseif field[2] == "libraryFolder" then
      value=value or ""
      if value ~= "" and not paths.validRelativePath(value) then return nil end
      if value == "" then value="/" end
    else
      if field[2] == "source" then value=value or modName end
      value=names.sanitizeMetadata(value,field[3])
    end
    header[#header+1] = "# " .. field[1] .. ": " .. value
  end
  local result=table.concat(header,"\n") .. "\n" .. text:sub(#HEADER+1)
  if #result > 1048576 then return nil end
  return result
end

local function decode(contents, metadataOnly)
  if type(contents) ~= "string" or #contents > 1048576 then return nil end
  contents=contents:gsub("\r\n","\n")
  if contents:sub(1,#HEADER) ~= HEADER then return nil end
  local metadata,seen = {},{}
  local position=#HEADER+1
  while position <= #contents do
    local ending=contents:find("\n",position,true)
    if not ending then return nil end
    local line=contents:sub(position,ending-1)
    local label,value=line:match("^# ([%a ]+):%s?(.*)$")
    local found
    for _,field in ipairs(fields) do
      if label==field[1] then
        if seen[label] then return nil end
        seen[label],found=true,true
        if field[2]=="favorite" then
          if value~="Yes" and value~="No" then return nil end
          metadata.favorite=value=="Yes"
        elseif field[2]=="libraryFolder" then
          if value=="/" then value="" end
          if value~="" and not paths.validRelativePath(value) then return nil end
          metadata.libraryFolder=value
        else
          if #value>field[3] or value:find("%c") then return nil end
          if field[2]=="presetName" and value~="" and names.validatedPresetName(value)~=value then return nil end
          metadata[field[2]]=value
        end
      end
    end
    if not found then break end
    position=ending+1
  end
  local rows,body,voice=records.decode(HEADER..contents:sub(position))
  if not rows then return nil end
  local entries={}
  for _,row in ipairs(rows) do
    if row.state=="Selected" or row.state=="Off" then
      local selection
      if row.kind=="Appearance" then selection={kind="appearance",name=row.choices[1]}
      elseif row.kind=="Morph" then selection={kind="morph",morph_name=row.choices[1]}
      elseif row.kind=="Switcher" then selection={kind="switcher",names=row.choices} end
      entries[#entries+1]={key=row.legacyKey or row.name,slot=row.slot~="[unavailable]" and row.slot or nil,
        index=tonumber(row.value) or 0,choice=row.legacyChoice,selection=selection}
    end
  end
  if #entries==0 then return nil end
  metadata.format,metadata.managedByCpm=9,true
  metadata.notes,metadata.tags,metadata.favorite=metadata.notes or "",metadata.tags or "",metadata.favorite==true
  metadata.source=metadata.source or "Character Preset Manager (CET)"
  metadata.sourceBody,metadata.sourceVoice=body or "Unknown",voice or "Unknown"
  metadata.entryCount,metadata.entryCountKnown=#entries,true
  metadata.metadataLoaded,metadata.lazy=true,metadataOnly==true
  if not metadataOnly then metadata.entries,metadata.format9Rows=entries,rows end
  return metadata
end

local function sameAppearance(first,second)
  if not first or not second then return false end
  local encoded=records.encode(first.format9Rows or legacyRows(first.entries),first.sourceBody or "Unknown",first.sourceVoice or "Unknown")
  return encoded~=nil and encoded==records.encode(second.format9Rows or legacyRows(second.entries),
    second.sourceBody or "Unknown",second.sourceVoice or "Unknown")
end

return {encode=encode,decode=decode,sameAppearance=sameAppearance}
