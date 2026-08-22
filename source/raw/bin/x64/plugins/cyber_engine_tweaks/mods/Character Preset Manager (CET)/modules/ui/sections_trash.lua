local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

drawTrashSection = function(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
if collapsibleSectionHeader("DELETE & RESTORE ITEMS", "trash") then
      ImGui.TextWrapped("Move presets, folders, and shared-folder files to Trash. You can restore them later.")
      state.ensureTrashViewCache()
      local trashNames = state.trash.cachedNames
      local trashGroupIds = state.trash.cachedGroupIds
      local trashBundleNames = state.trash.cachedBundleNames
      local trashCount = #trashNames + #trashGroupIds + #trashBundleNames
      local trashStatus = state.library.selected
        and ("Ready to move %s to Trash. %d recoverable item%s currently in Trash.")
          :format(state.library.selected, trashCount, trashCount == 1 and "" or "s")
        or ("Select a preset under Load & Restore Appearance to move it to Trash. %d recoverable item%s currently in Trash.")
          :format(trashCount, trashCount == 1 and "" or "s")
      drawSectionStatus("delete", "##trashStatus", statusHeight, trashStatus,
        state.library.selected and "ready" or "info")
      if state.library.selected then
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
      if #trashNames == 0 and #trashGroupIds == 0 and #trashBundleNames == 0 then
        ImGui.TextWrapped("Trash is empty.")
      else
        ImGui.TextWrapped(("%d preset%s in Trash  |  %d shared-folder file%s")
          :format(#trashNames, #trashNames == 1 and "" or "s",
            #trashBundleNames, #trashBundleNames == 1 and "" or "s"))
        local trashRows = {}
        for _, value in ipairs(trashGroupIds) do
          trashRows[#trashRows + 1] = { kind = "group", value = value }
        end
        for _, value in ipairs(trashNames) do
          trashRows[#trashRows + 1] = { kind = "preset", value = value }
        end
        for _, value in ipairs(trashBundleNames) do
          trashRows[#trashRows + 1] = { kind = "bundle", value = value }
        end
        drawPageControls("trashItems", #trashRows, UI_LIST_PAGE_SIZE, "Trash")
        ImGui.BeginChild("##trashList", 0, ImGui.GetFontSize() * 6, true)
        local trashChanged = false
        local firstRow, lastRow = pagedRange("trashItems",
          #trashRows, UI_LIST_PAGE_SIZE)
        for index = firstRow, lastRow do
          local row = trashRows[index]
          if row.kind == "group" then
            local groupId = row.value
            local group = state.trash.groups[groupId]
            local stats = state.trash.cachedGroupStats[groupId]
              or { presets = 0, folders = 0 }
            if fullWidthButton(("Restore Folder %s (%d presets, %d folders)")
                :format(helpers.breadcrumb(group.root), stats.presets, stats.folders) ..
                "##trashGroup:" .. groupId, actionButtonHeight) then
              restoreTrashGroup(groupId)
              trashChanged = true
              break
            end
          elseif row.kind == "preset" then
            local filename = row.value
            local item = state.trash.items[filename]
            if item and fullWidthButton("Restore " .. (item.original or filename) ..
                "##trash:" .. filename, actionButtonHeight) then
              restoreTrashPreset(filename)
              trashChanged = true
              break
            end
          else
            local filename = row.value
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
    end
end

return _ENV
