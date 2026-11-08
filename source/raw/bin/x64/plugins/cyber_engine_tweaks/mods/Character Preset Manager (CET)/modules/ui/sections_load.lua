local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime
local commands = require("modules/ui/commands")

drawLoadSection = function(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
helpers.syncForceFullLoadSelection()
if collapsibleSectionHeader("ADVANCED PRESET MANAGER", "load") then
    ImGui.TextColored(1.0, 1.0, 1.0, 1.0, "Select a preset to load")
    local body=helpers.editorBody()
    local names = {}
    for _,name in ipairs(helpers.sortedPresetNames()) do
      if helpers.presetVisibleForBody(state.library.presets[name],body) then names[#names+1]=name end
    end
    local selectedPreset = state.library.selected
      and state.library.presets[state.library.selected]
    ImGui.Spacing()
    ImGui.PushItemWidth(-1)
    local previousSearchText=state.library.searchText
    state.library.searchText=ImGui.InputTextWithHint("##presetSearch","Search presets, folders, or tags",state.library.searchText,65)
    if state.library.searchText~=previousSearchText then commands.run(runtime,"filter") end
    ImGui.PopItemWidth()
    local emptySearch=not tostring(state.library.searchText):match("%S")
    if emptySearch then ImGui.BeginDisabled() end
    if fullWidthButton("Clear Search##presetSearchClear",actionButtonHeight) then commands.run(runtime,"clear_filter") end
    if emptySearch then ImGui.EndDisabled() end
    if fullWidthButton("Refresh##presetRefresh",actionButtonHeight) then commands.run(runtime,"refresh") end
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
    for _, name in ipairs(helpers.filteredPresetNames()) do
      if helpers.presetVisibleForBody(state.library.presets[name],body) then visibleNames[name] = true end
    end
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
      local parentVisible = state.ui.multiplePresets or queryActive
        or folderAncestorsExpanded(folder, state.library.expandedLoadFolders)
      if subtreeCount > 0 and parentVisible
          and (folderMatches or #matchingPresets > 0 or descendantMatches) then
        local expanded = state.library.expandedLoadFolders[folder] == true
        loadRows[#loadRows + 1] = {
          kind = "folder", folder = folder, count = subtreeCount, expanded = expanded
        }
        if expanded or queryActive or state.ui.multiplePresets then
          for _, name in ipairs(folderMatches and folderPresets or matchingPresets) do
            if helpers.presetVisibleForBody(state.library.presets[name],body) then
              loadRows[#loadRows + 1] = {kind="preset",name=name,label=baseName(name)}
            end
          end
        end
      end
    end
    for _, name in ipairs(state.cache.matchingPresetsByFolder[""] or EMPTY_LIST) do
      if helpers.presetVisibleForBody(state.library.presets[name],body) then
        loadRows[#loadRows + 1] = { kind = "preset", name = name, label = name }
      end
    end
    if state.ui.multiplePresets then
      local visibleBulkNames, seenBulkNames = {}, {}
      for _,name in ipairs(names) do
        if visibleNames[name] and not seenBulkNames[name] then
          seenBulkNames[name]=true
          visibleBulkNames[#visibleBulkNames+1]=name
        end
      end
      state.ui.visibleBulkNames = visibleBulkNames
      ImGui.TextWrapped(("Selected presets: %d"):format(#selectedBulkPresetNames()))
      if fullWidthButton("Select All Visible##managerSelectAll", actionButtonHeight) then
        commands.run(runtime, "bulk_select_visible", {visibleNames=visibleBulkNames})
      end
      if fullWidthButton("Clear Selection##managerClearAll", actionButtonHeight) then
        commands.run(runtime, "bulk_clear", {selectedBulkNames=selectedBulkPresetNames()})
      end
    end
    drawPageControls("loadPresets", #loadRows, UI_LIST_PAGE_SIZE, "Presets")
    ImGui.BeginChild("##presetList", 0, presetListHeight, true)
    if #names == 0 then
      ImGui.TextWrapped("No presets saved.")
    else
      local function drawPresetChoice(name, label, idSuffix)
        local preset = state.library.presets[name]
        local tags = tostring(preset and preset.tags or "")
        local displayLabel = helpers.presetBodyLabel(preset,label)
        if tags ~= "" then
          local maximumRowLength = narrowTopRow and 46 or 72
          local availableTagLength = math.max(8, maximumRowLength - #label - 5)
          if #tags > availableTagLength then
            tags = tags:sub(1, availableTagLength - 3) .. "..."
          end
          displayLabel = displayLabel .. "  -  " .. tags
        end
        local selected = state.ui.multiplePresets and state.trash.bulkSelected[name] == true
          or not state.ui.multiplePresets and state.library.selected == name
        if state.ui.multiplePresets then displayLabel = (selected and "[Selected] " or "[ ] ") .. displayLabel end
        if ImGui.Selectable(displayLabel .. "##preset:" .. name .. tostring(idSuffix or ""), selected) then
          if state.ui.multiplePresets then
            commands.run(runtime, "bulk_select", {name=name,selectedForBulk=selected})
          elseif state.library.selected ~= name then
            commands.run(runtime, "select", {name=name})
          end
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
          ImGui.SetNextItemOpen(expanded or queryActive or state.ui.multiplePresets, ImGuiCond.Always)
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
          if not queryActive and not state.ui.multiplePresets then
            state.library.expandedLoadFolders[folder] = nodeOpen
          end
        end
      end
    end
    ImGui.EndChild()
    ImGui.Spacing()

    if not state.ui.multiplePresets then
    if state.library.selected and state.library.presets[state.library.selected] then
      local preset = state.library.presets[state.library.selected]
      coloredWrapped(0.97, 0.72, 0.20, 1.0,
        ("%s  |  %s  |  %d options  |  Format %s | %s")
          :format(baseName(state.library.selected),
          helpers.breadcrumb(parentFolder(state.library.selected)),
          state.presetEntryCount(preset), tostring(preset.format or 4),helpers.presetBody(preset)))
    end

    if state.load.preflight then
      local check=state.load.preflight
      ImGui.TextWrapped(("Option check: %d found, %d missing, %d repeated, %d invalid.")
        :format(check.available,check.unavailable,check.ambiguous,check.invalid))
    end
    local migration=helpers.presetMigration
    if migration then
      local heading=false
      for _,item in ipairs(migration.rows()) do
        if item.phase=="body" then
          if not heading then
            ImGui.TextWrapped("Presets needing a body type")
            ImGui.TextWrapped("Choose the body this preset was saved for. Voice and file names do not determine it.")
            heading=true
          end
          ImGui.TextWrapped(helpers.breadcrumb(item.name))
          local busy=state.load.auto or state.load.needsContinue or state.load.pendingChange
          if busy then ImGui.BeginDisabled() end
          if fullWidthButton("Male##upgradeBodyMale:"..item.storage,actionButtonHeight) then migration.assignBody(item.name,"Male") end
          if fullWidthButton("Female##upgradeBodyFemale:"..item.storage,actionButtonHeight) then migration.assignBody(item.name,"Female") end
          if busy then ImGui.EndDisabled() end
        end
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
      commands.run(runtime, "load")
    end
    if loadButtonDisabled then ImGui.EndDisabled() end
    local restoreUnavailable = not state.load.recoverySnapshotAvailable or not state.app.inCustomization
      or state.load.auto or state.load.needsContinue
    if restoreUnavailable then ImGui.BeginDisabled() end
    if not restoreUnavailable then ImGui.PushStyleColor(ImGuiCol.Text,1.0,0.8,0.2,1.0) end
    if fullWidthButton("Undo Last Load##restoreAppearance",actionButtonHeight) then commands.run(runtime,"restore_previous") end
    if not restoreUnavailable then ImGui.PopStyleColor(1) end
    if restoreUnavailable then ImGui.EndDisabled() end
    if not state.library.selected then ImGui.BeginDisabled() end
    local deleteLabel = state.trash.pendingDeleteName == state.library.selected and state.library.selected
      and "Confirm Move to Trash##managerTrash" or "Move Selected Preset to Trash##managerTrash"
    if dangerButton(deleteLabel,ImGui.GetContentRegionAvail(),actionButtonHeight) then commands.run(runtime,"delete") end
    if not state.library.selected then ImGui.EndDisabled() end
    local randomizerAvailable = canRunAppearanceRandomizer()
    if not randomizerAvailable then ImGui.BeginDisabled() end
    if fullWidthButton("Randomize##appearanceRandomize", actionButtonHeight) then
      commands.run(runtime, "randomize", {available = randomizerAvailable})
    end
    if not randomizerAvailable then ImGui.EndDisabled() end
    ImGui.Spacing()
    drawSaveSection(presetListHeight,statusHeight,actionButtonHeight,extraHeight,narrowTopRow)
    if compactSubsectionButton("Advanced Preset Options",
        "Hide Advanced Preset Options", "loadFavorites") then
      ImGui.Indent(8)
      local randomizerAvailable = canRunAppearanceRandomizer()
      if not randomizerAvailable then ImGui.BeginDisabled() end
      if fullWidthButton("Randomize Settings##appearanceRandomizeSettings", actionButtonHeight) then
        commands.run(runtime, "randomize_settings", {available = randomizerAvailable})
      end
      if not randomizerAvailable then ImGui.EndDisabled() end
      if state.editor.pendingRandomizeSettings then
        ImGui.TextWrapped("Close CET to open the game's Randomize Settings.")
      end
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
        if state.load.forceFull then
          local warning,kind=helpers.forceFullLoadWarning(optionalPreset)
          if kind=="critical_warning" then coloredWrapped(1.0,0.4,0.4,1.0,warning)
          else coloredWrapped(1.0,0.8,0.2,1.0,warning) end
        end

      end
      finishCompactSubsection()
    end

    end
    if not state.ui.multiplePresets then ui.drawSaveLocation(presetListHeight,statusHeight,actionButtonHeight) end
    if state.ui.multiplePresets then
      drawBulkSection(presetListHeight,statusHeight,actionButtonHeight,extraHeight,narrowTopRow)
    else
      drawManageSection(presetListHeight,statusHeight,actionButtonHeight,extraHeight,narrowTopRow)
    end
    drawFoldersSection(presetListHeight,statusHeight,actionButtonHeight,extraHeight,narrowTopRow)
    local wasMultiple=state.ui.multiplePresets==true
    local multiple=compactSubsectionButton("Select Multiple Presets","Finish Selecting","multiplePresets")
    if multiple~=wasMultiple then
      state.ui.multiplePresets=multiple
      commands.run(runtime,"bulk_clear",{selectedBulkNames=selectedBulkPresetNames()})
    end
    end
end

return _ENV
