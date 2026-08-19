local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

drawTrashSection = function(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
if collapsibleSectionHeader("DELETE & RESTORE", "trash") then
      ImGui.TextWrapped("Move presets, folders, and shared-folder files to Trash. You can restore them later.")
      if not state.library.selected then
        ImGui.TextDisabled("Select a preset under Load Preset to move one preset to Trash.")
      else
        local deleteLabel = state.trash.pendingDeleteName == state.library.selected
          and "Confirm Move to Trash##danger"
          or "Move Selected Preset to Trash##danger"
        if dangerButton(deleteLabel, ImGui.GetContentRegionAvail(), actionButtonHeight) then
          trashPreset()
        end
      end

      ImGui.Spacing()
      ImGui.Separator()
      ImGui.Spacing()
      ImGui.TextColored(0.97, 0.72, 0.20, 1.0, "Recover from Trash")
      state.ensureTrashViewCache()
      local trashNames = state.trash.cachedNames
      local trashGroupIds = state.trash.cachedGroupIds
      local trashBundleNames = state.trash.cachedBundleNames
      if #trashNames == 0 and #trashGroupIds == 0 and #trashBundleNames == 0 then
        ImGui.TextDisabled("Trash is empty.")
      else
        ImGui.TextWrapped(("%d preset%s in Trash  |  %d shared-folder file%s")
          :format(#trashNames, #trashNames == 1 and "" or "s",
            #trashBundleNames, #trashBundleNames == 1 and "" or "s"))
        ImGui.BeginChild("##trashList", 0, ImGui.GetFontSize() * 6, true)
        local trashChanged = false
        for _, groupId in ipairs(trashGroupIds) do
          local group = state.trash.groups[groupId]
          local stats = state.trash.cachedGroupStats[groupId] or { presets = 0, folders = 0 }
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
            local item = state.trash.items[filename]
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
          local emptyLabel = state.trash.pendingEmpty
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
