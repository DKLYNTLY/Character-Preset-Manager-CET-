local _ENV = require("modules.runtime")

function helpHeading(text)
  ImGui.Spacing()
  ImGui.TextColored(0.97, 0.72, 0.20, 1.0, text)
  ImGui.Separator()
end

ui.readCETBinding = function(slug)
  local bound
  local queryAvailable = false
  if type(IsBound) == "function" then
    local ok, result = pcall(IsBound, slug)
    if ok and type(result) == "boolean" then
      queryAvailable = true
      bound = result
    end
  end
  if bound == false then return "unbound" end
  if type(GetBind) == "function" then
    local ok, result = pcall(GetBind, slug)
    if ok then
      queryAvailable = true
      if type(result) == "string" then
        result = result:match("^%s*(.-)%s*$")
        if result ~= "" then return "bound", result end
      end
      if bound == nil then return "unbound" end
    end
  end
  if bound then return "bound" end
  if queryAvailable then return "unbound" end
  return "unavailable"
end

ui.drawBindingHelp = function(label, slug, receivedCount)
  ImGui.TextWrapped(label)
  local binding = state.bindingCache[slug]
  if not binding then
    local status, assignedKey = ui.readCETBinding(slug)
    binding = { status = status, assignedKey = assignedKey }
    state.bindingCache[slug] = binding
  end
  local status, assignedKey = binding.status, binding.assignedKey
  if status == "bound" and assignedKey then
    coloredWrapped(0.3, 1.0, 0.4, 1.0, "Assigned key: " .. assignedKey)
  elseif status == "bound" then
    coloredWrapped(0.3, 1.0, 0.4, 1.0, "Assigned in CET Bindings.")
  elseif status == "unbound" then
    coloredWrapped(1.0, 0.4, 0.4, 1.0, "Assigned key: Not set")
  elseif receivedCount > 0 then
    coloredWrapped(0.3, 1.0, 0.4, 1.0,
      ("CET input detected %d time%s this session.")
        :format(receivedCount, receivedCount == 1 and "" or "s"))
  else
      coloredWrapped(0.64, 0.67, 0.73, 1.0,
        "Assigned key unavailable; view it in CET Bindings.")
  end
end

ui.pathCallout = function(childId, label, path)
  ImGui.Spacing()
  ImGui.PushStyleColor(ImGuiCol.ChildBg, 0.086, 0.094, 0.118, 0.85)
  ImGui.PushStyleColor(ImGuiCol.Border, 0.95, 0.72, 0.20, 0.55)
  local pathLines = math.max(1, math.ceil(#tostring(path) / 48))
  local calloutHeight = math.min(118, 38 + pathLines * 18)
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

ui.discoveryViewport = function()
  if ImGui.GetMainViewport then
    local viewport = ImGui.GetMainViewport()
    if viewport and viewport.WorkPos and viewport.WorkSize then
      return viewport.WorkPos.x, viewport.WorkPos.y,
        viewport.WorkSize.x, viewport.WorkSize.y
    end
  end
  if ImGui.GetDisplaySize then
    local width, height = ImGui.GetDisplaySize()
    if width and height then return 0, 0, width, height end
  end
  return 0, 0, 1920, 1080
end

drawDiscoveryHudNotice = function()
  if not state.discoveryNoticePending or state.discoveryNoticeIgnored
      or state.overlayOpen then return end
  local layout = state.discoveryNoticeLayout
  if not layout then
    local viewportX, viewportY, viewportWidth = ui.discoveryViewport()
    local titleWidth = ImGui.CalcTextSize(DISCOVERY_NOTICE_TITLE)
    local messageWidth = ImGui.CalcTextSize(DISCOVERY_NOTICE_MESSAGE)
    local settingsWidth = ImGui.CalcTextSize(DISCOVERY_NOTICE_SETTINGS_MESSAGE)
    local width = math.min(viewportWidth - 48,
      math.max(340, math.max(titleWidth, messageWidth, settingsWidth) + 32))
    layout = {
      width = width,
      height = 82,
      x = viewportX + math.max(24, (viewportWidth - width) * 0.5),
      y = viewportY + 72,
      titleX = math.max(14, (width - titleWidth) * 0.5),
      messageX = math.max(14, (width - messageWidth) * 0.5),
      settingsX = math.max(14, (width - settingsWidth) * 0.5),
      flags = bit32.bor(
        ImGuiWindowFlags.NoTitleBar,
        ImGuiWindowFlags.NoResize,
        ImGuiWindowFlags.NoScrollbar,
        ImGuiWindowFlags.NoScrollWithMouse,
        ImGuiWindowFlags.NoCollapse,
        ImGuiWindowFlags.NoSavedSettings,
        ImGuiWindowFlags.NoMove,
        ImGuiWindowFlags.NoInputs
      ),
    }
    state.discoveryNoticeLayout = layout
  end
  ImGui.SetNextWindowPos(layout.x, layout.y, ImGuiCond.Always)
  ImGui.SetNextWindowSize(layout.width, layout.height, ImGuiCond.Always)
  ImGui.PushStyleColor(ImGuiCol.WindowBg, 0.055, 0.059, 0.078, 0.94)
  ImGui.PushStyleColor(ImGuiCol.Border, 0.95, 0.72, 0.20, 0.85)
  ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 6.0)
  ImGui.PushStyleVar(ImGuiStyleVar.WindowBorderSize, 1.0)
  ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 14.0, 7.0)
  if ImGui.Begin("##CharacterPresetManagerDiscovery", true, layout.flags) then
    ImGui.SetCursorPosX(layout.titleX)
    ImGui.TextColored(0.97, 0.72, 0.20, 1.0,
      DISCOVERY_NOTICE_TITLE)
    ImGui.SetCursorPosX(layout.messageX)
    ImGui.TextColored(1.0, 1.0, 1.0, 1.0,
      DISCOVERY_NOTICE_MESSAGE)
    ImGui.SetCursorPosX(layout.settingsX)
    ImGui.TextColored(0.64, 0.67, 0.73, 1.0,
      DISCOVERY_NOTICE_SETTINGS_MESSAGE)
  end
  ImGui.End()
  ImGui.PopStyleVar(3)
  ImGui.PopStyleColor(2)
end

drawSettingsPanel = function(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
if state.settingsOpen then
      ImGui.Spacing()
      ImGui.BeginChild("##settings", 0, 226, true)
      ImGui.TextColored(0.97, 0.72, 0.20, 1.0, "Settings")
      ImGui.TextDisabled(CONFIG_FILE)
      ImGui.TextWrapped("Show the gameplay reminder when a character customization screen opens.")
      local reminderEnabled = not state.discoveryNoticeIgnored
      local reminderLabel = reminderEnabled
        and "Customization Reminder: Enabled"
        or "Customization Reminder: Disabled"
      if fullWidthButton(reminderLabel .. "##discoveryPreference", actionButtonHeight) then
        local saved
        if reminderEnabled then saved = helpers.ignoreDiscoveryNotice()
        else saved = helpers.restoreDiscoveryNotice() end
        local currentState = state.discoveryNoticeIgnored and "disabled" or "enabled"
        if saved then
          state.settingsStatus = "Customization reminder " .. currentState .. ". Settings saved."
        else
          state.settingsStatus = "Customization reminder " .. currentState ..
            " for this session, but the settings file could not be saved."
        end
      end
      local sortLabel = state.sortMode == "modified"
        and "Preset Sort: Last Modified" or "Preset Sort: Name"
      if fullWidthButton(sortLabel .. "##presetSort", actionButtonHeight) then
        state.sortMode = state.sortMode == "modified" and "name" or "modified"
        invalidateViewCache()
        state.settingsStatus = writeConfig() and "Settings saved." or "The settings file could not be saved."
      end
      if fullWidthButton("Reload Settings File##reloadConfig", actionButtonHeight) then
        local config, loaded = readConfig()
        if loaded then
          state.discoveryNoticeIgnored = not config.discoveryReminder
          if state.discoveryNoticeIgnored then state.discoveryNoticePending = false end
          state.discoveryNoticeLayout = nil
          state.sortMode = config.presetSort == "modified" and "modified" or "name"
          invalidateViewCache()
          state.settingsStatus = "Settings file reloaded."
        else
          state.settingsStatus = "The settings file could not be reloaded."
        end
      end
      if state.settingsStatus ~= "" then
        coloredWrapped(0.64, 0.67, 0.73, 1.0, state.settingsStatus)
      end
      ImGui.EndChild()
    end
end

drawHelpPanel = function(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
if state.helpOpen then
      ImGui.Spacing()
      ImGui.PushStyleColor(ImGuiCol.ChildBg, 0.086, 0.094, 0.118, 0.85)
      ImGui.PushStyleColor(ImGuiCol.Border, 0.95, 0.72, 0.20, 0.55)
      ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 1.0, 1.0, 1.0)
      ImGui.PushStyleColor(ImGuiCol.TextDisabled, 0.64, 0.67, 0.73, 1.0)
      ImGui.BeginChild("##help", 0, 230 + math.min(extraHeight * 0.20, 80), true)

      helpHeading("Before You Start")
      coloredWrapped(1.0, 0.4, 0.4, 1.0,
        "Remove Appearance Change Unlocker (ACU) and Character Customization Anywhere, then restart the game. These mods change the same character screens and cannot be used with Character Preset Manager.")
      ImGui.TextWrapped("Keep the same character option mods, versions, and load order that were used to make the preset. If they change, check the appearance and save the preset again.")
      ImGui.TextWrapped("Photo Mode and Appearance Menu Mod may stay installed, but you cannot save or load presets inside their menus. Use the full editor, a mirror, a ripperdoc, or the new-game editor.")
      coloredWrapped(1.0, 0.8, 0.2, 1.0,
        "If the game stays on a loading screen after you close an editor, remove all clothing and choose No Outfit before trying again. This is a Cyberpunk issue and can happen without this mod.")

      ImGui.Separator()

      helpHeading("Open the Editor")
      ImGui.TextWrapped("Load a saved game, then select Open Full Appearance Editor. You can also use a mirror, a ripperdoc, or the new-game editor.")
      ImGui.TextWrapped("Set these keys under CET Bindings > Character Preset Manager (CET). Close the CET window before using the editor key.")
      ui.drawBindingHelp("Open Full Appearance Editor", "preset_manager_open_editor_input",
        state.editorInputCount)
      ui.drawBindingHelp("Toggle Character Preset Manager (CET)",
        "vanilla_character_presets_toggle", state.windowHotkeyCount)

      helpHeading("Load a Preset")
      ImGui.TextWrapped("1. Open a supported character editor.")
      ImGui.TextWrapped("2. Choose a preset under Load Preset.")
      ImGui.TextWrapped("3. Select Load Selected Preset once.")
      coloredWrapped(0.3, 1.0, 0.4, 1.0,
        "4. Wait for the final result. Green means every option was confirmed. Yellow means the game did not confirm one or more changes.")
      ImGui.TextWrapped("If you add, remove, or edit preset files outside CET, select Refresh under Load Preset before using them.")
      coloredWrapped(1.0, 0.8, 0.2, 1.0,
        "After applying the preset, the mod may clear appearance options that are not saved in it. It checks the preset again after each cleared option.")

      helpHeading("Save a Preset")
      ImGui.TextWrapped("1. Open a supported character editor.")
      ImGui.TextWrapped("2. Under Save Preset, open Choose Save Destination.")
      ImGui.TextWrapped("3. Choose a folder or All Presets, then enter a name.")
      ImGui.TextWrapped("4. Select Save New Preset. Only confirm Replace Existing Preset if you want to overwrite it.")

      helpHeading("Organize Presets")
      ImGui.TextWrapped("Select a folder row under Load Preset to open or close it. Presets that are not in a folder appear under All Presets.")
      ImGui.TextWrapped("To move a preset, choose the preset, choose its new folder, then select Move Selected Preset Here. Choose All Presets to remove it from a folder.")
      ImGui.TextWrapped("A new folder is placed inside the selected folder. Choose All Presets first to create a main folder.")
      ImGui.TextWrapped("Folders made in CET organize presets only inside the mod. They do not create matching Windows folders and have no set limit.")
      ImGui.TextWrapped("Windows folders placed inside Character Presets appear with an Imported label. The mod keeps unknown files in those folders safe.")

      helpHeading("Rename, Copy, or Remove")
      ImGui.TextWrapped("Choose a preset or folder first. Renaming a preset also renames its .preset file. Renaming a folder changes only the name shown in the mod.")
      ImGui.TextWrapped("A copy appears beside the original. Copying a folder also copies every preset and folder inside it.")
      ImGui.TextWrapped("Remove Folder, Keep Presets removes the folder but moves everything inside it to the folder above. It never deletes unknown files.")

      helpHeading("Delete and Restore")
      ImGui.TextWrapped("Under Folders, you can move a folder and everything inside it to Trash. Use Delete & Restore to move one preset or several visible presets to Trash.")
      ImGui.TextWrapped("You can restore presets and complete folders later. If a name is already in use, the restored item gets a Copy name instead of replacing anything.")
      ImGui.TextWrapped("Empty Trash Permanently is the only action that permanently deletes files. All Trash actions ask for confirmation.")

      helpHeading("Share One Preset")
      ImGui.TextWrapped("Share one appearance by sending its .preset file. To install one, place the file in Character Presets or in a Windows folder inside it, then select Refresh under Load Preset.")
      ImGui.TextWrapped("A shared preset does not include its CET folder. Older Character Preset Manager and compatible ACU preset files can still be loaded.")
      ImGui.TextWrapped("New format-8 preset files use plain headings and readable option details. Saving over an older preset or saving its optional details updates it to the current format.")
      ImGui.TextWrapped("If an older preset loads the wrong custom option after you change option mods, correct the appearance and save it again in the current format.")
      ui.pathCallout("##presetFolderPath", "Preset Folder",
        "bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Character Presets")
      if fullWidthButton("Copy Preset Folder Path##copyPresetPath", actionButtonHeight) then
        ImGui.SetClipboardText(
          "bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Character Presets")
      end

      helpHeading("Share a Folder")
      ImGui.TextWrapped("To share a folder, choose a non-empty folder under Folders and select Export Folder for Sharing. The new .cpmfolder file appears in Character Presets and includes everything inside that folder.")
      ImGui.TextWrapped("To install a shared folder, place its .cpmfolder file in Character Presets. Under Folders, choose All Presets, then select Install Shared Folders.")
      ImGui.TextWrapped("The mod skips a bundle that was already imported and has not changed. If you deleted its imported folder, you can import the same bundle again.")
      ImGui.TextWrapped("To remove only a .cpmfolder file, choose All Presets, open Shared Folder Files, and move the file to Trash. This does not remove the installed presets or the folder that was shared.")

      helpHeading("Settings")
      ImGui.TextWrapped("Use Settings to turn the character-screen reminder on or off and choose how presets are sorted. Your choices are saved.")
      ImGui.TextWrapped("Advanced users can also change Data/Config/Config.txt, then select Reload Settings File.")

      helpHeading("Activity Log")
      ImGui.TextWrapped("Open the activity log to see recent preset actions, warnings, and errors. You can copy the log when asking for help.")
      if fullWidthButton("Open Activity Log##openDebugFromHelp", actionButtonHeight) then
        ui.readDiagnosticLog()
        state.debugOpen = true
        state.helpOpen = false
        state.settingsOpen = false
      end

      ImGui.EndChild()
      ImGui.PopStyleColor(4)
    end
end

return _ENV
