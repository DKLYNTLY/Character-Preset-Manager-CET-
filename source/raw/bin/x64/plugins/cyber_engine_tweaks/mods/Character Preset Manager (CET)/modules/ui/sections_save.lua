local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime
local commands = require("modules/ui/commands")

drawSaveSection = function(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
if collapsibleSectionHeader("SAVE & REPLACE PRESETS", "create") then
    ImGui.TextColored(1.0, 1.0, 1.0, 1.0,
      "Save the current appearance as a new preset")
    local saveLocation = helpers.breadcrumb(state.library.selectedFolder)
    local statusSaveUnavailable = not state.app.inCustomization
      or validatedPresetName(state.library.newName) == nil
    local saveStatus = not state.app.inCustomization
      and "Open new-game creation, the full editor, a mirror, or a supported ripperdoc to save a preset."
      or (validatedPresetName(state.library.newName) == nil
        and "Enter a preset name to enable saving."
        or "Ready to save this appearance.")
    drawSectionStatus("create", "##createStatus", statusHeight, saveStatus,
      statusSaveUnavailable and "info" or "ready", "Save location: " .. saveLocation)
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
    end
end

return _ENV
