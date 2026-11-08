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
  if state.ui.focusWindowRequested then
    ImGui.SetNextWindowFocus()
    state.ui.focusWindowRequested = false
  end
  local visible = ImGui.Begin("Character Preset Manager (CET)##CPM2")
  if state.ui.initialWindowPlacementPending and initialX then
    state.ui.initialWindowPlacementPending = false
    log(("[UI] Placed the window on the right for first use: displayWidth=%s x=%s y=%s.")
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
    local actionButtonHeight = math.max(32, ImGui.GetFrameHeight())

    local narrowTopRow = ImGui.GetWindowWidth() < 620
    ImGui.TextColored(1.0,1.0,1.0,1.0,"v"..VERSION)
    ImGui.SameLine()
    ImGui.TextColored(0.35,0.9,0.45,1.0,state.app.inCustomization and "Editor ready" or "Open a character editor to save or load")
    local available=ImGui.GetContentRegionAvail()
    local settingsWidth=ImGui.CalcTextSize("Settings")+ImGui.GetFontSize()*2
    local logWidth=ImGui.CalcTextSize("Log")+ImGui.GetFontSize()*2
    local creatorWidth=available-settingsWidth-logWidth-16
    local stack=creatorWidth<ImGui.CalcTextSize("Character")+24
    local creatorUnavailable=state.editor.openPending or state.app.inCustomization or not state.editor.hooksAvailable
    if creatorUnavailable then ImGui.BeginDisabled() end
    if ui.sizedActionButton("Character Creator##toolbarCreator",stack and available or creatorWidth,actionButtonHeight) then
      require("modules/ui/commands").run(runtime,"open_editor")
    end
    if creatorUnavailable then ImGui.EndDisabled() end
    if not stack then ImGui.SameLine() end
    if ui.sizedActionButton("Settings##settings",stack and (available-8)*0.5 or settingsWidth,actionButtonHeight) then
      state.ui.settingsOpen=not state.ui.settingsOpen
      if state.ui.settingsOpen then ui.closeDebugPanel() end
    end
    ImGui.SameLine()
    if ui.sizedActionButton("Log##debug",stack and (available-8)*0.5 or logWidth,actionButtonHeight) then
      if state.ui.debugOpen then ui.closeDebugPanel()
      else state.ui.debugOpen=true;state.ui.settingsOpen=false;ui.readDiagnosticLog() end
    end
    drawSettingsPanel(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
    if state.ui.debugOpen then
      ui.drawDebugPanel(extraHeight)
    end
    local actionSection = state.ui.actionStatusSection or "load"
    drawSectionStatus(actionSection, "##managerActionStatus", statusHeight,
      "Choose a preset or save the current appearance. Press Refresh to reload the library.", "info")
    drawLoadSection(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
    drawTrashSection(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
  end
ImGui.End()
  popTheme()
end

return _ENV
