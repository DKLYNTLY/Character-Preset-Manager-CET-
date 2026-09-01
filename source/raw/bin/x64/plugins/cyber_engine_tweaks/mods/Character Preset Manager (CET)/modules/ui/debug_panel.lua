local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

ui.setDebugLogText = function(text)
  state.ui.debugLogText = tostring(text or "")
  local lines = {}
  for line in (state.ui.debugLogText .. "\n"):gmatch("(.-)\n") do
    local lowerLine = line:lower()
    local kind = "disabled"
    if line == "" then
      kind = "blank"
    elseif lowerLine:find("[load error]", 1, true)
        or lowerLine:find("[error]", 1, true) then
      kind = "error"
    elseif lowerLine:find("[load warning]", 1, true)
        or lowerLine:find("[warn]", 1, true) then
      kind = "warn"
    elseif lowerLine:find("[complete]", 1, true) then
      kind = "complete"
    elseif lowerLine:find("[load]", 1, true) then
      kind = "load"
    elseif lowerLine:find("[info]", 1, true) then
      kind = "info"
    elseif lowerLine:find("error", 1, true)
        or lowerLine:find("could not", 1, true)
        or lowerLine:find("not available", 1, true) then
      kind = "error"
    end
    table.insert(lines, { text = line, kind = kind })
  end
  state.ui.debugLogLines = lines
  state.ui.listPages.activityLog = math.max(1,
    math.ceil(#lines / ACTIVITY_LOG_PAGE_SIZE))
end

ui.clearDiagnosticLog = function()
  state.ui.debugLogText = ""
  state.ui.debugLogLines = {}
end

ui.closeDebugPanel = function()
  state.ui.debugOpen = false
  ui.clearDiagnosticLog()
end

ui.readDiagnosticLog = function()
  closeActivityLog()
  local file = io.open(LOG_FILE, "rb")
  if not file then
    ui.setDebugLogText("No activity log yet -- nothing has happened this session.")
    return
  end
  local limit = 65536
  local sizeOk, size = pcall(file.seek, file, "end")
  if not sizeOk or not size then
    file:close()
    ui.setDebugLogText("The activity log could not be measured.")
    return
  end
  local truncated = size > limit
  local start = truncated and (size - limit) or 0
  local seekOk, seekResult = pcall(file.seek, file, "set", start)
  local ok, contents = false, nil
  if seekOk and seekResult ~= nil then ok, contents = pcall(file.read, file, "*a") end
  file:close()
  if not ok or type(contents) ~= "string" then
    ui.setDebugLogText("The activity log could not be read.")
    return
  end
  if truncated then
    contents = "[Showing the newest 64 KB of Data/Logs/Activity.log]\n\n" ..
      contents
  end
  ui.setDebugLogText(contents ~= "" and contents
    or "Data/Logs/Activity.log is empty.")
end

ui.drawDebugPanel = function(height)
  ImGui.Spacing()
  local logRowStartX = ImGui.GetCursorPosX()
  local logRowWidth = ImGui.GetContentRegionAvail()
  local logButtonWidth = 68
  local logButtonHeight = 32
  local logButtonsWidth = logButtonWidth * 3 + 16
  ImGui.TextColored(0.97, 0.72, 0.20, 1.0, "Activity Log")
  ImGui.SameLine()
  ImGui.SetCursorPosX(logRowStartX + logRowWidth - logButtonsWidth)
  if ImGui.Button("Refresh##debugRefresh", logButtonWidth, logButtonHeight) then ui.readDiagnosticLog() end
  ImGui.SameLine()
  if ImGui.Button("Copy##debugCopy", logButtonWidth, logButtonHeight) then
    ImGui.SetClipboardText(state.ui.debugLogText or "")
  end
  ImGui.SameLine()
  if ImGui.Button("Close##debugClose", logButtonWidth, logButtonHeight) then ui.closeDebugPanel() end
  if compactSubsectionButton(
      "Technical Details", "Hide Technical Details", "advancedDiagnostics") then
    ImGui.Indent(8)
    ImGui.TextWrapped(("Editor launch: input=%d  controller=%d  redirect=%d  puppet=%d")
      :format(state.editor.inputCount, state.editor.controllerCaptureCount,
        state.editor.pauseRedirectCount, state.editor.puppetReadyCount))
    coloredWrapped(0.64, 0.67, 0.73, 1.0,
      "After one successful input launch, all four values should be at least 1.")
    ImGui.TextWrapped(state.nativeCatalog.serviceAvailable
      and "Native file service: answered this game session"
      or (state.nativeCatalog.serviceProbePending
        and "Native file service: waiting for its startup answer"
        or "Native file service: no answer this game session"))
    if state.nativeCatalog.available then
      ImGui.TextWrapped(("Native file list: verified, %d files, %d folders, %d skipped")
        :format(state.nativeCatalog.fileCount, state.nativeCatalog.directoryCount,
          state.nativeCatalog.skipped))
    else
      ImGui.TextWrapped("Native file list: CET fallback -- " ..
        tostring(state.nativeCatalog.fallbackReason or "not available"))
    end
    finishCompactSubsection()
  end
  ImGui.TextColored(0.3, 1.0, 0.4, 1.0, "Green = complete")
  ImGui.SameLine()
  ImGui.TextColored(0.75, 0.77, 0.82, 1.0, "|")
  ImGui.SameLine()
  ImGui.TextColored(1.0, 0.8, 0.2, 1.0, "Yellow = warning")
  ImGui.SameLine()
  ImGui.TextColored(0.75, 0.77, 0.82, 1.0, "|")
  ImGui.SameLine()
  ImGui.TextColored(1.0, 0.4, 0.4, 1.0, "Red = error")
  ImGui.Spacing()
  drawPageControls("activityLog", #state.ui.debugLogLines,
    ACTIVITY_LOG_PAGE_SIZE, "Activity Log")
  ImGui.BeginChild("##debugLog", 0, height or 200, true)
  local firstLine, lastLine = pagedRange("activityLog",
    #state.ui.debugLogLines, ACTIVITY_LOG_PAGE_SIZE)
  for index = firstLine, lastLine do
    local entry = state.ui.debugLogLines[index]
    local line = entry.text
    if entry.kind == "blank" then
      ImGui.Spacing()
    elseif entry.kind == "error" then
      coloredWrapped(1.0, 0.4, 0.4, 1.0, line)
    elseif entry.kind == "warn" then
      coloredWrapped(1.0, 0.8, 0.2, 1.0, line)
    elseif entry.kind == "complete" then
      coloredWrapped(0.3, 1.0, 0.4, 1.0, line)
    elseif entry.kind == "load" then
      coloredWrapped(1.0, 1.0, 1.0, 1.0, line)
    elseif entry.kind == "info" then
      coloredWrapped(1.0, 1.0, 1.0, 1.0, line)
    else
      ImGui.TextDisabled(line)
    end
  end
  ImGui.EndChild()
end

return _ENV
