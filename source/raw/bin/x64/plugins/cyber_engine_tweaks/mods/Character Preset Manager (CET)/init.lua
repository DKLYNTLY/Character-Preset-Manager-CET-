
local MOD_NAME = "Character Preset Manager (CET)"
local VERSION = "3.0.4"
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
local DISCOVERY_NOTICE_MESSAGE = "Press the key you assigned to the CET Overlay."
local DISCOVERY_NOTICE_SETTINGS_MESSAGE = "You can turn off this message in Settings."
local LOG_ARCHIVE_LIMIT = 10
local CURRENT_PRESET_FORMAT = 8
local activitySequence = 0

local AUTO_LOAD_TIMING = {
  interval = 0.10,
  pollInterval = 0.05,
  settleTimeout = 0.20,
  dependencyTimeout = 1.25,
  dependencyStableTime = 0.20,
}
local PREFLIGHT_REFRESH_INTERVAL = 0.75
local AUTO_LOAD_LIMITS = {
  minimumSeconds = 60,
  secondsPerOption = 2,
  maximumScannedPresets = 8192,
  maximumScannedEntries = 1048576,
}
local STALL_CONFIRMATION_PASSES = 3
local EDITOR_OPEN_TIMEOUT = 5.0
local MAX_TREE_DEPTH = 12
local MAX_PRESET_BYTES = 1048576
local MAX_PRESET_ENTRIES = 4096
local MAX_PRESET_LINES = MAX_PRESET_ENTRIES * 4 + 64
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
    loadDetails = false,
    folderBundleFiles = false,
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
  loadOrderedEntries = nil,
  loadSavedEntryByKey = nil,
  loadSavedSlotCounts = nil,
  loadValueCount = 0,
  loadForcedKeys = {},
  loadResolvedChoiceIndexes = {},
  loadApplyAttempts = {},
  loadUnconfirmed = {},
  loadCleanupAttempts = {},
  loadCleanupSkipped = {},
  loadLoggedWarnings = {},
  loadOptionIdentityCache = {},
  loadMetadataCache = nil,
  loadMetadataHits = 0,
  loadMetadataMisses = 0,
  loadTargetPolls = 0,
  loadTargetPollSeconds = 0,
  loadTargetFallbacks = 0,
  loadPendingChange = nil,
  loadPendingElapsed = 0,
  loadPhase = "apply",
  loadElapsed = 0,
  loadOptionsSeconds = 0,
  loadScanSeconds = 0,
  loadChoiceSeconds = 0,
  loadApplySeconds = 0,
  loadWaitSeconds = 0,
  loadOptionCalls = 0,
  loadStructureChanges = 0,
  loadLastStructureSignature = nil,
  loadLastStructureDescriptors = nil,
  loadMetadataDisabled = false,
  loadReturnToCleanup = false,
  loadDependencyKeys = {},
  loadDependencyRemaps = {},
  loadNextInterval = AUTO_LOAD_TIMING.interval,
  forceFullLoad = false,
  pendingOverwriteName = nil,
  pendingOverwriteFingerprint = nil,
  pendingDeleteName = nil,
  pendingDeleteFingerprint = nil,
  pendingRemoveFolder = nil,
  selectedBundleFile = nil,
  helpOpen = false,
  debugOpen = false,
  settingsOpen = false,
  settingsStatus = "",
  debugLogText = "",
  debugLogLines = {},
  bindingCache = {},
  autoLoad = false,
  autoLoadTimer = 0,
  autoLoadPasses = 0,
  preflight = nil,
  preflightDirty = true,
  preflightPresetName = nil,
  preflightTimer = 0,
  trash = {},
  trashGroups = {},
  trashBundles = {},
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
  folderBundleFilesDirty = true,
  cachedFolderBundleFiles = {},
  trashViewDirty = true,
  cachedTrashNames = {},
  cachedTrashGroupIds = {},
  cachedTrashBundleNames = {},
  cachedTrashGroupStats = {},
  windowPositionCached = false,
  cachedWindowX = nil,
  cachedWindowY = nil,
  cachedDisplayWidth = nil,
  clothingCheckDirty = true,
  cachedClothingLabels = nil,
  clothingCheckNextAt = 0,
  statusKinds = {},
}

local STATUS_SECTIONS = { "editor", "load", "create", "folder", "rename", "delete", "bulk" }

local function fileExists(path)
  local file = io.open(path, "rb")
  if not file then return false end
  file:close()
  return true
end

local function isFolderBundleFilename(filename)
  return type(filename) == "string" and filename ~= ""
    and #filename <= 255 and not filename:find("/", 1, true)
    and not filename:find("\\", 1, true) and not filename:find("%c")
    and filename:lower():sub(-#FOLDER_BUNDLE_EXTENSION) == FOLDER_BUNDLE_EXTENSION
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
  local hash, secondHash, bytesRead = 0, 0, 0
  local ok = pcall(function()
    while true do
      local chunk = file:read(FILE_COPY_CHUNK_SIZE)
      if not chunk then break end
      bytesRead = bytesRead + #chunk
      for index = 1, #chunk do
        local byte = chunk:byte(index)
        hash = (hash * 131 + byte) % 2147483647
        secondHash = (secondHash * 137 + byte) % 2147483629
      end
    end
  end)
  local closeOk, closeResult = pcall(file.close, file)
  if not ok or bytesRead ~= fileSize
      or not closeOk or closeResult == nil then return nil end
  local legacy = tostring(bytesRead) .. ":" .. tostring(hash)
  return "2:" .. legacy .. ":" .. tostring(secondHash), legacy
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
  state.loadOrderedEntries = nil
  state.loadSavedEntryByKey = nil
  state.loadSavedSlotCounts = nil
  state.loadValueCount = 0
  state.loadForcedKeys = {}
  state.loadResolvedChoiceIndexes = {}
  state.loadApplyAttempts = {}
  state.loadUnconfirmed = {}
  state.loadCleanupAttempts = {}
  state.loadCleanupSkipped = {}
  state.loadLoggedWarnings = {}
  state.loadOptionIdentityCache = {}
  state.loadMetadataCache = nil
  state.loadMetadataHits = 0
  state.loadMetadataMisses = 0
  state.loadTargetPolls = 0
  state.loadTargetPollSeconds = 0
  state.loadTargetFallbacks = 0
  state.loadPendingChange = nil
  state.loadPendingElapsed = 0
  state.loadPhase = "apply"
  state.loadElapsed = 0
  state.loadOptionsSeconds = 0
  state.loadScanSeconds = 0
  state.loadChoiceSeconds = 0
  state.loadApplySeconds = 0
  state.loadWaitSeconds = 0
  state.loadOptionCalls = 0
  state.loadStructureChanges = 0
  state.loadLastStructureSignature = nil
  state.loadLastStructureDescriptors = nil
  state.loadMetadataDisabled = false
  state.loadReturnToCleanup = false
  state.loadDependencyKeys = {}
  state.loadDependencyRemaps = {}
  state.loadNextInterval = AUTO_LOAD_TIMING.interval
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

local function logTimestamp()
  local ok, value = pcall(os.date, "%Y-%m-%d %H:%M:%S")
  if ok and value then return value end
  return "unknown-time"
end

local helpers = {}
local closeActivityLog

local activityLogFile = nil

closeActivityLog = function()
  if not activityLogFile then return true end
  local file = activityLogFile
  activityLogFile = nil
  local flushOk, flushResult = pcall(file.flush, file)
  local closeOk, closeResult = pcall(file.close, file)
  return flushOk and flushResult ~= nil and closeOk and closeResult ~= nil
end

local function writeLog(message, level)
  if not activityLogFile then activityLogFile = io.open(LOG_FILE, "a") end
  local file = activityLogFile
  if not file then return false end
  activitySequence = activitySequence + 1
  local wrote, writeResult = pcall(file.write, file,
    ("[%s] [#%04d] [%s] %s\n"):format(
      logTimestamp(),
      activitySequence,
      tostring(level or "info"):upper(),
      tostring(message)
    ))
  if not wrote or writeResult == nil then
    closeActivityLog()
    return false
  end
  local normalizedLevel = tostring(level or "info"):lower()
  if normalizedLevel:find("error", 1, true)
      or normalizedLevel:find("warn", 1, true)
      or normalizedLevel == "complete" then
    local flushOk, flushResult = pcall(file.flush, file)
    if not flushOk or flushResult == nil then
      closeActivityLog()
      return false
    end
  end
  return true
end

helpers.pruneLogArchives = function()
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

helpers.archiveLogForNewSession = function()
  closeActivityLog()
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
      archiveName = LOG_ARCHIVE_DIR .. "/" ..
        LOG_ARCHIVE_PREFIX .. tostring(timestamp) ..
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

    local deleted, pruneError = helpers.pruneLogArchives()

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

local function setStatus(section, message, isError, kind)
  local effectiveError = isError == true
  state[section .. "Status"] = message
  state[section .. "StatusError"] = effectiveError
  state.statusKinds[section] = kind or (effectiveError and "error" or "info")
  if section == "load" then
    local transient = message:find("Applied one option.", 1, true) == 1
      or message:find("Cleared a remaining option.", 1, true) == 1
      or message:find("Cleanup complete.", 1, true) == 1
      or message:find("Recent changes were applied.", 1, true) == 1
      or message:find("The editor options changed.", 1, true) == 1
      or message:find("Pass ", 1, true) == 1
    if transient and not effectiveError then return end
    local level = "load"
    if effectiveError then
      level = "load error"
    elseif kind == "success" then
      level = "complete"
    end
    log(message, level)
  else
    log(("[%s] %s"):format(section, message), isError and "error" or "info")
  end
end

local function clearStatus(section)
  state[section .. "Status"] = ""
  state[section .. "StatusError"] = false
  state.statusKinds[section] = nil
end

helpers.clearSectionStatuses = function()
  for _, section in ipairs(STATUS_SECTIONS) do
    clearStatus(section)
  end
  state.lastLoggedFolderStatus = nil
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

local isCustomizationActive
local refreshPreflight

local function setEditorOpenStatus(message, isError, kind)
  state.editorStatus = message
  state.editorStatusError = isError == true
  state.statusKinds.editor = kind or (isError and "error" or "info")
  log("[editor] " .. tostring(message), isError and "error" or "info")
end

helpers.activeWardrobeSetEquipped = function()
  local playerOk, player = pcall(Game.GetPlayer)
  if not playerOk or not player then return false, nil end
  local setOk, activeSet = pcall(EquipmentSystem.GetActiveWardrobeSetID, player)
  if not setOk or activeSet == nil then return false, player end
  return activeSet ~= gameWardrobeClothingSetIndex.INVALID, player
end

helpers.equippedClothingLabels = function()
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
  local active, player = helpers.activeWardrobeSetEquipped()
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
  local systemOk, system = pcall(Game.GetCharacterCustomizationSystem)
  if not systemOk or not system then
    return nil, nil, "Character customization system is unavailable"
  end
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

local function optionSlot(option)
  if not option or not option.info then return nil end
  local ok, slot = pcall(function()
    local value = option.info.uiSlot
    if value == nil then return nil end
    if NameToString then return NameToString(value) end
    return tostring(value)
  end)
  slot = ok and tostring(slot or "") or ""
  if slot == "" or #slot > MAX_PRESET_KEY_BYTES or slot:find("%c") then return nil end
  return slot
end

local function isRuntimePointerText(value)
  value = tostring(value or "")
  return value:match("^userdata: 0x%x+$") ~= nil
    or value:match("^table: 0x%x+$") ~= nil
    or value:match("^function: 0x%x+$") ~= nil
    or value:match("^thread: 0x%x+$") ~= nil
end

local function stableRuntimeValue(value)
  if value == nil then return nil end
  if type(value) == "string" then
    if value == "" or isRuntimePointerText(value) then
      return nil
    end
    return value
  end
  local nameOk, name = pcall(function()
    if NameToString then return NameToString(value) end
    return nil
  end)
  local nameText = nameOk and name and tostring(name) or ""
  if nameText ~= "" and not isRuntimePointerText(nameText) then return nameText end
  local textOk, text = pcall(tostring, value)
  text = textOk and tostring(text or "") or ""
  if isRuntimePointerText(text) then return nil end
  return text ~= "" and text or nil
end

local function stableChoiceIdentity(choice)
  local field, value = tostring(choice or ""):match("^([%a]+):(.*)$")
  if value == "" or (field ~= "definitions" and field ~= "options"
      and field ~= "morphNames") then return nil end
  if isRuntimePointerText(value) then return nil end
  return field .. ":" .. value
end

local function choiceCollectionValue(info, field, index, member)
  local ok, value = pcall(function()
    local collection = info and info[field]
    if collection == nil then return nil end
    local item = collection[index + 1]
    if item == nil then return nil end
    return member and item[member] or item
  end)
  return ok and stableRuntimeValue(value) or nil
end

helpers.optionChoiceKey = function(option, index)
  if not option or not option.info or type(index) ~= "number"
      or index ~= math.floor(index) or index < 0 or index > MAX_OPTION_INDEX then return nil end
  for _, source in ipairs({
    { "definitions", nil },
    { "options", "localizedName" },
    { "morphNames", nil },
  }) do
    local value = choiceCollectionValue(option.info, source[1], index, source[2])
    if value then return source[1] .. ":" .. value end
  end
  return nil
end

local function optionChoiceIndex(option, choice)
  choice = stableChoiceIdentity(choice)
  local field, wanted = tostring(choice or ""):match("^([%a]+):(.*)$")
  if not option or not option.info or wanted == ""
      or (field ~= "definitions" and field ~= "options" and field ~= "morphNames") then
    return nil
  end
  local member = field == "options" and "localizedName" or nil
  local sizeOk, size = pcall(function() return #(option.info[field] or {}) end)
  if not sizeOk or type(size) ~= "number" or size > MAX_OPTION_INDEX then return nil end
  local match = nil
  for index = 0, size - 1 do
    if choiceCollectionValue(option.info, field, index, member) == wanted then
      if match ~= nil then return nil end
      match = index
    end
  end
  return match
end

local function optionChoiceMatchesIndex(option, choice, index)
  choice = stableChoiceIdentity(choice)
  local field, wanted = tostring(choice or ""):match("^([%a]+):(.*)$")
  index = tonumber(index)
  if not option or not option.info or wanted == "" or not index
      or index ~= math.floor(index) or index < 0 or index > MAX_OPTION_INDEX then
    return false
  end
  local member = field == "options" and "localizedName" or nil
  return choiceCollectionValue(option.info, field, index, member) == wanted
end

helpers.optionDisplayName = function(option, key)
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
    :format(helpers.optionDisplayName(option, key), tostring(key or "unknown"),
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

helpers.ignoreDiscoveryNotice = function()
  state.discoveryNoticeIgnored = true
  state.discoveryNoticePending = false
  state.discoveryNoticeLayout = nil
  local saved = writeConfig and writeConfig()
  log(saved and "[UI] Discovery reminder disabled by the user."
    or "[UI] Discovery reminder disabled for this session; config could not be saved.",
    saved and "info" or "warn")
  return saved == true
end

helpers.restoreDiscoveryNotice = function()
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
  if state.invalidatePreflight then state.invalidatePreflight() end
end

local function invalidatePresetAndTrashCaches()
  invalidateViewCache()
  if state.invalidateTrashViewCache then state.invalidateTrashViewCache() end
end

helpers.rebuildViewCache = function()
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
  if state.viewCacheDirty then helpers.rebuildViewCache() end
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

helpers.presetsInFolder = function(folder)
  ensureViewCache()
  return state.cachedPresetsByFolder[folder] or EMPTY_LIST
end

helpers.rebuildFilteredViewCache = function()
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
    helpers.rebuildFilteredViewCache()
  end
end

helpers.filteredPresetNames = function()
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

helpers.readCatalog = function()
  local assignments, folders, ignored = {}, {}, {}
  local file = io.open(CATALOG_FILE, "rb")
  if not file then return assignments, folders, ignored, nil end
  local sizeOk, size = pcall(file.seek, file, "end")
  local rewindOk, rewindResult = pcall(file.seek, file, "set", 0)
  if not sizeOk or not size or size > MAX_CATALOG_BYTES
      or not rewindOk or rewindResult == nil then
    file:close()
    log("[FOLDER LIST] The saved folder list cannot be read or is larger than the safety limit.", "error")
    return assignments, folders, ignored, false
  end
  local lineCount = 0
  for line in file:lines() do
    lineCount = lineCount + 1
    if lineCount > MAX_CATALOG_LINES then
      file:close()
      log("[FOLDER LIST] The saved folder list has too many lines.", "error")
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
      log(("[FOLDER LIST] Line %d in the saved folder list is invalid."):format(lineCount), "error")
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

local function readPresetFile(path, metadataOnly)
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
  local entryCount = 0
  local metadata = { format = 4, source = "Legacy or ACU-compatible" }
  local lineNumber, malformed, pendingSlot, pendingChoice = 0, 0, nil, nil
  local readableFormatConfirmed = false
  local lastEntry = nil
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
    elseif not metadataOnly and metadataKey == "slot" then
      local slot = catalogDecode(metadataValue)
      pendingSlot = #slot <= MAX_PRESET_KEY_BYTES and not slot:find("%c")
        and slot or nil
    elseif not metadataOnly and metadataKey == "choice" then
      local choice = catalogDecode(metadataValue)
      pendingChoice = #choice <= MAX_PRESET_KEY_BYTES * 4 and not choice:find("%c")
        and stableChoiceIdentity(choice) or nil
    end
    local readableKey, readableValue = line:match("^# ([%a ]+):%s?(.*)$")
    if readableKey == "Format" and entryCount == 0 then
      local readableFormat = tonumber(readableValue)
      if readableFormat and readableFormat >= CURRENT_PRESET_FORMAT then
        metadata.format = readableFormat
        readableFormatConfirmed = true
      end
    elseif readableFormatConfirmed and readableKey == "Source" then
      metadata.source = sanitizeMetadata(readableValue, 128)
    elseif readableFormatConfirmed and readableKey == "Created" then
      metadata.created = sanitizeMetadata(readableValue, 64)
    elseif readableFormatConfirmed and readableKey == "Modified" then
      metadata.modified = sanitizeMetadata(readableValue, 64)
    elseif readableFormatConfirmed and readableKey == "Notes" then
      metadata.notes = sanitizeMetadata(readableValue, 512)
    elseif readableFormatConfirmed and readableKey == "Tags" then
      metadata.tags = sanitizeMetadata(readableValue, 128)
    elseif not metadataOnly and readableFormatConfirmed
        and readableKey == "Editor slot" and lastEntry then
      local slot = sanitizeMetadata(readableValue, MAX_PRESET_KEY_BYTES)
      lastEntry.slot = slot ~= "" and slot or nil
    elseif not metadataOnly and readableFormatConfirmed
        and readableKey == "Saved choice" and lastEntry then
      lastEntry.choice = stableChoiceIdentity(
        sanitizeMetadata(readableValue, MAX_PRESET_KEY_BYTES * 4))
    end
    local key, index = nil, nil
    if not line:match("^#") then
      key, index = line:match("^%s*(.-):(-?%d+)%s*$")
    end
    local numericIndex = tonumber(index)
    if key and key ~= "" then
      local indexError = optionIndexValidationError(numericIndex)
      if #key > MAX_PRESET_KEY_BYTES
          or indexError
          or entryCount >= MAX_PRESET_ENTRIES then
        file:close()
        log(("[FILES] Preset rejected at line %d: file='%s' keyBytes=%d index='%s' indexError='%s' entriesBefore=%d.")
          :format(lineNumber, path, #key, tostring(index),
            tostring(indexError or "none"), entryCount), "warn")
        return nil
      end
      entryCount = entryCount + 1
      if not metadataOnly then
        lastEntry = {
          key = key,
          index = numericIndex,
          slot = pendingSlot,
          choice = pendingChoice,
        }
        table.insert(entries, lastEntry)
      else
        lastEntry = nil
      end
      pendingSlot, pendingChoice = nil, nil
    elseif not metadataKey and line:match("%S") and not line:match("^#") then
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
  if entryCount == 0 then return nil end
  return {
    format = metadata.format,
    source = metadata.source,
    created = metadata.created,
    modified = metadata.modified,
    notes = metadata.notes or "",
    tags = metadata.tags or "",
    entries = not metadataOnly and entries or nil,
    entryCount = entryCount,
    entryCountKnown = true,
    lazy = metadataOnly == true,
  }
end

state.presetEntryCount = function(preset)
  if not preset then return 0 end
  if preset.entries then return #preset.entries end
  return tonumber(preset.entryCount) or 0
end

state.hydratePreset = function(preset, path)
  if not preset then return nil end
  if preset.entries then return preset end
  local loaded = readPresetFile(path)
  if not loaded then return nil end
  local storage = preset.storage
  for key in pairs(preset) do preset[key] = nil end
  for key, value in pairs(loaded) do preset[key] = value end
  preset.storage = storage
  preset.fingerprint = fileFingerprint(path, MAX_PRESET_BYTES)
  preset.lazy = false
  return preset
end

local function hydrateNamedPreset(name)
  local preset = name and state.presets[name]
  if not preset then return nil end
  return state.hydratePreset(preset, presetPath(name))
end

state.invalidatePreflight = function()
  state.preflight = nil
  state.preflightDirty = true
  state.preflightPresetName = nil
  state.preflightTimer = 0
end

local function writePresetContents(path, preset)
  local file = io.open(path, "w")
  if not file then return false end
  local wrote, writeResult = pcall(function()
    local format = tonumber(preset.format) or 5
    if format >= CURRENT_PRESET_FORMAT then
      local header = {
        "# Character Preset Manager (CET) preset",
        "# Format: " .. tostring(format),
        "# Source: " .. sanitizeMetadata(preset.source or MOD_NAME, 128),
        "# Created: " .. sanitizeMetadata(preset.created or "", 64),
        "# Modified: " .. sanitizeMetadata(preset.modified or "", 64),
        "# Notes: " .. sanitizeMetadata(preset.notes, 512),
        "# Tags: " .. sanitizeMetadata(preset.tags, 128),
        "#",
        "# Appearance options",
        "# Each main line is OptionKey:SavedNumber.",
        "# Editor slot and Saved choice lines describe the option above them.",
        "",
      }
      for _, line in ipairs(header) do
        if not file:write(line .. "\n") then return false end
      end
      for _, entry in ipairs(preset.entries or {}) do
        if not file:write(("%s:%d\n"):format(
            tostring(entry.key), tonumber(entry.index) or 0)) then return false end
        if entry.slot and entry.slot ~= "" then
          if not file:write("# Editor slot: " ..
              sanitizeMetadata(entry.slot, MAX_PRESET_KEY_BYTES) .. "\n") then return false end
        end
        if entry.choice and entry.choice ~= "" then
          if not file:write("# Saved choice: " ..
              sanitizeMetadata(entry.choice, MAX_PRESET_KEY_BYTES * 4) .. "\n") then return false end
        end
        if not file:write("\n") then return false end
      end
      return file:flush() ~= nil
    end
    local metadata = {
      { "format", tostring(format) },
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
      if entry.slot and entry.slot ~= "" then
        local slotResult = file:write("# CPM\tslot\t" .. catalogEncode(entry.slot) .. "\n")
        if not slotResult then return false end
      end
      if entry.choice and entry.choice ~= "" then
        local choiceResult = file:write("# CPM\tchoice\t" .. catalogEncode(entry.choice) .. "\n")
        if not choiceResult then return false end
      end
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
    if not recovered then return false end
  end
  os.remove(temporary)
  if not writeTemporary(temporary) then
    os.remove(temporary)
    log(("[FILES] Could not write temporary %s '%s'."):format(description, temporary), "error")
    return false
  end
  if os.rename(temporary, path) then
    os.remove(backup)
    return true
  end

  os.remove(backup)
  local movedOriginal = os.rename(path, backup)
  if not movedOriginal then
    os.remove(temporary)
    return false
  end
  if not os.rename(temporary, path) then
    local restored, restoreError = os.rename(backup, path)
    if restored then
      os.remove(temporary)
    else
      log(("[FILES] Could not restore backup after replacing %s: backup='%s' target='%s' temporary='%s' error=%s")
        :format(description, backup, path, temporary, tostring(restoreError)), "error")
    end
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
    log("[FOLDER LIST] The folder list has more entries than the safety limit.", "error")
    return false
  end
  local catalogBytes = 0
  for _, line in ipairs(lines) do catalogBytes = catalogBytes + #line + 1 end
  if catalogBytes > MAX_CATALOG_BYTES then
    log("[FOLDER LIST] The folder list is larger than the safety limit.", "error")
    return false
  end
  local result, changed = writeLinesIfChanged(
    CATALOG_FILE, lines, "folder list", MAX_CATALOG_BYTES)
  log(("[CATALOG] Saved presets=%d folders=%d ignoredPhysicalFolders=%d success=%s.")
    :format(
      (function() local count = 0; for _ in pairs(presets or {}) do count = count + 1 end; return count end)(),
      (function() local count = 0; for _ in pairs(folders or {}) do count = count + 1 end; return count end)(),
      (function() local count = 0; for _ in pairs(ignoredPhysicalFolders or {}) do count = count + 1 end; return count end)(),
      tostring(result)), result and "info" or "error")
  if result and not changed then
    log("[FOLDER LIST] The saved folder list is already current. No file update was needed.", "info")
  end
  return result
end

local function writePresetPath(path, preset)
  local wrote = atomicReplace(path, function(temporary)
    if not writePresetContents(temporary, preset) then return false end
    return presetsMatch(preset, readPresetFile(temporary))
  end, "preset")
  if wrote then preset.fingerprint = fileFingerprint(path, MAX_PRESET_BYTES) end
  return wrote
end

presetsMatch = function(expected, actual)
  local expectedEntries = expected and expected.entries or {}
  local actualEntries = actual and actual.entries or {}
  if expected and actual and expected.fingerprint and actual.fingerprint then
    return expected.fingerprint == actual.fingerprint
  end
  if state.presetEntryCount(expected) ~= state.presetEntryCount(actual) then return false end
  if (tonumber(expected and expected.format) or 4) >= 5 then
    for _, key in ipairs({ "format", "source", "created", "modified", "notes", "tags" }) do
      if tostring(expected[key] or "") ~= tostring(actual and actual[key] or "") then
        return false
      end
    end
  end
  if not expected or not actual or not expected.entries or not actual.entries then
    return true
  end
  for index, entry in ipairs(expectedEntries) do
    local other = actualEntries[index]
    if not other
        or tostring(entry.key) ~= tostring(other.key)
        or (tonumber(entry.index) or 0) ~= (tonumber(other.index) or 0) then
      return false
    end
    if (tonumber(expected and expected.format) or 4) >= 6
        and tostring(entry.slot or "") ~= tostring(other.slot or "") then return false end
    if (tonumber(expected and expected.format) or 4) >= 7
        and tostring(entry.choice or "") ~= tostring(other.choice or "") then return false end
  end
  return true
end

local function readVerifiedPresetCopy(expected, path)
  local copy = readPresetFile(path)
  if not copy or not presetsMatch(expected, copy) then return nil end
  copy.fingerprint = fileFingerprint(path, MAX_PRESET_BYTES)
  return copy
end

helpers.readInventory = function()
  local presets, folders = {}, {}
  local contents, readError = readBoundedFile(INVENTORY_FILE, MAX_CATALOG_BYTES)
  if not contents then
    if readError ~= "missing" then
      log("[INVENTORY] The preset file list is unreadable or too large; it was not used as the startup comparison.", "warn")
    end
    return presets, folders, false
  end
  local lineCount = 0
  for line in (contents .. "\n"):gmatch("(.-)\n") do
    if line ~= "" then
      lineCount = lineCount + 1
      if lineCount > MAX_CATALOG_LINES then
        log("[INVENTORY] The preset file list has too many lines; it was not used as the startup comparison.", "warn")
        return {}, {}, false
      end
      local encodedName, count, format, encodedModified, fingerprint =
        line:match("^P2\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]*)\t([^\t]+)$")
      local kind, name = line:match("^([PF]):(.*)$")
      if encodedName then
        name = catalogDecode(encodedName)
        local entryCount = count ~= "-" and tonumber(count) or nil
        local presetFormat = format ~= "-" and tonumber(format) or nil
        if not validRelativePath(name)
            or (count ~= "-" and not entryCount)
            or (format ~= "-" and not presetFormat)
            or (entryCount and (entryCount < 1 or entryCount > MAX_PRESET_ENTRIES))
            or (presetFormat and presetFormat < 1)
            or (fingerprint ~= "-" and not fingerprint:match("^2:%d+:%d+:%d+$")) then
          log("[INVENTORY] The preset file list contains an invalid preset record; it was not used as the startup comparison.", "warn")
          return {}, {}, false
        end
        presets[name] = {
          entryCount = entryCount or 0,
          entryCountKnown = entryCount ~= nil,
          format = presetFormat,
          modified = catalogDecode(encodedModified),
          fingerprint = fingerprint ~= "-" and fingerprint or nil,
          lazy = true,
        }
      elseif kind == "P" and validRelativePath(name) then
        presets[name] = true
      elseif kind == "F" and validRelativePath(name) then
        folders[name] = true
      else
        log("[INVENTORY] The preset file list contains an invalid line; it was not used as the startup comparison.", "warn")
        return {}, {}, false
      end
    end
  end
  return presets, folders, true
end

local function writeInventory(presets, folders)
  local lines = {}
  for name, preset in pairs(presets or {}) do
    local count = preset and preset.entryCountKnown == true
      and state.presetEntryCount(preset) or nil
    local format = tonumber(preset and preset.format)
    table.insert(lines, "P2\t" .. catalogEncode(name) .. "\t" ..
      (count and tostring(count) or "-") .. "\t" ..
      (format and tostring(format) or "-") .. "\t" ..
      catalogEncode(preset and preset.modified or "") .. "\t" ..
      tostring(preset and preset.fingerprint or "-"))
  end
  for name in pairs(folders or {}) do table.insert(lines, "F:" .. name) end
  table.sort(lines, function(a, b) return a:lower() < b:lower() end)
  local result, changed = writeLinesIfChanged(
    INVENTORY_FILE, lines, "preset file list", MAX_CATALOG_BYTES)
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

local function cleanupFailureMessage(paths, cleanedMessage, leftoverMessage)
  return removeFileList(paths) and cleanedMessage or leftoverMessage
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
local folderBundleFiles
local trashSelectedFolderBundle

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

local function writeHexFile(output, path)
  local input = io.open(path, "rb")
  if not input then return false, nil end
  local sizeOk, size = pcall(input.seek, input, "end")
  local rewindOk, rewindResult = pcall(input.seek, input, "set", 0)
  if not sizeOk or not size or size > MAX_PRESET_BYTES
      or not rewindOk or rewindResult == nil then
    input:close()
    return false, size
  end
  local readBytes = 0
  local writeOk, writeResult = pcall(function()
    while true do
      local chunk = input:read(FILE_COPY_CHUNK_SIZE)
      if not chunk then break end
      readBytes = readBytes + #chunk
      if not output:write(hexEncode(chunk)) then return false end
    end
    return readBytes == size
  end)
  local closeOk, closeResult = pcall(input.close, input)
  return writeOk and writeResult == true and closeOk and closeResult ~= nil, size
end

folderBundleFiles = function(forceRefresh)
  if not forceRefresh and not state.folderBundleFilesDirty then
    return state.cachedFolderBundleFiles
  end
  local bundles = {}
  local entries = safeDirectoryEntries(PRESET_DIR, 0)
  if not entries then return state.cachedFolderBundleFiles end
  for _, entry in ipairs(entries) do
    if entry.type == "file"
        and entry.name:lower():sub(-#FOLDER_BUNDLE_EXTENSION) == FOLDER_BUNDLE_EXTENSION then
      table.insert(bundles, PRESET_DIR .. "/" .. entry.name)
    end
  end
  table.sort(bundles, function(a, b) return a:lower() < b:lower() end)
  state.cachedFolderBundleFiles = bundles
  state.folderBundleFilesDirty = false
  return state.cachedFolderBundleFiles
end

local function uniqueTrashedBundleFilename(filename)
  local stem = filename:sub(1, -#FOLDER_BUNDLE_EXTENSION - 1)
  for index = 1, 9999 do
    local suffix = index == 1 and "" or (" %d"):format(index)
    local candidate = stem:sub(1, 255 - #FOLDER_BUNDLE_EXTENSION - #suffix) ..
      suffix .. FOLDER_BUNDLE_EXTENSION
    if not fileExists(TRASH_DIR .. "/" .. candidate) then return candidate end
  end
  return nil
end

trashSelectedFolderBundle = function()
  state.statusKinds.folder = nil
  auditSection("TRASH FOLDER BUNDLE")
  local selected = state.selectedBundleFile
  if not isFolderBundleFilename(selected) then
    state.folderStatus, state.folderStatusError =
      "Select a shared-folder file to move to Trash.", true
    return
  end
  local selectedPath = nil
  for _, path in ipairs(folderBundleFiles(true)) do
    local leaf = path:match("([^/]+)$")
    if leaf and leaf:lower() == selected:lower() then
      selected, selectedPath = leaf, path
      break
    end
  end
  if not selectedPath then
    state.selectedBundleFile = nil
    state.folderStatus, state.folderStatusError =
      "That shared-folder file is no longer available.", true
    return
  end
  local fingerprint = fileFingerprint(selectedPath, MAX_FOLDER_BUNDLE_BYTES)
  if not fingerprint then
    state.folderStatus, state.folderStatusError =
      "The selected shared-folder file could not be checked safely.", true
    return
  end
  local trashFilename = uniqueTrashedBundleFilename(selected)
  if not trashFilename then
    state.folderStatus, state.folderStatusError =
      "The mod could not create a safe Trash file name for the shared folder.", true
    return
  end
  local trashPath = TRASH_DIR .. "/" .. trashFilename
  local moved, moveError = os.rename(selectedPath, trashPath)
  if not moved then
    state.folderStatus, state.folderStatusError =
      ("The shared-folder file could not be moved to Trash: %s"):format(tostring(moveError)), true
    return
  end
  if fileFingerprint(trashPath, MAX_FOLDER_BUNDLE_BYTES) ~= fingerprint then
    local rolledBack = os.rename(trashPath, selectedPath) ~= nil
    state.folderStatus, state.folderStatusError = rolledBack
      and "Folder bundle verification failed; the file was returned to Character Presets."
      or "Folder bundle verification failed, and the file could not be returned from Trash.", true
    return
  end
  state.trashBundles[trashFilename] = true
  state.trashViewDirty = true
  state.selectedBundleFile = nil
  state.folderBundleFilesDirty = true
  state.folderStatus, state.folderStatusError =
    ("Moved shared-folder file \"%s\" to Trash. Presets and folders were not changed.")
      :format(selected), false
  state.statusKinds.folder = "success"
  log(("[FOLDER BUNDLE] Moved file='%s' to Trash as '%s'.")
    :format(selectedPath, trashFilename), "complete")
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
      local encodedName, fingerprint, encodedRoot =
        line:match("^B\t([^\t]+)\t(2:%d+:%d+:%d+)\t([^\t]+)$")
      if not encodedName then
        encodedName, fingerprint, encodedRoot =
          line:match("^B\t([^\t]+)\t(%d+:%d+)\t([^\t]+)$")
      end
      if not encodedName then
        encodedName, fingerprint = line:match("^B\t([^\t]+)\t(2:%d+:%d+:%d+)$")
      end
      if not encodedName then
        encodedName, fingerprint = line:match("^B\t([^\t]+)\t(%d+:%d+)$")
      end
      local filename = encodedName and catalogDecode(encodedName) or nil
      local root = encodedRoot and catalogDecode(encodedRoot) or nil
      if not isFolderBundleFilename(filename)
          or (root ~= nil and not validBundlePath(root)) then return nil, false end
      imported[filename:lower()] = {
        filename = filename,
        fingerprint = fingerprint,
        root = root,
      }
    end
  end
  return imported, true
end

local function writeImportedBundles(imported)
  local lines = {}
  for _, item in pairs(imported or {}) do
    if not isFolderBundleFilename(item.filename)
        or type(item.fingerprint) ~= "string"
        or (not item.fingerprint:match("^%d+:%d+$")
          and not item.fingerprint:match("^2:%d+:%d+:%d+$")) then return false end
    local line = "B\t" .. catalogEncode(item.filename) .. "\t" .. item.fingerprint
    if item.root ~= nil then
      if not validBundlePath(item.root) then return false end
      line = line .. "\t" .. catalogEncode(item.root)
    end
    table.insert(lines, line)
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
  state.statusKinds.folder = nil
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
      ("This folder has more than the %d presets allowed in one shared-folder file."):format(MAX_FOLDER_BUNDLE_PRESETS), true; return
  end
  local folders = {}
  for candidate in pairs(state.folders) do
    if candidate ~= folder and isInFolderTree(candidate, folder) then
      table.insert(folders, candidate:sub(#folder + 2))
    end
  end
  table.sort(folders, function(a, b) return a:lower() < b:lower() end)
  local filename = uniqueFolderBundleFilename(folder)
  if not filename then
    state.folderStatus, state.folderStatusError =
      "The mod could not create an unused file name for the shared folder.", true; return
  end
  local bundleError = nil
  local wrote = atomicReplace(filename, function(temporary)
    local file = io.open(temporary, "wb")
    if not file then return false end
    local wroteOk, writeResult = pcall(function()
      local header = "CPMFOLDER\t1\nROOT\t" .. catalogEncode(baseName(folder)) .. "\n"
      local totalBytes = #header
      if not file:write(header) then return false end
      for _, relativeFolder in ipairs(folders) do
        if not validBundlePath(relativeFolder) then
          bundleError = "A folder or preset name inside this folder is not safe to export."
          return false
        end
        local line = "F\t" .. catalogEncode(relativeFolder) .. "\n"
        totalBytes = totalBytes + #line
        if totalBytes > MAX_FOLDER_BUNDLE_BYTES then
          bundleError = "The shared-folder file would be larger than the 32 MB limit."
          return false
        end
        if not file:write(line) then return false end
      end
      for _, name in ipairs(names) do
        local relativeName = name:sub(#folder + 2)
        if not validBundlePath(relativeName) then
          bundleError = "This preset could not be read and was not exported: " .. name
          return false
        end
        local prefix = "P\t" .. catalogEncode(relativeName) .. "\t"
        local source = io.open(presetPath(name), "rb")
        if not source then
          bundleError = "This preset could not be read and was not exported: " .. name
          return false
        end
        local sizeOk, sourceBytes = pcall(source.seek, source, "end")
        source:close()
        if not sizeOk or not sourceBytes or sourceBytes > MAX_PRESET_BYTES then
          bundleError = "This preset could not be read and was not exported: " .. name
          return false
        end
        totalBytes = totalBytes + #prefix + (sourceBytes * 2) + 1
        if totalBytes > MAX_FOLDER_BUNDLE_BYTES then
          bundleError = "The shared-folder file would be larger than the 32 MB limit."
          return false
        end
        if not file:write(prefix) then return false end
        local streamed, streamedBytes = writeHexFile(file, presetPath(name))
        if not streamed or streamedBytes ~= sourceBytes or not file:write("\n") then
          bundleError = "This preset could not be read and was not exported: " .. name
          return false
        end
      end
      return file:flush() ~= nil
    end)
    local closeOk, closeResult = pcall(file.close, file)
    return wroteOk and writeResult == true and closeOk and closeResult ~= nil
  end, "folder bundle")
  if not wrote then
    state.folderStatus, state.folderStatusError = bundleError
      or "The shared-folder file could not be saved.", true; return
  end
  state.folderBundleFilesDirty = true
  state.folderStatus, state.folderStatusError =
    ("Exported %d preset%s to %s. Share this one file.")
      :format(#names, #names == 1 and "" or "s", filename), false
  state.statusKinds.folder = "success"
  log(("[FOLDER BUNDLE] Exported folder='%s' presets=%d file='%s'.")
    :format(folder, #names, filename), "complete")
end

local function inspectFolderBundle(filename)
  local file = io.open(filename, "rb")
  if not file then return nil, "The shared-folder file could not be opened." end
  local function fail(message)
    pcall(file.close, file)
    return nil, message
  end
  local sizeOk, size = pcall(file.seek, file, "end")
  local rewindOk, rewindResult = pcall(file.seek, file, "set", 0)
  if not sizeOk or not size or size > MAX_FOLDER_BUNDLE_BYTES
      or not rewindOk or rewindResult == nil then
    file:close()
    return nil, "The shared-folder file is unreadable or larger than the 32 MB limit."
  end
  local bundle = { folders = {}, folderNames = {}, presets = {}, presetNames = {} }
  local lineNumber = 0
  for line in file:lines() do
    line = line:gsub("\r$", "")
    if line ~= "" then
      lineNumber = lineNumber + 1
      if lineNumber == 1 then
        if line ~= "CPMFOLDER\t1" then
          return fail("The shared-folder file has an invalid first line.")
        end
      else
        local root = line:match("^ROOT\t([^\t]+)$")
        local folder = line:match("^F\t([^\t]+)$")
        local name, encoded = line:match("^P\t([^\t]+)\t([%x]+)$")
        if root then
          root = catalogDecode(root)
          if bundle.root or not validBundlePath(root) or parentFolder(root) ~= "" then
            return fail("The shared folder has an invalid main folder name.")
          end
          bundle.root = root
        elseif folder then
          folder = catalogDecode(folder)
          if not validBundlePath(folder) then
            return fail("The shared folder contains an invalid folder name.")
          end
          if bundle.folderNames[folder:lower()] then
            return fail("The shared-folder file contains the same folder more than once.")
          end
          bundle.folderNames[folder:lower()] = true
          bundle.folders[folder] = true
        elseif name then
          name = catalogDecode(name)
          if not validBundlePath(name) or #encoded % 2 ~= 0
              or #encoded > MAX_PRESET_BYTES * 2
              or #bundle.presets >= MAX_FOLDER_BUNDLE_PRESETS then
            return fail("The shared-folder file contains an invalid preset.")
          end
          if bundle.presetNames[name:lower()] then
            return fail("The shared-folder file contains the same preset more than once.")
          end
          bundle.presetNames[name:lower()] = true
          table.insert(bundle.presets, { name = name })
        else
          return fail(("Line %d in the shared-folder file is invalid."):format(lineNumber))
        end
      end
    end
  end
  local closeOk, closeResult = pcall(file.close, file)
  if not closeOk or closeResult == nil then
    return nil, "The shared-folder file could not be closed safely."
  end
  if not bundle.root or #bundle.presets == 0 then return nil, "The shared-folder file is empty or incomplete." end
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
  local bundle, bundleError = inspectFolderBundle(filename)
  if not bundle then return nil, bundleError end
  local root = bundle.root
  if folderNameExists(root) then root = uniqueFolderCopyName(root) end
  if not root then return nil, "The mod could not create an unused name for the imported folder." end
  local newPresets = cloneMap(state.presets)
  local newFolders = cloneMap(state.folders)
  local newManualFolders = cloneMap(state.manualFolders)
  local newIgnored = cloneMap(state.ignoredPhysicalFolders)
  addFolderAncestors(newFolders, root)
  for folder in pairs(bundle.folders) do
    addFolderAncestors(newFolders, joinFolder(root, folder))
  end
  local reservedStorage = storageFilenamesInUse()
  if not reservedStorage then return nil, "The existing preset file names could not be checked safely." end
  local createdFiles = {}
  for _, item in ipairs(bundle.presets) do
    local logicalName = joinFolder(root, item.name)
    if findPresetCollision(logicalName) then
      return nil, "An imported preset has the same name as an existing preset."
    end
    local storage = uniqueStorageName(baseName(logicalName), reservedStorage)
    if not storage then
      return nil, "The mod could not create a safe file name for an imported preset."
    end
    item.logicalName = logicalName
    item.storage = storage
    item.path = PRESET_DIR .. "/" .. storage .. ".preset"
  end
  local plansByName = {}
  for _, item in ipairs(bundle.presets) do plansByName[item.name:lower()] = item end
  local file = io.open(filename, "rb")
  if not file then return nil, "The shared-folder file could not be reopened for installation." end
  local importedCount = 0
  local importError = nil
  for line in file:lines() do
    line = line:gsub("\r$", "")
    local encodedName, encoded = line:match("^P\t([^\t]+)\t([%x]+)$")
    if encodedName then
      local name = catalogDecode(encodedName)
      local item = plansByName[name:lower()]
      local contents = item and hexDecode(encoded) or nil
      if not item or not contents or #contents > MAX_PRESET_BYTES
          or not writeRawPreset(item.path, contents) then
        importError = "An imported preset file could not be written safely."
        break
      end
      table.insert(createdFiles, item.path)
      local preset = readPresetFile(item.path, true)
      if not preset then
        importError = "An imported preset failed verification."
        break
      end
      preset.fingerprint = fileFingerprint(item.path, MAX_PRESET_BYTES)
      preset.storage = item.storage
      newPresets[item.logicalName] = preset
      importedCount = importedCount + 1
    end
  end
  local closeOk, closeResult = pcall(file.close, file)
  if importError or not closeOk or closeResult == nil
      or importedCount ~= #bundle.presets
      or fileFingerprint(filename, MAX_FOLDER_BUNDLE_BYTES) ~= fingerprint then
    local message = importError
      or "The shared-folder file changed or could not be read completely during installation."
    return nil, cleanupFailureMessage(createdFiles, message,
      message .. " Some partial preset files could not be removed.")
  end
  if not writeCatalog(newPresets, newFolders, newManualFolders, newIgnored) then
    return nil, cleanupFailureMessage(createdFiles,
      "The imported folder was removed again because the folder list could not be saved.",
      "The folder list could not be saved, and some imported preset files could not be removed.")
  end
  local inventorySaved = writeInventory(newPresets, newFolders)
  if not inventorySaved then
    writeCatalog(state.presets, state.folders, state.manualFolders,
      state.ignoredPhysicalFolders)
    return nil, cleanupFailureMessage(createdFiles,
      "The imported folder was removed again because the preset file list could not be saved.",
      "The preset file list could not be saved, and some imported preset files could not be removed.")
  end
  local leaf = filename:match("([^/]+)$")
  local updatedImported = cloneMap(importedBundles)
  updatedImported[leaf:lower()] = {
    filename = leaf,
    fingerprint = fingerprint,
    root = root,
  }
  if not writeImportedBundles(updatedImported) then
    writeCatalog(state.presets, state.folders, state.manualFolders,
      state.ignoredPhysicalFolders)
    writeInventory(state.presets, state.folders)
    return nil, cleanupFailureMessage(createdFiles,
      "The imported folder was removed again because the completed import could not be recorded.",
      "The completed import could not be recorded, and some imported preset files could not be removed.")
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
  state.statusKinds.folder = nil
  auditSection("IMPORT FOLDER BUNDLES")
  local files = folderBundleFiles(true)
  if #files == 0 then
    state.folderStatus, state.folderStatusError =
      "Place a .cpmfolder file in Character Presets, then select Install Shared Folders.", true; return
  end
  local importedBundles, registryOk = readImportedBundles()
  if not registryOk then
    state.folderStatus, state.folderStatusError =
      "Imported Bundles.txt is unreadable or unsafe. No bundles were changed.", true; return
  end
  local imported, skipped, failures, warnings = 0, 0, {}, {}
  for _, filename in ipairs(files) do
    local leaf = filename:match("([^/]+)$")
    local fingerprint, legacyFingerprint = fileFingerprint(filename, MAX_FOLDER_BUNDLE_BYTES)
    local previousImport = importedBundles[leaf:lower()]
    local previouslySame = previousImport
      and (previousImport.fingerprint == fingerprint
        or previousImport.fingerprint == legacyFingerprint)
    if not fingerprint then
      table.insert(failures, filename .. ": The file could not be checked safely.")
    elseif previouslySame
        and previousImport.root and folderNameExists(previousImport.root) then
      if previousImport.fingerprint ~= fingerprint then
        previousImport.fingerprint = fingerprint
        if not writeImportedBundles(importedBundles) then
          table.insert(warnings,
            filename .. ": The saved file check could not be updated, but the existing folder was kept.")
        end
      end
      skipped = skipped + 1
      log(("[FOLDER BUNDLE] Skipped previously imported file='%s' fingerprint='%s' root='%s'.")
        :format(filename, fingerprint, previousImport.root), "info")
    else
      if previouslySame then
        log(("[FOLDER BUNDLE] Previously imported folder root='%s' is no longer present; reimporting file='%s'.")
          :format(tostring(previousImport.root or "unknown"), filename), "info")
      end
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
    state.folderStatus = ("Installed %d shared folder%s; skipped %d already installed.%s")
      :format(imported, imported == 1 and "" or "s",
        skipped,
        #warnings > 0 and (" " .. table.concat(warnings, " | ")) or "")
    state.folderStatusError = false
    state.statusKinds.folder = "success"
  end
end

end

local function refreshPresets(scanReason, recoveryAssignments, recoveryFolders,
    recoveryManualFolders)
  state.folderBundleFilesDirty = true
  local currentPresets = state.presets or {}
  local currentFolders = state.folders or {}
  local previousPresets = currentPresets
  local previousFolders = currentFolders
  local baselineAvailable = state.ready
  if scanReason == "startup" then
    previousPresets, previousFolders, baselineAvailable = helpers.readInventory()
    log(("[INVENTORY] Startup baseline available=%s presets=%d folders=%d.")
      :format(tostring(baselineAvailable),
        (function() local count = 0; for _ in pairs(previousPresets) do count = count + 1 end; return count end)(),
        (function() local count = 0; for _ in pairs(previousFolders) do count = count + 1 end; return count end)()), "info")
  end
  local assignments, catalogFolders, ignoredPhysicalFolders, catalogStatus = helpers.readCatalog()
  if catalogStatus == false then
    log("[FOLDER LIST] The preset scan stopped because the saved folder list is invalid.", "error")
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
  local scannedPresetCount = 0
  local scannedEntryCount = 0
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
        if scannedPresetCount >= AUTO_LOAD_LIMITS.maximumScannedPresets then
          log(("[FILES] Scan stopped after %d presets because the library exceeds the safety limit.")
            :format(scannedPresetCount), "error")
          return false
        end
        local preset
        if scanReason == "startup" then
          local inventoryName = assignments[storage]
          if not validRelativePath(inventoryName) then inventoryName = storage end
          if type(previousPresets[inventoryName]) == "table" then
            preset = {
              entryCount = 0,
              entryCountKnown = false,
              lazy = true,
            }
          else
            preset = readPresetFile(path .. "/" .. filename, true)
          end
        else
          preset = readPresetFile(path .. "/" .. filename, scanReason ~= "external")
        end
        if preset then
          if scanReason == "external" then
            preset.fingerprint = fileFingerprint(
              path .. "/" .. filename, MAX_PRESET_BYTES)
            if not preset.fingerprint then
              log(("[FILES] Scan stopped because '%s' could not be checked safely.")
                :format(childRelative), "error")
              return false
            end
          end
          scannedPresetCount = scannedPresetCount + 1
          local entryCount = preset.entryCountKnown == true
            and state.presetEntryCount(preset) or 0
          scannedEntryCount = scannedEntryCount + entryCount
          if scannedEntryCount > AUTO_LOAD_LIMITS.maximumScannedEntries then
            log(("[FILES] Scan stopped after %d saved options because the library exceeds the safety limit.")
              :format(scannedEntryCount), "error")
            return false
          end
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
    log(("[FILES] The preset scan did not finish. The last good preset and file lists were kept (reason=%s).")
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
    local inventoryPreset = previousPresets[logicalName]
    if scanReason == "startup" and type(inventoryPreset) == "table" then
      preset.entryCount = state.presetEntryCount(inventoryPreset)
      preset.entryCountKnown = inventoryPreset.entryCountKnown
      preset.format = inventoryPreset.format
      preset.modified = inventoryPreset.modified
      preset.fingerprint = inventoryPreset.fingerprint
      local knownEntries = inventoryPreset.entryCountKnown
        and state.presetEntryCount(inventoryPreset) or 0
      scannedEntryCount = scannedEntryCount + knownEntries
      if scannedEntryCount > AUTO_LOAD_LIMITS.maximumScannedEntries then
        log(("[FILES] Startup stopped after %d saved options because the library exceeds the safety limit.")
          :format(scannedEntryCount), "error")
        return currentPresets, false
      end
    end
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
    log("[FOLDER LIST] The last good preset list was kept because the saved folder list could not be updated.", "error")
    return currentPresets, false
  end

  local changeSummary = { added = 0, removed = 0, modified = 0,
    foldersAdded = 0, foldersRemoved = 0 }
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
    changeSummary.added = added
    changeSummary.removed = removed
    changeSummary.modified = modified
    changeSummary.foldersAdded = foldersAdded
    changeSummary.foldersRemoved = foldersRemoved
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
  return presets, true, changeSummary
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
          ("A character option name is longer than the %d-byte preset limit. Open the Activity Log to see which option caused this.")
            :format(MAX_PRESET_KEY_BYTES),
          true
        )
        return
      end
      if #entries >= MAX_PRESET_ENTRIES then
        log(("[SNAPSHOT] Rejected %s | savedEntries=%d maximum=%d")
          :format(identity, #entries, MAX_PRESET_ENTRIES), "error")
        setStatus("create",
          ("The editor contains more than %d active options. Open the Activity Log for details.")
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
          "A character option returned a number that the mod cannot use. Open the Activity Log to see which option caused this.",
          true
        )
        return
      end
      savedOccurrences[key] = (savedOccurrences[key] or 0) + 1
      local slot = optionSlot(option)
      local choice = helpers.optionChoiceKey(option, currentIndex)
      log(("[SNAPSHOT] Saved %s index=%d slot='%s' choice='%s' editable=true active=true")
        :format(optionAuditIdentity(option, key, savedOccurrences[key]),
          currentIndex, tostring(slot or "none"), tostring(choice or "none")), "info")
      table.insert(entries, {
        key = key,
        index = currentIndex,
        slot = slot,
        choice = choice,
      })
    end
  end
  if #entries == 0 then
    setStatus("create", "No editable options were found.", true)
    return
  end

  local previousPreset = state.presets[name]
  if previousPreset and not hydrateNamedPreset(name) then
    setStatus("create", "The existing preset could not be read safely before replacement.", true)
    return
  end
  local storage = previousPreset and previousPreset.storage
    or uniqueStorageName(leafName)
  if not storage then
    setStatus("create", "The mod could not create a safe file name for this preset.", true)
    return
  end
  local newPreset = {
    format = CURRENT_PRESET_FORMAT,
    source = MOD_NAME,
    created = previousPreset and previousPreset.created or logTimestamp(),
    modified = logTimestamp(),
    notes = previousPreset and previousPreset.notes or "",
    tags = previousPreset and previousPreset.tags or "",
    entries = entries,
    entryCount = #entries,
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
      and "The preset was not saved because its folder could not be recorded."
      or "The folder list could not be saved, and the preset file could not be returned to its earlier state.", true)
    return
  end
  state.selected = name
  state.presetNotes = newPreset.notes or ""
  state.presetTags = newPreset.tags or ""
  invalidateViewCache()
  state.renameName = ""
  state.newName = ""
  resetLoadState()
  log(("Created preset '%s': format=%d orderedOptions=%d")
    :format(name, CURRENT_PRESET_FORMAT, #entries), "info")
  if writeInventory(state.presets, state.folders) then
    setStatus("create", ("Saved \"%s\" with %d options.")
      :format(name, #entries), false, "success")
  else
    setStatus("create", ("Saved \"%s\", but the preset file list could not be updated.")
      :format(name), false, "warning")
  end
end

state.logLoadOnce = function(key, message, level)
  key = tostring(key or message)
  if state.loadLoggedWarnings[key] then return end
  state.loadLoggedWarnings[key] = true
  log(message, level)
end

state.loadOptionIdentity = function(option, key, occurrence)
  local cacheKey = tostring(key or "unknown") .. "\31" .. tostring(occurrence or 1)
  local identity = state.loadOptionIdentityCache[cacheKey]
  if not identity then
    identity = optionAuditIdentity(option, key, occurrence)
    state.loadOptionIdentityCache[cacheKey] = identity
  end
  return identity
end

helpers.loadClock = function()
  local ok, value = pcall(os.clock)
  return ok and tonumber(value) or 0
end

helpers.loadChoiceShape = function(option)
  local parts = {}
  for _, field in ipairs({ "definitions", "options", "morphNames" }) do
    local ok, size = pcall(function()
      return option and option.info and #(option.info[field] or {}) or 0
    end)
    parts[#parts + 1] = field .. ":" .. tostring(ok and tonumber(size) or "?")
  end
  return table.concat(parts, ",")
end

helpers.loadStructureDelta = function(before, after)
  local function fingerprint(descriptor)
    return table.concat({
      tostring(descriptor.label or ""), tostring(descriptor.occurrence or 0),
      tostring(descriptor.slot or ""), tostring(descriptor.slotOccurrence or 0),
      descriptor.editable and "1" or "0", descriptor.active and "1" or "0",
    }, "\29")
  end
  local function identity(descriptor)
    return ("LocKey=%s occurrence=%s slot=%s active=%s editable=%s choices=%s")
      :format(tostring(descriptor.label or "unknown"),
        tostring(descriptor.occurrence or "none"), tostring(descriptor.slot or "none"),
        tostring(descriptor.active), tostring(descriptor.editable),
        tostring(descriptor.choiceShape or "unknown"))
  end
  local beforeCounts, afterCounts = {}, {}
  for _, descriptor in ipairs(before or {}) do
    local key = fingerprint(descriptor)
    beforeCounts[key] = (beforeCounts[key] or 0) + 1
  end
  for _, descriptor in ipairs(after or {}) do
    local key = fingerprint(descriptor)
    afterCounts[key] = (afterCounts[key] or 0) + 1
  end
  local removed, added = {}, {}
  for _, descriptor in ipairs(before or {}) do
    local key = fingerprint(descriptor)
    if (beforeCounts[key] or 0) > (afterCounts[key] or 0) then
      if #removed < 12 then removed[#removed + 1] = identity(descriptor) end
      beforeCounts[key] = beforeCounts[key] - 1
    end
  end
  for _, descriptor in ipairs(after or {}) do
    local key = fingerprint(descriptor)
    if (afterCounts[key] or 0) > (beforeCounts[key] or 0) then
      if #added < 12 then added[#added + 1] = identity(descriptor) end
      afterCounts[key] = afterCounts[key] - 1
    end
  end
  return #removed > 0 and table.concat(removed, " || ") or "none",
    #added > 0 and table.concat(added, " || ") or "none"
end

helpers.scanLoadOptions = function(options, relevantLabels, relevantSlots)
  local started = helpers.loadClock()
  relevantLabels = relevantLabels or {}
  relevantSlots = relevantSlots or {}
  local result = {
    exposed = {},
    activeExposed = {},
    activeByKey = {},
    activeKeySet = {},
    activeCounts = {},
    exposedBySlot = {},
    activeSlotCounts = {},
    descriptors = {},
  }
  local occurrences, activeSlotCounts, signatureParts = {}, result.activeSlotCounts, {}
  local cached = not state.loadMetadataDisabled and state.loadMetadataCache or nil
  local cacheValid = cached ~= nil and type(cached.descriptors) == "table"
  local fullExposure = state.forceFullLoad or state.loadPhase == "cleanup"
  for position, option in ipairs(options) do
    local label = optionKey(option)
    local slot = optionSlot(option)
    local editable = option and option.isEditable and true or false
    local active = option and option.isActive and true or false
    local occurrence, key, slotOccurrence
    if label and editable and active then
      occurrences[label] = (occurrences[label] or 0) + 1
      occurrence = occurrences[label]
      result.activeCounts[label] = occurrence
      key = label .. "\31" .. tostring(occurrence)
      if slot then
        activeSlotCounts[slot] = (activeSlotCounts[slot] or 0) + 1
        slotOccurrence = activeSlotCounts[slot]
      end
    end
    local pending = state.loadPendingChange
    local choiceShape = label and (relevantLabels[label]
      or (pending and pending.label == label))
        and helpers.loadChoiceShape(option) or "not-checked"
    local cachedDescriptor = cacheValid and cached.descriptors[position] or nil
    local descriptorMatches = cachedDescriptor
      and cachedDescriptor.label == label
      and cachedDescriptor.key == key
      and cachedDescriptor.occurrence == occurrence
      and cachedDescriptor.slot == slot
      and cachedDescriptor.slotOccurrence == slotOccurrence
      and cachedDescriptor.editable == editable
      and cachedDescriptor.active == active
      and cachedDescriptor.choiceShape == choiceShape
    local descriptor = descriptorMatches and cachedDescriptor or {
        label = label,
        key = key,
        occurrence = occurrence,
        slot = slot,
        slotOccurrence = slotOccurrence,
        editable = editable,
        active = active,
        choiceShape = choiceShape,
      }
    if not descriptorMatches then cacheValid = false end
    result.descriptors[position] = descriptor
    local pendingOption = state.loadPendingChange
    local includeOption = key and (fullExposure or relevantLabels[label]
      or (slot and relevantSlots[slot])
      or (pendingOption and pendingOption.label == label))
    if includeOption then
      local exposedOption = {
        option = option,
        position = position,
        label = label,
        key = key,
        occurrence = occurrence,
        slot = slot,
        slotOccurrence = slotOccurrence,
        choiceShape = choiceShape,
      }
      result.exposed[#result.exposed + 1] = exposedOption
      result.activeKeySet[key] = true
      result.activeByKey[key] = exposedOption
      result.activeExposed[#result.activeExposed + 1] = exposedOption
      if slot then
        result.exposedBySlot[slot .. "\31" .. tostring(slotOccurrence)] = exposedOption
      end
    end
    signatureParts[position] = table.concat({
      tostring(label or ""), tostring(occurrence or 0), tostring(slot or ""),
      tostring(slotOccurrence or 0), editable and "1" or "0", active and "1" or "0",
    }, "\29")
  end
  if cached and cached.descriptors[#options + 1] then cacheValid = false end
  result.signature = table.concat(signatureParts, "\30")
  local previousSignature = state.loadLastStructureSignature
  local previousDescriptors = state.loadLastStructureDescriptors
  if previousSignature and previousSignature ~= result.signature then
    state.loadStructureChanges = state.loadStructureChanges + 1
    state.loadMetadataCache = nil
    state.loadResolvedChoiceIndexes = {}
    state.loadOptionIdentityCache = {}
    state.loadDependencyRemaps = {}
    local removed, added = helpers.loadStructureDelta(
      previousDescriptors, result.descriptors)
    local pending = state.loadPendingChange
    if pending then
      pending.longSettle = true
      state.loadDependencyKeys[pending.trackingKey] = true
      log(("[MEASURE] Option structure changed after %s '%s': exposed %d options.")
        :format(pending.kind, pending.identity, #options), "info")
    else
      log(("[MEASURE] Option structure changed between load checks: exposed %d options; stable metadata was rebuilt.")
        :format(#options), "info")
    end
    log(("[MEASURE] Structure difference | removed: %s | added: %s")
      :format(removed, added), "info")
  end
  state.loadLastStructureSignature = result.signature
  state.loadLastStructureDescriptors = result.descriptors
  if not state.loadMetadataDisabled then
    if cacheValid and cached.signature == result.signature then
      state.loadMetadataHits = state.loadMetadataHits + 1
    else
      state.loadMetadataMisses = state.loadMetadataMisses + 1
      state.loadMetadataCache = {
        signature = result.signature,
        descriptors = result.descriptors,
      }
    end
  else
    state.loadMetadataMisses = state.loadMetadataMisses + 1
  end
  state.loadScanSeconds = state.loadScanSeconds + math.max(0, helpers.loadClock() - started)
  return result
end

helpers.resolveLoadChoice = function(option, choice, cachedIndex)
  local started = helpers.loadClock()
  local resolved = not state.loadMetadataDisabled and cachedIndex or nil
  if resolved == nil or not optionChoiceMatchesIndex(option, choice, resolved) then
    resolved = optionChoiceIndex(option, choice)
  end
  state.loadChoiceSeconds = state.loadChoiceSeconds
    + math.max(0, helpers.loadClock() - started)
  return resolved
end

helpers.loadOptionNeedsLongSettle = function(exposedOption, trackingKey)
  if state.loadDependencyKeys[trackingKey] then return true end
  local text = table.concat({
    tostring(exposedOption.label or ""),
    tostring(exposedOption.slot or ""),
    helpers.optionDisplayName(exposedOption.option, exposedOption.label),
  }, " "):lower()
  return text:find("hair", 1, true) ~= nil or text:find("beard", 1, true) ~= nil
end

helpers.pollPendingOption = function(options)
  local pending = state.loadPendingChange
  if not pending or state.forceFullLoad or state.loadMetadataDisabled
      or not pending.position or pending.confirmedAt or pending.longSettle then
    return "full"
  end
  local started = helpers.loadClock()
  state.loadTargetPolls = state.loadTargetPolls + 1
  local candidate = options[pending.position]
  local valid = candidate ~= nil
    and optionKey(candidate) == pending.label
    and candidate.isEditable and candidate.isActive
    and optionSlot(candidate) == pending.slot
  local occurrence = 0
  if valid then
    for position = 1, pending.position do
      local option = options[position]
      if option and option.isEditable and option.isActive
          and optionKey(option) == pending.label then
        occurrence = occurrence + 1
      end
    end
    valid = occurrence == pending.occurrence
      and helpers.loadChoiceShape(candidate) == pending.choiceShape
  end
  state.loadTargetPollSeconds = state.loadTargetPollSeconds
    + math.max(0, helpers.loadClock() - started)
  if not valid then
    state.loadTargetFallbacks = state.loadTargetFallbacks + 1
    state.loadMetadataCache = nil
    state.loadMetadataDisabled = true
    state.loadResolvedChoiceIndexes = {}
    state.loadOptionIdentityCache = {}
    state.loadDependencyRemaps = {}
    log(("[CACHE] The pending option no longer matches its saved position; full scanning will be used for the rest of this load: %s")
      :format(pending.identity), "warn")
    return "fallback"
  end
  local current = tonumber(candidate.currIndex) or 0
  local timeout = pending.longSettle and AUTO_LOAD_TIMING.dependencyTimeout
    or AUTO_LOAD_TIMING.settleTimeout
  if current == pending.target
      or state.loadElapsed - pending.attemptStartedAt >= timeout then
    return "full"
  end
  state.loadNextInterval = AUTO_LOAD_TIMING.pollInterval
  state.loadPendingElapsed = math.max(0, state.loadElapsed - pending.startedAt)
  return "waiting"
end

helpers.beginPendingChange = function(system, exposedOption, target, kind, trackingKey, current)
  local attempts = kind == "cleanup" and state.loadCleanupAttempts
    or state.loadApplyAttempts
  local started = helpers.loadClock()
  local ok, applyError = pcall(
    system.ApplyChangeToOption, system, exposedOption.option, target)
  state.loadApplySeconds = state.loadApplySeconds
    + math.max(0, helpers.loadClock() - started)
  if not ok then return false, applyError end
  attempts[trackingKey] = (attempts[trackingKey] or 0) + 1
  local longSettle = helpers.loadOptionNeedsLongSettle(exposedOption, trackingKey)
  exposedOption.choiceShape = helpers.loadChoiceShape(exposedOption.option)
  state.loadPendingChange = {
    kind = kind,
    trackingKey = trackingKey,
    optionKey = exposedOption.key,
    position = exposedOption.position,
    label = exposedOption.label,
    occurrence = exposedOption.occurrence,
    slot = exposedOption.slot,
    choiceShape = exposedOption.choiceShape,
    target = target,
    previous = current,
    identity = state.loadOptionIdentity(
      exposedOption.option, exposedOption.label, exposedOption.occurrence),
    startedAt = state.loadElapsed,
    attemptStartedAt = state.loadElapsed,
    structureSignature = state.loadLastStructureSignature,
    confirmedAt = nil,
    confirmedSignature = nil,
    longSettle = longSettle,
  }
  state.loadPendingElapsed = 0
  state.loadNextInterval = AUTO_LOAD_TIMING.pollInterval
  state.loadNeedsContinue = true
  state.previousUnresolvedSignature = nil
  state.unresolvedRepeatCount = 0
  return true
end

helpers.clearVisibleLoadSatisfaction = function(scan)
  for key in pairs(scan.activeKeySet) do
    if not state.loadUnconfirmed[key] then state.loadSatisfied[key] = nil end
  end
  state.loadApplyAttempts = {}
  state.previousUnresolvedSignature = nil
  state.unresolvedRepeatCount = 0
end

helpers.checkPendingChange = function(system, scan)
  local pending = state.loadPendingChange
  if not pending then return "none" end
  local candidate = scan.activeByKey[pending.optionKey]
  if candidate and (candidate.label ~= pending.label
      or candidate.occurrence ~= pending.occurrence
      or candidate.slot ~= pending.slot) then
    candidate = nil
    state.loadMetadataCache = nil
    state.loadMetadataDisabled = true
    state.loadResolvedChoiceIndexes = {}
    state.loadOptionIdentityCache = {}
    state.loadDependencyRemaps = {}
    log(("[CACHE] Live option identity changed while waiting for %s; full scanning will be used for the rest of this load: %s")
      :format(pending.kind, pending.identity), "warn")
  elseif candidate and candidate.choiceShape ~= pending.choiceShape then
    if not pending.choiceStructureChanged then
      state.loadMetadataCache = nil
      state.loadMetadataDisabled = true
      state.loadResolvedChoiceIndexes = {}
      state.loadOptionIdentityCache = {}
      state.loadDependencyRemaps = {}
      pending.longSettle = true
      pending.choiceStructureChanged = true
      log(("[CACHE] Choice structure changed while waiting for %s; the result will require manual confirmation: %s")
        :format(pending.kind, pending.identity), "warn")
    end
  end
  local current = candidate and (tonumber(candidate.option.currIndex) or 0) or nil
  local disappeared = candidate == nil
  local reached = not pending.choiceStructureChanged and current == pending.target
  local structureChanged = scan.signature ~= pending.structureSignature
  if structureChanged then pending.longSettle = true end
  if disappeared then pending.longSettle = true end
  if reached or disappeared then
    if pending.longSettle then
      if pending.confirmedAt == nil
          or pending.confirmedSignature ~= scan.signature then
        pending.confirmedAt = state.loadElapsed
        pending.confirmedSignature = scan.signature
        state.loadNextInterval = AUTO_LOAD_TIMING.pollInterval
        setStatus("load", disappeared
          and "A dependent option was replaced. Waiting for the editor to settle."
          or "The option changed. Waiting for dependent options to settle.")
        return "waiting"
      end
      if state.loadElapsed - pending.confirmedAt
          < AUTO_LOAD_TIMING.dependencyStableTime then
        state.loadNextInterval = AUTO_LOAD_TIMING.pollInterval
        return "waiting"
      end
    end
    local waited = math.max(0, state.loadElapsed - pending.startedAt)
    state.loadWaitSeconds = state.loadWaitSeconds + waited
    state.loadPendingElapsed = waited
    state.loadPendingChange = nil
    state.loadNextInterval = AUTO_LOAD_TIMING.interval
    if pending.kind == "apply" then
      state.loadSatisfied[pending.trackingKey] = true
      state.loadUnconfirmed[pending.trackingKey] = nil
      if pending.forced then state.loadForcedKeys[pending.trackingKey] = true end
    else
      state.loadPhase = "verify"
      state.loadReturnToCleanup = true
      helpers.clearVisibleLoadSatisfaction(scan)
    end
    log(("SETTLED | %s | %s | target=%s | result=%s | currIndex wait=%.3fs | structureChanged=%s")
      :format(pending.kind, pending.identity, tostring(pending.target),
        disappeared and "dependent option disappeared" or "value confirmed",
        waited, tostring(structureChanged)), "info")
    return "settled"
  end
  local timeout = pending.longSettle and AUTO_LOAD_TIMING.dependencyTimeout
    or AUTO_LOAD_TIMING.settleTimeout
  local sinceAttempt = state.loadElapsed - pending.attemptStartedAt
  if sinceAttempt < timeout then
    state.loadNextInterval = AUTO_LOAD_TIMING.pollInterval
    state.loadPendingElapsed = math.max(0, state.loadElapsed - pending.startedAt)
    return "waiting"
  end
  local waited = math.max(0, state.loadElapsed - pending.startedAt)
  state.loadWaitSeconds = state.loadWaitSeconds + waited
  state.loadPendingChange = nil
  state.loadNextInterval = AUTO_LOAD_TIMING.interval
  if pending.kind == "cleanup" then
    state.loadCleanupSkipped[pending.trackingKey] = true
    state.loadPhase = "verify"
    state.loadReturnToCleanup = true
    helpers.clearVisibleLoadSatisfaction(scan)
    state.logLoadOnce("cleanup-not-confirmed:" .. pending.trackingKey,
      ("[UNCONFIRMED] The game did not expose whether a remaining option cleared after %.3fs. It was not applied again: %s")
        :format(waited, pending.identity), "warn")
  else
    state.loadSatisfied[pending.trackingKey] = true
    state.loadUnconfirmed[pending.trackingKey] = true
    if pending.forced then state.loadForcedKeys[pending.trackingKey] = true end
    state.logLoadOnce("apply-not-confirmed:" .. pending.trackingKey,
      ("[UNCONFIRMED] The game did not update currIndex after %.3fs. The option was applied once and was not repeated: %s targetIndex=%s")
        :format(waited, pending.identity, tostring(pending.target)), "warn")
  end
  return "unconfirmed"
end

helpers.logLoadMeasurements = function(result)
  log(("[MEASURE] Load %s | preset='%s' | elapsed=%.3fs | GetUnitedOptions calls=%d time=%.6fs | scans=%.6fs | targeted polls=%d time=%.6fs fallbacks=%d | choice matching=%.6fs | ApplyChangeToOption=%.6fs | currIndex/dependency wait=%.3fs | structure changes=%d | metadata hits=%d misses=%d disabled=%s")
    :format(tostring(result), tostring(state.loadPresetName or state.selected),
      state.loadElapsed, state.loadOptionCalls, state.loadOptionsSeconds,
      state.loadScanSeconds, state.loadTargetPolls, state.loadTargetPollSeconds,
      state.loadTargetFallbacks, state.loadChoiceSeconds, state.loadApplySeconds,
      state.loadWaitSeconds, state.loadStructureChanges, state.loadMetadataHits,
      state.loadMetadataMisses, tostring(state.loadMetadataDisabled)), "info")
end

local function loadPreset()
  if not state.selected or not state.presets[state.selected] then
    resetLoadState()
    setStatus("load", "Select a preset.", true)
    return
  end
  local selectedPreset = hydrateNamedPreset(state.selected)
  if not selectedPreset then
    resetLoadState()
    setStatus("load", "The selected preset could not be read safely.", true)
    return
  end
  local optionsStarted = helpers.loadClock()
  local system, options, optionsError = getOptions()
  state.loadOptionsSeconds = state.loadOptionsSeconds
    + math.max(0, helpers.loadClock() - optionsStarted)
  state.loadOptionCalls = state.loadOptionCalls + 1
  if not options then
    setStatus("load", "Open a customization screen before loading a preset.", true)
    log("[load] " .. tostring(optionsError), "warn")
    return
  end
  if state.loadPresetName ~= state.selected then refreshPreflight() end

  local preset = selectedPreset
  local values, savedCounts, orderedEntries, savedSlotCounts, valueCount, savedEntryByKey
  if state.loadPresetName == state.selected then
    state.loadPass = state.loadPass + 1
    values = state.loadValues
    savedCounts = state.loadSavedCounts
    orderedEntries = state.loadOrderedEntries
    savedEntryByKey = state.loadSavedEntryByKey
    savedSlotCounts = state.loadSavedSlotCounts
    valueCount = state.loadValueCount
  else
    auditSection("LOAD PRESET")
    log(("[PRESET] Load requested: name='%s'"):format(tostring(state.selected)), "load")
    state.loadPresetName = state.selected
    state.loadPass = 1
    state.previousUnresolvedSignature = nil
    state.unresolvedRepeatCount = 0
    state.loadSatisfied = {}
    state.loadForcedKeys = {}
    state.loadResolvedChoiceIndexes = {}
    state.loadApplyAttempts = {}
    state.loadUnconfirmed = {}
    state.loadCleanupAttempts = {}
    state.loadCleanupSkipped = {}
    state.loadPhase = "apply"
    state.loadReturnToCleanup = false
    values, savedCounts, orderedEntries, savedSlotCounts, valueCount, savedEntryByKey = {}, {}, {}, {}, 0, {}
    for _, entry in ipairs(preset.entries or {}) do
      local label = tostring(entry.key or "")
      if label ~= "" then
        savedCounts[label] = (savedCounts[label] or 0) + 1
        local savedKey = label .. "\31" .. tostring(savedCounts[label])
        values[savedKey] = tonumber(entry.index) or 0
        local slot = tostring(entry.slot or "")
        local slotOccurrence = nil
        if slot ~= "" then
          savedSlotCounts[slot] = (savedSlotCounts[slot] or 0) + 1
          slotOccurrence = savedSlotCounts[slot]
        end
        table.insert(orderedEntries, {
          key = savedKey,
          label = label,
          index = tonumber(entry.index) or 0,
          slot = slot ~= "" and slot or nil,
          slotOccurrence = slotOccurrence,
          choice = entry.choice,
          position = #orderedEntries + 1,
        })
        savedEntryByKey[savedKey] = orderedEntries[#orderedEntries]
        valueCount = valueCount + 1
      end
    end
    state.loadValues = values
    state.loadSavedCounts = savedCounts
    state.loadOrderedEntries = orderedEntries
    state.loadSavedEntryByKey = savedEntryByKey
    state.loadSavedSlotCounts = savedSlotCounts
    state.loadValueCount = valueCount
  end
  state.loadStalled = false
  if valueCount == 0 then setStatus("load", "The preset contains no saved options.", true); return end

  if state.loadPass == 1 then
    log(("Preset='%s' | saved=%d options | editor exposes=%d options | format=%s")
      :format(state.selected, valueCount, #options, tostring(preset.format or 1)),
      "load")
  end

  local applied, missing, ambiguous, invalid = 0, 0, 0, 0
  local deferred = {}
  local unresolved = {}
  local seen = {}
  if helpers.pollPendingOption(options) == "waiting" then return end
  local scan = helpers.scanLoadOptions(options, savedCounts, savedSlotCounts)
  local exposed = scan.exposed
  local activeKeySet = scan.activeKeySet
  local activeCounts = scan.activeCounts
  local activeExposed = scan.activeExposed
  local exposedBySlot = scan.exposedBySlot
  local activeSlotCounts = scan.activeSlotCounts

  local pendingResult = helpers.checkPendingChange(system, scan)
  if pendingResult == "waiting" or pendingResult == "failed" then return end
  if (pendingResult == "settled" or pendingResult == "unconfirmed")
      and state.loadPhase == "verify" then
    state.loadRemaining = valueCount
    state.loadNeedsContinue = true
    setStatus("load", "A remaining option was cleared. Verifying the preset again.")
    return
  end

  if state.loadPhase == "cleanup" then
    for _, exposedOption in ipairs(exposed) do
      local label = exposedOption.label
      local occurrence = exposedOption.occurrence
      local cleanupKey = exposedOption.key
      local current = tonumber(exposedOption.option.currIndex) or 0
      local remap = cleanupKey and state.loadDependencyRemaps[cleanupKey] or nil
      local keepRemap = remap and state.loadSatisfied[remap.savedKey]
        and exposedOption.slot == remap.slot
        and exposedOption.slotOccurrence == remap.slotOccurrence
        and (activeSlotCounts[remap.slot] or 0) == remap.slotCount
        and optionChoiceMatchesIndex(
          exposedOption.option, remap.choice, remap.target)
      if remap and not keepRemap then
        state.loadDependencyRemaps[cleanupKey] = nil
      end
      if cleanupKey and occurrence > (savedCounts[label] or 0)
          and current ~= 0 and not keepRemap
          and not state.loadCleanupSkipped[cleanupKey] then
        local ok, clearError = helpers.beginPendingChange(
          system, exposedOption, 0, "cleanup", cleanupKey, current)
        if not ok then
          state.resetBeforeLoad = false
          state.loadNeedsContinue = false
          state.loadStalled = true
          log(("FAILED | pass=%d | %s | index %d -> 0 | reset leftover | %s")
            :format(state.loadPass,
              state.loadOptionIdentity(exposedOption.option, label, occurrence),
              current, tostring(clearError)), "error")
          setStatus("load",
            "Loading stopped because a remaining option could not be cleared safely. Close the editor without confirming, reopen it, and retry.",
            true)
          helpers.logLoadMeasurements("cleanup-failed")
        else
          log(("CHANGE | pass=%d | %s | index %d -> 0 | post-apply leftover cleanup")
            :format(state.loadPass,
              state.loadOptionIdentity(exposedOption.option, label, occurrence),
              current), "info")
          setStatus("load", "Clearing one remaining option. Waiting for the editor.")
        end
        return
      end
    end
    state.loadPhase = "verify"
    state.loadReturnToCleanup = false
    state.resetBeforeLoad = false
    state.loadRemaining = valueCount
    state.loadNeedsContinue = true
    helpers.clearVisibleLoadSatisfaction(scan)
    log("CLEANUP | No additional exposed leftover options require resetting. Verifying the preset.", "info")
    setStatus("load", "Cleanup complete. Verifying the preset again.")
    return
  end

  local satisfiedBefore = 0
  for _, exposedOption in ipairs(exposed) do
    local key = exposedOption.key
    local label = exposedOption.label
    local wanted = key and values[key] or nil
    local savedEntry = key and savedEntryByKey[key] or nil
    if wanted ~= nil and savedEntry and savedEntry.choice then
      local cachedIndex = state.loadResolvedChoiceIndexes[key]
      local resolvedIndex = helpers.resolveLoadChoice(
        exposedOption.option, savedEntry.choice, cachedIndex)
      if resolvedIndex ~= nil then
        state.loadResolvedChoiceIndexes[key] = resolvedIndex
        wanted = resolvedIndex
        values[key] = resolvedIndex
      end
    end
    local countMatches = label
      and (savedCounts[label] or 0) == (activeCounts[label] or 0)
    if wanted ~= nil and countMatches and optionIndexIsValid(wanted)
        and ((tonumber(exposedOption.option.currIndex) or 0) == wanted
          or (state.loadSatisfied[key] and state.loadUnconfirmed[key])) then
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
    local savedEntry = key and savedEntryByKey[key] or nil
    local choiceUnavailable = false
    if wanted ~= nil and savedEntry and savedEntry.choice then
      local resolvedIndex = helpers.resolveLoadChoice(
        option, savedEntry.choice, state.loadResolvedChoiceIndexes[key])
      if resolvedIndex == nil then
        state.loadResolvedChoiceIndexes[key] = nil
        choiceUnavailable = true
      else
        state.loadResolvedChoiceIndexes[key] = resolvedIndex
        wanted = resolvedIndex
        values[key] = resolvedIndex
      end
    end
    local countMatches = label
      and (savedCounts[label] or 0) == (activeCounts[label] or 0)
    local indexIsValid = wanted == nil or optionIndexIsValid(wanted)
    if wanted ~= nil then
      seen[key] = true
      if choiceUnavailable then
        missing = missing + 1
        unresolved["unavailable-choice:" .. tostring(key)] = true
        state.logLoadOnce("unavailable-choice:" .. tostring(key),
          ("[SKIPPED] Saved choice is no longer exposed for %s choice='%s'")
            :format(state.loadOptionIdentity(option, label, exposedOption.occurrence),
              tostring(savedEntry.choice)), "warn")
      elseif not countMatches then
        ambiguous = ambiguous + 1
        unresolved["ambiguous:" .. tostring(key)] = true
        state.logLoadOnce("ambiguous:" .. tostring(key),
          ("[SKIPPED] Ambiguous repeated option: %s savedCount=%d exposedCount=%d")
            :format(
              state.loadOptionIdentity(option, label, exposedOption.occurrence),
              savedCounts[label] or 0,
              activeCounts[label] or 0
            ), "warn")
      elseif not indexIsValid then
        invalid = invalid + 1
        unresolved["invalid-index:" .. tostring(key)] = true
        state.logLoadOnce("invalid-index:" .. tostring(key),
          ("[SKIPPED] Saved index is outside the supported native range: %s targetIndex=%s")
            :format(state.loadOptionIdentity(option, label, exposedOption.occurrence),
              tostring(wanted)), "warn")
      end
    end
    if wanted ~= nil and not choiceUnavailable and countMatches and indexIsValid
        and option.isEditable and option.isActive then
      local current = tonumber(option.currIndex) or 0
      if current == wanted then
        state.loadSatisfied[key] = true
        state.loadUnconfirmed[key] = nil
        applied = applied + 1
      elseif state.loadSatisfied[key] and state.loadUnconfirmed[key] then
        applied = applied + 1
      elseif state.loadSatisfied[key] then
        deferred[key] = true
        missing = missing + 1
        unresolved["reverted:" .. tostring(key)] = true
      else
        if savedEntry and savedEntry.choice and wanted ~= savedEntry.index then
          log(("CHOICE REMAP | pass=%d | %s | savedIndex=%s currentIndex=%s choice='%s'")
            :format(state.loadPass,
              state.loadOptionIdentity(option, label, exposedOption.occurrence),
              tostring(savedEntry.index), tostring(wanted), tostring(savedEntry.choice)),
            "info")
        end
        local ok, applyError = helpers.beginPendingChange(
          system, exposedOption, wanted, "apply", key, current)
        if ok then
          state.loadRemaining = math.max(0, valueCount - satisfiedBefore - 1)
          log(("CHANGE | pass=%d | %s | index %s -> %s")
            :format(state.loadPass,
              state.loadOptionIdentity(option, label, exposedOption.occurrence),
              tostring(current), tostring(wanted)), "info")
          setStatus("load", ("Applied one option. Waiting for the editor; %d %s remain%s to be checked.")
            :format(state.loadRemaining,
              state.loadRemaining == 1 and "option" or "options",
              state.loadRemaining == 1 and "s" or ""))
        else
          state.loadNeedsContinue = false
          state.loadStalled = true
          log(("FAILED | pass=%d | %s | target index %s | %s")
            :format(state.loadPass,
              state.loadOptionIdentity(option, label, exposedOption.occurrence),
              tostring(wanted), tostring(applyError)), "error")
          setStatus("load",
            "Loading stopped because an option could not be applied safely. " ..
            "Close the editor without confirming, reopen it, and retry.",
            true
          )
          helpers.logLoadMeasurements("apply-failed")
        end
        return
      end
    end
  end
  for key, wanted in pairs(values) do
    if wanted == 0 and not activeKeySet[key] and not state.loadSatisfied[key] then
      state.loadSatisfied[key] = true
      local hiddenLabel, hiddenOccurrence = occurrenceKeyParts(key)
      log(("VERIFY | %s | target index=0 | already clear because the dependent option is hidden")
        :format(optionAuditIdentity(nil, hiddenLabel, hiddenOccurrence)), "info")
    end
  end
  local claimedOptions = {}
  for _, exposedOption in ipairs(exposed) do
    if exposedOption.key and values[exposedOption.key] ~= nil then
      claimedOptions[exposedOption.option] = true
    end
  end
  for _, entry in ipairs(orderedEntries or {}) do
    local savedKey = entry.key
    if not seen[savedKey]
        and entry.slot and entry.choice
        and (savedSlotCounts[entry.slot] or 0) == (activeSlotCounts[entry.slot] or 0) then
      local slotKey = entry.slot .. "\31" .. tostring(entry.slotOccurrence or 1)
      local candidate = exposedBySlot[slotKey]
      if candidate and candidate.option.isEditable and candidate.option.isActive
          and not claimedOptions[candidate.option] then
        local target = helpers.resolveLoadChoice(candidate.option, entry.choice,
          state.loadResolvedChoiceIndexes[savedKey])
        if target ~= nil and optionIndexIsValid(target) then
          state.loadResolvedChoiceIndexes[savedKey] = target
          seen[savedKey] = true
          claimedOptions[candidate.option] = true
          state.loadDependencyRemaps[candidate.key] = {
            savedKey = savedKey,
            slot = candidate.slot,
            slotOccurrence = candidate.slotOccurrence,
            slotCount = savedSlotCounts[entry.slot] or 0,
            choice = entry.choice,
            target = target,
          }
          local current = tonumber(candidate.option.currIndex) or 0
          if current == target then
            state.loadSatisfied[savedKey] = true
            state.loadUnconfirmed[savedKey] = nil
            applied = applied + 1
          elseif state.loadSatisfied[savedKey] and state.loadUnconfirmed[savedKey] then
            applied = applied + 1
          elseif state.loadSatisfied[savedKey] then
            deferred[savedKey] = true
            missing = missing + 1
            unresolved["reverted-remap:" .. tostring(savedKey)] = true
          else
            state.loadDependencyKeys[savedKey] = true
            local ok, applyError = helpers.beginPendingChange(
              system, candidate, target, "apply", savedKey, current)
            if ok then
              state.loadRemaining = math.max(0, valueCount - satisfiedBefore - 1)
              log(("DEPENDENCY REMAP | pass=%d | saved LocKey='%s' disappeared | uiSlot='%s' and saved choice='%s' matched %s | index %s -> %s")
                :format(state.loadPass, entry.label, entry.slot, entry.choice,
                  optionAuditIdentity(candidate.option, candidate.label,
                    candidate.occurrence), tostring(current), tostring(target)), "info")
              setStatus("load",
                "A hairstyle-dependent option was replaced. Its saved choice was matched safely; waiting for the editor.")
            else
              state.loadNeedsContinue = false
              state.loadStalled = true
              log(("DEPENDENCY REMAP FAILED | pass=%d | saved LocKey='%s' | uiSlot='%s' target index %s | %s")
                :format(state.loadPass, entry.label, entry.slot, tostring(target),
                  tostring(applyError)), "error")
              helpers.logLoadMeasurements("dependency-remap-failed")
              setStatus("load",
                "Loading stopped because a replaced hairstyle-dependent option could not be applied safely. Close the editor without confirming, reopen it, and retry.",
                true)
            end
            return
          end
        end
      end
    end
  end
  if state.forceFullLoad then
    if not state.loadMetadataDisabled then
      state.loadMetadataCache = nil
      state.loadMetadataDisabled = true
      state.loadResolvedChoiceIndexes = {}
      state.loadOptionIdentityCache = {}
      state.loadDependencyRemaps = {}
      log("[CACHE] Force Full Load fallback disabled metadata reuse for this load.", "info")
    end
    for _, entry in ipairs(orderedEntries or {}) do
      local savedKey = entry.key
      if not seen[savedKey] and not state.loadSatisfied[savedKey]
          and optionIndexIsValid(entry.index) then
        local candidate = nil
        local method = nil
        if entry.slot
            and (savedSlotCounts[entry.slot] or 0) == (activeSlotCounts[entry.slot] or 0) then
          local slotKey = entry.slot .. "\31" .. tostring(entry.slotOccurrence or 1)
          candidate = exposedBySlot[slotKey]
          method = "uiSlot"
        elseif not entry.slot and entry.position and entry.position > 1
            and entry.position < #(orderedEntries or {}) then
          local previousEntry = orderedEntries[entry.position - 1]
          local nextEntry = orderedEntries[entry.position + 1]
          local positioned = activeExposed[entry.position]
          if positioned and activeExposed[entry.position - 1]
              and activeExposed[entry.position + 1]
              and activeExposed[entry.position - 1].key == previousEntry.key
              and activeExposed[entry.position + 1].key == nextEntry.key
              and values[positioned.key] == nil then
            candidate = positioned
            method = "anchored legacy position"
          end
        end
        if candidate and candidate.option.isEditable and candidate.option.isActive
            and not claimedOptions[candidate.option] then
          local target = entry.choice and helpers.resolveLoadChoice(
            candidate.option, entry.choice, nil)
            or entry.index
          if target ~= nil and optionIndexIsValid(target) then
            seen[savedKey] = true
            local current = tonumber(candidate.option.currIndex) or 0
            if current == target then
              state.loadSatisfied[savedKey] = true
              state.loadUnconfirmed[savedKey] = nil
              state.loadForcedKeys[savedKey] = true
            else
              local ok, applyError = helpers.beginPendingChange(
                system, candidate, target, "apply", savedKey, current)
              if ok then
                state.loadPendingChange.forced = true
                state.loadRemaining = math.max(0, valueCount - satisfiedBefore - 1)
                log(("FORCED | pass=%d | saved LocKey='%s' unavailable | %s fallback -> %s | index %s -> %s")
                  :format(state.loadPass, entry.label, method,
                    optionAuditIdentity(candidate.option, candidate.label, candidate.occurrence),
                    tostring(current), tostring(target)), "warn")
                setStatus("load",
                  "Applied one unmatched option using Force Full Load. Waiting for the editor.")
                return
              else
                state.loadForcedKeys[savedKey] = nil
                log(("FORCE FAILED | pass=%d | saved LocKey='%s' | %s fallback target index %s | %s")
                  :format(state.loadPass, entry.label, method, tostring(target),
                    tostring(applyError)), "error")
                state.loadNeedsContinue = false
                state.loadStalled = true
                helpers.logLoadMeasurements("force-failed")
                setStatus("load",
                  "Loading stopped because Force Full Load could not apply an option safely. Close the editor without confirming, reopen it, and retry.",
                  true)
                return
              end
            end
          elseif entry.choice then
            state.logLoadOnce("force-choice:" .. tostring(savedKey),
              ("[SKIPPED] Force Full Load found the selector but not its saved choice: LocKey='%s' choice='%s'.")
                :format(entry.label, tostring(entry.choice)), "warn")
          end
        end
      end
    end
  end

  for key in pairs(deferred) do state.loadSatisfied[key] = nil end

  local forced = 0
  for key in pairs(values) do
    if not seen[key] then
      if state.loadSatisfied[key] then
        applied = applied + 1
        if state.loadForcedKeys[key] then forced = forced + 1 end
        local hiddenLabel, hiddenOccurrence = occurrenceKeyParts(key)
        log(("VERIFY | %s | target index=%s | applied, then hidden by dependency")
          :format(optionAuditIdentity(nil, hiddenLabel, hiddenOccurrence),
            tostring(values[key])), "info")
      else
        missing = missing + 1
        unresolved["unavailable:" .. tostring(key)] = true
        local missingLabel, missingOccurrence = occurrenceKeyParts(key)
        state.logLoadOnce("unavailable:" .. tostring(key),
          ("[SKIPPED] Saved option unavailable in current editor/body setup: %s targetIndex=%s")
            :format(state.loadOptionIdentity(nil, missingLabel, missingOccurrence),
              tostring(values[key])), "warn")
      end
    elseif state.loadForcedKeys[key] then
      applied = applied + 1
      forced = forced + 1
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
      helpers.logLoadMeasurements("stopped")
      setStatus("load", (
        "Loading stopped because %d of %d options were still missing after %d checks. " ..
        "Adding, removing, updating, or changing the order of CCXL mods can move or rename options. " ..
        "Check your option mods. Correct the appearance if needed, then save the preset again."
      ):format(state.loadRemaining, valueCount, STALL_CONFIRMATION_PASSES))
    else
      state.loadNeedsContinue = true
      setStatus("load", ("Pass %d complete: %d of %d applied, %d remaining. Continuing automatically.")
        :format(state.loadPass, applied, valueCount, state.loadRemaining))
    end
  else
    if state.loadPhase == "apply" and state.resetBeforeLoad then
      state.loadPhase = "cleanup"
      state.loadRemaining = valueCount
      state.loadNeedsContinue = true
      state.previousUnresolvedSignature = nil
      state.unresolvedRepeatCount = 0
      log("APPLY | Saved preset options were processed. Checking for genuine leftovers next.", "info")
      setStatus("load", "Preset options applied. Checking for remaining options.")
      return
    end
    if state.loadPhase == "verify" and state.loadReturnToCleanup then
      state.loadPhase = "cleanup"
      state.loadReturnToCleanup = false
      state.loadRemaining = valueCount
      state.loadNeedsContinue = true
      state.previousUnresolvedSignature = nil
      state.unresolvedRepeatCount = 0
      log("VERIFY | Post-cleanup preset check finished. Checking for another leftover option.", "info")
      setStatus("load", "Preset checked. Looking for another remaining option.")
      return
    end
    local cleanupSkipped = 0
    for _ in pairs(state.loadCleanupSkipped) do cleanupSkipped = cleanupSkipped + 1 end
    local unconfirmed = 0
    for key in pairs(state.loadUnconfirmed) do
      if values[key] ~= nil then unconfirmed = unconfirmed + 1 end
    end
    state.loadNeedsContinue = false
    state.loadStalled = false
    state.previousUnresolvedSignature = nil
    state.unresolvedRepeatCount = 0
    refreshCustomizationUi()
    log(("SUMMARY | preset='%s' | processed=%d | confirmed=%d | unconfirmed=%d | forced=%d | cleanupUnconfirmed=%d | failed=0 | unavailable=0 | ambiguous=0 | passes=%d | result=%s")
      :format(state.selected, applied, math.max(0, applied - unconfirmed), unconfirmed,
        forced, cleanupSkipped, state.loadPass,
        (cleanupSkipped > 0 or unconfirmed > 0) and "complete-with-warning" or "complete"),
      (cleanupSkipped > 0 or unconfirmed > 0) and "warn" or "complete")
    helpers.logLoadMeasurements("complete")
    if cleanupSkipped > 0 or unconfirmed > 0 then
      local details = {}
      if unconfirmed > 0 then
        details[#details + 1] = ("%d saved option%s could not be confirmed")
          :format(unconfirmed, unconfirmed == 1 and "" or "s")
      end
      if cleanupSkipped > 0 then
        details[#details + 1] = ("%d remaining option%s could not be confirmed as cleared")
          :format(cleanupSkipped, cleanupSkipped == 1 and "" or "s")
      end
      setStatus("load", "Preset load finished, but " .. table.concat(details, " and ") ..
        ". Check the appearance and Activity Log before confirming the editor.",
        false, "warning")
    elseif forced > 0 then
      setStatus("load", (
        "Preset fully applied: %d options applied in %d pass%s. Force Full Load matched %d option%s. " ..
        "Check the hair, hair color, and other forced options."
      ):format(valueCount, state.loadPass, state.loadPass == 1 and "" or "es", forced,
        forced == 1 and "" or "s"), false, "success")
    else
      setStatus("load", ("Preset fully applied: %d options applied in %d pass%s.")
        :format(valueCount, state.loadPass, state.loadPass == 1 and "" or "es"),
        false, "success")
    end
  end
end

refreshPreflight = function()
  state.preflight = nil
  state.preflightDirty = false
  state.preflightPresetName = state.selected
  local preset = state.selected and state.presets[state.selected]
  if not preset then return end
  local wasLazy = not preset.entries
  preset = hydrateNamedPreset(state.selected)
  if not preset then return end
  if wasLazy then
    state.presetNotes = preset.notes or ""
    state.presetTags = preset.tags or ""
    writeInventory(state.presets, state.folders)
  end
  local _, options = getOptions()
  state.inCustomization = options ~= nil
  if not options then return end
  local savedCounts, savedSlotCounts = {}, {}
  for _, entry in ipairs(preset.entries or {}) do
    savedCounts[entry.key] = (savedCounts[entry.key] or 0) + 1
    local slot = tostring(entry.slot or "")
    if slot ~= "" then savedSlotCounts[slot] = (savedSlotCounts[slot] or 0) + 1 end
  end
  local exposedCounts, exposedByLabel, exposedBySlot = {}, {}, {}
  local activeSlotCounts = {}
  for _, option in ipairs(options) do
    local key = optionKey(option)
    if key and option.isEditable and option.isActive then
      exposedCounts[key] = (exposedCounts[key] or 0) + 1
      exposedByLabel[key] = exposedByLabel[key] or {}
      table.insert(exposedByLabel[key], option)
      local slot = optionSlot(option)
      if slot then
        activeSlotCounts[slot] = (activeSlotCounts[slot] or 0) + 1
        exposedBySlot[slot] = exposedBySlot[slot] or {}
        table.insert(exposedBySlot[slot], option)
      end
    end
  end
  local available, unavailable, ambiguous, invalid = 0, 0, 0, 0
  local savedOccurrences, savedSlotOccurrences, claimedOptions = {}, {}, {}
  for _, entry in ipairs(preset.entries or {}) do
    local key = entry.key
    savedOccurrences[key] = (savedOccurrences[key] or 0) + 1
    local candidate = nil
    if (exposedCounts[key] or 0) == (savedCounts[key] or 0) then
      candidate = (exposedByLabel[key] or {})[savedOccurrences[key]]
    end
    local slot = tostring(entry.slot or "")
    if slot ~= "" then
      savedSlotOccurrences[slot] = (savedSlotOccurrences[slot] or 0) + 1
    end
    if not candidate and slot ~= ""
        and (savedSlotCounts[slot] or 0) == (activeSlotCounts[slot] or 0) then
      local slotCandidate = (exposedBySlot[slot] or {})[savedSlotOccurrences[slot]]
      if slotCandidate and not claimedOptions[slotCandidate]
          and (state.forceFullLoad
            or (entry.choice and optionChoiceIndex(slotCandidate, entry.choice) ~= nil)) then
        candidate = slotCandidate
      end
    end
    if not optionIndexIsValid(tonumber(entry.index)) then
      invalid = invalid + 1
    elseif candidate and not claimedOptions[candidate] then
      if entry.choice and optionChoiceIndex(candidate, entry.choice) == nil then
        unavailable = unavailable + 1
      else
        available = available + 1
        claimedOptions[candidate] = true
      end
    elseif tonumber(entry.index) == 0 and (exposedCounts[key] or 0) == 0 then
      available = available + 1
    elseif (exposedCounts[key] or 0) == 0 then
      unavailable = unavailable + 1
    else
      ambiguous = ambiguous + 1
    end
  end
  state.preflight = {
    total = state.presetEntryCount(preset),
    available = available,
    unavailable = unavailable,
    ambiguous = ambiguous,
    invalid = invalid,
  }
end

local function cancelLoading()
  local name = state.loadPresetName or state.selected
  if state.loadPresetName then helpers.logLoadMeasurements("canceled") end
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
local restoreTrashBundle
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
    log("[TRASH] The Trash list contains an unsafe entry or too many entries.", "error")
    return false
  end
  local result, changed = writeLinesIfChanged(
    TRASH_CATALOG_FILE, lines, "Trash list", MAX_CATALOG_BYTES)
  if result and not changed then
    log("[TRASH] The saved Trash list is already current. No file update was needed.", "info")
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
    log("[TRASH] The Trash list cannot be read, contains unsafe data, or is too large. The last good Trash list was kept.", "error")
    return false
  end
  for filename, item in pairs(recoveredOriginals or {}) do originals[filename] = item end
  local trash, trashBundles = {}, {}
  local entries, listError = safeDirectoryEntries(TRASH_DIR, 0)
  if not entries then
    log(("[TRASH] The Trash folder could not be read safely: %s. The last good Trash list was kept.")
      :format(tostring(listError)), "error")
    return false
  end
  local trashPresetCount = 0
  for _, entry in ipairs(entries) do
    if entry.type == "file" and entry.name:lower():sub(-7) == ".preset" then
      if trashPresetCount >= AUTO_LOAD_LIMITS.maximumScannedPresets then
        log("[TRASH] The Trash folder contains more presets than the safety limit. The last good Trash list was kept.", "error")
        return false
      end
      trashPresetCount = trashPresetCount + 1
      local catalogItem = originals[entry.name]
      trash[entry.name] = {
        original = catalogItem and catalogItem.original or entry.name:sub(1, -8),
        group = catalogItem and catalogItem.group or nil,
        preset = { entryCount = 0, entryCountKnown = false, lazy = true },
      }
    elseif entry.type == "file" and isFolderBundleFilename(entry.name) then
      trashBundles[entry.name] = true
    end
  end
  state.trash = trash
  state.trashGroups = groups
  state.trashBundles = trashBundles
  state.trashViewDirty = true
  if not writeTrashCatalog(trash, groups) then return false end
  return true
end

state.invalidateTrashViewCache = function()
  state.trashViewDirty = true
end

state.ensureTrashViewCache = function()
  if not state.trashViewDirty then return end
  local trashNames, groupIds, bundleNames, groupStats = {}, {}, {}, {}
  for filename, item in pairs(state.trash) do
    table.insert(trashNames, filename)
    if item.group then
      local stats = groupStats[item.group] or { presets = 0, folders = 0 }
      stats.presets = stats.presets + 1
      groupStats[item.group] = stats
    end
  end
  for groupId, group in pairs(state.trashGroups) do
    table.insert(groupIds, groupId)
    local stats = groupStats[groupId] or { presets = 0, folders = 0 }
    for _ in pairs(group.folders or {}) do stats.folders = stats.folders + 1 end
    groupStats[groupId] = stats
  end
  for filename in pairs(state.trashBundles) do table.insert(bundleNames, filename) end
  table.sort(trashNames, function(a, b) return a:lower() < b:lower() end)
  table.sort(groupIds, function(a, b)
    return state.trashGroups[a].root:lower() < state.trashGroups[b].root:lower()
  end)
  table.sort(bundleNames, function(a, b) return a:lower() < b:lower() end)
  state.cachedTrashNames = trashNames
  state.cachedTrashGroupIds = groupIds
  state.cachedTrashBundleNames = bundleNames
  state.cachedTrashGroupStats = groupStats
  state.trashViewDirty = false
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

local function uniqueRestoredBundleFilename(filename)
  local stem = filename:sub(1, -#FOLDER_BUNDLE_EXTENSION - 1)
  for index = 1, 9999 do
    local suffix = index == 1 and "" or (" Copy %d"):format(index)
    local candidate = stem:sub(1, 255 - #FOLDER_BUNDLE_EXTENSION - #suffix) ..
      suffix .. FOLDER_BUNDLE_EXTENSION
    if not fileExists(PRESET_DIR .. "/" .. candidate) then return candidate end
  end
  return nil
end

restoreTrashBundle = function(filename)
  if not state.trashBundles[filename] or not isFolderBundleFilename(filename) then
    setStatus("delete", "The shared-folder file is no longer in Trash.", true)
    return
  end
  local sourcePath = TRASH_DIR .. "/" .. filename
  local fingerprint = fileFingerprint(sourcePath, MAX_FOLDER_BUNDLE_BYTES)
  local restoredFilename = fingerprint and uniqueRestoredBundleFilename(filename) or nil
  if not fingerprint then
    setStatus("delete", "The shared-folder file in Trash could not be checked safely.", true)
    return
  end
  if not restoredFilename then
    setStatus("delete", "The mod could not create a safe file name for the restored shared folder.", true)
    return
  end
  local destinationPath = PRESET_DIR .. "/" .. restoredFilename
  local moved, moveError = os.rename(sourcePath, destinationPath)
  if not moved then
    setStatus("delete", "The shared-folder file could not be restored: " ..
      tostring(moveError), true)
    return
  end
  if fileFingerprint(destinationPath, MAX_FOLDER_BUNDLE_BYTES) ~= fingerprint then
    local rolledBack = os.rename(destinationPath, sourcePath) ~= nil
    setStatus("delete", rolledBack
      and "The restored shared-folder file could not be checked, so it was returned to Trash."
      or "The restored shared-folder file could not be checked or returned to Trash.", true)
    return
  end
  state.trashBundles[filename] = nil
  state.invalidateTrashViewCache()
  state.selectedBundleFile = restoredFilename
  state.folderBundleFilesDirty = true
  setStatus("delete", ("Restored shared-folder file \"%s\" to Character Presets.")
    :format(restoredFilename), false, "success")
  log(("[FOLDER BUNDLE] Restored Trash file='%s' as '%s'.")
    :format(filename, restoredFilename), "complete")
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
    setStatus("delete", "The mod could not create a safe file name in Trash.", true)
    return
  end
  local trashPath = TRASH_DIR .. "/" .. trashFilename
  local plan = {
    storage = preset.storage,
    trashFilename = trashFilename,
    name = old,
  }
  if not writeTransaction("prepared", "trash", { plan }) then
    setStatus("delete", "The recovery record for this Trash action could not be created.", true)
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
      and "The preset was returned because the Trash records could not be saved."
      or "The Trash operation failed, and the preset file could not be restored.", true)
    return
  end
  state.selected = nil
  state.presetNotes = ""
  state.presetTags = ""
  invalidatePresetAndTrashCaches()
  state.renameName = ""
  resetLoadState()
  clearStatus("rename")
  if writeInventory(state.presets, state.folders) then
    setStatus("delete", "Moved \"" .. old .. "\" to Trash.", false, "success")
  else
    setStatus("delete", "Moved \"" .. old .. "\" to Trash, but the preset file list could not be updated.",
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
    setStatus("delete", "The mod could not create an unused name for the restored preset.", true); return
  end
  local storage = uniqueStorageName(baseName(logicalName))
  if not storage then
    setStatus("delete", "The mod could not create a safe file name for the restored preset.", true); return
  end
  local sourcePath = TRASH_DIR .. "/" .. filename
  local destinationPath = PRESET_DIR .. "/" .. storage .. ".preset"
  local plan = {
    storage = storage, trashFilename = filename, name = logicalName,
    recoveryName = item.original,
  }
  if not writeTransaction("prepared", "restore", { plan }) then
    setStatus("delete", "The recovery record for this restore action could not be created.", true); return
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
  preset.fingerprint = fileFingerprint(destinationPath, MAX_PRESET_BYTES)
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
      and "The preset was returned to Trash because the restore records could not be saved."
      or "The restore could not finish or return the file to Trash. The mod will try to recover it at the next startup.", true)
    return
  end
  state.selected = logicalName
  state.presetNotes = preset.notes or ""
  state.presetTags = preset.tags or ""
  invalidatePresetAndTrashCaches()
  local inventorySaved = writeInventory(state.presets, state.folders)
  setStatus("delete", "Restored \"" .. logicalName .. "\" from Trash." ..
    (inventorySaved and "" or " The preset file list could not be updated."), false,
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
    setStatus("delete", "The existing preset file names could not be checked safely.", true); return
  end
  for name in pairs(state.presets) do reservedLogical[name:lower()] = true end
  local plans = {}
  for _, filename in ipairs(filenames) do
    local item = state.trash[filename]
    local logicalName = allocateRestoreLogicalName(item.original, reservedLogical)
    local storage = logicalName and uniqueStorageName(baseName(logicalName), reservedStorage)
    if not logicalName or not storage then
      setStatus("delete", "The mod could not create a safe name for every preset in this folder.", true); return
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
    setStatus("delete", "The recovery record for this folder restore could not be created.", true); return
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
        and "The folder restore stopped, and some files could not be returned to Trash. The mod will try to recover them at the next startup."
        or "Folder restore stopped before all preset files could be moved.", true)
      return
    end
    local verified = readPresetFile(plan.destination)
    if not verified or (plan.item.preset.entryCountKnown ~= false
        and not presetsMatch(plan.item.preset, verified)) then
      table.insert(moved, plan)
      local rollbackFailed = false
      for index = #moved, 1, -1 do
        local item = moved[index]
        if not os.rename(item.destination, item.source) then rollbackFailed = true end
      end
      if not rollbackFailed then os.remove(TRANSACTION_FILE) end
      setStatus("delete", rollbackFailed
        and "A restored preset could not be checked, and some files could not be returned to Trash. The mod will try to recover them at the next startup."
        or "Folder restore verification failed; moved files were returned to Trash.", true)
      return
    end
    verified.fingerprint = fileFingerprint(plan.destination, MAX_PRESET_BYTES)
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
      and "The folder restore could not finish, and some files could not be returned to Trash. The mod will try to recover them at the next startup."
      or "The presets were returned to Trash because the folder or Trash lists could not be saved.", true)
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
  invalidatePresetAndTrashCaches()
  resetLoadState()
  local inventorySaved = writeInventory(newPresets, newFolders)
  setStatus("delete", ("Restored folder \"%s\" with %d preset%s, including empty folders inside it.")
    :format(group.root, #plans, #plans == 1 and "" or "s") ..
    (inventorySaved and "" or " The preset file list could not be updated."), false,
    inventorySaved and "success" or "warning")
end

emptyTrash = function()
  local count = 0
  for _ in pairs(state.trash) do count = count + 1 end
  local groupCount = 0
  for _ in pairs(state.trashGroups) do groupCount = groupCount + 1 end
  local bundleCount = 0
  for _ in pairs(state.trashBundles) do bundleCount = bundleCount + 1 end
  if count == 0 and groupCount == 0 and bundleCount == 0 then
    setStatus("delete", "Trash is already empty."); return
  end
  if not state.pendingEmptyTrash then
    cancelConfirmations()
    state.pendingEmptyTrash = true
    setStatus("delete", ("Permanently delete %d preset%s, %d saved folder record%s, and %d shared-folder file%s from Trash? Select Empty Trash Permanently again.")
      :format(count, count == 1 and "" or "s", groupCount,
        groupCount == 1 and "" or "s", bundleCount, bundleCount == 1 and "" or "s"))
    return
  end
  state.pendingEmptyTrash = false
  local failed, presetFailed = 0, 0
  for filename in pairs(state.trash) do
    if os.remove(TRASH_DIR .. "/" .. filename) then
      state.trash[filename] = nil
    else
      failed = failed + 1
      presetFailed = presetFailed + 1
    end
  end
  for filename in pairs(state.trashBundles) do
    if os.remove(TRASH_DIR .. "/" .. filename) then
      state.trashBundles[filename] = nil
    else
      failed = failed + 1
    end
  end
  if presetFailed == 0 then state.trashGroups = {} end
  state.invalidateTrashViewCache()
  local catalogSaved = writeTrashCatalog(state.trash, state.trashGroups)
  if failed > 0 then
    setStatus("delete", ("Trash cleanup stopped with %d file%s remaining.")
      :format(failed, failed == 1 and "" or "s"), true)
  elseif not catalogSaved then
    setStatus("delete", "Trash was emptied, but its list could not be updated.", true)
  else
    setStatus("delete", "Trash emptied permanently.", false, "success")
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
      setStatus("bulk", "The mod could not create a safe file name in Trash.", true)
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
    setStatus("bulk", "The recovery record for moving these items to Trash could not be created.", true)
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
      and "The Trash lists could not be saved, and at least one preset could not be returned. Refresh is complete; check Trash."
      or "The presets were returned because the folder, Trash, or recovery lists could not be saved.", true)
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
  invalidatePresetAndTrashCaches()
  resetLoadState()
  cancelConfirmations()
  local inventorySaved = writeInventory(newPresets, newFolders)
  local physicalFolderRemoved = false
  if physicalFolderWasImported
      and directoryTreeContainsFiles(folderPath(folder), 0) == false then
    physicalFolderRemoved = removeEmptyDirectoryTree(folderPath(folder), 0)
  end
  setStatus("bulk", (folder
    and ("Moved folder \"%s\" and %d preset%s to Trash; removed %d folder%s inside it. Restoring the folder rebuilds this structure.%s")
      :format(folder, #names, #names == 1 and "" or "s", nestedFolderCount,
        nestedFolderCount == 1 and "" or "s",
        physicalFolderWasImported and (physicalFolderRemoved
          and " Its empty Windows folder was removed."
          or " Its Windows folder was kept because it contains other files or could not be removed safely.") or "")
    or ("Moved %d preset%s to Trash. You can restore them later.")
      :format(#names, #names == 1 and "" or "s")) ..
    (inventorySaved and "" or " The preset file list could not be updated."), false,
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
      and ("Move folder \"%s\" and %d preset%s to Trash? Select Confirm Move Folder & Presets to Trash.")
        :format(folder, #names, #names == 1 and "" or "s")
      or ("Move %d selected preset%s to Trash? Select Confirm Bulk Trash.")
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
    setStatus("rename", "The recovery record for this rename could not be created.", true)
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
          and "The name shown in the mod could not be changed, and the file could not be moved back. The folder list now uses the new file name."
          or "The name shown in the mod could not be changed, the file could not be moved back, and the folder list could not be repaired.", true)
        return
      end
      os.remove(TRANSACTION_FILE)
    end
    if persisted then
      writeCatalog(state.presets, state.folders, state.manualFolders,
        state.ignoredPhysicalFolders)
      writeInventory(state.presets, state.folders)
    end
    setStatus("rename", "The preset could not be renamed because the folder list or recovery record could not be saved.", true)
    return
  end
  state.selected = newName
  invalidateViewCache()
  state.renameName = ""
  cancelConfirmations()
  resetLoadState()
  setStatus("rename", "Renamed \"" .. old .. "\" to \"" .. newName .. "\".",
    false, "success")
  log(("[PRESET] Display and physical rename completed: '%s' -> '%s' storage='%s'.")
    :format(old, newName, preset.storage), "complete")
end

local function movePresetToSelectedFolder()
  state.statusKinds.folder = nil
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
      "The preset could not be moved because the folder list could not be saved.", true; return
  end
  state.selected = newName
  invalidateViewCache()
  cancelConfirmations()
  resetLoadState()
  state.folderStatus, state.folderStatusError =
    ("Moved \"%s\" to %s."):format(baseName(newName),
      state.selectedFolder == "" and "All Presets" or state.selectedFolder), false
  state.statusKinds.folder = "success"
  log(("[PRESET] Virtual move completed: '%s' -> '%s' storage='%s'.")
    :format(old, newName, preset.storage), "complete")
end

local function savePresetMetadata()
  if not state.selected or not state.presets[state.selected] then
    setStatus("rename", "Select a preset before saving its details.", true); return
  end
  local preset = hydrateNamedPreset(state.selected)
  if not preset then
    setStatus("rename", "The selected preset could not be read safely.", true)
    return
  end
  local previousNotes, previousTags = preset.notes, preset.tags
  local previousModified, previousFormat = preset.modified, preset.format
  local previousSource = preset.source
  preset.notes = sanitizeMetadata(state.presetNotes, 512)
  preset.tags = sanitizeMetadata(state.presetTags, 128)
  preset.modified = logTimestamp()
  preset.created = preset.created or preset.modified
  preset.source = MOD_NAME
  preset.format = math.max(CURRENT_PRESET_FORMAT, tonumber(preset.format) or 4)
  if not writePresetPath(presetPath(state.selected), preset) then
    preset.notes, preset.tags = previousNotes, previousTags
    preset.modified, preset.format = previousModified, previousFormat
    preset.source = previousSource
    setStatus("rename", "Preset details could not be saved safely.", true)
    return
  end
  state.presetNotes = preset.notes
  state.presetTags = preset.tags
  invalidateViewCache()
  local inventorySaved = writeInventory(state.presets, state.folders)
  setStatus("rename", "Saved details for \"" .. state.selected .. "\"." ..
    (inventorySaved and "" or " The preset file list could not be updated."),
    false, inventorySaved and "success" or "warning")
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
  local sourcePreset = hydrateNamedPreset(source)
  if not sourcePreset then
    setStatus("rename", "The selected preset could not be read safely.", true)
    return
  end
  local storage = uniqueStorageName(baseName(destination))
  if not storage then
    setStatus("rename", "The mod could not create a safe file name for the copy.", true); return
  end
  local destinationPath = PRESET_DIR .. "/" .. storage .. ".preset"
  if not copyFile(presetPath(source), destinationPath) then
    setStatus("rename", cleanupFailureMessage({ destinationPath },
      "The duplicate could not be written.",
      "The duplicate failed, and its partial file could not be removed."), true); return
  end
  local duplicate = readVerifiedPresetCopy(sourcePreset, destinationPath)
  if not duplicate then
    setStatus("rename", cleanupFailureMessage({ destinationPath },
      "The duplicate could not be verified.",
      "Duplicate verification failed, and its file could not be removed."), true); return
  end
  duplicate.storage = storage
  state.presets[destination] = duplicate
  if not persistVirtualState(state.presets, state.folders, state.manualFolders,
      state.ignoredPhysicalFolders) then
    state.presets[destination] = nil
    setStatus("rename", cleanupFailureMessage({ destinationPath },
      "The copy was removed because the folder list could not be saved.",
      "The folder list could not be saved, and the copied file could not be removed."), true)
    return
  end
  state.selected = destination
  invalidateViewCache()
  state.renameName = ""
  cancelConfirmations()
  resetLoadState()
  setStatus("rename", ("Duplicated \"%s\" as \"%s\"."):format(source, destination),
    false, "success")
  log(("[PRESET] Duplicate completed: source='%s' destination='%s' storage='%s'.")
    :format(source, destination, storage), "complete")
end

local function createFolder()
  state.statusKinds.folder = nil
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
    state.folderStatus, state.folderStatusError = "The folder could not be saved.", true; return
  end
  state.selectedFolder = name
  invalidateViewCache()
  state.folderName = ""
  cancelConfirmations()
  state.folderStatus, state.folderStatusError = "Created folder \"" .. name .. "\".", false
  state.statusKinds.folder = "success"
  log(("[FOLDER] Created virtual folder '%s'."):format(name), "complete")
end

local function renameFolder()
  state.statusKinds.folder = nil
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
    state.folderStatus, state.folderStatusError = "The folder could not be renamed because the folder list could not be saved.", true; return
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
    ("Renamed folder \"%s\" to \"%s\"."):format(old, destination), false
  state.statusKinds.folder = "success"
  log(("[FOLDER] Virtual rename completed: '%s' -> '%s'."):format(old, destination), "complete")
end

local function duplicateFolder()
  state.statusKinds.folder = nil
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
      preset = hydrateNamedPreset(name)
      if not preset then
        state.folderStatus, state.folderStatusError = cleanupFailureMessage(createdFiles,
          "Folder duplication stopped because a source preset could not be read.",
          "A source preset could not be read, and some partial files could not be removed."), true; return
      end
      local mapped = remapFolderTreePath(name, source, destination)
      if findPresetCollision(mapped) or newPresets[mapped] then
        state.folderStatus, state.folderStatusError = cleanupFailureMessage(createdFiles,
          "The copied folder would contain duplicate preset names.",
          "Folder duplication found duplicate names, and some partial files could not be removed."), true; return
      end
      local storage = uniqueStorageName(baseName(mapped), reservedStorage)
      if not storage then
        state.folderStatus, state.folderStatusError = cleanupFailureMessage(createdFiles,
          "The mod could not create a safe file name for the copied preset.",
          "Storage allocation failed, and some partial files could not be removed."), true; return
      end
      local path = PRESET_DIR .. "/" .. storage .. ".preset"
      if not copyFile(presetPath(name), path) then
        table.insert(createdFiles, path)
        state.folderStatus, state.folderStatusError = cleanupFailureMessage(createdFiles,
          "Folder duplication failed; partial preset copies were removed.",
          "Folder duplication failed, and some partial files could not be removed."), true; return
      end
      local copy = readVerifiedPresetCopy(preset, path)
      if not copy then
        table.insert(createdFiles, path)
        state.folderStatus, state.folderStatusError = cleanupFailureMessage(createdFiles,
          "Folder duplication verification failed; partial copies were removed.",
          "Folder duplication verification failed, and some partial files could not be removed."), true; return
      end
      copy.storage = storage
      newPresets[mapped] = copy
      table.insert(createdFiles, path)
    end
  end
  if not persistVirtualState(newPresets, newFolders, newManualFolders,
      state.ignoredPhysicalFolders) then
    state.folderStatus, state.folderStatusError = cleanupFailureMessage(createdFiles,
      "The folder copy was removed because the folder list could not be saved.",
      "The folder list could not be saved, and some copied files could not be removed."), true; return
  end
  state.presets = newPresets
  state.folders = newFolders
  state.manualFolders = newManualFolders
  invalidateViewCache()
  state.selectedFolder = destination
  cancelConfirmations()
  state.folderStatus, state.folderStatusError =
    ("Copied folder \"%s\" as \"%s\"."):format(source, destination), false
  state.statusKinds.folder = "success"
  log(("[FOLDER] Virtual duplicate completed: source='%s' destination='%s' presets=%d.")
    :format(source, destination, #createdFiles), "complete")
end

local function removeVirtualFolder()
  state.statusKinds.folder = nil
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
            "The mod could not create a safe destination file name for an imported preset.", true; return
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
      "The recovery record for removing this imported folder could not be created.", true; return
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
        and "The imported folder was left unchanged because a preset file could not be moved."
        or "A preset could not be moved, and some earlier moves could not be undone. The mod will try to recover them at the next startup.", true
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
        and "The folder was restored because the folder list or recovery record could not be saved."
        or "The folder removal could not finish or be undone. The mod will try to recover it at the next startup.", true
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
          and ". Its empty Windows folder was also removed."
          or ". Its Windows folder was kept because it contains other files or could not be removed safely.")
        or "."), false
  state.statusKinds.folder = "success"
end

local function refreshEditorState()
  local wasInCustomization = state.inCustomization
  state.inCustomization = isCustomizationActive()
  if state.inCustomization ~= wasInCustomization then
    if state.loadPresetName and (state.loadNeedsContinue or state.loadPendingChange) then
      helpers.logLoadMeasurements("editor-changed")
    end
    resetLoadState()
    state.invalidatePreflight()
    state.clothingCheckDirty = true
    state.clothingCheckNextAt = 0
  end
  if not state.inCustomization then state.activeBodyMorphMenu = nil end
end

local draw
local drawDiscoveryHudNotice

do

local ui = {}

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

local function drawSectionStatus(section, childId, height)
  local text = state[section .. "Status"]
  if not text or text == "" then return end
  local kind = state.statusKinds[section]
  local isError = state[section .. "StatusError"] or kind == "error"
  local checkClothing = section == "load"
    and not isError
    and state.inCustomization
    and not state.newGameCharacterCreator
    and not state.autoLoad
    and not state.loadNeedsContinue
    and kind == "ready"
  if checkClothing then
    local clockOk, now = pcall(os.clock)
    now = clockOk and tonumber(now) or 0
    if state.clothingCheckDirty or now >= (state.clothingCheckNextAt or 0) then
      state.cachedClothingLabels = helpers.equippedClothingLabels()
      state.clothingCheckDirty = false
      state.clothingCheckNextAt = now + 1
    end
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
  local success = not isError and (kind == "success" or kind == "ready")
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
    local successLabel = kind == "ready" and "READY" or "SUCCESS"
    ImGui.TextColored(0.3, 1.0, 0.4, 1.0, successLabel)
    coloredWrapped(1.0, 1.0, 1.0, 1.0, text)
  else
    ImGui.TextColored(0.97, 0.72, 0.20, 1.0, "STATUS")
    coloredWrapped(1.0, 1.0, 1.0, 1.0, text)
  end
  ImGui.EndChild()
  if customColors then ImGui.PopStyleColor(2) end
end

ui.setDebugLogText = function(text)
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

ui.readDiagnosticLog = function()
  closeActivityLog()
  local file = io.open(LOG_FILE, "rb")
  if not file then
    ui.setDebugLogText("No activity log yet -- nothing has happened this session.")
    return
  end
  local limit = 65536
  local sizeOk, size = pcall(file.seek, file, "end")
  if not sizeOk or not size then
    file:close()
    ui.setDebugLogText("The activity log could not be measured.")
    return
  end
  local truncated = size > limit
  local start = truncated and (size - limit) or 0
  local seekOk, seekResult = pcall(file.seek, file, "set", start)
  local ok, contents = false, nil
  if seekOk and seekResult ~= nil then ok, contents = pcall(file.read, file, "*a") end
  file:close()
  if not ok or type(contents) ~= "string" then
    ui.setDebugLogText("The activity log could not be read.")
    return
  end
  if truncated then
    contents = "[Showing the newest 64 KB of Data/Logs/Activity.log]\n\n" ..
      contents
  end
  ui.setDebugLogText(contents ~= "" and contents
    or "Data/Logs/Activity.log is empty.")
end

ui.drawDebugPanel = function(height)
  ImGui.Spacing()
  local logRowStartX = ImGui.GetCursorPosX()
  local logRowWidth = ImGui.GetContentRegionAvail()
  local logButtonWidth = 68
  local logButtonHeight = 32
  local logButtonsWidth = logButtonWidth * 3 + 16
  ImGui.TextColored(0.97, 0.72, 0.20, 1.0, "Activity Log")
  ImGui.SameLine()
  ImGui.SetCursorPosX(logRowStartX + logRowWidth - logButtonsWidth)
  if ImGui.Button("Refresh##debugRefresh", logButtonWidth, logButtonHeight) then ui.readDiagnosticLog() end
  ImGui.SameLine()
  if ImGui.Button("Copy##debugCopy", logButtonWidth, logButtonHeight) then
    ImGui.SetClipboardText(state.debugLogText or "")
  end
  ImGui.SameLine()
  if ImGui.Button("Close##debugClose", logButtonWidth, logButtonHeight) then state.debugOpen = false end
  if ImGui.CollapsingHeader("Advanced Technical Details##advancedDiagnostics") then
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

ui.readCETBinding = function(slug)
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

ui.drawBindingHelp = function(label, slug, receivedCount)
  ImGui.TextWrapped(label)
  local binding = state.bindingCache[slug]
  if not binding then
    local status, assignedKey = ui.readCETBinding(slug)
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

ui.pathCallout = function(childId, label, path)
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

ui.defaultWindowPosition = function()
  local viewportOk, workX, workY, workWidth = pcall(function()
    if not ImGui.GetMainViewport then return nil end
    local viewport = ImGui.GetMainViewport()
    if not viewport or not viewport.WorkPos or not viewport.WorkSize then return nil end
    return tonumber(viewport.WorkPos.x or viewport.WorkPos.X or viewport.WorkPos[1]),
      tonumber(viewport.WorkPos.y or viewport.WorkPos.Y or viewport.WorkPos[2]),
      tonumber(viewport.WorkSize.x or viewport.WorkSize.X or viewport.WorkSize[1])
  end)
  if viewportOk and workWidth and workWidth > 460 then
    workX, workY = workX or 0, workY or 0
    return math.max(workX + 20, workX + workWidth - 440), workY + 40, workWidth
  end
  local sizeOk, first, second = pcall(function()
    if ImGui.GetDisplaySize then return ImGui.GetDisplaySize() end
    if ImGui.GetIO then
      local io = ImGui.GetIO()
      return io and io.DisplaySize or nil
    end
    return nil
  end)
  local displayWidth = nil
  if sizeOk then
    displayWidth = tonumber(first)
    if not displayWidth and first then
      local widthOk, width = pcall(function()
        return first.x or first.X or first[1]
      end)
      if widthOk then displayWidth = tonumber(width) end
    end
    if not displayWidth then displayWidth = tonumber(second) end
  end
  if not displayWidth then
    local resolutionOk, resolutionWidth = pcall(function()
      return GetDisplayResolution and GetDisplayResolution() or nil
    end)
    if resolutionOk then displayWidth = tonumber(resolutionWidth) end
  end
  if not displayWidth or displayWidth <= 460 then return nil, 40, displayWidth end
  return math.max(20, displayWidth - 440), 40, displayWidth
end

ui.discoveryViewport = function()
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
    local viewportX, viewportY, viewportWidth = ui.discoveryViewport()
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

ui.drawBulkTrashOptions = function(actionButtonHeight, statusHeight)
  ImGui.TextColored(0.97, 0.72, 0.20, 1.0, "Select multiple presets")
  ImGui.PushItemWidth(-1)
  local previousSearchText = state.searchText
  state.searchText = ImGui.InputTextWithHint("##bulkPresetSearch",
    "Search presets or folders", state.searchText, 65)
  if state.searchText ~= previousSearchText then invalidateFilteredViewCache() end
  ImGui.PopItemWidth()
  local visibleNames = helpers.filteredPresetNames()
  local selectedBulkNames = selectedBulkPresetNames()
  local bulkButtonWidth = (ImGui.GetContentRegionAvail() - 8) * 0.5
  if ImGui.Button("Select All Visible##bulkSelectAll",
      bulkButtonWidth, actionButtonHeight) then
    for _, name in ipairs(visibleNames) do state.bulkSelected[name] = true end
    invalidateBulkSelectionCache()
    cancelConfirmations()
    clearStatus("bulk")
  end
  ImGui.SameLine()
  if #selectedBulkNames == 0 then ImGui.BeginDisabled() end
  if ImGui.Button("Clear Selection##bulkClear",
      bulkButtonWidth, actionButtonHeight) then
    state.bulkSelected = {}
    invalidateBulkSelectionCache()
    cancelConfirmations()
    clearStatus("bulk")
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
        if selectedForBulk then
          state.bulkSelected[name] = nil
        else
          state.bulkSelected[name] = true
        end
        invalidateBulkSelectionCache()
        cancelConfirmations()
        clearStatus("bulk")
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
  drawSectionStatus("bulk", "##bulkStatus", statusHeight)
end

draw = function()
  if not state.overlayOpen or not state.windowOpen then return end

  pushTheme()
  if not state.windowPositionCached then
    state.cachedWindowX, state.cachedWindowY, state.cachedDisplayWidth = ui.defaultWindowPosition()
    state.windowPositionCached = true
  end
  local initialX = state.cachedWindowX
  local initialY = state.cachedWindowY or 40
  local displayWidth = state.cachedDisplayWidth
  if initialX then
    local positionCondition = state.initialWindowPlacementPending
      and ImGuiCond.Always or ImGuiCond.FirstUseEver
    ImGui.SetNextWindowPos(initialX, initialY, positionCondition)
  end
  ImGui.SetNextWindowSize(420, 700, ImGuiCond.FirstUseEver)
  local visible = ImGui.Begin("Character Preset Manager (CET)##CPM2")
  if state.initialWindowPlacementPending and initialX then
    state.initialWindowPlacementPending = false
    log(("[UI] Initial window position forced to the right: displayWidth=%s x=%s y=%s.")
      :format(tostring(displayWidth), tostring(initialX), tostring(initialY)), "info")
    local status = io.open(WINDOW_POSITION_STATUS_FILE, "w")
    if status then
      local wrote = status:write((
        "Character Preset Manager (CET) initial right-side position applied.\n" ..
        "Applied: %s\nDisplay width: %s\nInitial X: %s\nInitial Y: %s\n"
      ):format(logTimestamp(), tostring(displayWidth), tostring(initialX),
        tostring(initialY)))
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
        if reminderEnabled then saved = helpers.ignoreDiscoveryNotice()
        else saved = helpers.restoreDiscoveryNotice() end
        local currentState = state.discoveryNoticeIgnored and "disabled" or "enabled"
        if saved then
          state.settingsStatus = "Customization reminder " .. currentState .. ". Settings saved."
        else
          state.settingsStatus = "Customization reminder " .. currentState ..
            " for this session, but the settings file could not be saved."
        end
      end
      local sortLabel = state.sortMode == "modified"
        and "Preset Sort: Last Modified" or "Preset Sort: Name"
      if fullWidthButton(sortLabel .. "##presetSort", actionButtonHeight) then
        state.sortMode = state.sortMode == "modified" and "name" or "modified"
        invalidateViewCache()
        state.settingsStatus = writeConfig() and "Settings saved." or "The settings file could not be saved."
      end
      if fullWidthButton("Reload Settings File##reloadConfig", actionButtonHeight) then
        local config, loaded = readConfig()
        if loaded then
          state.discoveryNoticeIgnored = not config.discoveryReminder
          if state.discoveryNoticeIgnored then state.discoveryNoticePending = false end
          state.discoveryNoticeLayout = nil
          state.sortMode = config.presetSort == "modified" and "modified" or "name"
          invalidateViewCache()
          state.settingsStatus = "Settings file reloaded."
        else
          state.settingsStatus = "The settings file could not be reloaded."
        end
      end
      if state.settingsStatus ~= "" then
        coloredWrapped(0.64, 0.67, 0.73, 1.0, state.settingsStatus)
      end
      ImGui.EndChild()
    end
    if state.debugOpen then
      ui.drawDebugPanel(200 + extraHeight * 0.35)
    end
    if state.helpOpen then
      ImGui.Spacing()
      ImGui.PushStyleColor(ImGuiCol.ChildBg, 0.086, 0.094, 0.118, 0.85)
      ImGui.PushStyleColor(ImGuiCol.Border, 0.95, 0.72, 0.20, 0.55)
      ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 1.0, 1.0, 1.0)
      ImGui.PushStyleColor(ImGuiCol.TextDisabled, 0.64, 0.67, 0.73, 1.0)
      ImGui.BeginChild("##help", 0, 230 + math.min(extraHeight * 0.20, 80), true)

      helpHeading("Before You Start")
      coloredWrapped(1.0, 0.4, 0.4, 1.0,
        "Remove Appearance Change Unlocker (ACU) and Character Customization Anywhere, then restart the game. These mods change the same character screens and cannot be used with Character Preset Manager.")
      ImGui.TextWrapped("Keep the same character option mods, versions, and load order that were used to make the preset. If they change, check the appearance and save the preset again.")
      ImGui.TextWrapped("Photo Mode and Appearance Menu Mod may stay installed, but you cannot save or load presets inside their menus. Use the full editor, a mirror, a ripperdoc, or the new-game editor.")
      coloredWrapped(1.0, 0.8, 0.2, 1.0,
        "If the game stays on a loading screen after you close an editor, remove all clothing and choose No Outfit before trying again. This is a Cyberpunk issue and can happen without this mod.")

      ImGui.Separator()

      helpHeading("Open the Editor")
      ImGui.TextWrapped("Load a saved game, then select Open Full Appearance Editor. You can also use a mirror, a ripperdoc, or the new-game editor.")
      ImGui.TextWrapped("Set these keys under CET Bindings > Character Preset Manager (CET). Close the CET window before using the editor key.")
      ui.drawBindingHelp("Open Full Appearance Editor", "preset_manager_open_editor_input",
        state.editorInputCount)
      ui.drawBindingHelp("Toggle Character Preset Manager (CET)",
        "vanilla_character_presets_toggle", state.windowHotkeyCount)

      helpHeading("Load a Preset")
      ImGui.TextWrapped("1. Open a supported character editor.")
      ImGui.TextWrapped("2. Choose a preset under Load Preset.")
      ImGui.TextWrapped("3. Select Load Selected Preset once.")
      coloredWrapped(0.3, 1.0, 0.4, 1.0,
        "4. Wait for the final result. Green means every option was confirmed. Yellow means the game did not confirm one or more changes.")
      ImGui.TextWrapped("If you add, remove, or edit preset files outside CET, select Refresh under Load Preset before using them.")
      coloredWrapped(1.0, 0.8, 0.2, 1.0,
        "After applying the preset, the mod may clear appearance options that are not saved in it. It checks the preset again after each cleared option.")

      helpHeading("Save a Preset")
      ImGui.TextWrapped("1. Open a supported character editor.")
      ImGui.TextWrapped("2. Under Save Preset, open Choose Save Destination.")
      ImGui.TextWrapped("3. Choose a folder or All Presets, then enter a name.")
      ImGui.TextWrapped("4. Select Save New Preset. Only confirm Replace Existing Preset if you want to overwrite it.")

      helpHeading("Organize Presets")
      ImGui.TextWrapped("Select a folder row under Load Preset to open or close it. Presets that are not in a folder appear under All Presets.")
      ImGui.TextWrapped("To move a preset, choose the preset, choose its new folder, then select Move Selected Preset Here. Choose All Presets to remove it from a folder.")
      ImGui.TextWrapped("A new folder is placed inside the selected folder. Choose All Presets first to create a main folder.")
      ImGui.TextWrapped("Folders made in CET organize presets only inside the mod. They do not create matching Windows folders and have no set limit.")
      ImGui.TextWrapped("Windows folders placed inside Character Presets appear with an Imported label. The mod keeps unknown files in those folders safe.")

      helpHeading("Rename, Copy, or Remove")
      ImGui.TextWrapped("Choose a preset or folder first. Renaming a preset also renames its .preset file. Renaming a folder changes only the name shown in the mod.")
      ImGui.TextWrapped("A copy appears beside the original. Copying a folder also copies every preset and folder inside it.")
      ImGui.TextWrapped("Remove Folder, Keep Presets removes the folder but moves everything inside it to the folder above. It never deletes unknown files.")

      helpHeading("Delete and Restore")
      ImGui.TextWrapped("Under Folders, you can move a folder and everything inside it to Trash. Use Delete & Restore to move one preset or several visible presets to Trash.")
      ImGui.TextWrapped("You can restore presets and complete folders later. If a name is already in use, the restored item gets a Copy name instead of replacing anything.")
      ImGui.TextWrapped("Empty Trash Permanently is the only action that permanently deletes files. All Trash actions ask for confirmation.")

      helpHeading("Share One Preset")
      ImGui.TextWrapped("Share one appearance by sending its .preset file. To install one, place the file in Character Presets or in a Windows folder inside it, then select Refresh under Load Preset.")
      ImGui.TextWrapped("A shared preset does not include its CET folder. Older Character Preset Manager and compatible ACU preset files can still be loaded.")
      ImGui.TextWrapped("New format-8 preset files use plain headings and readable option details. Saving over an older preset or saving its optional details updates it to the current format.")
      ImGui.TextWrapped("If an older preset loads the wrong custom option after you change option mods, correct the appearance and save it again in the current format.")
      ui.pathCallout("##presetFolderPath", "Preset Folder",
        "bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Character Presets")
      if fullWidthButton("Copy Preset Folder Path##copyPresetPath", actionButtonHeight) then
        ImGui.SetClipboardText(
          "bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Character Presets")
      end

      helpHeading("Share a Folder")
      ImGui.TextWrapped("To share a folder, choose a non-empty folder under Folders and select Export Folder for Sharing. The new .cpmfolder file appears in Character Presets and includes everything inside that folder.")
      ImGui.TextWrapped("To install a shared folder, place its .cpmfolder file in Character Presets. Under Folders, choose All Presets, then select Install Shared Folders.")
      ImGui.TextWrapped("The mod skips a bundle that was already imported and has not changed. If you deleted its imported folder, you can import the same bundle again.")
      ImGui.TextWrapped("To remove only a .cpmfolder file, choose All Presets, open Shared Folder Files, and move the file to Trash. This does not remove the installed presets or the folder that was shared.")

      helpHeading("Settings")
      ImGui.TextWrapped("Use Settings to turn the character-screen reminder on or off and choose how presets are sorted. Your choices are saved.")
      ImGui.TextWrapped("Advanced users can also change Data/Config/Config.txt, then select Reload Settings File.")

      helpHeading("Activity Log")
      ImGui.TextWrapped("Open the activity log to see recent preset actions, warnings, and errors. You can copy the log when asking for help.")
      if fullWidthButton("Open Activity Log##openDebugFromHelp", actionButtonHeight) then
        ui.readDiagnosticLog()
        state.debugOpen = true
        state.helpOpen = false
      end

      ImGui.EndChild()
      ImGui.PopStyleColor(4)
    end

    if collapsibleSectionHeader("APPEARANCE EDITOR", "editor") then
    ImGui.TextWrapped("Opens the game's full character editor. Apartment mirrors offer the same options.")
    ImGui.Spacing()
    local editorUnavailable = state.editorOpenPending or state.inCustomization
      or not state.editorHooksAvailable
    if editorUnavailable then ImGui.BeginDisabled() end
    if fullWidthButton("Open Full Appearance Editor##openEditor", actionButtonHeight) then
      openFullAppearanceEditor()
    end
    if editorUnavailable then ImGui.EndDisabled() end
    drawSectionStatus("editor", "##editorStatus", statusHeight)
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
      local _, refreshed, changes = refreshPresets("external")
      refreshTrash()
      if state.selected and state.presets[state.selected] then
        state.presetNotes = state.presets[state.selected].notes or ""
        state.presetTags = state.presets[state.selected].tags or ""
      end
      refreshPreflight()
      local added = changes and changes.added or 0
      local removed = changes and changes.removed or 0
      local updated = changes and changes.modified or 0
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
          state.invalidatePreflight()
          local selectedPreset = state.presets[name]
          state.presetNotes = selectedPreset and selectedPreset.notes or ""
          state.presetTags = selectedPreset and selectedPreset.tags or ""
          cancelConfirmations()
          state.renameName = ""
          resetLoadState()
          clearStatus("rename")
          clearStatus("delete")
          refreshPreflight()
        end
      end
      for _, folder in ipairs(sortedFolderNames()) do
        local folderPresets = helpers.presetsInFolder(folder)
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

    if state.preflightDirty or state.preflightPresetName ~= state.selected then
      refreshPreflight()
    end
    if state.selected and state.presets[state.selected] then
      local preset = state.presets[state.selected]
      ImGui.TextColored(0.97, 0.72, 0.20, 1.0, baseName(state.selected))
      coloredWrapped(0.64, 0.67, 0.73, 1.0,
        ("%s  |  %d options  |  Format %s")
        :format(breadcrumb(parentFolder(state.selected)), state.presetEntryCount(preset),
          tostring(preset.format or 4)))
      if state.preflight then
        local check = state.preflight
        local color = (check.ambiguous + check.invalid) > 0 and { 1.0, 0.4, 0.4 }
          or check.unavailable > 0 and { 1.0, 0.8, 0.2 } or { 0.3, 1.0, 0.4 }
        coloredWrapped(color[1], color[2], color[3], 1.0,
          ("Option check: %d found  |  %d missing  |  %d repeated  |  %d invalid")
            :format(check.available, check.unavailable, check.ambiguous, check.invalid))
      else
        ImGui.TextDisabled("Open a customization screen to check compatibility.")
      end
      if compactSubsectionButton("More Preset Info", "Hide Preset Info", "loadDetails") then
        ImGui.Indent(8)
        coloredWrapped(0.64, 0.67, 0.73, 1.0,
          ("Source: %s\nModified: %s")
            :format(tostring(preset.source or "Older or ACU preset"),
            tostring(preset.modified or "Unknown")))
        if preset.tags and preset.tags ~= "" then ImGui.TextWrapped("Tags: " .. preset.tags) end
        if preset.notes and preset.notes ~= "" then ImGui.TextWrapped("Notes: " .. preset.notes) end
        ImGui.Unindent(8)
      end
    end

    if state.autoLoad then ImGui.BeginDisabled() end
    local forceLoadLabel = state.forceFullLoad
      and "Force Full Load: On##forceFullLoad"
      or "Force Full Load: Off##forceFullLoad"
    if fullWidthButton(forceLoadLabel, actionButtonHeight) then
      state.forceFullLoad = not state.forceFullLoad
      resetLoadState()
      state.invalidatePreflight()
      refreshPreflight()
      log(("[UI] Force Full Load toggled %s.")
        :format(state.forceFullLoad and "on" or "off"), "info")
    end
    if state.autoLoad then ImGui.EndDisabled() end
    if state.forceFullLoad then
      local selectedFormat = state.selected and state.presets[state.selected]
        and tonumber(state.presets[state.selected].format) or 4
      if selectedFormat >= 7 then
        coloredWrapped(1.0, 0.8, 0.2, 1.0,
          "Force Full Load will try saved editor positions. Check the appearance after loading.")
      else
        coloredWrapped(1.0, 0.4, 0.4, 1.0,
          "Older preset: added options may change the hair or color. Check the appearance after loading.")
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
    drawSectionStatus("load", "##loadStatus", statusHeight)
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
    drawSectionStatus("create", "##createStatus", statusHeight)
    end

    if collapsibleSectionHeader("FOLDERS", "folders") then
    ImGui.TextColored(1.0, 1.0, 1.0, 1.0,
      "Select how new or moved presets are organized")
    ImGui.TextWrapped("Selected destination: " .. breadcrumb(state.selectedFolder))
    coloredWrapped(0.64, 0.67, 0.73, 1.0,
      "Folders made in CET have no set limit. Imported folders are Windows folders inside Character Presets.")
    ImGui.Spacing()
    ImGui.BeginChild("##folderList", 0, ImGui.GetFontSize() * 4.5, true)
    if ImGui.Selectable("All Presets##rootFolder", state.selectedFolder == "")
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
      if moveUnavailable and not state.selected then
        ImGui.TextDisabled("Select a preset under Load Preset before moving it.")
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
        ("Trash will include %d folder%s inside this one. You can restore them later.")
          :format(nestedFolderCount, nestedFolderCount == 1 and "" or "s"))
      drawSectionStatus("bulk", "##folderBulkStatus", statusHeight)
    else
      local rootMoveUnavailable = not state.selected or parentFolder(state.selected) == ""
      if rootMoveUnavailable then ImGui.BeginDisabled() end
      if fullWidthButton("Move Selected Preset to All Presets", actionButtonHeight) then movePresetToSelectedFolder() end
      if rootMoveUnavailable then ImGui.EndDisabled() end
      if rootMoveUnavailable then ImGui.TextDisabled(not state.selected
        and "Select a preset under Load Preset before moving it."
        or "The selected preset is already in All Presets.")
      end
      if fullWidthButton("Install Shared Folders", actionButtonHeight) then
        importAvailableFolderBundles()
      end
      coloredWrapped(0.64, 0.67, 0.73, 1.0,
        "Installs .cpmfolder files from Character Presets. Files that were already installed and have not changed are skipped.")
      local bundleFiles = folderBundleFiles()
      local bundleLabel = ("Shared Folder Files (%d)"):format(#bundleFiles)
      if compactSubsectionButton(bundleLabel, "Hide Shared Folder Files", "folderBundleFiles") then
        ImGui.Indent(8)
        if #bundleFiles == 0 then
          state.selectedBundleFile = nil
          ImGui.TextDisabled("No .cpmfolder files found.")
        else
          ImGui.BeginChild("##folderBundleFileList", 0, ImGui.GetFontSize() * 3.5, true)
          local selectedStillExists = false
          for _, path in ipairs(bundleFiles) do
            local leaf = path:match("([^/]+)$") or path
            if state.selectedBundleFile
                and state.selectedBundleFile:lower() == leaf:lower() then
              state.selectedBundleFile = leaf
              selectedStillExists = true
            end
            if ImGui.Selectable(leaf .. "##bundleFile:" .. leaf,
                state.selectedBundleFile == leaf) then
              state.selectedBundleFile = leaf
              cancelConfirmations()
              selectedStillExists = true
            end
          end
          ImGui.EndChild()
          if state.selectedBundleFile and not selectedStillExists then
            state.selectedBundleFile = nil
          end
          local bundleDeleteUnavailable = not state.selectedBundleFile
          if bundleDeleteUnavailable then ImGui.BeginDisabled() end
          if dangerButton("Move Selected File to Trash##trashFolderBundle",
              ImGui.GetContentRegionAvail(), actionButtonHeight) then
            trashSelectedFolderBundle()
          end
          if bundleDeleteUnavailable then ImGui.EndDisabled() end
          ImGui.TextDisabled("Moves only the selected .cpmfolder file to Trash. You can restore it later.")
        end
        ImGui.Unindent(8)
      end
    end
    if state.folderStatus ~= "" then
      if state.lastLoggedFolderStatus ~= state.folderStatus then
        local level = state.folderStatusError and "error" or "info"
        log(("[FOLDER STATUS] %s"):format(state.folderStatus), level)
        state.lastLoggedFolderStatus = state.folderStatus
      end
    end
    drawSectionStatus("folder", "##folderStatus", statusHeight)
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
        drawSectionStatus("rename", "##renameStatus", statusHeight)
      end
    end

    if collapsibleSectionHeader("DELETE & RESTORE", "trash") then
      ImGui.TextWrapped("Move presets, folders, and shared-folder files to Trash. You can restore them later.")
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
        ui.drawBulkTrashOptions(actionButtonHeight, statusHeight)
        ImGui.Unindent(8)
      end

      ImGui.Spacing()
      ImGui.Separator()
      ImGui.Spacing()
      ImGui.TextColored(0.97, 0.72, 0.20, 1.0, "Recover from Trash")
      state.ensureTrashViewCache()
      local trashNames = state.cachedTrashNames
      local trashGroupIds = state.cachedTrashGroupIds
      local trashBundleNames = state.cachedTrashBundleNames
      if #trashNames == 0 and #trashGroupIds == 0 and #trashBundleNames == 0 then
        ImGui.TextDisabled("Trash is empty.")
      else
        ImGui.TextWrapped(("%d preset%s in Trash  |  %d shared-folder file%s")
          :format(#trashNames, #trashNames == 1 and "" or "s",
            #trashBundleNames, #trashBundleNames == 1 and "" or "s"))
        ImGui.BeginChild("##trashList", 0, ImGui.GetFontSize() * 6, true)
        local trashChanged = false
        for _, groupId in ipairs(trashGroupIds) do
          local group = state.trashGroups[groupId]
          local stats = state.cachedTrashGroupStats[groupId] or { presets = 0, folders = 0 }
          local groupPresetCount, folderCount = stats.presets, stats.folders
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
        if not trashChanged then
          if #trashBundleNames > 0 and (#trashGroupIds > 0 or #trashNames > 0) then
            ImGui.Separator()
          end
          for _, filename in ipairs(trashBundleNames) do
            if fullWidthButton("Restore File " .. filename ..
                "##trashBundle:" .. filename, actionButtonHeight) then
              restoreTrashBundle(filename)
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
      drawSectionStatus("delete", "##trashStatus", statusHeight)
    end

  end
  ImGui.End()
  popTheme()
end

end

registerForEvent("onInit", function()
  activitySequence = 0
  local archived, archiveResult, cleanupWarning, deletedArchives = helpers.archiveLogForNewSession()
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
      if state.loadPresetName and (state.loadNeedsContinue or state.loadPendingChange) then
        helpers.logLoadMeasurements("editor-opened")
      end
      resetLoadState()
      state.activeBodyMorphMenu = menu
      state.inCustomization = true
      state.invalidatePreflight()
      state.clothingCheckDirty = true
      state.cachedClothingLabels = nil
      state.clothingCheckNextAt = 0
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
      if state.loadPresetName and (state.loadNeedsContinue or state.loadPendingChange) then
        helpers.logLoadMeasurements("editor-closed")
      end
      resetLoadState()
      state.activeBodyMorphMenu = nil
      state.inCustomization = false
      state.invalidatePreflight()
      state.clothingCheckDirty = true
      state.cachedClothingLabels = nil
      state.clothingCheckNextAt = 0
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
      setEditorOpenStatus("Full editor opened.", false, "success")
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
    setStatus("load", "Open the character creator, a mirror, or a ripperdoc to save or load presets.",
      false, "ready")
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
  closeActivityLog()
end)

registerForEvent("onUpdate", function(delta)
  local elapsed = tonumber(delta) or 0
  local monitorPreflight = state.overlayOpen and state.windowOpen
    and state.selected ~= nil and not state.autoLoad
  if not state.editorOpenPending
      and not state.autoLoad and not monitorPreflight then
    return
  end
  if monitorPreflight then
    state.preflightTimer = state.preflightTimer + elapsed
    if state.preflightTimer >= PREFLIGHT_REFRESH_INTERVAL then
      state.invalidatePreflight()
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

  state.loadElapsed = state.loadElapsed + elapsed
  if state.loadPendingChange then
    state.loadPendingElapsed = math.max(0,
      state.loadElapsed - state.loadPendingChange.startedAt)
  end

  if not state.loadNeedsContinue then
    state.autoLoad = false
    state.autoLoadTimer = 0
    state.autoLoadPasses = 0
    return
  end

  state.autoLoadTimer = state.autoLoadTimer + elapsed
  if state.autoLoadTimer < state.loadNextInterval then return end
  state.autoLoadTimer = 0

  if not state.selected then
    state.autoLoad = false
    state.autoLoadTimer = 0
    state.autoLoadPasses = 0
    return
  end

  state.autoLoadPasses = state.autoLoadPasses + 1
  local maximumSeconds = math.max(
    AUTO_LOAD_LIMITS.minimumSeconds,
    (tonumber(state.loadValueCount) or 0) * AUTO_LOAD_LIMITS.secondsPerOption + 10)
  if state.loadElapsed > maximumSeconds then
    state.autoLoad = false
    helpers.logLoadMeasurements("safety-limit")
    setStatus("load",
      "Automatic loading reached its safety limit without stopping or finishing. " ..
      "This is unusual. Please report it and include the Activity Log.",
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
  log("[UI] CET overlay opened; showing Character Preset Manager. Use Refresh after changing preset files outside CET.", "info")
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
  refreshEditorState()
  refreshPreflight()
end)
registerForEvent("onOverlayClose", function()
  log("[UI] CET overlay closed.", "info")
  closeActivityLog()
  state.overlayOpen = false
  helpers.clearSectionStatuses()
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
