local editorModel = require("modules/application/editor")
local function install(runtime)
  if setfenv then setfenv(1, runtime) end
  local _ENV = runtime

local effects = {}
local function measure(reason)
  if editorModel.shouldMeasure(state.load.presetName, state.load.needsContinue,
      not not state.load.pendingChange) then helpers.logLoadMeasurements(reason) end
end
effects.clearCatalog = function() helpers.clearOptionCatalog() end
effects.disableWardrobe = function() temporarilyDisableWardrobe() end
effects.measureOpened = function() measure("editor-opened") end
effects.measureClosed = function() measure("editor-closed") end
effects.resetLoad = function() resetLoadState() end
effects.captureMenu = function(menu) state.editor.activeBodyMorphMenu = menu end
effects.enterCustomization = function() state.app.inCustomization = true end
effects.leaveCustomization = function() state.app.inCustomization = false end
effects.invalidatePreflight = function() state.invalidatePreflight() end
effects.connectBridge = function(menu) connectNativeBridgeForMenu(menu) end
effects.clearFallback = function(_, clearFallbackNotice) clearFallbackNotice() end
effects.logOpened = function()
  log(state.app.nativeBridge
    and "[UI] The character editor opened; the simple preset menu is ready."
    or "[UI] The character editor opened; waiting for the simple menu and file service.",
    state.app.nativeBridge and "info" or "warn")
end
effects.clearRandomize = function() state.editor.pendingRandomizeSettings = nil end
effects.clearMenu = function() state.editor.activeBodyMorphMenu = nil end
effects.clearLauncher = function() state.editor.openedByLauncher = false end
effects.restoreWardrobe = function() restoreTemporarilyDisabledWardrobe() end
effects.finishOverlay = function() helpers.finishOverlayRequest() end
effects.sessionAudit = function() helpers.auditSection("SESSION END") end
effects.sessionSummary = function()
  log(("[SUMMARY] inputs=%d controllerCaptures=%d pauseRedirects=%d editorPuppets=%d")
    :format(state.editor.inputCount, state.editor.controllerCaptureCount,
      state.editor.pauseRedirectCount, state.editor.puppetReadyCount), "info")
end
effects.stopApp = function() state.app.ready = false; state.app.inCustomization = false end
effects.enterNewGame = function() state.editor.newGameCharacterCreator = true end
effects.leaveNewGame = function() state.editor.newGameCharacterCreator = false end
effects.clearConfirmations = function() cancelConfirmations() end
effects.clearController = function() state.editor.inGameMenuController = nil end
effects.stopOpening = function() state.editor.openPending = false; state.editor.openTimer = 0 end
effects.clearHooks = function() state.editor.hooksAvailable = false end
effects.closeLog = function() closeActivityLog() end
effects.timeoutStatus = function()
  setEditorOpenStatus("The editor did not open. Return to normal gameplay and retry.", true)
end
effects.setupPuppet = function(scenario)
  local userData = MorphMenuUserData.new()
  userData.optionsListInitialized = false
  userData.updatingFinalizedState = true
  userData.editMode = gameuiCharacterCustomizationEditTag.NewGame
  scenario.currMenuName = "character_customization"
  local menus = scenario:GetMenusState()
  menus:OpenMenu("player_puppet")
  menus:OpenMenu("character_customization", userData)
end
effects.puppetFailureStatus = function(editorError)
  setEditorOpenStatus("Full editor setup failed: " .. tostring(editorError), true)
end
effects.puppetOpenedStatus = function() setEditorOpenStatus("Full editor opened.", false, "success") end
effects.hotkeyFailureStatus = function(launchError)
  setEditorOpenStatus("Editor hotkey failed before the menu request: " .. tostring(launchError), true)
end
local function execute(actions, context, clearFallbackNotice, wrappedMethod)
  for _, action in ipairs(actions) do
    if action == "originalPuppet" then return wrappedMethod() end
    effects[action](context, clearFallbackNotice)
  end
end
local function setupPuppet(scenario, actions) execute(actions, scenario) end

helpers.registerEditorHooks = function(clearFallbackNotice)
  local observeInitOk, observeInitError = pcall(
    Observe,
    "characterCreationBodyMorphMenu",
    "OnInitialize",
    function(menu)
      execute(editorModel.plan("opened"), menu, clearFallbackNotice)
    end
  )
  local observeExitOk, observeExitError = pcall(
    Observe,
    "characterCreationBodyMorphMenu",
    "OnUninitialize",
    function()
      execute(editorModel.plan("closed"), nil, clearFallbackNotice)
    end
  )
  if not observeInitOk or not observeExitOk then
    log(("UI refresh observer registration unavailable: initialize=%s uninitialize=%s")
      :format(tostring(observeInitError), tostring(observeExitError)), "warn")
  end
  if observeInitOk and observeExitOk then
    log("[HOOK] Character customization UI observers registered.", "info")
  end

  local cameraHookOk, cameraHookError = pcall(
    Override,
    "BaseCharacterCreationController",
    "RequestCameraChange",
    function(_, slotName, delayed, wrappedMethod)
      if editorModel.cameraBlocked(state.app.inCustomization, state.app.presetCameraHold,
          state.load.auto, state.load.needsContinue) then return end
      return wrappedMethod(slotName, delayed == true)
    end
  )
  if not cameraHookOk then
    log("Automatic camera focus could not be paused during preset loading: " ..
      tostring(cameraHookError), "warn")
  end

  local newGameEnterOk, newGameEnterError = pcall(
    Observe,
    "MenuScenario_CharacterCustomization",
    "OnEnterScenario",
    function()
      execute(editorModel.plan("newGameEnter"))
    end
  )
  local newGameExitOk, newGameExitError = pcall(
    Observe,
    "MenuScenario_CharacterCustomization",
    "OnLeaveScenario",
    function()
      execute(editorModel.plan("newGameExit"))
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
      state.editor.controllerCaptureCount = editorModel.nextCount(state.editor.controllerCaptureCount)
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
      state.editor.controllerCaptureCount = editorModel.nextCount(state.editor.controllerCaptureCount)
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
      if editorModel.pauseAction(state.editor.openPending) == "original" then
        return wrappedMethod(previousScenario, userData)
      end
      local count, pending, timer, launched = editorModel.redirectPause(state.editor.pauseRedirectCount)
      state.editor.pauseRedirectCount = count
      state.editor.openPending = pending
      state.editor.openTimer = timer
      state.editor.openedByLauncher = launched
      setEditorOpenStatus("Preparing the full editor...", false)
      return scenario:SwitchToScenario("MenuScenario_CharacterCustomizationMirror")
    end
  )

  local editorOverrideOk, editorOverrideError = pcall(
    Override,
    "MenuScenario_CharacterCustomizationMirror",
    "OnCCOPuppetReady",
    function(scenario, wrappedMethod)
      state.editor.puppetReadyCount = editorModel.nextCount(state.editor.puppetReadyCount)
      log(("[editor diagnostic] customization puppet ready (%d)")
        :format(state.editor.puppetReadyCount), "info")
      local _, actions = editorModel.puppetPlan(state.editor.newGameCharacterCreator)
      local opened, editorError = pcall(setupPuppet, scenario, actions)
      return execute(editorModel.puppetResult(opened), editorError, nil, wrappedMethod)
    end
  )

  state.editor.hooksAvailable = editorModel.hooksAvailable(menuObserverOk,
    menuInitializeObserverOk, pauseOverrideOk, editorOverrideOk)
  if not state.editor.hooksAvailable then
    log(("Full-editor hooks unavailable: controller=%s initialize=%s pause=%s editor=%s")
      :format(tostring(menuObserverError), tostring(menuInitializeObserverError),
        tostring(pauseOverrideError), tostring(editorOverrideError)), "error")
    setEditorOpenStatus("This game or CET version does not support the full editor.", true)
  else
    log("[HOOK] Full-editor launch and mirror-unlock hooks registered.", "info")
  end

end

helpers.shutdownEditor = function(clearFallbackNotice)
  execute(editorModel.plan("shutdown"), nil, clearFallbackNotice)
end

helpers.updateEditorWatchdog = function(elapsed)
  local actions
  state.editor.openTimer, actions = editorModel.watchdog(
    state.editor.openTimer, elapsed, EDITOR_OPEN_TIMEOUT)
  execute(actions)
end

helpers.onEditorInput = function(keyDown)
  if not keyDown then return end
  state.editor.inputCount = editorModel.nextCount(state.editor.inputCount)
  log(("[editor diagnostic] input binding pressed (%d)")
    :format(state.editor.inputCount), "info")
  local launchOk, launchError = pcall(openFullAppearanceEditor)
  execute(editorModel.hotkeyResult(launchOk), launchError)
end

return {register=helpers.registerEditorHooks, shutdown=helpers.shutdownEditor, updateWatchdog=helpers.updateEditorWatchdog, input=helpers.onEditorInput}
end
return {install=install}
