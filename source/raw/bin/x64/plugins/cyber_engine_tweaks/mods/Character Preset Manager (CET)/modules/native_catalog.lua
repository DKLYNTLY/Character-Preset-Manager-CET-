local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

local function decodeNativeField(value)
  return (tostring(value or ""):gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end))
end

local function fields(line)
  local result = {}
  for value in (line .. "\t"):gmatch("(.-)\t") do
    result[#result + 1] = value
  end
  return result
end

local function supportedFile(path)
  local lowered = path:lower()
  return lowered:sub(-7) == ".preset"
    or lowered:sub(-10) == ".cpmfolder"
    or lowered:sub(-10) == ".cpmbackup"
end

local function validNativeRelativePath(value)
  if not validRelativePath(value) then return false end
  local depth = 0
  for part in value:gmatch("[^/]+") do
    depth = depth + 1
    if depth > MAX_TREE_DEPTH or #part > 255 or part:find("[<>:\"\\|%?%*%c]")
        or part:match("[%. ]$") then return false end
  end
  return depth > 0
end

local function addChild(children, parent, name, entryType)
  children[parent] = children[parent] or { entries = {}, names = {} }
  local key = name:lower()
  if children[parent].names[key] then return false end
  children[parent].names[key] = true
  children[parent].entries[#children[parent].entries + 1] = {
    name = name,
    type = entryType,
  }
  return true
end

readNativeFileCatalog = function()
  local contents, readError = readBoundedFile(NATIVE_FILE_CATALOG, MAX_CATALOG_BYTES)
  if not contents then return nil, readError == "missing" and "not available" or "could not be read" end
  local protocol, generation
  local expectedFiles, expectedDirectories, skipped
  local directories, files = {}, {}
  local directoryNames, fileNames = {}, {}
  for line in (contents .. "\n"):gmatch("([^\r\n]*)\r?\n") do
    if line ~= "" then
      local row = fields(line)
      if row[1] == "protocol" and #row == 2 then
        protocol = tonumber(row[2])
      elseif row[1] == "generation" and #row == 2 then
        generation = row[2]
      elseif row[1] == "summary" and #row == 4 then
        expectedFiles = tonumber(row[2])
        expectedDirectories = tonumber(row[3])
        skipped = tonumber(row[4])
      elseif row[1] == "directory" and #row == 2 then
        local relative = decodeNativeField(row[2])
        local lowered = relative:lower()
        if not validNativeRelativePath(relative) or directoryNames[lowered] then
          return nil, "contains an invalid folder entry"
        end
        directoryNames[lowered] = true
        directories[#directories + 1] = relative
      elseif row[1] == "file" and #row == 5 then
        local relative = decodeNativeField(row[2])
        local size = tonumber(row[3])
        local modified = tonumber(row[4])
        local fingerprint = row[5]
        local fingerprintSize = fingerprint:match("^2:(%d+):%d+:%d+$")
        local lowered = relative:lower()
        if not validNativeRelativePath(relative) or not supportedFile(relative)
            or fileNames[lowered] or type(size) ~= "number" or size < 0
            or size ~= math.floor(size) or size > MAX_LIBRARY_BACKUP_BYTES
            or type(modified) ~= "number" or modified ~= math.floor(modified)
            or not fingerprintSize or tonumber(fingerprintSize) ~= size
            or #fingerprint > 64 then
          return nil, "contains an invalid file entry"
        end
        fileNames[lowered] = true
        files[#files + 1] = {
          relative = relative,
          size = size,
          modified = modified,
          fingerprint = fingerprint,
        }
      else
        return nil, "contains an unsupported entry"
      end
    end
  end
  if protocol ~= NATIVE_FILE_PROTOCOL then return nil, "uses a different protocol" end
  if type(generation) ~= "string" or generation == "" then return nil, "has no generation" end
  if expectedFiles ~= #files or expectedDirectories ~= #directories
      or type(skipped) ~= "number" or skipped < 0 or skipped ~= math.floor(skipped) then
    return nil, "has an invalid summary"
  end
  local children = { [""] = { entries = {}, names = {} } }
  table.sort(directories, function(a, b) return a:lower() < b:lower() end)
  for _, relative in ipairs(directories) do
    local parent = parentFolder(relative)
    if parent ~= "" and not directoryNames[parent:lower()] then
      return nil, "is missing a parent folder"
    end
    if not addChild(children, parent, baseName(relative), "directory") then
      return nil, "contains repeated names"
    end
    children[relative] = children[relative] or { entries = {}, names = {} }
  end
  table.sort(files, function(a, b) return a.relative:lower() < b.relative:lower() end)
  for _, file in ipairs(files) do
    local parent = parentFolder(file.relative)
    if parent ~= "" and not directoryNames[parent:lower()] then
      return nil, "places a file in a missing folder"
    end
    if not addChild(children, parent, baseName(file.relative), "file") then
      return nil, "contains repeated names"
    end
  end
  for _, group in pairs(children) do
    table.sort(group.entries, function(a, b) return a.name:lower() < b.name:lower() end)
    group.names = nil
  end
  local fileByRelative = {}
  for _, file in ipairs(files) do fileByRelative[file.relative:lower()] = file end
  return {
    protocol = protocol,
    generation = generation,
    files = files,
    fileByRelative = fileByRelative,
    directories = directories,
    children = children,
    skipped = skipped,
  }
end

nativeCatalogDirectoryEntries = function(catalog, relative, depth)
  if (tonumber(depth) or 0) > MAX_TREE_DEPTH then
    return nil, "folder nesting exceeds the safety limit"
  end
  local group = catalog and catalog.children and catalog.children[relative or ""]
  if not group then return nil, "folder is missing from the native catalog" end
  local result = {}
  for _, entry in ipairs(group.entries) do
    result[#result + 1] = { name = entry.name, type = entry.type }
  end
  return result
end

local function collectLuaCatalog(relative, depth, output)
  local entries = safeDirectoryEntries(folderPath(relative), depth)
  if not entries then return false end
  for _, entry in ipairs(entries) do
    local child = joinFolder(relative, entry.name)
    if entry.type == "directory" then
      output["directory\31" .. child:lower()] = true
      if child ~= ".Character Preset Manager Trash"
          and not collectLuaCatalog(child, depth + 1, output) then return false end
    elseif supportedFile(child) then
      output["file\31" .. child:lower()] = true
    end
  end
  return true
end

local function nativeCatalogMatchesLua(catalog)
  local nativeEntries, luaEntries = {}, {}
  for _, directory in ipairs(catalog.directories) do
    nativeEntries["directory\31" .. directory:lower()] = true
  end
  for _, file in ipairs(catalog.files) do
    nativeEntries["file\31" .. file.relative:lower()] = true
  end
  if not collectLuaCatalog("", 0, luaEntries) then return false, "the CET folder check could not finish" end
  for key in pairs(nativeEntries) do
    if not luaEntries[key] then return false, "the native list contains a stale entry" end
  end
  for key in pairs(luaEntries) do
    if not nativeEntries[key] then return false, "the native list is waiting for an update" end
  end
  return true
end

verifiedNativeFileCatalog = function()
  local catalog, reason = readNativeFileCatalog()
  if catalog then
    local matches, mismatch = nativeCatalogMatchesLua(catalog)
    if not matches then catalog, reason = nil, mismatch end
  end
  state.nativeCatalog.available = catalog ~= nil
  state.nativeCatalog.generation = catalog and catalog.generation or nil
  state.nativeCatalog.fileCount = catalog and #catalog.files or 0
  state.nativeCatalog.directoryCount = catalog and #catalog.directories or 0
  state.nativeCatalog.skipped = catalog and catalog.skipped or 0
  state.nativeCatalog.fallbackReason = catalog and nil or reason
  if catalog then
    log(("[NATIVE FILES] Verified %d files and %d folders against CET's folder check.")
      :format(#catalog.files, #catalog.directories), "info")
  else
    log(("[NATIVE FILES] CET used its own safe folder check because the native list %s.")
      :format(tostring(reason or "was unavailable")), "info")
  end
  return catalog
end

return _ENV
