local _ENV = require("modules.runtime")

drawFoldersSection = function(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
if collapsibleSectionHeader("FOLDERS", "folders") then
    ImGui.TextColored(1.0, 1.0, 1.0, 1.0,
      "Select how new or moved presets are organized")
    ImGui.TextWrapped("Selected destination: " .. helpers.breadcrumb(state.selectedFolder))
    coloredWrapped(0.64, 0.67, 0.73, 1.0,
      "Folders made in CET have no set limit. Imported folders are Windows folders inside Character Presets.")
    ImGui.Spacing()
    ImGui.BeginChild("##folderList", 0, ImGui.GetFontSize() * 4.5, true)
    if ImGui.Selectable("All Presets##rootFolder", state.selectedFolder == "")
        and state.selectedFolder ~= "" then
      log(("[UI] Folder selection changed: old='%s' new='<root>'.")
        :format(state.selectedFolder), "info")
      state.selectedFolder = ""
      cancelConfirmations()
    end
    for _, folder in ipairs(sortedFolderNames()) do
      local label = string.rep("  ", folderDepth(folder)) .. baseName(folder) ..
        (state.manualFolders[folder] and " (imported)" or "")
      if ImGui.Selectable(label .. "##folder:" .. folder, state.selectedFolder == folder)
          and state.selectedFolder ~= folder then
        log(("[UI] Folder selection changed: old='%s' new='%s'.")
          :format(tostring(state.selectedFolder), folder), "info")
        state.selectedFolder = folder
        cancelConfirmations()
        state.folderRenameName = ""
      end
    end
    ImGui.EndChild()
    ImGui.PushItemWidth(-1)
    state.folderName = ImGui.InputTextWithHint("##newFolder", "New folder name", state.folderName, 65)
    ImGui.PopItemWidth()
    local addFolderUnavailable = validatedFolderName(state.folderName) == nil
    if addFolderUnavailable then ImGui.BeginDisabled() end
    if fullWidthButton("Add Folder", actionButtonHeight) then createFolder() end
    if addFolderUnavailable then ImGui.EndDisabled() end
    if addFolderUnavailable then ImGui.TextDisabled("Enter a valid folder name to enable adding.") end
    if state.selectedFolder ~= "" then
      ImGui.PushItemWidth(-1)
      state.folderRenameName = ImGui.InputTextWithHint("##renameFolder", "Rename selected folder", state.folderRenameName, 65)
      ImGui.PopItemWidth()
      local folderRenameUnavailable = sanitizeName(state.folderRenameName) == ""
      if folderRenameUnavailable then ImGui.BeginDisabled() end
      if fullWidthButton("Rename Folder", actionButtonHeight) then renameFolder() end
      if folderRenameUnavailable then ImGui.EndDisabled() end
      if fullWidthButton("Duplicate Selected Folder", actionButtonHeight) then duplicateFolder() end
      local moveUnavailable = not state.selected
        or parentFolder(state.selected) == state.selectedFolder
      if moveUnavailable then ImGui.BeginDisabled() end
      if fullWidthButton("Move Selected Preset Here", actionButtonHeight) then movePresetToSelectedFolder() end
      if moveUnavailable then ImGui.EndDisabled() end
      if moveUnavailable and not state.selected then
        ImGui.TextDisabled("Select a preset under Load Preset before moving it.")
      end
      if fullWidthButton("Export Folder for Sharing", actionButtonHeight) then
        exportSelectedFolderBundle()
      end
      local removeFolderLabel = state.pendingRemoveFolder == state.selectedFolder
        and "Confirm Remove Folder, Keep Presets"
        or "Remove Folder, Keep Presets"
      if fullWidthButton(removeFolderLabel .. "##removeFolder", actionButtonHeight) then
        removeVirtualFolder()
      end
      local folderBulkNames = bulkPresetNamesInFolder(state.selectedFolder)
      local nestedFolderCount = state.cachedBulkNestedFolderCount or 0
      local folderAction = "folder:" .. state.selectedFolder
      local folderTrashUnavailable = #folderBulkNames == 0
      if folderTrashUnavailable then ImGui.BeginDisabled() end
      local folderTrashLabel = state.pendingBulkAction == folderAction
        and "Confirm Move Folder & Presets to Trash"
        or ("Move Folder & %d Preset%s to Trash")
          :format(#folderBulkNames, #folderBulkNames == 1 and "" or "s")
      if dangerButton(folderTrashLabel .. "##folderTrash",
          ImGui.GetContentRegionAvail(), actionButtonHeight) then
        requestBulkTrash(folderBulkNames, state.selectedFolder)
      end
      if folderTrashUnavailable then ImGui.EndDisabled() end
      coloredWrapped(0.64, 0.67, 0.73, 1.0,
        ("Trash will include %d folder%s inside this one. You can restore them later.")
          :format(nestedFolderCount, nestedFolderCount == 1 and "" or "s"))
      drawSectionStatus("bulk", "##folderBulkStatus", statusHeight)
    else
      local rootMoveUnavailable = not state.selected or parentFolder(state.selected) == ""
      if rootMoveUnavailable then ImGui.BeginDisabled() end
      if fullWidthButton("Move Selected Preset to All Presets", actionButtonHeight) then movePresetToSelectedFolder() end
      if rootMoveUnavailable then ImGui.EndDisabled() end
      if rootMoveUnavailable then ImGui.TextDisabled(not state.selected
        and "Select a preset under Load Preset before moving it."
        or "The selected preset is already in All Presets.")
      end
      if fullWidthButton("Install Shared Folders", actionButtonHeight) then
        importAvailableFolderBundles()
      end
      coloredWrapped(0.64, 0.67, 0.73, 1.0,
        "Installs .cpmfolder files from Character Presets. Files that were already installed and have not changed are skipped.")
      local bundleFiles = folderBundleFiles()
      local bundleLabel = ("Shared Folder Files (%d)"):format(#bundleFiles)
      if compactSubsectionButton(bundleLabel, "Hide Shared Folder Files", "folderBundleFiles") then
        ImGui.Indent(8)
        if #bundleFiles == 0 then
          state.selectedBundleFile = nil
          ImGui.TextDisabled("No .cpmfolder files found.")
        else
          ImGui.BeginChild("##folderBundleFileList", 0, ImGui.GetFontSize() * 3.5, true)
          local selectedStillExists = false
          for _, path in ipairs(bundleFiles) do
            local leaf = path:match("([^/]+)$") or path
            if state.selectedBundleFile
                and state.selectedBundleFile:lower() == leaf:lower() then
              state.selectedBundleFile = leaf
              selectedStillExists = true
            end
            if ImGui.Selectable(leaf .. "##bundleFile:" .. leaf,
                state.selectedBundleFile == leaf) then
              state.selectedBundleFile = leaf
              cancelConfirmations()
              selectedStillExists = true
            end
          end
          ImGui.EndChild()
          if state.selectedBundleFile and not selectedStillExists then
            state.selectedBundleFile = nil
          end
          local bundleDeleteUnavailable = not state.selectedBundleFile
          if bundleDeleteUnavailable then ImGui.BeginDisabled() end
          if dangerButton("Move Selected File to Trash##trashFolderBundle",
              ImGui.GetContentRegionAvail(), actionButtonHeight) then
            trashSelectedFolderBundle()
          end
          if bundleDeleteUnavailable then ImGui.EndDisabled() end
          ImGui.TextDisabled("Moves only the selected .cpmfolder file to Trash. You can restore it later.")
        end
        ImGui.Unindent(8)
      end
    end
    if state.folderStatus ~= "" then
      if state.lastLoggedFolderStatus ~= state.folderStatus then
        local level = state.folderStatusError and "error" or "info"
        log(("[FOLDER STATUS] %s"):format(state.folderStatus), level)
        state.lastLoggedFolderStatus = state.folderStatus
      end
    end
    drawSectionStatus("folder", "##folderStatus", statusHeight)
    end
end

return _ENV
