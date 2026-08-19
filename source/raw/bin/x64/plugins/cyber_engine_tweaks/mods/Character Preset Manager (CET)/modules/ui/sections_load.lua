local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

drawLoadSection = function(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
helpers.syncForceFullLoadSelection()
if collapsibleSectionHeader("LOAD & RESTORE APPEARANCE", "load") then
    ImGui.TextColored(1.0, 1.0, 1.0, 1.0, "Select a preset to load")
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
    if state.library.searchText ~= previousSearchText then invalidateFilteredViewCache() end
    ImGui.PopItemWidth()
    if not narrowTopRow then ImGui.SameLine() end
    local clearSearchUnavailable = not tostring(state.library.searchText):match("%S")
    if clearSearchUnavailable then ImGui.BeginDisabled() end
    if ImGui.Button("Clear##presetSearchClear", searchButtonWidth, actionButtonHeight) then
      state.library.searchText = ""
      invalidateFilteredViewCache()
    end
    if clearSearchUnavailable then ImGui.EndDisabled() end
    ImGui.SameLine()
    if ImGui.Button("Refresh##presetRefresh", searchButtonWidth, actionButtonHeight) then
      local _, refreshed, changes = refreshPresets("external")
      refreshTrash()
      if state.library.selected and state.library.presets[state.library.selected] then
        state.library.presetNotes = state.library.presets[state.library.selected].notes or ""
        state.library.presetTags = state.library.presets[state.library.selected].tags or ""
      end
      refreshPreflight()
      local added = changes and changes.added or 0
      local removed = changes and changes.removed or 0
      local updated = changes and changes.modified or 0
      setStatus("load", refreshed
        and ("Refreshed: %d added, %d updated, %d removed; %d available.")
          :format(added, updated, removed, #helpers.sortedPresetNames())
        or "Refresh failed; the previous list was kept.", not refreshed)
    end
    ImGui.BeginChild("##presetList", 0, presetListHeight, true)
    local names = helpers.sortedPresetNames()
    ensureFilteredViewCache()
    local queryActive = state.cache.queryActive
    local matchedFolders = state.cache.matchedFolders
    if #names == 0 then
      ImGui.TextDisabled("No presets saved.")
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
          log(("[UI] Preset selection changed: old='%s' new='%s'.")
            :format(tostring(state.library.selected), name), "info")
          state.library.selected = name
          addFolderAncestors(state.library.expandedLoadFolders, parentFolder(name))
          state.invalidatePreflight()
          local selectedPreset = state.library.presets[name]
          state.library.presetNotes = selectedPreset and selectedPreset.notes or ""
          state.library.presetTags = selectedPreset and selectedPreset.tags or ""
          cancelConfirmations()
          state.library.renameName = ""
          resetLoadState()
          clearStatus("rename")
          clearStatus("delete")
          refreshPreflight()
        end
      end
      local visibleNames = {}
      for _, name in ipairs(helpers.filteredPresetNames()) do visibleNames[name] = true end
      local favoriteNames = {}
      for _, name in ipairs(names) do
        local preset = state.library.presets[name]
        if preset and preset.favorite == true and visibleNames[name] then
          table.insert(favoriteNames, name)
        end
      end
      if #favoriteNames > 0 then
        ImGui.TextColored(0.97, 0.72, 0.20, 1.0, "Favorites")
        for _, name in ipairs(favoriteNames) do
          drawPresetChoice(name, helpers.breadcrumb(name), ":favorite")
        end
        ImGui.Separator()
      end
      for _, folder in ipairs(sortedFolderNames()) do
        local folderPresets = helpers.presetsInFolder(folder)
        local subtreeCount = state.cache.folderPresetCounts[folder] or 0
        local folderMatches = state.cache.folderMatches[folder] == true
        local matchingPresets = state.cache.matchingPresetsByFolder[folder] or EMPTY_LIST
        local descendantMatches = matchedFolders[folder] == true
        if subtreeCount > 0 and (folderMatches or #matchingPresets > 0 or descendantMatches) then
          local expanded = state.library.expandedLoadFolders[folder] == true
          local folderKind = state.library.manualFolders[folder]
            and " (imported)" or ""
          ImGui.SetNextItemOpen(expanded or queryActive, ImGuiCond.Always)
          local treeFlags = 8 + 2048 + (expanded and 1 or 0)
          local nodeOpen = ImGui.TreeNodeEx(
            string.rep("  ", folderDepth(folder)) .. baseName(folder) ..
              (" (%d)"):format(subtreeCount) .. folderKind .. "##loadFolder:" .. folder,
            treeFlags)
          if not queryActive then
            state.library.expandedLoadFolders[folder] = nodeOpen
          end
          if nodeOpen then
            ImGui.Indent(12)
            for _, name in ipairs(folderMatches and folderPresets or matchingPresets) do
              drawPresetChoice(name, baseName(name))
            end
            ImGui.Unindent(12)
          end
        end
      end
      for _, name in ipairs(state.cache.matchingPresetsByFolder[""] or EMPTY_LIST) do
        drawPresetChoice(name, name)
      end
    end
    ImGui.EndChild()
    ImGui.Spacing()

    if state.load.preflightDirty or state.load.preflightPresetName ~= state.library.selected then
      refreshPreflight()
    end
    if state.library.selected and state.library.presets[state.library.selected] then
      local preset = state.library.presets[state.library.selected]
      ImGui.TextColored(0.97, 0.72, 0.20, 1.0, baseName(state.library.selected))
      coloredWrapped(0.64, 0.67, 0.73, 1.0,
        ("%s  |  %d options  |  Format %s")
        :format(helpers.breadcrumb(parentFolder(state.library.selected)), state.presetEntryCount(preset),
          tostring(preset.format or 4)))
      if state.load.preflight then
        local check = state.load.preflight
        local color = (check.ambiguous + check.invalid) > 0 and { 1.0, 0.4, 0.4 }
          or check.unavailable > 0 and { 1.0, 0.8, 0.2 } or { 0.3, 1.0, 0.4 }
        coloredWrapped(color[1], color[2], color[3], 1.0,
          ("Option check: %d found  |  %d missing  |  %d repeated  |  %d invalid")
            :format(check.available, check.unavailable, check.ambiguous, check.invalid))
      else
        ImGui.TextDisabled("Open a customization screen to check compatibility.")
      end
    end

    if compactSubsectionButton("Favorites & Details",
        "Hide Favorites & Details", "loadFavorites") then
      ImGui.Indent(8)
      local optionalPreset = state.library.selected
        and state.library.presets[state.library.selected]
      if optionalPreset then
        coloredWrapped(0.64, 0.67, 0.73, 1.0,
          ("Source: %s\nModified: %s")
            :format(tostring(optionalPreset.source or "Older or ACU preset"),
            tostring(optionalPreset.modified or "Unknown")))
        if optionalPreset.tags and optionalPreset.tags ~= "" then
          ImGui.TextWrapped("Tags: " .. optionalPreset.tags)
        end
        if optionalPreset.notes and optionalPreset.notes ~= "" then
          ImGui.TextWrapped("Notes: " .. optionalPreset.notes)
        end
        local favoriteLabel = optionalPreset.favorite == true
          and "Remove Selected Preset from Favorites##favoritePreset"
          or "Add Selected Preset to Favorites##favoritePreset"
        if fullWidthButton(favoriteLabel, actionButtonHeight) then
          toggleSelectedPresetFavorite()
        end
      else
        ImGui.TextDisabled("Select a preset to use Favorites or view its details.")
      end
      ImGui.Unindent(8)
    end

    local restoreFileAvailable = fileExists(LAST_APPEARANCE_FILE)
    local restoreUnavailable = not restoreFileAvailable or not state.app.inCustomization
      or state.load.auto or state.load.needsContinue
    if restoreUnavailable then ImGui.BeginDisabled() end
    if fullWidthButton("Restore Previous Appearance##restoreAppearance",
        actionButtonHeight) then
      restoreLastAppearance()
    end
    if restoreUnavailable then ImGui.EndDisabled() end
    if not restoreFileAvailable then
      ImGui.TextDisabled("This becomes available after the first normal preset load.")
    elseif not state.app.inCustomization then
      ImGui.TextDisabled("Open a customization screen to restore the previous appearance.")
    end

    if state.load.auto then ImGui.BeginDisabled() end
    local forceLoadLabel = state.load.forceFull
      and "Force Full Load: On##forceFullLoad"
      or "Force Full Load: Off##forceFullLoad"
    if fullWidthButton(forceLoadLabel, actionButtonHeight) then
      state.load.forceFull = not state.load.forceFull
      resetLoadState()
      state.invalidatePreflight()
      refreshPreflight()
      log(("[UI] Force Full Load toggled %s.")
        :format(state.load.forceFull and "on" or "off"), "info")
    end
    if state.load.auto then ImGui.EndDisabled() end
    if state.load.forceFull then
      local selectedPreset = state.library.selected
        and state.library.presets[state.library.selected]
      local selectedFormat = selectedPreset and tonumber(selectedPreset.format) or 4
      if selectedFormat >= 7 then
        coloredWrapped(1.0, 0.8, 0.2, 1.0,
          "Force Full Load will try saved editor positions. Check the appearance after loading.")
      else
        coloredWrapped(1.0, 0.4, 0.4, 1.0,
          "Older preset: added options may change the hair or color. Check the appearance after loading.")
      end
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
      if not state.load.needsContinue then
        resetLoadState()
      end
      state.load.autoTimer = 0
      state.load.autoPasses = 0
      state.load.resetBefore = true
      loadPreset()
      if state.load.needsContinue then state.load.auto = true end
    end
    if loadButtonDisabled then ImGui.EndDisabled() end
    if state.load.auto or state.load.needsContinue then
      if dangerButton("Cancel Loading##cancelLoad", ImGui.GetContentRegionAvail(), actionButtonHeight) then
        cancelLoading()
      end
    elseif loadUnavailable then
      ImGui.TextDisabled(not state.library.selected and "Select a preset to enable loading."
        or "Open a customization screen to enable loading.")
    end
    drawSectionStatus("load", "##loadStatus", statusHeight)
    end
end

return _ENV
