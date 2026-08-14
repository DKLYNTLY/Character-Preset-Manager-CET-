
local MOD_NAME = "Character Preset Manager (CET)"
local VERSION = "3.0.2"
local PRESET_DIR = "Character Presets"
local DATA_DIR = "Data"
local CONFIG_DIR = DATA_DIR .. "/Config"
local CATALOG_DIR = DATA_DIR .. "/Catalog"
local RECOVERY_DIR = DATA_DIR .. "/Recovery"
local TRASH_DIR = RECOVERY_DIR .. "/Trash"
local LOG_DIR = DATA_DIR .. "/Logs"
local LOG_ARCHIVE_DIR = LOG_DIR .. "/Archive"
local TRASH_CATALOG_FILE = RECOVERY_DIR .. "/Trash Catalog.txt"
local TRANSACTION_FILE = RECOVERY_DIR .. "/Recovery Journal.txt"
local CATALOG_FILE = CATALOG_DIR .. "/Virtual Folders.txt"
local INVENTORY_FILE = CATALOG_DIR .. "/Preset Inventory.txt"
local IMPORTED_BUNDLES_FILE = CATALOG_DIR .. "/Imported Bundles.txt"
local LOG_FILE = LOG_DIR .. "/Activity.log"
local LOG_ARCHIVE_PREFIX = "Activity "
local WINDOW_POSITION_STATUS_FILE = CONFIG_DIR .. "/Window Position Status.txt"
local CONFIG_FILE = CONFIG_DIR .. "/Config.txt"
local DISCOVERY_NOTICE_TITLE = "OPEN CHARACTER PRESET MANAGER"
local DISCOVERY_NOTICE_MESSAGE = "Press your assigned CET Overlay key to open its window."
local DISCOVERY_NOTICE_SETTINGS_MESSAGE = "Turn this message off in Settings."
local LOG_ARCHIVE_LIMIT = 10
local activitySequence = 0

local AUTO_LOAD_INTERVAL = 0.40
local AUTO_LOAD_MAX_PASSES = 400
local STALL_CONFIRMATION_PASSES = 3
local EDITOR_OPEN_TIMEOUT = 5.0
local STATUS_CLEAR_DELAY = 8.0
local STATUS_UPDATE_INTERVAL = 0.25
local MAX_TREE_DEPTH = 12
local MAX_PRESET_BYTES = 1048576
local MAX_PRESET_ENTRIES = 4096
local MAX_PRESET_LINES = 8192
local MAX_PRESET_KEY_BYTES = 256
local MAX_OPTION_INDEX = 4294967295
local FILE_COPY_CHUNK_SIZE = 65536
local MAX_CATALOG_BYTES = 8388608
local MAX_CATALOG_LINES = 32768
local MAX_TRANSACTION_BYTES = 1048576
local MAX_TRANSACTION_LINES = 8192
local MAX_FOLDER_BUNDLE_BYTES = 33554432
local MAX_FOLDER_BUNDLE_PRESETS = 512
local FOLDER_BUNDLE_EXTENSION = ".cpmfolder"
local log
local readConfig
local writeConfig

local state = {
  overlayOpen = false,
  windowOpen = true,
  ready = false,
  inCustomization = false,
  selected = nil,
  newName = "",
  renameName = "",
  searchText = "",
  presetNotes = "",
  presetTags = "",
  presets = {},
  folders = {},
  manualFolders = {},
  ignoredPhysicalFolders = {},
  expandedLoadFolders = {},
  openSections = {
    editor = true,
    load = true,
    create = true,
    folders = false,
    manage = false,
    trash = false,
  },
  openSubsections = {
    saveDestination = false,
    presetDetails = false,
    bulkTrash = false,
  },
  selectedFolder = "",
  folderName = "",
  folderRenameName = "",
  folderStatus = "",
  folderStatusError = false,
  lastLoggedFolderStatus = nil,
  loadStatus = "Load a save and open the character editor.",
  loadStatusError = false,
  createStatus = "",
  createStatusError = false,
  renameStatus = "",
  renameStatusError = false,
  deleteStatus = "",
  deleteStatusError = false,
  bulkStatus = "",
  bulkStatusError = false,
  loadPresetName = nil,
  loadPass = 0,
  loadRemaining = 0,
  loadNeedsContinue = false,
  loadStalled = false,
  previousUnresolvedSignature = nil,
  unresolvedRepeatCount = 0,
  loadSatisfied = {},
  loadValues = nil,
  loadSavedCounts = nil,
  loadValueCount = 0,
  pendingOverwriteName = nil,
  pendingOverwriteFingerprint = nil,
  pendingDeleteName = nil,
  pendingDeleteFingerprint = nil,
  pendingRemoveFolder = nil,
  helpOpen = false,
  debugOpen = false,
  advancedDiagnosticsOpen = false,
  settingsOpen = false,
  settingsStatus = "",
  debugLogText = "",
  debugLogLines = {},
  bindingCache = {},
  autoLoad = false,
  autoLoadTimer = 0,
  autoLoadPasses = 0,
  preflight = nil,
  trash = {},
  trashGroups = {},
  pendingEmptyTrash = false,
  bulkSelected = {},
  pendingBulkAction = nil,
  pendingBulkFingerprint = nil,
  sortMode = "name",
  resetBeforeLoad = false,
  activeBodyMorphMenu = nil,
  inGameMenuController = nil,
  editorOpenPending = false,
  editorOpenTimer = 0,
  editorStatus = "Load a save before opening the full editor.",
  editorStatusError = false,
  windowHotkeyCount = 0,
  editorInputCount = 0,
  editorControllerCaptureCount = 0,
  editorPauseRedirectCount = 0,
  editorPuppetReadyCount = 0,
  editorOpenedByLauncher = false,
  editorHooksAvailable = false,
  newGameCharacterCreator = false,
  wardrobeTemporarilyDisabled = false,
  initialWindowPlacementPending = true,
  discoveryNoticePending = false,
  discoveryNoticeIgnored = false,
  discoveryNoticeLayout = nil,
  viewCacheDirty = true,
  cachedPresetNames = {},
  cachedFolderNames = {},
  cachedPresetsByFolder = {},
  cachedFolderPresetCounts = {},
  filteredViewDirty = true,
  cachedSearchText = nil,
  cachedFilteredPresetNames = {},
  cachedMatchedFolders = {},
  cachedMatchingPresetsByFolder = {},
  cachedBulkFolder = nil,
  cachedBulkFolderNames = {},
  cachedBulkNestedFolderCount = 0,
  bulkSelectionDirty = true,
  cachedBulkSelectedNames = {},
  windowPositionCached = false,
  cachedWindowX = nil,
  cachedDisplayWidth = nil,
  clothingCheckDirty = true,
  cachedClothingLabels = nil,
  statusUpdateTimer = 0,
  statusTimers = {},
  statusSnapshots = {},
  statusKinds = {},
}

local STATUS_SECTIONS = { "editor", "load", "create", "folder", "rename", "delete", "bulk" }

local function fileExists(path)
  local file = io.open(path, "rb")
  if not file then return false end
  file:close()
  return true
end

local function fileFingerprint(path, maximumBytes)
  local file = io.open(path, "rb")
  if not file then return nil end
  local sizeOk, fileSize = pcall(file.seek, file, "end")
  local rewindOk, rewindResult = pcall(file.seek, file, "set", 0)
  if not sizeOk or not fileSize or fileSize > (maximumBytes or MAX_PRESET_BYTES)
      or not rewindOk or rewindResult == nil then
    file:close()
    return nil
  end
  local hash, bytesRead = 0, 0
  local ok = pcall(function()
    while true do
      local chunk = file:read(FILE_COPY_CHUNK_SIZE)
      if not chunk then break end
      bytesRead = bytesRead + #chunk
      for index = 1, #chunk do
        hash = (hash * 131 + chunk:byte(index)) % 2147483647
      end
    end
  end)
  local closeOk, closeResult = pcall(file.close, file)
  if not ok or bytesRead ~= fileSize
      or not closeOk or closeResult == nil then return nil end
  return tostring(bytesRead) .. ":" .. tostring(hash)
end

local function cancelConfirmations()
  state.pendingOverwriteName = nil
  state.pendingOverwriteFingerprint = nil
  state.pendingDeleteName = nil
  state.pendingDeleteFingerprint = nil
  state.pendingRemoveFolder = nil
  state.pendingEmptyTrash = false
  state.pendingBulkAction = nil
  state.pendingBulkFingerprint = nil
end

local function resetLoadState()
  state.loadPresetName = nil
  state.loadPass = 0
  state.loadRemaining = 0
  state.loadNeedsContinue = false
  state.loadStalled = false
  state.previousUnresolvedSignature = nil
  state.unresolvedRepeatCount = 0
  state.loadSatisfied = {}
  state.loadValues = nil
  state.loadSavedCounts = nil
  state.loadValueCount = 0
  state.autoLoad = false
  state.autoLoadTimer = 0
  state.autoLoadPasses = 0
  state.resetBeforeLoad = false
end

local function cloneMap(source)
  local copy = {}
  for key, value in pairs(source or {}) do copy[key] = value end
  return copy
end

local function safeDirectoryEntries(path, depth)
  if (tonumber(depth) or 0) > MAX_TREE_DEPTH then
    return nil, "folder nesting exceeds the safety limit"
  end
  local ok, entries = pcall(dir, path)
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

local function directoryTreeContainsFiles(path, depth)
  local entries = safeDirectoryEntries(path, depth)
  if not entries then return nil end
  for _, entry in ipairs(entries) do
    if entry.type == "directory" then
      local containsFiles = directoryTreeContainsFiles(path .. "/" .. entry.name, depth + 1)
      if containsFiles == nil or containsFiles then return containsFiles end
    else
      return true
    end
  end
  return false
end

local function removeEmptyDirectoryTree(path, depth)
  local entries = safeDirectoryEntries(path, depth)
  if not entries then return false end
  for _, entry in ipairs(entries) do
    if entry.type ~= "directory"
        or not removeEmptyDirectoryTree(path .. "/" .. entry.name, depth + 1) then
      return false
    end
  end
  return os.remove(path) ~= nil
end

local function isNewGameCharacterCreator()
  return state.newGameCharacterCreator == true
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
  local listOk, files = pcall(dir, LOG_ARCHIVE_DIR)
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
    local removed, removeError = os.remove(LOG_ARCHIVE_DIR .. "/" .. oldest)
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
  local sizeOk, size = pcall(file.seek, file, "end")
  if not sizeOk or not size then file:close(); return false, "the existing activity log could not be measured" end
  if size > 0 then
    local rewindOk, rewindResult = pcall(file.seek, file, "set", 0)
    if not rewindOk or rewindResult == nil then file:close(); return false, "the existing activity log could not be rewound" end
    local dateOk, timestamp = pcall(os.date, "%Y-%m-%d_%H-%M-%S")
    if not dateOk or not timestamp then timestamp = "unknown-date" end

    local archiveName = LOG_ARCHIVE_DIR .. "/" ..
      LOG_ARCHIVE_PREFIX .. tostring(timestamp) .. ".txt"
    local suffix = 2
    while suffix <= 9999 do
      local existing = io.open(archiveName, "rb")
      if not existing then break end
      existing:close()
      archiveName = LOG_ARCHIVE_PREFIX .. tostring(timestamp) ..
        ("-%d.txt"):format(suffix)
      suffix = suffix + 1
    end
    if suffix > 9999 and fileExists(archiveName) then
      file:close()
      return false, "a unique dated activity-log archive name could not be found"
    end

    local archive = io.open(archiveName, "wb")
    if not archive then file:close(); return false, "the dated activity-log archive could not be created" end
    local archivedBytes = 0
    local writeOk, writeResult = pcall(function()
      while true do
        local chunk = file:read(FILE_COPY_CHUNK_SIZE)
        if not chunk then break end
        if not archive:write(chunk) then return false end
        archivedBytes = archivedBytes + #chunk
      end
      return archivedBytes == size and archive:flush() ~= nil
    end)
    file:close()
    local closeOk, closeResult = pcall(archive.close, archive)
    if not writeOk or writeResult ~= true or not closeOk or closeResult == nil then
      return false, "the dated activity-log archive could not be written"
    end

    local deleted, pruneError = pruneLogArchives()

    local fresh = io.open(LOG_FILE, "w")
    if not fresh then return false, "the activity log could not be cleared" end
    fresh:close()
    return true, archiveName, pruneError, deleted
  end

  file:close()
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

local function inferredStatusKind(section, message, isError)
  if isError then return "error" end
  if section == "load" and (message:find("Preset fully applied", 1, true)
      or message:find("Open the character creator", 1, true) == 1) then return "success" end
  if section == "create" and message:find("Saved ", 1, true) == 1 then return "success" end
  if section == "rename" and (message:find("Renamed ", 1, true) == 1
      or message:find("Duplicated ", 1, true) == 1
      or message:find("Saved details ", 1, true) == 1) then return "success" end
  if section == "delete" and (message:find("Moved ", 1, true) == 1
      or message:find("Restored ", 1, true) == 1
      or message == "Trash emptied permanently.") then return "success" end
  if section == "bulk" and message:find("Moved ", 1, true) == 1 then return "success" end
  if section == "editor" and message == "Full editor opened." then return "success" end
  return "info"
end

local function setStatus(section, message, isError, kind)
  local loadStopped = section == "load"
    and message:find("Loading stopped", 1, true) == 1
  local effectiveError = isError == true or loadStopped
  state[section .. "Status"] = message
  state[section .. "StatusError"] = effectiveError
  state.statusKinds[section] = kind or inferredStatusKind(section, message, effectiveError)
  state.statusSnapshots[section] = message
  state.statusTimers[section] = 0
  if section == "load" then
    local transient = message:find("Applied one option.", 1, true) == 1
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

local function statusShouldRemain(section, text)
  if not text or text == "" then return true end
  if section == "load" then
    return state.autoLoad
      or state.loadNeedsContinue
      or text:find("Open the character creator", 1, true) == 1
  end
  if section == "editor" then return state.editorOpenPending end
  if section == "delete" then
    return state.pendingEmptyTrash == true or state.pendingDeleteName ~= nil
      and state.pendingDeleteName == state.selected
  end
  if section == "bulk" then return state.pendingBulkAction ~= nil end
  if section == "folder" then return state.pendingRemoveFolder ~= nil end
  return false
end

local function updateStatusTimers(delta)
  local elapsed = tonumber(delta) or 0
  for _, section in ipairs(STATUS_SECTIONS) do
    local statusKey = section .. "Status"
    local errorKey = section .. "StatusError"
    local text = state[statusKey] or ""
    if state.statusSnapshots[section] ~= text then
      state.statusSnapshots[section] = text
      state.statusTimers[section] = 0
    elseif text ~= "" and not statusShouldRemain(section, text) then
      local timer = (state.statusTimers[section] or 0) + elapsed
      if timer >= STATUS_CLEAR_DELAY then
        state[statusKey] = ""
        state[errorKey] = false
        state.statusSnapshots[section] = ""
        state.statusTimers[section] = 0
      else
        state.statusTimers[section] = timer
      end
    else
      state.statusTimers[section] = 0
    end
  end
end

local function sanitizeName(value)
  value = tostring(value or "")
  value = value:gsub("^%s+", ""):gsub("%s+$", "")
  value = value:gsub("[<>:\"/\\|%?%*%c]", "_")
  return value:sub(1, 64)
end

local function sanitizeMetadata(value, maximum)
  value = tostring(value or ""):gsub("[%c]", " ")
  value = value:gsub("^%s+", ""):gsub("%s+$", "")
  return value:sub(1, maximum)
end

local function validatedPresetName(value)
  local raw = tostring(value or "")
  local name = sanitizeName(raw)
  if name == "" then return nil, "Enter a name." end
  if name:match("[%. ]$") then
    return nil, "Preset names cannot end with a period or space."
  end

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
local refreshPreflight

local function setEditorOpenStatus(message, isError)
  state.editorStatus = message
  state.editorStatusError = isError == true
  state.statusKinds.editor = inferredStatusKind("editor", message, isError == true)
  log("[editor] " .. tostring(message), isError and "error" or "info")
end

local function activeWardrobeSetEquipped()
  local playerOk, player = pcall(Game.GetPlayer)
  if not playerOk or not player then return false, nil end
  local setOk, activeSet = pcall(EquipmentSystem.GetActiveWardrobeSetID, player)
  if not setOk or activeSet == nil then return false, player end
  return activeSet ~= gameWardrobeClothingSetIndex.INVALID, player
end

local function equippedClothingLabels()
  local playerOk, player = pcall(Game.GetPlayer)
  if not playerOk or not player then return nil end
  local dataOk, data = pcall(EquipmentSystem.GetData, player)
  if not dataOk or not data then return nil end
  local areas = {
    { area = gamedataEquipmentArea.Head, label = "Head" },
    { area = gamedataEquipmentArea.Face, label = "Face" },
    { area = gamedataEquipmentArea.OuterChest, label = "Outer torso" },
    { area = gamedataEquipmentArea.InnerChest, label = "Inner torso" },
    { area = gamedataEquipmentArea.Legs, label = "Legs" },
    { area = gamedataEquipmentArea.Feet, label = "Feet" },
    { area = gamedataEquipmentArea.Outfit, label = "Outfit" },
  }
  local labels = {}
  for _, entry in ipairs(areas) do
    local itemOk, item = pcall(data.GetActiveItem, data, entry.area)
    if itemOk and item then
      local validOk, valid = pcall(ItemID.IsValid, item)
      if validOk and valid then table.insert(labels, entry.label) end
    end
  end
  return labels
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
  if not state.editorHooksAvailable then
    setEditorOpenStatus("The full editor is not available with this game or CET version.", true)
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
  state.editorOpenPending = true
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
  setEditorOpenStatus("Opening the full appearance editor...", false)
  return true
end

local emptyCustomizationName
local function getOptions()
  local system = customizationSystem()
  if not system then return nil, nil, "Character customization system is unavailable" end
  local ok, options = pcall(function()
    if not emptyCustomizationName then emptyCustomizationName = ToCName({}) end
    return system:GetUnitedOptions(
      true,
      true,
      true,
      emptyCustomizationName,
      emptyCustomizationName,
      emptyCustomizationName
    )
  end)
  if not ok or type(options) ~= "table" or next(options) == nil then
    return nil, nil, "Customization options haven't loaded yet"
  end
  return system, options
end

isCustomizationActive = function()
  local _, options = getOptions()
  return options ~= nil
end

local function optionKey(option)
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

local function optionIndexValidationError(index)
  if type(index) ~= "number" then return "not numeric" end
  if index ~= math.floor(index) then return "not an integer" end
  if index < 0 then return "below zero" end
  if index > MAX_OPTION_INDEX then return "above the native Uint32 maximum" end
  return nil
end

local function optionIndexIsValid(index)
  return optionIndexValidationError(index) == nil
end

assert(optionIndexIsValid(0)
  and optionIndexIsValid(65535)
  and optionIndexIsValid(65536)
  and optionIndexIsValid(4294967295)
  and not optionIndexIsValid(-1)
  and not optionIndexIsValid(4294967296),
  MOD_NAME .. " option-index validation contract failed")

local function ignoreDiscoveryNotice()
  state.discoveryNoticeIgnored = true
  state.discoveryNoticePending = false
  state.discoveryNoticeLayout = nil
  local saved = writeConfig and writeConfig()
  log(saved and "[UI] Discovery reminder disabled by the user."
    or "[UI] Discovery reminder disabled for this session; config could not be saved.",
    saved and "info" or "warn")
  return saved == true
end

local function restoreDiscoveryNotice()
  state.discoveryNoticeIgnored = false
  state.discoveryNoticeLayout = nil
  local saved = writeConfig and writeConfig()
  log(saved and "[UI] Discovery reminder restored by the user."
    or "[UI] Discovery reminder restored for this session; config could not be saved.",
    saved and "info" or "warn")
  return saved == true
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

local function parentFolder(name)
  return name:match("^(.*)/[^/]+$") or ""
end

local function baseName(name)
  return name:match("([^/]+)$") or name
end

local function folderDepth(name)
  local depth = 0
  for _ in tostring(name or ""):gmatch("/") do depth = depth + 1 end
  return depth
end

local function breadcrumb(name)
  if not name or name == "" then return "All Presets" end
  return (name:gsub("/", " > "))
end

local function normalizeSearch(query)
  return tostring(query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
end

local function textMatches(value, query)
  return query == "" or tostring(value or ""):lower():find(query, 1, true) ~= nil
end

local function validModifiedTimestamp(value)
  local year, month, day, hour, minute, second = tostring(value or "")
    :match("^(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d):(%d%d)$")
  year, month, day = tonumber(year), tonumber(month), tonumber(day)
  hour, minute, second = tonumber(hour), tonumber(minute), tonumber(second)
  return year ~= nil and year >= 2000 and month >= 1 and month <= 12
    and day >= 1 and day <= 31 and hour >= 0 and hour <= 23
    and minute >= 0 and minute <= 59 and second >= 0 and second <= 59
end

local function invalidateFilteredViewCache()
  state.filteredViewDirty = true
  state.cachedBulkFolder = nil
end

local function invalidateBulkSelectionCache()
  state.bulkSelectionDirty = true
end

local function invalidateViewCache()
  state.viewCacheDirty = true
  invalidateFilteredViewCache()
  invalidateBulkSelectionCache()
end

local function rebuildViewCache()
  local presetNames = {}
  local folderNames = {}
  local presetsByFolder = {}
  local folderPresetCounts = {}
  for name in pairs(state.presets) do
    table.insert(presetNames, name)
    local folder = parentFolder(name)
    presetsByFolder[folder] = presetsByFolder[folder] or {}
    table.insert(presetsByFolder[folder], name)
    local current = folder
    while current ~= "" do
      folderPresetCounts[current] = (folderPresetCounts[current] or 0) + 1
      current = parentFolder(current)
    end
  end
  for name in pairs(state.folders) do table.insert(folderNames, name) end
  local function presetLess(a, b)
    if state.sortMode == "modified" then
      local aValue = tostring((state.presets[a] or {}).modified or "")
      local bValue = tostring((state.presets[b] or {}).modified or "")
      local aModified = validModifiedTimestamp(aValue) and aValue or ""
      local bModified = validModifiedTimestamp(bValue) and bValue or ""
      if aModified ~= bModified then return aModified > bModified end
    end
    return baseName(a):lower() < baseName(b):lower()
  end
  table.sort(presetNames, presetLess)
  table.sort(folderNames, function(a, b) return a:lower() < b:lower() end)
  for _, names in pairs(presetsByFolder) do
    table.sort(names, presetLess)
  end
  state.cachedPresetNames = presetNames
  state.cachedFolderNames = folderNames
  state.cachedPresetsByFolder = presetsByFolder
  state.cachedFolderPresetCounts = folderPresetCounts
  state.viewCacheDirty = false
end

local function ensureViewCache()
  if state.viewCacheDirty then rebuildViewCache() end
end

local EMPTY_LIST = {}

local function sortedPresetNames()
  ensureViewCache()
  return state.cachedPresetNames
end

local function sortedFolderNames()
  ensureViewCache()
  return state.cachedFolderNames
end

local function presetsInFolder(folder)
  ensureViewCache()
  return state.cachedPresetsByFolder[folder] or EMPTY_LIST
end

local function rebuildFilteredViewCache()
  ensureViewCache()
  local query = normalizeSearch(state.searchText)
  local visibleNames = {}
  local matchedFolders = {}
  local folderMatches = {}
  local matchingByFolder = {}
  for _, name in ipairs(state.cachedPresetNames) do
    if textMatches(name, query) then
      table.insert(visibleNames, name)
      local directFolder = parentFolder(name)
      matchingByFolder[directFolder] = matchingByFolder[directFolder] or {}
      table.insert(matchingByFolder[directFolder], name)
      local current = directFolder
      while current ~= "" do
        matchedFolders[current] = true
        current = parentFolder(current)
      end
    end
  end
  for _, folder in ipairs(state.cachedFolderNames) do
    if textMatches(folder, query) then folderMatches[folder] = true end
  end
  state.cachedSearchText = query
  state.cachedQueryActive = query ~= ""
  state.cachedFilteredPresetNames = visibleNames
  state.cachedMatchedFolders = matchedFolders
  state.cachedFolderMatches = folderMatches
  state.cachedMatchingPresetsByFolder = matchingByFolder
  state.filteredViewDirty = false
end

local function ensureFilteredViewCache()
  local query = normalizeSearch(state.searchText)
  if state.filteredViewDirty or state.cachedSearchText ~= query then
    rebuildFilteredViewCache()
  end
end

local function filteredPresetNames()
  ensureFilteredViewCache()
  return state.cachedFilteredPresetNames
end

local function joinFolder(folder, name)
  if not folder or folder == "" then return name end
  return folder .. "/" .. name
end

local function isInFolderTree(path, folder)
  return path == folder or path:sub(1, #folder + 1) == folder .. "/"
end

local function addFolderAncestors(folders, folder)
  local current = folder
  while current and current ~= "" do
    folders[current] = true
    current = parentFolder(current)
  end
end

local function presetPath(name)
  local preset = state.presets[name]
  local storage = preset and preset.storage or name
  return PRESET_DIR .. "/" .. storage .. ".preset"
end

local function folderPath(name)
  return name == "" and PRESET_DIR or (PRESET_DIR .. "/" .. name)
end

local function findPresetCollision(name, excludeName)
  local lowered = name:lower()
  for existing in pairs(state.presets) do
    if existing:lower() == lowered and existing ~= excludeName then
      return existing
    end
  end
  return nil
end

local function validRelativePath(value)
  if type(value) ~= "string" or value == ""
      or value:sub(1, 1) == "/" or value:sub(-1) == "/"
      or value:find("//", 1, true) or value:find("\\", 1, true) then
    return false
  end
  for part in value:gmatch("[^/]+") do
    if part == "." or part == ".." or part == "" then return false end
  end
  return true
end

local function catalogEncode(value)
  return (tostring(value or ""):gsub("([^%w%-%._/])", function(character)
    return ("%%%02X"):format(character:byte())
  end))
end

local function catalogDecode(value)
  return (tostring(value or ""):gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end))
end

local function readCatalog()
  local assignments, folders, ignored = {}, {}, {}
  local file = io.open(CATALOG_FILE, "rb")
  if not file then return assignments, folders, ignored, nil end
  local sizeOk, size = pcall(file.seek, file, "end")
  local rewindOk, rewindResult = pcall(file.seek, file, "set", 0)
  if not sizeOk or not size or size > MAX_CATALOG_BYTES
      or not rewindOk or rewindResult == nil then
    file:close()
    log("[CATALOG] Virtual-folder catalog is unreadable or exceeds the safety limit.", "error")
    return assignments, folders, ignored, false
  end
  local lineCount = 0
  for line in file:lines() do
    lineCount = lineCount + 1
    if lineCount > MAX_CATALOG_LINES then
      file:close()
      log("[CATALOG] Virtual-folder catalog exceeds the line limit.", "error")
      return {}, {}, {}, false
    end
    local kind, first, second = line:match("^([PFX])\t([^\t]+)\t?([^\t]*)$")
    first = catalogDecode(first)
    second = catalogDecode(second)
    if kind == "P" and validRelativePath(first) and validRelativePath(second) then
      assignments[first] = second
    elseif kind == "F" and validRelativePath(first) then
      folders[first] = true
    elseif kind == "X" and validRelativePath(first) then
      ignored[first] = true
    elseif line:match("%S") then
      file:close()
      log(("[CATALOG] Invalid virtual-folder catalog line %d."):format(lineCount), "error")
      return {}, {}, {}, false
    end
  end
  file:close()
  return assignments, folders, ignored, true
end

local function storageFilenamesInUse()
  local entries = safeDirectoryEntries(PRESET_DIR, 0)
  if not entries then return nil end
  local used = {}
  for _, entry in ipairs(entries) do used[entry.name:lower()] = true end
  return used
end

local function uniqueStorageName(leafName, used)
  used = used or storageFilenamesInUse()
  if not used then return nil end
  for index = 1, 9999 do
    local suffix = index == 1 and "" or (" %d"):format(index)
    local candidate = leafName:sub(1, 64 - #suffix) .. suffix
    local filename = (candidate .. ".preset"):lower()
    if not used[filename] then
      used[filename] = true
      return candidate
    end
  end
  return nil
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

local presetsMatch

local function readPresetFile(path)
  local file = io.open(path, "r")
  if not file then return nil end
  local sizeOk, size = pcall(file.seek, file, "end")
  if not sizeOk or not size or size > MAX_PRESET_BYTES then
    file:close()
    log(("[FILES] Preset rejected because its size is invalid: file='%s' bytes='%s'.")
      :format(path, tostring(size)), "warn")
    return nil
  end
  local rewindOk, rewindResult = pcall(file.seek, file, "set", 0)
  if not rewindOk or rewindResult == nil then file:close(); return nil end
  local entries = {}
  local metadata = { format = 4, source = "Legacy or ACU-compatible" }
  local lineNumber, malformed = 0, 0
  for line in file:lines() do
    lineNumber = lineNumber + 1
    if lineNumber > MAX_PRESET_LINES then
      file:close()
      log(("[FILES] Preset rejected because it exceeds %d lines: file='%s'.")
        :format(MAX_PRESET_LINES, path), "warn")
      return nil
    end
    local metadataKey, metadataValue = line:match("^# CPM\t([%a]+)\t(.*)$")
    if metadataKey == "format" then
      metadata.format = tonumber(metadataValue) or 4
    elseif metadataKey == "source" then
      metadata.source = catalogDecode(metadataValue)
    elseif metadataKey == "created" then
      metadata.created = catalogDecode(metadataValue)
    elseif metadataKey == "modified" then
      metadata.modified = catalogDecode(metadataValue)
    elseif metadataKey == "notes" then
      metadata.notes = sanitizeMetadata(catalogDecode(metadataValue), 512)
    elseif metadataKey == "tags" then
      metadata.tags = sanitizeMetadata(catalogDecode(metadataValue), 128)
    end
    local key, index = line:match("^%s*(.-):(-?%d+)%s*$")
    local numericIndex = tonumber(index)
    if key and key ~= "" then
      local indexError = optionIndexValidationError(numericIndex)
      if #key > MAX_PRESET_KEY_BYTES
          or indexError
          or #entries >= MAX_PRESET_ENTRIES then
        file:close()
        log(("[FILES] Preset rejected at line %d: file='%s' keyBytes=%d index='%s' indexError='%s' entriesBefore=%d.")
          :format(lineNumber, path, #key, tostring(index),
            tostring(indexError or "none"), #entries), "warn")
        return nil
      end
      table.insert(entries, { key = key, index = numericIndex })
    elseif not metadataKey and line:match("%S") then
      malformed = malformed + 1
      if malformed <= 20 then
        log(("[FILES] Malformed preset line skipped: file='%s' line=%d content='%s'.")
          :format(path, lineNumber, line), "warn")
      end
    end
  end
  file:close()
  if malformed > 0 then
    log(("[FILES] Preset '%s' contains %d malformed nonblank line%s; valid entries remain loadable.")
      :format(path, malformed, malformed == 1 and "" or "s"), "warn")
  end
  if #entries == 0 then return nil end
  return {
    format = metadata.format,
    source = metadata.source,
    created = metadata.created,
    modified = metadata.modified,
    notes = metadata.notes or "",
    tags = metadata.tags or "",
    entries = entries,
  }
end

local function writePresetContents(path, preset)
  local file = io.open(path, "w")
  if not file then return false end
  local wrote, writeResult = pcall(function()
    local metadata = {
      { "format", tostring(tonumber(preset.format) or 5) },
      { "source", preset.source or MOD_NAME },
      { "created", preset.created or "" },
      { "modified", preset.modified or "" },
      { "notes", sanitizeMetadata(preset.notes, 512) },
      { "tags", sanitizeMetadata(preset.tags, 128) },
    }
    for _, item in ipairs(metadata) do
      local result = file:write(("# CPM\t%s\t%s\n"):format(
        item[1], item[1] == "format" and item[2] or catalogEncode(item[2])))
      if not result then return false end
    end
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

local function readBoundedFile(path, maximumBytes)
  local file = io.open(path, "rb")
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

local function writeLinesIfChanged(path, lines, description, maximumBytes)
  local contents = #lines > 0 and (table.concat(lines, "\n") .. "\n") or ""
  if #contents > maximumBytes then return false, false end
  local existing = readBoundedFile(path, maximumBytes)
  if existing == contents then return true, false end
  local result = atomicReplace(path, function(temporary)
    local file = io.open(temporary, "wb")
    if not file then return false end
    local wrote, writeResult = pcall(function()
      return file:write(contents) ~= nil and file:flush() ~= nil
    end)
    local closeOk, closeResult = pcall(file.close, file)
    return wrote and writeResult == true and closeOk and closeResult ~= nil
  end, description)
  return result, result
end

writeConfig = function()
  local result = atomicReplace(CONFIG_FILE, function(temporary)
    local file = io.open(temporary, "wb")
    if not file then return false end
    local wrote, writeResult = pcall(function()
      return file:write(
        "discoveryReminder=" .. tostring(not state.discoveryNoticeIgnored) .. "\n" ..
        "presetSort=" .. (state.sortMode == "modified" and "modified" or "name") .. "\n"
      ) ~= nil and file:flush() ~= nil
    end)
    local closeOk, closeResult = pcall(file.close, file)
    return wrote and writeResult == true and closeOk and closeResult ~= nil
  end, "config")
  return result
end

readConfig = function()
  local config = {
    discoveryReminder = true,
    presetSort = "name",
  }
  local file = io.open(CONFIG_FILE, "rb")
  if not file then return config, false end
  local sizeOk, size = pcall(file.seek, file, "end")
  local rewindOk, rewindResult = pcall(file.seek, file, "set", 0)
  if not sizeOk or not size or size > 4096
      or not rewindOk or rewindResult == nil then
    file:close()
    log("[CONFIG] Config is unreadable or exceeds 4 KB; defaults were used.", "warn")
    return config, false
  end
  for line in file:lines() do
    local key, value = line:match("^%s*([%a]+)%s*=%s*([%a]+)%s*$")
    if key == "discoveryReminder" and (value == "true" or value == "false") then
      config.discoveryReminder = value == "true"
    elseif key == "presetSort" and (value == "name" or value == "modified") then
      config.presetSort = value
    elseif line:match("%S") and not line:match("^%s*#") then
      log("[CONFIG] Ignored unsupported config line: " .. tostring(line), "warn")
    end
  end
  file:close()
  return config, true
end

local function writeCatalog(presets, folders, manualFolders, ignoredPhysicalFolders)
  local lines = {}
  for logicalName, preset in pairs(presets or {}) do
    if preset.storage and validRelativePath(preset.storage)
        and validRelativePath(logicalName) then
      table.insert(lines, "P\t" .. catalogEncode(preset.storage) .. "\t" ..
        catalogEncode(logicalName))
    end
  end
  for folder in pairs(folders or {}) do
    if not (manualFolders or {})[folder] and validRelativePath(folder) then
      table.insert(lines, "F\t" .. catalogEncode(folder))
    end
  end
  for folder in pairs(ignoredPhysicalFolders or {}) do
    if validRelativePath(folder) then
      table.insert(lines, "X\t" .. catalogEncode(folder))
    end
  end
  table.sort(lines, function(a, b) return a:lower() < b:lower() end)
  if #lines > MAX_CATALOG_LINES then
    log("[CATALOG] Virtual-folder catalog exceeds the safe entry limit.", "error")
    return false
  end
  local catalogBytes = 0
  for _, line in ipairs(lines) do catalogBytes = catalogBytes + #line + 1 end
  if catalogBytes > MAX_CATALOG_BYTES then
    log("[CATALOG] Virtual-folder catalog exceeds the safe size limit.", "error")
    return false
  end
  local result, changed = writeLinesIfChanged(
    CATALOG_FILE, lines, "virtual-folder catalog", MAX_CATALOG_BYTES)
  log(("[CATALOG] Saved presets=%d folders=%d ignoredPhysicalFolders=%d success=%s.")
    :format(
      (function() local count = 0; for _ in pairs(presets or {}) do count = count + 1 end; return count end)(),
      (function() local count = 0; for _ in pairs(folders or {}) do count = count + 1 end; return count end)(),
      (function() local count = 0; for _ in pairs(ignoredPhysicalFolders or {}) do count = count + 1 end; return count end)(),
      tostring(result)), result and "info" or "error")
  if result and not changed then
    log("[CATALOG] Virtual-folder catalog was already current; write skipped.", "info")
  end
  return result
end

local function writePresetPath(path, preset)
  return atomicReplace(path, function(temporary)
    if not writePresetContents(temporary, preset) then return false end
    return presetsMatch(preset, readPresetFile(temporary))
  end, "preset")
end

presetsMatch = function(expected, actual)
  local expectedEntries = expected and expected.entries or {}
  local actualEntries = actual and actual.entries or {}
  if #expectedEntries ~= #actualEntries then return false end
  if (tonumber(expected and expected.format) or 4) >= 5 then
    for _, key in ipairs({ "format", "source", "created", "modified", "notes", "tags" }) do
      if tostring(expected[key] or "") ~= tostring(actual and actual[key] or "") then
        return false
      end
    end
  end
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
  local result, changed = writeLinesIfChanged(
    INVENTORY_FILE, lines, "inventory", MAX_CATALOG_BYTES)
  log(("[INVENTORY] Saved %d tracked path%s to '%s' success=%s.")
    :format(#lines, #lines == 1 and "" or "s", INVENTORY_FILE, tostring(result)),
    result and "info" or "error")
  if result and not changed then
    log("[INVENTORY] Inventory was already current; write skipped.", "info")
  end
  return result
end

local function copyFile(source, destination)
  local input = io.open(source, "rb")
  if not input then
    log(("[FILES] Copy failed: could not open source='%s'."):format(source), "error")
    return false
  end
  local sizeOk, sourceSize = pcall(input.seek, input, "end")
  local rewindOk, rewindResult = pcall(input.seek, input, "set", 0)
  if not sizeOk or not sourceSize or not rewindOk or rewindResult == nil then
    input:close()
    log(("[FILES] Copy failed: could not measure source='%s'."):format(source), "error")
    return false
  end
  local output = io.open(destination, "wb")
  if not output then
    input:close()
    log(("[FILES] Copy failed: could not open destination='%s'."):format(destination), "error")
    return false
  end
  local copiedBytes = 0
  local writeOk, writeResult = pcall(function()
    while true do
      local chunk = input:read(FILE_COPY_CHUNK_SIZE)
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
  log(("[FILES] Copy source='%s' destination='%s' bytes=%d success=%s.")
    :format(source, destination, copiedBytes, tostring(copied)), copied and "info" or "error")
  return copied
end

local function removeFileList(paths)
  local success = true
  for _, path in ipairs(paths or {}) do
    if fileExists(path) and not os.remove(path) then success = false end
  end
  return success
end

local function uniquePresetCopyName(sourceName)
  local folder = parentFolder(sourceName)
  local leaf = baseName(sourceName)
  for index = 1, 999 do
    local suffix = index == 1 and " Copy" or (" Copy %d"):format(index)
    local candidate = joinFolder(folder, leaf .. suffix)
    if not findPresetCollision(candidate) then return candidate end
  end
  return nil
end

local function findExistingFolderName(name, excludeName)
  local lowered = name:lower()
  for existing in pairs(state.folders) do
    if existing:lower() == lowered and existing ~= excludeName then return existing end
  end
  return nil
end

local function folderNameExists(name)
  return findExistingFolderName(name) ~= nil
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

local exportSelectedFolderBundle
local importAvailableFolderBundles

do

local function validBundlePath(value)
  if not validRelativePath(value) then return false end
  for part in value:gmatch("[^/]+") do
    local validated = validatedPresetName(part)
    if validated ~= part then return false end
  end
  return true
end

local function hexEncode(value)
  return (value:gsub(".", function(character)
    return ("%02X"):format(character:byte())
  end))
end

local function hexDecode(value)
  if #value % 2 ~= 0 or not value:match("^%x+$") then return nil end
  return (value:gsub("(%x%x)", function(pair)
    return string.char(tonumber(pair, 16))
  end))
end

local function folderBundleFiles()
  local bundles = {}
  local entries = safeDirectoryEntries(PRESET_DIR, 0)
  if not entries then return bundles end
  for _, entry in ipairs(entries) do
    if entry.type == "file"
        and entry.name:lower():sub(-#FOLDER_BUNDLE_EXTENSION) == FOLDER_BUNDLE_EXTENSION then
      table.insert(bundles, PRESET_DIR .. "/" .. entry.name)
    end
  end
  table.sort(bundles, function(a, b) return a:lower() < b:lower() end)
  return bundles
end

local function validBundleFilename(filename)
  return type(filename) == "string" and filename ~= ""
    and #filename <= 255 and not filename:find("/", 1, true)
    and not filename:find("\\", 1, true) and not filename:find("%c")
    and filename:lower():sub(-#FOLDER_BUNDLE_EXTENSION) == FOLDER_BUNDLE_EXTENSION
end

local function readImportedBundles()
  local imported = {}
  local contents, readError = readBoundedFile(IMPORTED_BUNDLES_FILE, MAX_CATALOG_BYTES)
  if not contents then return imported, readError == "missing" end
  local lineCount = 0
  for line in (contents .. "\n"):gmatch("(.-)\n") do
    if line ~= "" then
      lineCount = lineCount + 1
      if lineCount > MAX_CATALOG_LINES then return nil, false end
      local encodedName, fingerprint = line:match("^B\t([^\t]+)\t(%d+:%d+)$")
      local filename = encodedName and catalogDecode(encodedName) or nil
      if not validBundleFilename(filename) then return nil, false end
      imported[filename:lower()] = { filename = filename, fingerprint = fingerprint }
    end
  end
  return imported, true
end

local function writeImportedBundles(imported)
  local lines = {}
  for _, item in pairs(imported or {}) do
    if not validBundleFilename(item.filename)
        or type(item.fingerprint) ~= "string"
        or not item.fingerprint:match("^%d+:%d+$") then return false end
    table.insert(lines, "B\t" .. catalogEncode(item.filename) .. "\t" .. item.fingerprint)
  end
  table.sort(lines, function(a, b) return a:lower() < b:lower() end)
  return writeLinesIfChanged(
    IMPORTED_BUNDLES_FILE, lines, "imported-bundle registry", MAX_CATALOG_BYTES) == true
end

local function uniqueFolderBundleFilename(folder)
  local stem = "Character Preset Manager Folder - " .. baseName(folder)
  for index = 1, 999 do
    local suffix = index == 1 and "" or (" Copy %d"):format(index)
    local filename = PRESET_DIR .. "/" .. stem .. suffix .. FOLDER_BUNDLE_EXTENSION
    if not fileExists(filename) and not fileExists(filename .. ".tmp")
        and not fileExists(filename .. ".bak") then return filename end
  end
  return nil
end

exportSelectedFolderBundle = function()
  auditSection("EXPORT FOLDER BUNDLE")
  local folder = state.selectedFolder
  if folder == "" or not state.folders[folder] then
    state.folderStatus, state.folderStatusError = "Select a folder to export.", true; return
  end
  local names = {}
  for name in pairs(state.presets) do
    if isInFolderTree(parentFolder(name), folder) then table.insert(names, name) end
  end
  table.sort(names, function(a, b) return a:lower() < b:lower() end)
  if #names == 0 then
    state.folderStatus, state.folderStatusError =
      "The selected folder contains no presets to share.", true; return
  end
  if #names > MAX_FOLDER_BUNDLE_PRESETS then
    state.folderStatus, state.folderStatusError =
      ("The folder exceeds the %d-preset bundle limit."):format(MAX_FOLDER_BUNDLE_PRESETS), true; return
  end
  local lines = { "CPMFOLDER\t1", "ROOT\t" .. catalogEncode(baseName(folder)) }
  local totalBytes = #lines[1] + #lines[2] + 2
  local folders = {}
  for candidate in pairs(state.folders) do
    if candidate ~= folder and isInFolderTree(candidate, folder) then
      table.insert(folders, candidate:sub(#folder + 2))
    end
  end
  table.sort(folders, function(a, b) return a:lower() < b:lower() end)
  for _, relativeFolder in ipairs(folders) do
    if not validBundlePath(relativeFolder) then
      state.folderStatus, state.folderStatusError =
        "The folder contains an unsafe nested path and cannot be exported.", true; return
    end
    local line = "F\t" .. catalogEncode(relativeFolder)
    totalBytes = totalBytes + #line + 1
    if totalBytes > MAX_FOLDER_BUNDLE_BYTES then
      state.folderStatus, state.folderStatusError =
        "The folder bundle would exceed the 32 MB safety limit.", true; return
    end
    table.insert(lines, line)
  end
  for _, name in ipairs(names) do
    local relativeName = name:sub(#folder + 2)
    local contents = readBoundedFile(presetPath(name), MAX_PRESET_BYTES)
    if not contents or not validBundlePath(relativeName) then
      state.folderStatus, state.folderStatusError =
        "A preset could not be read safely for export: " .. name, true; return
    end
    local prefix = "P\t" .. catalogEncode(relativeName) .. "\t"
    local projectedBytes = totalBytes + #prefix + (#contents * 2) + 1
    if projectedBytes > MAX_FOLDER_BUNDLE_BYTES then
      state.folderStatus, state.folderStatusError =
        "The folder bundle would exceed the 32 MB safety limit.", true; return
    end
    local line = prefix .. hexEncode(contents)
    totalBytes = projectedBytes
    table.insert(lines, line)
  end
  local filename = uniqueFolderBundleFilename(folder)
  if not filename then
    state.folderStatus, state.folderStatusError =
      "A unique folder-bundle filename could not be allocated.", true; return
  end
  local wrote = writeLinesIfChanged(filename, lines, "folder bundle", MAX_FOLDER_BUNDLE_BYTES)
  if not wrote then
    state.folderStatus, state.folderStatusError = "The folder bundle could not be written.", true; return
  end
  state.folderStatus, state.folderStatusError =
    ("Exported %d preset%s to %s. Share this one file.")
      :format(#names, #names == 1 and "" or "s", filename), false
  log(("[FOLDER BUNDLE] Exported folder='%s' presets=%d file='%s'.")
    :format(folder, #names, filename), "complete")
end

local function readFolderBundle(filename)
  local contents, readError = readBoundedFile(filename, MAX_FOLDER_BUNDLE_BYTES)
  if not contents then return nil, "Bundle could not be read: " .. tostring(readError) end
  local bundle = { folders = {}, folderNames = {}, presets = {}, presetNames = {} }
  local lineNumber = 0
  for line in contents:gmatch("[^\n]+") do
    line = line:gsub("\r$", "")
    if line ~= "" then
      lineNumber = lineNumber + 1
      if lineNumber == 1 then
        if line ~= "CPMFOLDER\t1" then return nil, "Bundle header is invalid." end
      else
        local root = line:match("^ROOT\t([^\t]+)$")
        local folder = line:match("^F\t([^\t]+)$")
        local name, encoded = line:match("^P\t([^\t]+)\t([%x]+)$")
        if root then
          root = catalogDecode(root)
          if bundle.root or not validBundlePath(root) or parentFolder(root) ~= "" then
            return nil, "Bundle root is invalid."
          end
          bundle.root = root
        elseif folder then
          folder = catalogDecode(folder)
          if not validBundlePath(folder) then return nil, "Bundle folder path is invalid." end
          if bundle.folderNames[folder:lower()] then
            return nil, "Bundle contains duplicate folder paths."
          end
          bundle.folderNames[folder:lower()] = true
          bundle.folders[folder] = true
        elseif name then
          name = catalogDecode(name)
          local raw = hexDecode(encoded)
          if not raw or not validBundlePath(name) or #raw > MAX_PRESET_BYTES
              or #bundle.presets >= MAX_FOLDER_BUNDLE_PRESETS then
            return nil, "Bundle preset entry is invalid."
          end
          if bundle.presetNames[name:lower()] then
            return nil, "Bundle contains duplicate preset paths."
          end
          bundle.presetNames[name:lower()] = true
          table.insert(bundle.presets, { name = name, contents = raw })
        else
          return nil, ("Bundle line %d is invalid."):format(lineNumber)
        end
      end
    end
  end
  if not bundle.root or #bundle.presets == 0 then return nil, "Bundle is empty or incomplete." end
  bundle.folderNames = nil
  bundle.presetNames = nil
  return bundle
end

local function writeRawPreset(path, contents)
  return atomicReplace(path, function(temporary)
    local file = io.open(temporary, "wb")
    if not file then return false end
    local wrote, writeResult = pcall(function()
      return file:write(contents) ~= nil and file:flush() ~= nil
    end)
    local closeOk, closeResult = pcall(file.close, file)
    return wrote and writeResult == true and closeOk and closeResult ~= nil
  end, "imported folder preset")
end

local function importFolderBundle(filename, fingerprint, importedBundles)
  local bundle, bundleError = readFolderBundle(filename)
  if not bundle then return nil, bundleError end
  local root = bundle.root
  if folderNameExists(root) then root = uniqueFolderCopyName(root) end
  if not root then return nil, "A unique imported folder name could not be allocated." end
  local newPresets = cloneMap(state.presets)
  local newFolders = cloneMap(state.folders)
  local newManualFolders = cloneMap(state.manualFolders)
  local newIgnored = cloneMap(state.ignoredPhysicalFolders)
  addFolderAncestors(newFolders, root)
  for folder in pairs(bundle.folders) do
    addFolderAncestors(newFolders, joinFolder(root, folder))
  end
  local reservedStorage = storageFilenamesInUse()
  if not reservedStorage then return nil, "Preset storage could not be inspected safely." end
  local createdFiles = {}
  for _, item in ipairs(bundle.presets) do
    local logicalName = joinFolder(root, item.name)
    if findPresetCollision(logicalName) then
      removeFileList(createdFiles)
      return nil, "An imported preset name would collide with an existing preset."
    end
    local storage = uniqueStorageName(baseName(logicalName), reservedStorage)
    if not storage then
      removeFileList(createdFiles)
      return nil, "A safe imported preset filename could not be allocated."
    end
    local path = PRESET_DIR .. "/" .. storage .. ".preset"
    if not writeRawPreset(path, item.contents) then
      removeFileList(createdFiles)
      return nil, "An imported preset file could not be written."
    end
    table.insert(createdFiles, path)
    local preset = readPresetFile(path)
    item.contents = nil
    if not preset then
      removeFileList(createdFiles)
      return nil, "An imported preset failed verification."
    end
    preset.storage = storage
    newPresets[logicalName] = preset
  end
  if not writeCatalog(newPresets, newFolders, newManualFolders, newIgnored) then
    removeFileList(createdFiles)
    return nil, "The imported folder was rolled back because the catalog could not be saved."
  end
  local inventorySaved = writeInventory(newPresets, newFolders)
  if not inventorySaved then
    writeCatalog(state.presets, state.folders, state.manualFolders,
      state.ignoredPhysicalFolders)
    removeFileList(createdFiles)
    return nil, "The imported folder was rolled back because the inventory could not be saved."
  end
  local leaf = filename:match("([^/]+)$")
  local updatedImported = cloneMap(importedBundles)
  updatedImported[leaf:lower()] = { filename = leaf, fingerprint = fingerprint }
  if not writeImportedBundles(updatedImported) then
    writeCatalog(state.presets, state.folders, state.manualFolders,
      state.ignoredPhysicalFolders)
    writeInventory(state.presets, state.folders)
    removeFileList(createdFiles)
    return nil, "The imported folder was rolled back because its import record could not be saved."
  end
  state.presets, state.folders = newPresets, newFolders
  state.manualFolders, state.ignoredPhysicalFolders = newManualFolders, newIgnored
  state.selectedFolder = root
  invalidateViewCache()
  resetLoadState()
  cancelConfirmations()
  importedBundles[leaf:lower()] = updatedImported[leaf:lower()]
  log(("[FOLDER BUNDLE] Imported file='%s' root='%s' presets=%d fingerprint='%s'.")
    :format(filename, root, #bundle.presets, fingerprint), "complete")
  return root, ""
end

importAvailableFolderBundles = function()
  auditSection("IMPORT FOLDER BUNDLES")
  local files = folderBundleFiles()
  if #files == 0 then
    state.folderStatus, state.folderStatusError =
      "Place a .cpmfolder file in Character Presets, then select Import Folder Bundles.", true; return
  end
  local importedBundles, registryOk = readImportedBundles()
  if not registryOk then
    state.folderStatus, state.folderStatusError =
      "Imported Bundles.txt is unreadable or unsafe. No bundles were changed.", true; return
  end
  local imported, skipped, failures, warnings = 0, 0, {}, {}
  for _, filename in ipairs(files) do
    local leaf = filename:match("([^/]+)$")
    local fingerprint = fileFingerprint(filename, MAX_FOLDER_BUNDLE_BYTES)
    if not fingerprint then
      table.insert(failures, filename .. ": Bundle fingerprint could not be read safely.")
    elseif importedBundles[leaf:lower()]
        and importedBundles[leaf:lower()].fingerprint == fingerprint then
      skipped = skipped + 1
      log(("[FOLDER BUNDLE] Skipped previously imported file='%s' fingerprint='%s'.")
        :format(filename, fingerprint), "info")
    else
      local root, result = importFolderBundle(filename, fingerprint, importedBundles)
      if root then
        imported = imported + 1
        if result ~= "" then table.insert(warnings, filename .. ":" .. result) end
      else
        table.insert(failures, filename .. ": " .. tostring(result))
      end
    end
  end
  if #failures > 0 then
    state.folderStatus = ("Imported %d bundle%s; skipped %d already imported. Failed: %s")
      :format(imported, imported == 1 and "" or "s", skipped, table.concat(failures, " | "))
    state.folderStatusError = true
  else
    state.folderStatus = ("Imported %d folder bundle%s; skipped %d already imported.%s")
      :format(imported, imported == 1 and "" or "s",
        skipped,
        #warnings > 0 and (" " .. table.concat(warnings, " | ")) or "")
    state.folderStatusError = false
  end
end

end

local function refreshPresets(scanReason, recoveryAssignments, recoveryFolders,
    recoveryManualFolders)
  local currentPresets = state.presets or {}
  local currentFolders = state.folders or {}
  local previousPresets = currentPresets
  local previousFolders = currentFolders
  local baselineAvailable = state.ready
  if scanReason == "startup" then
    previousPresets, previousFolders, baselineAvailable = readInventory()
    log(("[INVENTORY] Startup baseline available=%s presets=%d folders=%d.")
      :format(tostring(baselineAvailable),
        (function() local count = 0; for _ in pairs(previousPresets) do count = count + 1 end; return count end)(),
        (function() local count = 0; for _ in pairs(previousFolders) do count = count + 1 end; return count end)()), "info")
  end
  local assignments, catalogFolders, ignoredPhysicalFolders, catalogStatus = readCatalog()
  if catalogStatus == false then
    log("[CATALOG] Preset scan stopped because the existing virtual-folder catalog is invalid.", "error")
    return currentPresets, false
  end
  for storage, logicalName in pairs(recoveryAssignments or {}) do
    assignments[storage] = logicalName
    addFolderAncestors(catalogFolders, parentFolder(logicalName))
  end
  for folder in pairs(recoveryFolders or {}) do
    addFolderAncestors(catalogFolders, folder)
  end
  for folder in pairs(recoveryManualFolders or {}) do
    ignoredPhysicalFolders[folder] = nil
  end
  local scannedPresets = {}
  local physicalFolders = {}
  local function scan(relative, depth)
    local path = folderPath(relative)
    local files, listError = safeDirectoryEntries(path, depth)
    if not files then
      log(("[FILES] Scan stopped at '%s': %s."):format(path, tostring(listError)), "error")
      return false
    end
    if relative ~= "" then physicalFolders[relative] = true end
    for _, entry in ipairs(files) do
      local filename = entry.name
      local childRelative = joinFolder(relative, filename)
      local name = filename:lower():sub(-7) == ".preset"
        and filename:sub(1, -8) or nil
      if entry.type == "file" and name and name ~= "" then
        local storage = joinFolder(relative, name)
        local preset = readPresetFile(path .. "/" .. filename)
        if preset then
          preset.storage = storage
          scannedPresets[storage] = preset
        else
          log(("[FILES] Skipped unreadable, unsafe, or empty preset '%s'.")
            :format(childRelative), "warn")
        end
      elseif entry.type == "directory"
          and childRelative ~= ".Character Preset Manager Trash"
          and not scan(childRelative, depth + 1) then
        return false
      end
    end
    return true
  end

  if not scan("", 0) then
    log(("[FILES] Preset scan was incomplete; previous state and inventory were retained (reason=%s).")
      :format(tostring(scanReason or "unspecified")), "error")
    return currentPresets, false
  end

  local presets = {}
  local folders = {}
  local manualFolders = {}
  local usedLogicalNames = {}
  for folder in pairs(catalogFolders) do addFolderAncestors(folders, folder) end
  local storageNames = {}
  for storage in pairs(scannedPresets) do table.insert(storageNames, storage) end
  table.sort(storageNames, function(a, b) return a:lower() < b:lower() end)
  for _, storage in ipairs(storageNames) do
    local preset = scannedPresets[storage]
    local preferred = assignments[storage]
    if not validRelativePath(preferred) then preferred = storage end
    local logicalName = preferred
    local lowered = logicalName:lower()
    if usedLogicalNames[lowered] then
      local folder = parentFolder(preferred)
      local leaf = baseName(preferred)
      local resolved = false
      for index = 2, 9999 do
        local suffix = (" %d"):format(index)
        local candidate = joinFolder(folder, leaf:sub(1, 64 - #suffix) .. suffix)
        if not usedLogicalNames[candidate:lower()] then
          logicalName = candidate
          lowered = candidate:lower()
          resolved = true
          break
        end
      end
      if not resolved then
        log(("[CATALOG] Could not assign a unique display name for storage='%s'.")
          :format(storage), "error")
        return currentPresets, false
      end
    end
    usedLogicalNames[lowered] = true
    preset.storage = storage
    presets[logicalName] = preset
    local logicalFolder = parentFolder(logicalName)
    addFolderAncestors(folders, logicalFolder)
    if logicalName == storage and logicalFolder ~= "" then
      local current = logicalFolder
      while current ~= "" do
        manualFolders[current] = true
        ignoredPhysicalFolders[current] = nil
        current = parentFolder(current)
      end
    end
  end
  for folder in pairs(physicalFolders) do
    if not ignoredPhysicalFolders[folder] then
      addFolderAncestors(folders, folder)
      local current = folder
      while current ~= "" do
        manualFolders[current] = true
        current = parentFolder(current)
      end
    end
  end

  if not writeCatalog(presets, folders, manualFolders, ignoredPhysicalFolders) then
    log("[CATALOG] Preset scan retained the previous state because the virtual-folder catalog could not be updated.", "error")
    return currentPresets, false
  end

  local externalScan = scanReason == "external" or scanReason == "startup"
  if externalScan and baselineAvailable then
    local added, removed, modified = 0, 0, 0
    local foldersAdded, foldersRemoved = 0, 0
    for name, preset in pairs(presets) do
      if not previousPresets[name] then
        added = added + 1
        log(("[EXTERNAL CHANGE] Preset added or moved in: '%s'.")
          :format(PRESET_DIR .. "/" .. preset.storage .. ".preset"), "warn")
      elseif type(previousPresets[name]) == "table"
          and not presetsMatch(previousPresets[name], preset) then
        modified = modified + 1
        log(("[EXTERNAL CHANGE] Preset contents changed: '%s'.")
          :format(PRESET_DIR .. "/" .. preset.storage .. ".preset"), "warn")
      end
    end
    for name in pairs(previousPresets) do
      if not presets[name] then
        removed = removed + 1
        log(("[EXTERNAL CHANGE] Preset removed or moved out: '%s'."):format(name), "warn")
      end
    end
    for name in pairs(folders) do
      if not previousFolders[name] then
        foldersAdded = foldersAdded + 1
        log(("[EXTERNAL CHANGE] Folder added or moved in: '%s'."):format(name), "warn")
      end
    end
    for name in pairs(previousFolders) do
      if not folders[name] then
        foldersRemoved = foldersRemoved + 1
        log(("[EXTERNAL CHANGE] Folder removed or moved out: '%s'."):format(name), "warn")
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
  state.manualFolders = manualFolders
  state.ignoredPhysicalFolders = ignoredPhysicalFolders
  invalidateViewCache()
  resetLoadState()
  for folder in pairs(state.expandedLoadFolders) do
    if not folders[folder] then state.expandedLoadFolders[folder] = nil end
  end
  writeInventory(presets, folders)
  if state.selectedFolder ~= "" and not folders[state.selectedFolder] then
    state.selectedFolder = ""
    cancelConfirmations()
  end
  if state.selected and not presets[state.selected] then
    state.selected = nil
    resetLoadState()
    cancelConfirmations()
  end
  for name in pairs(state.bulkSelected) do
    if not presets[name] then state.bulkSelected[name] = nil end
  end
  local count = 0
  for _ in pairs(presets) do count = count + 1 end
  log(("[FILES] Scanned '%s': %d readable preset file%s found (reason=%s).")
    :format(PRESET_DIR, count, count == 1 and "" or "s", tostring(scanReason or "unspecified")), "info")
  return presets, true
end

local function savePreset(confirmOverwrite)
  auditSection("CREATE PRESET")
  log(("[PRESET] Create requested: enteredName='%s' overwriteConfirmed=%s")
    :format(tostring(state.newName), tostring(confirmOverwrite == true)), "info")
  local _, options, optionsError = getOptions()
  if not options then
    setStatus("create", "Open the character creator, a mirror, or a ripperdoc.", true)
    log("[create] " .. tostring(optionsError), "warn")
    return
  end
  local leafName, nameError = validatedPresetName(state.newName)
  if not leafName then setStatus("create", nameError, true); return end
  local name = joinFolder(state.selectedFolder, leafName)
  local armedOverwriteName = state.pendingOverwriteName
  local armedOverwriteFingerprint = state.pendingOverwriteFingerprint
  cancelConfirmations()
  resetLoadState()

  local collision = findPresetCollision(name)
  if collision and collision ~= name then
    state.pendingOverwriteName = nil
    setStatus("create", ("\"%s\" conflicts with \"%s\" because Windows treats them as the same name. Enter another name.")
      :format(name, collision), true)
    return
  end
  if collision == name then
    local currentFingerprint = fileFingerprint(presetPath(collision))
    if not currentFingerprint then
      setStatus("create", "The existing preset could not be verified safely.", true)
      return
    end
    if not confirmOverwrite
        or armedOverwriteName ~= name
        or armedOverwriteFingerprint ~= currentFingerprint then
      state.pendingOverwriteName = name
      state.pendingOverwriteFingerprint = currentFingerprint
      local message = confirmOverwrite and armedOverwriteName == name
        and ("\"%s\" changed after confirmation. Review it and select Confirm Overwrite again.")
          :format(name)
        or ("\"%s\" already exists. Select Confirm Overwrite to replace it.")
          :format(name)
      setStatus("create", message, true)
      return
    end
  end
  state.pendingOverwriteName = nil
  state.pendingOverwriteFingerprint = nil

  local entries = {}
  local savedOccurrences = {}
  for _, option in ipairs(options) do
    local key = optionKey(option)
    if key and option.isEditable and option.isActive then
      local currentIndex = tonumber(option.currIndex)
      local identity = optionAuditIdentity(
        option,
        key,
        (savedOccurrences[key] or 0) + 1
      )
      if #key > MAX_PRESET_KEY_BYTES then
        log(("[SNAPSHOT] Rejected %s | keyBytes=%d maximum=%d")
          :format(identity, #key, MAX_PRESET_KEY_BYTES), "error")
        setStatus("create",
          ("A customization option name exceeds the %d-byte preset limit. See Debug for the exact option.")
            :format(MAX_PRESET_KEY_BYTES),
          true
        )
        return
      end
      if #entries >= MAX_PRESET_ENTRIES then
        log(("[SNAPSHOT] Rejected %s | savedEntries=%d maximum=%d")
          :format(identity, #entries, MAX_PRESET_ENTRIES), "error")
        setStatus("create",
          ("The editor exposes more than %d active options. See Debug for details.")
            :format(MAX_PRESET_ENTRIES),
          true
        )
        return
      end
      local indexError = optionIndexValidationError(currentIndex)
      if indexError then
        log(("[SNAPSHOT] Rejected %s | index=%s reason='%s' nativeMaximum=%d")
          :format(identity, tostring(currentIndex), indexError, MAX_OPTION_INDEX), "error")
        setStatus("create",
          "A customization option returned an unsupported index. See Debug for the exact option and value.",
          true
        )
        return
      end
      savedOccurrences[key] = (savedOccurrences[key] or 0) + 1
      log(("[SNAPSHOT] Saved %s index=%d editable=true active=true")
        :format(optionAuditIdentity(option, key, savedOccurrences[key]),
          currentIndex), "info")
      table.insert(entries, {
        key = key,
        index = currentIndex,
      })
    end
  end
  if #entries == 0 then
    setStatus("create", "No editable options were found.", true)
    return
  end

  local previousPreset = state.presets[name]
  local storage = previousPreset and previousPreset.storage
    or uniqueStorageName(leafName)
  if not storage then
    setStatus("create", "A safe storage filename could not be allocated.", true)
    return
  end
  local newPreset = {
    format = 5,
    source = MOD_NAME,
    created = previousPreset and previousPreset.created or logTimestamp(),
    modified = logTimestamp(),
    notes = previousPreset and previousPreset.notes or "",
    tags = previousPreset and previousPreset.tags or "",
    entries = entries,
    storage = storage,
  }
  local storagePath = PRESET_DIR .. "/" .. storage .. ".preset"
  if not writePresetPath(storagePath, newPreset) then
    setStatus("create", "Could not write " .. storagePath .. ".", true)
    return
  end
  state.presets[name] = newPreset
  if not writeCatalog(state.presets, state.folders, state.manualFolders,
      state.ignoredPhysicalFolders) then
    local rolledBack = true
    if previousPreset then
      rolledBack = writePresetPath(storagePath, previousPreset)
      state.presets[name] = previousPreset
    else
      rolledBack = removeFileList({ storagePath })
      state.presets[name] = nil
    end
    setStatus("create", rolledBack
      and "The preset was not saved because its virtual folder could not be recorded."
      or "The virtual-folder catalog failed, and the preset file could not be rolled back safely.", true)
    return
  end
  state.selected = name
  state.presetNotes = newPreset.notes or ""
  state.presetTags = newPreset.tags or ""
  invalidateViewCache()
  state.renameName = ""
  state.newName = ""
  resetLoadState()
  log(("Created preset '%s': format=5 orderedOptions=%d")
    :format(name, #entries), "info")
  if writeInventory(state.presets, state.folders) then
    setStatus("create", ("Saved \"%s\" with %d options.")
      :format(name, #entries))
  else
    setStatus("create", ("Saved \"%s\", but the inventory could not be updated.")
      :format(name), false, "warning")
  end
end

local function loadPreset()
  if not state.selected or not state.presets[state.selected] then
    resetLoadState()
    setStatus("load", "Select a preset.", true)
    return
  end
  local system, options, optionsError = getOptions()
  if not options then
    setStatus("load", "Open a customization screen before loading a preset.", true)
    log("[load] " .. tostring(optionsError), "warn")
    return
  end
  if state.loadPresetName ~= state.selected then refreshPreflight() end

  local preset = state.presets[state.selected]
  local values, savedCounts, valueCount
  if state.loadPresetName == state.selected then
    state.loadPass = state.loadPass + 1
    values = state.loadValues
    savedCounts = state.loadSavedCounts
    valueCount = state.loadValueCount
  else
    auditSection("LOAD PRESET")
    log(("[PRESET] Load requested: name='%s'"):format(tostring(state.selected)), "load")
    state.loadPresetName = state.selected
    state.loadPass = 1
    state.previousUnresolvedSignature = nil
    state.unresolvedRepeatCount = 0
    state.loadSatisfied = {}
    values, savedCounts, valueCount = {}, {}, 0
    for _, entry in ipairs(preset.entries or {}) do
      local label = tostring(entry.key or "")
      if label ~= "" then
        savedCounts[label] = (savedCounts[label] or 0) + 1
        local savedKey = label .. "\31" .. tostring(savedCounts[label])
        values[savedKey] = tonumber(entry.index) or 0
        valueCount = valueCount + 1
      end
    end
    state.loadValues = values
    state.loadSavedCounts = savedCounts
    state.loadValueCount = valueCount
  end
  state.loadStalled = false
  if valueCount == 0 then setStatus("load", "The preset contains no saved options.", true); return end

  if state.loadPass == 1 then
    log(("Preset='%s' | saved=%d options | editor exposes=%d options | format=%s")
      :format(state.selected, valueCount, #options, tostring(preset.format or 1)),
      "load")
  end

  if state.resetBeforeLoad then
    local activeOccurrences = {}
    for _, option in ipairs(options) do
      local label = optionKey(option)
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

  local applied, missing, ambiguous, invalid = 0, 0, 0, 0
  local unresolved = {}
  local seen = {}
  local exposed = {}
  local activeKeySet = {}
  local activeCounts = {}
  local occurrences = {}
  for _, option in ipairs(options) do
    local label = optionKey(option)
    local key = nil
    local occurrence = nil
    if label and option.isEditable and option.isActive then
      occurrences[label] = (occurrences[label] or 0) + 1
      activeCounts[label] = occurrences[label]
      occurrence = occurrences[label]
      key = label .. "\31" .. tostring(occurrence)
    end
    table.insert(exposed, {
      option = option,
      label = label,
      key = key,
      occurrence = occurrence,
    })
    if key then activeKeySet[key] = true end
  end

  local satisfiedBefore = 0
  for _, exposedOption in ipairs(exposed) do
    local key = exposedOption.key
    local label = exposedOption.label
    local wanted = key and values[key] or nil
    local countMatches = label
      and (savedCounts[label] or 0) == (activeCounts[label] or 0)
    if wanted ~= nil and countMatches and optionIndexIsValid(wanted)
        and (tonumber(exposedOption.option.currIndex) or 0) == wanted then
      satisfiedBefore = satisfiedBefore + 1
    end
  end
  for key in pairs(values) do
    if not activeKeySet[key] and state.loadSatisfied[key] then
      satisfiedBefore = satisfiedBefore + 1
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
    local indexIsValid = wanted == nil or optionIndexIsValid(wanted)
    if wanted ~= nil then
      seen[key] = true
      if not countMatches then
        ambiguous = ambiguous + 1
        unresolved["ambiguous:" .. tostring(key)] = true
        log(("[SKIPPED] Ambiguous repeated option: %s savedCount=%d exposedCount=%d")
          :format(
            optionAuditIdentity(option, label, exposedOption.occurrence),
            savedCounts[label] or 0,
            activeCounts[label] or 0
          ), "warn")
      elseif not indexIsValid then
        invalid = invalid + 1
        unresolved["invalid-index:" .. tostring(key)] = true
        log(("[SKIPPED] Saved index is outside the supported native range: %s targetIndex=%s")
          :format(optionAuditIdentity(option, label, exposedOption.occurrence),
            tostring(wanted)), "warn")
      end
    end
    if wanted ~= nil and countMatches and indexIsValid
        and option.isEditable and option.isActive then
      local current = tonumber(option.currIndex) or 0
      if current == wanted then
        state.loadSatisfied[key] = true
        applied = applied + 1
      else
        state.loadSatisfied[key] = nil
        local ok, applyError = pcall(system.ApplyChangeToOption, system, option, wanted)
        if ok then
          state.loadSatisfied[key] = true
          state.loadRemaining = math.max(0, valueCount - satisfiedBefore - 1)
          state.loadNeedsContinue = true
          state.previousUnresolvedSignature = nil
          state.unresolvedRepeatCount = 0
          log(("CHANGE | pass=%d | %s | index %s -> %s")
            :format(state.loadPass,
              optionAuditIdentity(option, label, exposedOption.occurrence),
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
              optionAuditIdentity(option, label, exposedOption.occurrence),
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
  state.loadRemaining = missing + ambiguous + invalid
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
        :format(state.loadPass, applied, valueCount, state.loadRemaining))
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

refreshPreflight = function()
  state.preflight = nil
  local preset = state.selected and state.presets[state.selected]
  if not preset then return end
  local _, options = getOptions()
  if not options then return end
  local savedCounts, exposedCounts = {}, {}
  local invalid = 0
  for _, entry in ipairs(preset.entries or {}) do
    savedCounts[entry.key] = (savedCounts[entry.key] or 0) + 1
    if not optionIndexIsValid(tonumber(entry.index)) then invalid = invalid + 1 end
  end
  for _, option in ipairs(options) do
    local key = optionKey(option)
    if key and option.isEditable and option.isActive then
      exposedCounts[key] = (exposedCounts[key] or 0) + 1
    end
  end
  local available, unavailable, ambiguous = 0, 0, 0
  for key, count in pairs(savedCounts) do
    local exposed = exposedCounts[key] or 0
    if exposed == count then
      available = available + count
    elseif exposed == 0 then
      unavailable = unavailable + count
    else
      ambiguous = ambiguous + count
    end
  end
  state.preflight = {
    total = #(preset.entries or {}),
    available = available,
    unavailable = unavailable,
    ambiguous = ambiguous,
    invalid = invalid,
  }
end

local function cancelLoading()
  local name = state.loadPresetName or state.selected
  resetLoadState()
  setStatus("load", name and ("Loading canceled for \"" .. name .. "\".")
    or "Loading canceled.")
end

local writeTransaction
local completeTransaction
local recoverTransaction
local refreshTrash
local trashPreset
local restoreTrashPreset
local restoreTrashGroup
local emptyTrash
local bulkPresetNamesInFolder
local selectedBulkPresetNames
local requestBulkTrash

do

local function validTrashFilename(filename)
  return type(filename) == "string" and #filename > 7 and #filename <= 71
    and filename:find("/", 1, true) == nil and filename:find("\\", 1, true) == nil
    and filename:lower():sub(-7) == ".preset"
end

local function trashCatalogLines(trash, groups)
  local lines = {}
  for filename, item in pairs(trash or {}) do
    if not validTrashFilename(filename)
        or not validRelativePath(item.original or "") then return nil end
    table.insert(lines, "P\t" .. catalogEncode(filename) .. "\t" ..
      catalogEncode(item.original) .. "\t" .. catalogEncode(item.group or ""))
  end
  for groupId, group in pairs(groups or {}) do
    if type(groupId) ~= "string" or groupId == "" or #groupId > 256
        or not validRelativePath(group.root or "") then return nil end
    table.insert(lines, "G\t" .. catalogEncode(groupId) .. "\t" ..
      catalogEncode(group.root))
    for folder in pairs(group.folders or {}) do
      if not validRelativePath(folder) then return nil end
      table.insert(lines, "F\t" .. catalogEncode(groupId) .. "\t" ..
        catalogEncode(folder))
    end
    for folder in pairs(group.manualFolders or {}) do
      if not validRelativePath(folder) then return nil end
      table.insert(lines, "M\t" .. catalogEncode(groupId) .. "\t" ..
        catalogEncode(folder))
    end
  end
  table.sort(lines, function(a, b) return a:lower() < b:lower() end)
  if #lines > MAX_CATALOG_LINES then return nil end
  return lines
end

local function writeTrashCatalog(trash, groups)
  groups = groups or state.trashGroups
  local lines = trashCatalogLines(trash, groups)
  if not lines then
    log("[TRASH] Trash catalog contains an unsafe or excessive entry.", "error")
    return false
  end
  local result, changed = writeLinesIfChanged(
    TRASH_CATALOG_FILE, lines, "trash catalog", MAX_CATALOG_BYTES)
  if result and not changed then
    log("[TRASH] Trash catalog was already current; write skipped.", "info")
  end
  return result
end

local function readTrashCatalog()
  local originals, groups = {}, {}
  local contents, readError = readBoundedFile(TRASH_CATALOG_FILE, MAX_CATALOG_BYTES)
  if not contents then
    return originals, groups, readError == "missing"
  end
  local lineCount = 0
  for line in (contents .. "\n"):gmatch("(.-)\n") do
    if line ~= "" then
      lineCount = lineCount + 1
      if lineCount > MAX_CATALOG_LINES then return nil, nil, false end
      local kind, first, second, third = line:match("^([PGFM])\t([^\t]+)\t([^\t]+)\t?(.*)$")
      if kind == "P" then
        local filename = catalogDecode(first)
        local original = catalogDecode(second)
        local group = third ~= "" and catalogDecode(third) or nil
        if not validTrashFilename(filename) or not validRelativePath(original)
            or (group and #group > 256) then return nil, nil, false end
        originals[filename] = { original = original, group = group }
      elseif kind == "G" then
        local groupId, root = catalogDecode(first), catalogDecode(second)
        if groupId == "" or #groupId > 256 or not validRelativePath(root) then
          return nil, nil, false
        end
        groups[groupId] = groups[groupId] or { root = root, folders = {}, manualFolders = {} }
        groups[groupId].root = root
      elseif kind == "F" or kind == "M" then
        local groupId, folder = catalogDecode(first), catalogDecode(second)
        if groupId == "" or #groupId > 256 or not validRelativePath(folder) then
          return nil, nil, false
        end
        groups[groupId] = groups[groupId] or {
          root = folder, folders = {}, manualFolders = {},
        }
        groups[groupId].manualFolders = groups[groupId].manualFolders or {}
        if kind == "M" then
          groups[groupId].manualFolders[folder] = true
        else
          groups[groupId].folders[folder] = true
        end
      else return nil, nil, false end
    end
  end
  for groupId, group in pairs(groups) do
    if not group.root or group.root == "" then groups[groupId] = nil end
  end
  for _, item in pairs(originals) do
    if item.group and not groups[item.group] then return nil, nil, false end
  end
  return originals, groups, true
end

writeTransaction = function(phase, operation, plans)
  local lines = { "V\t1", "H\t" .. phase .. "\t" .. operation }
  for _, plan in ipairs(plans or {}) do
    if operation == "rename" then
      if not validRelativePath(plan.storage or "")
          or not validRelativePath(plan.destinationStorage or "")
          or not validRelativePath(plan.name or "") then return false end
      table.insert(lines, "R\t" .. catalogEncode(plan.storage) .. "\t" ..
        catalogEncode(plan.destinationStorage) .. "\t" .. catalogEncode(plan.name))
    else
      if not validRelativePath(plan.storage or "")
          or not validTrashFilename(plan.trashFilename)
          or not validRelativePath(plan.recoveryName or plan.name or "") then return false end
      table.insert(lines, "P\t" .. catalogEncode(plan.storage) .. "\t" ..
        catalogEncode(plan.trashFilename) .. "\t" ..
        catalogEncode(plan.recoveryName or plan.name))
    end
  end
  for folder in pairs((plans or {}).recoveryFolders or {}) do
    if not validRelativePath(folder) then return false end
    table.insert(lines, "D\t" .. catalogEncode(folder) .. "\t" ..
      ((plans.recoveryManualFolders or {})[folder] and "1" or "0"))
  end
  if #lines > MAX_TRANSACTION_LINES then return false end
  local result = writeLinesIfChanged(
    TRANSACTION_FILE, lines, "transaction journal", MAX_TRANSACTION_BYTES)
  return result == true
end

local function readTransaction()
  local contents, readError = readBoundedFile(TRANSACTION_FILE, MAX_TRANSACTION_BYTES)
  if not contents then return nil, readError == "missing" and "missing" or "invalid" end
  local transaction = { plans = {}, recoveryFolders = {}, recoveryManualFolders = {} }
  local lineCount = 0
  for line in (contents .. "\n"):gmatch("(.-)\n") do
    if line ~= "" then
      lineCount = lineCount + 1
      if lineCount > MAX_TRANSACTION_LINES then return nil, "invalid" end
      local phase, operation = line:match("^H\t([^\t]+)\t([^\t]+)$")
      if phase then
        transaction.phase, transaction.operation = phase, operation
      else
        local storage, filename, name = line:match("^P\t([^\t]+)\t([^\t]+)\t([^\t]+)$")
        if storage then
          storage, filename, name = catalogDecode(storage), catalogDecode(filename), catalogDecode(name)
          if not validRelativePath(storage) or not validTrashFilename(filename)
              or not validRelativePath(name) then return nil, "invalid" end
          table.insert(transaction.plans, {
            storage = storage, trashFilename = filename, name = name,
          })
        else
          local oldStorage, newStorage, name = line:match("^R\t([^\t]+)\t([^\t]+)\t([^\t]+)$")
          if oldStorage then
            oldStorage, newStorage, name = catalogDecode(oldStorage),
              catalogDecode(newStorage), catalogDecode(name)
            if not validRelativePath(oldStorage) or not validRelativePath(newStorage)
                or not validRelativePath(name) then return nil, "invalid" end
            table.insert(transaction.plans, {
              storage = oldStorage, destinationStorage = newStorage, name = name,
            })
          else
            local folder, manual = line:match("^D\t([^\t]+)\t([01])$")
            if folder then
              folder = catalogDecode(folder)
              if not validRelativePath(folder) then return nil, "invalid" end
              transaction.recoveryFolders[folder] = true
              if manual == "1" then transaction.recoveryManualFolders[folder] = true end
            elseif line ~= "V\t1" then
              return nil, "invalid"
            end
          end
        end
      end
    end
  end
  if (transaction.phase ~= "prepared" and transaction.phase ~= "committed")
      or (transaction.operation ~= "trash" and transaction.operation ~= "restore"
        and transaction.operation ~= "rename")
      or #transaction.plans == 0 then return nil, "invalid" end
  return transaction
end

completeTransaction = function(operation, plans)
  if not writeTransaction("committed", operation, plans) then return false end
  return os.remove(TRANSACTION_FILE) ~= nil or not fileExists(TRANSACTION_FILE)
end

recoverTransaction = function()
  local transaction, transactionError = readTransaction()
  if not transaction then
    if transactionError ~= "missing" then
      log("[RECOVERY] Transaction journal is invalid; preset scanning was stopped.", "error")
      return false, {}, {}, {}, {}
    end
    return true, {}, {}, {}, {}
  end
  if transaction.phase == "committed" then
    local removed = os.remove(TRANSACTION_FILE) ~= nil or not fileExists(TRANSACTION_FILE)
    log(removed and "[RECOVERY] Completed transaction journal cleanup."
      or "[RECOVERY] The committed transaction is safe, but its journal could not be removed; cleanup will retry next startup.",
      removed and "info" or "warn")
    return true, {}, {}, {}, {}
  end
  local recoveredOriginals, recoveredAssignments, recovered = {}, {}, true
  for _, plan in ipairs(transaction.plans) do
    local mainPath = PRESET_DIR .. "/" .. plan.storage .. ".preset"
    local trashPath = plan.trashFilename and (TRASH_DIR .. "/" .. plan.trashFilename) or nil
    local renamedPath = plan.destinationStorage
      and (PRESET_DIR .. "/" .. plan.destinationStorage .. ".preset") or nil
    local rollbackSource = transaction.operation == "trash" and trashPath
      or transaction.operation == "restore" and mainPath or renamedPath
    local rollbackDestination = transaction.operation == "trash" and mainPath
      or transaction.operation == "restore" and trashPath or mainPath
    if fileExists(rollbackSource) and not fileExists(rollbackDestination) then
      if not os.rename(rollbackSource, rollbackDestination) then recovered = false end
    elseif not fileExists(rollbackSource) and not fileExists(rollbackDestination) then
      recovered = false
    end
    if trashPath and fileExists(trashPath) then
      recoveredOriginals[plan.trashFilename] = { original = plan.name }
    end
    if transaction.operation == "trash" or transaction.operation == "rename" then
      recoveredAssignments[plan.storage] = plan.name
    end
  end
  if recovered then os.remove(TRANSACTION_FILE) end
  log("[RECOVERY] Unfinished " .. transaction.operation .. " transaction " ..
    (recovered and "was rolled back." or "could not be fully rolled back; it will be retried."),
    recovered and "warn" or "error")
  return recovered, recoveredOriginals, recoveredAssignments,
    transaction.recoveryFolders, transaction.recoveryManualFolders
end

refreshTrash = function(recoveredOriginals)
  local originals, groups, catalogOk = readTrashCatalog()
  if not catalogOk then
    log("[TRASH] Trash catalog is unreadable, unsafe, or exceeds its limits; previous Trash state was retained.", "error")
    return false
  end
  for filename, item in pairs(recoveredOriginals or {}) do originals[filename] = item end
  local trash = {}
  local entries = safeDirectoryEntries(TRASH_DIR, 0)
  for _, entry in ipairs(entries or {}) do
    if entry.type == "file" and entry.name:lower():sub(-7) == ".preset" then
      local preset = readPresetFile(TRASH_DIR .. "/" .. entry.name)
      if preset then
        local catalogItem = originals[entry.name]
        trash[entry.name] = {
          original = catalogItem and catalogItem.original or entry.name:sub(1, -8),
          group = catalogItem and catalogItem.group or nil,
          preset = preset,
        }
      end
    end
  end
  state.trash = trash
  state.trashGroups = groups
  if not writeTrashCatalog(trash, groups) then return false end
  return true
end

local function uniqueTrashFilename(name, reserved)
  local leaf = sanitizeName(baseName(name))
  for index = 1, 9999 do
    local suffix = index == 1 and "" or (" %d"):format(index)
    local candidate = leaf:sub(1, 64 - #suffix) .. suffix .. ".preset"
    if not state.trash[candidate] and not (reserved or {})[candidate]
        and not fileExists(TRASH_DIR .. "/" .. candidate) then
      return candidate
    end
  end
  return nil
end

trashPreset = function()
  auditSection("TRASH PRESET")
  log(("[PRESET] Trash requested: selected='%s' confirmed=%s")
    :format(tostring(state.selected),
      tostring(state.pendingDeleteName == state.selected)), "info")
  if not state.selected then return end
  local old = state.selected
  local preset = state.presets[old]
  if not preset then
    setStatus("delete", "The selected preset is no longer available.", true)
    return
  end
  local currentFingerprint = fileFingerprint(presetPath(old))
  if not currentFingerprint then
    cancelConfirmations()
    setStatus("delete", "The selected preset file could not be verified safely.", true)
    return
  end
  if state.pendingDeleteName ~= old then
    state.pendingDeleteName = old
    state.pendingDeleteFingerprint = currentFingerprint
    setStatus("delete", ("Move \"%s\" to Trash? Select Confirm Move to Trash.")
      :format(old))
    return
  end
  if state.pendingDeleteFingerprint ~= currentFingerprint then
    cancelConfirmations()
    setStatus("delete", "The preset changed after confirmation. Review it and start deletion again.", true)
    return
  end
  state.pendingDeleteName = nil
  state.pendingDeleteFingerprint = nil

  local oldPath = presetPath(old)
  local trashFilename = uniqueTrashFilename(old)
  if not trashFilename then
    setStatus("delete", "A safe Trash filename could not be allocated.", true)
    return
  end
  local trashPath = TRASH_DIR .. "/" .. trashFilename
  local plan = {
    storage = preset.storage,
    trashFilename = trashFilename,
    name = old,
  }
  if not writeTransaction("prepared", "trash", { plan }) then
    setStatus("delete", "The Trash recovery journal could not be created.", true)
    return
  end
  local moved, moveError = os.rename(oldPath, trashPath)
  if not moved then
    os.remove(TRANSACTION_FILE)
    setStatus("delete", ("Could not move \"%s\" to Trash: %s")
      :format(old, tostring(moveError)), true)
    return
  end
  state.presets[old] = nil
  state.trash[trashFilename] = { original = old, preset = preset }
  local catalogsSaved = writeCatalog(state.presets, state.folders, state.manualFolders,
      state.ignoredPhysicalFolders) and writeTrashCatalog(state.trash)
  local transactionCompleted = catalogsSaved and completeTransaction("trash", { plan })
  if not transactionCompleted then
    state.presets[old] = preset
    state.trash[trashFilename] = nil
    local restored = os.rename(trashPath, oldPath) ~= nil
    writeCatalog(state.presets, state.folders, state.manualFolders,
      state.ignoredPhysicalFolders)
    writeTrashCatalog(state.trash)
    if restored then os.remove(TRANSACTION_FILE) end
    setStatus("delete", restored
      and "The Trash operation was rolled back because its catalogs or recovery journal could not be finalized."
      or "The Trash operation failed, and the preset file could not be restored.", true)
    return
  end
  state.selected = nil
  state.presetNotes = ""
  state.presetTags = ""
  invalidateViewCache()
  state.renameName = ""
  resetLoadState()
  state.renameStatus = ""
  state.renameStatusError = false
  if writeInventory(state.presets, state.folders) then
    setStatus("delete", "Moved \"" .. old .. "\" to Trash.")
  else
    setStatus("delete", "Moved \"" .. old .. "\" to Trash, but the inventory could not be updated.",
      false, "warning")
  end
end

restoreTrashPreset = function(filename)
  local item = state.trash[filename]
  if not item then setStatus("delete", "The Trash item is no longer available.", true); return end
  local logicalName = item.original
  if findPresetCollision(logicalName) then
    logicalName = uniquePresetCopyName(logicalName)
  end
  if not logicalName then
    setStatus("delete", "A unique restored preset name could not be allocated.", true); return
  end
  local storage = uniqueStorageName(baseName(logicalName))
  if not storage then
    setStatus("delete", "A safe restored filename could not be allocated.", true); return
  end
  local sourcePath = TRASH_DIR .. "/" .. filename
  local destinationPath = PRESET_DIR .. "/" .. storage .. ".preset"
  local plan = {
    storage = storage, trashFilename = filename, name = logicalName,
    recoveryName = item.original,
  }
  if not writeTransaction("prepared", "restore", { plan }) then
    setStatus("delete", "The restore recovery journal could not be created.", true); return
  end
  local moved, moveError = os.rename(sourcePath, destinationPath)
  if not moved then
    os.remove(TRANSACTION_FILE)
    setStatus("delete", "The preset could not be restored: " .. tostring(moveError), true); return
  end
  local preset = readPresetFile(destinationPath)
  if not preset then
    os.rename(destinationPath, sourcePath)
    os.remove(TRANSACTION_FILE)
    setStatus("delete", "The restored preset could not be verified.", true); return
  end
  preset.storage = storage
  local previousFolders = cloneMap(state.folders)
  state.presets[logicalName] = preset
  addFolderAncestors(state.folders, parentFolder(logicalName))
  state.trash[filename] = nil
  local catalogsSaved = writeCatalog(state.presets, state.folders, state.manualFolders,
      state.ignoredPhysicalFolders) and writeTrashCatalog(state.trash)
  local transactionCompleted = catalogsSaved and completeTransaction("restore", { plan })
  if not transactionCompleted then
    state.presets[logicalName] = nil
    state.folders = previousFolders
    state.trash[filename] = item
    local restored = os.rename(destinationPath, sourcePath) ~= nil
    writeCatalog(state.presets, state.folders, state.manualFolders,
      state.ignoredPhysicalFolders)
    writeTrashCatalog(state.trash)
    if restored then os.remove(TRANSACTION_FILE) end
    setStatus("delete", restored
      and "Restore was rolled back because its catalogs or recovery journal could not be finalized."
      or "Restore could not be finalized or rolled back; startup recovery will retry it.", true)
    return
  end
  state.selected = logicalName
  state.presetNotes = preset.notes or ""
  state.presetTags = preset.tags or ""
  invalidateViewCache()
  local inventorySaved = writeInventory(state.presets, state.folders)
  setStatus("delete", "Restored \"" .. logicalName .. "\" from Trash." ..
    (inventorySaved and "" or " The inventory could not be updated."), false,
    inventorySaved and "success" or "warning")
end

local function allocateRestoreLogicalName(original, reserved)
  if not reserved[original:lower()] and not findPresetCollision(original) then
    reserved[original:lower()] = true
    return original
  end
  local folder, leaf = parentFolder(original), baseName(original)
  for index = 1, 999 do
    local suffix = index == 1 and " Copy" or (" Copy %d"):format(index)
    local candidate = joinFolder(folder, leaf:sub(1, 64 - #suffix) .. suffix)
    if not reserved[candidate:lower()] and not findPresetCollision(candidate) then
      reserved[candidate:lower()] = true
      return candidate
    end
  end
  return nil
end

restoreTrashGroup = function(groupId)
  local group = state.trashGroups[groupId]
  if not group then
    setStatus("delete", "The trashed folder group is no longer available.", true); return
  end
  local filenames = {}
  for filename, item in pairs(state.trash) do
    if item.group == groupId then table.insert(filenames, filename) end
  end
  table.sort(filenames, function(a, b) return a:lower() < b:lower() end)
  local reservedLogical, reservedStorage = {}, storageFilenamesInUse()
  if not reservedStorage then
    setStatus("delete", "Storage filenames could not be checked safely.", true); return
  end
  for name in pairs(state.presets) do reservedLogical[name:lower()] = true end
  local plans = {}
  for _, filename in ipairs(filenames) do
    local item = state.trash[filename]
    local logicalName = allocateRestoreLogicalName(item.original, reservedLogical)
    local storage = logicalName and uniqueStorageName(baseName(logicalName), reservedStorage)
    if not logicalName or not storage then
      setStatus("delete", "A safe name could not be allocated for every folder preset.", true); return
    end
    table.insert(plans, {
      filename = filename,
      trashFilename = filename,
      name = logicalName,
      recoveryName = item.original,
      storage = storage,
      item = item,
      source = TRASH_DIR .. "/" .. filename,
      destination = PRESET_DIR .. "/" .. storage .. ".preset",
    })
  end

  if #plans > 0 and not writeTransaction("prepared", "restore", plans) then
    setStatus("delete", "The folder restore recovery journal could not be created.", true); return
  end
  local moved = {}
  for _, plan in ipairs(plans) do
    if not os.rename(plan.source, plan.destination) then
      local rollbackFailed = false
      for index = #moved, 1, -1 do
        local item = moved[index]
        if not os.rename(item.destination, item.source) then rollbackFailed = true end
      end
      if not rollbackFailed then os.remove(TRANSACTION_FILE) end
      setStatus("delete", rollbackFailed
        and "Folder restore stopped and could not fully roll back; startup recovery will retry it."
        or "Folder restore stopped before all preset files could be moved.", true)
      return
    end
    local verified = readPresetFile(plan.destination)
    if not verified or not presetsMatch(plan.item.preset, verified) then
      table.insert(moved, plan)
      local rollbackFailed = false
      for index = #moved, 1, -1 do
        local item = moved[index]
        if not os.rename(item.destination, item.source) then rollbackFailed = true end
      end
      if not rollbackFailed then os.remove(TRANSACTION_FILE) end
      setStatus("delete", rollbackFailed
        and "Folder restore verification failed and could not fully roll back; startup recovery will retry it."
        or "Folder restore verification failed; moved files were returned to Trash.", true)
      return
    end
    plan.preset = verified
    table.insert(moved, plan)
  end

  local newPresets, newFolders = cloneMap(state.presets), cloneMap(state.folders)
  local newTrash, newGroups = cloneMap(state.trash), cloneMap(state.trashGroups)
  local newManualFolders = cloneMap(state.manualFolders)
  local newIgnored = cloneMap(state.ignoredPhysicalFolders)
  for folder in pairs(group.folders or {}) do addFolderAncestors(newFolders, folder) end
  for folder in pairs(group.manualFolders or {}) do
    newManualFolders[folder] = true
    newIgnored[folder] = nil
  end
  addFolderAncestors(newFolders, group.root)
  for _, plan in ipairs(plans) do
    plan.preset.storage = plan.storage
    newPresets[plan.name] = plan.preset
    newTrash[plan.filename] = nil
    addFolderAncestors(newFolders, parentFolder(plan.name))
  end
  newGroups[groupId] = nil
  local catalogsSaved = writeCatalog(newPresets, newFolders, newManualFolders,
      newIgnored) and writeTrashCatalog(newTrash, newGroups)
  local transactionCompleted = #plans == 0 or
    (catalogsSaved and completeTransaction("restore", plans))
  if #plans == 0 then transactionCompleted = catalogsSaved end
  if not transactionCompleted then
    local rollbackFailed = false
    for index = #moved, 1, -1 do
      local plan = moved[index]
      if not os.rename(plan.destination, plan.source) then rollbackFailed = true end
    end
    writeCatalog(state.presets, state.folders, state.manualFolders,
      state.ignoredPhysicalFolders)
    writeTrashCatalog(state.trash, state.trashGroups)
    if not rollbackFailed then os.remove(TRANSACTION_FILE) end
    setStatus("delete", rollbackFailed
      and "Folder restore could not be finalized or fully rolled back; startup recovery will retry it."
      or "Folder restore was rolled back because its catalogs could not be finalized.", true)
    return
  end

  state.presets, state.folders = newPresets, newFolders
  state.trash, state.trashGroups = newTrash, newGroups
  state.manualFolders, state.ignoredPhysicalFolders = newManualFolders, newIgnored
  if plans[1] then
    state.selected = plans[1].name
    state.presetNotes = plans[1].preset.notes or ""
    state.presetTags = plans[1].preset.tags or ""
  end
  invalidateViewCache()
  resetLoadState()
  local inventorySaved = writeInventory(newPresets, newFolders)
  setStatus("delete", ("Restored folder \"%s\" with %d preset%s, including empty virtual folders.")
    :format(group.root, #plans, #plans == 1 and "" or "s") ..
    (inventorySaved and "" or " The inventory could not be updated."), false,
    inventorySaved and "success" or "warning")
end

emptyTrash = function()
  local count = 0
  for _ in pairs(state.trash) do count = count + 1 end
  local groupCount = 0
  for _ in pairs(state.trashGroups) do groupCount = groupCount + 1 end
  if count == 0 and groupCount == 0 then setStatus("delete", "Trash is already empty."); return end
  if not state.pendingEmptyTrash then
    cancelConfirmations()
    state.pendingEmptyTrash = true
    setStatus("delete", ("Permanently delete %d trashed preset%s and %d folder recovery record%s? Select Empty Trash Permanently again.")
      :format(count, count == 1 and "" or "s", groupCount,
        groupCount == 1 and "" or "s"))
    return
  end
  state.pendingEmptyTrash = false
  local failed = 0
  for filename in pairs(state.trash) do
    if os.remove(TRASH_DIR .. "/" .. filename) then
      state.trash[filename] = nil
    else
      failed = failed + 1
    end
  end
  if failed == 0 then state.trashGroups = {} end
  local catalogSaved = writeTrashCatalog(state.trash, state.trashGroups)
  if failed > 0 then
    setStatus("delete", ("Trash cleanup stopped with %d file%s remaining.")
      :format(failed, failed == 1 and "" or "s"), true)
  elseif not catalogSaved then
    setStatus("delete", "Trash was emptied, but its catalog could not be updated.", true)
  else
    setStatus("delete", "Trash emptied permanently.")
  end
end

bulkPresetNamesInFolder = function(folder)
  ensureViewCache()
  if state.cachedBulkFolder == folder then return state.cachedBulkFolderNames end
  local names = {}
  for _, name in ipairs(state.cachedPresetNames) do
    if isInFolderTree(parentFolder(name), folder) then table.insert(names, name) end
  end
  local nestedFolderCount = 0
  for candidate in pairs(state.folders) do
    if candidate ~= folder and isInFolderTree(candidate, folder) then
      nestedFolderCount = nestedFolderCount + 1
    end
  end
  state.cachedBulkFolder = folder
  state.cachedBulkFolderNames = names
  state.cachedBulkNestedFolderCount = nestedFolderCount
  return names
end

selectedBulkPresetNames = function()
  if not state.bulkSelectionDirty then return state.cachedBulkSelectedNames end
  local names = {}
  for name in pairs(state.bulkSelected) do
    if state.presets[name] then table.insert(names, name) end
  end
  table.sort(names, function(a, b) return a:lower() < b:lower() end)
  state.cachedBulkSelectedNames = names
  state.bulkSelectionDirty = false
  return names
end

local function bulkTrashFingerprint(names, folder)
  local parts = { "folder:" .. tostring(folder or "") }
  for _, name in ipairs(names) do
    local preset = state.presets[name]
    if not preset then return nil, "A selected preset is no longer available." end
    local fingerprint = fileFingerprint(presetPath(name))
    if not fingerprint then
      return nil, ("The preset \"%s\" could not be verified safely."):format(name)
    end
    table.insert(parts, "preset:" .. name .. ":" .. fingerprint)
  end
  if folder then
    for candidate in pairs(state.folders) do
      if isInFolderTree(candidate, folder) then table.insert(parts, "folder:" .. candidate) end
    end
  end
  table.sort(parts)
  return table.concat(parts, "\30")
end

local function moveBulkPresetsToTrash(names, folder)
  local physicalFolderWasImported = folder and state.manualFolders[folder] == true
  local reserved, plans = {}, {}
  for _, name in ipairs(names) do
    local preset = state.presets[name]
    local trashFilename = uniqueTrashFilename(name, reserved)
    if not preset or not trashFilename then
      setStatus("bulk", "A safe Trash filename could not be allocated.", true)
      return false
    end
    reserved[trashFilename] = true
    table.insert(plans, {
      name = name,
      preset = preset,
      storage = preset.storage,
      source = presetPath(name),
      destination = TRASH_DIR .. "/" .. trashFilename,
      trashFilename = trashFilename,
    })
  end

  if folder then
    plans.recoveryFolders, plans.recoveryManualFolders = {}, {}
    for candidate in pairs(state.folders) do
      if isInFolderTree(candidate, folder) then
        plans.recoveryFolders[candidate] = true
        if state.manualFolders[candidate] then
          plans.recoveryManualFolders[candidate] = true
        end
      end
    end
  end

  if not writeTransaction("prepared", "trash", plans) then
    setStatus("bulk", "The Bulk Trash recovery journal could not be created.", true)
    return false
  end

  local moved = {}
  for _, plan in ipairs(plans) do
    local movedFile, moveError = os.rename(plan.source, plan.destination)
    if not movedFile then
      local rollbackFailed = false
      for index = #moved, 1, -1 do
        local item = moved[index]
        if not os.rename(item.destination, item.source) then rollbackFailed = true end
      end
      if rollbackFailed then
        refreshPresets("bulk-recovery")
        refreshTrash()
      else
        os.remove(TRANSACTION_FILE)
      end
      setStatus("bulk", rollbackFailed
        and "Bulk Trash failed, and at least one moved preset could not be restored. Refresh completed; review Trash."
        or ("Bulk Trash stopped at \"%s\": %s"):format(plan.name, tostring(moveError)), true)
      return false
    end
    table.insert(moved, plan)
  end

  local newPresets = cloneMap(state.presets)
  local newTrash = cloneMap(state.trash)
  local newTrashGroups = cloneMap(state.trashGroups)
  local newFolders = cloneMap(state.folders)
  local newManualFolders = cloneMap(state.manualFolders)
  local newIgnored = cloneMap(state.ignoredPhysicalFolders)
  local nestedFolderCount = 0
  local groupId = folder and plans[1].trashFilename or nil
  if groupId then
    newTrashGroups[groupId] = { root = folder, folders = {}, manualFolders = {} }
  end
  if folder then
    for candidate in pairs(state.folders) do
      if isInFolderTree(candidate, folder) then
        newTrashGroups[groupId].folders[candidate] = true
        if state.manualFolders[candidate] then
          newTrashGroups[groupId].manualFolders[candidate] = true
        end
        if candidate ~= folder then nestedFolderCount = nestedFolderCount + 1 end
      end
    end
  end
  for _, plan in ipairs(plans) do
    newPresets[plan.name] = nil
    newTrash[plan.trashFilename] = {
      original = plan.name, preset = plan.preset, group = groupId,
    }
  end
  if folder then
    newFolders, newManualFolders = {}, {}
    for candidate in pairs(state.folders) do
      if not isInFolderTree(candidate, folder) then
        newFolders[candidate] = true
        if state.manualFolders[candidate] then newManualFolders[candidate] = true end
      elseif state.manualFolders[candidate] then
        newIgnored[candidate] = true
      end
    end
  end

  local catalogsSaved = writeCatalog(newPresets, newFolders, newManualFolders, newIgnored)
    and writeTrashCatalog(newTrash, newTrashGroups)
  local transactionCompleted = catalogsSaved and completeTransaction("trash", plans)
  if not transactionCompleted then
    local rollbackFailed = false
    for index = #moved, 1, -1 do
      local plan = moved[index]
      if not os.rename(plan.destination, plan.source) then rollbackFailed = true end
    end
    if rollbackFailed then
      refreshPresets("bulk-recovery")
      refreshTrash()
    else
      writeCatalog(state.presets, state.folders, state.manualFolders,
        state.ignoredPhysicalFolders)
      writeTrashCatalog(state.trash, state.trashGroups)
      os.remove(TRANSACTION_FILE)
    end
    setStatus("bulk", rollbackFailed
      and "Bulk Trash cataloging failed, and at least one preset could not be moved back. Refresh completed; review Trash."
      or "Bulk Trash was rolled back because its catalogs or recovery journal could not be finalized.", true)
    return false
  end

  state.presets, state.trash = newPresets, newTrash
  state.trashGroups = newTrashGroups
  state.folders, state.manualFolders = newFolders, newManualFolders
  state.ignoredPhysicalFolders = newIgnored
  if state.selected and not newPresets[state.selected] then
    state.selected = nil
    state.presetNotes, state.presetTags = "", ""
  end
  if folder then
    local destination = parentFolder(folder)
    state.selectedFolder = newFolders[destination] and destination or ""
  end
  for _, name in ipairs(names) do state.bulkSelected[name] = nil end
  invalidateViewCache()
  resetLoadState()
  cancelConfirmations()
  local inventorySaved = writeInventory(newPresets, newFolders)
  local physicalFolderRemoved = false
  if physicalFolderWasImported
      and directoryTreeContainsFiles(folderPath(folder), 0) == false then
    physicalFolderRemoved = removeEmptyDirectoryTree(folderPath(folder), 0)
  end
  setStatus("bulk", (folder
    and ("Moved folder \"%s\" and %d preset%s to recoverable Trash; removed %d nested folder entr%s. Restoring presets rebuilds their folder paths.%s")
      :format(folder, #names, #names == 1 and "" or "s", nestedFolderCount,
        nestedFolderCount == 1 and "y" or "ies",
        physicalFolderWasImported and (physicalFolderRemoved
          and " Its empty physical directory was removed."
          or " Its physical directory was kept because other content remains or it could not be removed safely.") or "")
    or ("Moved %d preset%s to recoverable Trash.")
      :format(#names, #names == 1 and "" or "s")) ..
    (inventorySaved and "" or " The inventory could not be updated."), false,
    inventorySaved and "success" or "warning")
  return true
end

requestBulkTrash = function(names, folder)
  if #names == 0 then
    setStatus("bulk", folder
      and "The selected folder contains no presets. Use Remove Folder, Keep Presets."
      or "Select at least one preset for the bulk action.", true)
    return
  end
  local fingerprint, fingerprintError = bulkTrashFingerprint(names, folder)
  if not fingerprint then setStatus("bulk", fingerprintError, true); return end
  local action = folder and ("folder:" .. folder) or "presets"
  if state.pendingBulkAction ~= action
      or state.pendingBulkFingerprint ~= fingerprint then
    state.pendingBulkAction = action
    state.pendingBulkFingerprint = fingerprint
    setStatus("bulk", folder
      and ("Move folder \"%s\" and %d preset%s to recoverable Trash? Select Confirm Move Folder & Presets to Trash.")
        :format(folder, #names, #names == 1 and "" or "s")
      or ("Move %d selected preset%s to recoverable Trash? Select Confirm Bulk Trash.")
        :format(#names, #names == 1 and "" or "s"))
    return
  end
  moveBulkPresetsToTrash(names, folder)
end

end

local function remapFolderTreePath(path, source, destination)
  if path == source then return destination end
  if path:sub(1, #source + 1) == source .. "/" then
    return destination .. path:sub(#source + 1)
  end
  return path
end

local function persistVirtualState(presets, folders, manualFolders, ignoredPhysicalFolders)
  if not writeCatalog(presets, folders, manualFolders, ignoredPhysicalFolders) then
    return false
  end
  writeInventory(presets, folders)
  return true
end

local function renamePreset()
  auditSection("RENAME PRESET")
  if not state.selected or not state.presets[state.selected] then
    setStatus("rename", "Select a preset before renaming it.", true)
    return
  end
  local newLeafName, nameError = validatedPresetName(state.renameName)
  if not newLeafName then setStatus("rename", nameError, true); return end
  local old = state.selected
  local newName = joinFolder(parentFolder(old), newLeafName)
  if newName == old then setStatus("rename", "The preset already has this name."); return end
  if newName:lower() == old:lower() then
    setStatus("rename", "Preset names cannot differ only by capitalization.", true)
    return
  end
  local collision = findPresetCollision(newName, old)
  if collision then
    setStatus("rename", ("A preset named \"%s\" already exists."):format(collision), true)
    return
  end
  local preset = state.presets[old]
  local oldStorage = preset.storage
  local newStorage = joinFolder(parentFolder(oldStorage), newLeafName)
  local oldPath = PRESET_DIR .. "/" .. oldStorage .. ".preset"
  local newPath = PRESET_DIR .. "/" .. newStorage .. ".preset"
  local physicalRenameNeeded = newStorage ~= oldStorage
  if physicalRenameNeeded and fileExists(newPath) then
    setStatus("rename", "A shareable preset file with that name already exists.", true)
    return
  end
  local renamePlan = {
    storage = oldStorage,
    destinationStorage = newStorage,
    name = old,
  }
  if physicalRenameNeeded then
    if not writeTransaction("prepared", "rename", { renamePlan }) then
      setStatus("rename", "The rename recovery journal could not be created.", true)
      return
    end
    local renamed, renameError = os.rename(oldPath, newPath)
    if not renamed then
      os.remove(TRANSACTION_FILE)
      setStatus("rename", "The shareable preset file could not be renamed: " ..
        tostring(renameError), true)
      return
    end
    preset.storage = newStorage
  end
  state.presets[old] = nil
  state.presets[newName] = preset
  local persisted = persistVirtualState(state.presets, state.folders, state.manualFolders,
      state.ignoredPhysicalFolders)
  local transactionCompleted = persisted and (not physicalRenameNeeded
    or completeTransaction("rename", { renamePlan }))
  if not transactionCompleted then
    state.presets[newName] = nil
    state.presets[old] = preset
    if physicalRenameNeeded then
      local rolledBack = os.rename(newPath, oldPath) ~= nil
      preset.storage = rolledBack and oldStorage or newStorage
      if not rolledBack then
        local repaired = writeCatalog(state.presets, state.folders, state.manualFolders,
          state.ignoredPhysicalFolders)
        setStatus("rename", repaired
          and "The display rename failed, and the physical file could not be moved back. The catalog now tracks the new physical filename."
          or "The display rename failed, the physical file could not be moved back, and the catalog could not be repaired.", true)
        return
      end
      os.remove(TRANSACTION_FILE)
    end
    if persisted then
      writeCatalog(state.presets, state.folders, state.manualFolders,
        state.ignoredPhysicalFolders)
      writeInventory(state.presets, state.folders)
    end
    setStatus("rename", "The preset could not be renamed because its catalog or recovery journal could not be finalized.", true)
    return
  end
  state.selected = newName
  invalidateViewCache()
  state.renameName = ""
  cancelConfirmations()
  resetLoadState()
  setStatus("rename", "Renamed \"" .. old .. "\" to \"" .. newName .. "\".")
  log(("[PRESET] Display and physical rename completed: '%s' -> '%s' storage='%s'.")
    :format(old, newName, preset.storage), "complete")
end

local function movePresetToSelectedFolder()
  auditSection("MOVE PRESET")
  if not state.selected or not state.presets[state.selected] then
    state.folderStatus, state.folderStatusError = "Select a preset before moving it.", true; return
  end
  local old = state.selected
  local newName = joinFolder(state.selectedFolder, baseName(old))
  if newName == old then
    state.folderStatus, state.folderStatusError = "The preset is already in the selected folder.", false; return
  end
  local collision = findPresetCollision(newName, old)
  if collision then
    state.folderStatus, state.folderStatusError =
      ("A preset named \"%s\" already exists there."):format(baseName(collision)), true; return
  end
  local preset = state.presets[old]
  state.presets[old] = nil
  state.presets[newName] = preset
  if not persistVirtualState(state.presets, state.folders, state.manualFolders,
      state.ignoredPhysicalFolders) then
    state.presets[newName] = nil
    state.presets[old] = preset
    state.folderStatus, state.folderStatusError =
      "The preset could not be moved because the virtual-folder catalog could not be saved.", true; return
  end
  state.selected = newName
  invalidateViewCache()
  cancelConfirmations()
  resetLoadState()
  state.folderStatus, state.folderStatusError =
    ("Moved \"%s\" to %s."):format(baseName(newName),
      state.selectedFolder == "" and "All Presets" or state.selectedFolder), false
  log(("[PRESET] Virtual move completed: '%s' -> '%s' storage='%s'.")
    :format(old, newName, preset.storage), "complete")
end

local function savePresetMetadata()
  if not state.selected or not state.presets[state.selected] then
    setStatus("rename", "Select a preset before saving its details.", true); return
  end
  local preset = state.presets[state.selected]
  local previousNotes, previousTags = preset.notes, preset.tags
  local previousModified, previousFormat = preset.modified, preset.format
  local previousSource = preset.source
  preset.notes = sanitizeMetadata(state.presetNotes, 512)
  preset.tags = sanitizeMetadata(state.presetTags, 128)
  preset.modified = logTimestamp()
  preset.created = preset.created or preset.modified
  preset.source = MOD_NAME
  preset.format = 5
  if not writePresetPath(presetPath(state.selected), preset) then
    preset.notes, preset.tags = previousNotes, previousTags
    preset.modified, preset.format = previousModified, previousFormat
    preset.source = previousSource
    setStatus("rename", "Preset details could not be saved safely.", true)
    return
  end
  state.presetNotes = preset.notes
  state.presetTags = preset.tags
  setStatus("rename", "Saved details for \"" .. state.selected .. "\".")
end

local function duplicatePreset()
  auditSection("DUPLICATE PRESET")
  if not state.selected or not state.presets[state.selected] then
    setStatus("rename", "Select a preset before duplicating it.", true); return
  end
  local source = state.selected
  local destination = uniquePresetCopyName(source)
  if not destination then
    setStatus("rename", "Could not find an available name for the duplicate.", true); return
  end
  local sourcePreset = state.presets[source]
  local storage = uniqueStorageName(baseName(destination))
  if not storage then
    setStatus("rename", "A safe storage filename could not be allocated.", true); return
  end
  local destinationPath = PRESET_DIR .. "/" .. storage .. ".preset"
  if not copyFile(presetPath(source), destinationPath) then
    local cleaned = removeFileList({ destinationPath })
    setStatus("rename", cleaned and "The duplicate could not be written."
      or "The duplicate failed, and its partial file could not be removed.", true); return
  end
  local duplicate = readPresetFile(destinationPath)
  if not duplicate or not presetsMatch(sourcePreset, duplicate) then
    local cleaned = removeFileList({ destinationPath })
    setStatus("rename", cleaned and "The duplicate could not be verified."
      or "Duplicate verification failed, and its file could not be removed.", true); return
  end
  duplicate.storage = storage
  state.presets[destination] = duplicate
  if not persistVirtualState(state.presets, state.folders, state.manualFolders,
      state.ignoredPhysicalFolders) then
    state.presets[destination] = nil
    local cleaned = removeFileList({ destinationPath })
    setStatus("rename", cleaned
      and "The duplicate was removed because the virtual-folder catalog could not be saved."
      or "The catalog failed, and the duplicated file could not be removed.", true)
    return
  end
  state.selected = destination
  invalidateViewCache()
  state.renameName = ""
  cancelConfirmations()
  resetLoadState()
  setStatus("rename", ("Duplicated \"%s\" as \"%s\"."):format(source, destination))
  log(("[PRESET] Duplicate completed: source='%s' destination='%s' storage='%s'.")
    :format(source, destination, storage), "complete")
end

local function createFolder()
  auditSection("CREATE FOLDER")
  local leaf, nameError = validatedFolderName(state.folderName)
  if not leaf then state.folderStatus, state.folderStatusError = nameError, true; return end
  local name = joinFolder(state.selectedFolder, leaf)
  local existing = findExistingFolderName(name)
  if existing then
    state.folderStatus, state.folderStatusError =
      ("A folder named \"%s\" already exists."):format(existing), true; return
  end
  state.folders[name] = true
  state.manualFolders[name] = nil
  if not persistVirtualState(state.presets, state.folders, state.manualFolders,
      state.ignoredPhysicalFolders) then
    state.folders[name] = nil
    state.folderStatus, state.folderStatusError = "The virtual folder could not be saved.", true; return
  end
  state.selectedFolder = name
  invalidateViewCache()
  state.folderName = ""
  cancelConfirmations()
  state.folderStatus, state.folderStatusError = "Created virtual folder \"" .. name .. "\".", false
  log(("[FOLDER] Created virtual folder '%s'."):format(name), "complete")
end

local function renameFolder()
  auditSection("RENAME FOLDER")
  local old = state.selectedFolder
  if old == "" or not state.folders[old] then
    state.folderStatus, state.folderStatusError = "Select a folder to rename.", true; return
  end
  local newLeaf, nameError = validatedFolderName(state.folderRenameName)
  if not newLeaf then state.folderStatus, state.folderStatusError = nameError, true; return end
  local destination = joinFolder(parentFolder(old), newLeaf)
  if destination == old then
    state.folderStatus, state.folderStatusError = "The folder already has this name.", false; return
  end
  if destination:lower() == old:lower() then
    state.folderStatus, state.folderStatusError =
      "Folder names cannot differ only by capitalization.", true; return
  end
  local existing = findExistingFolderName(destination, old)
  if existing then
    state.folderStatus, state.folderStatusError =
      ("A folder named \"%s\" already exists."):format(existing), true; return
  end

  local newPresets, newFolders = {}, {}
  local newManualFolders = {}
  local newIgnored = cloneMap(state.ignoredPhysicalFolders)
  local usedPresetNames = {}
  for name, preset in pairs(state.presets) do
    local mapped = isInFolderTree(parentFolder(name), old)
      and remapFolderTreePath(name, old, destination) or name
    if usedPresetNames[mapped:lower()] then
      state.folderStatus, state.folderStatusError = "The rename would create duplicate preset names.", true; return
    end
    usedPresetNames[mapped:lower()] = true
    newPresets[mapped] = preset
  end
  local usedFolders = {}
  for folder in pairs(state.folders) do
    local mapped = remapFolderTreePath(folder, old, destination)
    if usedFolders[mapped:lower()] then
      state.folderStatus, state.folderStatusError = "The rename would create duplicate folders.", true; return
    end
    usedFolders[mapped:lower()] = true
    newFolders[mapped] = true
    if mapped == folder and state.manualFolders[folder] then
      newManualFolders[mapped] = true
    elseif mapped ~= folder and state.manualFolders[folder] then
      newIgnored[folder] = true
    end
  end
  if not persistVirtualState(newPresets, newFolders, newManualFolders, newIgnored) then
    state.folderStatus, state.folderStatusError = "The folder could not be renamed because the catalog could not be saved.", true; return
  end
  local selectedPreset = state.selected
  if selectedPreset and isInFolderTree(parentFolder(selectedPreset), old) then
    selectedPreset = remapFolderTreePath(selectedPreset, old, destination)
  end
  state.presets = newPresets
  state.folders = newFolders
  state.manualFolders = newManualFolders
  state.ignoredPhysicalFolders = newIgnored
  invalidateViewCache()
  state.selectedFolder = destination
  state.selected = selectedPreset
  state.folderRenameName = ""
  cancelConfirmations()
  resetLoadState()
  state.folderStatus, state.folderStatusError =
    ("Renamed virtual folder \"%s\" to \"%s\"."):format(old, destination), false
  log(("[FOLDER] Virtual rename completed: '%s' -> '%s'."):format(old, destination), "complete")
end

local function duplicateFolder()
  auditSection("DUPLICATE FOLDER")
  local source = state.selectedFolder
  if source == "" or not state.folders[source] then
    state.folderStatus, state.folderStatusError = "Select a folder to duplicate.", true; return
  end
  local destination = uniqueFolderCopyName(source)
  if not destination then
    state.folderStatus, state.folderStatusError = "Could not find an available name for the duplicate folder.", true; return
  end
  local newPresets = cloneMap(state.presets)
  local newFolders = cloneMap(state.folders)
  local newManualFolders = cloneMap(state.manualFolders)
  local reservedStorage = storageFilenamesInUse()
  if not reservedStorage then
    state.folderStatus, state.folderStatusError = "Storage filenames could not be checked safely.", true; return
  end
  local createdFiles = {}
  for folder in pairs(state.folders) do
    if isInFolderTree(folder, source) then
      local mapped = remapFolderTreePath(folder, source, destination)
      newFolders[mapped] = true
      newManualFolders[mapped] = nil
    end
  end
  newFolders[destination] = true
  for name, preset in pairs(state.presets) do
    if isInFolderTree(parentFolder(name), source) then
      local mapped = remapFolderTreePath(name, source, destination)
      if findPresetCollision(mapped) or newPresets[mapped] then
        local cleaned = removeFileList(createdFiles)
        state.folderStatus, state.folderStatusError = cleaned
          and "The copied folder would contain duplicate preset names."
          or "Folder duplication found duplicate names, and some partial files could not be removed.", true; return
      end
      local storage = uniqueStorageName(baseName(mapped), reservedStorage)
      if not storage then
        local cleaned = removeFileList(createdFiles)
        state.folderStatus, state.folderStatusError = cleaned
          and "A safe storage filename could not be allocated."
          or "Storage allocation failed, and some partial files could not be removed.", true; return
      end
      local path = PRESET_DIR .. "/" .. storage .. ".preset"
      if not copyFile(PRESET_DIR .. "/" .. preset.storage .. ".preset", path) then
        table.insert(createdFiles, path)
        local cleaned = removeFileList(createdFiles)
        state.folderStatus, state.folderStatusError = cleaned
          and "Folder duplication failed; partial preset copies were removed."
          or "Folder duplication failed, and some partial files could not be removed.", true; return
      end
      local copy = readPresetFile(path)
      if not copy or not presetsMatch(preset, copy) then
        table.insert(createdFiles, path)
        local cleaned = removeFileList(createdFiles)
        state.folderStatus, state.folderStatusError = cleaned
          and "Folder duplication verification failed; partial copies were removed."
          or "Folder duplication verification failed, and some partial files could not be removed.", true; return
      end
      copy.storage = storage
      newPresets[mapped] = copy
      table.insert(createdFiles, path)
    end
  end
  if not persistVirtualState(newPresets, newFolders, newManualFolders,
      state.ignoredPhysicalFolders) then
    local cleaned = removeFileList(createdFiles)
    state.folderStatus, state.folderStatusError = cleaned
      and "Folder duplication was rolled back because the catalog could not be saved."
      or "The catalog failed, and some duplicated files could not be removed.", true; return
  end
  state.presets = newPresets
  state.folders = newFolders
  state.manualFolders = newManualFolders
  invalidateViewCache()
  state.selectedFolder = destination
  cancelConfirmations()
  state.folderStatus, state.folderStatusError =
    ("Duplicated virtual folder \"%s\" as \"%s\"."):format(source, destination), false
  log(("[FOLDER] Virtual duplicate completed: source='%s' destination='%s' presets=%d.")
    :format(source, destination, #createdFiles), "complete")
end

local function removeVirtualFolder()
  auditSection("REMOVE VIRTUAL FOLDER")
  local folder = state.selectedFolder
  if folder == "" or not state.folders[folder] then
    state.folderStatus, state.folderStatusError = "Select a folder to remove.", true; return
  end
  local destinationParent = parentFolder(folder)
  local wasManualFolder = state.manualFolders[folder] == true
  if state.pendingRemoveFolder ~= folder then
    state.pendingRemoveFolder = folder
    state.folderStatus = ("Remove folder \"%s\" and keep its presets? Its presets and nested folders will move to %s. No preset files will be deleted. Select Confirm Remove Folder, Keep Presets.")
      :format(folder, destinationParent == "" and "All Presets" or ("\"" .. destinationParent .. "\""))
    state.folderStatusError = false
    return
  end
  state.pendingRemoveFolder = nil
  local newPresets, newFolders = {}, {}
  local newManualFolders = {}
  local newIgnored = cloneMap(state.ignoredPhysicalFolders)
  local usedPresets, usedFolders = {}, {}
  for name, preset in pairs(state.presets) do
    local mapped = name
    if isInFolderTree(parentFolder(name), folder) then
      mapped = joinFolder(destinationParent, name:sub(#folder + 2))
    end
    if usedPresets[mapped:lower()] then
      state.folderStatus, state.folderStatusError =
        "The folder cannot be removed because preset names would collide.", true; return
    end
    usedPresets[mapped:lower()] = true
    newPresets[mapped] = preset
  end
  for candidate in pairs(state.folders) do
    if candidate ~= folder then
      local mapped = candidate
      if isInFolderTree(candidate, folder) then
        mapped = joinFolder(destinationParent, candidate:sub(#folder + 2))
      end
      if usedFolders[mapped:lower()] then
        state.folderStatus, state.folderStatusError =
          "The folder cannot be removed because folder names would collide.", true; return
      end
      usedFolders[mapped:lower()] = true
      newFolders[mapped] = true
      if mapped == candidate and state.manualFolders[candidate] then
        newManualFolders[mapped] = true
      elseif mapped ~= candidate and state.manualFolders[candidate] then
        newIgnored[candidate] = true
      end
    elseif state.manualFolders[candidate] then
      newIgnored[candidate] = true
    end
  end
  local relocationPlans = {}
  if wasManualFolder then
    local reservedStorage = storageFilenamesInUse()
    if not reservedStorage then
      state.folderStatus, state.folderStatusError =
        "The imported folder could not be inspected safely.", true; return
    end
    for logicalName, preset in pairs(state.presets) do
      local storageFolder = parentFolder(preset.storage or "")
      if storageFolder ~= "" and isInFolderTree(storageFolder, folder) then
        local destinationStorage = uniqueStorageName(baseName(preset.storage), reservedStorage)
        if not destinationStorage then
          state.folderStatus, state.folderStatusError =
            "A safe destination filename could not be allocated for an imported preset.", true; return
        end
        table.insert(relocationPlans, {
          storage = preset.storage,
          destinationStorage = destinationStorage,
          name = logicalName,
          preset = preset,
        })
      end
    end
  end
  table.sort(relocationPlans, function(a, b)
    return a.storage:lower() < b.storage:lower()
  end)
  if #relocationPlans > 0
      and not writeTransaction("prepared", "rename", relocationPlans) then
    state.folderStatus, state.folderStatusError =
      "The imported-folder recovery journal could not be created.", true; return
  end
  local movedPlans = {}
  for _, plan in ipairs(relocationPlans) do
    local sourcePath = PRESET_DIR .. "/" .. plan.storage .. ".preset"
    local destinationPath = PRESET_DIR .. "/" .. plan.destinationStorage .. ".preset"
    if not fileExists(sourcePath) or fileExists(destinationPath)
        or not os.rename(sourcePath, destinationPath) then
      local rolledBack = true
      for index = #movedPlans, 1, -1 do
        local moved = movedPlans[index]
        local movedPath = PRESET_DIR .. "/" .. moved.destinationStorage .. ".preset"
        local originalPath = PRESET_DIR .. "/" .. moved.storage .. ".preset"
        if not os.rename(movedPath, originalPath) then rolledBack = false end
      end
      if rolledBack then os.remove(TRANSACTION_FILE) end
      state.folderStatus, state.folderStatusError = rolledBack
        and "The imported folder was unchanged because a preset file could not be relocated."
        or "Preset relocation failed and could not be fully rolled back; startup recovery will retry it.", true
      return
    end
    table.insert(movedPlans, plan)
  end
  for _, plan in ipairs(relocationPlans) do
    plan.preset.storage = plan.destinationStorage
  end
  local persisted = persistVirtualState(newPresets, newFolders, newManualFolders, newIgnored)
  local transactionCompleted = persisted and (#relocationPlans == 0
    or completeTransaction("rename", relocationPlans))
  if not transactionCompleted then
    for _, plan in ipairs(relocationPlans) do plan.preset.storage = plan.storage end
    local rolledBack = true
    for index = #relocationPlans, 1, -1 do
      local plan = relocationPlans[index]
      local destinationPath = PRESET_DIR .. "/" .. plan.destinationStorage .. ".preset"
      local sourcePath = PRESET_DIR .. "/" .. plan.storage .. ".preset"
      if fileExists(destinationPath) and not os.rename(destinationPath, sourcePath) then
        rolledBack = false
      end
    end
    persistVirtualState(state.presets, state.folders, state.manualFolders,
      state.ignoredPhysicalFolders)
    if rolledBack then os.remove(TRANSACTION_FILE) end
    state.folderStatus, state.folderStatusError =
      rolledBack
        and "The folder removal was rolled back because its catalog or recovery journal could not be finalized."
        or "Folder removal could not be finalized or rolled back; startup recovery will retry it.", true
    return
  end
  local selectedPreset = state.selected
  if selectedPreset and isInFolderTree(parentFolder(selectedPreset), folder) then
    selectedPreset = joinFolder(destinationParent, selectedPreset:sub(#folder + 2))
  end
  state.presets, state.folders = newPresets, newFolders
  state.manualFolders, state.ignoredPhysicalFolders = newManualFolders, newIgnored
  state.selected, state.selectedFolder = selectedPreset, destinationParent
  invalidateViewCache()
  cancelConfirmations()
  resetLoadState()
  local physicalFolderRemoved = false
  if wasManualFolder
      and directoryTreeContainsFiles(folderPath(folder), 0) == false then
    physicalFolderRemoved = removeEmptyDirectoryTree(folderPath(folder), 0)
  end
  state.folderStatus, state.folderStatusError =
    "Removed folder \"" .. folder .. "\", kept all presets, and moved them to " ..
      (destinationParent == "" and "All Presets" or ("\"" .. destinationParent .. "\"")) ..
      (wasManualFolder
        and (physicalFolderRemoved
          and ". Its empty physical directory was also removed."
          or ". Its physical directory was kept because other content remains or it could not be removed safely.")
        or "."), false
end

local function refreshEditorState()
  state.inCustomization = isCustomizationActive()
  if not state.inCustomization then state.activeBodyMorphMenu = nil end
end

local draw
local drawDiscoveryHudNotice

do

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
  ImGui.PushStyleColor(ImGuiCol.Header, 0.055, 0.059, 0.078, 0.98)
  ImGui.PushStyleColor(ImGuiCol.HeaderHovered, 0.12, 0.09, 0.04, 0.98)
  ImGui.PushStyleColor(ImGuiCol.HeaderActive, 0.18, 0.12, 0.04, 1.0)
  ImGui.PushStyleColor(ImGuiCol.Text, 0.97, 0.72, 0.20, 1.0)
  local defaultFlag = state.openSections[key] ~= false and 32 or 0
  local open = ImGui.CollapsingHeader(label .. "##CPMSectionV2:" .. key, defaultFlag)
  ImGui.PopStyleColor(4)
  if open then ImGui.Spacing() end
  return open
end

local function fullWidthButton(label, height)
  local width = ImGui.GetContentRegionAvail()
  return ImGui.Button(label, width, height or 32)
end

local function compactSubsectionButton(closedLabel, openLabel, key)
  ImGui.Spacing()
  local open = state.openSubsections[key] == true
  local closedWidth = ImGui.CalcTextSize(closedLabel)
  local openWidth = ImGui.CalcTextSize(openLabel)
  local availableWidth = ImGui.GetContentRegionAvail()
  local width = math.min(math.max(closedWidth, openWidth) + 20, availableWidth)
  ImGui.PushStyleColor(ImGuiCol.Button, 0.10, 0.11, 0.14, 1.0)
  ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.28, 0.38, 0.50, 0.78)
  ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.24, 0.32, 0.42, 0.95)
  ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, 0.0)
  if ImGui.Button((open and openLabel or closedLabel) ..
      "##CPMSubsection:" .. key, width, 26) then
    open = not open
    state.openSubsections[key] = open
  end
  ImGui.PopStyleVar(1)
  ImGui.PopStyleColor(3)
  if open then ImGui.Spacing() end
  return open
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
  local kind = state.statusKinds[section]
  local isError = state[section .. "StatusError"] or kind == "error"
  local checkClothing = section == "load"
    and not isError
    and state.inCustomization
    and not isNewGameCharacterCreator()
    and not state.autoLoad
    and not state.loadNeedsContinue
    and text:find("Open the character creator", 1, true) == 1
  if checkClothing and state.clothingCheckDirty then
    state.cachedClothingLabels = equippedClothingLabels()
    state.clothingCheckDirty = false
  end
  local clothingLabels = {}
  if checkClothing then clothingLabels = state.cachedClothingLabels end
  local clothingCheckUnavailable = checkClothing and clothingLabels == nil
  clothingLabels = clothingLabels or {}
  local clothingWarning = #clothingLabels > 0
  if clothingWarning then
    text = "Equipped areas: " .. table.concat(clothingLabels, ", ") ..
      ". You may ignore this notice and load normally. If the game hangs when customization closes, unequip these items and select No Outfit before trying again."
  elseif clothingCheckUnavailable then
    text = "Clothing could not be checked. You may ignore this notice and load normally. If the game hangs when customization closes, unequip all clothing and select No Outfit before trying again."
  end
  local success = not isError and (kind == "success"
    or (kind == nil and isSuccess and isSuccess(text)))
  local warning = not isError and kind == "warning"
  local destructiveWarning = (section == "delete"
      and (state.pendingEmptyTrash == true
        or (state.pendingDeleteName ~= nil
          and state.pendingDeleteName == state.selected)))
    or (section == "bulk" and state.pendingBulkAction ~= nil)
  local customColors = false
  ImGui.Spacing()
  if isError or destructiveWarning then
    ImGui.PushStyleColor(ImGuiCol.ChildBg, 0.086, 0.094, 0.118, 0.85)
    ImGui.PushStyleColor(ImGuiCol.Border, 0.90, 0.25, 0.22, 0.90)
    customColors = true
  elseif warning or clothingWarning or clothingCheckUnavailable then
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
  elseif warning then
    ImGui.TextColored(1.0, 0.8, 0.2, 1.0, "WARNING")
    coloredWrapped(1.0, 1.0, 1.0, 1.0, text)
  elseif clothingWarning or clothingCheckUnavailable then
    ImGui.TextColored(1.0, 0.8, 0.2, 1.0, "OPTIONAL CLOTHING NOTICE")
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

local statusSuccess = {}

statusSuccess.load = function(text)
  return text:find("Preset fully applied", 1, true) ~= nil
    or text:find("Open the character creator", 1, true) == 1
end
statusSuccess.create = function(text) return text:find("^Saved ") ~= nil end
statusSuccess.rename = function(text)
  return text:find("^Renamed ") ~= nil or text:find("^Duplicated ") ~= nil
    or text:find("^Saved details ") ~= nil
end
statusSuccess.delete = function(text)
  return text:find("^Moved ") ~= nil or text:find("^Restored ") ~= nil
    or text == "Trash emptied permanently."
end
statusSuccess.bulk = function(text) return text:find("^Moved ") ~= nil end
statusSuccess.editor = function(text) return text == "Full editor opened." end
statusSuccess.folder = function(text)
  return text:find("^Created virtual folder ") ~= nil
    or text:find("^Renamed virtual folder ") ~= nil
    or text:find("^Duplicated virtual folder ") ~= nil
    or text:find("^Removed folder ") ~= nil
    or text:find("^Exported ") ~= nil
    or text:find("^Imported ") ~= nil
    or text:find("^Moved ") ~= nil
end

local function setDebugLogText(text)
  state.debugLogText = tostring(text or "")
  local lines = {}
  for line in (state.debugLogText .. "\n"):gmatch("(.-)\n") do
    local lowerLine = line:lower()
    local kind = "disabled"
    if line == "" then
      kind = "blank"
    elseif lowerLine:find("[load error]", 1, true)
        or lowerLine:find("[error]", 1, true) then
      kind = "error"
    elseif lowerLine:find("[load warning]", 1, true)
        or lowerLine:find("[warn]", 1, true) then
      kind = "warn"
    elseif lowerLine:find("[complete]", 1, true) then
      kind = "complete"
    elseif lowerLine:find("[load]", 1, true) then
      kind = "load"
    elseif lowerLine:find("[info]", 1, true) then
      kind = "info"
    elseif lowerLine:find("error", 1, true)
        or lowerLine:find("could not", 1, true)
        or lowerLine:find("not available", 1, true) then
      kind = "error"
    end
    table.insert(lines, { text = line, kind = kind })
  end
  state.debugLogLines = lines
end

local function readDiagnosticLog()
  local file = io.open(LOG_FILE, "rb")
  if not file then
    setDebugLogText("No activity log yet -- nothing has happened this session.")
    return
  end
  local limit = 65536
  local sizeOk, size = pcall(file.seek, file, "end")
  if not sizeOk or not size then
    file:close()
    setDebugLogText("The activity log could not be measured.")
    return
  end
  local truncated = size > limit
  local start = truncated and (size - limit) or 0
  local seekOk, seekResult = pcall(file.seek, file, "set", start)
  local ok, contents = false, nil
  if seekOk and seekResult ~= nil then ok, contents = pcall(file.read, file, "*a") end
  file:close()
  if not ok or type(contents) ~= "string" then
    setDebugLogText("The activity log could not be read.")
    return
  end
  if truncated then
    contents = "[Showing the newest 64 KB of Data/Logs/Activity.log]\n\n" ..
      contents
  end
  setDebugLogText(contents ~= "" and contents
    or "Data/Logs/Activity.log is empty.")
end

local function drawDebugPanel(height)
  ImGui.Spacing()
  local logRowStartX = ImGui.GetCursorPosX()
  local logRowWidth = ImGui.GetContentRegionAvail()
  local logButtonWidth = 68
  local logButtonHeight = 32
  local logButtonsWidth = logButtonWidth * 3 + 16
  ImGui.TextColored(0.97, 0.72, 0.20, 1.0, "Activity Log")
  ImGui.SameLine()
  ImGui.SetCursorPosX(logRowStartX + logRowWidth - logButtonsWidth)
  if ImGui.Button("Refresh##debugRefresh", logButtonWidth, logButtonHeight) then readDiagnosticLog() end
  ImGui.SameLine()
  if ImGui.Button("Copy##debugCopy", logButtonWidth, logButtonHeight) then
    ImGui.SetClipboardText(state.debugLogText or "")
  end
  ImGui.SameLine()
  if ImGui.Button("Close##debugClose", logButtonWidth, logButtonHeight) then state.debugOpen = false end
  if ImGui.CollapsingHeader("Advanced diagnostics##advancedDiagnostics") then
    ImGui.TextWrapped(("Editor launch: input=%d  controller=%d  redirect=%d  puppet=%d")
      :format(state.editorInputCount, state.editorControllerCaptureCount,
        state.editorPauseRedirectCount, state.editorPuppetReadyCount))
    coloredWrapped(0.64, 0.67, 0.73, 1.0,
      "After one successful input launch, all four values should be at least 1.")
  end
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
  for _, entry in ipairs(state.debugLogLines) do
    local line = entry.text
    if entry.kind == "blank" then
      ImGui.Spacing()
    elseif entry.kind == "error" then
      coloredWrapped(1.0, 0.4, 0.4, 1.0, line)
    elseif entry.kind == "warn" then
      coloredWrapped(1.0, 0.8, 0.2, 1.0, line)
    elseif entry.kind == "complete" then
      coloredWrapped(0.3, 1.0, 0.4, 1.0, line)
    elseif entry.kind == "load" then
      coloredWrapped(1.0, 1.0, 1.0, 1.0, line)
    elseif entry.kind == "info" then
      coloredWrapped(1.0, 1.0, 1.0, 1.0, line)
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

local function readCETBinding(slug)
  local bound
  local queryAvailable = false
  if type(IsBound) == "function" then
    local ok, result = pcall(IsBound, slug)
    if ok and type(result) == "boolean" then
      queryAvailable = true
      bound = result
    end
  end
  if bound == false then return "unbound" end
  if type(GetBind) == "function" then
    local ok, result = pcall(GetBind, slug)
    if ok then
      queryAvailable = true
      if type(result) == "string" then
        result = result:match("^%s*(.-)%s*$")
        if result ~= "" then return "bound", result end
      end
      if bound == nil then return "unbound" end
    end
  end
  if bound then return "bound" end
  if queryAvailable then return "unbound" end
  return "unavailable"
end

local function drawBindingHelp(label, slug, receivedCount)
  ImGui.TextWrapped(label)
  local binding = state.bindingCache[slug]
  if not binding then
    local status, assignedKey = readCETBinding(slug)
    binding = { status = status, assignedKey = assignedKey }
    state.bindingCache[slug] = binding
  end
  local status, assignedKey = binding.status, binding.assignedKey
  if status == "bound" and assignedKey then
    coloredWrapped(0.3, 1.0, 0.4, 1.0, "Assigned key: " .. assignedKey)
  elseif status == "bound" then
    coloredWrapped(0.3, 1.0, 0.4, 1.0, "Assigned in CET Bindings.")
  elseif status == "unbound" then
    coloredWrapped(1.0, 0.4, 0.4, 1.0, "Assigned key: Not set")
  elseif receivedCount > 0 then
    coloredWrapped(0.3, 1.0, 0.4, 1.0,
      ("CET input detected %d time%s this session.")
        :format(receivedCount, receivedCount == 1 and "" or "s"))
  else
      coloredWrapped(0.64, 0.67, 0.73, 1.0,
        "Assigned key unavailable; view it in CET Bindings.")
  end
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

local function discoveryViewport()
  if ImGui.GetMainViewport then
    local viewport = ImGui.GetMainViewport()
    if viewport and viewport.WorkPos and viewport.WorkSize then
      return viewport.WorkPos.x, viewport.WorkPos.y,
        viewport.WorkSize.x, viewport.WorkSize.y
    end
  end
  if ImGui.GetDisplaySize then
    local width, height = ImGui.GetDisplaySize()
    if width and height then return 0, 0, width, height end
  end
  return 0, 0, 1920, 1080
end

drawDiscoveryHudNotice = function()
  if not state.discoveryNoticePending or state.discoveryNoticeIgnored
      or state.overlayOpen then return end
  local layout = state.discoveryNoticeLayout
  if not layout then
    local viewportX, viewportY, viewportWidth = discoveryViewport()
    local titleWidth = ImGui.CalcTextSize(DISCOVERY_NOTICE_TITLE)
    local messageWidth = ImGui.CalcTextSize(DISCOVERY_NOTICE_MESSAGE)
    local settingsWidth = ImGui.CalcTextSize(DISCOVERY_NOTICE_SETTINGS_MESSAGE)
    local width = math.min(viewportWidth - 48,
      math.max(340, math.max(titleWidth, messageWidth, settingsWidth) + 32))
    layout = {
      width = width,
      height = 82,
      x = viewportX + math.max(24, (viewportWidth - width) * 0.5),
      y = viewportY + 72,
      titleX = math.max(14, (width - titleWidth) * 0.5),
      messageX = math.max(14, (width - messageWidth) * 0.5),
      settingsX = math.max(14, (width - settingsWidth) * 0.5),
      flags = bit32.bor(
        ImGuiWindowFlags.NoTitleBar,
        ImGuiWindowFlags.NoResize,
        ImGuiWindowFlags.NoScrollbar,
        ImGuiWindowFlags.NoScrollWithMouse,
        ImGuiWindowFlags.NoCollapse,
        ImGuiWindowFlags.NoSavedSettings,
        ImGuiWindowFlags.NoMove,
        ImGuiWindowFlags.NoInputs
      ),
    }
    state.discoveryNoticeLayout = layout
  end
  ImGui.SetNextWindowPos(layout.x, layout.y, ImGuiCond.Always)
  ImGui.SetNextWindowSize(layout.width, layout.height, ImGuiCond.Always)
  ImGui.PushStyleColor(ImGuiCol.WindowBg, 0.055, 0.059, 0.078, 0.94)
  ImGui.PushStyleColor(ImGuiCol.Border, 0.95, 0.72, 0.20, 0.85)
  ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 6.0)
  ImGui.PushStyleVar(ImGuiStyleVar.WindowBorderSize, 1.0)
  ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 14.0, 7.0)
  if ImGui.Begin("##CharacterPresetManagerDiscovery", true, layout.flags) then
    ImGui.SetCursorPosX(layout.titleX)
    ImGui.TextColored(0.97, 0.72, 0.20, 1.0,
      DISCOVERY_NOTICE_TITLE)
    ImGui.SetCursorPosX(layout.messageX)
    ImGui.TextColored(1.0, 1.0, 1.0, 1.0,
      DISCOVERY_NOTICE_MESSAGE)
    ImGui.SetCursorPosX(layout.settingsX)
    ImGui.TextColored(0.64, 0.67, 0.73, 1.0,
      DISCOVERY_NOTICE_SETTINGS_MESSAGE)
  end
  ImGui.End()
  ImGui.PopStyleVar(3)
  ImGui.PopStyleColor(2)
end

local function drawBulkTrashOptions(actionButtonHeight, statusHeight)
  ImGui.TextColored(0.97, 0.72, 0.20, 1.0, "Select multiple presets")
  ImGui.PushItemWidth(-1)
  local previousSearchText = state.searchText
  state.searchText = ImGui.InputTextWithHint("##bulkPresetSearch",
    "Search presets or folders", state.searchText, 65)
  if state.searchText ~= previousSearchText then invalidateFilteredViewCache() end
  ImGui.PopItemWidth()
  local visibleNames = filteredPresetNames()
  local selectedBulkNames = selectedBulkPresetNames()
  local bulkButtonWidth = (ImGui.GetContentRegionAvail() - 8) * 0.5
  if ImGui.Button("Select All Visible##bulkSelectAll",
      bulkButtonWidth, actionButtonHeight) then
    for _, name in ipairs(visibleNames) do state.bulkSelected[name] = true end
    invalidateBulkSelectionCache()
    cancelConfirmations()
    state.bulkStatus = ""
    state.bulkStatusError = false
  end
  ImGui.SameLine()
  if #selectedBulkNames == 0 then ImGui.BeginDisabled() end
  if ImGui.Button("Clear Selection##bulkClear",
      bulkButtonWidth, actionButtonHeight) then
    state.bulkSelected = {}
    invalidateBulkSelectionCache()
    cancelConfirmations()
    state.bulkStatus = ""
    state.bulkStatusError = false
  end
  if #selectedBulkNames == 0 then ImGui.EndDisabled() end
  ImGui.BeginChild("##bulkPresetList", 0, ImGui.GetFontSize() * 6, true)
  if #visibleNames == 0 then
    ImGui.TextDisabled("No presets match the current search.")
  else
    for _, name in ipairs(visibleNames) do
      local selectedForBulk = state.bulkSelected[name] == true
      if ImGui.Selectable((selectedForBulk and "[x] " or "[ ] ") ..
          breadcrumb(name) .. "##bulkPreset:" .. name, selectedForBulk) then
        state.bulkSelected[name] = selectedForBulk and nil or true
        invalidateBulkSelectionCache()
        cancelConfirmations()
        state.bulkStatus = ""
        state.bulkStatusError = false
      end
    end
  end
  ImGui.EndChild()
  selectedBulkNames = selectedBulkPresetNames()
  ImGui.TextDisabled(("%d preset%s selected.")
    :format(#selectedBulkNames, #selectedBulkNames == 1 and "" or "s"))
  if #selectedBulkNames == 0 then ImGui.BeginDisabled() end
  local bulkTrashLabel = state.pendingBulkAction == "presets"
    and "Confirm Bulk Trash"
    or ("Move %d Preset%s to Trash")
      :format(#selectedBulkNames, #selectedBulkNames == 1 and "" or "s")
  if dangerButton(bulkTrashLabel .. "##bulkPresetTrash",
      ImGui.GetContentRegionAvail(), actionButtonHeight) then
    requestBulkTrash(selectedBulkNames)
  end
  if #selectedBulkNames == 0 then ImGui.EndDisabled() end
  drawSectionStatus("bulk", "##bulkStatus", statusSuccess.bulk, statusHeight)
end

draw = function()
  if not state.overlayOpen or not state.windowOpen then return end

  pushTheme()
  if not state.windowPositionCached then
    state.cachedWindowX, state.cachedDisplayWidth = defaultWindowPosition()
    state.windowPositionCached = true
  end
  local initialX = state.cachedWindowX
  local displayWidth = state.cachedDisplayWidth
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
    local actionButtonHeight = 32

    local narrowTopRow = ImGui.GetWindowWidth() < 620
    local topRowStartX = ImGui.GetCursorPosX()
    local topRowWidth = ImGui.GetContentRegionAvail()
    local topButtonWidth = 72
    local topControlsWidth = topButtonWidth * 2 + 8
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
    if ImGui.Button("Settings##settings", topButtonWidth, actionButtonHeight) then
      state.settingsOpen = not state.settingsOpen
    end
    ImGui.SameLine()
    if ImGui.Button("Help##help", topButtonWidth, actionButtonHeight) then
      state.helpOpen = not state.helpOpen
      if state.helpOpen then state.debugOpen = false end
      if state.helpOpen then state.bindingCache = {} end
    end
    if state.settingsOpen then
      ImGui.Spacing()
      ImGui.BeginChild("##settings", 0, 226, true)
      ImGui.TextColored(0.97, 0.72, 0.20, 1.0, "Settings")
      ImGui.TextDisabled(CONFIG_FILE)
      ImGui.TextWrapped("Show the gameplay reminder when a character customization screen opens.")
      local reminderEnabled = not state.discoveryNoticeIgnored
      local reminderLabel = reminderEnabled
        and "Customization Reminder: Enabled"
        or "Customization Reminder: Disabled"
      if fullWidthButton(reminderLabel .. "##discoveryPreference", actionButtonHeight) then
        local saved
        if reminderEnabled then saved = ignoreDiscoveryNotice()
        else saved = restoreDiscoveryNotice() end
        local currentState = state.discoveryNoticeIgnored and "disabled" or "enabled"
        if saved then
          state.settingsStatus = "Customization reminder " .. currentState .. ". Config saved."
        else
          state.settingsStatus = "Customization reminder " .. currentState ..
            " for this session; config could not be saved."
        end
      end
      local sortLabel = state.sortMode == "modified"
        and "Preset Sort: Last Modified" or "Preset Sort: Name"
      if fullWidthButton(sortLabel .. "##presetSort", actionButtonHeight) then
        state.sortMode = state.sortMode == "modified" and "name" or "modified"
        invalidateViewCache()
        state.settingsStatus = writeConfig() and "Config saved." or "Config could not be saved."
      end
      if fullWidthButton("Reload Config from Disk##reloadConfig", actionButtonHeight) then
        local config, loaded = readConfig()
        if loaded then
          state.discoveryNoticeIgnored = not config.discoveryReminder
          if state.discoveryNoticeIgnored then state.discoveryNoticePending = false end
          state.discoveryNoticeLayout = nil
          state.sortMode = config.presetSort == "modified" and "modified" or "name"
          invalidateViewCache()
          state.settingsStatus = "Config reloaded."
        else
          state.settingsStatus = "Config could not be reloaded."
        end
      end
      if state.settingsStatus ~= "" then
        coloredWrapped(0.64, 0.67, 0.73, 1.0, state.settingsStatus)
      end
      ImGui.EndChild()
    end
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

      helpHeading("Known Game Issue")
      ImGui.TextWrapped("Cyberpunk may stay on a loading screen after any character editor closes. This can happen without this mod.")
      coloredWrapped(1.0, 0.8, 0.2, 1.0,
        "If this happens, unequip all clothing and select No Outfit before opening the editor. Put the items back on afterward.")

      helpHeading("Incompatible Mods")
      coloredWrapped(1.0, 0.4, 0.4, 1.0,
        "Remove Appearance Change Unlocker (ACU) and Character Customization Anywhere. They change the same character editor screens. Restart the game after removing them.")

      helpHeading("Character Option Mods")
      ImGui.TextWrapped("Keep the same character option mods and load order used when the preset was made.")
      ImGui.TextWrapped("If they changed, fix the appearance and save the preset again.")

      helpHeading("Photo Mode and Appearance Menu Mod")
      ImGui.TextWrapped("Both mods are compatible and may remain installed. Character Preset Manager cannot save or load presets from inside their interfaces. Use the full editor, a mirror, a ripperdoc, or the new-game editor.")

      ImGui.Separator()

      helpHeading("Open the Editor")
      ImGui.TextWrapped("Load a saved game, then select Open Full Appearance Editor. Mirrors, ripperdocs, and the new-game editor also work.")
      ImGui.TextWrapped("Set or change these under CET Bindings > Character Preset Manager (CET). Close the CET window before using the editor input.")
      drawBindingHelp("Open Full Appearance Editor", "preset_manager_open_editor_input",
        state.editorInputCount)
      drawBindingHelp("Toggle Character Preset Manager (CET)",
        "vanilla_character_presets_toggle", state.windowHotkeyCount)

      helpHeading("Load a Preset")
      ImGui.TextWrapped("1. Select a preset under Load Preset.")
      ImGui.TextWrapped("2. Select Load Selected Preset once.")
      coloredWrapped(0.3, 1.0, 0.4, 1.0,
        "3. Wait for Preset Fully Applied.")
      coloredWrapped(1.0, 0.8, 0.2, 1.0,
        "Options not saved in the preset may be removed.")

      helpHeading("Save a Preset")
      ImGui.TextWrapped("1. Open Choose Save Destination and select a folder or All Presets.")
      ImGui.TextWrapped("2. Enter a name under Save Preset.")
      ImGui.TextWrapped("3. Select Save New Preset. Confirm only if replacing an existing preset.")

      helpHeading("Folders")
      ImGui.TextWrapped("Select a folder row under Load Preset to open or close it.")
      ImGui.TextWrapped("To move a preset, select the preset, select a folder, then select Move Selected Preset Here. Select All Presets to move it out of a folder.")
      ImGui.TextWrapped("Adding a folder creates it inside the selected folder. Select All Presets first to add a root folder.")
      ImGui.TextWrapped("Folders created in CET are virtual and have no packaged slot limit. Renaming them or moving presets between them does not rename directories in File Explorer.")
      ImGui.TextWrapped("Directories created manually inside Character Presets are discovered recursively and labeled Imported. Their preset files stay at those paths until an operation explicitly relocates them.")

      helpHeading("Rename, Copy, or Remove")
      ImGui.TextWrapped("Select a preset or folder before using its rename or copy action. Renaming a preset also renames its shareable .preset file. Folder renames remain virtual.")
      ImGui.TextWrapped("Copies are placed beside the original. Copying a virtual folder copies all presets and nested virtual folders.")
      ImGui.TextWrapped("Remove Folder, Keep Presets moves its presets and nested folders to the parent after confirmation. For an Imported folder, recognized preset files are relocated first. Unknown files and any directory containing them are never deleted.")

      helpHeading("Delete and Restore")
      ImGui.TextWrapped("Use Folders to delete a selected folder safely by moving it and its presets to Trash. Use Delete & Restore for one selected preset, filtered multi-selection, restoration, and permanent cleanup. Trash actions require confirmation.")
      ImGui.TextWrapped("Restore Folder recovers its complete logical tree, including empty nested virtual folders. Restored files receive safe names in Character Presets; a conflict receives a Copy name instead of overwriting an existing preset.")

      helpHeading("Share One Preset")
      ImGui.TextWrapped("Place .preset files in the preset folder or a directory inside it. Copy one .preset file to share one appearance. A shared .preset does not contain its virtual folder assignment.")
      ImGui.TextWrapped("New .preset imports follow the manual directory where they are placed.")
      ImGui.TextWrapped("Select Refresh under Load Preset after changing files outside the game. Only current format-5 Character Preset Manager .preset files are accepted.")
      pathCallout("##presetFolderPath", "Preset Folder",
        "bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Character Presets")
      if fullWidthButton("Copy Preset Folder Path##copyPresetPath", actionButtonHeight) then
        ImGui.SetClipboardText(
          "bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Character Presets")
      end

      helpHeading("Share or Import a Folder")
      ImGui.TextWrapped("Export: select a non-empty folder under Folders, then select Export Folder for Sharing. The portable .cpmfolder file is saved in Character Presets and includes all nested folders and presets.")
      ImGui.TextWrapped("Import: put the .cpmfolder file in Character Presets. Under Folders, select All Presets (root), then select Import Folder Bundles. Every bundle found there is processed.")
      ImGui.TextWrapped("After a successful import, the bundle stays untouched and its filename plus fingerprint are recorded in Data/Catalog/Imported Bundles.txt. An unchanged bundle is skipped; a changed bundle with the same filename can be imported again. Existing folder names receive a safe Copy name.")

      helpHeading("Settings and Config")
      ImGui.TextWrapped("Settings controls the customization reminder and preset sorting. The reminder stays enabled until you turn it off here.")
      ImGui.TextWrapped("The same values can be edited in Data/Config/Config.txt, then applied with Reload Config from Disk.")

      helpHeading("Debug and Diagnostics")
      ImGui.TextWrapped("The activity log records preset actions, warnings, errors, and advanced editor diagnostics.")
      if fullWidthButton("Open Debug Log##openDebugFromHelp", actionButtonHeight) then
        readDiagnosticLog()
        state.debugOpen = true
        state.helpOpen = false
      end

      ImGui.EndChild()
      ImGui.PopStyleColor(4)
    end

    if collapsibleSectionHeader("APPEARANCE EDITOR", "editor") then
    ImGui.TextWrapped("Opens the full vanilla character editor. Apartment mirrors provide the same options.")
    ImGui.Spacing()
    local editorUnavailable = state.editorOpenPending or state.inCustomization
      or not state.editorHooksAvailable
    if editorUnavailable then ImGui.BeginDisabled() end
    if fullWidthButton("Open Full Appearance Editor##openEditor", actionButtonHeight) then
      openFullAppearanceEditor()
    end
    if editorUnavailable then ImGui.EndDisabled() end
    drawSectionStatus("editor", "##editorStatus", statusSuccess.editor, statusHeight)
    end

    if collapsibleSectionHeader("LOAD PRESET", "load") then
    ImGui.TextColored(1.0, 1.0, 1.0, 1.0, "Select a preset to load")
    ImGui.Spacing()
    local searchRowWidth = ImGui.GetContentRegionAvail()
    local searchButtonWidth = 64
    ImGui.PushItemWidth(math.max(80, searchRowWidth - searchButtonWidth * 2 - 16))
    local previousSearchText = state.searchText
    state.searchText = ImGui.InputTextWithHint("##presetSearch", "Search presets or folders", state.searchText, 65)
    if state.searchText ~= previousSearchText then invalidateFilteredViewCache() end
    ImGui.PopItemWidth()
    ImGui.SameLine()
    local clearSearchUnavailable = not tostring(state.searchText):match("%S")
    if clearSearchUnavailable then ImGui.BeginDisabled() end
    if ImGui.Button("Clear##presetSearchClear", searchButtonWidth, actionButtonHeight) then
      state.searchText = ""
      invalidateFilteredViewCache()
    end
    if clearSearchUnavailable then ImGui.EndDisabled() end
    ImGui.SameLine()
    if ImGui.Button("Refresh##presetRefresh", searchButtonWidth, actionButtonHeight) then
      local before = state.presets
      local after, refreshed = refreshPresets("external")
      refreshTrash()
      if state.selected and state.presets[state.selected] then
        state.presetNotes = state.presets[state.selected].notes or ""
        state.presetTags = state.presets[state.selected].tags or ""
      end
      refreshPreflight()
      local added, removed, updated = 0, 0, 0
      if refreshed then
        for name, preset in pairs(after) do
          if not before[name] then added = added + 1
          elseif not presetsMatch(before[name], preset) then updated = updated + 1 end
        end
        for name in pairs(before) do if not after[name] then removed = removed + 1 end end
      end
      setStatus("load", refreshed
        and ("Refreshed: %d added, %d updated, %d removed; %d available.")
          :format(added, updated, removed, #sortedPresetNames())
        or "Refresh failed; the previous list was kept.", not refreshed)
    end
    ImGui.BeginChild("##presetList", 0, presetListHeight, true)
    local names = sortedPresetNames()
    ensureFilteredViewCache()
    local queryActive = state.cachedQueryActive
    local matchedFolders = state.cachedMatchedFolders
    if #names == 0 then
      ImGui.TextDisabled("No presets saved.")
    else
      local function drawPresetChoice(name, label)
        if ImGui.Selectable(label .. "##preset:" .. name, state.selected == name)
            and state.selected ~= name then
          log(("[UI] Preset selection changed: old='%s' new='%s'.")
            :format(tostring(state.selected), name), "info")
          state.selected = name
          local selectedPreset = state.presets[name]
          state.presetNotes = selectedPreset and selectedPreset.notes or ""
          state.presetTags = selectedPreset and selectedPreset.tags or ""
          cancelConfirmations()
          state.renameName = ""
          resetLoadState()
          state.renameStatus = ""
          state.renameStatusError = false
          state.deleteStatus = ""
          state.deleteStatusError = false
          refreshPreflight()
        end
      end
      for _, folder in ipairs(sortedFolderNames()) do
        local folderPresets = presetsInFolder(folder)
        local subtreeCount = state.cachedFolderPresetCounts[folder] or 0
        local folderMatches = state.cachedFolderMatches[folder] == true
        local matchingPresets = state.cachedMatchingPresetsByFolder[folder] or EMPTY_LIST
        local descendantMatches = matchedFolders[folder] == true
        if subtreeCount > 0 and (folderMatches or #matchingPresets > 0 or descendantMatches) then
          local expanded = state.expandedLoadFolders[folder] == true
          local folderKind = state.manualFolders[folder]
            and " (imported)" or ""
          ImGui.SetNextItemOpen(expanded or queryActive, ImGuiCond.Always)
          local treeFlags = 8 + 2048 + (expanded and 1 or 0)
          local nodeOpen = ImGui.TreeNodeEx(
            string.rep("  ", folderDepth(folder)) .. baseName(folder) ..
              (" (%d)"):format(subtreeCount) .. folderKind .. "##loadFolder:" .. folder,
            treeFlags)
          if not queryActive then
            state.expandedLoadFolders[folder] = nodeOpen
          end
          if nodeOpen then
            ImGui.Indent(12)
            for _, name in ipairs(folderMatches and folderPresets or matchingPresets) do
              drawPresetChoice(name, baseName(name))
            end
            ImGui.Unindent(12)
          end
        end
      end
      for _, name in ipairs(state.cachedMatchingPresetsByFolder[""] or EMPTY_LIST) do
        drawPresetChoice(name, name)
      end
    end
    ImGui.EndChild()
    ImGui.Spacing()

    if state.selected and state.presets[state.selected] then
      local preset = state.presets[state.selected]
      ImGui.TextColored(0.97, 0.72, 0.20, 1.0, baseName(state.selected))
      coloredWrapped(0.64, 0.67, 0.73, 1.0,
        ("Folder: %s  |  Options: %d  |  Format: %s")
        :format(breadcrumb(parentFolder(state.selected)), #(preset.entries or {}),
          tostring(preset.format or 4)))
      coloredWrapped(0.64, 0.67, 0.73, 1.0,
        ("Source: %s  |  Modified: %s")
          :format(tostring(preset.source or "Legacy or ACU-compatible"),
          tostring(preset.modified or "Unknown")))
      if preset.tags and preset.tags ~= "" then ImGui.TextWrapped("Tags: " .. preset.tags) end
      if preset.notes and preset.notes ~= "" then ImGui.TextWrapped("Notes: " .. preset.notes) end
      if state.preflight then
        local check = state.preflight
        local color = (check.ambiguous + check.invalid) > 0 and { 1.0, 0.4, 0.4 }
          or check.unavailable > 0 and { 1.0, 0.8, 0.2 } or { 0.3, 1.0, 0.4 }
        coloredWrapped(color[1], color[2], color[3], 1.0,
          ("Compatibility check: %d available, %d dependency-hidden/unavailable, %d ambiguous, %d invalid")
            :format(check.available, check.unavailable, check.ambiguous, check.invalid))
      else
        ImGui.TextDisabled("Open a customization screen to check compatibility.")
      end
    end

    local loadUnavailable = not state.selected or not state.inCustomization
    if loadUnavailable then ImGui.BeginDisabled() end
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
        resetLoadState()
      end
      state.autoLoadTimer = 0
      state.autoLoadPasses = 0
      state.resetBeforeLoad = true
      loadPreset()
      if state.loadNeedsContinue then state.autoLoad = true end
    end
    if state.autoLoad then ImGui.EndDisabled() end
    if loadUnavailable then ImGui.EndDisabled() end
    if state.autoLoad or state.loadNeedsContinue then
      if dangerButton("Cancel Loading##cancelLoad", ImGui.GetContentRegionAvail(), actionButtonHeight) then
        cancelLoading()
      end
    elseif loadUnavailable then
      ImGui.TextDisabled(not state.selected and "Select a preset to enable loading."
        or "Open a customization screen to enable loading.")
    end
    drawSectionStatus("load", "##loadStatus", statusSuccess.load, statusHeight)
    end

    if collapsibleSectionHeader("SAVE PRESET", "create") then
    ImGui.TextColored(1.0, 1.0, 1.0, 1.0,
      "Save the current appearance as a new preset")
    ImGui.TextWrapped("Save location: " .. breadcrumb(state.selectedFolder))
    if compactSubsectionButton("Choose Save Destination", "Hide Save Destinations",
        "saveDestination") then
      ImGui.Indent(8)
      ImGui.BeginChild("##saveDestinationList", 0, ImGui.GetFontSize() * 4.5, true)
      if ImGui.Selectable("All Presets##saveDestinationRoot", state.selectedFolder == "")
          and state.selectedFolder ~= "" then
        state.selectedFolder = ""
        cancelConfirmations()
        setStatus("create", "Save destination changed to All Presets.")
        log("[UI] Save destination changed to '<root>'.", "info")
      end
      for _, folder in ipairs(sortedFolderNames()) do
        local label = string.rep("  ", folderDepth(folder)) .. baseName(folder) ..
          (state.manualFolders[folder] and " (imported)" or "")
        if ImGui.Selectable(label .. "##saveDestination:" .. folder,
            state.selectedFolder == folder) and state.selectedFolder ~= folder then
          state.selectedFolder = folder
          cancelConfirmations()
          setStatus("create", "Save destination changed to " .. breadcrumb(folder) .. ".")
          log(("[UI] Save destination changed to '%s'."):format(folder), "info")
        end
      end
      ImGui.EndChild()
      ImGui.Unindent(8)
    end
    ImGui.Spacing()
    ImGui.PushItemWidth(-1)
    local previousNewName = state.newName
    state.newName = ImGui.InputTextWithHint("##newPreset", "Name", state.newName, 65)
    ImGui.PopItemWidth()
    if state.newName ~= previousNewName then
      state.pendingOverwriteName = nil
      state.pendingOverwriteFingerprint = nil
    end
    local saveLabel = "Save New Preset"
    local pendingCreateName = joinFolder(state.selectedFolder, sanitizeName(state.newName))
    if state.pendingOverwriteName == pendingCreateName then
      saveLabel = "Confirm Overwrite"
    end
    ImGui.Spacing()
    local saveUnavailable = not state.inCustomization
      or validatedPresetName(state.newName) == nil
    if saveUnavailable then ImGui.BeginDisabled() end
    if fullWidthButton(saveLabel, actionButtonHeight) then
      savePreset(state.pendingOverwriteName == pendingCreateName)
    end
    if saveUnavailable then ImGui.EndDisabled() end
    if saveUnavailable then
      ImGui.TextDisabled(not state.inCustomization
        and "Open a customization screen to enable saving."
        or "Enter a valid preset name to enable saving.")
    end
    drawSectionStatus("create", "##createStatus", statusSuccess.create, statusHeight)
    end

    if collapsibleSectionHeader("FOLDERS", "folders") then
    ImGui.TextColored(1.0, 1.0, 1.0, 1.0,
      "Select how new or moved presets are organized")
    ImGui.TextWrapped("Selected destination: " .. breadcrumb(state.selectedFolder))
    coloredWrapped(0.64, 0.67, 0.73, 1.0,
      "Virtual folders have no packaged slot limit. Imported folders come from File Explorer.")
    ImGui.Spacing()
    ImGui.BeginChild("##folderList", 0, ImGui.GetFontSize() * 4.5, true)
    if ImGui.Selectable("All Presets (root)##rootFolder", state.selectedFolder == "")
        and state.selectedFolder ~= "" then
      log(("[UI] Folder selection changed: old='%s' new='<root>'.")
        :format(state.selectedFolder), "info")
      state.selectedFolder = ""
      cancelConfirmations()
    end
    for _, folder in ipairs(sortedFolderNames()) do
      local label = string.rep("  ", folderDepth(folder)) .. baseName(folder) ..
        (state.manualFolders[folder] and " (imported)" or "")
      if ImGui.Selectable(label .. "##folder:" .. folder, state.selectedFolder == folder)
          and state.selectedFolder ~= folder then
        log(("[UI] Folder selection changed: old='%s' new='%s'.")
          :format(tostring(state.selectedFolder), folder), "info")
        state.selectedFolder = folder
        cancelConfirmations()
        state.folderRenameName = ""
      end
    end
    ImGui.EndChild()
    ImGui.PushItemWidth(-1)
    state.folderName = ImGui.InputTextWithHint("##newFolder", "New folder name", state.folderName, 65)
    ImGui.PopItemWidth()
    local addFolderUnavailable = validatedFolderName(state.folderName) == nil
    if addFolderUnavailable then ImGui.BeginDisabled() end
    if fullWidthButton("Add Folder", actionButtonHeight) then createFolder() end
    if addFolderUnavailable then ImGui.EndDisabled() end
    if addFolderUnavailable then ImGui.TextDisabled("Enter a valid folder name to enable adding.") end
    if state.selectedFolder ~= "" then
      ImGui.PushItemWidth(-1)
      state.folderRenameName = ImGui.InputTextWithHint("##renameFolder", "Rename selected folder", state.folderRenameName, 65)
      ImGui.PopItemWidth()
      local folderRenameUnavailable = sanitizeName(state.folderRenameName) == ""
      if folderRenameUnavailable then ImGui.BeginDisabled() end
      if fullWidthButton("Rename Folder", actionButtonHeight) then renameFolder() end
      if folderRenameUnavailable then ImGui.EndDisabled() end
      if fullWidthButton("Duplicate Selected Folder", actionButtonHeight) then duplicateFolder() end
      local moveUnavailable = not state.selected
        or parentFolder(state.selected) == state.selectedFolder
      if moveUnavailable then ImGui.BeginDisabled() end
      if fullWidthButton("Move Selected Preset Here", actionButtonHeight) then movePresetToSelectedFolder() end
      if moveUnavailable then ImGui.EndDisabled() end
      if moveUnavailable then ImGui.TextDisabled(not state.selected
        and "Select a preset under Load Preset before moving it."
        or "The selected preset is already in this destination.")
      end
      if fullWidthButton("Export Folder for Sharing", actionButtonHeight) then
        exportSelectedFolderBundle()
      end
      local removeFolderLabel = state.pendingRemoveFolder == state.selectedFolder
        and "Confirm Remove Folder, Keep Presets"
        or "Remove Folder, Keep Presets"
      if fullWidthButton(removeFolderLabel .. "##removeFolder", actionButtonHeight) then
        removeVirtualFolder()
      end
      local folderBulkNames = bulkPresetNamesInFolder(state.selectedFolder)
      local nestedFolderCount = state.cachedBulkNestedFolderCount or 0
      local folderAction = "folder:" .. state.selectedFolder
      local folderTrashUnavailable = #folderBulkNames == 0
      if folderTrashUnavailable then ImGui.BeginDisabled() end
      local folderTrashLabel = state.pendingBulkAction == folderAction
        and "Confirm Move Folder & Presets to Trash"
        or ("Move Folder & %d Preset%s to Trash")
          :format(#folderBulkNames, #folderBulkNames == 1 and "" or "s")
      if dangerButton(folderTrashLabel .. "##folderTrash",
          ImGui.GetContentRegionAvail(), actionButtonHeight) then
        requestBulkTrash(folderBulkNames, state.selectedFolder)
      end
      if folderTrashUnavailable then ImGui.EndDisabled() end
      coloredWrapped(0.64, 0.67, 0.73, 1.0,
        ("Folder Trash includes %d nested folder%s and remains recoverable.")
          :format(nestedFolderCount, nestedFolderCount == 1 and "" or "s"))
      drawSectionStatus("bulk", "##folderBulkStatus", statusSuccess.bulk, statusHeight)
    else
      local rootMoveUnavailable = not state.selected or parentFolder(state.selected) == ""
      if rootMoveUnavailable then ImGui.BeginDisabled() end
      if fullWidthButton("Move Selected Preset to Root", actionButtonHeight) then movePresetToSelectedFolder() end
      if rootMoveUnavailable then ImGui.EndDisabled() end
      if rootMoveUnavailable then ImGui.TextDisabled(not state.selected
        and "Select a preset under Load Preset before moving it."
        or "The selected preset is already in All Presets.")
      end
      if fullWidthButton("Import Folder Bundles", actionButtonHeight) then
        importAvailableFolderBundles()
      end
      coloredWrapped(0.64, 0.67, 0.73, 1.0,
        "Place .cpmfolder files in Character Presets. Every bundle found there will be processed.")
    end
    if state.folderStatus ~= "" then
      if state.lastLoggedFolderStatus ~= state.folderStatus then
        local level = state.folderStatusError and "error" or "info"
        log(("[FOLDER STATUS] %s"):format(state.folderStatus), level)
        state.lastLoggedFolderStatus = state.folderStatus
      end
    end
    drawSectionStatus("folder", "##folderStatus", statusSuccess.folder, statusHeight)
    end

    if collapsibleSectionHeader("RENAME & COPY", "manage") then
      if not state.selected or not state.presets[state.selected] then
        coloredWrapped(0.64, 0.67, 0.73, 1.0,
          "Select a preset under Load Preset to rename, duplicate, or edit its details.")
      else
        ImGui.TextColored(0.97, 0.72, 0.20, 1.0,
          "Selected preset")
        ImGui.TextWrapped(state.selected)
        ImGui.Spacing()
        ImGui.PushItemWidth(-1)
        state.renameName = ImGui.InputTextWithHint(
          "##renamePreset", "New preset name", state.renameName, 65)
        ImGui.PopItemWidth()
        local renameUnavailable = sanitizeName(state.renameName) == ""
        local manageButtonWidth = (ImGui.GetContentRegionAvail() - 8) * 0.5
        if renameUnavailable then ImGui.BeginDisabled() end
        if ImGui.Button("Rename Preset##renameSelected",
            manageButtonWidth, actionButtonHeight) then renamePreset() end
        if renameUnavailable then ImGui.EndDisabled() end
        ImGui.SameLine()
        if ImGui.Button("Duplicate Preset##duplicateSelected",
            manageButtonWidth, actionButtonHeight) then duplicatePreset() end
        if compactSubsectionButton("Optional Preset Details", "Hide Preset Details",
            "presetDetails") then
          ImGui.Indent(8)
          ImGui.PushItemWidth(-1)
          state.presetTags = ImGui.InputTextWithHint("##presetTags", "Tags", state.presetTags, 129)
          state.presetNotes = ImGui.InputTextWithHint("##presetNotes", "Notes", state.presetNotes, 513)
          ImGui.PopItemWidth()
          if fullWidthButton("Save Preset Details", actionButtonHeight) then
            savePresetMetadata()
          end
          ImGui.Unindent(8)
        end
        drawSectionStatus("rename", "##renameStatus", statusSuccess.rename, statusHeight)
      end
    end

    if collapsibleSectionHeader("DELETE & RESTORE", "trash") then
      ImGui.TextWrapped("Delete presets safely by moving them to recoverable Trash, or restore them later.")
      if not state.selected then
        ImGui.TextDisabled("Select a preset under Load Preset to move one preset to Trash.")
      else
        local deleteLabel = state.pendingDeleteName == state.selected
          and "Confirm Move to Trash##danger"
          or "Move Selected Preset to Trash##danger"
        if dangerButton(deleteLabel, ImGui.GetContentRegionAvail(), actionButtonHeight) then
          trashPreset()
        end
      end

      if compactSubsectionButton("More Trash Options", "Hide More Trash Options",
          "bulkTrash") then
        ImGui.Indent(8)
        drawBulkTrashOptions(actionButtonHeight, statusHeight)
        ImGui.Unindent(8)
      end

      ImGui.Spacing()
      ImGui.Separator()
      ImGui.Spacing()
      ImGui.TextColored(0.97, 0.72, 0.20, 1.0, "Recover from Trash")
      local trashNames = {}
      for filename in pairs(state.trash) do table.insert(trashNames, filename) end
      table.sort(trashNames, function(a, b) return a:lower() < b:lower() end)
      local trashGroupIds = {}
      for groupId in pairs(state.trashGroups) do table.insert(trashGroupIds, groupId) end
      table.sort(trashGroupIds, function(a, b)
        return state.trashGroups[a].root:lower() < state.trashGroups[b].root:lower()
      end)
      if #trashNames == 0 and #trashGroupIds == 0 then
        ImGui.TextDisabled("Trash is empty.")
      else
        ImGui.TextWrapped(("%d recoverable preset%s")
          :format(#trashNames, #trashNames == 1 and "" or "s"))
        ImGui.BeginChild("##trashList", 0, ImGui.GetFontSize() * 6, true)
        local trashChanged = false
        for _, groupId in ipairs(trashGroupIds) do
          local group = state.trashGroups[groupId]
          local groupPresetCount, folderCount = 0, 0
          for _, item in pairs(state.trash) do
            if item.group == groupId then groupPresetCount = groupPresetCount + 1 end
          end
          for _ in pairs(group.folders or {}) do folderCount = folderCount + 1 end
          if fullWidthButton(("Restore Folder %s (%d presets, %d folders)")
              :format(breadcrumb(group.root), groupPresetCount, folderCount) ..
              "##trashGroup:" .. groupId, actionButtonHeight) then
            restoreTrashGroup(groupId)
            trashChanged = true
            break
          end
        end
        if not trashChanged then
          if #trashGroupIds > 0 and #trashNames > 0 then ImGui.Separator() end
          for _, filename in ipairs(trashNames) do
            local item = state.trash[filename]
            if item and fullWidthButton("Restore " .. (item.original or filename) ..
                "##trash:" .. filename, actionButtonHeight) then
              restoreTrashPreset(filename)
              trashChanged = true
              break
            end
          end
        end
        ImGui.EndChild()
        if not trashChanged then
          local emptyLabel = state.pendingEmptyTrash
            and "Confirm Empty Trash Permanently##emptyTrash"
            or "Empty Trash Permanently##emptyTrash"
          if dangerButton(emptyLabel, ImGui.GetContentRegionAvail(), actionButtonHeight) then
            emptyTrash()
          end
        end
      end
      drawSectionStatus("delete", "##trashStatus", statusSuccess.delete, statusHeight)
    end

  end
  ImGui.End()
  popTheme()
end

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
  local config, configLoaded = readConfig()
  state.discoveryNoticeIgnored = not config.discoveryReminder
  state.sortMode = config.presetSort == "modified" and "modified" or "name"
  if not configLoaded then writeConfig() end
  log(state.discoveryNoticeIgnored
    and "[UI] Character-customization discovery reminder is disabled by user preference."
    or "[UI] Character-customization discovery reminder is enabled.", "info")
  log(("[CONFIG] Loaded '%s': discoveryReminder=%s presetSort=%s.")
    :format(CONFIG_FILE, tostring(not state.discoveryNoticeIgnored), state.sortMode), "info")
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
      state.inCustomization = true
      state.clothingCheckDirty = true
      state.cachedClothingLabels = nil
      state.discoveryNoticePending = not state.discoveryNoticeIgnored
      state.discoveryNoticeLayout = nil
      log(state.discoveryNoticeIgnored
        and "[UI] Character customization opened; discovery reminder is ignored."
        or "[UI] Character customization opened; CET menu discovery notice scheduled.", "info")
    end
  )
  local observeExitOk, observeExitError = pcall(
    Observe,
    "characterCreationBodyMorphMenu",
    "OnUninitialize",
    function()
      state.activeBodyMorphMenu = nil
      state.inCustomization = false
      state.clothingCheckDirty = true
      state.cachedClothingLabels = nil
      state.discoveryNoticePending = false
      state.discoveryNoticeLayout = nil
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

  local newGameEnterOk, newGameEnterError = pcall(
    Observe,
    "MenuScenario_CharacterCustomization",
    "OnEnterScenario",
    function()
      state.newGameCharacterCreator = true
    end
  )
  local newGameExitOk, newGameExitError = pcall(
    Observe,
    "MenuScenario_CharacterCustomization",
    "OnLeaveScenario",
    function()
      state.newGameCharacterCreator = false
    end
  )
  if not newGameEnterOk or not newGameExitOk then
    log(("New-game screen tracking unavailable: enter=%s leave=%s")
      :format(tostring(newGameEnterError), tostring(newGameExitError)), "warn")
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
        restoreTemporarilyDisabledWardrobe()
        return wrappedMethod()
      end
      setEditorOpenStatus("Full editor opened.", false)
    end
  )

  state.editorHooksAvailable = (menuObserverOk or menuInitializeObserverOk)
    and pauseOverrideOk and editorOverrideOk
  if not state.editorHooksAvailable then
    log(("Full-editor hooks unavailable: controller=%s initialize=%s pause=%s editor=%s")
      :format(tostring(menuObserverError), tostring(menuInitializeObserverError),
        tostring(pauseOverrideError), tostring(editorOverrideError)), "error")
    setEditorOpenStatus("The full editor is not available with this game or CET version.", true)
  else
    log("[HOOK] Full-editor launch and mirror-unlock hooks registered.", "info")
  end

  local recovered, recoveredOriginals, recoveredAssignments,
    recoveredFolders, recoveredManualFolders = recoverTransaction()
  if recovered then
    refreshPresets("startup", recoveredAssignments, recoveredFolders,
      recoveredManualFolders)
    refreshTrash(recoveredOriginals)
  else
    setStatus("load", "Preset recovery is incomplete. Restart CET after checking file permissions; no preset files were changed further.", true)
  end
  local presetCount = 0
  for _ in pairs(state.presets) do presetCount = presetCount + 1 end
  log(("Preset files loaded: presets=%d directory='%s'")
    :format(presetCount, PRESET_DIR), "info")
  state.ready = true
  refreshEditorState()
  if recovered then
    setStatus("load", "Open the character creator, a mirror, or a ripperdoc to save or load presets.")
  end
end)

registerForEvent("onShutdown", function()
  auditSection("SESSION END")
  log(("[SUMMARY] inputs=%d controllerCaptures=%d pauseRedirects=%d editorPuppets=%d")
    :format(state.editorInputCount, state.editorControllerCaptureCount,
      state.editorPauseRedirectCount, state.editorPuppetReadyCount), "info")
  restoreTemporarilyDisabledWardrobe()
  state.ready = false
  state.inCustomization = false
  state.newGameCharacterCreator = false
  state.clothingCheckDirty = true
  state.cachedClothingLabels = nil
  cancelConfirmations()
  resetLoadState()
  state.activeBodyMorphMenu = nil
  state.inGameMenuController = nil
  state.editorOpenPending = false
  state.editorOpenTimer = 0
  state.editorOpenedByLauncher = false
  state.editorHooksAvailable = false
  state.discoveryNoticePending = false
  state.discoveryNoticeLayout = nil
end)

registerForEvent("onUpdate", function(delta)
  local elapsed = tonumber(delta) or 0
  local updateStatuses = state.overlayOpen and state.windowOpen
  if not updateStatuses then state.statusUpdateTimer = 0 end
  if not updateStatuses
      and not state.editorOpenPending
      and not state.autoLoad then
    return
  end
  if updateStatuses then
    state.statusUpdateTimer = state.statusUpdateTimer + elapsed
    if state.statusUpdateTimer >= STATUS_UPDATE_INTERVAL then
      updateStatusTimers(state.statusUpdateTimer)
      state.statusUpdateTimer = 0
    end
  end
  if state.editorOpenPending then
    state.editorOpenTimer = state.editorOpenTimer + elapsed
    if state.editorOpenTimer >= EDITOR_OPEN_TIMEOUT then
      state.editorOpenPending = false
      state.editorOpenTimer = 0
      restoreTemporarilyDisabledWardrobe()
      setEditorOpenStatus("The editor did not open. Return to normal gameplay and retry.", true)
    end
  end
  if not state.autoLoad then return end

  if not state.loadNeedsContinue then
    state.autoLoad = false
    state.autoLoadTimer = 0
    state.autoLoadPasses = 0
    return
  end

  state.autoLoadTimer = state.autoLoadTimer + elapsed
  if state.autoLoadTimer < AUTO_LOAD_INTERVAL then return end
  state.autoLoadTimer = 0

  if not state.selected then
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
  if state.discoveryNoticePending then
    state.discoveryNoticePending = false
    state.discoveryNoticeLayout = nil
    log("[UI] Character-customization CET discovery notification acknowledged.", "info")
  end
  state.overlayOpen = true
  state.windowOpen = true
  state.bindingCache = {}
  state.windowPositionCached = false
  state.cachedWindowX = nil
  state.cachedDisplayWidth = nil
  state.statusUpdateTimer = 0
  refreshPresets("external")
  refreshTrash()
  refreshEditorState()
  refreshPreflight()
end)
registerForEvent("onOverlayClose", function()
  log("[UI] CET overlay closed.", "info")
  state.overlayOpen = false
  state.statusUpdateTimer = 0
  cancelConfirmations()
end)
registerForEvent("onDraw", function()
  if state.discoveryNoticePending and not state.discoveryNoticeIgnored
      and not state.overlayOpen then
    local noticeOk, noticeError = pcall(drawDiscoveryHudNotice)
    if not noticeOk then
      state.discoveryNoticePending = false
      state.discoveryNoticeLayout = nil
      log("[UI] Discovery notification rendering disabled after an error: " ..
        tostring(noticeError), "error")
    end
  end
  if state.overlayOpen and state.windowOpen then draw() end
end)
registerHotkey("vanilla_character_presets_toggle", "Toggle Character Preset Manager (CET)", function()
  state.windowHotkeyCount = state.windowHotkeyCount + 1
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
