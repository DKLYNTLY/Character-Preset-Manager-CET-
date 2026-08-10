
local MOD_NAME = "Character Preset Manager (CET)"
local VERSION = "2.0.5"
local PRESET_DIR = "Character Presets"
local FOLDER_POOL = PRESET_DIR .. "/.Character Preset Manager Folder Slots"
local INVENTORY_FILE = "Character Preset Manager (CET) Inventory.txt"
local LOG_FILE = "Character Preset Manager (CET) Activity.log"
local LOG_ARCHIVE_PREFIX = "Character Preset Manager (CET) Activity "
local WINDOW_POSITION_STATUS_FILE = "Window Position Status.txt"
local LOG_ARCHIVE_LIMIT = 10
local activitySequence = 0

local AUTO_LOAD_INTERVAL = 0.40
local AUTO_LOAD_MAX_PASSES = 400
local STALL_CONFIRMATION_PASSES = 3
local EDITOR_STATE_REFRESH_INTERVAL = 0.25
local EDITOR_OPEN_TIMEOUT = 5.0
local log

local state = {
  overlayOpen = false,
  windowOpen = true,
  ready = false,
  inCustomization = false,
  editorStateRefreshTimer = 0,
  selected = nil,
  newName = "",
  renameName = "",
  presets = {},
  folders = {},
  openSections = {
    editor = true,
    load = true,
    create = true,
    folders = false,
    manage = false,
  },
  selectedFolder = "",
  folderName = "",
  folderRenameName = "",
  folderStatus = "",
  folderStatusError = false,
  lastLoggedFolderStatus = nil,
  pendingDeleteFolder = nil,
  pendingDeleteFolderStage = 0,
  pendingDeleteFolderPresetCount = 0,
  pendingDeleteFolderHasContents = false,
  loadStatus = "Load a save and open the character editor.",
  loadStatusError = false,
  createStatus = "",
  createStatusError = false,
  renameStatus = "",
  renameStatusError = false,
  deleteStatus = "",
  deleteStatusError = false,
  loadPresetName = nil,
  loadPass = 0,
  loadRemaining = 0,
  loadNeedsContinue = false,
  loadStalled = false,
  previousUnresolvedSignature = nil,
  unresolvedRepeatCount = 0,
  loadSatisfied = {},
  pendingOverwriteName = nil,
  pendingDeleteName = nil,
  helpOpen = false,
  debugOpen = false,
  debugLogText = "",
  autoLoad = false,
  autoLoadTimer = 0,
  autoLoadPasses = 0,
  resetBeforeLoad = false,
  activeBodyMorphMenu = nil,
  inGameMenuController = nil,
  editorOpenPending = false,
  editorOpenTimer = 0,
  editorStatus = "Load a save before opening the full editor.",
  editorStatusError = false,
  editorInputCount = 0,
  editorControllerCaptureCount = 0,
  editorPauseRedirectCount = 0,
  editorPuppetReadyCount = 0,
  editorOpenedByLauncher = false,
  wardrobeTemporarilyDisabled = false,
  initialWindowPlacementPending = true,
}

local function fileExists(path)
  local file = io.open(path, "rb")
  if not file then return false end
  file:close()
  return true
end

local function isNewGameCharacterCreator()
  if state.editorOpenedByLauncher or not state.activeBodyMorphMenu then return false end
  local modeOk, editMode = pcall(function()
    return state.activeBodyMorphMenu.m_editMode
  end)
  return modeOk and editMode == gameuiCharacterCustomizationEditTag.NewGame
end

local function logTimestamp()
  local ok, value = pcall(os.date, "%Y-%m-%d %H:%M:%S")
  if ok and value then return value end
  return "unknown-time"
end

local function writeLog(message, level)
  local file = io.open(LOG_FILE, "a")
  if not file then return false end
  activitySequence = activitySequence + 1
  file:write(("[%s] [#%04d] [%s] %s\n"):format(
    logTimestamp(),
    activitySequence,
    tostring(level or "info"):upper(),
    tostring(message)
  ))
  file:close()
  return true
end

local function pruneLogArchives()
  local listOk, files = pcall(dir, ".")
  if not listOk or type(files) ~= "table" then
    return 0, "dated activity-log archives could not be listed"
  end

  local archives = {}
  for _, entry in pairs(files) do
    local filename = type(entry) == "table" and entry.name or tostring(entry)
    if filename
        and filename:sub(1, #LOG_ARCHIVE_PREFIX) == LOG_ARCHIVE_PREFIX
        and filename:match("%.txt$") then
      table.insert(archives, filename)
    end
  end
  table.sort(archives)

  local deleted = 0
  while #archives > LOG_ARCHIVE_LIMIT do
    local oldest = table.remove(archives, 1)
    local removed, removeError = os.remove(oldest)
    if not removed then
      return deleted, ("oldest activity-log archive could not be deleted: %s")
        :format(tostring(removeError))
    end
    deleted = deleted + 1
  end
  return deleted, nil
end

local function archiveLogForNewSession()
  local file = io.open(LOG_FILE, "rb")
  if not file then return true, nil end
  local readOk, contents = pcall(file.read, file, "*a")
  file:close()
  if not readOk then return false, "the existing activity log could not be read" end

  contents = type(contents) == "string" and contents or ""
  if contents ~= "" then
    local dateOk, timestamp = pcall(os.date, "%Y-%m-%d_%H-%M-%S")
    if not dateOk or not timestamp then timestamp = "unknown-date" end

    local archiveName = LOG_ARCHIVE_PREFIX .. tostring(timestamp) .. ".txt"
    local suffix = 2
    while suffix <= 99 do
      local existing = io.open(archiveName, "rb")
      if not existing then break end
      existing:close()
      archiveName = LOG_ARCHIVE_PREFIX .. tostring(timestamp) ..
        ("-%d.txt"):format(suffix)
      suffix = suffix + 1
    end

    local archive = io.open(archiveName, "wb")
    if not archive then return false, "the dated activity-log archive could not be created" end
    local writeOk, writeResult = pcall(archive.write, archive, contents)
    archive:close()
    if not writeOk or not writeResult then
      return false, "the dated activity-log archive could not be written"
    end

    local deleted, pruneError = pruneLogArchives()

    local fresh = io.open(LOG_FILE, "w")
    if not fresh then return false, "the activity log could not be cleared" end
    fresh:close()
    return true, archiveName, pruneError, deleted
  end

  local fresh = io.open(LOG_FILE, "w")
  if not fresh then return false, "the empty activity log could not be refreshed" end
  fresh:close()
  return true, nil
end

log = function(message, level)
  level = level or "info"
  writeLog(message, level)
end

local function auditSection(title)
  log(("---------------- %s ----------------"):format(tostring(title)), "info")
end

local function setStatus(section, message, isError)
  local loadStopped = section == "load"
    and message:find("Loading stopped", 1, true) == 1
  local effectiveError = isError == true or loadStopped
  state[section .. "Status"] = message
  state[section .. "StatusError"] = effectiveError
  if section == "load" then
    local transient = message:find("Applied one option.", 1, true) == 1
      or message:find("Applied one replacement CCXL option.", 1, true) == 1
      or message:find("Cleared a remaining option.", 1, true) == 1
      or message:find("Cleanup complete.", 1, true) == 1
      or message:find("Pass ", 1, true) == 1
    if transient and not effectiveError then return end
    local level = "load"
    if effectiveError then
      level = "load error"
    elseif message:find("Preset fully applied", 1, true) == 1 then
      level = "complete"
    end
    log(message, level)
  else
    log(("[%s] %s"):format(section, message), isError and "error" or "info")
  end
end

local function sanitizeName(value)
  value = tostring(value or "")
  value = value:gsub("^%s+", ""):gsub("%s+$", "")
  value = value:gsub("[<>:\"/\\|%?%*%c]", "_")
  return value:sub(1, 64)
end

local function validatedPresetName(value)
  local raw = tostring(value or "")
  if raw:match("[%. ]$") then
    return nil, "Preset names cannot end with a period or space."
  end
  local name = sanitizeName(raw)
  if name == "" then return nil, "Enter a name." end

  local deviceName = (name:match("^([^%.]+)") or name):upper()
  if deviceName == "CON" or deviceName == "PRN"
      or deviceName == "AUX" or deviceName == "NUL"
      or deviceName:match("^COM[1-9]$")
      or deviceName:match("^LPT[1-9]$") then
    return nil, ("\"%s\" is a reserved Windows name. Enter another name.")
      :format(name)
  end
  return name
end

local function customizationSystem()
  local ok, system = pcall(Game.GetCharacterCustomizationSystem)
  if ok then return system end
  return nil
end

local isCustomizationActive

local function setEditorOpenStatus(message, isError)
  state.editorStatus = message
  state.editorStatusError = isError == true
  log("[editor] " .. tostring(message), isError and "error" or "info")
end

local function activeWardrobeSetEquipped()
  local playerOk, player = pcall(Game.GetPlayer)
  if not playerOk or not player then return false, nil end
  local setOk, activeSet = pcall(EquipmentSystem.GetActiveWardrobeSetID, player)
  if not setOk or activeSet == nil then return false, player end
  return activeSet ~= gameWardrobeClothingSetIndex.INVALID, player
end

local function hasEquippedClothing()
  local playerOk, player = pcall(Game.GetPlayer)
  if not playerOk or not player then return false end
  local dataOk, data = pcall(EquipmentSystem.GetData, player)
  if not dataOk or not data then return false end
  local areas = {
    gamedataEquipmentArea.Head,
    gamedataEquipmentArea.Face,
    gamedataEquipmentArea.OuterChest,
    gamedataEquipmentArea.InnerChest,
    gamedataEquipmentArea.Legs,
    gamedataEquipmentArea.Feet,
    gamedataEquipmentArea.Outfit,
  }
  for _, area in ipairs(areas) do
    local itemOk, item = pcall(data.GetActiveItem, data, area)
    if itemOk and item then
      local validOk, valid = pcall(ItemID.IsValid, item)
      if validOk and valid then return true end
    end
  end
  return false
end

local function equipmentSystem()
  local ok, system = pcall(function()
    return Game.GetScriptableSystemsContainer():Get("EquipmentSystem")
  end)
  if ok then return system end
  return nil
end

local function temporarilyDisableWardrobe()
  if state.wardrobeTemporarilyDisabled then return true end
  local active, player = activeWardrobeSetEquipped()
  if not active then return true end
  local system = equipmentSystem()
  if not system then
    log("[wardrobe] Active outfit detected, but the equipment system is unavailable.", "warn")
    return false
  end
  local ok, disableError = pcall(function()
    local request = QuestDisableWardrobeSetRequest.new()
    request.owner = player
    request.blockReequipping = true
    system:QueueRequest(request)
  end)
  if not ok then
    log("[wardrobe] Could not temporarily remove the active outfit: " ..
      tostring(disableError), "warn")
    return false
  end
  state.wardrobeTemporarilyDisabled = true
  log("[wardrobe] Active outfit temporarily removed for character customization.", "info")
  return true
end

local function restoreTemporarilyDisabledWardrobe()
  if not state.wardrobeTemporarilyDisabled then return true end
  local playerOk, player = pcall(Game.GetPlayer)
  local system = equipmentSystem()
  if not playerOk or not player or not system then
    log("[wardrobe] Outfit restoration is waiting for a valid player and equipment system.", "warn")
    return false
  end
  local ok, restoreError = pcall(function()
    local request = QuestRestoreWardrobeSetRequest.new()
    request.owner = player
    system:QueueRequest(request)
  end)
  if not ok then
    log("[wardrobe] Could not restore the temporarily removed outfit: " ..
      tostring(restoreError), "warn")
    return false
  end
  state.wardrobeTemporarilyDisabled = false
  log("[wardrobe] Restored the outfit used before character customization.", "info")
  return true
end

local function openFullAppearanceEditor()
  log(("[editor diagnostic] launch requested: controller=%s pending=%s customization=%s")
    :format(tostring(state.inGameMenuController ~= nil),
      tostring(state.editorOpenPending), tostring(isCustomizationActive())), "info")
  if state.editorOpenPending then
    setEditorOpenStatus("The editor is already opening.", true)
    return false
  end
  if isCustomizationActive() then
    setEditorOpenStatus("A customization screen is already open.", true)
    return false
  end
  if not state.inGameMenuController then
    setEditorOpenStatus("Load or reload a save.", true)
    return false
  end

  state.editorOpenTimer = 0
  temporarilyDisableWardrobe()
  local ok, openError = pcall(
    state.inGameMenuController.SpawnMenuInstanceEvent,
    state.inGameMenuController,
    "OnOpenPauseMenu"
  )
  if not ok then
    state.editorOpenPending = false
    restoreTemporarilyDisabledWardrobe()
    setEditorOpenStatus("The game rejected the request: " ..
      tostring(openError), true)
    return false
  end
  state.editorOpenPending = true
  setEditorOpenStatus("Opening the full appearance editor...", false)
  return true
end

isCustomizationActive = function()
  local system = customizationSystem()
  if not system then return false end
  local ok, options = pcall(
    system.GetUnitedOptions,
    system,
    true,
    true,
    true,
    ToCName({}),
    ToCName({}),
    ToCName({})
  )
  return ok and type(options) == "table" and next(options) ~= nil
end

local function getOptions()
  local system = customizationSystem()
  if not system then return nil, nil, "Character customization system is unavailable" end
  local ok, options = pcall(
    system.GetUnitedOptions,
    system,
    true,
    true,
    true,
    ToCName({}),
    ToCName({}),
    ToCName({})
  )
  if not ok or type(options) ~= "table" then
    return nil, nil, "Customization options haven't loaded yet"
  end
  return system, options
end

local function legacyOptionKey(option)
  if not option or not option.info then return nil end
  local ok, key = pcall(LocKeyToString, option.info.name)
  if not ok or not key or key == "" then return nil end
  return tostring(key)
end

local function optionDisplayName(option, key)
  local candidates = {}
  if option and option.info then
    table.insert(candidates, option.info.name)
    local localizedNameOk, localizedName = pcall(function()
      return option.info.localizedName
    end)
    if localizedNameOk and localizedName then table.insert(candidates, localizedName) end
  end
  if key and key ~= "" then
    local nameOk, cname = pcall(ToCName, { tostring(key) })
    if nameOk then table.insert(candidates, cname) end
  end

  for _, candidate in ipairs(candidates) do
    local ok, value = pcall(function()
      if Game and Game.GetLocalizedTextByKey then
        return Game.GetLocalizedTextByKey(candidate)
      end
      if GetLocalizedTextByKey then return GetLocalizedTextByKey(candidate) end
      return nil
    end)
    value = ok and tostring(value or "") or ""
    if value ~= "" and value ~= tostring(key or "") and not value:find("LocKey", 1, true) then
      return value
    end
  end
  return "Custom/CCXL option (no localization provided)"
end

local function optionAuditIdentity(option, key, occurrence)
  return ("%s | LocKey=%s | occurrence=%s")
    :format(optionDisplayName(option, key), tostring(key or "unknown"),
      tostring(occurrence or 1))
end

local function occurrenceKeyParts(value)
  local raw = tostring(value or "")
  local key, occurrence = raw:match("^(.-)\31(%d+)$")
  return key or raw, tonumber(occurrence) or 1
end

local function refreshCustomizationUi()
  local menu = state.activeBodyMorphMenu
  if not menu then
    log("UI refresh skipped: no active characterCreationBodyMorphMenu controller", "warn")
    return false
  end
  local ok, refreshError = pcall(function()
    menu:InitializeList()
  end)
  if not ok then
    log("UI refresh failed: " .. tostring(refreshError), "error")
    return false
  end
  log("[UI] Rebuilt the visible customization list from applied preset values.", "info")
  return true
end

local function unresolvedSignature(unresolved)
  local keys = {}
  for key in pairs(unresolved) do table.insert(keys, key) end
  table.sort(keys)
  return table.concat(keys, "\30")
end

local function sortedPresetNames()
  local names = {}
  for name in pairs(state.presets) do table.insert(names, name) end
  table.sort(names, function(a, b) return a:lower() < b:lower() end)
  return names
end

local function sortedFolderNames()
  local names = {}
  for name in pairs(state.folders) do table.insert(names, name) end
  table.sort(names, function(a, b) return a:lower() < b:lower() end)
  return names
end

local function parentFolder(name)
  return name:match("^(.*)/[^/]+$") or ""
end

local function baseName(name)
  return name:match("([^/]+)$") or name
end

local function presetsInFolder(folder)
  local names = {}
  for name in pairs(state.presets) do
    if parentFolder(name) == folder then table.insert(names, name) end
  end
  table.sort(names, function(a, b) return baseName(a):lower() < baseName(b):lower() end)
  return names
end

local function joinFolder(folder, name)
  if not folder or folder == "" then return name end
  return folder .. "/" .. name
end

local function findExistingName(name, excludeName)
  local lowered = name:lower()
  for existing in pairs(state.presets) do
    if existing:lower() == lowered and existing ~= excludeName then
      return existing
    end
  end
  return nil
end

local function presetPath(name)
  return PRESET_DIR .. "/" .. name .. ".preset"
end

local function folderPath(name)
  return name == "" and PRESET_DIR or (PRESET_DIR .. "/" .. name)
end

local function validatedFolderName(value)
  local name, nameError = validatedPresetName(value)
  if not name then
    nameError = nameError:gsub("Preset names", "Folder names")
      :gsub("preset name", "folder name")
      :gsub("filename", "folder name")
    return nil, nameError
  end
  return name
end

local function ensureFolderMarker(path, context)
  local markerPath = path .. "/.Character Preset Manager Folder"
  local existing = io.open(markerPath, "r")
  if existing then
    existing:close()
    return true
  end
  local marker = io.open(markerPath, "w")
  if not marker then
    log(("[FOLDER SLOT] Could not restore marker='%s' context='%s'.")
      :format(markerPath, tostring(context)), "error")
    return false
  end
  marker:write("Character Preset Manager recyclable folder slot. Do not remove.\n")
  local closed, closeResult = pcall(marker.close, marker)
  local success = closed and closeResult ~= nil
  log(("[FOLDER SLOT] Restored marker='%s' context='%s' success=%s.")
    :format(markerPath, tostring(context), tostring(success)), success and "info" or "error")
  return success
end

local function repairFolderSlots()
  local ok, slots = pcall(dir, FOLDER_POOL)
  if not ok or type(slots) ~= "table" then
    log(("[FOLDER SLOT] Startup repair could not list pool='%s'."):format(FOLDER_POOL), "error")
    return 0, 0
  end
  local inspected, repaired = 0, 0
  for _, entry in pairs(slots) do
    local name = type(entry) == "table" and entry.name or tostring(entry)
    local entryType = type(entry) == "table" and entry.type or nil
    if name and name ~= "." and name ~= ".." and entryType ~= "file" then
      inspected = inspected + 1
      local slotPath = FOLDER_POOL .. "/" .. name
      local marker = io.open(slotPath .. "/.Character Preset Manager Folder", "r")
      if marker then marker:close()
      elseif ensureFolderMarker(slotPath, "startup repair") then repaired = repaired + 1 end
    end
  end
  log(("[FOLDER SLOT] Startup repair complete: inspected=%d repaired=%d.")
    :format(inspected, repaired), repaired > 0 and "warn" or "info")
  return inspected, repaired
end

local function acquireFolderSlot(path)
  local ok, slots = pcall(dir, FOLDER_POOL)
  if not ok or type(slots) ~= "table" then
    log(("[FOLDER SLOT] Could not list pool '%s' for destination '%s'."):format(FOLDER_POOL, path), "error")
    return false
  end
  for _, entry in pairs(slots) do
    local name = type(entry) == "table" and entry.name or tostring(entry)
    local entryType = type(entry) == "table" and entry.type or nil
    if name and name ~= "." and name ~= ".." and entryType ~= "file" then
      if os.rename(FOLDER_POOL .. "/" .. name, path) then
        log(("[FOLDER SLOT] Acquired '%s' -> '%s'."):format(name, path), "info")
        return true
      end
    end
  end
  log(("[FOLDER SLOT] No slot could be acquired for '%s'."):format(path), "error")
  return false
end

local function availableFolderSlots()
  local ok, slots = pcall(dir, FOLDER_POOL)
  if not ok or type(slots) ~= "table" then return nil end
  local count = 0
  for _, entry in pairs(slots) do
    local name = type(entry) == "table" and entry.name or tostring(entry)
    local entryType = type(entry) == "table" and entry.type or nil
    if name and name:match("^Slot %d+$") and entryType ~= "file" then
      count = count + 1
    end
  end
  return count
end

local function recycleFolder(path)
  if not ensureFolderMarker(path, "recycle") then return false end
  local ok, slots = pcall(dir, FOLDER_POOL)
  if not ok or type(slots) ~= "table" then
    log(("[FOLDER SLOT] Could not list pool while recycling '%s'."):format(path), "error")
    return false
  end
  local used = {}
  for _, entry in pairs(slots) do
    local name = type(entry) == "table" and entry.name or tostring(entry)
    if name then used[name:lower()] = true end
  end
  for index = 1, 64 do
    local name = ("Slot %02d"):format(index)
    if not used[name:lower()] and os.rename(path, FOLDER_POOL .. "/" .. name) then
      log(("[FOLDER SLOT] Recycled '%s' -> '%s'."):format(path, name), "info")
      return true
    end
  end
  log(("[FOLDER SLOT] Could not recycle '%s': no destination slot was available."):format(path), "error")
  return false
end

local fileExists, presetsMatch

local function readPresetFile(path)
  local file = io.open(path, "r")
  if not file then return nil end
  local entries = {}
  local lineNumber, malformed = 0, 0
  for line in file:lines() do
    lineNumber = lineNumber + 1
    local key, index = line:match("^%s*(.-):(-?%d+)%s*$")
    if key and key ~= "" then
      table.insert(entries, { key = key, index = tonumber(index) or 0 })
    elseif line:match("%S") then
      malformed = malformed + 1
      log(("[FILES] Malformed preset line skipped: file='%s' line=%d content='%s'.")
        :format(path, lineNumber, line), "warn")
    end
  end
  file:close()
  if malformed > 0 then
    log(("[FILES] Preset '%s' contains %d malformed nonblank line%s; valid entries remain loadable.")
      :format(path, malformed, malformed == 1 and "" or "s"), "warn")
  end
  if #entries == 0 then return nil end
  return { format = 4, entries = entries }
end

local function writePresetContents(path, preset)
  local file = io.open(path, "w")
  if not file then return false end
  local wrote, writeResult = pcall(function()
    for _, entry in ipairs(preset.entries or {}) do
      local result = file:write(("%s:%d\n"):format(
        tostring(entry.key),
        tonumber(entry.index) or 0
      ))
      if not result then return false end
    end
    return file:flush() ~= nil
  end)
  local closed, closeResult = pcall(file.close, file)
  return wrote and writeResult == true and closed and closeResult ~= nil
end

local function atomicReplace(path, writeTemporary, description)
  local temporary = path .. ".tmp"
  local backup = path .. ".bak"

  if not fileExists(path) and fileExists(backup) then
    local recovered, recoverError = os.rename(backup, path)
    log(("[FILES] Recovery attempted: backup='%s' target='%s' success=%s error=%s")
      :format(backup, path, tostring(recovered ~= nil), tostring(recoverError)),
      recovered and "info" or "error")
  end
  os.remove(temporary)
  if not writeTemporary(temporary) then
    os.remove(temporary)
    log(("[FILES] Could not write temporary %s '%s'."):format(description, temporary), "error")
    return false
  end
  if os.rename(temporary, path) then return true end

  os.remove(backup)
  local movedOriginal = os.rename(path, backup)
  if not movedOriginal then
    os.remove(temporary)
    return false
  end
  if not os.rename(temporary, path) then
    os.rename(backup, path)
    os.remove(temporary)
    return false
  end
  os.remove(backup)
  return true
end

local function writePresetPath(path, preset)
  return atomicReplace(path, function(temporary)
    if not writePresetContents(temporary, preset) then return false end
    return presetsMatch(preset, readPresetFile(temporary))
  end, "preset")
end

local function writePresetFile(name, preset)
  return writePresetPath(presetPath(name), preset)
end

presetsMatch = function(expected, actual)
  local expectedEntries = expected and expected.entries or {}
  local actualEntries = actual and actual.entries or {}
  if #expectedEntries ~= #actualEntries then return false end
  for index, entry in ipairs(expectedEntries) do
    local other = actualEntries[index]
    if not other
        or tostring(entry.key) ~= tostring(other.key)
        or (tonumber(entry.index) or 0) ~= (tonumber(other.index) or 0) then
      return false
    end
  end
  return true
end

local function readInventory()
  local presets, folders = {}, {}
  local file = io.open(INVENTORY_FILE, "r")
  if not file then return presets, folders, false end
  for line in file:lines() do
    local kind, name = line:match("^([PF]):(.*)$")
    if kind == "P" and name ~= "" then presets[name] = true
    elseif kind == "F" and name ~= "" then folders[name] = true end
  end
  file:close()
  return presets, folders, true
end

local function writeInventory(presets, folders)
  local lines = {}
  for name in pairs(presets or {}) do table.insert(lines, "P:" .. name) end
  for name in pairs(folders or {}) do table.insert(lines, "F:" .. name) end
  table.sort(lines, function(a, b) return a:lower() < b:lower() end)
  local result = atomicReplace(INVENTORY_FILE, function(temporary)
    local file = io.open(temporary, "w")
    if not file then return false end
    local wrote, writeResult = pcall(function()
      for _, line in ipairs(lines) do
        if not file:write(line .. "\n") then return false end
      end
      return file:flush() ~= nil
    end)
    local closed, closeResult = pcall(file.close, file)
    return wrote and writeResult == true and closed and closeResult ~= nil
  end, "inventory")
  log(("[INVENTORY] Saved %d tracked path%s to '%s' success=%s.")
    :format(#lines, #lines == 1 and "" or "s", INVENTORY_FILE, tostring(result)),
    result and "info" or "error")
  return result
end

fileExists = function(path)
  local file = io.open(path, "r")
  if not file then return false end
  file:close()
  return true
end

local function copyFile(source, destination)
  local input = io.open(source, "rb")
  if not input then
    log(("[FILES] Copy failed: could not open source='%s'."):format(source), "error")
    return false
  end
  local readOk, contents = pcall(input.read, input, "*a")
  input:close()
  if not readOk then
    log(("[FILES] Copy failed while reading source='%s'."):format(source), "error")
    return false
  end
  local output = io.open(destination, "wb")
  if not output then
    log(("[FILES] Copy failed: could not open destination='%s'."):format(destination), "error")
    return false
  end
  local writeOk, writeResult = pcall(output.write, output, contents or "")
  local closeOk, closeResult = pcall(output.close, output)
  local copied = writeOk and writeResult ~= nil and closeOk and closeResult ~= nil
  log(("[FILES] Copy source='%s' destination='%s' bytes=%d success=%s.")
    :format(source, destination, #(contents or ""), tostring(copied)), copied and "info" or "error")
  return copied
end

local function uniquePresetCopyName(sourceName)
  local folder = parentFolder(sourceName)
  local leaf = baseName(sourceName)
  for index = 1, 999 do
    local suffix = index == 1 and " Copy" or (" Copy %d"):format(index)
    local candidate = joinFolder(folder, leaf .. suffix)
    if not findExistingName(candidate) then return candidate end
  end
  return nil
end

local function folderNameExists(name)
  local lowered = name:lower()
  for existing in pairs(state.folders) do
    if existing:lower() == lowered then return true end
  end
  return false
end

local function uniqueFolderCopyName(sourceName)
  local folder = parentFolder(sourceName)
  local leaf = baseName(sourceName)
  for index = 1, 999 do
    local suffix = index == 1 and " Copy" or (" Copy %d"):format(index)
    local candidate = joinFolder(folder, leaf .. suffix)
    if not folderNameExists(candidate) then return candidate end
  end
  return nil
end

local function replacePresetFile(name, preset)
  return writePresetPath(presetPath(name), preset)
end

local function refreshPresets(scanReason)
  local previousPresets = state.presets or {}
  local previousFolders = state.folders or {}
  local baselineAvailable = state.ready
  if scanReason == "startup" then
    previousPresets, previousFolders, baselineAvailable = readInventory()
    log(("[INVENTORY] Startup baseline available=%s presets=%d folders=%d.")
      :format(tostring(baselineAvailable),
        (function() local count = 0; for _ in pairs(previousPresets) do count = count + 1 end; return count end)(),
        (function() local count = 0; for _ in pairs(previousFolders) do count = count + 1 end; return count end)()), "info")
  end
  local presets = {}
  local folders = {}
  local function scan(relative, depth)
    if depth > 12 then
      log(("[FILES] Folder nesting limit reached at '%s'."):format(relative), "warn")
      return
    end
    local path = folderPath(relative)
    local ok, files = pcall(dir, path)
    if not ok or type(files) ~= "table" then return end
    if relative ~= "" then folders[relative] = true end
    for _, entry in pairs(files) do
      local filename = type(entry) == "table" and entry.name or tostring(entry)
      local entryType = type(entry) == "table" and entry.type or nil
      if filename and filename ~= "." and filename ~= ".." then
        local childRelative = joinFolder(relative, filename)
        local name = filename:match("^(.*)%.preset$")
        if entryType ~= "directory" and name and name ~= "" then
          local presetName = joinFolder(relative, name)
          local preset = readPresetFile(presetPath(presetName))
          if preset then
            presets[presetName] = preset
          else
            log(("[FILES] Skipped unreadable or empty preset '%s'.")
              :format(childRelative), "warn")
          end
        elseif entryType ~= "file" and childRelative ~= ".Character Preset Manager Folder Slots" then
          local childOk, childFiles = pcall(dir, folderPath(childRelative))
          if childOk and type(childFiles) == "table" then scan(childRelative, depth + 1) end
        end
      end
    end
  end

  local rootOk, rootFiles = pcall(dir, PRESET_DIR)
  if rootOk and type(rootFiles) == "table" then scan("", 0) else
    log(("[FILES] Could not scan preset folder '%s'."):format(PRESET_DIR), "error")
  end

  local externalScan = scanReason == "external" or scanReason == "startup"
  if externalScan and baselineAvailable then
    local added, removed, modified = 0, 0, 0
    local foldersAdded, foldersRemoved = 0, 0
    for name, preset in pairs(presets) do
      if not previousPresets[name] then
        added = added + 1
        log(("[EXTERNAL CHANGE] Preset added or moved in: '%s'."):format(presetPath(name)), "warn")
      elseif type(previousPresets[name]) == "table"
          and not presetsMatch(previousPresets[name], preset) then
        modified = modified + 1
        log(("[EXTERNAL CHANGE] Preset contents changed: '%s'."):format(presetPath(name)), "warn")
      end
    end
    for name in pairs(previousPresets) do
      if not presets[name] then
        removed = removed + 1
        log(("[EXTERNAL CHANGE] Preset removed or moved out: '%s'."):format(presetPath(name)), "warn")
      end
    end
    for name in pairs(folders) do
      if not previousFolders[name] then
        foldersAdded = foldersAdded + 1
        log(("[EXTERNAL CHANGE] Folder added or moved in: '%s'."):format(folderPath(name)), "warn")
      end
    end
    for name in pairs(previousFolders) do
      if not folders[name] then
        foldersRemoved = foldersRemoved + 1
        log(("[EXTERNAL CHANGE] Folder removed or moved out: '%s'."):format(folderPath(name)), "warn")
      end
    end
    local total = added + removed + modified + foldersAdded + foldersRemoved
    if total > 0 then
      log(("[EXTERNAL CHANGE WARNING] Rescan found %d change%s: presets added=%d removed=%d modified=%d; folders added=%d removed=%d. Changes made outside CET were accepted into the current list.")
        :format(total, total == 1 and "" or "s", added, removed, modified,
          foldersAdded, foldersRemoved), "warn")
    else
      log("[EXTERNAL CHANGE] Rescan found no changes made outside CET.", "info")
    end
  end

  state.presets = presets
  state.folders = folders
  for folder in pairs(state.expandedLoadFolders) do
    if not folders[folder] then state.expandedLoadFolders[folder] = nil end
  end
  writeInventory(presets, folders)
  if state.selectedFolder ~= "" and not folders[state.selectedFolder] then
    state.selectedFolder = ""
  end
  local count = 0
  for _ in pairs(presets) do count = count + 1 end
  log(("[FILES] Scanned '%s': %d readable preset file%s found (reason=%s).")
    :format(PRESET_DIR, count, count == 1 and "" or "s", tostring(scanReason or "unspecified")), "info")
  return presets
end

local function savePreset(confirmOverwrite)
  auditSection("CREATE PRESET")
  log(("[PRESET] Create requested: enteredName='%s' overwriteConfirmed=%s")
    :format(tostring(state.newName), tostring(confirmOverwrite == true)), "info")
  if not isCustomizationActive() then
    setStatus("create", "Open the character creator, a mirror, or a ripperdoc.", true)
    return
  end
  local leafName, nameError = validatedPresetName(state.newName)
  if not leafName then setStatus("create", nameError, true); return end
  local name = joinFolder(state.selectedFolder, leafName)
  state.pendingDeleteName = nil
  state.loadPresetName = nil
  state.loadPass = 0
  state.loadRemaining = 0
  state.loadNeedsContinue = false
  state.loadStalled = false
  state.previousUnresolvedSignature = nil
  state.unresolvedRepeatCount = 0
  state.autoLoad = false
  state.autoLoadTimer = 0
  state.autoLoadPasses = 0
  state.resetBeforeLoad = false

  local collision = findExistingName(name)
  if collision and collision ~= name then
    state.pendingOverwriteName = nil
    setStatus("create", ("\"%s\" conflicts with \"%s\" because Windows treats them as the same name. Enter another name.")
      :format(name, collision), true)
    return
  end
  if collision == name and not confirmOverwrite then
    state.pendingOverwriteName = name
    setStatus("create", ("\"%s\" already exists. Select Confirm Overwrite to replace it.")
      :format(name), true)
    return
  end
  state.pendingOverwriteName = nil

  local _, options, err = getOptions()
  if not options then setStatus("create", err, true); return end

  local entries = {}
  local savedOccurrences = {}
  for _, option in ipairs(options) do
    local key = legacyOptionKey(option)
    if key and option.isEditable and option.isActive then
      savedOccurrences[key] = (savedOccurrences[key] or 0) + 1
      log(("[SNAPSHOT] Saved %s index=%d editable=true active=true")
        :format(optionAuditIdentity(option, key, savedOccurrences[key]),
          tonumber(option.currIndex) or 0), "info")
      table.insert(entries, {
        key = key,
        index = tonumber(option.currIndex) or 0,
      })
    end
  end
  if #entries == 0 then
    setStatus("create", "No editable options were found.", true)
    return
  end

  local previousPreset = state.presets[name]
  state.presets[name] = {
    format = 4,
    entries = entries,
  }
  state.selected = name
  state.renameName = ""
  state.newName = ""
  state.loadPresetName = nil
  state.loadPass = 0
  state.loadRemaining = 0
  state.loadNeedsContinue = false
  state.loadStalled = false
  state.previousUnresolvedSignature = nil
  state.unresolvedRepeatCount = 0
  state.autoLoad = false
  state.autoLoadTimer = 0
  state.autoLoadPasses = 0
  state.resetBeforeLoad = false
  if not replacePresetFile(name, state.presets[name]) then
    state.presets[name] = previousPreset
    setStatus("create", "Could not write " .. presetPath(name) .. ".", true)
    return
  end
  log(("Created preset '%s': format=4 orderedOptions=%d")
    :format(name, #entries), "info")
  setStatus("create", ("Saved \"%s\" with %d options.")
    :format(name, #entries))
end

local function loadPreset()
  if not state.selected or not state.presets[state.selected] then
    setStatus("load", "Select a preset.", true)
    return
  end
  if not isCustomizationActive() then
    setStatus("load", "Open a customization screen before loading a preset.", true)
    return
  end

  local preset = state.presets[state.selected]
  if state.loadPresetName == state.selected then
    state.loadPass = state.loadPass + 1
  else
    auditSection("LOAD PRESET")
    log(("[PRESET] Load requested: name='%s'"):format(tostring(state.selected)), "load")
    state.loadPresetName = state.selected
    state.loadPass = 1
    state.previousUnresolvedSignature = nil
    state.unresolvedRepeatCount = 0
    state.loadSatisfied = {}
  end
  state.loadStalled = false
  local values, occurrences, savedKeys = {}, {}, {}
  local valueCount = 0
  for _, entry in ipairs(preset.entries or {}) do
    local label = tostring(entry.key or "")
    if label ~= "" then
      occurrences[label] = (occurrences[label] or 0) + 1
      local savedKey = label .. "\31" .. tostring(occurrences[label])
      values[savedKey] = tonumber(entry.index) or 0
      table.insert(savedKeys, savedKey)
      valueCount = valueCount + 1
    end
  end
  local savedCounts = occurrences
  if valueCount == 0 then setStatus("load", "The preset contains no saved options.", true); return end

  local system, options, err = getOptions()
  if not options then setStatus("load", err, true); return end
  if state.loadPass == 1 then
    log(("Preset='%s' | saved=%d options | editor exposes=%d options | format=%s")
      :format(state.selected, valueCount, #options, tostring(preset.format or 1)),
      "load")
  end

  if state.resetBeforeLoad then
    local activeOccurrences = {}
    for _, option in ipairs(options) do
      local label = legacyOptionKey(option)
      local current = tonumber(option.currIndex) or 0
      local occurrence = nil
      if label and option.isEditable and option.isActive then
        activeOccurrences[label] = (activeOccurrences[label] or 0) + 1
        occurrence = activeOccurrences[label]
      end
      if occurrence and occurrence > (savedCounts[label] or 0) and current ~= 0 then
        local ok, clearError = pcall(system.ApplyChangeToOption, system, option, 0)
        if ok then
          state.loadRemaining = valueCount
          state.loadNeedsContinue = true
          state.previousUnresolvedSignature = nil
          state.unresolvedRepeatCount = 0
          log(("CHANGE | pass=%d | %s | index %d -> 0 | reset leftover")
            :format(state.loadPass, optionAuditIdentity(option, label, occurrence),
              current), "info")
          setStatus("load", "Cleared a remaining option. Waiting for the editor.")
        else
          state.resetBeforeLoad = false
          state.loadNeedsContinue = false
          state.loadStalled = true
          log(("FAILED | pass=%d | %s | index %d -> 0 | reset leftover | %s")
            :format(state.loadPass, optionAuditIdentity(option, label, occurrence),
              current, tostring(clearError)), "error")
          setStatus("load", 
            "Loading stopped because a remaining option could not be cleared safely. " ..
            "Close the editor without confirming, reopen it, and retry.",
            true
          )
        end
        return
      end
    end

    state.resetBeforeLoad = false
    state.loadRemaining = valueCount
    state.loadNeedsContinue = true
    state.previousUnresolvedSignature = nil
    state.unresolvedRepeatCount = 0
    log("CLEANUP | No additional leftover options require resetting.", "info")
    setStatus("load", "Cleanup complete. Applying the preset.")
    return
  end

  local activeCounts = {}
  for _, option in ipairs(options) do
    local label = legacyOptionKey(option)
    if label and option.isEditable and option.isActive then
      activeCounts[label] = (activeCounts[label] or 0) + 1
    end
  end

  local applied, skipped, failed, missing, ambiguous = 0, 0, 0, 0, 0
  local unresolved = {}
  local seen = {}
  local exposed = {}
  local activeKeys = {}
  local activeOptionsByKey = {}
  occurrences = {}
  for _, option in ipairs(options) do
    local label = legacyOptionKey(option)
    local key = nil
    if label and option.isEditable and option.isActive then
      occurrences[label] = (occurrences[label] or 0) + 1
      key = label .. "\31" .. tostring(occurrences[label])
    end
    table.insert(exposed, { option = option, label = label, key = key })
    if key then
      table.insert(activeKeys, key)
      activeOptionsByKey[key] = option
    end
  end

  for i = 1, #exposed do
    local exposedOption = exposed[i]
    local option = exposedOption.option
    local label = exposedOption.label
    local key = exposedOption.key
    local wanted = key and values[key] or nil
    local countMatches = label
      and (savedCounts[label] or 0) == (activeCounts[label] or 0)
    if wanted ~= nil then
      seen[key] = true
      if not countMatches then
        ambiguous = ambiguous + 1
        unresolved["ambiguous:" .. tostring(key)] = true
        log(("[SKIPPED] Ambiguous repeated option: %s savedCount=%d exposedCount=%d")
          :format(
            optionAuditIdentity(option, label, occurrences[label]),
            savedCounts[label] or 0,
            activeCounts[label] or 0
          ), "warn")
      end
    end
    if wanted ~= nil and countMatches and option.isEditable and option.isActive then
      local current = tonumber(option.currIndex) or 0
      if current == wanted then
        state.loadSatisfied[key] = true
        applied = applied + 1
      else
        state.loadSatisfied[key] = nil
        local ok, applyError = pcall(system.ApplyChangeToOption, system, option, wanted)
        if ok then
          state.loadSatisfied[key] = true
          state.loadRemaining = math.max(1, valueCount - applied)
          state.loadNeedsContinue = true
          state.previousUnresolvedSignature = nil
          state.unresolvedRepeatCount = 0
          log(("CHANGE | pass=%d | %s | index %s -> %s")
            :format(state.loadPass,
              optionAuditIdentity(option, label, occurrences[label]),
              tostring(current), tostring(wanted)), "info")
          setStatus("load", ("Applied one option. %d %s remain%s to be checked.")
            :format(state.loadRemaining,
              state.loadRemaining == 1 and "option" or "options",
              state.loadRemaining == 1 and "s" or ""))
        else
          state.loadNeedsContinue = false
          state.loadStalled = true
          log(("FAILED | pass=%d | %s | target index %s | %s")
            :format(state.loadPass,
              optionAuditIdentity(option, label, occurrences[label]),
              tostring(wanted), tostring(applyError)), "error")
          setStatus("load", 
            "Loading stopped because an option could not be applied safely. " ..
            "Close the editor without confirming, reopen it, and retry.",
            true
          )
        end
        return
      end
    end
  end

  local activePositions = {}
  for i, key in ipairs(activeKeys) do activePositions[key] = i end

  local replacementCandidates = {}
  for savedIndex, savedKey in ipairs(savedKeys) do
    if not seen[savedKey] then
      local previousPosition, nextPosition = nil, nil
      for i = savedIndex - 1, 1, -1 do
        previousPosition = activePositions[savedKeys[i]]
        if previousPosition then break end
      end
      for i = savedIndex + 1, #savedKeys do
        nextPosition = activePositions[savedKeys[i]]
        if nextPosition then break end
      end
      if previousPosition and nextPosition
          and nextPosition == previousPosition + 2 then
        local replacementKey = activeKeys[previousPosition + 1]
        local replacementOption = replacementKey and activeOptionsByKey[replacementKey]
        if replacementOption and values[replacementKey] == nil then
          local candidate = replacementCandidates[replacementKey]
          if not candidate then
            candidate = { option = replacementOption, savedKeys = {} }
            replacementCandidates[replacementKey] = candidate
          end
          table.insert(candidate.savedKeys, savedKey)
        end
      end
    end
  end

  for replacementKey, candidate in pairs(replacementCandidates) do
    if #candidate.savedKeys == 1 then
      local savedKey = candidate.savedKeys[1]
      local replacementOption = candidate.option
      local wanted = values[savedKey]
      local current = tonumber(replacementOption.currIndex) or 0
      if current == wanted then
        state.loadSatisfied[savedKey] = true
      else
        state.loadSatisfied[savedKey] = nil
        local ok, applyError = pcall(
          system.ApplyChangeToOption,
          system,
          replacementOption,
          wanted
        )
        if ok then
          state.loadSatisfied[savedKey] = true
          state.loadRemaining = math.max(1, valueCount - applied)
          state.loadNeedsContinue = true
          state.previousUnresolvedSignature = nil
          state.unresolvedRepeatCount = 0
          local savedLabel, savedOccurrence = occurrenceKeyParts(savedKey)
          local replacementLabel, replacementOccurrence = occurrenceKeyParts(replacementKey)
          log(("CHANGE (mapped CCXL) | pass=%d | %s | replacement: %s | index %s -> %s")
            :format(state.loadPass,
              optionAuditIdentity(nil, savedLabel, savedOccurrence),
              optionAuditIdentity(replacementOption, replacementLabel,
                replacementOccurrence), tostring(current), tostring(wanted)), "info")
          setStatus("load", ("Applied one replacement CCXL option. %d %s remain%s to be checked.")
            :format(state.loadRemaining,
              state.loadRemaining == 1 and "option" or "options",
              state.loadRemaining == 1 and "s" or ""))
        else
          state.loadNeedsContinue = false
          state.loadStalled = true
          local savedLabel, savedOccurrence = occurrenceKeyParts(savedKey)
          local replacementLabel, replacementOccurrence = occurrenceKeyParts(replacementKey)
          log(("FAILED (mapped CCXL) | pass=%d | %s | replacement: %s | target index=%s | %s")
            :format(state.loadPass,
              optionAuditIdentity(nil, savedLabel, savedOccurrence),
              optionAuditIdentity(replacementOption, replacementLabel,
                replacementOccurrence), tostring(wanted), tostring(applyError)), "error")
          setStatus("load", 
            "Loading stopped because a replacement CCXL option could not be applied safely. " ..
            "Close the editor without confirming, reopen it, and retry.",
            true
          )
        end
        return
      end
    else
      for _, savedKey in ipairs(candidate.savedKeys) do
        unresolved["ambiguous-replacement:" .. tostring(savedKey)] = true
      end
      local replacementLabel, replacementOccurrence = occurrenceKeyParts(replacementKey)
      log(("[SKIPPED] Ambiguous mapped CCXL option: %s competingSavedOptions=%d")
        :format(optionAuditIdentity(candidate.option, replacementLabel,
          replacementOccurrence), #candidate.savedKeys), "warn")
    end
  end
  for key in pairs(values) do
    if not seen[key] then
      if state.loadSatisfied[key] then
        applied = applied + 1
        local hiddenLabel, hiddenOccurrence = occurrenceKeyParts(key)
        log(("VERIFY | %s | target index=%s | applied, then hidden by dependency")
          :format(optionAuditIdentity(nil, hiddenLabel, hiddenOccurrence),
            tostring(values[key])), "info")
      else
        missing = missing + 1
        unresolved["unavailable:" .. tostring(key)] = true
        local missingLabel, missingOccurrence = occurrenceKeyParts(key)
        log(("[SKIPPED] Saved option unavailable in current editor/body setup: %s targetIndex=%s")
          :format(optionAuditIdentity(nil, missingLabel, missingOccurrence),
            tostring(values[key])), "warn")
      end
    end
  end
  state.loadRemaining = failed + skipped + missing + ambiguous
  if state.loadRemaining > 0 then
    local signature = unresolvedSignature(unresolved)
    if state.previousUnresolvedSignature == signature then
      state.unresolvedRepeatCount = state.unresolvedRepeatCount + 1
    else
      state.previousUnresolvedSignature = signature
      state.unresolvedRepeatCount = 1
    end
    if state.unresolvedRepeatCount >= STALL_CONFIRMATION_PASSES then
      state.loadNeedsContinue = false
      state.loadStalled = true
      refreshCustomizationUi()
      log(("SUMMARY | preset='%s' | applied=%d | unresolved=%d | passes=%d | result=stopped")
        :format(state.selected, applied, state.loadRemaining, state.loadPass), "warn")
      log(("Load stalled: preset='%s' pass=%d unresolved=%d signature='%s'")
        :format(state.selected, state.loadPass, state.loadRemaining, signature), "warn")
      setStatus("load", (
        "Loading stopped: %d of %d options never resolved after %d identical checks. " ..
        "Adding, removing, or reordering CCXL mods can change option keys, " ..
        "counts, or indexes. Verify the CCXL setup and correct the appearance if " ..
        "required, then save the preset again from the current editor."
      ):format(state.loadRemaining, valueCount, STALL_CONFIRMATION_PASSES))
    else
      state.loadNeedsContinue = true
      setStatus("load", ("Pass %d complete: %d of %d applied, %d remaining. Continuing automatically.")
        :format(state.loadPass, applied, valueCount, state.loadRemaining), failed > 0)
    end
  else
    state.loadNeedsContinue = false
    state.loadStalled = false
    state.previousUnresolvedSignature = nil
    state.unresolvedRepeatCount = 0
    refreshCustomizationUi()
    log(("SUMMARY | preset='%s' | applied=%d | skipped=0 | failed=0 | unavailable=0 | ambiguous=0 | passes=%d | result=complete")
      :format(state.selected, applied, state.loadPass), "complete")
    setStatus("load", ("Preset fully applied: %d options applied in %d pass%s.")
      :format(valueCount, state.loadPass, state.loadPass == 1 and "" or "es"))
  end
end

local function deletePreset()
  auditSection("DELETE PRESET")
  log(("[PRESET] Delete requested: selected='%s' confirmed=%s")
    :format(tostring(state.selected),
      tostring(state.pendingDeleteName == state.selected)), "info")
  if not state.selected then return end
  local old = state.selected
  local preset = state.presets[old]
  if not preset then
    setStatus("delete", "The selected preset is no longer available.", true)
    return
  end
  if state.pendingDeleteName ~= old then
    state.pendingDeleteName = old
    setStatus("delete", ("Permanently delete \"%s\"? Select Confirm Delete to continue.")
      :format(old))
    return
  end
  state.pendingDeleteName = nil

  local removed, removeError = os.remove(presetPath(old))
  if not removed then
    setStatus("delete", ("Could not delete \"%s\": %s")
      :format(old, tostring(removeError)), true)
    return
  end
  state.presets[old] = nil
  state.selected = nil
  state.renameName = ""
  state.loadPresetName = nil
  state.loadPass = 0
  state.loadRemaining = 0
  state.loadNeedsContinue = false
  state.loadStalled = false
  state.previousUnresolvedSignature = nil
  state.unresolvedRepeatCount = 0
  state.autoLoad = false
  state.autoLoadTimer = 0
  state.autoLoadPasses = 0
  state.resetBeforeLoad = false
  state.renameStatus = ""
  state.renameStatusError = false
  setStatus("delete", "Deleted \"" .. old .. "\".")
end

local function renamePreset()
  auditSection("RENAME PRESET")
  log(("Rename requested: selected='%s' input='%s'")
    :format(tostring(state.selected), tostring(state.renameName)), "info")
  if not state.selected or not state.presets[state.selected] then
    setStatus("rename", "Select a preset before renaming it.", true)
    return
  end
  local newLeafName, nameError = validatedPresetName(state.renameName)
  if not newLeafName then setStatus("rename", nameError, true); return end
  state.pendingDeleteName = nil
  local old = state.selected
  local newName = joinFolder(parentFolder(old), newLeafName)
  if newName == old then
    setStatus("rename", "The preset already has this name.")
    return
  end
  if newName ~= old and newName:lower() == old:lower() then
    setStatus("rename", "Windows cannot distinguish those names by capitalization. Enter another name.", true)
    return
  end
  local collision = findExistingName(newName, old)
  if collision then
    setStatus("rename", ("A preset named \"%s\" already exists."):format(collision), true)
    return
  end
  state.presets[newName] = state.presets[old]
  if not writePresetFile(newName, state.presets[newName]) then
    state.presets[newName] = nil
    setStatus("rename", "Could not write " .. presetPath(newName) .. ".", true)
    return
  end
  if not readPresetFile(presetPath(newName)) then
    state.presets[newName] = nil
    setStatus("rename", "The renamed file could not be verified. The original file was retained.", true)
    return
  end
  local removed, removeError = os.remove(presetPath(old))
  if not removed then
    os.remove(presetPath(newName))
    state.presets[newName] = nil
    setStatus("rename", ("Could not remove the old preset file: %s"):format(tostring(removeError)), true)
    return
  end
  state.presets[old] = nil
  refreshPresets("internal:rename preset")
  state.selected = newName
  state.renameName = ""
  state.loadPresetName = nil
  state.loadPass = 0
  state.loadRemaining = 0
  state.loadNeedsContinue = false
  state.loadStalled = false
  state.previousUnresolvedSignature = nil
  state.unresolvedRepeatCount = 0
  state.autoLoad = false
  state.autoLoadTimer = 0
  state.autoLoadPasses = 0
  state.resetBeforeLoad = false
  state.deleteStatus = ""
  state.deleteStatusError = false
  setStatus("rename", "Renamed \"" .. old .. "\" to \"" .. newName .. "\".")
end

local function movePresetToSelectedFolder()
  auditSection("MOVE PRESET")
  log(("[PRESET] Move requested: selected='%s' destinationFolder='%s'.")
    :format(tostring(state.selected), state.selectedFolder == "" and "<root>" or state.selectedFolder), "info")
  if not state.selected or not state.presets[state.selected] then
    state.folderStatus, state.folderStatusError = "Select a preset before moving it.", true; return
  end
  local old = state.selected
  local newName = joinFolder(state.selectedFolder, baseName(old))
  if newName == old then
    state.folderStatus, state.folderStatusError = "The preset is already in the selected folder.", false; return
  end
  local collision = findExistingName(newName, old)
  if collision then
    state.folderStatus, state.folderStatusError =
      ("A preset named \"%s\" already exists there."):format(baseName(collision)), true
    return
  end
  local preset = state.presets[old]
  if not writePresetFile(newName, preset) or not presetsMatch(preset, readPresetFile(presetPath(newName))) then
    os.remove(presetPath(newName))
    state.folderStatus, state.folderStatusError =
      "The preset could not be copied to that folder.", true; return
  end
  local removed, removeError = os.remove(presetPath(old))
  if not removed then
    os.remove(presetPath(newName))
    state.folderStatus, state.folderStatusError =
      ("Could not remove the old preset file: %s"):format(tostring(removeError)), true; return
  end
  log(("[FILES] Move completed: old='%s' new='%s'."):format(presetPath(old), presetPath(newName)), "info")
  refreshPresets("internal:move preset")
  state.selected = newName
  state.pendingDeleteName = nil
  state.folderStatus, state.folderStatusError =
    ("Moved \"%s\" to %s."):format(baseName(newName),
      state.selectedFolder == "" and "All Presets" or state.selectedFolder), false
end

local function duplicatePreset()
  auditSection("DUPLICATE PRESET")
  log(("[PRESET] Duplicate requested: selected='%s'."):format(tostring(state.selected)), "info")
  if not state.selected or not state.presets[state.selected] then
    setStatus("rename", "Select a preset before duplicating it.", true); return
  end
  local source = state.selected
  local destination = uniquePresetCopyName(source)
  if not destination then
    setStatus("rename", "Could not find an available name for the duplicate.", true); return
  end
  local preset = state.presets[source]
  log(("[PRESET] Duplicate target selected: source='%s' destination='%s'."):format(source, destination), "info")
  if not writePresetFile(destination, preset)
      or not presetsMatch(preset, readPresetFile(presetPath(destination))) then
    os.remove(presetPath(destination))
    setStatus("rename", "The duplicate could not be written and verified.", true); return
  end
  refreshPresets("internal:duplicate preset")
  state.selected = destination
  state.pendingDeleteName = nil
  state.renameName = ""
  state.loadPresetName = nil
  state.loadPass = 0
  state.loadRemaining = 0
  state.loadNeedsContinue = false
  state.autoLoad = false
  log(("[PRESET] Duplicate verified: source='%s' destination='%s' entries=%d.")
    :format(source, destination, #(preset.entries or {})), "complete")
  setStatus("rename", ("Duplicated \"%s\" as \"%s\"."):format(source, destination))
end

local function createFolder()
  auditSection("CREATE FOLDER")
  log(("[FOLDER] Create requested: enteredName='%s'."):format(tostring(state.folderName)), "info")
  local name, nameError = validatedFolderName(state.folderName)
  if not name then state.folderStatus, state.folderStatusError = nameError, true; return end
  if state.folders[name] then
    state.folderStatus, state.folderStatusError = "The folder already exists.", true; return
  end
  if not acquireFolderSlot(folderPath(name)) then
    state.folderStatus, state.folderStatusError = "The folder could not be created because no folder slots are available.", true; return
  end
  refreshPresets("internal:create folder")
  state.selectedFolder = name
  state.folderName = ""
  state.folderStatus, state.folderStatusError = "Created folder \"" .. name .. "\".", false
  log(("[FOLDER] Created and selected '%s'."):format(name), "complete")
end

local function renameFolder()
  auditSection("RENAME FOLDER")
  log(("[FOLDER] Rename requested: selected='%s' enteredName='%s'.")
    :format(tostring(state.selectedFolder), tostring(state.folderRenameName)), "info")
  if state.selectedFolder == "" then
    state.folderStatus, state.folderStatusError = "Select a folder to rename.", true; return
  end
  local newName, nameError = validatedFolderName(state.folderRenameName)
  if not newName then state.folderStatus, state.folderStatusError = nameError, true; return end
  local old = state.selectedFolder
  local destination = joinFolder(parentFolder(old), newName)
  if destination == old then
    state.folderStatus, state.folderStatusError = "The folder already has this name.", false; return
  end
  if state.folders[destination] then
    state.folderStatus, state.folderStatusError = "The folder already exists.", true; return
  end
  local selectedBeforeRename = state.selected
  local moved, moveError = os.rename(folderPath(old), folderPath(destination))
  if not moved then
    state.folderStatus, state.folderStatusError = ("Could not rename the folder: %s"):format(tostring(moveError)), true; return
  end
  refreshPresets("internal:rename folder")
  state.selectedFolder = destination
  if selectedBeforeRename and selectedBeforeRename:sub(1, #old + 1) == old .. "/" then
    state.selected = destination .. selectedBeforeRename:sub(#old + 1)
  end
  state.loadPresetName = nil
  state.autoLoad = false
  state.folderRenameName = ""
  state.folderStatus, state.folderStatusError = ("Renamed folder \"%s\" to \"%s\"."):format(old, destination), false
  log(("[FOLDER] Renamed '%s' -> '%s'."):format(old, destination), "complete")
end

local function duplicateFolder()
  auditSection("DUPLICATE FOLDER")
  local source = state.selectedFolder
  log(("[FOLDER] Duplicate requested: selected='%s'."):format(tostring(source)), "info")
  if source == "" or not state.folders[source] then
    state.folderStatus, state.folderStatusError = "Select a folder to duplicate.", true; return
  end
  local destination = uniqueFolderCopyName(source)
  if not destination then
    state.folderStatus, state.folderStatusError = "Could not find an available name for the duplicate folder.", true; return
  end
  log(("[FOLDER] Duplicate target selected: source='%s' destination='%s'."):format(source, destination), "info")

  local function cleanup(relative, recycleSelf)
    local ok, contents = pcall(dir, folderPath(relative))
    if ok and type(contents) == "table" then
      for _, entry in pairs(contents) do
        local filename = type(entry) == "table" and entry.name or tostring(entry)
        local entryType = type(entry) == "table" and entry.type or nil
        if filename and filename ~= "." and filename ~= ".." then
          local child = joinFolder(relative, filename)
          local isDirectory = entryType == "directory"
          if entryType == nil then
            local childOk, childContents = pcall(dir, folderPath(child))
            isDirectory = childOk and type(childContents) == "table"
          end
          if isDirectory then
            cleanup(child, true)
          else
            local removed, removeError = os.remove(folderPath(child))
            log(("[FOLDER ROLLBACK] Removed file='%s' success=%s error=%s.")
              :format(folderPath(child), tostring(removed ~= nil), tostring(removeError)), removed and "info" or "error")
          end
        end
      end
    end
    if recycleSelf then recycleFolder(folderPath(relative)) end
  end

  local function copyTree(sourceRelative, destinationRelative)
    local ok, contents = pcall(dir, folderPath(sourceRelative))
    if not ok or type(contents) ~= "table" then return false end
    for _, entry in pairs(contents) do
      local filename = type(entry) == "table" and entry.name or tostring(entry)
      local entryType = type(entry) == "table" and entry.type or nil
      if filename and filename ~= "." and filename ~= ".." then
        local sourceChild = joinFolder(sourceRelative, filename)
        local destinationChild = joinFolder(destinationRelative, filename)
        local isDirectory = entryType == "directory"
        if entryType == nil then
          local childOk, childContents = pcall(dir, folderPath(sourceChild))
          isDirectory = childOk and type(childContents) == "table"
        end
        if isDirectory then
          log(("[FOLDER COPY] Creating nested folder source='%s' destination='%s'.")
            :format(sourceChild, destinationChild), "info")
          if not acquireFolderSlot(folderPath(destinationChild))
              or not copyTree(sourceChild, destinationChild) then return false end
        elseif not copyFile(folderPath(sourceChild), folderPath(destinationChild)) then
          return false
        end
      end
    end
    return true
  end

  if not acquireFolderSlot(folderPath(destination)) then
    state.folderStatus, state.folderStatusError = "The folder could not be duplicated because no folder slots are available.", true; return
  end
  if not copyTree(source, destination) then
    log(("[FOLDER ROLLBACK] Duplicate failed; removing partial destination='%s'."):format(destination), "warn")
    cleanup(destination, true)
    log(("[FOLDER ROLLBACK] Partial destination cleanup finished for '%s'."):format(destination), "info")
    state.folderStatus, state.folderStatusError = "Duplicate failed. The partial copy was removed.", true; return
  end
  refreshPresets("internal:duplicate folder")
  state.selectedFolder = destination
  state.pendingDeleteFolder = nil
  state.pendingDeleteFolderStage = 0
  state.pendingDeleteFolderPresetCount = 0
  state.pendingDeleteFolderHasContents = false
  state.folderStatus, state.folderStatusError =
    ("Duplicated folder \"%s\" as \"%s\"."):format(source, destination), false
  log(("[FOLDER] Duplicate completed: source='%s' destination='%s'."):format(source, destination), "complete")
end

local function deleteFolder()
  auditSection("DELETE FOLDER")
  local folder = state.selectedFolder
  log(("[FOLDER] Delete click: selected='%s' pending='%s' stage=%d.")
    :format(tostring(folder), tostring(state.pendingDeleteFolder), tonumber(state.pendingDeleteFolderStage) or 0), "info")
  if folder == "" then
    state.folderStatus, state.folderStatusError = "Select a folder to delete.", true; return
  end

  local filesToDelete = {}
  local foldersToDelete = {}
  local presetCount = 0
  local meaningfulFileCount = 0
  local function inspect(relative)
    local ok, contents = pcall(dir, folderPath(relative))
    if not ok or type(contents) ~= "table" then return false end
    for _, entry in pairs(contents) do
      local filename = type(entry) == "table" and entry.name or tostring(entry)
      local entryType = type(entry) == "table" and entry.type or nil
      if filename and filename ~= "." and filename ~= ".." then
        local child = joinFolder(relative, filename)
        local isDirectory = entryType == "directory"
        if entryType == nil then
          local childOk, childContents = pcall(dir, folderPath(child))
          isDirectory = childOk and type(childContents) == "table"
        end
        if isDirectory then
          if not inspect(child) then return false end
          table.insert(foldersToDelete, folderPath(child))
        else
          table.insert(filesToDelete, folderPath(child))
          if filename:match("%.preset$") then presetCount = presetCount + 1 end
          if filename ~= ".Character Preset Manager Folder"
              and filename ~= "__folder_managed_by_vortex" then
            meaningfulFileCount = meaningfulFileCount + 1
          end
        end
      end
    end
    return true
  end

  if not inspect(folder) then
    log(("[FOLDER] Inspection failed for '%s'."):format(folder), "error")
    state.folderStatus, state.folderStatusError = "The folder contents could not be verified.", true; return
  end
  log(("[FOLDER] Inspection complete: folder='%s' files=%d nestedFolders=%d presets=%d meaningfulFiles=%d.")
    :format(folder, #filesToDelete, #foldersToDelete, presetCount, meaningfulFileCount), "info")

  if state.pendingDeleteFolder ~= folder or state.pendingDeleteFolderStage == 0 then
    local hasContents = meaningfulFileCount > 0 or #foldersToDelete > 0
    state.pendingDeleteFolder = folder
    state.pendingDeleteFolderStage = hasContents and 1 or 2
    state.pendingDeleteFolderPresetCount = presetCount
    state.pendingDeleteFolderHasContents = hasContents
    if hasContents then
      state.folderStatus, state.folderStatusError =
        ("Delete \"%s\" and all contents? This will permanently delete %d preset%s. Select Confirm Delete Folder.")
          :format(folder, presetCount, presetCount == 1 and "" or "s"), false
    else
      state.folderStatus, state.folderStatusError =
          "Delete empty folder \"" .. folder .. "\"? Select Confirm Delete Empty Folder.", false
    end
    log(("[FOLDER] Delete confirmation armed: folder='%s' stage=%d hasContents=%s presets=%d.")
      :format(folder, state.pendingDeleteFolderStage, tostring(hasContents), presetCount), "warn")
    return
  end
  if state.pendingDeleteFolderStage == 1 then
    state.pendingDeleteFolderStage = 2
    state.folderStatus, state.folderStatusError =
      "This action cannot be undone. Select Permanently Delete Folder to continue.", false
    log(("[FOLDER] Final delete confirmation armed: folder='%s' presets=%d.")
      :format(folder, presetCount), "warn")
    return
  end

  for _, path in ipairs(filesToDelete) do
    local removed, removeError = os.remove(path)
    log(("[FILES] Delete folder content: path='%s' success=%s error=%s.")
      :format(path, tostring(removed ~= nil), tostring(removeError)), removed and "info" or "error")
    if not removed then
      state.folderStatus, state.folderStatusError =
        ("Deletion stopped because '%s' could not be removed: %s"):format(path, tostring(removeError)), true
      return
    end
  end
  for _, path in ipairs(foldersToDelete) do
    local removed, removeError = os.remove(path)
    log(("[FILES] Delete nested folder: path='%s' success=%s error=%s.")
      :format(path, tostring(removed ~= nil), tostring(removeError)), removed and "info" or "error")
    if not removed then
      state.folderStatus, state.folderStatusError =
        ("Deletion stopped because nested folder '%s' could not be removed: %s"):format(path, tostring(removeError)), true
      return
    end
  end
  if not recycleFolder(folderPath(folder)) then
    state.folderStatus, state.folderStatusError = "The contents were deleted, but the empty folder could not be recycled.", true; return
  end
  state.selectedFolder = ""
  state.pendingDeleteFolder = nil
  state.pendingDeleteFolderStage = 0
  state.pendingDeleteFolderPresetCount = 0
  state.pendingDeleteFolderHasContents = false
  refreshPresets("internal:delete folder")
  state.folderStatus, state.folderStatusError =
    ("Permanently deleted folder \"%s\" and %d preset%s.")
      :format(folder, presetCount, presetCount == 1 and "" or "s"), false
  log(("[FOLDER] Delete completed: folder='%s' files=%d nestedFolders=%d presets=%d.")
    :format(folder, #filesToDelete, #foldersToDelete, presetCount), "complete")
end

local function refreshEditorState()
  state.inCustomization = isCustomizationActive()
end


local THEME_COLORS = {
  { ImGuiCol.WindowBg,          0.055, 0.059, 0.078, 0.98 },
  { ImGuiCol.ChildBg,           0.086, 0.094, 0.118, 0.85 },
  { ImGuiCol.PopupBg,           0.075, 0.082, 0.102, 0.98 },
  { ImGuiCol.Border,            0.95,  0.72,  0.20,  0.55 },
  { ImGuiCol.TitleBg,           0.075, 0.055, 0.03,  1.0  },
  { ImGuiCol.TitleBgActive,     0.55,  0.35,  0.05,  1.0  },
  { ImGuiCol.Text,              1.0,   1.0,   1.0,   1.0  },
  { ImGuiCol.TextDisabled,      0.64,  0.67,  0.73,  1.0  },
  { ImGuiCol.FrameBg,           0.13,  0.14,  0.17,  1.0  },
  { ImGuiCol.FrameBgHovered,    0.19,  0.20,  0.24,  1.0  },
  { ImGuiCol.FrameBgActive,     0.22,  0.23,  0.28,  1.0  },
  { ImGuiCol.Button,            0.72,  0.42,  0.08,  0.92 },
  { ImGuiCol.ButtonHovered,     0.52,  0.29,  0.05,  1.0  },
  { ImGuiCol.ButtonActive,      0.36,  0.19,  0.03,  1.0  },
  { ImGuiCol.Header,            0.24,  0.32,  0.42,  0.65 },
  { ImGuiCol.HeaderHovered,     0.28,  0.38,  0.50,  0.65 },
  { ImGuiCol.HeaderActive,      0.24,  0.32,  0.42,  0.90 },
  { ImGuiCol.CheckMark,         0.97,  0.72,  0.20,  1.0  },
  { ImGuiCol.SliderGrab,        0.97,  0.72,  0.20,  1.0  },
  { ImGuiCol.SliderGrabActive,  0.85,  0.55,  0.10,  1.0  },
  { ImGuiCol.Separator,         0.95,  0.72,  0.20,  0.35 },
  { ImGuiCol.SeparatorHovered,  0.97,  0.75,  0.25,  0.6  },
  { ImGuiCol.ScrollbarBg,       0.06,  0.065, 0.08,  0.6  },
  { ImGuiCol.ScrollbarGrab,     0.30,  0.28,  0.22,  0.9  },
  { ImGuiCol.ScrollbarGrabHovered, 0.45, 0.38, 0.20, 1.0  },
  { ImGuiCol.ScrollbarGrabActive,  0.55, 0.42, 0.14, 1.0  },
}

local THEME_VARS = {
  { ImGuiStyleVar.WindowRounding,   8.0 },
  { ImGuiStyleVar.ChildRounding,    6.0 },
  { ImGuiStyleVar.FrameRounding,    4.0 },
  { ImGuiStyleVar.GrabRounding,     4.0 },
  { ImGuiStyleVar.PopupRounding,    6.0 },
  { ImGuiStyleVar.ScrollbarRounding,6.0 },
  { ImGuiStyleVar.WindowBorderSize, 1.0 },
  { ImGuiStyleVar.ChildBorderSize,  1.0 },
  { ImGuiStyleVar.FrameBorderSize,  1.0 },
  { ImGuiStyleVar.WindowPadding,    14.0, 14.0 },
  { ImGuiStyleVar.FramePadding,     8.0,  5.0  },
  { ImGuiStyleVar.ItemSpacing,      8.0,  8.0  },
}

local function pushTheme()
  for _, c in ipairs(THEME_COLORS) do
    ImGui.PushStyleColor(c[1], c[2], c[3], c[4], c[5])
  end
  for _, v in ipairs(THEME_VARS) do
    if v[3] then
      ImGui.PushStyleVar(v[1], v[2], v[3])
    else
      ImGui.PushStyleVar(v[1], v[2])
    end
  end
end

local function popTheme()
  ImGui.PopStyleVar(#THEME_VARS)
  ImGui.PopStyleColor(#THEME_COLORS)
end

local function collapsibleSectionHeader(label, key)
  ImGui.Spacing()
  ImGui.PushStyleColor(ImGuiCol.Text, 0.97, 0.72, 0.20, 1.0)
  local flags = state.openSections[key] ~= false and ImGuiTreeNodeFlags.DefaultOpen or 0
  local open = ImGui.CollapsingHeader(label .. "##section:" .. key, flags)
  ImGui.PopStyleColor()
  ImGui.Separator()
  if open then ImGui.Spacing() end
  return open
end

local function drawCompatibilityWarnings()
  ImGui.Spacing()
  ImGui.PushStyleColor(ImGuiCol.Header, 0.56, 0.10, 0.10, 0.92)
  ImGui.PushStyleColor(ImGuiCol.HeaderHovered, 0.72, 0.16, 0.14, 1.0)
  ImGui.PushStyleColor(ImGuiCol.HeaderActive, 0.45, 0.07, 0.07, 1.0)
  ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 0.82, 0.82, 1.0)
  local open = ImGui.CollapsingHeader(
    "COMPATIBILITY WARNINGS - READ FIRST##compatibilityWarnings",
    ImGuiTreeNodeFlags.DefaultOpen
  )
  ImGui.PopStyleColor(4)
  if not open then return end
  ImGui.PushStyleColor(ImGuiCol.ChildBg, 0.12, 0.055, 0.055, 0.88)
  ImGui.PushStyleColor(ImGuiCol.Border, 0.90, 0.25, 0.22, 0.90)
  ImGui.BeginChild("##compatibilityWarningsBody", 0, 245, true)
  coloredWrapped(1.0, 0.4, 0.4, 1.0,
    "Appearance Change Unlocker (ACU) and Character Customization Anywhere are incompatible. Remove both mods, close Cyberpunk 2077, and restart the game.")
  ImGui.Spacing()
  coloredWrapped(1.0, 0.4, 0.4, 1.0,
    "Photo Mode and Appearance Menu Mod are not supported.")
  ImGui.Spacing()
  ImGui.TextWrapped("A game bug can cause infinite loading when customization closes. It can also occur with vanilla mirrors, Equipment-EX, or detailed outfits.")
  coloredWrapped(1.0, 0.8, 0.2, 1.0,
    "Workaround: unequip all clothing and select No Outfit before opening customization. Re-equip all items afterward.")
  ImGui.Spacing()
  ImGui.TextWrapped("Use the same customization mods and load order used when the preset was created.")
  coloredWrapped(1.0, 0.8, 0.2, 1.0,
    "If the setup changed, correct the appearance and save the preset again.")
  ImGui.EndChild()
  ImGui.PopStyleColor(2)
end

local function fullWidthButton(label, height)
  local width = ImGui.GetContentRegionAvail()
  return ImGui.Button(label, width, height or 32)
end

local function dangerButton(label, width, height)
  ImGui.PushStyleColor(ImGuiCol.Button,        0.62, 0.16, 0.13, 0.92)
  ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.78, 0.20, 0.16, 1.0)
  ImGui.PushStyleColor(ImGuiCol.ButtonActive,  0.48, 0.11, 0.09, 1.0)
  local pressed = ImGui.Button(label, width, height or 32)
  ImGui.PopStyleColor(3)
  return pressed
end

local function coloredWrapped(r, g, b, a, text)
  ImGui.PushStyleColor(ImGuiCol.Text, r, g, b, a)
  ImGui.TextWrapped(text)
  ImGui.PopStyleColor(1)
end

local function drawSectionStatus(section, childId, isSuccess, height)
  local text = state[section .. "Status"]
  if not text or text == "" then return end
  local isError = state[section .. "StatusError"]
  local clothingWarning = section == "load"
    and not isError
    and state.inCustomization
    and not isNewGameCharacterCreator()
    and not state.autoLoad
    and not state.loadNeedsContinue
    and text:find("Open the character creator", 1, true) == 1
    and hasEquippedClothing()
  if clothingWarning then
    text = "Unequip all clothing before loading a preset. Clothing can trigger infinite loading when customization closes. Select No Outfit in the wardrobe."
  end
  local success = not isError and isSuccess and isSuccess(text)
  local destructiveWarning = (section == "delete"
      and state.pendingDeleteName ~= nil
      and state.pendingDeleteName == state.selected)
    or (section == "folder"
      and state.pendingDeleteFolder ~= nil
      and state.pendingDeleteFolder == state.selectedFolder
      and state.pendingDeleteFolderStage > 0)
  local customColors = false
  ImGui.Spacing()
  if isError or destructiveWarning then
    ImGui.PushStyleColor(ImGuiCol.ChildBg, 0.086, 0.094, 0.118, 0.85)
    ImGui.PushStyleColor(ImGuiCol.Border, 0.90, 0.25, 0.22, 0.90)
    customColors = true
  elseif clothingWarning then
    ImGui.PushStyleColor(ImGuiCol.ChildBg, 0.086, 0.094, 0.118, 0.85)
    ImGui.PushStyleColor(ImGuiCol.Border, 0.97, 0.72, 0.20, 0.90)
    customColors = true
  elseif success then
    ImGui.PushStyleColor(ImGuiCol.ChildBg, 0.086, 0.094, 0.118, 0.85)
    ImGui.PushStyleColor(ImGuiCol.Border, 0.22, 0.78, 0.34, 0.90)
    customColors = true
  end
  local estimatedLines = math.max(1, math.ceil(#tostring(text) / 48))
  local panelHeight = math.min(126, math.max(height or 64, 40 + estimatedLines * 18))
  ImGui.BeginChild(childId, 0, panelHeight, true)
  if isError then
    ImGui.TextColored(1.0, 0.4, 0.4, 1.0, "ERROR")
    coloredWrapped(1.0, 1.0, 1.0, 1.0, text)
  elseif destructiveWarning then
    ImGui.TextColored(1.0, 0.4, 0.4, 1.0, "WARNING")
    coloredWrapped(1.0, 0.4, 0.4, 1.0, text)
  elseif clothingWarning then
    ImGui.TextColored(1.0, 0.8, 0.2, 1.0, "CLOTHING DETECTED")
    coloredWrapped(1.0, 1.0, 1.0, 1.0, text)
  elseif section == "load" and state.loadStalled then
    ImGui.TextColored(1.0, 0.55, 0.15, 1.0, "ATTENTION")
    coloredWrapped(1.0, 1.0, 1.0, 1.0, text)
  elseif section == "load" and state.loadRemaining > 0 then
    ImGui.TextColored(1.0, 0.8, 0.2, 1.0, "LOADING")
    coloredWrapped(1.0, 1.0, 1.0, 1.0, text)
  elseif success then
    local successLabel = text:find("Open the character creator", 1, true) == 1
      and "READY" or "SUCCESS"
    ImGui.TextColored(0.3, 1.0, 0.4, 1.0, successLabel)
    coloredWrapped(1.0, 1.0, 1.0, 1.0, text)
  else
    ImGui.TextColored(0.97, 0.72, 0.20, 1.0, "STATUS")
    coloredWrapped(1.0, 1.0, 1.0, 1.0, text)
  end
  ImGui.EndChild()
  if customColors then ImGui.PopStyleColor(2) end
end

local function isLoadSuccess(text)
  return text:find("Preset fully applied", 1, true) ~= nil
    or text:find("Open the character creator", 1, true) == 1
end
local function isCreateSuccess(text) return text:find("^Saved ") ~= nil end
local function isRenameSuccess(text) return text:find("^Renamed ") ~= nil end
local function isDeleteSuccess(text) return text:find("^Deleted ") ~= nil end
local function isEditorSuccess(text) return text == "Full editor opened." end
local function isFolderSuccess(text)
  return text:find("^Created folder ") ~= nil
    or text:find("^Renamed folder ") ~= nil
    or text:find("^Duplicated folder ") ~= nil
    or text:find("^Permanently deleted folder ") ~= nil
end

local function readDiagnosticLog()
  local file = io.open(LOG_FILE, "r")
  if not file then
    state.debugLogText = "No activity log yet — nothing's happened this session."
    return
  end
  local ok, contents = pcall(file.read, file, "*a")
  file:close()
  if not ok or type(contents) ~= "string" then
    state.debugLogText = "The activity log could not be read."
    return
  end
  local limit = 65536
  if #contents > limit then
    contents = "[Showing the newest 64 KB of Character Preset Manager (CET) Activity.log]\n\n" ..
      contents:sub(#contents - limit + 1)
  end
  state.debugLogText = contents ~= "" and contents or "Character Preset Manager (CET) Activity.log is empty."
end

local function drawDebugPanel(height)
  ImGui.Spacing()
  local logRowStartX = ImGui.GetCursorPosX()
  local logRowWidth = ImGui.GetContentRegionAvail()
  local logButtonsWidth = 128
  ImGui.TextColored(0.97, 0.72, 0.20, 1.0, "Character Preset Manager Log")
  ImGui.SameLine()
  ImGui.SetCursorPosX(logRowStartX + logRowWidth - logButtonsWidth)
  if ImGui.Button("Refresh##debugRefresh", 68, 0) then readDiagnosticLog() end
  ImGui.SameLine()
  if ImGui.Button("Copy##debugCopy", 52, 0) then
    ImGui.SetClipboardText(state.debugLogText or "")
  end
  ImGui.TextWrapped(("Editor launch: input=%d  controller=%d  redirect=%d  puppet=%d")
    :format(state.editorInputCount, state.editorControllerCaptureCount,
      state.editorPauseRedirectCount, state.editorPuppetReadyCount))
  ImGui.TextDisabled("After one successful hotkey launch, all four values should be at least 1.")
  ImGui.TextColored(0.3, 1.0, 0.4, 1.0, "Green = complete")
  ImGui.SameLine()
  ImGui.TextColored(0.75, 0.77, 0.82, 1.0, "|")
  ImGui.SameLine()
  ImGui.TextColored(1.0, 0.8, 0.2, 1.0, "Yellow = warning")
  ImGui.SameLine()
  ImGui.TextColored(0.75, 0.77, 0.82, 1.0, "|")
  ImGui.SameLine()
  ImGui.TextColored(1.0, 0.4, 0.4, 1.0, "Red = error")
  ImGui.Spacing()
  ImGui.BeginChild("##debugLog", 0, height or 200, true)
  for line in ((state.debugLogText or "") .. "\n"):gmatch("(.-)\n") do
    local lowerLine = line:lower()
    if line == "" then
      ImGui.Spacing()
    elseif lowerLine:find("[load error]", 1, true)
        or lowerLine:find("[error]", 1, true) then
      coloredWrapped(1.0, 0.4, 0.4, 1.0, line)
    elseif lowerLine:find("[load warning]", 1, true)
        or lowerLine:find("[warn]", 1, true) then
      coloredWrapped(1.0, 0.8, 0.2, 1.0, line)
    elseif lowerLine:find("[complete]", 1, true) then
      coloredWrapped(0.3, 1.0, 0.4, 1.0, line)
    elseif lowerLine:find("[load]", 1, true) then
      coloredWrapped(1.0, 1.0, 1.0, 1.0, line)
    elseif lowerLine:find("[info]", 1, true) then
      coloredWrapped(1.0, 1.0, 1.0, 1.0, line)
    elseif lowerLine:find("error", 1, true)
        or lowerLine:find("could not", 1, true)
        or lowerLine:find("not available", 1, true) then
      coloredWrapped(1.0, 0.4, 0.4, 1.0, line)
    else
      ImGui.TextDisabled(line)
    end
  end
  ImGui.EndChild()
end

local function helpHeading(text)
  ImGui.Spacing()
  ImGui.TextColored(0.97, 0.72, 0.20, 1.0, text)
  ImGui.Separator()
end

local function pathCallout(childId, label, path)
  ImGui.Spacing()
  ImGui.PushStyleColor(ImGuiCol.ChildBg, 0.086, 0.094, 0.118, 0.85)
  ImGui.PushStyleColor(ImGuiCol.Border, 0.95, 0.72, 0.20, 0.55)
  local pathLines = math.max(1, math.ceil(#tostring(path) / 48))
  local calloutHeight = math.min(118, 38 + pathLines * 18)
  ImGui.BeginChild(childId, 0, calloutHeight, true)
  ImGui.TextColored(0.97, 0.72, 0.20, 1.0, label)
  coloredWrapped(1.0, 1.0, 1.0, 1.0, path)
  ImGui.EndChild()
  ImGui.PopStyleColor(2)
end

local function defaultWindowPosition()
  local displayWidth = nil
  local resolutionOk, resolutionWidth = pcall(function()
    if GetDisplayResolution then
      local width = GetDisplayResolution()
      return width
    end
    return nil
  end)
  if resolutionOk then displayWidth = tonumber(resolutionWidth) end

  local sizeOk, first, second = pcall(function()
    if displayWidth then return nil end
    if ImGui.GetDisplaySize then return ImGui.GetDisplaySize() end
    if ImGui.GetIO then
      local io = ImGui.GetIO()
      return io and io.DisplaySize or nil
    end
    return nil
  end)
  if not displayWidth and sizeOk then
    displayWidth = tonumber(first)
    if not displayWidth and first then
      local widthOk, width = pcall(function()
        return first.x or first.X or first[1]
      end)
      if widthOk then displayWidth = tonumber(width) end
    end
    if not displayWidth then displayWidth = tonumber(second) end
  end
  if not displayWidth or displayWidth <= 460 then return nil, displayWidth end
  return math.max(20, displayWidth - 440), displayWidth
end

local function draw()
  if not state.overlayOpen or not state.windowOpen then return end
  if state.editorStateRefreshTimer >= EDITOR_STATE_REFRESH_INTERVAL then
    refreshEditorState()
    state.editorStateRefreshTimer = 0
  end

  pushTheme()
  local initialX, displayWidth = defaultWindowPosition()
  if initialX then
    local positionCondition = state.initialWindowPlacementPending
      and ImGuiCond.Always or ImGuiCond.FirstUseEver
    ImGui.SetNextWindowPos(initialX, 40, positionCondition)
  end
  ImGui.SetNextWindowSize(420, 700, ImGuiCond.FirstUseEver)
  local visible = ImGui.Begin("Character Preset Manager (CET)##CPM2")
  if state.initialWindowPlacementPending and initialX then
    state.initialWindowPlacementPending = false
    log(("[UI] Initial window position forced to the right: displayWidth=%s x=%s y=40.")
      :format(tostring(displayWidth), tostring(initialX)), "info")
    local status = io.open(WINDOW_POSITION_STATUS_FILE, "w")
    if status then
      local wrote = status:write((
        "Character Preset Manager (CET) initial right-side position applied.\n" ..
        "Applied: %s\nDisplay width: %s\nInitial X: %s\n"
      ):format(logTimestamp(), tostring(displayWidth), tostring(initialX)))
      status:close()
      log(("[UI] Window position status written: file='%s' success=%s.")
        :format(WINDOW_POSITION_STATUS_FILE, tostring(wrote ~= nil)),
        wrote and "info" or "error")
    else
      log(("[UI] Could not write window position status '%s'; startup placement will retry next launch.")
        :format(WINDOW_POSITION_STATUS_FILE), "error")
    end
  end
  if visible then
    local extraHeight = math.max(0, ImGui.GetWindowHeight() - 700)
    local presetListHeight = ImGui.GetFontSize() * 6 + math.min(extraHeight * 0.16, 48)
    local statusHeight = 64 + math.min(extraHeight * 0.10, 28)
    local buttonGrowth = math.min(extraHeight * 0.02, 6)
    local actionButtonHeight = 32 + buttonGrowth

    local narrowTopRow = ImGui.GetWindowWidth() < 460
    local topRowStartX = ImGui.GetCursorPosX()
    local topRowWidth = ImGui.GetContentRegionAvail()
    local topControlsWidth = 134
    ImGui.TextColored(1.0, 1.0, 1.0, 1.0, "v" .. VERSION)
    ImGui.SameLine()
    if state.inCustomization then
      ImGui.TextColored(0.35, 0.9, 0.45, 1.0,
        narrowTopRow and "Editor ready" or "Customization editor open")
    else
      ImGui.TextColored(1.0, 0.65, 0.2, 1.0,
        narrowTopRow and "Open editor" or "Open customization to save or load presets")
    end
    ImGui.SameLine()
    ImGui.SetCursorPosX(topRowStartX + topRowWidth - topControlsWidth)
    if ImGui.Button("Debug##debug", 68, 0) then
      state.debugOpen = not state.debugOpen
      if state.debugOpen then readDiagnosticLog() end
    end
    ImGui.SameLine()
    if ImGui.Button("Help##help", 58, 0) then
      state.helpOpen = not state.helpOpen
    end
    drawCompatibilityWarnings()
    if state.debugOpen then
      drawDebugPanel(200 + extraHeight * 0.35)
    end
    if state.helpOpen then
      ImGui.Spacing()
      ImGui.PushStyleColor(ImGuiCol.ChildBg, 0.086, 0.094, 0.118, 0.85)
      ImGui.PushStyleColor(ImGuiCol.Border, 0.95, 0.72, 0.20, 0.55)
      ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 1.0, 1.0, 1.0)
      ImGui.PushStyleColor(ImGuiCol.TextDisabled, 0.64, 0.67, 0.73, 1.0)
      ImGui.BeginChild("##help", 0, 230 + math.min(extraHeight * 0.20, 80), true)

      helpHeading("Before You Begin")
      ImGui.TextWrapped("Load a save, then select Open Full Appearance Editor or use a mirror. Both provide the full character creator. Ripperdocs and the new-game editor are also supported.")

      helpHeading("Open the Full Appearance Editor")
      ImGui.TextWrapped("View the current hotkey on the CET Bindings page.")
      ImGui.TextWrapped("To change it, open Bindings, locate Character Preset Manager (CET), and assign Open Full Appearance Editor.")
      ImGui.TextWrapped("Close the CET overlay before using the hotkey during gameplay.")
      if state.editorInputCount > 0 then
        coloredWrapped(0.3, 1.0, 0.4, 1.0,
          ("Hotkey activations this session: %d.")
            :format(state.editorInputCount))
      else
        ImGui.TextDisabled("The hotkey has not been used this session.")
      end

      helpHeading("Load a Preset")
      ImGui.TextWrapped("1. Select a preset from the list.")
      ImGui.TextWrapped("2. Select Load Selected Preset once. Loading continues automatically.")
      coloredWrapped(0.3, 1.0, 0.4, 1.0,
        "3. Wait for the green Preset Fully Applied message.")
      coloredWrapped(1.0, 0.4, 0.4, 1.0,
        "Loading may remove cosmetic options that are not included in the preset.")
      pathCallout("##presetFolderPath", "Preset Folder",
        "bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Character Presets")

      helpHeading("Create a Preset")
      ImGui.TextWrapped("1. Select a folder or All Presets under Folders.")
      ImGui.TextWrapped("2. Enter a name under Create and select Create New Preset.")
      ImGui.TextWrapped("3. If the name exists, select Confirm Overwrite to replace it.")

      helpHeading("Folders: Add, Select, and Move")
      ImGui.TextWrapped("Folders and subfolders appear automatically. Select a folder in Load to expand or collapse it. Root presets appear below the folders.")
      ImGui.TextWrapped("Enter a name and select Add Folder. New and moved presets use the selected folder.")
      ImGui.TextWrapped("To move a preset, select it under Load, select a destination under Folders, and select Move Selected Preset Here. Select All Presets to move it to the root.")
      ImGui.TextWrapped("Renaming a folder does not change its contents.")

      helpHeading("Duplicate Presets and Folders")
      ImGui.TextWrapped("Duplicate Selected Preset creates a copy beside the original, named Copy, Copy 2, and so on.")
      ImGui.TextWrapped("Duplicate Selected Folder copies the folder, presets, and subfolders. The original remains unchanged.")
      coloredWrapped(1.0, 0.8, 0.2, 1.0,
        "Copying a folder uses a folder slot for every folder copied. If it fails or runs out of slots, the partial copy is cleaned up and the slots are returned.")

      helpHeading("Rename or Delete a Preset")
      ImGui.TextWrapped("Select a preset under Load. Rename Selected changes only the file name and retains the folder.")
      ImGui.TextWrapped("Duplicate Selected Preset retains the original and selects the new copy.")
      coloredWrapped(1.0, 0.4, 0.4, 1.0,
        "Delete Preset requires two confirmations and permanently deletes the file.")

      helpHeading("Delete a Folder")
      ImGui.TextWrapped("Empty folder: select Delete Folder & Contents, then Confirm Delete Empty Folder.")
      coloredWrapped(1.0, 0.4, 0.4, 1.0,
        "Non-empty folder: three confirmations permanently delete all contents.")
      ImGui.TextWrapped("The confirmation displays the preset count. Vortex metadata is also deleted.")

      helpHeading("Folder Slots")
      ImGui.TextWrapped("CET cannot create folders directly. This mod includes 16 reusable folder slots.")
      ImGui.TextWrapped("Creating or copying a folder uses one slot. Deleting a folder returns its slot. Manually created folders do not use slots.")
      ImGui.TextWrapped("Each slot contains a marker file that prevents deployment tools from removing it. Startup repairs missing markers.")
      ImGui.TextWrapped("Reinstalling the mod restores bundled slots without changing existing folders.")

      helpHeading("Share, Import, and Refresh")
      ImGui.TextWrapped("Place .preset files in the preset folder or a subfolder to import them. Copy a .preset file elsewhere to share it.")
      ImGui.TextWrapped("After changing files outside CET, close and reopen the overlay to refresh the list.")
      coloredWrapped(1.0, 0.4, 0.4, 1.0,
        "External file changes are recorded as activity-log warnings. Changes made while the game is closed are checked at the next launch.")
      coloredWrapped(1.0, 1.0, 1.0, 1.0,
        "ACU-format .preset files are supported.")

      helpHeading("If an Older Preset Needs Updating")
      coloredWrapped(1.0, 0.8, 0.2, 1.0,
        "Mirrors and the editor provide the full option set. If the CCXL setup changed, correct the appearance and save the preset again.")

      helpHeading("Debug and Log Files")
      ImGui.TextWrapped("Open Debug to view or copy the activity log. It records selections, actions, file changes, and results.")
      ImGui.TextWrapped("Green indicates completion, yellow indicates a warning, and red indicates an error.")
      pathCallout("##currentLogPath", "Current Log File",
        "bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Character Preset Manager (CET) Activity.log")
      coloredWrapped(1.0, 0.4, 0.4, 1.0,
        "Previous sessions are stored as dated log files. The 10 most recent files are retained.")

      ImGui.EndChild()
      ImGui.PopStyleColor(4)
    end

    if collapsibleSectionHeader("APPEARANCE EDITOR", "editor") then
    ImGui.TextWrapped("Opens the full vanilla character editor. Apartment mirrors provide the same options.")
    ImGui.Spacing()
    if state.editorOpenPending or state.inCustomization then ImGui.BeginDisabled() end
    if fullWidthButton("Open Full Appearance Editor##openEditor", actionButtonHeight) then
      openFullAppearanceEditor()
    end
    if state.editorOpenPending or state.inCustomization then ImGui.EndDisabled() end
    drawSectionStatus("editor", "##editorStatus", isEditorSuccess, statusHeight)
    end

    if collapsibleSectionHeader("LOAD", "load") then
    ImGui.TextColored(1.0, 1.0, 1.0, 1.0, "Select a preset to load")
    ImGui.Spacing()
    ImGui.BeginChild("##presetList", 0, presetListHeight, true)
    local names = sortedPresetNames()
    if #names == 0 then
      ImGui.TextDisabled("No presets saved.")
    else
      local function drawPresetChoice(name, label)
        if ImGui.Selectable(label .. "##preset:" .. name, state.selected == name)
            and state.selected ~= name then
          log(("[UI] Preset selection changed: old='%s' new='%s'.")
            :format(tostring(state.selected), name), "info")
          state.selected = name
          state.pendingDeleteName = nil
          state.renameName = ""
          state.loadPresetName = nil
          state.loadPass = 0
          state.loadRemaining = 0
          state.loadNeedsContinue = false
          state.loadStalled = false
          state.previousUnresolvedSignature = nil
          state.unresolvedRepeatCount = 0
          state.autoLoad = false
          state.autoLoadTimer = 0
          state.autoLoadPasses = 0
          state.resetBeforeLoad = false
          state.renameStatus = ""
          state.renameStatusError = false
          state.deleteStatus = ""
          state.deleteStatusError = false
        end
      end
      for _, folder in ipairs(sortedFolderNames()) do
        local folderPresets = presetsInFolder(folder)
        if #folderPresets > 0 then
          if ImGui.TreeNode(baseName(folder) .. " (folder)##loadFolder:" .. folder) then
            for _, name in ipairs(folderPresets) do drawPresetChoice(name, baseName(name)) end
            ImGui.TreePop()
          end
        end
      end
      for _, name in ipairs(presetsInFolder("")) do
        drawPresetChoice(name, name)
      end
    end
    ImGui.EndChild()
    ImGui.Spacing()

    if not state.selected then ImGui.BeginDisabled() end
    local loadLabel
    if state.autoLoad then
      loadLabel = ("Loading... (pass %d)"):format(state.loadPass)
    elseif state.loadNeedsContinue then
      loadLabel = ("Continue Loading Preset (%d remaining)"):format(state.loadRemaining)
    else
      loadLabel = "Load Selected Preset"
    end
    if state.autoLoad then ImGui.BeginDisabled() end
    if fullWidthButton(loadLabel .. "##loadPreset", actionButtonHeight) then
      if not state.loadNeedsContinue then
        state.loadPresetName = nil
        state.loadPass = 0
        state.previousUnresolvedSignature = nil
        state.unresolvedRepeatCount = 0
      end
      state.autoLoadTimer = 0
      state.autoLoadPasses = 0
      state.resetBeforeLoad = true
      loadPreset()
      if state.loadNeedsContinue then state.autoLoad = true end
    end
    if state.autoLoad then ImGui.EndDisabled() end
    if not state.selected then ImGui.EndDisabled() end
    drawSectionStatus("load", "##loadStatus", isLoadSuccess, statusHeight)
    end

    if collapsibleSectionHeader("CREATE", "create") then
    ImGui.TextColored(1.0, 1.0, 1.0, 1.0,
      "Save the current appearance as a new preset")
    ImGui.Spacing()
    ImGui.PushItemWidth(-1)
    local previousNewName = state.newName
    state.newName = ImGui.InputTextWithHint("##newPreset", "Name", state.newName, 65)
    ImGui.PopItemWidth()
    if state.newName ~= previousNewName then state.pendingOverwriteName = nil end
    local saveLabel = "Create New Preset"
    local pendingCreateName = joinFolder(state.selectedFolder, sanitizeName(state.newName))
    if state.pendingOverwriteName == pendingCreateName then
      saveLabel = "Confirm Overwrite"
    end
    ImGui.Spacing()
    if fullWidthButton(saveLabel, actionButtonHeight) then
      savePreset(state.pendingOverwriteName == pendingCreateName)
    end
    drawSectionStatus("create", "##createStatus", isCreateSuccess, statusHeight)
    end

    if collapsibleSectionHeader("FOLDERS", "folders") then
    ImGui.TextColored(1.0, 1.0, 1.0, 1.0,
      "Select where new or moved presets are stored")
    local slotsAvailable = availableFolderSlots()
    if slotsAvailable then
      local slotText = ("Free folder slots: %d"):format(slotsAvailable)
      if slotsAvailable <= 2 then
        coloredWrapped(1.0, 0.8, 0.2, 1.0, slotText)
      else
        ImGui.TextDisabled(slotText)
      end
    else
      coloredWrapped(1.0, 0.4, 0.4, 1.0, "Available folder slots could not be checked.")
    end
    ImGui.Spacing()
    ImGui.BeginChild("##folderList", 0, ImGui.GetFontSize() * 4.5, true)
    if ImGui.Selectable("All Presets (root)##rootFolder", state.selectedFolder == "")
        and state.selectedFolder ~= "" then
      log(("[UI] Folder selection changed: old='%s' new='<root>'.")
        :format(state.selectedFolder), "info")
      state.selectedFolder = ""
      state.pendingDeleteFolder = nil
      state.pendingDeleteFolderStage = 0
      state.pendingDeleteFolderPresetCount = 0
      state.pendingDeleteFolderHasContents = false
    end
    for _, folder in ipairs(sortedFolderNames()) do
      if ImGui.Selectable(folder .. "##folder", state.selectedFolder == folder)
          and state.selectedFolder ~= folder then
        log(("[UI] Folder selection changed: old='%s' new='%s'.")
          :format(tostring(state.selectedFolder), folder), "info")
        state.selectedFolder = folder
        state.pendingDeleteFolder = nil
        state.pendingDeleteFolderStage = 0
        state.pendingDeleteFolderPresetCount = 0
        state.pendingDeleteFolderHasContents = false
        state.folderRenameName = ""
      end
    end
    ImGui.EndChild()
    ImGui.PushItemWidth(-1)
    state.folderName = ImGui.InputTextWithHint("##newFolder", "New folder name", state.folderName, 65)
    ImGui.PopItemWidth()
    if fullWidthButton("Add Folder", actionButtonHeight) then createFolder() end
    if state.selectedFolder ~= "" then
      ImGui.PushItemWidth(-1)
      state.folderRenameName = ImGui.InputTextWithHint("##renameFolder", "Rename selected folder", state.folderRenameName, 65)
      ImGui.PopItemWidth()
      local folderRenameUnavailable = sanitizeName(state.folderRenameName) == ""
      if folderRenameUnavailable then ImGui.BeginDisabled() end
      if fullWidthButton("Rename Folder", actionButtonHeight) then renameFolder() end
      if folderRenameUnavailable then ImGui.EndDisabled() end
      if fullWidthButton("Duplicate Selected Folder", actionButtonHeight) then duplicateFolder() end
      if fullWidthButton("Move Selected Preset Here", actionButtonHeight) then movePresetToSelectedFolder() end
      local folderDeleteLabel = "Delete Folder & Contents##folderDanger"
      if state.pendingDeleteFolder == state.selectedFolder then
        if state.pendingDeleteFolderStage == 1 then
          folderDeleteLabel = ("Confirm Delete Folder (%d presets)##folderDanger")
            :format(state.pendingDeleteFolderPresetCount)
        elseif state.pendingDeleteFolderStage >= 2 then
          folderDeleteLabel = state.pendingDeleteFolderHasContents
            and "Permanently Delete Folder##folderDanger"
            or "Confirm Delete Empty Folder##folderDanger"
        end
      end
      if dangerButton(folderDeleteLabel, ImGui.GetContentRegionAvail(), actionButtonHeight) then deleteFolder() end
    elseif state.selected then
      if fullWidthButton("Move Selected Preset to Root", actionButtonHeight) then movePresetToSelectedFolder() end
    end
    if state.folderStatus ~= "" then
      local awaitingFolderDelete = state.pendingDeleteFolder == state.selectedFolder
        and state.pendingDeleteFolderStage > 0
      if state.lastLoggedFolderStatus ~= state.folderStatus then
        local level = state.folderStatusError and "error"
          or (awaitingFolderDelete and "warn" or "info")
        log(("[FOLDER STATUS] %s"):format(state.folderStatus), level)
        state.lastLoggedFolderStatus = state.folderStatus
      end
    end
    drawSectionStatus("folder", "##folderStatus", isFolderSuccess, statusHeight)
    end

    if collapsibleSectionHeader("MANAGE", "manage") then
    ImGui.TextColored(1.0, 1.0, 1.0, 1.0,
      "Manage the selected preset")
    ImGui.Spacing()
    ImGui.PushItemWidth(-1)
    state.renameName = ImGui.InputTextWithHint("##renamePreset", "New Name", state.renameName, 65)
    ImGui.PopItemWidth()
    ImGui.Spacing()
    local renameUnavailable = not state.selected or sanitizeName(state.renameName) == ""
    if renameUnavailable then ImGui.BeginDisabled() end
    if fullWidthButton("Rename Selected", actionButtonHeight) then renamePreset() end
    if renameUnavailable then ImGui.EndDisabled() end
    if not state.selected then ImGui.BeginDisabled() end
    if fullWidthButton("Duplicate Selected Preset", actionButtonHeight) then duplicatePreset() end
    if not state.selected then ImGui.EndDisabled() end
    drawSectionStatus("rename", "##renameStatus", isRenameSuccess, statusHeight)

    ImGui.Spacing()
    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()
    coloredWrapped(1.0, 0.4, 0.4, 1.0,
      "Preset deletion is permanent")
    ImGui.Spacing()
    if not state.selected then ImGui.BeginDisabled() end
    local deleteLabel = state.selected
      and state.pendingDeleteName == state.selected
      and "Confirm Delete##danger"
      or "Delete Preset##danger"
    if dangerButton(deleteLabel, ImGui.GetContentRegionAvail(), actionButtonHeight) then deletePreset() end
    if not state.selected then ImGui.EndDisabled() end
    drawSectionStatus("delete", "##deleteStatus", isDeleteSuccess, statusHeight)
    end

  end
  ImGui.End()
  popTheme()
end

registerForEvent("onInit", function()
  activitySequence = 0
  local archived, archiveResult, cleanupWarning, deletedArchives = archiveLogForNewSession()
  log(("========== Character Preset Manager (CET) v%s session started =========="):format(VERSION), "info")
  log("Log guide: CHANGE = an option was written; SNAPSHOT = an option was read while saving; SKIPPED = nothing was changed; SUMMARY = final result.", "info")
  if not archived then
    log("Could not archive the previous activity log: " .. tostring(archiveResult), "warn")
  elseif archiveResult then
    log("Previous activity log archived as " .. tostring(archiveResult), "info")
  end
  if cleanupWarning then
    log("Could not enforce the 10-file activity-log limit: " .. tostring(cleanupWarning), "warn")
  elseif (tonumber(deletedArchives) or 0) > 0 then
    log(("Deleted %d oldest activity-log archive%s to keep the newest %d.")
      :format(deletedArchives, deletedArchives == 1 and "" or "s", LOG_ARCHIVE_LIMIT), "info")
  end
  repairFolderSlots()
  state.initialWindowPlacementPending = not fileExists(WINDOW_POSITION_STATUS_FILE)
  if state.initialWindowPlacementPending then
    log(("[UI] Window position status '%s' not found; right-side default will be applied once.")
      :format(WINDOW_POSITION_STATUS_FILE), "info")
  else
    log(("[UI] Window position status '%s' found; CET's saved position will be preserved.")
      :format(WINDOW_POSITION_STATUS_FILE), "info")
  end

  local observeInitOk, observeInitError = pcall(
    Observe,
    "characterCreationBodyMorphMenu",
    "OnInitialize",
    function(menu)
      temporarilyDisableWardrobe()
      state.activeBodyMorphMenu = menu
    end
  )
  local observeExitOk, observeExitError = pcall(
    Observe,
    "characterCreationBodyMorphMenu",
    "OnUninitialize",
    function(menu)
      if state.activeBodyMorphMenu == menu then
        state.activeBodyMorphMenu = nil
      end
      state.editorOpenedByLauncher = false
      restoreTemporarilyDisabledWardrobe()
    end
  )
  if not observeInitOk or not observeExitOk then
    log(("UI refresh observer registration unavailable: initialize=%s uninitialize=%s")
      :format(tostring(observeInitError), tostring(observeExitError)), "warn")
  end
  if observeInitOk and observeExitOk then
    log("[HOOK] Character customization UI observers registered.", "info")
  end

  local menuObserverOk, menuObserverError = pcall(
    Observe,
    "gameuiInGameMenuGameController",
    "RegisterGlobalBlackboards",
    function(controller)
      state.inGameMenuController = controller
      state.editorControllerCaptureCount = state.editorControllerCaptureCount + 1
      log(("[editor diagnostic] in-game menu controller captured via blackboards (%d)")
        :format(state.editorControllerCaptureCount), "info")
    end
  )
  local menuInitializeObserverOk, menuInitializeObserverError = pcall(
    Observe,
    "gameuiInGameMenuGameController",
    "OnInitialize",
    function(controller)
      state.inGameMenuController = controller
      state.editorControllerCaptureCount = state.editorControllerCaptureCount + 1
      log(("[editor diagnostic] in-game menu controller captured via initialize (%d)")
        :format(state.editorControllerCaptureCount), "info")
    end
  )

  local pauseOverrideOk, pauseOverrideError = pcall(
    Override,
    "MenuScenario_PauseMenu",
    "OnEnterScenario",
    function(scenario, previousScenario, userData, wrappedMethod)
      log(("[editor diagnostic] pause scenario entered: pending=%s")
        :format(tostring(state.editorOpenPending)), "info")
      if not state.editorOpenPending then
        return wrappedMethod(previousScenario, userData)
      end
      state.editorPauseRedirectCount = state.editorPauseRedirectCount + 1
      state.editorOpenPending = false
      state.editorOpenTimer = 0
      state.editorOpenedByLauncher = true
      setEditorOpenStatus("Preparing the full editor...", false)
      return scenario:SwitchToScenario("MenuScenario_CharacterCustomizationMirror")
    end
  )

  local editorOverrideOk, editorOverrideError = pcall(
    Override,
    "MenuScenario_CharacterCustomizationMirror",
    "OnCCOPuppetReady",
    function(scenario, wrappedMethod)
      state.editorPuppetReadyCount = state.editorPuppetReadyCount + 1
      log(("[editor diagnostic] customization puppet ready (%d)")
        :format(state.editorPuppetReadyCount), "info")
      local opened, editorError = pcall(function()
        local userData = MorphMenuUserData.new()
        userData.optionsListInitialized = false
        userData.updatingFinalizedState = true
        userData.editMode = gameuiCharacterCustomizationEditTag.NewGame
        scenario.currMenuName = "character_customization"
        local menus = scenario:GetMenusState()
        menus:OpenMenu("player_puppet")
        menus:OpenMenu("character_customization", userData)
      end)
      if not opened then
        setEditorOpenStatus("Full editor setup failed: " ..
          tostring(editorError), true)
        state.editorOpenedByLauncher = false
        return
      end
      setEditorOpenStatus("Full editor opened.", false)
    end
  )

  if (not menuObserverOk and not menuInitializeObserverOk)
      or not pauseOverrideOk or not editorOverrideOk then
    log(("Full-editor hooks unavailable: controller=%s initialize=%s pause=%s editor=%s")
      :format(tostring(menuObserverError), tostring(menuInitializeObserverError),
        tostring(pauseOverrideError), tostring(editorOverrideError)), "error")
    setEditorOpenStatus("The full editor is not available with this game or CET version.", true)
  else
    log("[HOOK] Full-editor launch and mirror-unlock hooks registered.", "info")
  end

  refreshPresets("startup")
  local presetCount = 0
  for _ in pairs(state.presets) do presetCount = presetCount + 1 end
  log(("Preset files loaded: presets=%d directory='%s'")
    :format(presetCount, PRESET_DIR), "info")
  state.ready = true
  refreshEditorState()
  state.editorStateRefreshTimer = 0
  setStatus("load", "Open the character creator, a mirror, or a ripperdoc to save or load presets.")
end)

registerForEvent("onShutdown", function()
  auditSection("SESSION END")
  log(("[SUMMARY] inputs=%d controllerCaptures=%d pauseRedirects=%d editorPuppets=%d")
    :format(state.editorInputCount, state.editorControllerCaptureCount,
      state.editorPauseRedirectCount, state.editorPuppetReadyCount), "info")
  restoreTemporarilyDisabledWardrobe()
  state.ready = false
  state.inCustomization = false
  state.editorStateRefreshTimer = 0
  state.pendingDeleteName = nil
  state.loadPresetName = nil
  state.loadPass = 0
  state.loadRemaining = 0
  state.loadNeedsContinue = false
  state.loadStalled = false
  state.previousUnresolvedSignature = nil
  state.unresolvedRepeatCount = 0
  state.autoLoad = false
  state.autoLoadTimer = 0
  state.autoLoadPasses = 0
  state.resetBeforeLoad = false
  state.activeBodyMorphMenu = nil
  state.inGameMenuController = nil
  state.editorOpenPending = false
  state.editorOpenTimer = 0
  state.editorOpenedByLauncher = false
end)

registerForEvent("onUpdate", function(delta)
  if state.editorOpenPending then
    state.editorOpenTimer = state.editorOpenTimer + (tonumber(delta) or 0)
    if state.editorOpenTimer >= EDITOR_OPEN_TIMEOUT then
      state.editorOpenPending = false
      state.editorOpenTimer = 0
      restoreTemporarilyDisabledWardrobe()
      setEditorOpenStatus("The editor did not open. Return to normal gameplay and retry.", true)
    end
  end
  if state.overlayOpen then
    state.editorStateRefreshTimer = state.editorStateRefreshTimer + (tonumber(delta) or 0)
  end
  if not state.autoLoad then return end

  if not state.loadNeedsContinue then
    state.autoLoad = false
    state.autoLoadTimer = 0
    state.autoLoadPasses = 0
    return
  end

  state.autoLoadTimer = state.autoLoadTimer + (tonumber(delta) or 0)
  if state.autoLoadTimer < AUTO_LOAD_INTERVAL then return end
  state.autoLoadTimer = 0

  if not state.selected or not isCustomizationActive() then
    state.autoLoad = false
    state.autoLoadTimer = 0
    state.autoLoadPasses = 0
    return
  end

  state.autoLoadPasses = state.autoLoadPasses + 1
  if state.autoLoadPasses > AUTO_LOAD_MAX_PASSES then
    state.autoLoad = false
    setStatus("load",
      "Automatic loading hit the absolute safety limit without stalling or " ..
      "finishing. This is unusual -- please report it.",
      true
    )
    return
  end

  loadPreset()

  if not state.loadNeedsContinue then
    state.autoLoad = false
    state.autoLoadPasses = 0
  end
end)

registerForEvent("onOverlayOpen", function()
  log("[UI] CET overlay opened; showing Character Preset Manager and rescanning preset files.", "info")
  state.overlayOpen = true
  state.windowOpen = true
  refreshPresets("external")
  refreshEditorState()
  state.editorStateRefreshTimer = 0
end)
registerForEvent("onOverlayClose", function()
  log("[UI] CET overlay closed.", "info")
  state.overlayOpen = false
  state.pendingDeleteName = nil
end)
registerForEvent("onDraw", draw)
registerHotkey("vanilla_character_presets_toggle", "Toggle Character Preset Manager (CET)", function()
  state.windowOpen = not state.windowOpen
  log(("[UI] Character Preset Manager window visibility changed to %s.")
    :format(tostring(state.windowOpen)), "info")
end)
registerInput("preset_manager_open_editor_input", "Open Full Appearance Editor", function(keyDown)
  if not keyDown then return end
  state.editorInputCount = state.editorInputCount + 1
  log(("[editor diagnostic] input binding pressed (%d)")
    :format(state.editorInputCount), "info")
  local launchOk, launchError = pcall(openFullAppearanceEditor)
  if not launchOk then
    state.editorOpenPending = false
    state.editorOpenTimer = 0
    restoreTemporarilyDisabledWardrobe()
    setEditorOpenStatus("Editor hotkey failed before the menu request: " ..
      tostring(launchError), true)
  end
end)
