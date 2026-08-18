local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

function setEditorOpenStatus(message, isError, kind)
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

function equipmentSystem()
  local ok, system = pcall(function()
    return Game.GetScriptableSystemsContainer():Get("EquipmentSystem")
  end)
  if ok then return system end
  return nil
end

function temporarilyDisableWardrobe()
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

function restoreTemporarilyDisabledWardrobe()
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

function openFullAppearanceEditor()
  log(("[editor diagnostic] launch requested: controller=%s pending=%s customization=%s")
    :format(tostring(state.inGameMenuController ~= nil),
      tostring(state.editorOpenPending), tostring(helpers.isCustomizationActive())), "info")
  if state.editorOpenPending then
    setEditorOpenStatus("The editor is already opening.", true)
    return false
  end
  if not state.editorHooksAvailable then
    setEditorOpenStatus("The full editor is not available with this game or CET version.", true)
    return false
  end
  if helpers.isCustomizationActive() then
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


helpers.isCustomizationActive = function()
  local _, options = getOptions()
  return options ~= nil
end

function refreshEditorState()
  local wasInCustomization = state.inCustomization
  state.inCustomization = helpers.isCustomizationActive()
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

return _ENV
