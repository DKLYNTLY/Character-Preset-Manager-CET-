local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime
local commands = require("modules/ui/commands")

drawBulkSection = function(presetListHeight, statusHeight, actionButtonHeight, extraHeight,
    narrowTopRow)
  if state.ui.multiplePresets then
    local selectedBulkNames=selectedBulkPresetNames()
    local targetLabel = state.trash.bulkTargetFolder == ""
      and "All Presets" or state.trash.bulkTargetFolder
    if ImGui.BeginCombo("Move selected to folder##bulkTargetFolder", targetLabel) then
      if ImGui.Selectable("All Presets##bulkTargetRoot", state.trash.bulkTargetFolder == "") then
        commands.run(runtime, "bulk_location_root")
      end
      for _, folder in ipairs(sortedFolderNames()) do
        if ImGui.Selectable(helpers.breadcrumb(folder) .. "##bulkTarget:" .. folder,
            state.trash.bulkTargetFolder == folder) then
          commands.run(runtime, "bulk_location", {folder = folder})
        end
      end
      ImGui.EndCombo()
    end
    if #selectedBulkNames == 0 then ImGui.BeginDisabled() end
    if fullWidthButton("Move Selected##bulkMove",actionButtonHeight) then
      commands.run(runtime,"bulk_move",{selectedBulkNames=selectedBulkNames})
    end
    local bulkTrashLabel = state.trash.pendingBulkAction == "presets"
      and "Confirm Bulk Trash"
      or ("Move %d Preset%s to Trash")
        :format(#selectedBulkNames, #selectedBulkNames == 1 and "" or "s")
    if dangerButton(bulkTrashLabel .. "##bulkPresetTrash",
        ImGui.GetContentRegionAvail(), actionButtonHeight) then
      commands.run(runtime, "bulk_trash", {selectedBulkNames = selectedBulkNames})
    end
    if #selectedBulkNames == 0 then ImGui.EndDisabled() end
  end
end

return _ENV
