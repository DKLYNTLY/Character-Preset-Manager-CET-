local paths = require("modules/domain/paths")
local codecs = require("modules/domain/codecs")
local MAX_BYTES = 1048576
local MAX_RECORDS = 8192
local phases = {reserved=true,verified=true,prepared=true,complete=true}
local fields = {"storage","sourceFingerprint","backup","body","sourceFormat","phase","replacementFingerprint"}
local function fingerprint(value)
  return type(value)=="string" and #value>0 and #value<=128 and not value:find("%c")
end
local function validStorage(value)
  if not paths.validNativeRelativePath(value,12) then return false end
  for part in value:gmatch("[^/]+") do
    local stem=part:match("^[^%.]+"):upper()
    if stem=="CON" or stem=="PRN" or stem=="AUX" or stem=="NUL"
        or stem:match("^COM[1-9]$") or stem:match("^LPT[1-9]$") then return false end
  end
  return true
end
local function valid(entry)
  if type(entry)~="table" or not validStorage(entry.storage)
      or not paths.validNativeRelativePath(entry.backup,13) then return false end
  local batch,storage=entry.backup:match("^([%w_-]+)/(.*)%.preset$")
  if not batch or #batch>64 or storage~=entry.storage then return false end
  if not fingerprint(entry.sourceFingerprint) or not phases[entry.phase] then return false end
  if entry.body~="Unknown" and entry.body~="Male" and entry.body~="Female" then return false end
  if type(entry.sourceFormat)~="number" or entry.sourceFormat<1 or entry.sourceFormat>8
      or entry.sourceFormat~=math.floor(entry.sourceFormat) then return false end
  if entry.replacementFingerprint~="" and not fingerprint(entry.replacementFingerprint) then return false end
  if (entry.phase=="prepared" or entry.phase=="complete") and entry.replacementFingerprint=="" then return false end
  if entry.phase~="prepared" and entry.phase~="complete" and entry.replacementFingerprint~="" then return false end
  return true
end
local function encode(entries)
  if type(entries)~="table" or #entries>MAX_RECORDS then return nil end
  local lines,seen,backups,spellings={"CPM-UPGRADES\t1"},{},{},{}
  for _,entry in ipairs(entries) do
    if not valid(entry) then return nil end
    local normalized=entry.storage:lower()
    if spellings[normalized] and spellings[normalized]~=entry.storage then return nil end
    spellings[normalized]=entry.storage
    local key=normalized.."\31"..entry.sourceFingerprint
    if seen[key] or backups[entry.backup:lower()] then return nil end
    seen[key],backups[entry.backup:lower()]=true,true
    local values={}
    for _,field in ipairs(fields) do values[#values+1]=codecs.catalogEncode(entry[field]) end
    lines[#lines+1]=table.concat(values,"\t")
  end
  local text=table.concat(lines,"\n").."\n"
  return #text<=MAX_BYTES and text or nil
end
local function decode(text)
  if type(text)~="string" or #text>MAX_BYTES then return nil end
  local entries,lineNumber={},0
  for line in text:gmatch("([^\n]*)\n") do
    lineNumber=lineNumber+1
    if lineNumber==1 then
      if line~="CPM-UPGRADES\t1" then return nil end
    else
      local values={}
      for value in (line.."\t"):gmatch("([^\t]*)\t") do values[#values+1]=codecs.catalogDecode(value) end
      if #values~=#fields then return nil end
      local entry={}
      for index,field in ipairs(fields) do entry[field]=values[index] end
      entry.sourceFormat=tonumber(entry.sourceFormat)
      entries[#entries+1]=entry
      if #entries>MAX_RECORDS then return nil end
    end
  end
  if lineNumber==0 or encode(entries)~=text then return nil end
  return entries
end
return {encode=encode,decode=decode,validStorage=validStorage,MAX_BYTES=MAX_BYTES,MAX_RECORDS=MAX_RECORDS}
