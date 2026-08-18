local runtime = require("modules.runtime") or CPMRuntime
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

ui.drawBulkTrashOptions = function(actionButtonHeight, statusHeight)
  ImGui.TextColored(0.97, 0.72, 0.20, 1.0, "Select multiple presets")
  ImGui.PushItemWidth(-1)
  local previousSearchText = state.searchText
  state.searchText = ImGui.InputTextWithHint("##bulkPresetSearch",
    "Search presets or folders", state.searchText, 65)
  if state.searchText ~= previousSearchText then invalidateFilteredViewCache() end
  ImGui.PopItemWidth()
  local visibleNames = helpers.filteredPresetNames()
  local selectedBulkNames = selectedBulkPresetNames()
  local bulkButtonWidth = (ImGui.GetContentRegionAvail() - 8) * 0.5
  if ImGui.Button("Select All Visible##bulkSelectAll",
      bulkButtonWidth, actionButtonHeight) then
    for _, name in ipairs(visibleNames) do state.bulkSelected[name] = true end
    invalidateBulkSelectionCache()
    cancelConfirmations()
    clearStatus("bulk")
  end
  ImGui.SameLine()
  if #selectedBulkNames == 0 then ImGui.BeginDisabled() end
  if ImGui.Button("Clear Selection##bulkClear",
      bulkButtonWidth, actionButtonHeight) then
    state.bulkSelected = {}
    invalidateBulkSelectionCache()
    cancelConfirmations()
    clearStatus("bulk")
  end
  if #selectedBulkNames == 0 then ImGui.EndDisabled() end
  ImGui.BeginChild("##bulkPresetList", 0, ImGui.GetFontSize() * 6, true)
  if #visibleNames == 0 then
    ImGui.TextDisabled("No presets match the current search.")
  else
    for _, name in ipairs(visibleNames) do
      local selectedForBulk = state.bulkSelected[name] == true
      if ImGui.Selectable((selectedForBulk and "[x] " or "[ ] ") ..
          helpers.breadcrumb(name) .. "##bulkPreset:" .. name, selectedForBulk) then
        if selectedForBulk then
          state.bulkSelected[name] = nil
        else
          state.bulkSelected[name] = true
        end
        invalidateBulkSelectionCache()
        cancelConfirmations()
        clearStatus("bulk")
      end
    end
  end
  ImGui.EndChild()
  selectedBulkNames = selectedBulkPresetNames()
  ImGui.TextDisabled(("%d preset%s selected.")
    :format(#selectedBulkNames, #selectedBulkNames == 1 and "" or "s"))
  if #selectedBulkNames == 0 then ImGui.BeginDisabled() end
  local bulkTrashLabel = state.pendingBulkAction == "presets"
    and "Confirm Bulk Trash"
    or ("Move %d Preset%s to Trash")
      :format(#selectedBulkNames, #selectedBulkNames == 1 and "" or "s")
  if dangerButton(bulkTrashLabel .. "##bulkPresetTrash",
      ImGui.GetContentRegionAvail(), actionButtonHeight) then
    requestBulkTrash(selectedBulkNames)
  end
  if #selectedBulkNames == 0 then ImGui.EndDisabled() end
  drawSectionStatus("bulk", "##bulkStatus", statusHeight)
end

drawTrashSection = function(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
if collapsibleSectionHeader("DELETE & RESTORE", "trash") then
      ImGui.TextWrapped("Move presets, folders, and shared-folder files to Trash. You can restore them later.")
      if not state.selected then
        ImGui.TextDisabled("Select a preset under Load Preset to move one preset to Trash.")
      else
        local deleteLabel = state.pendingDeleteName == state.selected
          and "Confirm Move to Trash##danger"
          or "Move Selected Preset to Trash##danger"
        if dangerButton(deleteLabel, ImGui.GetContentRegionAvail(), actionButtonHeight) then
          trashPreset()
        end
      end

      if compactSubsectionButton("More Trash Options", "Hide More Trash Options",
          "bulkTrash") then
        ImGui.Indent(8)
        ui.drawBulkTrashOptions(actionButtonHeight, statusHeight)
        ImGui.Unindent(8)
      end

      ImGui.Spacing()
      ImGui.Separator()
      ImGui.Spacing()
      ImGui.TextColored(0.97, 0.72, 0.20, 1.0, "Recover from Trash")
      state.ensureTrashViewCache()
      local trashNames = state.cachedTrashNames
      local trashGroupIds = state.cachedTrashGroupIds
      local trashBundleNames = state.cachedTrashBundleNames
      if #trashNames == 0 and #trashGroupIds == 0 and #trashBundleNames == 0 then
        ImGui.TextDisabled("Trash is empty.")
      else
        ImGui.TextWrapped(("%d preset%s in Trash  |  %d shared-folder file%s")
          :format(#trashNames, #trashNames == 1 and "" or "s",
            #trashBundleNames, #trashBundleNames == 1 and "" or "s"))
        ImGui.BeginChild("##trashList", 0, ImGui.GetFontSize() * 6, true)
        local trashChanged = false
        for _, groupId in ipairs(trashGroupIds) do
          local group = state.trashGroups[groupId]
          local stats = state.cachedTrashGroupStats[groupId] or { presets = 0, folders = 0 }
          local groupPresetCount, folderCount = stats.presets, stats.folders
          if fullWidthButton(("Restore Folder %s (%d presets, %d folders)")
              :format(helpers.breadcrumb(group.root), groupPresetCount, folderCount) ..
              "##trashGroup:" .. groupId, actionButtonHeight) then
            restoreTrashGroup(groupId)
            trashChanged = true
            break
          end
        end
        if not trashChanged then
          if #trashGroupIds > 0 and #trashNames > 0 then ImGui.Separator() end
          for _, filename in ipairs(trashNames) do
            local item = state.trash[filename]
            if item and fullWidthButton("Restore " .. (item.original or filename) ..
                "##trash:" .. filename, actionButtonHeight) then
              restoreTrashPreset(filename)
              trashChanged = true
              break
            end
          end
        end
        if not trashChanged then
          if #trashBundleNames > 0 and (#trashGroupIds > 0 or #trashNames > 0) then
            ImGui.Separator()
          end
          for _, filename in ipairs(trashBundleNames) do
            if fullWidthButton("Restore File " .. filename ..
                "##trashBundle:" .. filename, actionButtonHeight) then
              restoreTrashBundle(filename)
              trashChanged = true
              break
            end
          end
        end
        ImGui.EndChild()
        if not trashChanged then
          local emptyLabel = state.pendingEmptyTrash
            and "Confirm Empty Trash Permanently##emptyTrash"
            or "Empty Trash Permanently##emptyTrash"
          if dangerButton(emptyLabel, ImGui.GetContentRegionAvail(), actionButtonHeight) then
            emptyTrash()
          end
        end
      end
      drawSectionStatus("delete", "##trashStatus", statusHeight)
    end
end

return _ENV
