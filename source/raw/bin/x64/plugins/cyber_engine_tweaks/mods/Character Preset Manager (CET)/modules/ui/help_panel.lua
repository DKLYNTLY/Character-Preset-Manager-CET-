local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

function helpHeading(text)
  ImGui.Spacing()
  ImGui.TextColored(0.97, 0.72, 0.20, 1.0, text)
  ImGui.Separator()
end

local function helpButton(label, description)
  ImGui.TextColored(0.97, 0.72, 0.20, 1.0, label)
  ImGui.TextWrapped(description)
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
      ImGui.BeginChild("##settings", 0, 240, true)
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
      if compactSubsectionButton("Settings File",
          "Hide Settings File", "settingsFile") then
      ImGui.Indent(8)
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
      finishCompactSubsection()
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
      ImGui.TextDisabled("Type a word, then select Search. Try: share, bug, clothing, ACU, backup, Trash, or favorite.")
      ImGui.PushItemWidth(-1)
      state.ui.helpSearchText = ImGui.InputTextWithHint(
        "##helpSearch", "What do you need help with?", state.ui.helpSearchText, 65)
      ImGui.PopItemWidth()
      local draftHelpQuery = normalizeSearch(state.ui.helpSearchText)
      local appliedHelpQuery = normalizeSearch(state.ui.helpAppliedSearchText)
      local helpSearchButtonWidth = (ImGui.GetContentRegionAvail() - 8) * 0.5
      local helpSearchReady = draftHelpQuery ~= appliedHelpQuery
      if not helpSearchReady then ImGui.BeginDisabled() end
      if ImGui.Button("Search##helpSearchApply", helpSearchButtonWidth,
          actionButtonHeight) then
        state.ui.helpAppliedSearchText = draftHelpQuery
        appliedHelpQuery = draftHelpQuery
      end
      if not helpSearchReady then ImGui.EndDisabled() end
      ImGui.SameLine()
      local helpSearchEmpty = draftHelpQuery == "" and appliedHelpQuery == ""
      if helpSearchEmpty then ImGui.BeginDisabled() end
      if ImGui.Button("Clear##helpSearchClear", helpSearchButtonWidth, actionButtonHeight) then
        state.ui.helpSearchText = ""
        state.ui.helpAppliedSearchText = ""
        draftHelpQuery = ""
        appliedHelpQuery = ""
      end
      if helpSearchEmpty then ImGui.EndDisabled() end
      local helpSearchPending = draftHelpQuery ~= appliedHelpQuery
      if helpSearchPending then
        ImGui.TextColored(0.97, 0.72, 0.20, 1.0,
          "Select Search to show matching Help topics.")
      elseif appliedHelpQuery ~= "" then
        ImGui.TextColored(0.3, 1.0, 0.4, 1.0,
          "Showing Help results for: " .. appliedHelpQuery)
      else
        ImGui.TextDisabled("Select a Help topic to open it.")
      end
      local visibleHelpTopics = 0
      local function showHelpTopic(title, keywords)
        local visible = not helpSearchPending and
          helpTopicMatches(appliedHelpQuery, title, keywords)
        if visible then visibleHelpTopics = visibleHelpTopics + 1 end
        if not visible then return false end
        if appliedHelpQuery ~= "" then return true end
        pushFoldingHeaderTheme()
        local open = ImGui.CollapsingHeader(title .. "##helpTopic:" .. title)
        popFoldingHeaderTheme()
        return open
      end

      if showHelpTopic("Main Window & Help Buttons",
          "button buttons controls interface section header open close settings help log search clear find title window") then
      helpHeading("Main Window & Help Buttons")
      ImGui.TextWrapped("Select any section heading to open or close that section. The window's X closes Character Preset Manager without closing CET.")
      ImGui.TextWrapped("Each section places its status card below the introductory text and above its controls. Read that card before choosing an action.")
      helpButton("Settings", "Opens or closes the mod's preferences. Opening it closes Help and the Activity Log.")
      helpButton("Help", "Opens or closes this searchable Help panel. Opening it closes Settings and the Activity Log.")
      helpButton("Log", "Opens or closes the Activity Log and reads its newest contents.")
      helpButton("Search", "Applies the words typed in Search Help and shows matching topics. Typing alone does not run the search.")
      helpButton("Clear", "Clears the Help search and shows every Help topic again.")
      helpButton("Previous / Next", "Moves through a long list one page at a time. The page line shows the current page and total pages.")
      helpButton("Open & Edit Appearance", "Opens or closes the controls for launching the full character editor.")
      helpButton("Load & Restore Appearance", "Opens or closes preset selection, loading, favorites, and appearance recovery.")
      helpButton("Save & Replace Presets", "Opens or closes the controls for saving the current appearance.")
      helpButton("Rename & Copy Presets", "Opens or closes the selected preset's rename, copy, tag, note, and file controls.")
      helpButton("Create & Organize Folders", "Opens or closes folder creation, organization, sharing, and sharing-file removal.")
      helpButton("Export & Import Backups", "Opens or closes complete-library backup controls.")
      helpButton("Select & Manage Multiple Presets", "Opens or closes selection and actions for several presets at once.")
      helpButton("Delete & Restore Items", "Opens or closes individual Trash, recovery, and permanent deletion controls.")
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

      if showHelpTopic("Open & Edit Appearance",
          "open launch hotkey key binding bindings mirror ripperdoc character creator full appearance editor button") then
      helpHeading("Open & Edit Appearance")
      ImGui.TextWrapped("Load a saved game, then select Open Full Appearance Editor. You can also use a mirror, a ripperdoc, or the new-game editor.")
      helpButton("Open Full Appearance Editor", "Opens the game's complete character editor. It is unavailable while an editor is already open or while the editor is still starting.")
      ImGui.TextWrapped("Set these keys under CET Bindings > Character Preset Manager (CET). Close the CET window before using the editor key.")
      ui.drawBindingHelp("Open Full Appearance Editor", "preset_manager_open_editor_input",
        state.editor.inputCount)
      ui.drawBindingHelp("Toggle Character Preset Manager (CET)",
        "vanilla_character_presets_toggle", state.editor.windowHotkeyCount)
      end

      if showHelpTopic("Load & Restore Appearance",
          "load apply loading bug issue problem stopped stuck wrong mismatch missing unavailable unconfirmed yellow green option check refresh clear search favorite favorites details restore previous force full continue cancel button") then
      helpHeading("Load & Restore Appearance")
      ImGui.TextWrapped("1. Open a supported character editor.")
      ImGui.TextWrapped("2. Choose a preset under Load & Restore Appearance.")
      ImGui.TextWrapped("3. Select Load Selected Preset once.")
      coloredWrapped(0.3, 1.0, 0.4, 1.0,
        "4. Wait for the final result. Green means every option was confirmed. Yellow means the game did not confirm one or more changes.")
      ImGui.TextWrapped("If you change preset files outside CET, select Refresh under Load & Restore Appearance before using them.")
      coloredWrapped(1.0, 0.8, 0.2, 1.0,
        "After applying the preset, the mod may clear appearance options that are not saved in it. It checks the preset again after each cleared option.")
      ImGui.TextWrapped("If loading stops or finishes with a yellow warning, open the Activity Log. Missing or changed character-option mods are the most common cause.")
      ImGui.TextWrapped("Open Preset Options below the main load and restore buttons, then select Check Compatibility when you want to compare the preset with the open editor. The result appears in the Load status card. Selecting a preset does not run this check automatically.")
      ImGui.TextWrapped("Force Full Load is under Preset Options to reduce accidental use. Its cautions appear in the Load status card.")
      ImGui.TextWrapped("Restore Previous Appearance follows the normal loading controls. It uses the recovery snapshot saved before the newest normal preset load.")
      ImGui.TextWrapped("The compact selected-preset line shows its name, folder, saved-option count, and format. Open Preset Options for actions only.")
      helpButton("Preset search", "Filters the preset list by preset name, folder name, or tag as you type.")
      helpButton("Clear", "Clears the preset search and shows the complete preset list.")
      helpButton("Refresh", "Reads preset, folder, Trash, and sharing-file changes made outside the mod without restarting it.")
      helpButton("Preset and folder rows", "A preset row selects that preset. A folder row opens or closes the folder. Favorite presets also appear in the Favorites group.")
      helpButton("Preset Options", "Below the main load and restore buttons, this shows or hides Check Compatibility, Force Full Load, and the favorite action.")
      ImGui.TextWrapped("Main sections, optional groups, and Help topics use the same blue highlight as selected preset rows. Saving and library-management sections start closed.")
      helpButton("Check Compatibility", "Checks the selected preset against the open character editor once. The found, missing, repeated, and invalid totals appear in the Load status card.")
      helpButton("Add Selected Preset to Favorites", "Adds the selected preset to the Favorites group without moving it from its folder.")
      helpButton("Remove Selected Preset from Favorites", "Removes the selected preset from the Favorites group without deleting or moving it.")
      helpButton("Restore Previous Appearance", "Restores the recovery snapshot made immediately before the newest normal preset load. It does not load an older preset file.")
      helpButton("Force Full Load: On / Off", "Under Preset Options, this turns saved-position matching on or off. It can help older presets find renamed options, but you should check the result after loading.")
      helpButton("Load Selected Preset", "Starts applying the selected preset to the open character editor.")
      helpButton("Continue Loading Preset", "Continues a load that needs another pass. The mod normally selects this automatically while loading.")
      helpButton("Cancel Loading", "Stops the active preset load before it finishes.")
      end

      if showHelpTopic("Save & Replace Presets",
          "save create overwrite confirm replace destination location folder all presets new preset name hide button") then
      helpHeading("Save & Replace Presets")
      ImGui.TextWrapped("1. Open a supported character editor.")
      ImGui.TextWrapped("2. Check the save location in the status card.")
      ImGui.TextWrapped("3. Enter a name and select Save New Preset. Only select Confirm Overwrite if you want to replace an existing preset.")
      ImGui.TextWrapped("4. To use another location, open Save Location below the save button and choose a folder or All Presets before saving.")
      helpButton("Save Location", "Below the main save button, this shows or hides the list of folders where the new preset can be saved.")
      helpButton("All Presets and folder rows", "Chooses the save location. All Presets saves outside every folder.")
      helpButton("Save New Preset", "Saves the appearance currently shown in the open character editor using the entered name and chosen location.")
      helpButton("Confirm Overwrite", "Replaces the existing preset with the same name and location. It appears only after Save New Preset finds that name already in use.")
      end

      if showHelpTopic("Create & Organize Folders",
          "organize folder folders add rename copy duplicate move remove keep delete trash confirm all presets selected actions imported windows button") then
      helpHeading("Create & Organize Folders")
      ImGui.TextWrapped("The status card shows the destination used by the folder and preset actions.")
      ImGui.TextWrapped("Select a folder row under Load & Restore Appearance to open or close it. Presets that are not in a folder appear under All Presets.")
      ImGui.TextWrapped("To favorite a preset, choose it under Load & Restore Appearance, open Preset Options, then select Add Selected Preset to Favorites. Favorites stay in their original folders and also appear together above the folder list.")
      ImGui.TextWrapped("To move a preset, choose the preset, choose its new folder, then select Move Selected Preset Here. Choose All Presets to remove it from a folder.")
      ImGui.TextWrapped("A new folder is placed inside the selected folder. Choose All Presets first to create a main folder.")
      ImGui.TextWrapped("Remove Folder, Keep Presets is under Create & Organize Folders. It removes the folder but moves everything inside it to the folder above, and it never deletes unknown files.")
      ImGui.TextWrapped("Folders made in CET organize presets only inside the mod. They do not create matching Windows folders and have no set limit.")
      ImGui.TextWrapped("Windows folders placed inside Character Presets appear with an Imported label. The mod keeps unknown files in those folders safe.")
      helpButton("All Presets and folder rows", "Chooses the destination used by Add Folder and the preset-move buttons. Selecting a folder also makes its management controls available.")
      helpButton("Add Folder", "Creates a folder with the entered name inside the selected folder. Choose All Presets first to create a main folder.")
      helpButton("Rename / Copy / Move / Delete", "Shows or hides the actions for the selected folder.")
      helpButton("Rename Folder", "Changes the selected folder's displayed name to the entered name.")
      helpButton("Duplicate Selected Folder", "Copies the selected folder, every folder inside it, and all of their presets.")
      helpButton("Move Selected Preset Here", "Moves the preset chosen under Load & Restore Appearance into the selected folder.")
      helpButton("Remove Folder, Keep Presets", "Removes only the selected CET folder and moves everything inside it to the folder above.")
      helpButton("Confirm Remove Folder, Keep Presets", "Confirms the folder-only removal after you select Remove Folder, Keep Presets once.")
      helpButton("Move Folder & Presets to Trash", "Moves the selected folder, its folders, and all presets inside it to Trash.")
      helpButton("Confirm Move Folder & Presets to Trash", "Confirms moving the complete selected folder group to Trash.")
      helpButton("Move Selected Preset to All Presets", "Removes the selected preset from its current folder and places it under All Presets.")
      end

      if showHelpTopic("Rename & Copy Presets",
          "manage rename duplicate copy tags notes file path details save hide button") then
      helpHeading("Rename & Copy Presets")
      ImGui.TextWrapped("Choose a preset or folder first. Renaming a preset also renames its .preset file. Renaming a folder changes only the name shown in the mod.")
      ImGui.TextWrapped("A copy appears beside the original. Copying a folder also copies every preset and folder inside it.")
      ImGui.TextWrapped("Open Rename & Copy Presets to rename or copy the selected preset. Open Tags, Notes & File to edit extra details or copy its file path.")
      helpButton("Rename Preset", "Renames the selected preset and its .preset file using the name entered above the button.")
      helpButton("Copy Preset", "Creates a separate copy beside the selected preset. It uses Copy, Copy 2, and similar names when needed.")
      helpButton("Tags, Notes & File", "Shows or hides the selected preset's file path, tags, notes, and detail-saving controls.")
      helpButton("Copy File Path", "Copies the selected preset's complete path from the Cyberpunk 2077 game folder.")
      helpButton("Save Preset Details", "Saves the entered tags and notes. Saving details may update an older preset to the current readable format.")
      end

      if showHelpTopic("Select & Manage Multiple Presets",
          "bulk multiple multi select selected all visible clear row target folder move export share trash confirm several presets button") then
      helpHeading("Select & Manage Multiple Presets")
      ImGui.TextWrapped("Open Select & Manage Multiple Presets to work with several presets at once. Select a preset row to add it to the selection. Select it again to remove it.")
      ImGui.TextWrapped("Use Select All Visible to include every preset shown by the current search. Clear Selection removes every check.")
      ImGui.TextWrapped("After selecting presets, you can move them to one folder, export them together as a .cpmfolder file, or move them to Trash.")
      helpButton("Bulk preset search", "Filters the rows in this section by preset or folder name. It uses the same search text as Load & Restore Appearance.")
      helpButton("Select All Visible", "Selects every preset currently shown by the search.")
      helpButton("Clear Selection", "Removes every preset from the current bulk selection.")
      helpButton("Preset rows", "Select a row to add that preset. A selected row starts with [Selected]; select it again to remove it.")
      helpButton("Move selected to folder", "Chooses the destination for Move Selected. Choose All Presets to remove the presets from their folders.")
      helpButton("Move Selected", "Moves every selected preset to the chosen destination folder.")
      helpButton("Export Selected", "Exports the selected presets together as a .cpmfolder sharing file without moving them.")
      helpButton("Move Presets to Trash", "Starts moving every selected preset to Trash. The number in the label shows how many will move.")
      helpButton("Confirm Bulk Trash", "Confirms the bulk Trash action after you select it once.")
      end

      if showHelpTopic("Delete & Restore Items",
          "delete trash restore recover recovery empty permanent confirm remove folder preset cpmfolder sharing file button") then
      helpHeading("Delete & Restore Items")
      ImGui.TextWrapped("Under Create & Organize Folders, you can move a folder and everything inside it to Trash. Under Delete & Restore Items, you can move the selected preset to Trash.")
      ImGui.TextWrapped("You can restore presets and complete folders later. If a name is already in use, the restored item gets a Copy name instead of replacing anything.")
      ImGui.TextWrapped("Empty Trash Permanently is the only action that permanently deletes files. All Trash actions ask for confirmation.")
      helpButton("Move Selected Preset to Trash", "Moves the preset chosen under Load & Restore Appearance to Trash after confirmation.")
      helpButton("Confirm Move to Trash", "Confirms moving the selected preset to Trash.")
      helpButton("Restore Folder", "Restores the named folder group, all folders inside it, and all of their presets.")
      helpButton("Restore [preset name]", "Restores that individual preset from Trash.")
      helpButton("Restore File [filename]", "Restores that .cpmfolder sharing file without changing installed presets or folders.")
      helpButton("Empty Trash Permanently", "Starts permanent deletion of everything currently in Trash.")
      helpButton("Confirm Empty Trash Permanently", "Permanently deletes every item in Trash. This cannot be undone by the mod.")
      end

      if showHelpTopic("Share One Preset",
          "share sharing send install import export preset file path character presets download upload bug issue wrong option legacy older ACU") then
      helpHeading("Share One Preset")
      ImGui.TextWrapped("Share one appearance by sending its .preset file. To install one, place the file in Character Presets or in a Windows folder inside it, then select Refresh under Load & Restore Appearance.")
      ImGui.TextWrapped("A current format-8 CPM preset records its preset name and CET folder. The mod uses those details when the saved folder list has no entry for the preset. Older Character Preset Manager and compatible ACU preset files can still be loaded.")
      ImGui.TextWrapped("New format-8 preset files begin with CPM Preset and use plain headings and readable option details. Saving over an older preset or saving its optional details updates it to the current format.")
      ImGui.TextWrapped("If an older preset loads the wrong custom option after you change option mods, correct the appearance and save it again in the current format.")
      ui.pathCallout("##presetFolderPath", "Preset Folder",
        "bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Character Presets")
      if fullWidthButton("Copy Preset Folder Path##copyPresetPath", actionButtonHeight) then
        ImGui.SetClipboardText(
          "bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Character Presets")
      end
      helpButton("Copy Preset Folder Path", "Copies the displayed Character Presets folder path so you can paste it into File Explorer or a message.")
      end

      if showHelpTopic("Share a Folder",
          "share sharing send install import export folder bundle cpmfolder file manage delete remove trash hide button") then
      helpHeading("Share a Folder")
      ImGui.TextWrapped("Under Create & Organize Folders, open Share & Import Folders. Choose a non-empty folder and select Export Selected Folder as a .cpmfolder File.")
      ImGui.TextWrapped("To install a shared folder, place its .cpmfolder file in Character Presets, open Share & Import Folders, then select Install .cpmfolder Files from Character Presets.")
      ImGui.TextWrapped("The mod skips a bundle that was already imported and has not changed. If you deleted its imported folder, you can import the same bundle again.")
      ImGui.TextWrapped("To check a sharing file first, select it under Manage & Remove .cpmfolder Files, then choose View Selected .cpmfolder Contents. The preview does not install or change anything.")
      ImGui.TextWrapped("To remove only a sharing file, open Manage & Remove .cpmfolder Files. Moving the file to Trash does not remove installed presets or folders.")
      helpButton("Share & Import Folders", "Shows or hides the controls used to create and install .cpmfolder sharing files.")
      helpButton("Export Selected Folder as a .cpmfolder File", "Creates a sharing file containing the selected folder, every folder inside it, and their presets.")
      helpButton("Install .cpmfolder Files from Character Presets", "Finds and installs valid .cpmfolder files placed in Character Presets.")
      helpButton("Manage & Remove .cpmfolder Files", "Shows or hides the sharing files currently stored in Character Presets. The number shows how many were found.")
      helpButton("Sharing-file rows", "Chooses which .cpmfolder file to view or move to Trash.")
      helpButton("View Selected .cpmfolder Contents / Hide Selected .cpmfolder Contents", "Checks the file and shows its main folder, nested folders, and every preset without installing it.")
      helpButton("Move Selected .cpmfolder File to Trash", "Moves only the selected sharing file to Trash. It does not remove the folder or presets that were installed from it.")
      end

      if showHelpTopic("Settings",
          "settings config customization reminder enabled disabled preset sort name last modified file reload hide preferences button") then
      helpHeading("Settings")
      ImGui.TextWrapped("Use Settings to turn the character-screen reminder on or off and choose how presets are sorted. Open Settings File and select Reload Settings File only after changing Data/Config/Config.txt by hand.")
      helpButton("Customization Reminder: Enabled / Disabled", "Turns the reminder shown when a character customization screen opens on or off. The choice is saved.")
      helpButton("Preset Sort: Name / Last Modified", "Switches the preset list between alphabetical order and newest-changed-first order.")
      helpButton("Settings File", "Shows or hides the manual settings-file control.")
      helpButton("Reload Settings File", "Applies changes made directly to Data/Config/Config.txt without restarting the game.")
      end

      if showHelpTopic("Export & Import Backups",
          "backup export complete everything import selected file dropdown library cpmbackup button") then
      helpHeading("Export & Import Backups")
      ImGui.TextWrapped("Open Export & Import Backups to export the complete preset library, import a .cpmbackup file, or delete a backup file. Complete backups include presets in Imported Windows folders, folders made in CET, empty CET folders, and settings.")
      helpButton("Export Complete Library Backup", "Creates and verifies a .cpmbackup file containing every preset, the CET folder layout, and the current settings file.")
      helpButton("Refresh Backup File List", "Finds .cpmbackup files added or removed outside the mod while the game is running.")
      helpButton("Backup file", "Chooses which .cpmbackup file to import or permanently delete.")
      helpButton("Import Selected Library Backup", "Imports the selected backup without replacing existing items that use the same names.")
      helpButton("Delete Selected Backup Permanently / Confirm Delete Selected Backup Permanently", "Permanently deletes only the chosen .cpmbackup file after a required second selection. Presets already in the library are not deleted.")
      end

      if showHelpTopic("Activity Log",
          "activity log debug diagnostic error errors warning warnings report support open refresh copy close technical details hide button") then
      helpHeading("Activity Log")
      ImGui.TextWrapped("Open the activity log to see recent preset actions, warnings, and errors. You can copy the log when asking for help.")
      ImGui.TextWrapped("A performance warning separates game-option retrieval time from preset-matching time when an option check takes at least 0.05 seconds.")
      helpButton("Previous / Next", "Moves through the Activity Log one page at a time. The newest page opens first.")
      helpButton("Refresh", "Reads the newest Activity Log contents from disk.")
      helpButton("Copy", "Copies the complete loaded Activity Log text to the clipboard, including pages that are not currently shown.")
      helpButton("Close", "Closes the Activity Log panel.")
      helpButton("Technical Details", "Shows or hides editor-launch counters used for troubleshooting the Open Full Appearance Editor action.")
      if fullWidthButton("Open Activity Log##openDebugFromHelp", actionButtonHeight) then
        ui.readDiagnosticLog()
        state.ui.debugOpen = true
        state.ui.helpOpen = false
        state.ui.settingsOpen = false
      end
      helpButton("Open Activity Log", "Closes Help and opens the Activity Log.")
      end

      if visibleHelpTopics == 0 and not helpSearchPending then
        ImGui.Spacing()
        ImGui.TextWrapped("No help topic matches that search. Try a shorter word such as share, bug, load, folder, backup, or Trash.")
      end

      ImGui.EndChild()
      ImGui.PopStyleColor(4)
    end
end

return _ENV
