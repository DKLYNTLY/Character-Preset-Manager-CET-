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

drawFallbackHudNotice = function()
  if not state.ui.fallbackNoticePending or state.app.overlayOpen then return end
  local layout = state.ui.fallbackNoticeLayout
  if not layout then
    local _, viewportY, viewportWidth = ui.defaultWindowPosition()
    viewportY = tonumber(viewportY) or 0
    viewportWidth = tonumber(viewportWidth) or 1280
    local titleWidth = ImGui.CalcTextSize(FALLBACK_NOTICE_TITLE)
    local messageWidth = ImGui.CalcTextSize(FALLBACK_NOTICE_MESSAGE)
    local cetWidth = ImGui.CalcTextSize(FALLBACK_NOTICE_CET_MESSAGE)
    local width = math.min(viewportWidth - 48,
      math.max(380, math.max(titleWidth, messageWidth, cetWidth) + 32))
    layout = {
      width = width,
      height = 82,
      x = math.max(24, (viewportWidth - width) * 0.5),
      y = viewportY + 72,
      titleX = math.max(14, (width - titleWidth) * 0.5),
      messageX = math.max(14, (width - messageWidth) * 0.5),
      cetX = math.max(14, (width - cetWidth) * 0.5),
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
    state.ui.fallbackNoticeLayout = layout
  end
  ImGui.SetNextWindowPos(layout.x, layout.y, ImGuiCond.Always)
  ImGui.SetNextWindowSize(layout.width, layout.height, ImGuiCond.Always)
  ImGui.PushStyleColor(ImGuiCol.WindowBg, 0.055, 0.059, 0.078, 0.94)
  ImGui.PushStyleColor(ImGuiCol.Border, 0.95, 0.72, 0.20, 0.85)
  ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 6.0)
  ImGui.PushStyleVar(ImGuiStyleVar.WindowBorderSize, 1.0)
  ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 14.0, 7.0)
  if ImGui.Begin("##CharacterPresetManagerFallback", true, layout.flags) then
    ImGui.SetCursorPosX(layout.titleX)
    ImGui.TextColored(0.97, 0.72, 0.20, 1.0, FALLBACK_NOTICE_TITLE)
    ImGui.SetCursorPosX(layout.messageX)
    ImGui.TextColored(1.0, 1.0, 1.0, 1.0, FALLBACK_NOTICE_MESSAGE)
    ImGui.SetCursorPosX(layout.cetX)
    ImGui.TextColored(0.64, 0.67, 0.73, 1.0, FALLBACK_NOTICE_CET_MESSAGE)
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
      ImGui.TextWrapped("Preset Sort Order")
      if ImGui.Selectable("Name##settingsSortName",
          state.preferences.presetSort == "name") then
        setPresetSortPreference("name")
      end
      if ImGui.Selectable("Last modified##settingsSortModified",
          state.preferences.presetSort == "modified") then
        setPresetSortPreference("modified")
      end
      ImGui.Spacing()
      ImGui.TextWrapped("This setting is available here in CET.")
      ImGui.TextDisabled(CONFIG_FILE)
      if compactSubsectionButton("Settings File",
          "Hide Settings File", "settingsFile") then
      ImGui.Indent(8)
      ImGui.TextWrapped("This file mirrors the shared setting automatically. Complete-library backups include it.")
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
      ImGui.TextWrapped("Select a section heading to open or close it. The arrow shows its state. Use the window's X to close Character Preset Manager while keeping CET open.")
      ImGui.TextWrapped("Each section shows its status above the controls. The orange line names the current selection or setting. Blue means information, green means ready or done, yellow means a warning, and red means an error.")
      helpButton("Settings", "Shows the mod's settings. It closes Help and the Activity Log.")
      helpButton("Help", "Shows this Help panel. Settings and the Activity Log close when Help opens.")
      helpButton("Log", "Shows or hides the Activity Log and reads its latest entries.")
      helpButton("Search", "Shows topics that match your search words. Select Search after typing.")
      helpButton("Clear", "Clears your search so you can browse all Help topics.")
      helpButton("Previous / Next", "Moves one page forward or back. The page counter shows where you are in the list.")
      helpButton("Open & Edit Appearance", "Shows or hides the full editor and randomizer controls.")
      helpButton("Load & Restore Appearance", "Shows the preset list, load controls, favorites, and appearance history.")
      helpButton("Save & Replace Presets", "Shows the controls for saving your current appearance.")
      helpButton("Rename & Copy Presets", "Shows the selected preset's name, copy controls, tags, notes, and file details.")
      helpButton("Create & Organize Folders", "Shows tools for creating, arranging, and sharing folders, plus controls for removing sharing files.")
      helpButton("Export & Import Backups", "Shows the controls for backing up or importing your whole library.")
      helpButton("Select & Manage Multiple Presets", "Shows tools for selecting and working with several presets together.")
      helpButton("Delete & Restore Items", "Shows Trash, restore controls, and permanent deletion.")
      end

      if showHelpTopic("Problems & Compatibility",
          "bug bugs issue issues problem problems error errors troubleshooting stuck infinite loading screen clothing clothes wardrobe outfit no outfit ACU appearance change unlocker character customization anywhere photo mode appearance menu mod incompatible incompatibility compatibility future update patch simple panel missing successor backup") then
      helpHeading("Problems & Compatibility")
      ImGui.TextWrapped("For game 2.5, install CET 1.38.0, RED4ext 1.31.0, redscript 0.5.32, and Codeware 1.21.1 or newer. These are the minimum versions; each framework must also support your installed game version.")
      coloredWrapped(1.0, 0.4, 0.4, 1.0,
        "Remove Character Customization Anywhere and restart the game. Both mods change the same character screens, so they cannot work together.")
      ImGui.TextWrapped("Uninstall Appearance Change Unlocker (ACU) and fully restart the game. Keep only its preset files, which the importer can read without ACU installed. The files are copied into the library after startup, and the file service watches for later changes. If a file is missing, select Refresh to check again.")
      ImGui.TextWrapped("Character Preset Manager follows on from ACU. The package includes the CET manager, simple menu, and file service. If the simple menu or file service stops working after a game update, use CET when its required frameworks support that game version.")
      ImGui.TextWrapped("CC and CCXL examples include EKT Custom Character Creator - FEMV ONLY for facial choices and Head Cyberware CCXL for added cyberware choices. Install each mod and its requirements separately; presets save choices, not the mod files.")
      ImGui.TextWrapped("Keep the character mods, versions, and load order used when you saved the preset. If your setup changes, check the result and save it again.")
      coloredWrapped(1.0, 0.8, 0.2, 1.0,
        "If closing an editor leaves the game on a loading screen, remove all clothing and choose No Outfit before trying again. This can also happen without the mod.")
      end

      if showHelpTopic("Open & Edit Appearance",
          "open launch hotkey key binding bindings mirror ripperdoc character creator full appearance editor voice tone feminine masculine confirm cancel button") then
      helpHeading("Open & Edit Appearance")
      ImGui.TextWrapped("Voice Tone cannot be changed mid-game. Choose your voice during new-game character creation.")
      ImGui.TextWrapped("Load a save and select Open Full Appearance Editor. Mirrors, ripperdocs, and new-game creation also support presets.")
      helpButton("Open Full Appearance Editor", "Opens the full character editor. Wait until it finishes opening before using another editor control.")
      ImGui.TextWrapped("Assign the editor key under CET Bindings > Character Preset Manager (CET). Close the CET overlay before pressing it.")
      ui.drawBindingHelp("Open Full Appearance Editor", "preset_manager_open_editor_input",
        state.editor.inputCount)
      helpButton("Randomize", "Randomizes your appearance using the game's current locks. R still works in the character screen. Wait for any preset load or recovery to finish first.")
      helpButton("Randomize Settings", "Shows which appearance categories the randomizer can change. If you use this button in CET, close the overlay to see the settings.")
      helpButton("Advanced Preset Manager", "Opens CET and shows the complete manager using your saved CET binding. Keep the game in focus and release other keys. If it does not open, press your CET binding yourself.")
      end

      if showHelpTopic("Load & Restore Appearance",
          "load apply loading bug issue problem stopped stuck wrong mismatch missing unavailable unconfirmed yellow green option check refresh clear search favorite favorites details restore previous force full continue cancel button") then
      helpHeading("Load & Restore Appearance")
      ImGui.TextWrapped("Select a preset once to load it automatically. Hair, cyberware, and linked choices may need a brief wait between changes. Check any unconfirmed-value warning before confirming the editor.")
      ImGui.TextWrapped("1. Open a supported character editor.")
      ImGui.TextWrapped("2. Find a preset in the simple menu on the left. Use Search to narrow the list, or select a folder to open it.")
      ImGui.TextWrapped("3. Select a preset to load it. To review it first, use Check Compatibility in CET.")
      ImGui.TextWrapped("4. Read Panel Status below the preset list. It shows load progress, results, errors, and prompts for Save or Trash. A red marker means something needs attention.")
      ImGui.TextWrapped("5. Use Check Compatibility in CET to see matches, changes, missing choices, unclear matches, invalid entries, and options that will be cleared.")
      coloredWrapped(0.3, 1.0, 0.4, 1.0,
        "6. Wait for loading to finish. Panel Status and the CET Load status say whether the game confirmed each saved choice.")
      ImGui.TextWrapped("After a preset or button action, Q and E can rotate your character again. Search and Preset Name keep the keyboard while you type.")
      ImGui.TextWrapped("If you change preset files outside CET, select Refresh under Load & Restore Appearance before using them.")
      coloredWrapped(1.0, 0.8, 0.2, 1.0,
        "Loading clears old choices first, applies main choices next, then applies colors and linked details. Each stage uses small groups across updates, followed by a shared check.")
      ImGui.TextWrapped("Open the Activity Log if loading stops or ends with a yellow warning. Check for missing or changed character mods.")
      ImGui.TextWrapped("Both menus use the same loader. Choices share a check at the end of each stage, with time for the editor to finish linked updates. Check the visible result before leaving the editor.")
      ImGui.TextWrapped("Open Advanced Preset Options and select Check Compatibility to compare a preset with the current editor. Read the result in the Load status card. Choosing a preset alone does not start a check.")
      ImGui.TextWrapped("Find Force Full Load under Advanced Preset Options. Read its warning in the Load status card before using it.")
      ImGui.TextWrapped("Appearance History sits below Restore Previous Appearance. Choose one of the five latest recovery entries.")
      ImGui.TextWrapped("The selected-preset line shows its name, folder, number of saved options, and format. Extra actions are under Advanced Preset Options.")
      helpButton("Preset search", "Filters the preset list by preset name, folder name, or tag as you type.")
      helpButton("Clear", "Clears the preset search and shows the complete preset list.")
      helpButton("Refresh", "Reads preset, folder, Trash, and sharing-file changes made outside the mod without restarting it.")
      helpButton("Preset and folder rows", "A preset row selects that preset. A folder row opens or closes the folder. Favorites also appear together in their own group above the folders.")
      helpButton("Refresh options", "Clears the option cache and reads the current editor list again. Saved choice lists are checked as they are used, including after a linked style changes. This does not reload mod files; restart the game after changing mods when needed.")
      helpButton("Appearance History", "Below Restore Previous Appearance, this shows the five newest recovery appearances and lets you restore one or clear the list.")
      helpButton("Advanced Preset Options", "Below Appearance History, this shows or hides Check Compatibility, Force Full Load, and the favorite action.")
      ImGui.TextWrapped("CET uses orange for main controls and selected rows, with white section headings. Extra controls use dark buttons. Open & Edit Appearance starts open; the other main sections start closed.")
      helpButton("Check Compatibility", "Checks the selected preset against the open character editor once. The found, missing, repeated, and invalid totals appear in the Load status card.")
      helpButton("Add Selected Preset to Favorites", "Adds the selected preset to the Favorites group without moving it from its folder.")
      helpButton("Remove Selected Preset from Favorites", "Removes the selected preset from the Favorites group without deleting or moving it.")
      helpButton("Restore Previous Appearance", "Restores the latest saved recovery appearance. The simple menu also offers Undo Last Load and Recovery History.")
      helpButton("Force Full Load: On / Off", "Allows matching by saved position when an older preset lacks exact details. Find it under Advanced Preset Options, then check the appearance when loading finishes.")
      helpButton("Load Selected Preset", "Starts applying the selected preset to the open character editor.")
      helpButton("Continue Loading Preset", "Continues an unfinished load. This normally happens on its own.")
      helpButton("Cancel Loading", "Stops loading further choices. Changes already made remain visible.")
      end

      if showHelpTopic("Save & Replace Presets",
          "save create overwrite confirm replace destination location folder all presets new preset name hide button") then
      helpHeading("Save & Replace Presets")
      ImGui.TextWrapped("1. Open a supported character editor.")
      ImGui.TextWrapped("2. In the character-screen panel, enter a name in Preset Name.")
      ImGui.TextWrapped("3. Select Save Location to open the folder list, then choose a folder or All Presets.")
      ImGui.TextWrapped("4. Select Save Preset. If the name is in use, the button changes to Confirm Overwrite. Press it again only to replace that preset.")
      ImGui.TextWrapped("Move Preset to Trash needs a second press on Confirm Move to Trash. Restore the preset from Trash in CET. CET also has renaming, permanent deletion, Empty Trash, Help, and other tools.")
      helpButton("Change Save Location", "Shows the folders you can save into. This control is below the main save button.")
      helpButton("All Presets and folder rows", "Chooses the save location. All Presets saves outside every folder.")
      helpButton("Save New Preset", "Saves your current appearance under the name and location you chose.")
      helpButton("Confirm Overwrite", "Replaces the preset with that name in the chosen folder. This prompt appears when the save name is already in use.")
      end

      if showHelpTopic("Create & Organize Folders",
          "organize folder folders add rename copy duplicate move remove keep delete trash confirm all presets selected actions imported windows button") then
      helpHeading("Create & Organize Folders")
      ImGui.TextWrapped("The status card names the folder that these actions will use.")
      ImGui.TextWrapped("Select a folder row under Load & Restore Appearance to open or close it. Presets that are not in a folder appear under All Presets.")
      ImGui.TextWrapped("Choose a preset under Load & Restore Appearance, then open Advanced Preset Options and select Add Selected Preset to Favorites. It stays in its folder and also appears above the folder list.")
      ImGui.TextWrapped("To move a preset, choose the preset, choose its new folder, then select Move Selected Preset Here. Choose All Presets to remove it from a folder.")
      ImGui.TextWrapped("A new folder is placed inside the selected folder. To create a main folder, choose All Presets before adding it.")
      ImGui.TextWrapped("Use Remove Folder, Keep Presets under Create & Organize Folders to remove only the folder. Its contents move to the folder above. Unknown files are kept.")
      ImGui.TextWrapped("Folders made in CET organize the library without creating Windows folders. You can nest them with no set depth limit.")
      ImGui.TextWrapped("Windows folders inside Character Presets show an Imported label. Files the mod does not recognize are kept.")
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
      ImGui.TextWrapped("Choose a preset or folder first. A preset rename also changes its .preset filename, while a folder rename only changes its name in the mod.")
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
      ImGui.TextWrapped("Open Select & Manage Multiple Presets to work with a group. Select each preset you want, then select it again to remove it from the group.")
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
      ImGui.TextWrapped("Move a whole folder to Trash under Create & Organize Folders. For one preset, use Delete & Restore Items.")
      ImGui.TextWrapped("You can restore presets and complete folders later. If a name is already in use, the restored item gets a Copy name instead of replacing anything.")
      ImGui.TextWrapped("Empty Trash Permanently deletes items in Trash. Deleting a backup permanently removes only that backup file. Both menus ask before moving a preset to recoverable Trash.")
      helpButton("Move Selected Preset to Trash", "The first press changes the same button to Confirm Move to Trash. The second press moves the chosen preset to recoverable Trash.")
      helpButton("Confirm Move to Trash", "Confirms moving the selected preset to Trash.")
      helpButton("Restore Folder", "Restores the named folder group, all folders inside it, and all of their presets.")
      helpButton("Restore [preset name]", "Restores that individual preset from Trash.")
      helpButton("Restore File [filename]", "Restores that .cpmfolder sharing file without changing installed presets or folders.")
      helpButton("Empty Trash Permanently", "Starts permanent deletion of everything currently in Trash.")
      helpButton("Confirm Empty Trash Permanently", "Permanently deletes every item in Trash. This cannot be undone by the mod.")
      end

      if showHelpTopic("Share One Preset",
          "share sharing send install export preset file path character presets download upload bug issue wrong option legacy older") then
      helpHeading("Share One Preset")
      ImGui.TextWrapped("Share one appearance by sending its .preset file. To install one, place the file in Character Presets or in a Windows folder inside it, then select Refresh under Load & Restore Appearance.")
      ImGui.TextWrapped("A format-8 CPM file stores its preset name and CET folder. These help rebuild a missing folder-list entry. Older preset files still load.")
      ImGui.TextWrapped("Format-8 files start with CPM Preset and use plain headings and option details. An older file stays unchanged until you overwrite it or save its notes or tags.")
      ImGui.TextWrapped("If an older preset loads the wrong custom option after you change option mods, correct the appearance and save it again in the current format.")
      ui.pathCallout("##presetFolderPath", "Preset Folder",
        "bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Character Presets")
      if fullWidthButton("Copy Preset Folder Path##copyPresetPath", actionButtonHeight) then
        ImGui.SetClipboardText(
          "bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Character Presets")
      end
      helpButton("Copy Preset Folder Path", "Copies the displayed Character Presets folder path so you can paste it into File Explorer or a message.")
      end

      if showHelpTopic("Import ACU Presets",
          "ACU appearance change unlocker successor import importing migrate migration preset presets 3.0.0 3.0.1 3.2.1 missing refresh watcher safety dangerous lock eyes") then
      helpHeading("Import ACU Presets")
      ImGui.TextWrapped("Character Preset Manager is ACU's successor and supports the preset layouts used by ACU 3.0.0, 3.0.1, and 3.2.1.")
      ImGui.TextWrapped("Back up your ACU .preset files, then uninstall ACU itself. Recreate bin/x64/plugins/cyber_engine_tweaks/mods/AppearanceChangeUnlocker/character-presets if needed and put only the saved preset files there. Fully restart the game. The importer checks that folder shortly after startup without needing ACU installed.")
      ImGui.TextWrapped("Open Character Preset Manager in CET and look under ACU Presets. If the copies are not shown, select Refresh once and wait a moment. Load the imported copies through Character Preset Manager, not ACU.")
      ImGui.TextWrapped("The original ACU files stay unchanged. New or changed files are copied when needed, and unchanged files are skipped. ACU subfolders are preserved.")
      ImGui.TextWrapped("If a preset does not appear, confirm that it ends in .preset, is not empty, is no larger than 1 MB, and is in the exact ACU folder above. Then check the Activity Log for ACU IMPORT or ACU SAFETY messages.")
      ImGui.TextWrapped("The Activity Log lists internal eye locks and other choices the game marks inactive or locked. That warning does not change the imported file or how it loads.")
      end

      if showHelpTopic("Share a Folder",
          "share sharing send install import export folder bundle cpmfolder file manage delete remove trash hide button") then
      helpHeading("Share a Folder")
      ImGui.TextWrapped("Under Create & Organize Folders, open Share & Import Folders. Choose a non-empty folder and select Export Selected Folder as a .cpmfolder File.")
      ImGui.TextWrapped("To install a shared folder, place its .cpmfolder file in Character Presets, open Share & Import Folders, then select Install .cpmfolder Files from Character Presets.")
      ImGui.TextWrapped("An unchanged bundle is skipped if its imported folder still exists. If you removed its imported folder, the same file can be imported again.")
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
          "settings config preset sort name last modified file hide preferences button") then
      helpHeading("Settings")
      ImGui.TextWrapped("Select Settings at the top of the manager to change Preset Sort Order. Assign your editor key under CET Bindings.")
      ImGui.TextWrapped("Preset Sort Order is the only preference. The mod keeps its load checks and safety features on.")
      ImGui.TextWrapped("The simple menu, five recovery entries, safety saves, and missing-option warnings stay enabled. Use Check Compatibility in CET for a closer look at saved choices.")
      helpButton("Settings File", "Shows the mirrored settings-file location. The mirror updates automatically and is included in complete-library backups.")
      end

      if showHelpTopic("Export & Import Backups",
          "backup export complete everything import selected file dropdown library cpmbackup button") then
      helpHeading("Export & Import Backups")
      ImGui.TextWrapped("Use Export & Import Backups to save your whole library, import a .cpmbackup file, or delete a backup. Each backup includes presets in imported Windows folders, CET folders, empty CET folders, and settings.")
      helpButton("Export Complete Library Backup", "Creates and verifies a .cpmbackup file containing every preset, the CET folder layout, and the current settings file.")
      helpButton("Refresh Backup File List", "Finds .cpmbackup files added or removed outside the mod while the game is running.")
      helpButton("Backup file", "Chooses which .cpmbackup file to import or permanently delete.")
      helpButton("Import Selected Library Backup", "Imports the selected backup without replacing existing items that use the same names.")
      helpButton("Delete Selected Backup Permanently / Confirm Delete Selected Backup Permanently", "Deletes only the chosen .cpmbackup file after a second press. Your installed presets stay in the library.")
      end

      if showHelpTopic("Activity Log",
          "activity log debug diagnostic error errors warning warnings report support open refresh copy close technical details hide button") then
      helpHeading("Activity Log")
      ImGui.TextWrapped("Open the activity log to see recent preset actions, warnings, and errors. You can copy the log when asking for help.")
      ImGui.TextWrapped("If an option check takes at least 0.05 seconds, the log shows how much time went into reading game options and matching the preset.")
      helpButton("Previous / Next", "Moves through the Activity Log one page at a time. The newest page opens first.")
      helpButton("Refresh", "Reads the newest Activity Log contents from disk.")
      helpButton("Copy", "Copies all loaded log entries to the clipboard, including pages you are not viewing.")
      helpButton("Close", "Closes the Activity Log panel.")
      helpButton("Technical Details", "Shows counts of editor-opening steps to help find problems with Open Full Appearance Editor.")
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
        ImGui.TextWrapped("No topics match your search. Try a shorter word, such as share, bug, load, folder, backup, or Trash.")
      end

      ImGui.EndChild()
      ImGui.PopStyleColor(4)
    end
end

return _ENV
