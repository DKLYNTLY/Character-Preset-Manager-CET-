local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime
local commands = require("modules/ui/commands")

drawLoadSection = function(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
helpers.syncForceFullLoadSelection()
if collapsibleSectionHeader("LOAD & RESTORE APPEARANCE", "load") then
    ImGui.TextColored(1.0, 1.0, 1.0, 1.0, "Select a preset to load")
    local names = helpers.sortedPresetNames()
    local selectedPreset = state.library.selected
      and state.library.presets[state.library.selected]
    local loadStatus, loadStatusKind
    if #names == 0 then
      loadStatus = "Save or install a preset before loading an appearance."
      loadStatusKind = "info"
    elseif not state.library.selected then
      loadStatus = "Select a preset to enable loading."
      loadStatusKind = "info"
    elseif not state.app.inCustomization then
      loadStatus = "Open new-game creation, the full editor, a mirror, or a supported ripperdoc to load this preset."
      loadStatusKind = "info"
    else
      local messages = {}
      local check = state.load.preflight
      if check then
        messages[#messages + 1] =
          ("Option check: %d found, %d missing, %d repeated, %d invalid.")
            :format(check.available, check.unavailable, check.ambiguous, check.invalid)
        if check.ambiguous + check.invalid > 0 then
          loadStatusKind = "critical_warning"
        elseif check.unavailable > 0 then
          loadStatusKind = "warning"
        else
          loadStatusKind = "ready"
        end
      end
      if state.load.forceFull then
        local forceWarning, forceWarningKind = helpers.forceFullLoadWarning(selectedPreset)
        messages[#messages + 1] = forceWarning
        if forceWarningKind == "critical_warning" or loadStatusKind ~= "critical_warning" then
          loadStatusKind = forceWarningKind
        end
      end
      if #messages == 0 then
        messages[1] = ("Ready to load %s."):format(state.library.selected)
        loadStatusKind = "ready"
      end
      loadStatus = table.concat(messages, " ")
    end
    local loadContext = #names == 0
      and "Available presets: 0"
      or "Selected preset: " .. tostring(state.library.selected or "None")
    drawSectionStatus("load", "##loadStatus", statusHeight, loadStatus,
      loadStatusKind, loadContext)
    ImGui.Spacing()
    local searchRowWidth = ImGui.GetContentRegionAvail()
    local searchButtonWidth = narrowTopRow
      and math.max(80, (searchRowWidth - 8) * 0.5) or 64
    local searchInputWidth = narrowTopRow
      and searchRowWidth or math.max(80, searchRowWidth - searchButtonWidth * 2 - 16)
    ImGui.PushItemWidth(searchInputWidth)
    local previousSearchText = state.library.searchText
    state.library.searchText = ImGui.InputTextWithHint(
      "##presetSearch", "Search presets, folders, or tags", state.library.searchText, 65)
    if state.library.searchText ~= previousSearchText then
      commands.run(runtime, "filter")
    end
    ImGui.PopItemWidth()
    if not narrowTopRow then ImGui.SameLine() end
    local clearSearchUnavailable = not tostring(state.library.searchText):match("%S")
    if clearSearchUnavailable then ImGui.BeginDisabled() end
    if ImGui.Button("Clear##presetSearchClear", searchButtonWidth, actionButtonHeight) then
      commands.run(runtime, "clear_filter")
    end
    if clearSearchUnavailable then ImGui.EndDisabled() end
    ImGui.SameLine()
    if ImGui.Button("Refresh##presetRefresh", searchButtonWidth, actionButtonHeight) then
      commands.run(runtime, "refresh")
    end
    local refreshOptionsUnavailable = not state.app.inCustomization
      or state.load.auto or state.load.needsContinue or state.load.pendingChange
    if refreshOptionsUnavailable then ImGui.BeginDisabled() end
    if fullWidthButton("Refresh options##refreshOptionCatalog", actionButtonHeight) then
      commands.run(runtime, "refresh_options")
    end
    if refreshOptionsUnavailable then ImGui.EndDisabled() end
    ensureFilteredViewCache()
    local queryActive = state.cache.queryActive
    local matchedFolders = state.cache.matchedFolders
    local loadRows = {}
    local visibleNames = {}
    for _, name in ipairs(helpers.filteredPresetNames()) do visibleNames[name] = true end
    local favoriteHeadingAdded = false
    for _, name in ipairs(names) do
      local preset = state.library.presets[name]
      if preset and preset.favorite == true and visibleNames[name] then
        if not favoriteHeadingAdded then
          loadRows[#loadRows + 1] = { kind = "heading", label = "Favorites" }
          favoriteHeadingAdded = true
        end
        loadRows[#loadRows + 1] = {
          kind = "preset", name = name, label = helpers.breadcrumb(name), suffix = ":favorite"
        }
      end
    end
    for _, folder in ipairs(sortedFolderNames()) do
      local folderPresets = helpers.presetsInFolder(folder)
      local subtreeCount = state.cache.folderPresetCounts[folder] or 0
      local folderMatches = state.cache.folderMatches[folder] == true
      local matchingPresets = state.cache.matchingPresetsByFolder[folder] or EMPTY_LIST
      local descendantMatches = matchedFolders[folder] == true
      local parentVisible = queryActive
        or folderAncestorsExpanded(folder, state.library.expandedLoadFolders)
      if subtreeCount > 0 and parentVisible
          and (folderMatches or #matchingPresets > 0 or descendantMatches) then
        local expanded = state.library.expandedLoadFolders[folder] == true
        loadRows[#loadRows + 1] = {
          kind = "folder", folder = folder, count = subtreeCount, expanded = expanded
        }
        if expanded or queryActive then
          for _, name in ipairs(folderMatches and folderPresets or matchingPresets) do
            loadRows[#loadRows + 1] = {
              kind = "preset", name = name, label = baseName(name)
            }
          end
        end
      end
    end
    for _, name in ipairs(state.cache.matchingPresetsByFolder[""] or EMPTY_LIST) do
      loadRows[#loadRows + 1] = { kind = "preset", name = name, label = name }
    end
    drawPageControls("loadPresets", #loadRows, UI_LIST_PAGE_SIZE, "Presets")
    ImGui.BeginChild("##presetList", 0, presetListHeight, true)
    if #names == 0 then
      ImGui.TextWrapped("No presets saved.")
    else
      local function drawPresetChoice(name, label, idSuffix)
        local preset = state.library.presets[name]
        local tags = tostring(preset and preset.tags or "")
        local displayLabel = label
        if tags ~= "" then
          local maximumRowLength = narrowTopRow and 46 or 72
          local availableTagLength = math.max(8, maximumRowLength - #label - 5)
          if #tags > availableTagLength then
            tags = tags:sub(1, availableTagLength - 3) .. "..."
          end
          displayLabel = label .. "  -  " .. tags
        end
        if ImGui.Selectable(displayLabel .. "##preset:" .. name .. tostring(idSuffix or ""),
            state.library.selected == name)
            and state.library.selected ~= name then
          commands.run(runtime, "select", {name = name})
        end
      end
      local firstRow, lastRow = pagedRange("loadPresets",
        #loadRows, UI_LIST_PAGE_SIZE)
      for index = firstRow, lastRow do
        local row = loadRows[index]
        if row.kind == "heading" then
          ImGui.TextColored(0.97, 0.72, 0.20, 1.0, row.label)
        elseif row.kind == "preset" then
          drawPresetChoice(row.name, row.label, row.suffix)
        else
          local folder = row.folder
          local expanded = row.expanded
          local folderKind = state.library.manualFolders[folder]
            and " (imported)" or ""
          local depth = folderDepth(folder)
          local branch = depth > 0
            and string.rep("  ", depth - 1) .. "> " or ""
          ImGui.SetNextItemOpen(expanded or queryActive, ImGuiCond.Always)
          local treeFlags = 8 + 2048 + (expanded and 1 or 0)
          if depth > 0 then
            ImGui.PushStyleColor(ImGuiCol.Text, 0.97, 0.72, 0.20, 1.0)
          else
            ImGui.PushStyleColor(ImGuiCol.Text, 0.22, 0.92, 1.0, 1.0)
          end
          local nodeOpen = ImGui.TreeNodeEx(
            branch .. baseName(folder) ..
              (" (%d)"):format(row.count) .. folderKind .. "##loadFolder:" .. folder,
            treeFlags)
          ImGui.PopStyleColor(1)
          if not queryActive then
            state.library.expandedLoadFolders[folder] = nodeOpen
          end
        end
      end
    end
    ImGui.EndChild()
    ImGui.Spacing()

    if state.library.selected and state.library.presets[state.library.selected] then
      local preset = state.library.presets[state.library.selected]
      coloredWrapped(0.97, 0.72, 0.20, 1.0,
        ("%s  |  %s  |  %d options  |  Format %s")
          :format(baseName(state.library.selected),
          helpers.breadcrumb(parentFolder(state.library.selected)),
          state.presetEntryCount(preset), tostring(preset.format or 4)))
    end

    local loadUnavailable = not state.library.selected or not state.app.inCustomization
    local loadLabel
    if state.load.auto then
      loadLabel = ("Loading... (pass %d)"):format(state.load.pass)
    elseif state.load.needsContinue then
      loadLabel = ("Continue Loading Preset (%d remaining)"):format(state.load.remaining)
    else
      loadLabel = "Load Selected Preset"
    end
    local loadButtonDisabled = loadUnavailable or state.load.auto
    if loadButtonDisabled then ImGui.BeginDisabled() end
    if fullWidthButton(loadLabel .. "##loadPreset", actionButtonHeight) then
      commands.run(runtime, "load")
    end
    if loadButtonDisabled then ImGui.EndDisabled() end
    local restoreFileAvailable = state.load.recoverySnapshotAvailable == true
    local restoreUnavailable = not restoreFileAvailable or not state.app.inCustomization
      or state.load.auto or state.load.needsContinue
    if restoreUnavailable then ImGui.BeginDisabled() end
    if fullWidthButton("Restore Previous Appearance##restoreAppearance",
        actionButtonHeight) then
      commands.run(runtime, "restore_previous")
    end
    if restoreUnavailable then ImGui.EndDisabled() end

    if compactSubsectionButton("Appearance History",
        "Hide Appearance History", "appearanceHistory") then
      ImGui.Indent(8)
      local historyEntries = state.history.entries
      if #historyEntries == 0 then
        ImGui.TextWrapped("There are no recovery entries yet. One is saved before each normal preset load.")
      else
        ImGui.TextWrapped("Choose the appearance you want to restore. The latest saved entry appears at the top.")
        for visibleIndex, entry in ipairs(historyEntries) do
          local label = ("Restore %d: %s | %d options | %s##appearanceHistory:%d")
            :format(visibleIndex, tostring(entry.date), tonumber(entry.count) or 0,
              tostring(entry.action), visibleIndex)
          local unavailable = not state.app.inCustomization
            or state.load.auto or state.load.needsContinue
          if unavailable then ImGui.BeginDisabled() end
          if fullWidthButton(label, actionButtonHeight) then
            commands.run(runtime, "restore_history", {visibleIndex = visibleIndex})
          end
          if unavailable then ImGui.EndDisabled() end
        end
        local clearLabel = state.history.pendingClear
          and "Confirm Clear Appearance History##clearAppearanceHistory"
          or "Clear Appearance History##clearAppearanceHistory"
        if dangerButton(clearLabel, ImGui.GetContentRegionAvail(), actionButtonHeight) then
          commands.run(runtime, "clear_history")
        end
      end
      finishCompactSubsection()
    end

    if compactSubsectionButton("Advanced Preset Options",
        "Hide Advanced Preset Options", "loadFavorites") then
      ImGui.Indent(8)
      local optionalPreset = state.library.selected
        and state.library.presets[state.library.selected]
      if optionalPreset then
        local compatibilityUnavailable = not state.app.inCustomization
          or state.load.auto or state.load.needsContinue
        if compatibilityUnavailable then ImGui.BeginDisabled() end
        if fullWidthButton("Check Compatibility##checkCompatibility",
            actionButtonHeight) then
          commands.run(runtime, "compare")
        end
        if compatibilityUnavailable then ImGui.EndDisabled() end
        if state.load.auto then ImGui.BeginDisabled() end
        local forceLoadLabel = state.load.forceFull
          and "Force Full Load: On##forceFullLoad"
          or "Force Full Load: Off##forceFullLoad"
        if fullWidthButton(forceLoadLabel, actionButtonHeight) then
          commands.run(runtime, "force_full")
        end
        if state.load.auto then ImGui.EndDisabled() end
        local favoriteLabel = optionalPreset.favorite == true
          and "Remove Selected Preset from Favorites##favoritePreset"
          or "Add Selected Preset to Favorites##favoritePreset"
        if fullWidthButton(favoriteLabel, actionButtonHeight) then
          commands.run(runtime, "favorite")
        end
      end
      finishCompactSubsection()
    end

    end
end

return _ENV
