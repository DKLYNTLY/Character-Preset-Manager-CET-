local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime
local catalogExportMessage

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
  ImGui.TextColored(0.97, 0.72, 0.20, 1.0, "Activity Log")
  local available = ImGui.GetContentRegionAvail()
  local logButtonHeight = math.max(32,ImGui.GetFrameHeight())
  local minimum = math.max(ImGui.CalcTextSize("Refresh"),ImGui.CalcTextSize("Close")) + ImGui.GetFontSize()*2
  local stack = available < minimum*3+16
  local width = stack and available or (available-16)/3
  if ImGui.Button("Refresh##debugRefresh",width,logButtonHeight) then ui.readDiagnosticLog() end
  if not stack then ImGui.SameLine() end
  if ImGui.Button("Copy##debugCopy",width,logButtonHeight) then ImGui.SetClipboardText(state.ui.debugLogText or "") end
  if not stack then ImGui.SameLine() end
  if ImGui.Button("Close##debugClose",width,logButtonHeight) then ui.closeDebugPanel() end
  ImGui.Spacing()
  local _,_,page,pages=pagedRange("activityLog",#state.ui.debugLogLines,ACTIVITY_LOG_PAGE_SIZE)
  local caption=("%d / %d"):format(page,pages)
  local pageWidth=math.max(ImGui.GetFontSize()*2,(available-ImGui.CalcTextSize(caption)-32)/2)
  if page<=1 then ImGui.BeginDisabled() end
  if ImGui.Button("<##logPrevious",pageWidth,logButtonHeight) then state.ui.listPages.activityLog=page-1 end
  if page<=1 then ImGui.EndDisabled() end
  ImGui.SameLine()
  ImGui.Text(caption)
  ImGui.SameLine()
  if page>=pages then ImGui.BeginDisabled() end
  if ImGui.Button(">##logNext",pageWidth,logButtonHeight) then state.ui.listPages.activityLog=page+1 end
  if page>=pages then ImGui.EndDisabled() end
  ImGui.BeginChild("##debugLog",0,ImGui.GetFontSize()*12+math.min(math.max(height or 0,0),100),true)
  local firstLine,lastLine=pagedRange("activityLog",#state.ui.debugLogLines,ACTIVITY_LOG_PAGE_SIZE)
  for index=firstLine,lastLine do
    local entry=state.ui.debugLogLines[index]
    if entry.kind=="blank" then ImGui.Spacing()
    elseif entry.kind=="error" then coloredWrapped(1.0,0.4,0.4,1.0,entry.text)
    elseif entry.kind=="warn" then coloredWrapped(1.0,0.8,0.2,1.0,entry.text)
    elseif entry.kind=="complete" then coloredWrapped(0.3,1.0,0.4,1.0,entry.text)
    elseif entry.kind=="info" or entry.kind=="load" then ImGui.TextWrapped(entry.text)
    else ImGui.TextDisabled(entry.text) end
  end
  ImGui.EndChild()
  if compactSubsectionButton(
      "Technical Details", "Hide Technical Details", "advancedDiagnostics") then
    ImGui.Indent(8)
    ImGui.TextColored(0.3,1.0,0.4,1.0,"Green: complete")
    ImGui.TextColored(1.0,0.8,0.2,1.0,"Yellow: warning")
    ImGui.TextColored(1.0,0.4,0.4,1.0,"Red: error")
    ImGui.Separator()
    local exportUnavailable = not state.app.inCustomization or state.load.auto
      or state.load.needsContinue or state.load.pendingChange ~= nil
    if exportUnavailable then ImGui.BeginDisabled() end
    if ImGui.Button("Export Option Catalog##exportCatalog") then
      local ok, message = helpers.exportOptionCatalog()
      catalogExportMessage = ok and "Saved catalog: " .. message or message
    end
    if exportUnavailable then ImGui.EndDisabled() end
    ImGui.TextWrapped("Writes a read-only snapshot of the editor options to Data/Logs. Unavailable identities are marked.")
    if catalogExportMessage then ImGui.TextWrapped(catalogExportMessage) end
    ImGui.TextWrapped(("Editor launch: input=%d  controller=%d  redirect=%d  puppet=%d")
      :format(state.editor.inputCount, state.editor.controllerCaptureCount,
        state.editor.pauseRedirectCount, state.editor.puppetReadyCount))
    coloredWrapped(0.64, 0.67, 0.73, 1.0,
      "After one successful input launch, all four values should be at least 1.")
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
end

return _ENV
