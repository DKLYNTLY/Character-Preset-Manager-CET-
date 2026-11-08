local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime
local commands = require("modules/ui/commands")

drawSaveSection = function(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
do
    ImGui.TextColored(1.0, 1.0, 1.0, 1.0,
      "Save the current appearance as a new preset")
    ImGui.Spacing()
    ImGui.PushItemWidth(-1)
    local previousNewName = state.library.newName
    state.library.newName = ImGui.InputTextWithHint("##newPreset", "Name", state.library.newName, 65)
    ImGui.PopItemWidth()
    if state.library.newName ~= previousNewName then
      commands.run(runtime, "name_changed")
    end
    local saveLabel = "Save New Preset"
    local pendingCreateName = joinFolder(state.library.selectedFolder, sanitizeName(state.library.newName))
    if state.library.pendingOverwriteName == pendingCreateName then
      saveLabel = "Confirm Overwrite"
    end
    ImGui.Spacing()
    local saveUnavailable = not state.app.inCustomization
      or validatedPresetName(state.library.newName) == nil
    if saveUnavailable then ImGui.BeginDisabled() end
    if fullWidthButton(saveLabel, actionButtonHeight) then
      commands.run(runtime, "save", {pendingCreateName = pendingCreateName})
    end
    if saveUnavailable then ImGui.EndDisabled() end
    if compactSubsectionButton("Change Save Location", "Hide Save Location",
        "saveDestination") then
      ImGui.Indent(8)
      local saveFolders = sortedFolderNames()
      drawPageControls("saveFolders", #saveFolders, UI_LIST_PAGE_SIZE, "Folders")
      ImGui.BeginChild("##saveDestinationList", 0, ImGui.GetFontSize() * 4.5, true)
      if ImGui.Selectable("All Presets##saveDestinationRoot", state.library.selectedFolder == "")
          and state.library.selectedFolder ~= "" then
        commands.run(runtime, "save_location_root")
      end
      local firstFolder, lastFolder = pagedRange("saveFolders",
        #saveFolders, UI_LIST_PAGE_SIZE)
      for index = firstFolder, lastFolder do
        local folder = saveFolders[index]
        local label = string.rep("  ", folderDepth(folder)) .. baseName(folder) ..
          (state.library.manualFolders[folder] and " (imported)" or "")
        if ImGui.Selectable(label .. "##saveDestination:" .. folder,
            state.library.selectedFolder == folder) and state.library.selectedFolder ~= folder then
          commands.run(runtime, "save_location", {folder = folder})
        end
      end
      ImGui.EndChild()
      finishCompactSubsection()
    end
    ImGui.TextWrapped("Save location: " .. helpers.breadcrumb(state.library.selectedFolder))
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
    end
end

return _ENV
