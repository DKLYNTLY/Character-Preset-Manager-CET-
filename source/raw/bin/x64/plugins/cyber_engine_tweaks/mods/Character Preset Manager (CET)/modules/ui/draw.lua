local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

draw = function()
if not state.app.overlayOpen or not state.app.windowOpen then return end

  pushTheme()
  if not state.ui.windowPositionCached then
    state.ui.cachedWindowX, state.ui.cachedWindowY, state.ui.cachedDisplayWidth = ui.defaultWindowPosition()
    state.ui.windowPositionCached = true
  end
  local initialX = state.ui.cachedWindowX
  local initialY = state.ui.cachedWindowY or 40
  local displayWidth = state.ui.cachedDisplayWidth
  if initialX then
    local positionCondition = state.ui.initialWindowPlacementPending
      and ImGuiCond.Always or ImGuiCond.FirstUseEver
    ImGui.SetNextWindowPos(initialX, initialY, positionCondition)
  end
  ImGui.SetNextWindowSize(420, 700, ImGuiCond.FirstUseEver)
  local visible = ImGui.Begin("Character Preset Manager (CET)##CPM2")
  if state.ui.initialWindowPlacementPending and initialX then
    state.ui.initialWindowPlacementPending = false
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
    if state.app.inCustomization then
      ImGui.TextColored(0.35, 0.9, 0.45, 1.0,
        narrowTopRow and "Editor ready" or "Customization editor open")
    else
      ImGui.TextColored(1.0, 0.65, 0.2, 1.0,
        narrowTopRow and "Open editor" or "Open customization to save or load presets")
    end
    ImGui.SameLine()
    ImGui.SetCursorPosX(topRowStartX + topRowWidth - topControlsWidth)
    if ImGui.Button("Settings##settings", topButtonWidth, actionButtonHeight) then
      state.ui.settingsOpen = not state.ui.settingsOpen
      if state.ui.settingsOpen then
        state.ui.helpOpen = false
        ui.closeDebugPanel()
      end
    end
    ImGui.SameLine()
    if ImGui.Button("Help##help", topButtonWidth, actionButtonHeight) then
      state.ui.helpOpen = not state.ui.helpOpen
      if state.ui.helpOpen then
        state.ui.settingsOpen = false
        ui.closeDebugPanel()
        state.ui.bindingCache = {}
      end
    end
    ImGui.SameLine()
    if ImGui.Button("Log##debug", topButtonWidth, actionButtonHeight) then
      if state.ui.debugOpen then
        ui.closeDebugPanel()
      else
        state.ui.debugOpen = true
        state.ui.settingsOpen = false
        state.ui.helpOpen = false
        ui.readDiagnosticLog()
      end
    end
    drawSettingsPanel(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
    if state.ui.debugOpen then
      ui.drawDebugPanel(extraHeight)
    end
    drawHelpPanel(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
    drawEditorSection(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
    drawLoadSection(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
    drawSaveSection(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
    drawManageSection(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
    drawFoldersSection(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
    drawBackupSection(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
    drawBulkSection(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
    drawTrashSection(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
  end
ImGui.End()
  popTheme()
end

return _ENV
