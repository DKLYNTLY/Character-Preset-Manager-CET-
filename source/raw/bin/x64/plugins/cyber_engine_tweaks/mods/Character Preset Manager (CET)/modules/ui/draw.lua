local _ENV = require("modules.runtime")

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
    local wrote = writeFileSafely(WINDOW_POSITION_STATUS_FILE, "w", function(status)
      return status:write((
        "Character Preset Manager (CET) initial right-side position applied.\n" ..
        "Applied: %s\nDisplay width: %s\nInitial X: %s\nInitial Y: %s\n"
      ):format(logTimestamp(), tostring(displayWidth), tostring(initialX),
        tostring(initialY))) ~= nil
    end)
    if wrote then
      log(("[UI] Window position status written: file='%s' success=%s.")
        :format(WINDOW_POSITION_STATUS_FILE, tostring(wrote)), "info")
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
    local topControlsWidth = topButtonWidth * 3 + 16
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
      if state.settingsOpen then
        state.helpOpen = false
        state.debugOpen = false
      end
    end
    ImGui.SameLine()
    if ImGui.Button("Help##help", topButtonWidth, actionButtonHeight) then
      state.helpOpen = not state.helpOpen
      if state.helpOpen then
        state.settingsOpen = false
        state.debugOpen = false
        state.bindingCache = {}
      end
    end
    ImGui.SameLine()
    if ImGui.Button("Log##debug", topButtonWidth, actionButtonHeight) then
      state.debugOpen = not state.debugOpen
      if state.debugOpen then
        state.settingsOpen = false
        state.helpOpen = false
        ui.readDiagnosticLog()
      end
    end
    drawSettingsPanel(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
    if state.debugOpen then
      ui.drawDebugPanel(extraHeight)
    end
    drawHelpPanel(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
    drawEditorSection(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
    drawLoadSection(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
    drawSaveSection(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
    drawFoldersSection(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
    drawManageSection(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
    drawTrashSection(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
  end
ImGui.End()
  popTheme()
end

return _ENV
