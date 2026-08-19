local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

drawFoldersSection = function(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
if collapsibleSectionHeader("CREATE & ORGANIZE FOLDERS", "folders") then
    ImGui.TextColored(1.0, 1.0, 1.0, 1.0,
      "Select how new or moved presets are organized")
    ImGui.TextWrapped("Selected destination: " .. helpers.breadcrumb(state.library.selectedFolder))
    coloredWrapped(0.64, 0.67, 0.73, 1.0,
      "Folders made in CET have no set limit. Imported folders are Windows folders inside Character Presets.")
    ImGui.Spacing()
    ImGui.BeginChild("##folderList", 0, ImGui.GetFontSize() * 4.5, true)
    if ImGui.Selectable("All Presets##rootFolder", state.library.selectedFolder == "")
        and state.library.selectedFolder ~= "" then
      log(("[UI] Folder selection changed: old='%s' new='<root>'.")
        :format(state.library.selectedFolder), "info")
      state.library.selectedFolder = ""
      cancelConfirmations()
    end
    for _, folder in ipairs(sortedFolderNames()) do
      local label = string.rep("  ", folderDepth(folder)) .. baseName(folder) ..
        (state.library.manualFolders[folder] and " (imported)" or "")
      if ImGui.Selectable(label .. "##folder:" .. folder, state.library.selectedFolder == folder)
          and state.library.selectedFolder ~= folder then
        log(("[UI] Folder selection changed: old='%s' new='%s'.")
          :format(tostring(state.library.selectedFolder), folder), "info")
        state.library.selectedFolder = folder
        cancelConfirmations()
        state.library.folderRenameName = ""
      end
    end
    ImGui.EndChild()
    ImGui.PushItemWidth(-1)
    state.library.folderName = ImGui.InputTextWithHint("##newFolder", "New folder name", state.library.folderName, 65)
    ImGui.PopItemWidth()
    local addFolderUnavailable = validatedFolderName(state.library.folderName) == nil
    if addFolderUnavailable then ImGui.BeginDisabled() end
    if fullWidthButton("Add Folder", actionButtonHeight) then createFolder() end
    if addFolderUnavailable then ImGui.EndDisabled() end
    if addFolderUnavailable then ImGui.TextDisabled("Enter a valid folder name to enable adding.") end
    if state.library.selectedFolder ~= "" then
      if compactSubsectionButton("Rename / Copy / Move / Delete",
          "Hide Selected Folder Actions", "selectedFolderActions") then
      ImGui.Indent(8)
      ImGui.PushItemWidth(-1)
      state.library.folderRenameName = ImGui.InputTextWithHint("##renameFolder", "Rename selected folder", state.library.folderRenameName, 65)
      ImGui.PopItemWidth()
      local folderRenameUnavailable = sanitizeName(state.library.folderRenameName) == ""
      if folderRenameUnavailable then ImGui.BeginDisabled() end
      if fullWidthButton("Rename Folder", actionButtonHeight) then renameFolder() end
      if folderRenameUnavailable then ImGui.EndDisabled() end
      if fullWidthButton("Duplicate Selected Folder", actionButtonHeight) then duplicateFolder() end
      local moveUnavailable = not state.library.selected
        or parentFolder(state.library.selected) == state.library.selectedFolder
      if moveUnavailable then ImGui.BeginDisabled() end
      if fullWidthButton("Move Selected Preset Here", actionButtonHeight) then movePresetToSelectedFolder() end
      if moveUnavailable then ImGui.EndDisabled() end
      if moveUnavailable and not state.library.selected then
        ImGui.TextDisabled("Select a preset under Load & Restore Appearance before moving it.")
      end
      local removeFolderLabel = state.library.pendingRemoveFolder == state.library.selectedFolder
        and "Confirm Remove Folder, Keep Presets"
        or "Remove Folder, Keep Presets"
      if fullWidthButton(removeFolderLabel .. "##removeFolder", actionButtonHeight) then
        removeVirtualFolder()
      end
      local folderBulkNames = bulkPresetNamesInFolder(state.library.selectedFolder)
      local nestedFolderCount = state.trash.cachedBulkNestedFolderCount or 0
      local folderAction = "folder:" .. state.library.selectedFolder
      local folderTrashUnavailable = #folderBulkNames == 0
      if folderTrashUnavailable then ImGui.BeginDisabled() end
      local folderTrashLabel = state.trash.pendingBulkAction == folderAction
        and "Confirm Move Folder & Presets to Trash"
        or ("Move Folder & %d Preset%s to Trash")
          :format(#folderBulkNames, #folderBulkNames == 1 and "" or "s")
      if dangerButton(folderTrashLabel .. "##folderTrash",
          ImGui.GetContentRegionAvail(), actionButtonHeight) then
        requestBulkTrash(folderBulkNames, state.library.selectedFolder)
      end
      if folderTrashUnavailable then ImGui.EndDisabled() end
      coloredWrapped(0.64, 0.67, 0.73, 1.0,
        ("Trash will include %d folder%s inside this one. You can restore them later.")
          :format(nestedFolderCount, nestedFolderCount == 1 and "" or "s"))
      drawSectionStatus("bulk", "##folderBulkStatus", statusHeight)
      ImGui.Unindent(8)
      end
    else
      local rootMoveUnavailable = not state.library.selected or parentFolder(state.library.selected) == ""
      if rootMoveUnavailable then ImGui.BeginDisabled() end
      if fullWidthButton("Move Selected Preset to All Presets", actionButtonHeight) then movePresetToSelectedFolder() end
      if rootMoveUnavailable then ImGui.EndDisabled() end
      if rootMoveUnavailable then ImGui.TextDisabled(not state.library.selected
        and "Select a preset under Load & Restore Appearance before moving it."
        or "The selected preset is already in All Presets.")
      end
    end
    if compactSubsectionButton("Share & Import Folders",
        "Hide Share & Import Folders", "folderSharing") then
    ImGui.Indent(8)
    ImGui.TextColored(0.97, 0.72, 0.20, 1.0, "Shared Folder Files")
    ImGui.TextWrapped("Export a folder for sharing or install .cpmfolder files from Character Presets.")
    local folderExportUnavailable = state.library.selectedFolder == ""
    if folderExportUnavailable then ImGui.BeginDisabled() end
    if fullWidthButton("Export Selected Folder as a .cpmfolder File", actionButtonHeight) then
      exportSelectedFolderBundle()
    end
    if folderExportUnavailable then ImGui.EndDisabled() end
    if folderExportUnavailable then
      ImGui.TextDisabled("Choose a folder above to export it for sharing.")
    end
    if fullWidthButton("Install .cpmfolder Files from Character Presets", actionButtonHeight) then
      importAvailableFolderBundles()
    end
    ImGui.Unindent(8)
    end
    local bundleFiles = folderBundleFiles()
    local bundleLabel = ("Manage & Remove .cpmfolder Files (%d)")
      :format(#bundleFiles)
    if compactSubsectionButton(bundleLabel, "Hide .cpmfolder File Manager",
        "folderBundleFiles") then
      ImGui.Indent(8)
      if #bundleFiles == 0 then
        state.library.selectedBundleFile = nil
        ImGui.TextDisabled("No .cpmfolder files found in Character Presets.")
      else
        ImGui.TextWrapped("Choose a sharing file below, then move only that file to Trash.")
        ImGui.BeginChild("##folderBundleFileList", 0, ImGui.GetFontSize() * 3.5, true)
        local selectedStillExists = false
        for _, path in ipairs(bundleFiles) do
          local leaf = path:match("([^/]+)$") or path
          if state.library.selectedBundleFile
              and state.library.selectedBundleFile:lower() == leaf:lower() then
            state.library.selectedBundleFile = leaf
            selectedStillExists = true
          end
          if ImGui.Selectable(leaf .. "##bundleFile:" .. leaf,
              state.library.selectedBundleFile == leaf) then
            state.library.selectedBundleFile = leaf
            cancelConfirmations()
            selectedStillExists = true
          end
        end
        ImGui.EndChild()
        if state.library.selectedBundleFile and not selectedStillExists then
          state.library.selectedBundleFile = nil
        end
        local bundleDeleteUnavailable = not state.library.selectedBundleFile
        if bundleDeleteUnavailable then ImGui.BeginDisabled() end
        if dangerButton("Move Selected .cpmfolder File to Trash##trashFolderBundle",
            ImGui.GetContentRegionAvail(), actionButtonHeight) then
          trashSelectedFolderBundle()
        end
        if bundleDeleteUnavailable then ImGui.EndDisabled() end
        ImGui.TextDisabled("You can restore the file later under Delete & Restore Items.")
      end
      ImGui.Unindent(8)
    end
    if state.status.sections.folder.message ~= "" then
      if state.status.lastLoggedFolder ~= state.status.sections.folder.message then
        local level = state.status.sections.folder.error and "error" or "info"
        log(("[FOLDER STATUS] %s"):format(state.status.sections.folder.message), level)
        state.status.lastLoggedFolder = state.status.sections.folder.message
      end
    end
    drawSectionStatus("folder", "##folderStatus", statusHeight)
    end
end

return _ENV
