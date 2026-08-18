local _ENV = require("modules.runtime")

events = {}

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
end

events.onShutdown = function()
  helpers.auditSection("SESSION END")
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
end

events.onUpdate = function(delta)
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
end

events.onOverlayOpen = function()
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
end

events.onOverlayClose = function()
  log("[UI] CET overlay closed.", "info")
  closeActivityLog()
  state.overlayOpen = false
  helpers.clearSectionStatuses()
  cancelConfirmations()
end

events.onDraw = function()
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
end

events.toggleWindow = function()
  state.windowHotkeyCount = state.windowHotkeyCount + 1
  state.windowOpen = not state.windowOpen
  log(("[UI] Character Preset Manager window visibility changed to %s.")
    :format(tostring(state.windowOpen)), "info")
end

events.openEditor = function(keyDown)
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
end

return events
