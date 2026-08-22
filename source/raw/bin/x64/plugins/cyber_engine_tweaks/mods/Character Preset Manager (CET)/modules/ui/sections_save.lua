local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

drawSaveSection = function(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
if collapsibleSectionHeader("SAVE & REPLACE PRESETS", "create") then
    ImGui.TextColored(1.0, 1.0, 1.0, 1.0,
      "Save the current appearance as a new preset")
    ImGui.TextWrapped("Save location: " .. helpers.breadcrumb(state.library.selectedFolder))
    if compactSubsectionButton("Save Location", "Hide Save Location",
        "saveDestination") then
      ImGui.Indent(8)
      local saveFolders = sortedFolderNames()
      drawPageControls("saveFolders", #saveFolders, UI_LIST_PAGE_SIZE, "Folders")
      ImGui.BeginChild("##saveDestinationList", 0, ImGui.GetFontSize() * 4.5, true)
      if ImGui.Selectable("All Presets##saveDestinationRoot", state.library.selectedFolder == "")
          and state.library.selectedFolder ~= "" then
        state.library.selectedFolder = ""
        cancelConfirmations()
        setStatus("create", "Save destination changed to All Presets.")
        log("[UI] Save destination changed to '<root>'.", "info")
      end
      local firstFolder, lastFolder = pagedRange("saveFolders",
        #saveFolders, UI_LIST_PAGE_SIZE)
      for index = firstFolder, lastFolder do
        local folder = saveFolders[index]
        local label = string.rep("  ", folderDepth(folder)) .. baseName(folder) ..
          (state.library.manualFolders[folder] and " (imported)" or "")
        if ImGui.Selectable(label .. "##saveDestination:" .. folder,
            state.library.selectedFolder == folder) and state.library.selectedFolder ~= folder then
          state.library.selectedFolder = folder
          cancelConfirmations()
          setStatus("create", "Save destination changed to " .. helpers.breadcrumb(folder) .. ".")
          log(("[UI] Save destination changed to '%s'."):format(folder), "info")
        end
      end
      ImGui.EndChild()
      finishCompactSubsection()
    end
    ImGui.Spacing()
    ImGui.PushItemWidth(-1)
    local previousNewName = state.library.newName
    state.library.newName = ImGui.InputTextWithHint("##newPreset", "Name", state.library.newName, 65)
    ImGui.PopItemWidth()
    if state.library.newName ~= previousNewName then
      state.library.pendingOverwriteName = nil
      state.library.pendingOverwriteFingerprint = nil
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
      savePreset(state.library.pendingOverwriteName == pendingCreateName)
    end
    if saveUnavailable then ImGui.EndDisabled() end
    local saveStatus = not state.app.inCustomization
      and "Open the character creator, a mirror, or a ripperdoc to save a preset."
      or (validatedPresetName(state.library.newName) == nil
        and "Enter a preset name to enable saving."
        or ("Ready to save this appearance in %s.")
          :format(helpers.breadcrumb(state.library.selectedFolder)))
    drawSectionStatus("create", "##createStatus", statusHeight, saveStatus,
      saveUnavailable and "info" or "ready")
    end
end

return _ENV
