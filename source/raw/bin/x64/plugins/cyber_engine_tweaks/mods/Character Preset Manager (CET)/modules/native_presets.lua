local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

local function fields(line)
  local result = {}
  for value in (line .. "\t"):gmatch("(.-)\t") do result[#result + 1] = value end
  return result
end

helpers.readNativePreset = function(path, metadataOnly)
  if path:sub(1, #PRESET_DIR + 1) ~= PRESET_DIR .. "/"
      or path:sub(-7):lower() ~= ".preset" then return nil end
  local fingerprint = fileFingerprint(path, MAX_PRESET_BYTES)
  if not fingerprint or not fingerprint:match("^2:%d+:%d+:%d+$") then return nil end
  local cachePath = CATALOG_DIR .. "/Parsed Presets/p1-" .. fingerprint:gsub(":", "-") .. ".txt"
  local contents = readBoundedFile(cachePath, MAX_PRESET_BYTES * 4 + 65536)
  if not contents then return nil end
  local header, meta, entries, warnings = nil, {}, {}, {}
  local count, finished = 0, false
  for line in (contents .. "\n"):gmatch("([^\r\n]*)\r?\n") do
    if line ~= "" then
      if finished then return nil end
      local row = fields(line)
      if not header then
        if #row ~= 5 or row[1] ~= "CPMParsed" or row[2] ~= "1" or row[3] ~= fingerprint then return nil end
        local format, total = tonumber(row[4]), tonumber(row[5])
        if not format or format ~= math.floor(format) or not total or total < 1
            or total > MAX_PRESET_ENTRIES or total ~= math.floor(total) then return nil end
        header = { format = format, total = total }
      elseif row[1] == "meta" and #row == 3 and count == 0 then
        local allowed = { source = true, created = true, modified = true, notes = true,
          tags = true, favorite = true, managedByCpm = true, presetName = true,
          libraryFolder = true, malformed = true }
        if not allowed[row[2]] or meta[row[2]] ~= nil then return nil end
        meta[row[2]] = catalogDecode(row[3])
      elseif row[1] == "entry" and #row == 5 then
        local key, index = catalogDecode(row[2]), tonumber(row[3])
        local slot, choice = catalogDecode(row[4]), catalogDecode(row[5])
        if key == "" or #key > MAX_PRESET_KEY_BYTES or optionIndexValidationError(index)
            or #slot > MAX_PRESET_KEY_BYTES or slot:find("%c")
            or #choice > MAX_PRESET_KEY_BYTES * 4 or choice:find("%c")
            or (choice ~= "" and not stableChoiceIdentity(choice)) then return nil end
        count = count + 1
        if count > header.total then return nil end
        if not metadataOnly then
          entries[#entries + 1] = { key = key, index = index,
            slot = slot ~= "" and slot or nil, choice = choice ~= "" and choice or nil }
        end
      elseif row[1] == "warning" and #row == 3 then
        local number = tonumber(row[2])
        if not number or number < 1 or number > MAX_PRESET_LINES or #warnings >= 20 then return nil end
        warnings[#warnings + 1] = { number = number, text = catalogDecode(row[3]) }
      elseif row[1] == "end" and #row == 2 and tonumber(row[2]) == count and count == header.total then
        finished = true
      else
        return nil
      end
    end
  end
  if not header or not finished then return nil end
  local malformed = tonumber(meta.malformed) or 0
  if malformed < #warnings or malformed > MAX_PRESET_LINES or malformed ~= math.floor(malformed) then return nil end
  for _, warning in ipairs(warnings) do
    log(("[FILES] Malformed preset line skipped: file='%s' line=%d content='%s'.")
      :format(path, warning.number, warning.text), "warn")
  end
  if malformed > 0 then
    log(("[FILES] Preset '%s' contains %d malformed lines; valid entries remain loadable.")
      :format(path, malformed), "warn")
  end
  local name, folder
  if meta.managedByCpm == "1" then
    if meta.presetName and validatedPresetName(meta.presetName) == meta.presetName then name = meta.presetName end
    folder = meta.libraryFolder == "/" and "" or meta.libraryFolder
    if folder and folder ~= "" and not validRelativePath(folder) then folder = nil end
  end
  state.nativeCatalog.parsedReads = (state.nativeCatalog.parsedReads or 0) + 1
  if not metadataOnly then
    log(("[NATIVE PRESET] Read %d saved options from the DLL's parsed cache: '%s'.")
      :format(count, path), "info")
  end
  return {
    format = header.format, source = meta.source or "Legacy or ACU-compatible",
    created = meta.created, modified = meta.modified,
    notes = sanitizeMetadata(meta.notes or "", 512), tags = sanitizeMetadata(meta.tags or "", 128),
    favorite = meta.favorite == "1", managedByCpm = meta.managedByCpm == "1",
    presetName = name, libraryFolder = folder,
    entries = not metadataOnly and entries or nil, entryCount = count, entryCountKnown = true,
    metadataLoaded = true, lazy = metadataOnly == true, nativeSourceFingerprint = fingerprint,
  }
end

return _ENV
