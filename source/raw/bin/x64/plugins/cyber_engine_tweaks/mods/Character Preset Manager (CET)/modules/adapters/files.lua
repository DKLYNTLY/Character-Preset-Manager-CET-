local FINGERPRINT_MULTIPLIER = 131
local FINGERPRINT_MODULUS = 2147483647
local SECOND_FINGERPRINT_MULTIPLIER = 137
local SECOND_FINGERPRINT_MODULUS = 2147483629

local function fileExists(ioApi, path)
  local file = ioApi.open(path, "rb")
  if not file then return false end
  file:close()
  return true
end

local function writeFileSafely(ioApi, path, mode, writerFn)
  local file = ioApi.open(path, mode)
  if not file then return false, "open" end
  local wrote, writeResult = pcall(writerFn, file)
  local closed, closeResult = pcall(file.close, file)
  if not wrote or writeResult ~= true or not closed or closeResult == nil then
    return false, "write"
  end
  return true
end

local function fileFingerprint(ioApi, path, maximumBytes, defaultMaximumBytes, chunkSize)
  local file = ioApi.open(path, "rb")
  if not file then return nil end
  local sizeOk, fileSize = pcall(file.seek, file, "end")
  local rewindOk, rewindResult = pcall(file.seek, file, "set", 0)
  if not sizeOk or not fileSize or fileSize > (maximumBytes or defaultMaximumBytes)
      or not rewindOk or rewindResult == nil then
    file:close()
    return nil
  end
  local hash, secondHash, bytesRead = 0, 0, 0
  local ok = pcall(function()
    while true do
      local chunk = file:read(chunkSize)
      if not chunk then break end
      bytesRead = bytesRead + #chunk
      for index = 1, #chunk do
        local byte = chunk:byte(index)
        hash = (hash * FINGERPRINT_MULTIPLIER + byte) % FINGERPRINT_MODULUS
        secondHash = (secondHash * SECOND_FINGERPRINT_MULTIPLIER + byte) % SECOND_FINGERPRINT_MODULUS
      end
    end
  end)
  local closeOk, closeResult = pcall(file.close, file)
  if not ok or bytesRead ~= fileSize
      or not closeOk or closeResult == nil then return nil end
  local legacy = tostring(bytesRead) .. ":" .. tostring(hash)
  return "2:" .. legacy .. ":" .. tostring(secondHash), legacy
end

local function safeDirectoryEntries(listDirectory, path, depth, maximumDepth)
  if (tonumber(depth) or 0) > maximumDepth then
    return nil, "folder nesting exceeds the safety limit"
  end
  local ok, entries = pcall(listDirectory, path)
  if not ok or type(entries) ~= "table" then
    return nil, "folder could not be listed safely"
  end
  local validated = {}
  for _, entry in pairs(entries) do
    if type(entry) ~= "table"
        or type(entry.name) ~= "string"
        or (entry.type ~= "file" and entry.type ~= "directory")
        or entry.name == ""
        or entry.name == "."
        or entry.name == ".."
        or entry.name:find("/", 1, true)
        or entry.name:find("\\", 1, true)
        or entry.name:find("%c") then
      return nil, "folder contains an invalid directory entry"
    end
    table.insert(validated, entry)
  end
  table.sort(validated, function(a, b) return a.name:lower() < b.name:lower() end)
  return validated
end

local function directoryTreeContainsFiles(files, path, depth)
  local entries = files.entries(path, depth)
  if not entries then return nil end
  for _, entry in ipairs(entries) do
    if entry.type == "directory" then
      local containsFiles = directoryTreeContainsFiles(files, path .. "/" .. entry.name, depth + 1)
      if containsFiles == nil or containsFiles then return containsFiles end
    else
      return true
    end
  end
  return false
end

local function removeEmptyDirectoryTree(files, path, depth)
  local entries = files.entries(path, depth)
  if not entries then return false end
  for _, entry in ipairs(entries) do
    if entry.type ~= "directory"
        or not removeEmptyDirectoryTree(files, path .. "/" .. entry.name, depth + 1) then
      return false
    end
  end
  return files.delete(path) ~= nil
end

local function readBoundedFile(ioApi, path, maximumBytes)
  local file = ioApi.open(path, "rb")
  if not file then return nil, "missing" end
  local sizeOk, size = pcall(file.seek, file, "end")
  local rewindOk, rewindResult = pcall(file.seek, file, "set", 0)
  if not sizeOk or not size or size > maximumBytes
      or not rewindOk or rewindResult == nil then
    file:close()
    return nil, "size"
  end
  local readOk, contents = pcall(file.read, file, "*a")
  local closeOk, closeResult = pcall(file.close, file)
  if not readOk or type(contents) ~= "string" or not closeOk or closeResult == nil then
    return nil, "read"
  end
  return contents
end

local function copyFile(ioApi, source, destination, chunkSize)
  local report
  local function diagnostic(message, level) report = {message = message, level = level} end
  local input = ioApi.open(source, "rb")
  if not input then
    diagnostic(("[FILES] Copy failed: could not open source='%s'."):format(source), "error")
    return false, report
  end
  local sizeOk, sourceSize = pcall(input.seek, input, "end")
  local rewindOk, rewindResult = pcall(input.seek, input, "set", 0)
  if not sizeOk or not sourceSize or not rewindOk or rewindResult == nil then
    input:close()
    diagnostic(("[FILES] Copy failed: could not measure source='%s'."):format(source), "error")
    return false, report
  end
  local output = ioApi.open(destination, "wb")
  if not output then
    input:close()
    diagnostic(("[FILES] Copy failed: could not open destination='%s'."):format(destination), "error")
    return false, report
  end
  local copiedBytes = 0
  local writeOk, writeResult = pcall(function()
    while true do
      local chunk = input:read(chunkSize)
      if not chunk then break end
      if not output:write(chunk) then return false end
      copiedBytes = copiedBytes + #chunk
    end
    return copiedBytes == sourceSize and output:flush() ~= nil
  end)
  local inputCloseOk, inputCloseResult = pcall(input.close, input)
  local closeOk, closeResult = pcall(output.close, output)
  local copied = writeOk and writeResult == true
    and inputCloseOk and inputCloseResult ~= nil
    and closeOk and closeResult ~= nil
  diagnostic(("[FILES] Copy source='%s' destination='%s' bytes=%d success=%s.")
    :format(source, destination, copiedBytes, tostring(copied)), copied and "info" or "error")
  return copied, report
end

local function removeFileList(files, paths)
  local success = true
  for _, path in ipairs(paths or {}) do
    if files.exists(path) and not files.delete(path) then success = false end
  end
  return success
end

local function pack(...)
  return {n = select("#", ...), ...}
end

local function run(operation, report, ...)
  local thread = coroutine.create(operation)
  local arguments = {n = select("#", ...), ...}
  while true do
    local result = pack(coroutine.resume(thread, unpack(arguments, 1, arguments.n)))
    if not result[1] then error(result[2], 0) end
    if coroutine.status(thread) == "dead" then
      return unpack(result, 2, result.n)
    end
    report(result[2].message, result[2].level)
    arguments = {n = 0}
  end
end

local function rename(osApi, source, destination)
  return osApi.rename(source, destination)
end

local function delete(osApi, path)
  return osApi.remove(path)
end

local function writeBytes(ioApi, path, contents)
  return writeFileSafely(ioApi, path, "wb", function(file)
    return file:write(contents) ~= nil and file:flush() ~= nil
  end)
end

return {
  fileExists = fileExists,
  fileFingerprint = fileFingerprint,
  writeFileSafely = writeFileSafely,
  readBoundedFile = readBoundedFile,
  copyFile = copyFile,
  safeDirectoryEntries = safeDirectoryEntries,
  directoryTreeContainsFiles = directoryTreeContainsFiles,
  removeEmptyDirectoryTree = removeEmptyDirectoryTree,
  removeFileList = removeFileList,
  run = run,
  rename = rename,
  delete = delete,
  writeBytes = writeBytes,
}
