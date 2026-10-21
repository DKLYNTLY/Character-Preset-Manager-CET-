local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

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
  if state.editor.wardrobeTemporarilyDisabled then return true end
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
  log("[wardrobe] Active outfit temporarily removed for character customization.", "info")
  return true
end

function restoreTemporarilyDisabledWardrobe()
  if not state.editor.wardrobeTemporarilyDisabled then return true end
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
  state.editor.wardrobeTemporarilyDisabled = false
  log("[wardrobe] Restored the outfit used before character customization.", "info")
  return true
end

function openFullAppearanceEditor()
  log(("[editor diagnostic] launch requested: controller=%s pending=%s customization=%s")
    :format(tostring(state.editor.inGameMenuController ~= nil),
      tostring(state.editor.openPending), tostring(helpers.isCustomizationActive())), "info")
  if state.editor.openPending then
    setEditorOpenStatus("The editor is already opening.", true)
    return false
  end
  if not state.editor.hooksAvailable then
    setEditorOpenStatus("The full editor is not available with this game or CET version.", true)
    return false
  end
  if helpers.isCustomizationActive() then
    setEditorOpenStatus("A customization screen is already open.", true)
    return false
  end
  if not state.editor.inGameMenuController then
    setEditorOpenStatus("Load or reload a save.", true)
    return false
  end

  state.editor.openTimer = 0
  state.editor.openPending = true
  temporarilyDisableWardrobe()
  local ok, openError = pcall(
    state.editor.inGameMenuController.SpawnMenuInstanceEvent,
    state.editor.inGameMenuController,
    "OnOpenPauseMenu"
  )
  if not ok then
    state.editor.openPending = false
    restoreTemporarilyDisabledWardrobe()
    setEditorOpenStatus("The game rejected the request: " ..
      tostring(openError), true)
    return false
  end
  setEditorOpenStatus("Opening the full appearance editor...", false)
  return true
end


helpers.isCustomizationActive = function()
  local _, options = getOptions()
  return options ~= nil
end

function refreshEditorState()
  local wasInCustomization = state.app.inCustomization
  state.app.inCustomization = helpers.isCustomizationActive()
  if state.app.inCustomization ~= wasInCustomization then
    if state.load.presetName and (state.load.needsContinue or state.load.pendingChange) then
      helpers.logLoadMeasurements("editor-changed")
    end
    resetLoadState()
    state.invalidatePreflight()
  end
  if not state.app.inCustomization then state.editor.activeBodyMorphMenu = nil end
end

return _ENV
