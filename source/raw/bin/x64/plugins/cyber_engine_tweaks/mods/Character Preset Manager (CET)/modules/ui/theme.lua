local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime
local commands = require("modules/ui/commands")

ui = {}

THEME_COLORS = {
  { ImGuiCol.WindowBg,          0.055, 0.059, 0.078, 0.98 },
  { ImGuiCol.ChildBg,           0.086, 0.094, 0.118, 0.85 },
  { ImGuiCol.PopupBg,           0.075, 0.082, 0.102, 0.98 },
  { ImGuiCol.Border,            0.95,  0.72,  0.20,  0.55 },
  { ImGuiCol.TitleBg,           0.075, 0.055, 0.03,  1.0  },
  { ImGuiCol.TitleBgActive,     0.55,  0.35,  0.05,  1.0  },
  { ImGuiCol.Text,              1.0,   1.0,   1.0,   1.0  },
  { ImGuiCol.TextDisabled,      0.64,  0.67,  0.73,  1.0  },
  { ImGuiCol.FrameBg,           0.13,  0.14,  0.17,  1.0  },
  { ImGuiCol.FrameBgHovered,    0.19,  0.20,  0.24,  1.0  },
  { ImGuiCol.FrameBgActive,     0.22,  0.23,  0.28,  1.0  },
  { ImGuiCol.Button,            0.72,  0.42,  0.08,  0.92 },
  { ImGuiCol.ButtonHovered,     0.52,  0.29,  0.05,  1.0  },
  { ImGuiCol.ButtonActive,      0.36,  0.19,  0.03,  1.0  },
  { ImGuiCol.Header,            0.50,  0.28,  0.05,  0.86 },
  { ImGuiCol.HeaderHovered,     0.36,  0.19,  0.03,  0.96 },
  { ImGuiCol.HeaderActive,      0.28,  0.14,  0.02,  1.0  },
  { ImGuiCol.CheckMark,         0.97,  0.72,  0.20,  1.0  },
  { ImGuiCol.SliderGrab,        0.97,  0.72,  0.20,  1.0  },
  { ImGuiCol.SliderGrabActive,  0.85,  0.55,  0.10,  1.0  },
  { ImGuiCol.Separator,         0.95,  0.72,  0.20,  0.35 },
  { ImGuiCol.SeparatorHovered,  0.97,  0.75,  0.25,  0.6  },
  { ImGuiCol.ScrollbarBg,       0.06,  0.065, 0.08,  0.6  },
  { ImGuiCol.ScrollbarGrab,     0.30,  0.28,  0.22,  0.9  },
  { ImGuiCol.ScrollbarGrabHovered, 0.45, 0.38, 0.20, 1.0  },
  { ImGuiCol.ScrollbarGrabActive,  0.55, 0.42, 0.14, 1.0  },
}

THEME_VARS = {
  { ImGuiStyleVar.WindowRounding,   8.0 },
  { ImGuiStyleVar.ChildRounding,    6.0 },
  { ImGuiStyleVar.FrameRounding,    4.0 },
  { ImGuiStyleVar.GrabRounding,     4.0 },
  { ImGuiStyleVar.PopupRounding,    6.0 },
  { ImGuiStyleVar.ScrollbarRounding,6.0 },
  { ImGuiStyleVar.WindowBorderSize, 1.0 },
  { ImGuiStyleVar.ChildBorderSize,  1.0 },
  { ImGuiStyleVar.FrameBorderSize,  1.0 },
  { ImGuiStyleVar.WindowPadding,    14.0, 14.0 },
  { ImGuiStyleVar.FramePadding,     8.0,  5.0  },
  { ImGuiStyleVar.ItemSpacing,      8.0,  8.0  },
}

function pushTheme()
  for _, c in ipairs(THEME_COLORS) do
    ImGui.PushStyleColor(c[1], c[2], c[3], c[4], c[5])
  end
  for _, v in ipairs(THEME_VARS) do
    if v[3] then
      ImGui.PushStyleVar(v[1], v[2], v[3])
    else
      ImGui.PushStyleVar(v[1], v[2])
    end
  end
end

function popTheme()
  ImGui.PopStyleVar(#THEME_VARS)
  ImGui.PopStyleColor(#THEME_COLORS)
end

function pushFoldingHeaderTheme()
  ImGui.PushStyleColor(ImGuiCol.Header, 0.055, 0.059, 0.078, 0.98)
  ImGui.PushStyleColor(ImGuiCol.HeaderHovered, 0.12, 0.09, 0.04, 0.98)
  ImGui.PushStyleColor(ImGuiCol.HeaderActive, 0.18, 0.12, 0.04, 1.0)
  ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 1.0, 1.0, 1.0)
  ImGui.PushStyleColor(ImGuiCol.Border, 0.95, 0.72, 0.20, 0.55)
end

function popFoldingHeaderTheme()
  ImGui.PopStyleColor(5)
end

function collapsibleSectionHeader(label, key)
  ImGui.Spacing()
  ImGui.Separator()
  ImGui.Spacing()
  local destination = state.ui.scrollToSectionRequested or (state.ui.scrollToLoadRequested == true and "load" or nil)
  local focusLoad = destination ~= nil
  if focusLoad then
    ImGui.SetNextItemOpen(key == destination, ImGuiCond.Always)
  else
    ImGui.SetNextItemOpen(false, ImGuiCond.Once)
  end
  pushFoldingHeaderTheme()
  local open = ImGui.CollapsingHeader(label .. "##CPMSectionV4:" .. key)
  popFoldingHeaderTheme()
  state.ui.openSections[key] = open
  if key == destination and focusLoad then
    ImGui.SetScrollHereY(0.0)
    state.ui.scrollToLoadRequested = false
    state.ui.scrollToSectionRequested = nil
    if key == "trash" and helpers.setTrashFollowup then helpers.setTrashFollowup(false) end
  end
  if open then ImGui.Spacing() end
  return open
end

ui.focusSection = function(key)
  local destination=state.ui.scrollToSectionRequested or (state.ui.scrollToLoadRequested==true and "load" or nil)
  if destination==key then
    ImGui.SetScrollHereY(0.0)
    state.ui.scrollToSectionRequested=nil
    state.ui.scrollToLoadRequested=false
    if key=="trash" and helpers.setTrashFollowup then helpers.setTrashFollowup(false) end
  end
end

local function fitButtonText(label,width,height)
  local text,suffix=label:match("^(.-)(##.*)$")
  text,suffix=text or label,suffix or ""
  local lines,line={},""
  for word in text:gmatch("%S+") do
    local nextLine=line=="" and word or line.." "..word
    if line~="" and ImGui.CalcTextSize(nextLine)>math.max(ImGui.GetFontSize()*2,width-24) then
      lines[#lines+1]=line
      line=word
    else line=nextLine end
  end
  lines[#lines+1]=line
  return table.concat(lines,"\n")..suffix,math.max(height or 32,ImGui.GetFrameHeight()+(#lines-1)*ImGui.GetFontSize())
end

ui.sizedActionButton = function(label,width,height)
  local text,buttonHeight=fitButtonText(label,width,height)
  return ImGui.Button(text,width,buttonHeight)
end

function fullWidthButton(label, height)
  local width = ImGui.GetContentRegionAvail()
  local text,buttonHeight=fitButtonText(label,width,height)
  return ImGui.Button(text,width,buttonHeight)
end

function compactSubsectionButton(closedLabel, openLabel, key, plainToggle)
  ImGui.Spacing()
  local open = state.ui.openSubsections[key] == true
  local width=ImGui.GetContentRegionAvail()
  local startX=ImGui.GetCursorPosX()
  ImGui.PushStyleColor(ImGuiCol.Button,
    open and 0.18 or 0.10, open and 0.12 or 0.11,
    open and 0.04 or 0.14, 1.0)
  ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.20, 0.10, 0.02, 0.98)
  ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.30, 0.16, 0.03, 1.0)
  ImGui.PushStyleColor(ImGuiCol.Border,
    open and 1.0 or 0.95, open and 0.55 or 0.72,
    open and 0.15 or 0.20, open and 0.85 or 0.55)
  ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 1.0, 1.0, 1.0)
  local text,buttonHeight=fitButtonText((open and openLabel or closedLabel).."##CPMSubsection:"..key,width,30)
  if ImGui.Button(text,width,buttonHeight) then
    open = not open
    state.ui.openSubsections[key] = open
  end
  ImGui.PopStyleColor(5)
  ImGui.SetCursorPosX(startX)
  if open and not plainToggle then
    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()
  end
  return open
end

function finishCompactSubsection()
  ImGui.Unindent(8)
  ImGui.Spacing()
  ImGui.Separator()
end

function dangerButton(label, width, height)
  ImGui.PushStyleColor(ImGuiCol.Button,        0.62, 0.16, 0.13, 0.92)
  ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.78, 0.20, 0.16, 1.0)
  ImGui.PushStyleColor(ImGuiCol.ButtonActive,  0.48, 0.11, 0.09, 1.0)
  local text,buttonHeight=fitButtonText(label,width,height)
  local pressed = ImGui.Button(text,width,buttonHeight)
  ImGui.PopStyleColor(3)
  return pressed
end

function coloredWrapped(r, g, b, a, text)
  ImGui.PushStyleColor(ImGuiCol.Text, r, g, b, a)
  ImGui.TextWrapped(text)
  ImGui.PopStyleColor(1)
end

function drawSectionStatus(section, childId, height, fallbackMessage, fallbackKind,
    contextText)
  local sectionStatus = state.status.sections[section]
  local hasCurrentStatus = sectionStatus.message and sectionStatus.message ~= ""
  local text = hasCurrentStatus and sectionStatus.message or fallbackMessage
  if not text or text == "" then return end
  local kind = hasCurrentStatus and state.status.kinds[section] or fallbackKind
  local isError = hasCurrentStatus and (sectionStatus.error or kind == "error")
  local success = not isError and (kind == "success" or kind == "ready")
  local warning = not isError and kind == "warning"
  local criticalWarning = not isError and kind == "critical_warning"
  local attention = section == "load"
    and (state.load.stalled or state.load.remaining > 0)
  local destructiveWarning = (section == "delete"
      and (state.trash.pendingEmpty == true
        or (state.trash.pendingDeleteName ~= nil
          and state.trash.pendingDeleteName == state.library.selected)))
    or (section == "bulk" and state.trash.pendingBulkAction == "presets")
    or (section == "folder" and state.trash.pendingBulkAction ~= nil
      and state.trash.pendingBulkAction ~= "presets")
  local customColors = false
  ImGui.Spacing()
  if isError or destructiveWarning or criticalWarning then
    ImGui.PushStyleColor(ImGuiCol.ChildBg, 0.086, 0.094, 0.118, 0.85)
    ImGui.PushStyleColor(ImGuiCol.Border, 0.90, 0.25, 0.22, 0.90)
    customColors = true
  elseif warning then
    ImGui.PushStyleColor(ImGuiCol.ChildBg, 0.086, 0.094, 0.118, 0.85)
    ImGui.PushStyleColor(ImGuiCol.Border, 0.97, 0.72, 0.20, 0.90)
    customColors = true
  elseif attention then
    ImGui.PushStyleColor(ImGuiCol.ChildBg, 0.086, 0.094, 0.118, 0.85)
    ImGui.PushStyleColor(ImGuiCol.Border, 1.0, 0.55, 0.15, 0.90)
    customColors = true
  elseif success then
    ImGui.PushStyleColor(ImGuiCol.ChildBg, 0.086, 0.094, 0.118, 0.85)
    ImGui.PushStyleColor(ImGuiCol.Border, 0.22, 0.78, 0.34, 0.90)
    customColors = true
  else
    ImGui.PushStyleColor(ImGuiCol.ChildBg, 0.086, 0.094, 0.118, 0.85)
    ImGui.PushStyleColor(ImGuiCol.Border, 0.30, 0.55, 0.82, 0.90)
    customColors = true
  end
  local estimatedLines = math.max(1, math.ceil(#tostring(text) / 48))
  if contextText and contextText ~= "" then estimatedLines = estimatedLines + 1 end
  local panelHeight = math.min(ImGui.GetFontSize()*9, math.max(height or 64, ImGui.GetFontSize()*(2+estimatedLines)))
  ImGui.BeginChild(childId, 0, panelHeight, true)
  local function drawStatusText(r, g, b)
    if contextText and contextText ~= "" then
      coloredWrapped(1.0, 0.58, 0.16, 1.0, contextText)
    end
    coloredWrapped(r, g, b, 1.0, text)
  end
  if isError then
    ImGui.TextColored(1.0, 0.4, 0.4, 1.0, "ERROR")
    drawStatusText(1.0, 1.0, 1.0)
  elseif destructiveWarning or criticalWarning then
    ImGui.TextColored(1.0, 0.4, 0.4, 1.0, "WARNING")
    drawStatusText(1.0, 0.4, 0.4)
  elseif warning then
    ImGui.TextColored(1.0, 0.8, 0.2, 1.0, "WARNING")
    drawStatusText(1.0, 1.0, 1.0)
  elseif section == "load" and state.load.stalled then
    ImGui.TextColored(1.0, 0.55, 0.15, 1.0, "ATTENTION")
    drawStatusText(1.0, 1.0, 1.0)
  elseif section == "load" and state.load.remaining > 0 then
    ImGui.TextColored(1.0, 0.8, 0.2, 1.0, "LOADING")
    drawStatusText(1.0, 1.0, 1.0)
  elseif success then
    local successLabel = kind == "ready" and "READY" or "SUCCESS"
    ImGui.TextColored(0.3, 1.0, 0.4, 1.0, successLabel)
    drawStatusText(1.0, 1.0, 1.0)
  else
    ImGui.TextColored(0.42, 0.72, 0.95, 1.0, "STATUS")
    drawStatusText(1.0, 1.0, 1.0)
  end
  ImGui.EndChild()
  if customColors then ImGui.PopStyleColor(2) end
end

function pagedRange(key, count, pageSize)
  local size = math.max(1, tonumber(pageSize) or UI_LIST_PAGE_SIZE)
  local pages = math.max(1, math.ceil((tonumber(count) or 0) / size))
  local page = math.max(1, math.min(pages,
    tonumber(state.ui.listPages[key]) or 1))
  state.ui.listPages[key] = page
  return (page - 1) * size + 1, math.min(count, page * size), page, pages
end

function drawPageControls(key, count, pageSize, label)
  local _, _, page, pages = pagedRange(key, count, pageSize)
  if pages <= 1 then return end
  local width = (ImGui.GetContentRegionAvail() - 8) * 0.5
  if page <= 1 then ImGui.BeginDisabled() end
  if ImGui.Button("Previous##page:" .. key, width, math.max(28, ImGui.GetFrameHeight())) then
    state.ui.listPages[key] = page - 1
  end
  if page <= 1 then ImGui.EndDisabled() end
  ImGui.SameLine()
  if page >= pages then ImGui.BeginDisabled() end
  if ImGui.Button("Next##page:" .. key, width, math.max(28, ImGui.GetFrameHeight())) then
    state.ui.listPages[key] = page + 1
  end
  if page >= pages then ImGui.EndDisabled() end
  ImGui.TextDisabled(("%s page %d of %d"):format(label or "List", page, pages))
end

ui.pathCallout = function(childId, label, path)
  ImGui.Spacing()
  ImGui.PushStyleColor(ImGuiCol.ChildBg, 0.086, 0.094, 0.118, 0.85)
  ImGui.PushStyleColor(ImGuiCol.Border, 0.95, 0.72, 0.20, 0.55)
  local pathLines = math.max(1, math.ceil(#tostring(path) / 48))
  local calloutHeight = ImGui.GetFontSize() * math.min(8, 2 + pathLines)
  ImGui.BeginChild(childId, 0, calloutHeight, true)
  ImGui.TextColored(0.97, 0.72, 0.20, 1.0, label)
  coloredWrapped(1.0, 1.0, 1.0, 1.0, path)
  ImGui.EndChild()
  ImGui.PopStyleColor(2)
end

ui.defaultWindowPosition = function()
  local viewportOk, workX, workY, workWidth = pcall(function()
    if not ImGui.GetMainViewport then return nil end
    local viewport = ImGui.GetMainViewport()
    if not viewport or not viewport.WorkPos or not viewport.WorkSize then return nil end
    return tonumber(viewport.WorkPos.x or viewport.WorkPos.X or viewport.WorkPos[1]),
      tonumber(viewport.WorkPos.y or viewport.WorkPos.Y or viewport.WorkPos[2]),
      tonumber(viewport.WorkSize.x or viewport.WorkSize.X or viewport.WorkSize[1])
  end)
  if viewportOk and workWidth and workWidth > 460 then
    workX, workY = workX or 0, workY or 0
    return math.max(workX + 20, workX + workWidth - 440), workY + 40, workWidth
  end
  local sizeOk, first, second = pcall(function()
    if ImGui.GetDisplaySize then return ImGui.GetDisplaySize() end
    if ImGui.GetIO then
      local io = ImGui.GetIO()
      return io and io.DisplaySize or nil
    end
    return nil
  end)
  local displayWidth = nil
  if sizeOk then
    displayWidth = tonumber(first)
    if not displayWidth and first then
      local widthOk, width = pcall(function()
        return first.x or first.X or first[1]
      end)
      if widthOk then displayWidth = tonumber(width) end
    end
    if not displayWidth then displayWidth = tonumber(second) end
  end
  if not displayWidth then
    local resolutionOk, resolutionWidth = pcall(function()
      return GetDisplayResolution and GetDisplayResolution() or nil
    end)
    if resolutionOk then displayWidth = tonumber(resolutionWidth) end
  end
  if not displayWidth or displayWidth <= 460 then return nil, 40, displayWidth end
  return math.max(20, displayWidth - 440), 40, displayWidth
end

drawSettingsPanel = function(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
  if not state.ui.settingsOpen then return end
  ImGui.Spacing()
  ImGui.BeginChild("##settings",0,ImGui.GetFontSize()*18,true)
  ImGui.TextColored(0.97,0.72,0.20,1.0,"Settings")
  ImGui.Separator()
  ImGui.TextColored(0.22,0.92,1.0,1.0,"Preset Library")
  ImGui.TextWrapped("Visibility")
  ImGui.PushItemWidth(-1)
  local visibility = state.preferences.presetBodyFilter == "all" and "Show all presets" or "Filter by body"
  if ImGui.BeginCombo("##settingsVisibility",visibility) then
    if ImGui.Selectable("Filter by body",state.preferences.presetBodyFilter~="all") then helpers.setPresetBodyFilter("body") end
    if ImGui.Selectable("Show all presets",state.preferences.presetBodyFilter=="all") then helpers.setPresetBodyFilter("all") end
    ImGui.EndCombo()
  end
  ImGui.TextWrapped("Filter by body hides Unknown and opposite-body presets. Refresh checks missing body information.")
  ImGui.TextWrapped("Sort order")
  local modified = state.preferences.presetSort == "modified"
  if ImGui.BeginCombo("##settingsSort",modified and "Last modified" or "Name") then
    if ImGui.Selectable("Name",not modified) then commands.run(runtime,"sort_name") end
    if ImGui.Selectable("Last modified",modified) then commands.run(runtime,"sort_modified") end
    ImGui.EndCombo()
  end
  ImGui.PopItemWidth()
  ImGui.Spacing()
  ImGui.Separator()
  ImGui.TextColored(0.22,0.92,1.0,1.0,"Diagnostics")
  local detailed=ImGui.Checkbox("Detailed appearance tracing",state.preferences.detailedAppearanceTrace==true)
  if detailed~=state.preferences.detailedAppearanceTrace then
    local previous=state.preferences.detailedAppearanceTrace
    state.preferences.detailedAppearanceTrace=detailed
    if not writeConfig() then state.preferences.detailedAppearanceTrace=previous end
  end
  ImGui.TextWrapped("Adds snapshots, per-choice logs, and performance profiles. Leave this off for normal use.")
  ImGui.Spacing()
  ImGui.Separator()
  ImGui.TextColored(0.22,0.92,1.0,1.0,"Saved Settings")
  ImGui.TextWrapped("Changes save automatically. These controls are available in CET.")
  ImGui.TextWrapped(CONFIG_FILE)
  if state.status.settings ~= "" then ImGui.TextWrapped(state.status.settings) end
  ImGui.EndChild()
end


return _ENV
