local runtime = require("modules.runtime") or CPMRuntime
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

drawLoadSection = function(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
if collapsibleSectionHeader("LOAD PRESET", "load") then
    ImGui.TextColored(1.0, 1.0, 1.0, 1.0, "Select a preset to load")
    ImGui.Spacing()
    local searchRowWidth = ImGui.GetContentRegionAvail()
    local searchButtonWidth = narrowTopRow and 48 or 64
    ImGui.PushItemWidth(math.max(80, searchRowWidth - searchButtonWidth * 2 - 16))
    local previousSearchText = state.searchText
    state.searchText = ImGui.InputTextWithHint(
      "##presetSearch", "Search presets, folders, or tags", state.searchText, 65)
    if state.searchText ~= previousSearchText then invalidateFilteredViewCache() end
    ImGui.PopItemWidth()
    ImGui.SameLine()
    local clearSearchUnavailable = not tostring(state.searchText):match("%S")
    if clearSearchUnavailable then ImGui.BeginDisabled() end
    if ImGui.Button("Clear##presetSearchClear", searchButtonWidth, actionButtonHeight) then
      state.searchText = ""
      invalidateFilteredViewCache()
    end
    if clearSearchUnavailable then ImGui.EndDisabled() end
    ImGui.SameLine()
    if ImGui.Button("Refresh##presetRefresh", searchButtonWidth, actionButtonHeight) then
      local _, refreshed, changes = refreshPresets("external")
      refreshTrash()
      if state.selected and state.presets[state.selected] then
        state.presetNotes = state.presets[state.selected].notes or ""
        state.presetTags = state.presets[state.selected].tags or ""
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
    local queryActive = state.cachedQueryActive
    local matchedFolders = state.cachedMatchedFolders
    if #names == 0 then
      ImGui.TextDisabled("No presets saved.")
    else
      local function drawPresetChoice(name, label)
        local preset = state.presets[name]
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
        if ImGui.Selectable(displayLabel .. "##preset:" .. name, state.selected == name)
            and state.selected ~= name then
          log(("[UI] Preset selection changed: old='%s' new='%s'.")
            :format(tostring(state.selected), name), "info")
          state.selected = name
          addFolderAncestors(state.expandedLoadFolders, parentFolder(name))
          state.invalidatePreflight()
          local selectedPreset = state.presets[name]
          state.presetNotes = selectedPreset and selectedPreset.notes or ""
          state.presetTags = selectedPreset and selectedPreset.tags or ""
          cancelConfirmations()
          state.renameName = ""
          resetLoadState()
          clearStatus("rename")
          clearStatus("delete")
          refreshPreflight()
        end
      end
      for _, folder in ipairs(sortedFolderNames()) do
        local folderPresets = helpers.presetsInFolder(folder)
        local subtreeCount = state.cachedFolderPresetCounts[folder] or 0
        local folderMatches = state.cachedFolderMatches[folder] == true
        local matchingPresets = state.cachedMatchingPresetsByFolder[folder] or EMPTY_LIST
        local descendantMatches = matchedFolders[folder] == true
        if subtreeCount > 0 and (folderMatches or #matchingPresets > 0 or descendantMatches) then
          local expanded = state.expandedLoadFolders[folder] == true
          local folderKind = state.manualFolders[folder]
            and " (imported)" or ""
          ImGui.SetNextItemOpen(expanded or queryActive, ImGuiCond.Always)
          local treeFlags = 8 + 2048 + (expanded and 1 or 0)
          local nodeOpen = ImGui.TreeNodeEx(
            string.rep("  ", folderDepth(folder)) .. baseName(folder) ..
              (" (%d)"):format(subtreeCount) .. folderKind .. "##loadFolder:" .. folder,
            treeFlags)
          if not queryActive then
            state.expandedLoadFolders[folder] = nodeOpen
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
      for _, name in ipairs(state.cachedMatchingPresetsByFolder[""] or EMPTY_LIST) do
        drawPresetChoice(name, name)
      end
    end
    ImGui.EndChild()
    ImGui.Spacing()

    if state.preflightDirty or state.preflightPresetName ~= state.selected then
      refreshPreflight()
    end
    if state.selected and state.presets[state.selected] then
      local preset = state.presets[state.selected]
      ImGui.TextColored(0.97, 0.72, 0.20, 1.0, baseName(state.selected))
      coloredWrapped(0.64, 0.67, 0.73, 1.0,
        ("%s  |  %d options  |  Format %s")
        :format(helpers.breadcrumb(parentFolder(state.selected)), state.presetEntryCount(preset),
          tostring(preset.format or 4)))
      if state.preflight then
        local check = state.preflight
        local color = (check.ambiguous + check.invalid) > 0 and { 1.0, 0.4, 0.4 }
          or check.unavailable > 0 and { 1.0, 0.8, 0.2 } or { 0.3, 1.0, 0.4 }
        coloredWrapped(color[1], color[2], color[3], 1.0,
          ("Option check: %d found  |  %d missing  |  %d repeated  |  %d invalid")
            :format(check.available, check.unavailable, check.ambiguous, check.invalid))
      else
        ImGui.TextDisabled("Open a customization screen to check compatibility.")
      end
      if compactSubsectionButton("More Preset Info", "Hide Preset Info", "loadDetails") then
        ImGui.Indent(8)
        coloredWrapped(0.64, 0.67, 0.73, 1.0,
          ("Source: %s\nModified: %s")
            :format(tostring(preset.source or "Older or ACU preset"),
            tostring(preset.modified or "Unknown")))
        if preset.tags and preset.tags ~= "" then ImGui.TextWrapped("Tags: " .. preset.tags) end
        if preset.notes and preset.notes ~= "" then ImGui.TextWrapped("Notes: " .. preset.notes) end
        ImGui.Unindent(8)
      end
    end

    if state.autoLoad then ImGui.BeginDisabled() end
    local forceLoadLabel = state.forceFullLoad
      and "Force Full Load: On##forceFullLoad"
      or "Force Full Load: Off##forceFullLoad"
    if fullWidthButton(forceLoadLabel, actionButtonHeight) then
      state.forceFullLoad = not state.forceFullLoad
      resetLoadState()
      state.invalidatePreflight()
      refreshPreflight()
      log(("[UI] Force Full Load toggled %s.")
        :format(state.forceFullLoad and "on" or "off"), "info")
    end
    if state.autoLoad then ImGui.EndDisabled() end
    if state.forceFullLoad then
      local selectedFormat = state.selected and state.presets[state.selected]
        and tonumber(state.presets[state.selected].format) or 4
      if selectedFormat >= 7 then
        coloredWrapped(1.0, 0.8, 0.2, 1.0,
          "Force Full Load will try saved editor positions. Check the appearance after loading.")
      else
        coloredWrapped(1.0, 0.4, 0.4, 1.0,
          "Older preset: added options may change the hair or color. Check the appearance after loading.")
      end
    end

    local loadUnavailable = not state.selected or not state.inCustomization
    local loadLabel
    if state.autoLoad then
      loadLabel = ("Loading... (pass %d)"):format(state.loadPass)
    elseif state.loadNeedsContinue then
      loadLabel = ("Continue Loading Preset (%d remaining)"):format(state.loadRemaining)
    else
      loadLabel = "Load Selected Preset"
    end
    local loadButtonDisabled = loadUnavailable or state.autoLoad
    if loadButtonDisabled then ImGui.BeginDisabled() end
    if fullWidthButton(loadLabel .. "##loadPreset", actionButtonHeight) then
      if not state.loadNeedsContinue then
        resetLoadState()
      end
      state.autoLoadTimer = 0
      state.autoLoadPasses = 0
      state.resetBeforeLoad = true
      loadPreset()
      if state.loadNeedsContinue then state.autoLoad = true end
    end
    if loadButtonDisabled then ImGui.EndDisabled() end
    if state.autoLoad or state.loadNeedsContinue then
      if dangerButton("Cancel Loading##cancelLoad", ImGui.GetContentRegionAvail(), actionButtonHeight) then
        cancelLoading()
      end
    elseif loadUnavailable then
      ImGui.TextDisabled(not state.selected and "Select a preset to enable loading."
        or "Open a customization screen to enable loading.")
    end
    drawSectionStatus("load", "##loadStatus", statusHeight)
    end
end

return _ENV
