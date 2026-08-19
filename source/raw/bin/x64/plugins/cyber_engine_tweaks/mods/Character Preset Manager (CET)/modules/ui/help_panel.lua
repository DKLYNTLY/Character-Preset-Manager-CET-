local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

function helpHeading(text)
  ImGui.Spacing()
  ImGui.TextColored(0.97, 0.72, 0.20, 1.0, text)
  ImGui.Separator()
end

local function helpTopicMatches(query, title, keywords)
  if query == "" then return true end
  local searchable = (tostring(title) .. " " .. tostring(keywords or "")):lower()
  for term in query:gmatch("%S+") do
    if not searchable:find(term, 1, true) then return false end
  end
  return true
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
  local binding = state.ui.bindingCache[slug]
  if not binding then
    local status, assignedKey = ui.readCETBinding(slug)
    binding = { status = status, assignedKey = assignedKey }
    state.ui.bindingCache[slug] = binding
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
  if not state.ui.discoveryNoticePending or state.ui.discoveryNoticeIgnored
      or state.app.overlayOpen then return end
  local layout = state.ui.discoveryNoticeLayout
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
    state.ui.discoveryNoticeLayout = layout
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
if state.ui.settingsOpen then
      ImGui.Spacing()
      ImGui.BeginChild("##settings", 0, 360, true)
      ImGui.TextColored(0.97, 0.72, 0.20, 1.0, "Settings")
      ImGui.TextDisabled(CONFIG_FILE)
      ImGui.TextWrapped("Show the gameplay reminder when a character customization screen opens.")
      local reminderEnabled = not state.ui.discoveryNoticeIgnored
      local reminderLabel = reminderEnabled
        and "Customization Reminder: Enabled"
        or "Customization Reminder: Disabled"
      if fullWidthButton(reminderLabel .. "##discoveryPreference", actionButtonHeight) then
        local saved
        if reminderEnabled then saved = helpers.ignoreDiscoveryNotice()
        else saved = helpers.restoreDiscoveryNotice() end
        local currentState = state.ui.discoveryNoticeIgnored and "disabled" or "enabled"
        if saved then
          state.status.settings = "Customization reminder " .. currentState .. ". Settings saved."
        else
          state.status.settings = "Customization reminder " .. currentState ..
            " for this session, but the settings file could not be saved."
        end
      end
      local sortLabel = state.library.sortMode == "modified"
        and "Preset Sort: Last Modified" or "Preset Sort: Name"
      if fullWidthButton(sortLabel .. "##presetSort", actionButtonHeight) then
        state.library.sortMode = state.library.sortMode == "modified" and "name" or "modified"
        invalidateViewCache()
        state.status.settings = writeConfig() and "Settings saved." or "The settings file could not be saved."
      end
      if fullWidthButton("Reload Settings File##reloadConfig", actionButtonHeight) then
        local config, loaded = readConfig()
        if loaded then
          state.ui.discoveryNoticeIgnored = not config.discoveryReminder
          if state.ui.discoveryNoticeIgnored then state.ui.discoveryNoticePending = false end
          state.ui.discoveryNoticeLayout = nil
          state.library.sortMode = config.presetSort == "modified" and "modified" or "name"
          invalidateViewCache()
          state.status.settings = "Settings file reloaded."
        else
          state.status.settings = "The settings file could not be reloaded."
        end
      end
      if compactSubsectionButton("Backup: Export / Import / Restore",
          "Hide Backup & Recovery", "backupRecovery") then
      ImGui.Indent(8)
      if fullWidthButton("Export Everything##exportLibraryBackup", actionButtonHeight) then
        exportLibraryBackup()
      end
      local backupFiles = libraryBackupFiles()
      if #backupFiles > 0 and not state.backup.selectedFile then
        state.backup.selectedFile = backupFiles[#backupFiles]
      end
      local selectedBackupLabel = state.backup.selectedFile
        and state.backup.selectedFile:match("([^/]+)$") or "No library backup found"
      if ImGui.BeginCombo("Library backup to import##libraryBackupFile", selectedBackupLabel) then
        for _, backupPath in ipairs(backupFiles) do
          local label = backupPath:match("([^/]+)$") or backupPath
          if ImGui.Selectable(label .. "##backup:" .. backupPath,
              state.backup.selectedFile == backupPath) then
            state.backup.selectedFile = backupPath
          end
        end
        ImGui.EndCombo()
      end
      if #backupFiles == 0 then ImGui.BeginDisabled() end
      if fullWidthButton("Import Library Backup##importLibraryBackup", actionButtonHeight) then
        importLibraryBackup()
      end
      if #backupFiles == 0 then ImGui.EndDisabled() end
      if not fileExists(LAST_APPEARANCE_FILE) then ImGui.BeginDisabled() end
      if fullWidthButton("Restore Appearance from Before Last Load##restoreAppearance", actionButtonHeight) then
        restoreLastAppearance()
        state.ui.settingsOpen = false
      end
      if not fileExists(LAST_APPEARANCE_FILE) then ImGui.EndDisabled() end
      ImGui.Unindent(8)
      end
      if state.status.settings ~= "" then
        coloredWrapped(0.64, 0.67, 0.73, 1.0, state.status.settings)
      end
      ImGui.EndChild()
    end
end

drawHelpPanel = function(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
if state.ui.helpOpen then
      ImGui.Spacing()
      ImGui.PushStyleColor(ImGuiCol.ChildBg, 0.086, 0.094, 0.118, 0.85)
      ImGui.PushStyleColor(ImGuiCol.Border, 0.95, 0.72, 0.20, 0.55)
      ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 1.0, 1.0, 1.0)
      ImGui.PushStyleColor(ImGuiCol.TextDisabled, 0.64, 0.67, 0.73, 1.0)
      ImGui.BeginChild("##help", 0, 230 + math.min(extraHeight * 0.20, 80), true)

      ImGui.TextColored(0.97, 0.72, 0.20, 1.0, "Search Help")
      ImGui.TextDisabled("Try: share, bug, clothing, ACU, backup, Trash, or favorite")
      local helpSearchButtonWidth = 54
      ImGui.PushItemWidth(math.max(90,
        ImGui.GetContentRegionAvail() - helpSearchButtonWidth - 8))
      state.ui.helpSearchText = ImGui.InputTextWithHint(
        "##helpSearch", "What do you need help with?", state.ui.helpSearchText, 65)
      ImGui.PopItemWidth()
      ImGui.SameLine()
      local helpSearchEmpty = normalizeSearch(state.ui.helpSearchText) == ""
      if helpSearchEmpty then ImGui.BeginDisabled() end
      if ImGui.Button("Clear##helpSearchClear", helpSearchButtonWidth, actionButtonHeight) then
        state.ui.helpSearchText = ""
      end
      if helpSearchEmpty then ImGui.EndDisabled() end
      local helpQuery = normalizeSearch(state.ui.helpSearchText)
      local visibleHelpTopics = 0
      local function showHelpTopic(title, keywords)
        local visible = helpTopicMatches(helpQuery, title, keywords)
        if visible then visibleHelpTopics = visibleHelpTopics + 1 end
        return visible
      end

      if showHelpTopic("Problems & Compatibility",
          "bug bugs issue issues problem problems error errors troubleshooting stuck infinite loading screen clothing clothes wardrobe outfit no outfit ACU appearance change unlocker character customization anywhere photo mode appearance menu mod incompatible incompatibility compatibility") then
      helpHeading("Problems & Compatibility")
      coloredWrapped(1.0, 0.4, 0.4, 1.0,
        "Remove Appearance Change Unlocker (ACU) and Character Customization Anywhere, then restart the game. These mods change the same character screens and cannot be used with Character Preset Manager.")
      ImGui.TextWrapped("Keep the same character option mods, versions, and load order that were used to make the preset. If they change, check the appearance and save the preset again.")
      ImGui.TextWrapped("Photo Mode and Appearance Menu Mod may stay installed, but you cannot save or load presets inside their menus. Use the full editor, a mirror, a ripperdoc, or the new-game editor.")
      coloredWrapped(1.0, 0.8, 0.2, 1.0,
        "If the game stays on a loading screen after you close an editor, remove all clothing and choose No Outfit before trying again. This is a Cyberpunk issue and can happen without this mod.")
      end

      if showHelpTopic("Open the Editor",
          "open launch hotkey key binding bindings mirror ripperdoc character creator full appearance editor") then
      helpHeading("Open the Editor")
      ImGui.TextWrapped("Load a saved game, then select Open Full Appearance Editor. You can also use a mirror, a ripperdoc, or the new-game editor.")
      ImGui.TextWrapped("Set these keys under CET Bindings > Character Preset Manager (CET). Close the CET window before using the editor key.")
      ui.drawBindingHelp("Open Full Appearance Editor", "preset_manager_open_editor_input",
        state.editor.inputCount)
      ui.drawBindingHelp("Toggle Character Preset Manager (CET)",
        "vanilla_character_presets_toggle", state.editor.windowHotkeyCount)
      end

      if showHelpTopic("Load a Preset",
          "load apply loading bug issue problem stopped stuck wrong mismatch missing unavailable unconfirmed yellow green option check refresh") then
      helpHeading("Load a Preset")
      ImGui.TextWrapped("1. Open a supported character editor.")
      ImGui.TextWrapped("2. Choose a preset under Load Preset.")
      ImGui.TextWrapped("3. Select Load Selected Preset once.")
      coloredWrapped(0.3, 1.0, 0.4, 1.0,
        "4. Wait for the final result. Green means every option was confirmed. Yellow means the game did not confirm one or more changes.")
      ImGui.TextWrapped("If you add, remove, or edit preset files outside CET, select Refresh under Load Preset before using them.")
      coloredWrapped(1.0, 0.8, 0.2, 1.0,
        "After applying the preset, the mod may clear appearance options that are not saved in it. It checks the preset again after each cleared option.")
      ImGui.TextWrapped("If loading stops or finishes with a yellow warning, open the Activity Log. Missing or changed character-option mods are the most common cause.")
      end

      if showHelpTopic("Save a Preset",
          "save create overwrite replace destination folder new preset") then
      helpHeading("Save a Preset")
      ImGui.TextWrapped("1. Open a supported character editor.")
      ImGui.TextWrapped("2. Under Save Preset, open Choose Save Folder.")
      ImGui.TextWrapped("3. Choose a folder or All Presets, then enter a name.")
      ImGui.TextWrapped("4. Select Save New Preset. Only confirm Replace Existing Preset if you want to overwrite it.")
      end

      if showHelpTopic("Organize Presets",
          "organize folder folders move favorite favorites pin imported windows folder") then
      helpHeading("Organize Presets")
      ImGui.TextWrapped("Select a folder row under Load Preset to open or close it. Presets that are not in a folder appear under All Presets.")
      ImGui.TextWrapped("To favorite a preset, choose it under Load Preset, then select Add Selected Preset to Favorites. Favorites stay in their original folders and also appear together above the folder list.")
      ImGui.TextWrapped("To move a preset, choose the preset, choose its new folder, then select Move Selected Preset Here. Choose All Presets to remove it from a folder.")
      ImGui.TextWrapped("A new folder is placed inside the selected folder. Choose All Presets first to create a main folder.")
      ImGui.TextWrapped("Folders made in CET organize presets only inside the mod. They do not create matching Windows folders and have no set limit.")
      ImGui.TextWrapped("Windows folders placed inside Character Presets appear with an Imported label. The mod keeps unknown files in those folders safe.")
      end

      if showHelpTopic("Rename, Copy, or Remove",
          "rename duplicate copy remove folder keep presets file name") then
      helpHeading("Rename, Copy, or Remove")
      ImGui.TextWrapped("Choose a preset or folder first. Renaming a preset also renames its .preset file. Renaming a folder changes only the name shown in the mod.")
      ImGui.TextWrapped("A copy appears beside the original. Copying a folder also copies every preset and folder inside it.")
      ImGui.TextWrapped("Remove Folder, Keep Presets removes the folder but moves everything inside it to the folder above. It never deletes unknown files.")
      end

      if showHelpTopic("Bulk Actions",
          "bulk multiple multi select selected move export share trash several presets") then
      helpHeading("Bulk Actions")
      ImGui.TextWrapped("Open Bulk Actions to work with several presets at once. Select a preset row to add it to the selection. Select it again to remove it.")
      ImGui.TextWrapped("Use Select All Visible to include every preset shown by the current search. Clear Selection removes every check.")
      ImGui.TextWrapped("After selecting presets, you can move them to one folder, export them together as a .cpmfolder file, or move them to Trash.")
      end

      if showHelpTopic("Delete and Restore",
          "delete trash restore recover recovery empty remove cpmfolder sharing file") then
      helpHeading("Delete and Restore")
      ImGui.TextWrapped("Under Folders, you can move a folder and everything inside it to Trash. Under Delete & Restore, you can move the selected preset to Trash.")
      ImGui.TextWrapped("You can restore presets and complete folders later. If a name is already in use, the restored item gets a Copy name instead of replacing anything.")
      ImGui.TextWrapped("Empty Trash Permanently is the only action that permanently deletes files. All Trash actions ask for confirmation.")
      end

      if showHelpTopic("Share One Preset",
          "share sharing send install import export preset file path character presets download upload bug issue wrong option legacy older ACU") then
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
      end

      if showHelpTopic("Share a Folder",
          "share sharing send install import export folder bundle cpmfolder file delete remove trash") then
      helpHeading("Share a Folder")
      ImGui.TextWrapped("To share a folder, choose a non-empty folder under Folders and select Export Selected Folder as a .cpmfolder File. The new file appears in Character Presets and includes everything inside that folder.")
      ImGui.TextWrapped("To install a shared folder, place its .cpmfolder file in Character Presets. Open Folders, then select Install .cpmfolder Files from Character Presets.")
      ImGui.TextWrapped("The mod skips a bundle that was already imported and has not changed. If you deleted its imported folder, you can import the same bundle again.")
      ImGui.TextWrapped("To remove only a .cpmfolder file, open Folders, then open .cpmfolder Files: Manage / Remove. Moving the sharing file to Trash does not remove installed presets or folders.")
      end

      if showHelpTopic("Settings, Backup & Recovery",
          "settings config reminder sort backup export everything import library restore appearance snapshot recovery") then
      helpHeading("Settings, Backup & Recovery")
      ImGui.TextWrapped("Use Settings to turn the character-screen reminder on or off, choose how presets are sorted, or export and import a complete library backup.")
      ImGui.TextWrapped("Before each normal preset load, the mod quietly saves the current appearance. Restore Appearance from Before Last Load uses the newest snapshot and does not add it to the preset list.")
      ImGui.TextWrapped("Advanced users can also change Data/Config/Config.txt, then select Reload Settings File.")
      end

      if showHelpTopic("Activity Log",
          "activity log debug diagnostic error errors warning warnings report support copy") then
      helpHeading("Activity Log")
      ImGui.TextWrapped("Open the activity log to see recent preset actions, warnings, and errors. You can copy the log when asking for help.")
      if fullWidthButton("Open Activity Log##openDebugFromHelp", actionButtonHeight) then
        ui.readDiagnosticLog()
        state.ui.debugOpen = true
        state.ui.helpOpen = false
        state.ui.settingsOpen = false
      end
      end

      if visibleHelpTopics == 0 then
        ImGui.Spacing()
        ImGui.TextWrapped("No help topic matches that search. Try a shorter word such as share, bug, load, folder, backup, or Trash.")
      end

      ImGui.EndChild()
      ImGui.PopStyleColor(4)
    end
end

return _ENV
