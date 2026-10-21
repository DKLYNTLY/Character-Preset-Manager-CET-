local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

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
    log("[FALLBACK] The character-screen panel and native file service are unavailable. The CET manager remains available.", "warn")
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
  state.ui.bindingCache = {}
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
  local observeInitOk, observeInitError = pcall(
    Observe,
    "characterCreationBodyMorphMenu",
    "OnInitialize",
    function(menu)
      state.app.optionsMemo = nil
      temporarilyDisableWardrobe()
      if state.load.presetName and (state.load.needsContinue or state.load.pendingChange) then
        helpers.logLoadMeasurements("editor-opened")
      end
      resetLoadState()
      state.editor.activeBodyMorphMenu = menu
      state.app.inCustomization = true
      state.invalidatePreflight()
      connectNativeBridgeForMenu(menu)
      clearFallbackNotice()
      log(state.app.nativeBridge
        and "[UI] Character customization opened; native preset panel is available."
        or "[UI] Character customization opened; waiting for the packaged panel and native file service.",
        state.app.nativeBridge and "info" or "warn")
    end
  )
  local observeExitOk, observeExitError = pcall(
    Observe,
    "characterCreationBodyMorphMenu",
    "OnUninitialize",
    function()
      state.app.optionsMemo = nil
      if state.load.presetName and (state.load.needsContinue or state.load.pendingChange) then
        helpers.logLoadMeasurements("editor-closed")
      end
      resetLoadState()
      state.editor.activeBodyMorphMenu = nil
      state.app.inCustomization = false
      state.invalidatePreflight()
      clearFallbackNotice()
      state.editor.openedByLauncher = false
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
      state.editor.newGameCharacterCreator = true
    end
  )
  local newGameExitOk, newGameExitError = pcall(
    Observe,
    "MenuScenario_CharacterCustomization",
    "OnLeaveScenario",
    function()
      state.editor.newGameCharacterCreator = false
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
      state.editor.inGameMenuController = controller
      state.editor.controllerCaptureCount = state.editor.controllerCaptureCount + 1
      log(("[editor diagnostic] in-game menu controller captured via blackboards (%d)")
        :format(state.editor.controllerCaptureCount), "info")
    end
  )
  local menuInitializeObserverOk, menuInitializeObserverError = pcall(
    Observe,
    "gameuiInGameMenuGameController",
    "OnInitialize",
    function(controller)
      state.editor.inGameMenuController = controller
      state.editor.controllerCaptureCount = state.editor.controllerCaptureCount + 1
      log(("[editor diagnostic] in-game menu controller captured via initialize (%d)")
        :format(state.editor.controllerCaptureCount), "info")
    end
  )

  local pauseOverrideOk, pauseOverrideError = pcall(
    Override,
    "MenuScenario_PauseMenu",
    "OnEnterScenario",
    function(scenario, previousScenario, userData, wrappedMethod)
      log(("[editor diagnostic] pause scenario entered: pending=%s")
        :format(tostring(state.editor.openPending)), "info")
      if not state.editor.openPending then
        return wrappedMethod(previousScenario, userData)
      end
      state.editor.pauseRedirectCount = state.editor.pauseRedirectCount + 1
      state.editor.openPending = false
      state.editor.openTimer = 0
      state.editor.openedByLauncher = true
      setEditorOpenStatus("Preparing the full editor...", false)
      return scenario:SwitchToScenario("MenuScenario_CharacterCustomizationMirror")
    end
  )

  local editorOverrideOk, editorOverrideError = pcall(
    Override,
    "MenuScenario_CharacterCustomizationMirror",
    "OnCCOPuppetReady",
    function(scenario, wrappedMethod)
      state.editor.puppetReadyCount = state.editor.puppetReadyCount + 1
      log(("[editor diagnostic] customization puppet ready (%d)")
        :format(state.editor.puppetReadyCount), "info")
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
        state.editor.openedByLauncher = false
        restoreTemporarilyDisabledWardrobe()
        return wrappedMethod()
      end
      setEditorOpenStatus("Full editor opened.", false, "success")
    end
  )

  state.editor.hooksAvailable = (menuObserverOk or menuInitializeObserverOk)
    and pauseOverrideOk and editorOverrideOk
  if not state.editor.hooksAvailable then
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
  helpers.auditSection("SESSION END")
  log(("[SUMMARY] inputs=%d controllerCaptures=%d pauseRedirects=%d editorPuppets=%d")
    :format(state.editor.inputCount, state.editor.controllerCaptureCount,
      state.editor.pauseRedirectCount, state.editor.puppetReadyCount), "info")
  restoreTemporarilyDisabledWardrobe()
  state.app.ready = false
  state.app.inCustomization = false
  state.editor.newGameCharacterCreator = false
  cancelConfirmations()
  resetLoadState()
  state.editor.activeBodyMorphMenu = nil
  state.editor.inGameMenuController = nil
  state.editor.openPending = false
  state.editor.openTimer = 0
  state.editor.openedByLauncher = false
  state.editor.hooksAvailable = false
  clearFallbackNotice()
  closeActivityLog()
end

events.onUpdate = function(delta)
  local elapsed = tonumber(delta) or 0
  updateAcuImport(elapsed)
  updateNativeBridge(elapsed)
  updateFallbackNotice(elapsed)
  if not state.editor.openPending and not state.load.auto then
    return
  end
  if state.editor.openPending then
    state.editor.openTimer = state.editor.openTimer + elapsed
    if state.editor.openTimer >= EDITOR_OPEN_TIMEOUT then
      state.editor.openPending = false
      state.editor.openTimer = 0
      restoreTemporarilyDisabledWardrobe()
      setEditorOpenStatus("The editor did not open. Return to normal gameplay and retry.", true)
    end
  end
  if not state.load.auto then return end

  state.load.elapsed = state.load.elapsed + elapsed
  if state.load.pendingChange then
    state.load.pendingElapsed = math.max(0,
      state.load.elapsed - state.load.pendingChange.startedAt)
  end

  if not state.load.needsContinue then
    state.load.auto = false
    state.load.autoTimer = 0
    state.load.autoPasses = 0
    return
  end

  state.load.autoTimer = state.load.autoTimer + elapsed
  if state.load.autoTimer < state.load.nextInterval then return end
  state.load.autoTimer = 0

  if not state.library.selected and not state.load.overridePreset then
    state.load.auto = false
    state.load.autoTimer = 0
    state.load.autoPasses = 0
    return
  end

  state.load.autoPasses = state.load.autoPasses + 1
  local maximumSeconds = math.max(
    AUTO_LOAD_LIMITS.minimumSeconds,
    (tonumber(state.load.valueCount) or 0) * AUTO_LOAD_LIMITS.secondsPerOption + 10)
  if state.load.elapsed > maximumSeconds then
    state.load.auto = false
    helpers.logLoadMeasurements("safety-limit")
    setStatus("load",
      "Automatic loading reached its safety limit without stopping or finishing. " ..
      "This is unusual. Please report it and include the Activity Log.",
      true
    )
    return
  end

  loadPreset()

  if not state.load.needsContinue then
    state.load.auto = false
    state.load.autoPasses = 0
    if not state.app.overlayOpen or not state.app.windowOpen then
      helpers.releaseIdleMemory()
    end
  end
end

events.onOverlayOpen = function()
  log("[UI] CET overlay opened; showing Character Preset Manager. Use Refresh after changing preset files outside CET.", "info")
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
  state.backup.filesDirty = true
  state.ui.bindingCache = {}
  state.ui.windowPositionCached = false
  state.ui.cachedWindowX = nil
  state.ui.cachedDisplayWidth = nil
  refreshEditorState()
end

events.onOverlayClose = function()
  log("[UI] CET overlay closed.", "info")
  closeActivityLog()
  state.app.overlayOpen = false
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

events.toggleWindow = function()
  state.editor.windowHotkeyCount = state.editor.windowHotkeyCount + 1
  state.app.windowOpen = not state.app.windowOpen
  if not state.app.windowOpen then helpers.releaseIdleMemory() end
  log(("[UI] Character Preset Manager window visibility changed to %s.")
    :format(tostring(state.app.windowOpen)), "info")
end

events.openEditor = function(keyDown)
  if not keyDown then return end
  state.editor.inputCount = state.editor.inputCount + 1
  log(("[editor diagnostic] input binding pressed (%d)")
    :format(state.editor.inputCount), "info")
  local launchOk, launchError = pcall(openFullAppearanceEditor)
  if not launchOk then
    state.editor.openPending = false
    state.editor.openTimer = 0
    restoreTemporarilyDisabledWardrobe()
    setEditorOpenStatus("Editor hotkey failed before the menu request: " ..
      tostring(launchError), true)
  end
end

return events
