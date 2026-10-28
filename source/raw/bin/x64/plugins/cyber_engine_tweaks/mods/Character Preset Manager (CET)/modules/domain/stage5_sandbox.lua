local hostRequire, hostLoadfile, hostSetfenv = require, loadfile, setfenv
local hostPairs, hostError, hostPcall = pairs, error, pcall
local hostRawget, hostSetmetatable = rawget, setmetatable
local installed = false
local monitored = {
  ["modules/domain/library"] = true,
  ["modules/domain/library_view"] = true,
  ["modules/domain/folders"] = true,
  ["modules/domain/catalog_codec"] = true,
  ["modules/application/library"] = true,
}
local verified = {
  ipairs = ipairs, tonumber = tonumber, tostring = tostring, type = type,
  math = {max = math.max},
  table = {insert = table.insert, sort = table.sort, concat = table.concat},
}
local allowedNames = {"ipairs", "math.max", "pairs", "require", "table.concat", "table.insert", "table.sort", "tonumber", "tostring", "type"}
local dependencies = {
  ["modules/domain/paths"] = true, ["modules/domain/names"] = true,
  ["modules/domain/codecs"] = true, ["modules/domain/library"] = true,
}
local hostGlobals = _G
local legacyGlobals = {}
for name in ([=[
ACTIVITY_LOG_PAGE_SIZE ACU_IMPORT_FILES_PER_FRAME ACU_IMPORT_POLL_SECONDS ACU_IMPORT_REQUEST_FILE ACU_IMPORT_RESULTS_FILE APPEARANCE_HISTORY_LIMIT AUTO_LOAD_LIMITS AUTO_LOAD_TIMING CATALOG_DIR CATALOG_FILE CName CONFIG_DIR CONFIG_FILE CURRENT_PRESET_FORMAT DATA_DIR EDITOR_OPEN_TIMEOUT EMPTY_LIST EquipmentSystem FALLBACK_NOTICE_CET_MESSAGE FALLBACK_NOTICE_DELAY_SECONDS FALLBACK_NOTICE_MESSAGE FALLBACK_NOTICE_TITLE FILE_COPY_CHUNK_SIZE FOLDER_BUNDLE_EXTENSION FORCE_FULL_LOAD_FORMAT_THRESHOLD Game GetBind GetDisplayResolution GetLocalizedTextByKey HISTORY_DIR HISTORY_FILE_PREFIX IMPORTED_BUNDLES_FILE INVENTORY_FILE ImGui ImGuiCol ImGuiCond ImGuiStyleVar ImGuiWindowFlags IsBound LAST_APPEARANCE_FILE LIBRARY_BACKUP_EXTENSION LOG_ARCHIVE_DIR LOG_ARCHIVE_LIMIT LOG_ARCHIVE_PREFIX LOG_DIR LOG_FILE LocKeyToString MAX_CATALOG_BYTES MAX_CATALOG_LINES MAX_FOLDER_BUNDLE_BYTES MAX_FOLDER_BUNDLE_PRESETS MAX_LIBRARY_BACKUP_BYTES MAX_OPTION_INDEX MAX_PRESET_BYTES MAX_PRESET_ENTRIES MAX_PRESET_KEY_BYTES MAX_PRESET_LINES MAX_TRANSACTION_BYTES MAX_TRANSACTION_LINES MAX_TREE_DEPTH MOD_NAME MorphMenuUserData NATIVE_BRIDGE_PROTOCOL NATIVE_FILE_CATALOG NATIVE_FILE_PROTOCOL NATIVE_LIST_LIMIT NATIVE_READY_STATUS NATIVE_REQUEST_POLL_SECONDS NameToString OPTION_CHOICE_CACHE_LIMIT Observe Override PRESET_DIR QuestDisableWardrobeSetRequest QuestRestoreWardrobeSetRequest RECOVERY_DIR SLOW_PREFLIGHT_SECONDS STALL_CONFIRMATION_PASSES STATUS_SECTIONS THEME_COLORS THEME_VARS TRANSACTION_FILE TRASH_CATALOG_FILE TRASH_DIR ToCName UI_LIST_PAGE_SIZE VERSION WINDOW_POSITION_STATUS_FILE _G activityLogFile activitySequence addFolderAncestors assert atomicReplace baseName beginLoadPass bit32 bulkPresetNamesInFolder canRunAppearanceRandomizer cancelConfirmations catalogDecode catalogEncode choiceCollectionValue cleanupFailureMessage clearAppearanceHistory clearFolderBundlePreview clearStatus cloneMap closeActivityLog collapsibleSectionHeader coloredWrapped compactSubsectionButton comparePresetWithCurrent compareSelectedPreset completeTransaction connectNativeBridgeForMenu continueLoadPass copyFile createFolder dangerButton deleteFile deleteSelectedLibraryBackup dir directoryTreeContainsFiles draw drawBackupSection drawBulkSection drawEditorSection drawFallbackHudNotice drawFoldersSection drawHelpPanel drawLoadSection drawManageSection drawPageControls drawSaveSection drawSectionStatus drawSettingsPanel drawTrashSection duplicateFolder duplicatePreset emptyCustomizationName emptyTrash ensureFilteredViewCache ensureViewCache equipmentSystem error events exportLibraryBackup exportSelectedBulkPresetBundle exportSelectedFolderBundle fileExists fileFingerprint findExistingFolderName findPresetCollision finishCompactSubsection folderAncestorsExpanded folderBundleFiles folderDepth folderNameExists folderPath fullWidthButton gameWardrobeClothingSetIndex gameuiCharacterCustomizationEditTag getOptions helpHeading helpers hydrateNamedPreset hydrateNamedPresetMetadata importAvailableFolderBundles importLibraryBackup initializeAcuImport initializeNativeBridge invalidateBulkSelectionCache invalidateFilteredViewCache invalidatePresetAndTrashCaches invalidateViewCache io ipairs isFolderBundleFilename isInFolderTree isRuntimePointerText joinFolder libraryBackupFiles loadPreset log logAcuDangerousOptions logTimestamp math movePresetToSelectedFolder moveSelectedBulkPresetsToFolder nativeCatalogDirectoryEntries next normalizeSearch occurrenceKeyParts openFullAppearanceEditor optionAuditIdentity optionChoiceIndex optionChoiceMatchesIndex optionIndexIsValid optionIndexValidationError optionKey optionSlot os pagedRange pairs parentFolder pcall persistVirtualState popFoldingHeaderTheme popTheme presetPath presetsMatch pushFoldingHeaderTheme pushTheme readBoundedFile readConfig readNativeFileCatalog readPresetFile readVerifiedPresetCopy recoverTransaction refreshAppearanceHistory refreshCustomizationUi refreshEditorState refreshPreflight refreshPresets refreshTrash remapFolderTreePath removeEmptyDirectoryTree removeFileList removeVirtualFolder renameFile renameFolder renamePreset requestAcuImport requestBulkTrash require resetLoadState restoreAppearanceHistory restoreLastAppearance restoreTemporarilyDisabledWardrobe restoreTrashBundle restoreTrashGroup restoreTrashPreset runAppearanceRandomizer safeDirectoryEntries sanitizeMetadata sanitizeName saveAppearanceHistorySnapshot saveLastAppearanceSnapshot savePreset savePresetMetadata savedEntryAuditIdentity selectedBulkPresetNames setEditorOpenStatus setPresetSortPreference setStatus setfenv setmetatable sortedFolderNames stableChoiceIdentity stableRuntimeValue state storageFilenamesInUse string table temporarilyDisableWardrobe textMatches toggleSelectedPresetFavorite tonumber tostring trashPreset trashSelectedFolderBundle trimAppearanceHistory type ui uniqueFolderCopyName uniquePresetCopyName uniqueStorageName unresolvedSignature updateAcuImport updateNativeBridge utf8 validModifiedTimestamp validRelativePath validatedFolderName validatedPresetName verifiedNativeFileCatalog viewSelectedFolderBundleContents writeCatalog writeConfig writeFileSafely writeInventory writeLinesIfChanged writeLog writePresetContents writePresetPath writeTransaction
]=]):gmatch("%S+") do legacyGlobals[name] = true end
local function namespace(name, members)
  return hostSetmetatable({}, {
    __index = function(_, key)
      if not members[key] then hostError("Forbidden baseline library member: " .. name .. "." .. tostring(key), 0) end
      return hostGlobals[name][key]
    end,
    __newindex = function(_, key) hostError("Baseline library write: " .. name .. "." .. tostring(key), 0) end,
  })
end
local legacyLibraries = {
  io = namespace("io", {open=true}),
  os = namespace("os", {clock=true,date=true,time=true,rename=true,remove=true}),
  math = namespace("math", {ceil=true,floor=true,max=true,min=true}),
  table = namespace("table", {concat=true,insert=true,remove=true,sort=true}),
  string = namespace("string", {char=true,rep=true}),
}
local function legacyEnvironment(moduleName, loader)
  local env
  env = hostSetmetatable({}, {
    __index = function(_, key)
      if not legacyGlobals[key] then hostError("Forbidden production global in " .. moduleName .. ": " .. tostring(key), 0) end
      if key == "_G" then return env end
      if key == "require" then return loader end
      if legacyLibraries[key] then return legacyLibraries[key] end
      return hostGlobals[key]
    end,
    __newindex = function(_, key) hostError("Production module wrote outside runtime: " .. moduleName .. ": " .. tostring(key), 0) end,
  })
  return env
end
local function environment(moduleName, loader)
  local allowed = {}
  for key,value in hostPairs(verified) do allowed[key] = value end
  for _, name in ipairs({"math", "table"}) do
    local members = verified[name]
    allowed[name] = hostSetmetatable({}, {
      __index = function(_, key)
        local value = members[key]
        if value == nil then hostError("Forbidden stage 5 library member: " .. name .. "." .. tostring(key), 0) end
        return value
      end,
      __newindex = function(_, key) hostError("Stage 5 library write: " .. name .. "." .. tostring(key), 0) end,
    })
  end
  allowed.require = function(name)
    if not dependencies[name] then hostError("Forbidden stage 5 dependency: " .. tostring(name), 0) end
    return loader(name)
  end
  allowed.pairs = function(items)
    local runtime = package.loaded["modules/runtime"]
    local iterator = runtime and hostRawget(runtime, "pairs") or hostPairs
    return iterator(items)
  end
  return hostSetmetatable({}, {
    __index = function(_, key)
      local value = allowed[key]
      if value == nil then hostError("Forbidden stage 5 global in " .. moduleName .. ": " .. tostring(key), 0) end
      return value
    end,
    __newindex = function(_, key)
      hostError("Stage 5 module wrote a global in " .. moduleName .. ": " .. tostring(key), 0)
    end,
  })
end
local function install(root)
  if installed then return end
  installed = true
  local loader
  loader = function(name)
    if not name:match("^modules/") or name:match("/stage%d") then return hostRequire(name) end
    if package.loaded[name] then return package.loaded[name] end
    local chunk = assert(hostLoadfile(root .. name .. ".lua"))
    hostSetfenv(chunk, monitored[name] and environment(name, loader) or legacyEnvironment(name, loader))
    local result = chunk()
    assert(type(result) == "table", "stage 5 module did not return a function table")
    package.loaded[name] = result
    return result
  end
  _G.require = loader
  for name in hostPairs(monitored) do package.loaded[name] = nil end
  for _, forbidden in ipairs({"coroutine", "debug", "package", "io", "os", "_G"}) do
    local env = environment("gate self-test", loader)
    local ok = hostPcall(function() return env[forbidden] end)
    assert(not ok, "sandbox gate allowed " .. forbidden)
  end
  local priorRuntime = package.loaded["modules/runtime"]
  for name in hostPairs(monitored) do loader(name) end
  assert(package.loaded["modules/runtime"] == priorRuntime, "stage 5 modules loaded the shared runtime")
end
return {install = install, allowedNames = allowedNames, monitored = monitored, legacyGlobals = legacyGlobals}
