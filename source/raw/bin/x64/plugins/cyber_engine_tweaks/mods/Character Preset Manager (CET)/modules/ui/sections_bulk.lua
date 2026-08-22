local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

drawBulkSection = function(presetListHeight, statusHeight, actionButtonHeight, extraHeight,
    narrowTopRow)
  if collapsibleSectionHeader("SELECT & MANAGE MULTIPLE PRESETS", "bulk") then
    ImGui.TextWrapped("Select several presets, then move them to one folder, export them together, or move them to Trash.")
    local visibleNames = helpers.filteredPresetNames()
    local selectedBulkNames = selectedBulkPresetNames()
    local bulkStatus = #visibleNames == 0
      and "No presets match the current search."
      or (#selectedBulkNames == 0
        and "Select a preset row to add it. Select it again to remove it."
        or ("%d preset%s selected. Choose an action below.")
          :format(#selectedBulkNames, #selectedBulkNames == 1 and "" or "s"))
    drawSectionStatus("bulk", "##bulkStatus", statusHeight, bulkStatus,
      #selectedBulkNames > 0 and "ready" or "info")
    ImGui.TextColored(0.97, 0.72, 0.20, 1.0, "Select multiple presets")
    ImGui.PushItemWidth(-1)
    local previousSearchText = state.library.searchText
    state.library.searchText = ImGui.InputTextWithHint("##bulkPresetSearch",
      "Search presets or folders", state.library.searchText, 65)
    if state.library.searchText ~= previousSearchText then
      invalidateFilteredViewCache()
      state.ui.listPages.bulkPresets = 1
    end
    ImGui.PopItemWidth()
    local bulkButtonWidth = (ImGui.GetContentRegionAvail() - 8) * 0.5
    if ImGui.Button("Select All Visible##bulkSelectAll",
        bulkButtonWidth, actionButtonHeight) then
      for _, name in ipairs(visibleNames) do state.trash.bulkSelected[name] = true end
      invalidateBulkSelectionCache()
      cancelConfirmations()
      clearStatus("bulk")
    end
    ImGui.SameLine()
    if #selectedBulkNames == 0 then ImGui.BeginDisabled() end
    if ImGui.Button("Clear Selection##bulkClear",
        bulkButtonWidth, actionButtonHeight) then
      state.trash.bulkSelected = {}
      invalidateBulkSelectionCache()
      cancelConfirmations()
      clearStatus("bulk")
    end
    if #selectedBulkNames == 0 then ImGui.EndDisabled() end
    drawPageControls("bulkPresets", #visibleNames, UI_LIST_PAGE_SIZE, "Presets")
    ImGui.BeginChild("##bulkPresetList", 0, ImGui.GetFontSize() * 6, true)
    if #visibleNames == 0 then
      ImGui.TextWrapped("No presets match the current search.")
    else
      local firstPreset, lastPreset = pagedRange("bulkPresets",
        #visibleNames, UI_LIST_PAGE_SIZE)
      for index = firstPreset, lastPreset do
        local name = visibleNames[index]
        local selectedForBulk = state.trash.bulkSelected[name] == true
        local rowLabel = (selectedForBulk and "[Selected] " or "[ ] ") ..
          helpers.breadcrumb(name) .. "##bulkPreset:" .. name
        if fullWidthButton(rowLabel, 28) then
          if selectedForBulk then
            state.trash.bulkSelected[name] = nil
          else
            state.trash.bulkSelected[name] = true
          end
          invalidateBulkSelectionCache()
          cancelConfirmations()
          clearStatus("bulk")
        end
      end
    end
    ImGui.EndChild()
    selectedBulkNames = selectedBulkPresetNames()
    local targetLabel = state.trash.bulkTargetFolder == ""
      and "All Presets" or state.trash.bulkTargetFolder
    if ImGui.BeginCombo("Move selected to folder##bulkTargetFolder", targetLabel) then
      if ImGui.Selectable("All Presets##bulkTargetRoot", state.trash.bulkTargetFolder == "") then
        state.trash.bulkTargetFolder = ""
        clearStatus("bulk")
      end
      for _, folder in ipairs(sortedFolderNames()) do
        if ImGui.Selectable(helpers.breadcrumb(folder) .. "##bulkTarget:" .. folder,
            state.trash.bulkTargetFolder == folder) then
          state.trash.bulkTargetFolder = folder
          clearStatus("bulk")
        end
      end
      ImGui.EndCombo()
    end
    if #selectedBulkNames == 0 then ImGui.BeginDisabled() end
    local bulkActionWidth = (ImGui.GetContentRegionAvail() - 8) * 0.5
    if ImGui.Button("Move Selected##bulkMove", bulkActionWidth, actionButtonHeight) then
      moveSelectedBulkPresetsToFolder()
    end
    ImGui.SameLine()
    if ImGui.Button("Export Selected##bulkExport", bulkActionWidth, actionButtonHeight) then
      exportSelectedBulkPresetBundle()
    end
    local bulkTrashLabel = state.trash.pendingBulkAction == "presets"
      and "Confirm Bulk Trash"
      or ("Move %d Preset%s to Trash")
        :format(#selectedBulkNames, #selectedBulkNames == 1 and "" or "s")
    if dangerButton(bulkTrashLabel .. "##bulkPresetTrash",
        ImGui.GetContentRegionAvail(), actionButtonHeight) then
      requestBulkTrash(selectedBulkNames)
    end
    if #selectedBulkNames == 0 then ImGui.EndDisabled() end
  end
end

return _ENV
