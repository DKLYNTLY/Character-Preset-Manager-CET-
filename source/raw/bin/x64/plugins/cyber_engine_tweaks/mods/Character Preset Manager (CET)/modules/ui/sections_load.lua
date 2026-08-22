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
    if state.library.searchText ~= previousSearchText then
      invalidateFilteredViewCache()
      state.ui.listPages.loadPresets = 1
    end
    ImGui.PopItemWidth()
    if not narrowTopRow then ImGui.SameLine() end
    local clearSearchUnavailable = not tostring(state.library.searchText):match("%S")
    if clearSearchUnavailable then ImGui.BeginDisabled() end
    if ImGui.Button("Clear##presetSearchClear", searchButtonWidth, actionButtonHeight) then
      state.library.searchText = ""
      invalidateFilteredViewCache()
      state.ui.listPages.loadPresets = 1
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
      local added = changes and changes.added or 0
      local removed = changes and changes.removed or 0
      local updated = changes and changes.modified or 0
      setStatus("load", refreshed
        and ("Refreshed: %d added, %d updated, %d removed; %d available.")
          :format(added, updated, removed, #helpers.sortedPresetNames())
        or "Refresh failed; the previous list was kept.", not refreshed)
    end
    local names = helpers.sortedPresetNames()
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
      if subtreeCount > 0 and (folderMatches or #matchingPresets > 0 or descendantMatches) then
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
          log(("[UI] Preset selection changed: old='%s' new='%s'.")
            :format(tostring(state.library.selected), name), "info")
          state.library.selected = name
          addFolderAncestors(state.library.expandedLoadFolders, parentFolder(name))
          state.invalidatePreflight()
          local selectedPreset = hydrateNamedPresetMetadata(name)
            or state.library.presets[name]
          state.library.presetNotes = selectedPreset and selectedPreset.notes or ""
          state.library.presetTags = selectedPreset and selectedPreset.tags or ""
          invalidateFilteredViewCache()
          cancelConfirmations()
          state.library.renameName = ""
          resetLoadState()
          clearStatus("load")
          clearStatus("rename")
          clearStatus("delete")
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
          ImGui.SetNextItemOpen(expanded or queryActive, ImGuiCond.Always)
          local treeFlags = 8 + 2048 + (expanded and 1 or 0)
          local nodeOpen = ImGui.TreeNodeEx(
            string.rep("  ", folderDepth(folder)) .. baseName(folder) ..
              (" (%d)"):format(row.count) .. folderKind .. "##loadFolder:" .. folder,
            treeFlags)
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
      ImGui.TextColored(0.97, 0.72, 0.20, 1.0,
        "Preset: " .. baseName(state.library.selected))
      coloredWrapped(1.0, 1.0, 1.0, 1.0,
        ("Folder: %s\nSaved options: %d")
        :format(helpers.breadcrumb(parentFolder(state.library.selected)),
          state.presetEntryCount(preset)))
    end

    if compactSubsectionButton("Preset Options",
        "Hide Preset Options", "loadFavorites") then
      ImGui.Indent(8)
      local optionalPreset = state.library.selected
        and state.library.presets[state.library.selected]
      if optionalPreset then
        local compatibilityUnavailable = not state.app.inCustomization
          or state.load.auto or state.load.needsContinue
        if compatibilityUnavailable then ImGui.BeginDisabled() end
        if fullWidthButton("Check Compatibility##checkCompatibility",
            actionButtonHeight) then
          clearStatus("load")
          state.invalidatePreflight()
          log(("[UI] Compatibility check requested for '%s'.")
            :format(state.library.selected), "info")
          refreshPreflight()
        end
        if compatibilityUnavailable then ImGui.EndDisabled() end
        coloredWrapped(1.0, 1.0, 1.0, 1.0,
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
        ImGui.TextWrapped("Select a preset to check compatibility or use its options.")
      end
      ImGui.Unindent(8)
    end

    if state.load.auto then ImGui.BeginDisabled() end
    local forceLoadLabel = state.load.forceFull
      and "Force Full Load: On##forceFullLoad"
      or "Force Full Load: Off##forceFullLoad"
    if fullWidthButton(forceLoadLabel, actionButtonHeight) then
      state.load.forceFull = not state.load.forceFull
      resetLoadState()
      state.invalidatePreflight()
      clearStatus("load")
      log(("[UI] Force Full Load toggled %s.")
        :format(state.load.forceFull and "on" or "off"), "info")
    end
    if state.load.auto then ImGui.EndDisabled() end
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
    end
    local restoreFileAvailable = state.load.recoverySnapshotAvailable == true
    local restoreUnavailable = not restoreFileAvailable or not state.app.inCustomization
      or state.load.auto or state.load.needsContinue
    if restoreUnavailable then ImGui.BeginDisabled() end
    if fullWidthButton("Restore Previous Appearance##restoreAppearance",
        actionButtonHeight) then
      restoreLastAppearance()
    end
    if restoreUnavailable then ImGui.EndDisabled() end

    local selectedPreset = state.library.selected
      and state.library.presets[state.library.selected]
    local loadStatus, loadStatusKind
    if #names == 0 then
      loadStatus = "Save a preset before trying to load an appearance."
      loadStatusKind = "info"
    elseif not state.library.selected then
      loadStatus = "Select a preset to enable loading."
      loadStatusKind = "info"
    elseif not state.app.inCustomization then
      loadStatus = "Open the character creator, a mirror, or a ripperdoc to load the selected preset."
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
    drawSectionStatus("load", "##loadStatus", statusHeight, loadStatus,
      loadStatusKind)
    end
end

return _ENV
