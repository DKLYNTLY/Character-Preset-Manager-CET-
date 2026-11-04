local identities = require("modules/domain/identities")
local MAX_OPTIONS, MAX_CHOICES, MAX_BYTES, MAX_TEXT = 2048, 65536, 8388608, 1024

local function capture(runtime)
  local lines, bytes, choices, occurrences = {}, 0, 0, {}
  local function add(value)
    bytes = bytes + #value + 1
    if bytes > MAX_BYTES then error("The catalog exceeds the 8 MiB export limit.", 0) end
    lines[#lines + 1] = value
  end
  local function read(callback)
    local ok, value = pcall(callback)
    if ok then return value end
    return nil
  end
  local function text(value)
    if value == nil then return "[unavailable]" end
    if type(value) ~= "string" then return "[unavailable]" end
    if #value > MAX_TEXT then error("A catalog identity exceeds the 1024-byte export limit.", 0) end
    if identities.isRuntimePointerText(value) then return "[unavailable]" end
    if value:find("%a:[/\\]") or value:find("\\\\", 1, true)
        or value:match("^%s*[/\\]") or value:find("%s[/\\]") or value:find("=[/\\]")
        or value:lower():find("file:", 1, true) then
      return "[redacted path]"
    end
    return value:gsub("\\", "\\\\"):gsub("%c", function(character)
      return ("\\x%02X"):format(character:byte())
    end)
  end
  local function name(value)
    if value == nil then return "[unavailable]" end
    if type(value) == "string" then return text(value) end
    return text(read(function() return runtime.NameToString(value) end))
  end
  local function number(value)
    if identities.optionIndexIsValid(value) then return tostring(value) end
    return "[unavailable]"
  end
  local function flag(value)
    if type(value) == "boolean" then return tostring(value) end
    return "[unavailable]"
  end
  local function count(value)
    if type(value) ~= "table" and type(value) ~= "userdata" then return nil end
    local size = read(function() return #value end)
    if type(size) ~= "number" or size < 0 or size ~= math.floor(size) then return nil end
    if size > MAX_CHOICES then error("The catalog exceeds the 65536-choice export limit.", 0) end
    return size
  end
  local function charge()
    choices = choices + 1
    if choices > MAX_CHOICES then error("The catalog exceeds the 65536-choice export limit.", 0) end
  end
  local system = read(function() return runtime.Game.GetCharacterCustomizationSystem() end)
  if not system then return nil, "The character editor is not available." end
  local options = read(function()
    local empty = runtime.ToCName({})
    return system:GetUnitedOptions(true, true, true, empty, empty, empty)
  end)
  if type(options) ~= "table" or #options == 0 then return nil, "The option catalog is not available." end
  if #options > MAX_OPTIONS then return nil, "The catalog exceeds the 2048-option export limit." end
  add("CPM customization option catalog")
  add("Catalog layout: 1")
  add("Indexes are zero-based. Occurrences include inactive and noneditable options.")
  add("Unavailable fields are not evidence that a choice is absent.")
  for position = 1, #options do
    local option = read(function() return options[position] end)
    local info = read(function() return option.info end)
    local internal = name(read(function() return info.name end))
    local label = text(read(function() return runtime.optionKey(option) end))
    local occurrenceKey = internal ~= "[unavailable]" and internal or label
    occurrences[occurrenceKey] = (occurrences[occurrenceKey] or 0) + 1
    add(("Option\t%d\tname=%s\tlabel=%s\tslot=%s\toccurrence=%d\tindex=%s\tactive=%s\teditable=%s")
      :format(position, internal, label, name(read(function() return info.uiSlot end)),
        occurrences[occurrenceKey], number(read(function() return option.currIndex end)),
        flag(read(function() return option.isActive end)), flag(read(function() return option.isEditable end))))
    for _, source in ipairs({{"definitions", "name"}, {"morphNames", "morphName"}, {"options", nil}}) do
      local collection = read(function() return info[source[1]] end)
      local size = collection and count(collection) or nil
      if size == nil then
        add("Collection\t" .. source[1] .. "\t[unavailable]")
      else
        add(("Collection\t%s\t%d"):format(source[1], size))
        for index = 0, size - 1 do
          charge()
          local item = read(function() return collection[index + 1] end)
          local identity = source[2] and read(function() return item[source[2]] end) or nil
          if source[2] and type(item) == "string" then identity = item end
          local localized = text(read(function() return item.localizedName end))
          add(("Choice\t%s\t%d\tname=%s\tlabel=%s"):format(source[1], index, name(identity), localized))
          if source[1] == "options" then
            local names = read(function() return item.names end)
            local namesCount = names and count(names) or nil
            if namesCount == nil then add("Switcher names\t[unavailable]")
            else
              add(("Switcher names\t%d"):format(namesCount))
              for offset = 1, namesCount do
                charge()
                add(("Switcher name\t%d\t%s"):format(offset, name(read(function() return names[offset] end))))
              end
            end
          end
        end
      end
    end
  end
  add(("Capture complete\toptions=%d\tchoice records=%d"):format(#options, choices))
  return table.concat(lines, "\n") .. "\n", #options
end

local function install(runtime)
  if setfenv then setfenv(1, runtime) end
  local _ENV = runtime
  helpers.exportOptionCatalog = function()
    if not state.app.inCustomization or state.load.auto or state.load.needsContinue or state.load.pendingChange then
      local message = "Open the editor and wait for loading to finish before exporting its catalog."
      setStatus("load", message)
      return false, message
    end
    local ok, contents, count = pcall(capture, {Game=Game, ToCName=ToCName, NameToString=NameToString, optionKey=optionKey})
    if not ok then
      local reasons = {
        ["The catalog exceeds the 8 MiB export limit."]=true,
        ["The catalog exceeds the 65536-choice export limit."]=true,
        ["A catalog identity exceeds the 1024-byte export limit."]=true,
      }
      count = reasons[contents] and contents or "The option catalog could not be captured."
      contents = nil
    end
    if not contents then
      log("[CATALOG EXPORT] " .. count, "warn")
      setStatus("load", count, true)
      return false, count
    end
    local dateOk, timestamp = pcall(os.date, "%Y-%m-%d %H-%M-%S")
    timestamp = dateOk and type(timestamp) == "string" and timestamp:match("^%d%d%d%d%-%d%d%-%d%d %d%d%-%d%d%-%d%d$")
      or "undated"
    local destination
    for sequence = 1, 999 do
      local candidate = ("%s/Option Catalog %s-%03d.txt"):format(LOG_DIR, timestamp, sequence)
      local checkOk, exists = pcall(function()
        return fileExists(candidate) or fileExists(candidate .. ".tmp")
          or fileExists(candidate .. ".bak")
      end)
      if not checkOk then break end
      if not exists then destination = candidate; break end
    end
    local saveOk, saved
    if destination then saveOk, saved = pcall(atomicReplace, destination, function(temporary)
      local file = io.open(temporary, "wb")
      if not file then return false end
      local writeOk, result = pcall(file.write, file, contents)
      local closeOk, closed = pcall(file.close, file)
      return writeOk and result ~= nil and closeOk and closed ~= nil
    end, "option catalog export") end
    if not saveOk or not saved then
      log("[CATALOG EXPORT] The diagnostic file could not be written.", "warn")
      local message = "The option catalog could not be saved. Check that Data/Logs is writable."
      setStatus("load", message, true)
      return false, message
    end
    local message = ("Saved %d options to %s."):format(count, destination)
    log("[CATALOG EXPORT] " .. message, "info")
    setStatus("load", message, false, "success")
    return true, destination
  end
end

return {install=install, capture=capture}
