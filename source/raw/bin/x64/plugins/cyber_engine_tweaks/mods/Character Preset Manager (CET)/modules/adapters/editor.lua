local editorModel = require("modules/application/editor")
local function install(runtime)
  if setfenv then setfenv(1, runtime) end
  local _ENV = runtime
local effects = {}
effects.clearPending = function() state.editor.openPending = false end
effects.restoreWardrobe = function() restoreTemporarilyDisabledWardrobe() end
effects.launchFailureStatus = function(openError)
  setEditorOpenStatus("The game rejected the request: " .. tostring(openError), true)
end
effects.openingStatus = function() setEditorOpenStatus("Opening the full appearance editor...", false) end
effects.measureChanged = function()
  if editorModel.shouldMeasure(state.load.presetName, state.load.needsContinue,
      not not state.load.pendingChange) then helpers.logLoadMeasurements("editor-changed") end
end
effects.resetLoad = function() resetLoadState() end
effects.invalidatePreflight = function() state.invalidatePreflight() end
effects.clearInactiveMenu = function()
  if editorModel.clearInactiveMenu(state.app.inCustomization) then state.editor.activeBodyMorphMenu = nil end
end
local function execute(actions, detail)
  for _, action in ipairs(actions) do effects[action](detail) end
end

function setEditorOpenStatus(message, isError, kind)
  state.status.sections.editor.message = message
  state.status.sections.editor.error = isError == true
  state.status.kinds.editor = kind or (isError and "error" or "info")
  log("[editor] " .. tostring(message), isError and "error" or "info")
end

helpers.activeWardrobeSetEquipped = function()
  local playerOk, player = pcall(Game.GetPlayer)
  if not playerOk or not player then return false, nil end
  local setOk, activeSet = pcall(EquipmentSystem.GetActiveWardrobeSetID, player)
  if not setOk or activeSet == nil then return false, player end
  return activeSet ~= gameWardrobeClothingSetIndex.INVALID, player
end

function equipmentSystem()
  local ok, system = pcall(function()
    return Game.GetScriptableSystemsContainer():Get("EquipmentSystem")
  end)
  if ok then return system end
  return nil
end

function temporarilyDisableWardrobe()
  if not editorModel.wardrobeNeeded(state.editor.wardrobeTemporarilyDisabled) then return true end
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
  state.editor.wardrobeTemporarilyDisabled = true
  log("[wardrobe] The active outfit was removed while the character editor is open.", "info")
  return true
end

function restoreTemporarilyDisabledWardrobe()
  if not editorModel.restoreNeeded(state.editor.wardrobeTemporarilyDisabled) then return true end
  local playerOk, player = pcall(Game.GetPlayer)
  local system = equipmentSystem()
  if not playerOk or not player or not system then
    log("[wardrobe] Waiting for the player and equipment system before putting the outfit back on.", "warn")
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
  state.editor.wardrobeTemporarilyDisabled = false
  log("[wardrobe] Put the outfit back on after character editing.", "info")
  return true
end

function openFullAppearanceEditor()
  log(("[editor diagnostic] launch requested: controller=%s pending=%s customization=%s")
    :format(tostring(state.editor.inGameMenuController ~= nil),
      tostring(state.editor.openPending), tostring(helpers.isCustomizationActive())), "info")
  local gate = editorModel.launchGate(state.editor.openPending, state.editor.hooksAvailable)
  if gate == "pending" then
    setEditorOpenStatus("The editor is already opening.", true)
    return false
  end
  if gate == "unsupported" then
    setEditorOpenStatus("This game or CET version does not support the full editor.", true)
    return false
  end
  local target = editorModel.launchTarget(helpers.isCustomizationActive(),
    not not state.editor.inGameMenuController)
  if target == "active" then
    setEditorOpenStatus("A customization screen is already open.", true)
    return false
  end
  if target == "unavailable" then
    setEditorOpenStatus("Load or reload a save.", true)
    return false
  end

  local timer, pending = editorModel.beginLaunch()
  state.editor.openTimer = timer
  state.editor.openPending = pending
  temporarilyDisableWardrobe()
  local ok, openError = pcall(
    state.editor.inGameMenuController.SpawnMenuInstanceEvent,
    state.editor.inGameMenuController,
    "OnOpenPauseMenu"
  )
  execute(editorModel.launchResult(ok), openError)
  return ok
end


helpers.isCustomizationActive = function()
  local _, options = getOptions()
  return options ~= nil
end

function refreshEditorState()
  local wasInCustomization = state.app.inCustomization
  state.app.inCustomization = helpers.isCustomizationActive()
  execute(editorModel.refreshPlan(wasInCustomization, state.app.inCustomization))
end


return {open=openFullAppearanceEditor, refresh=refreshEditorState, disableWardrobe=temporarilyDisableWardrobe, restoreWardrobe=restoreTemporarilyDisabledWardrobe}
end
return {install=install}
