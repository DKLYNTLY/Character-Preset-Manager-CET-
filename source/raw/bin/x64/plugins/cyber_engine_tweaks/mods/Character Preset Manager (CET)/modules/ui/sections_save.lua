local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

drawSaveSection = function(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
if collapsibleSectionHeader("SAVE & REPLACE PRESETS", "create") then
    ImGui.TextColored(1.0, 1.0, 1.0, 1.0,
      "Save the current appearance as a new preset")
    local saveLocation = helpers.breadcrumb(state.library.selectedFolder)
    local statusSaveUnavailable = not state.app.inCustomization
      or validatedPresetName(state.library.newName) == nil
    local saveStatus = not state.app.inCustomization
      and ("Save location: %s. Open the character creator, a mirror, or a ripperdoc to save a preset.")
        :format(saveLocation)
      or (validatedPresetName(state.library.newName) == nil
        and ("Save location: %s. Enter a preset name to enable saving.")
          :format(saveLocation)
        or ("Save location: %s. Ready to save this appearance.")
          :format(saveLocation))
    drawSectionStatus("create", "##createStatus", statusHeight, saveStatus,
      statusSaveUnavailable and "info" or "ready")
    ImGui.Spacing()
    ImGui.PushItemWidth(-1)
    local previousNewName = state.library.newName
    state.library.newName = ImGui.InputTextWithHint("##newPreset", "Name", state.library.newName, 65)
    ImGui.PopItemWidth()
    if state.library.newName ~= previousNewName then
      state.library.pendingOverwriteName = nil
      state.library.pendingOverwriteFingerprint = nil
      clearStatus("create")
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
        setStatus("create", "Save location: All Presets.")
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
          setStatus("create", "Save location: " .. helpers.breadcrumb(folder) .. ".")
          log(("[UI] Save destination changed to '%s'."):format(folder), "info")
        end
      end
      ImGui.EndChild()
      finishCompactSubsection()
    end
    end
end

return _ENV
