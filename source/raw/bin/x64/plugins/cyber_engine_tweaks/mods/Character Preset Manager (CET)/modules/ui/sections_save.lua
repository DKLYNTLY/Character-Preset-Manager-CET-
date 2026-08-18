local runtime = require("modules.runtime") or CPMRuntime
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

drawSaveSection = function(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
if collapsibleSectionHeader("SAVE PRESET", "create") then
    ImGui.TextColored(1.0, 1.0, 1.0, 1.0,
      "Save the current appearance as a new preset")
    ImGui.TextWrapped("Save location: " .. helpers.breadcrumb(state.selectedFolder))
    if compactSubsectionButton("Choose Save Destination", "Hide Save Destinations",
        "saveDestination") then
      ImGui.Indent(8)
      ImGui.BeginChild("##saveDestinationList", 0, ImGui.GetFontSize() * 4.5, true)
      if ImGui.Selectable("All Presets##saveDestinationRoot", state.selectedFolder == "")
          and state.selectedFolder ~= "" then
        state.selectedFolder = ""
        cancelConfirmations()
        setStatus("create", "Save destination changed to All Presets.")
        log("[UI] Save destination changed to '<root>'.", "info")
      end
      for _, folder in ipairs(sortedFolderNames()) do
        local label = string.rep("  ", folderDepth(folder)) .. baseName(folder) ..
          (state.manualFolders[folder] and " (imported)" or "")
        if ImGui.Selectable(label .. "##saveDestination:" .. folder,
            state.selectedFolder == folder) and state.selectedFolder ~= folder then
          state.selectedFolder = folder
          cancelConfirmations()
          setStatus("create", "Save destination changed to " .. helpers.breadcrumb(folder) .. ".")
          log(("[UI] Save destination changed to '%s'."):format(folder), "info")
        end
      end
      ImGui.EndChild()
      ImGui.Unindent(8)
    end
    ImGui.Spacing()
    ImGui.PushItemWidth(-1)
    local previousNewName = state.newName
    state.newName = ImGui.InputTextWithHint("##newPreset", "Name", state.newName, 65)
    ImGui.PopItemWidth()
    if state.newName ~= previousNewName then
      state.pendingOverwriteName = nil
      state.pendingOverwriteFingerprint = nil
    end
    local saveLabel = "Save New Preset"
    local pendingCreateName = joinFolder(state.selectedFolder, sanitizeName(state.newName))
    if state.pendingOverwriteName == pendingCreateName then
      saveLabel = "Confirm Overwrite"
    end
    ImGui.Spacing()
    local saveUnavailable = not state.inCustomization
      or validatedPresetName(state.newName) == nil
    if saveUnavailable then ImGui.BeginDisabled() end
    if fullWidthButton(saveLabel, actionButtonHeight) then
      savePreset(state.pendingOverwriteName == pendingCreateName)
    end
    if saveUnavailable then ImGui.EndDisabled() end
    if saveUnavailable then
      ImGui.TextDisabled(not state.inCustomization
        and "Open a customization screen to enable saving."
        or "Enter a valid preset name to enable saving.")
    end
    drawSectionStatus("create", "##createStatus", statusHeight)
    end
end

return _ENV
