local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime
require("modules/adapters/cet_hooks").install(runtime)

events = {}

local function clearFallbackNotice()
  state.ui.fallbackNoticePending = false
  state.ui.fallbackNoticeAcknowledged = false
  state.ui.fallbackNoticeChecked = false
  state.ui.fallbackNoticeTimer = 0
  state.ui.fallbackNoticeLayout = nil
end

local function updateFallbackNotice(elapsed)
  if not state.app.inCustomization or state.app.overlayOpen
      or state.ui.fallbackNoticeAcknowledged
      or state.app.nativeBridge or state.nativeCatalog.available then
    state.ui.fallbackNoticePending = false
    state.ui.fallbackNoticeTimer = 0
    state.ui.fallbackNoticeLayout = nil
    return
  end
  state.ui.fallbackNoticeTimer = state.ui.fallbackNoticeTimer
    + math.max(0, tonumber(elapsed) or 0)
  if state.ui.fallbackNoticeTimer < FALLBACK_NOTICE_DELAY_SECONDS then return end
  if not state.ui.fallbackNoticeChecked then
    state.ui.fallbackNoticeChecked = true
    verifiedNativeFileCatalog()
  end
  if state.app.nativeBridge or state.nativeCatalog.available then return end
  state.ui.fallbackNoticePending = true
  if not state.ui.fallbackNoticeLogged then
    state.ui.fallbackNoticeLogged = true
    log("[FALLBACK] The simple menu and file service are not available. Open the complete manager in CET.", "warn")
  end
end

helpers.releaseIdleMemory = function()
  if state.load.auto or state.load.needsContinue or state.load.pendingChange then
    return false
  end
  helpers.releaseFinishedLoadWorkingData()
  for _, preset in pairs(state.library.presets) do
    state.dehydratePreset(preset)
  end
  helpers.releaseViewCaches()
  ui.closeDebugPanel()
  state.app.optionsMemo = nil
  state.invalidatePreflight()
  return true
end

events.onInit = function()
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
  state.preferences.presetSort = config.presetSort
  state.library.sortMode = config.presetSort == "modified" and "modified" or "name"
  writeConfig()
  log(("[CONFIG] Loaded '%s': presetSort=%s.")
    :format(CONFIG_FILE, state.library.sortMode), "info")
  state.ui.initialWindowPlacementPending = not fileExists(WINDOW_POSITION_STATUS_FILE)
  if state.ui.initialWindowPlacementPending then
    log(("[UI] Window position status '%s' not found; right-side default will be applied once.")
      :format(WINDOW_POSITION_STATUS_FILE), "info")
  else
    log(("[UI] Window position status '%s' found; CET's saved position will be preserved.")
      :format(WINDOW_POSITION_STATUS_FILE), "info")
  end
  helpers.registerEditorHooks(clearFallbackNotice)

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
  for _ in pairs(state.library.presets) do presetCount = presetCount + 1 end
  log(("Preset files loaded: presets=%d directory='%s'")
    :format(presetCount, PRESET_DIR), "info")
  state.app.ready = true
  initializeAcuImport()
  initializeNativeBridge(configLoaded)
  refreshAppearanceHistory()
  refreshEditorState()
  if recovered then
    setStatus("load", "Open the character creator, a mirror, or a ripperdoc to save or load presets.",
      false, "ready")
  end
end

events.onShutdown = function()
  helpers.shutdownEditor(clearFallbackNotice)
end

events.onUpdate = function(delta)
  state.app.optionsMemo = nil
  local elapsed = tonumber(delta) or 0
  helpers.updateOverlayRequest(elapsed)
  updateAcuImport(elapsed)
  local loadInvocationBeforeBridge = state.app.loadInvocation
  updateNativeBridge(elapsed)
  updateFallbackNotice(elapsed)
  if not state.editor.openPending and not state.load.auto then
    return
  end
  if state.editor.openPending then helpers.updateEditorWatchdog(elapsed) end
  if not state.load.auto then return end

  helpers.updateAutomaticLoad(elapsed, loadInvocationBeforeBridge)
end

events.onOverlayOpen = function()
  helpers.finishOverlayRequest()
  log("[UI] CET opened; showing Character Preset Manager. Select Refresh after changing preset files outside CET.", "info")
  if state.ui.fallbackNoticePending then
    state.ui.fallbackNoticePending = false
    state.ui.fallbackNoticeLayout = nil
    log("[FALLBACK] The CET fallback reminder was acknowledged.", "info")
  end
  if state.app.inCustomization then
    state.ui.fallbackNoticeAcknowledged = true
  end
  state.app.overlayOpen = true
  state.app.windowOpen = true
  state.app.optionsMemo = nil
  refreshAppearanceHistory()
  state.ui.windowPositionCached = false
  state.ui.cachedWindowX = nil
  state.ui.cachedDisplayWidth = nil
  refreshEditorState()
end

events.onOverlayClose = function()
  log("[UI] CET overlay closed.", "info")
  closeActivityLog()
  state.app.overlayOpen = false
  local pendingMenu = state.editor.pendingRandomizeSettings
  state.editor.pendingRandomizeSettings = nil
  if pendingMenu and pendingMenu == state.editor.activeBodyMorphMenu then
    runAppearanceRandomizer(true)
  end
  helpers.clearSectionStatuses()
  cancelConfirmations()
  helpers.releaseIdleMemory()
end

events.onDraw = function()
  if state.ui.fallbackNoticePending and not state.app.overlayOpen then
    local noticeOk, noticeError = pcall(drawFallbackHudNotice)
    if not noticeOk then
      state.ui.fallbackNoticePending = false
      state.ui.fallbackNoticeLayout = nil
      log("[FALLBACK] The CET fallback reminder was hidden after a display error: " ..
        tostring(noticeError), "error")
    end
  end
  if state.app.overlayOpen and state.app.windowOpen then draw() end
end

events.openEditor = function(keyDown)
  return helpers.onEditorInput(keyDown)
end

return events
