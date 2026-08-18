local runtime = require("modules.runtime") or CPMRuntime
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

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
  { ImGuiCol.Header,            0.24,  0.32,  0.42,  0.65 },
  { ImGuiCol.HeaderHovered,     0.28,  0.38,  0.50,  0.65 },
  { ImGuiCol.HeaderActive,      0.24,  0.32,  0.42,  0.90 },
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

function collapsibleSectionHeader(label, key)
  ImGui.Spacing()
  ImGui.PushStyleColor(ImGuiCol.Header, 0.055, 0.059, 0.078, 0.98)
  ImGui.PushStyleColor(ImGuiCol.HeaderHovered, 0.12, 0.09, 0.04, 0.98)
  ImGui.PushStyleColor(ImGuiCol.HeaderActive, 0.18, 0.12, 0.04, 1.0)
  ImGui.PushStyleColor(ImGuiCol.Text, 0.97, 0.72, 0.20, 1.0)
  local defaultFlag = state.openSections[key] ~= false and 32 or 0
  local open = ImGui.CollapsingHeader(label .. "##CPMSectionV2:" .. key, defaultFlag)
  ImGui.PopStyleColor(4)
  if open then ImGui.Spacing() end
  return open
end

function fullWidthButton(label, height)
  local width = ImGui.GetContentRegionAvail()
  return ImGui.Button(label, width, height or 32)
end

function compactSubsectionButton(closedLabel, openLabel, key)
  ImGui.Spacing()
  local open = state.openSubsections[key] == true
  local closedWidth = ImGui.CalcTextSize(closedLabel)
  local openWidth = ImGui.CalcTextSize(openLabel)
  local availableWidth = ImGui.GetContentRegionAvail()
  local width = math.min(math.max(closedWidth, openWidth) + 20, availableWidth)
  ImGui.PushStyleColor(ImGuiCol.Button, 0.10, 0.11, 0.14, 1.0)
  ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.28, 0.38, 0.50, 0.78)
  ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.24, 0.32, 0.42, 0.95)
  ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, 0.0)
  if ImGui.Button((open and openLabel or closedLabel) ..
      "##CPMSubsection:" .. key, width, 26) then
    open = not open
    state.openSubsections[key] = open
  end
  ImGui.PopStyleVar(1)
  ImGui.PopStyleColor(3)
  if open then ImGui.Spacing() end
  return open
end

function dangerButton(label, width, height)
  ImGui.PushStyleColor(ImGuiCol.Button,        0.62, 0.16, 0.13, 0.92)
  ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.78, 0.20, 0.16, 1.0)
  ImGui.PushStyleColor(ImGuiCol.ButtonActive,  0.48, 0.11, 0.09, 1.0)
  local pressed = ImGui.Button(label, width, height or 32)
  ImGui.PopStyleColor(3)
  return pressed
end

function coloredWrapped(r, g, b, a, text)
  ImGui.PushStyleColor(ImGuiCol.Text, r, g, b, a)
  ImGui.TextWrapped(text)
  ImGui.PopStyleColor(1)
end

function drawSectionStatus(section, childId, height)
  local text = state[section .. "Status"]
  if not text or text == "" then return end
  local kind = state.statusKinds[section]
  local isError = state[section .. "StatusError"] or kind == "error"
  local checkClothing = section == "load"
    and not isError
    and state.inCustomization
    and not state.newGameCharacterCreator
    and not state.autoLoad
    and not state.loadNeedsContinue
    and kind == "ready"
  if checkClothing then
    local clockOk, now = pcall(os.clock)
    now = clockOk and tonumber(now) or 0
    if state.clothingCheckDirty or now >= (state.clothingCheckNextAt or 0) then
      state.cachedClothingLabels = helpers.equippedClothingLabels()
      state.clothingCheckDirty = false
      state.clothingCheckNextAt = now + 1
    end
  end
  local clothingLabels = {}
  if checkClothing then clothingLabels = state.cachedClothingLabels end
  local clothingCheckUnavailable = checkClothing and clothingLabels == nil
  clothingLabels = clothingLabels or {}
  local clothingWarning = #clothingLabels > 0
  if clothingWarning then
    text = "Equipped areas: " .. table.concat(clothingLabels, ", ") ..
      ". You may ignore this notice and load normally. If the game hangs when customization closes, unequip these items and select No Outfit before trying again."
  elseif clothingCheckUnavailable then
    text = "Clothing could not be checked. You may ignore this notice and load normally. If the game hangs when customization closes, unequip all clothing and select No Outfit before trying again."
  end
  local success = not isError and (kind == "success" or kind == "ready")
  local warning = not isError and kind == "warning"
  local destructiveWarning = (section == "delete"
      and (state.pendingEmptyTrash == true
        or (state.pendingDeleteName ~= nil
          and state.pendingDeleteName == state.selected)))
    or (section == "bulk" and state.pendingBulkAction ~= nil)
  local customColors = false
  ImGui.Spacing()
  if isError or destructiveWarning then
    ImGui.PushStyleColor(ImGuiCol.ChildBg, 0.086, 0.094, 0.118, 0.85)
    ImGui.PushStyleColor(ImGuiCol.Border, 0.90, 0.25, 0.22, 0.90)
    customColors = true
  elseif warning or clothingWarning or clothingCheckUnavailable then
    ImGui.PushStyleColor(ImGuiCol.ChildBg, 0.086, 0.094, 0.118, 0.85)
    ImGui.PushStyleColor(ImGuiCol.Border, 0.97, 0.72, 0.20, 0.90)
    customColors = true
  elseif success then
    ImGui.PushStyleColor(ImGuiCol.ChildBg, 0.086, 0.094, 0.118, 0.85)
    ImGui.PushStyleColor(ImGuiCol.Border, 0.22, 0.78, 0.34, 0.90)
    customColors = true
  end
  local estimatedLines = math.max(1, math.ceil(#tostring(text) / 48))
  local panelHeight = math.min(126, math.max(height or 64, 40 + estimatedLines * 18))
  ImGui.BeginChild(childId, 0, panelHeight, true)
  if isError then
    ImGui.TextColored(1.0, 0.4, 0.4, 1.0, "ERROR")
    coloredWrapped(1.0, 1.0, 1.0, 1.0, text)
  elseif destructiveWarning then
    ImGui.TextColored(1.0, 0.4, 0.4, 1.0, "WARNING")
    coloredWrapped(1.0, 0.4, 0.4, 1.0, text)
  elseif warning then
    ImGui.TextColored(1.0, 0.8, 0.2, 1.0, "WARNING")
    coloredWrapped(1.0, 1.0, 1.0, 1.0, text)
  elseif clothingWarning or clothingCheckUnavailable then
    ImGui.TextColored(1.0, 0.8, 0.2, 1.0, "OPTIONAL CLOTHING NOTICE")
    coloredWrapped(1.0, 1.0, 1.0, 1.0, text)
  elseif section == "load" and state.loadStalled then
    ImGui.TextColored(1.0, 0.55, 0.15, 1.0, "ATTENTION")
    coloredWrapped(1.0, 1.0, 1.0, 1.0, text)
  elseif section == "load" and state.loadRemaining > 0 then
    ImGui.TextColored(1.0, 0.8, 0.2, 1.0, "LOADING")
    coloredWrapped(1.0, 1.0, 1.0, 1.0, text)
  elseif success then
    local successLabel = kind == "ready" and "READY" or "SUCCESS"
    ImGui.TextColored(0.3, 1.0, 0.4, 1.0, successLabel)
    coloredWrapped(1.0, 1.0, 1.0, 1.0, text)
  else
    ImGui.TextColored(0.97, 0.72, 0.20, 1.0, "STATUS")
    coloredWrapped(1.0, 1.0, 1.0, 1.0, text)
  end
  ImGui.EndChild()
  if customColors then ImGui.PopStyleColor(2) end
end

return _ENV
