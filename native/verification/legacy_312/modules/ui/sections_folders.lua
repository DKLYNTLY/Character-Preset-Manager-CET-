local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

drawFoldersSection = function(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
if collapsibleSectionHeader("CREATE & ORGANIZE FOLDERS", "folders") then
    ImGui.TextColored(1.0, 1.0, 1.0, 1.0,
      "Create folders or move presets between them")
    local folderStatus = state.library.selectedFolder == ""
      and (not state.library.selected
        and "Enter a folder name to add one, or select a preset before moving it."
        or (parentFolder(state.library.selected) == ""
          and "The selected preset is already here."
          or "The selected preset can be moved here."))
      or "Add a folder or open the selected folder actions."
    drawSectionStatus("folder", "##folderStatus", statusHeight, folderStatus, "ready",
      "Destination: " .. helpers.breadcrumb(state.library.selectedFolder))
    ImGui.Spacing()
    local folderNames = sortedFolderNames()
    drawPageControls("organizeFolders", #folderNames, UI_LIST_PAGE_SIZE, "Folders")
    ImGui.BeginChild("##folderList", 0, ImGui.GetFontSize() * 4.5, true)
    if ImGui.Selectable("All Presets##rootFolder", state.library.selectedFolder == "")
        and state.library.selectedFolder ~= "" then
      log(("[UI] Folder selection changed: old='%s' new='<root>'.")
        :format(state.library.selectedFolder), "info")
      state.library.selectedFolder = ""
      cancelConfirmations()
    end
    local firstFolder, lastFolder = pagedRange("organizeFolders",
      #folderNames, UI_LIST_PAGE_SIZE)
    for index = firstFolder, lastFolder do
      local folder = folderNames[index]
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
      coloredWrapped(1.0, 1.0, 1.0, 1.0,
        ("Trash will include %d folder%s inside this one. You can restore them later.")
          :format(nestedFolderCount, nestedFolderCount == 1 and "" or "s"))
      finishCompactSubsection()
      end
    else
      local rootMoveUnavailable = not state.library.selected or parentFolder(state.library.selected) == ""
      if rootMoveUnavailable then ImGui.BeginDisabled() end
      if fullWidthButton("Move Selected Preset to All Presets", actionButtonHeight) then movePresetToSelectedFolder() end
      if rootMoveUnavailable then ImGui.EndDisabled() end
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
    if fullWidthButton("Install .cpmfolder Files from Character Presets", actionButtonHeight) then
      importAvailableFolderBundles()
    end
    finishCompactSubsection()
    end
    local bundleFiles = folderBundleFiles()
    local bundleLabel = ("Manage & Remove .cpmfolder Files (%d)")
      :format(#bundleFiles)
    if compactSubsectionButton(bundleLabel, "Hide .cpmfolder File Manager",
        "folderBundleFiles") then
      ImGui.Indent(8)
      if #bundleFiles == 0 then
        state.library.selectedBundleFile = nil
        clearFolderBundlePreview()
        ImGui.TextWrapped("No .cpmfolder files found in Character Presets.")
      else
        ImGui.TextWrapped("Choose a sharing file below to view its contents or move only that file to Trash.")
        drawPageControls("folderBundleFiles", #bundleFiles,
          UI_LIST_PAGE_SIZE, "Sharing files")
        ImGui.BeginChild("##folderBundleFileList", 0, ImGui.GetFontSize() * 3.5, true)
        local selectedStillExists = false
        for _, path in ipairs(bundleFiles) do
          local leaf = path:match("([^/]+)$") or path
          if state.library.selectedBundleFile
              and state.library.selectedBundleFile:lower() == leaf:lower() then
            state.library.selectedBundleFile = leaf
            selectedStillExists = true
          end
        end
        local firstBundle, lastBundle = pagedRange("folderBundleFiles",
          #bundleFiles, UI_LIST_PAGE_SIZE)
        for index = firstBundle, lastBundle do
          local path = bundleFiles[index]
          local leaf = path:match("([^/]+)$") or path
          if ImGui.Selectable(leaf .. "##bundleFile:" .. leaf,
              state.library.selectedBundleFile == leaf) then
            if state.library.selectedBundleFile ~= leaf then clearFolderBundlePreview() end
            state.library.selectedBundleFile = leaf
            cancelConfirmations()
            selectedStillExists = true
          end
        end
        ImGui.EndChild()
        if state.library.selectedBundleFile and not selectedStillExists then
          state.library.selectedBundleFile = nil
          clearFolderBundlePreview()
        end
        local bundleActionUnavailable = not state.library.selectedBundleFile
        if bundleActionUnavailable then ImGui.BeginDisabled() end
        local preview = state.library.folderBundlePreview
        local previewVisible = preview and state.library.selectedBundleFile
          and preview.filename:lower() == state.library.selectedBundleFile:lower()
        local previewLabel = previewVisible
          and "Hide Selected .cpmfolder Contents##viewFolderBundle"
          or "View Selected .cpmfolder Contents##viewFolderBundle"
        if fullWidthButton(previewLabel, actionButtonHeight) then
          if previewVisible then
            clearFolderBundlePreview()
            clearStatus("folder")
          else viewSelectedFolderBundleContents() end
        end
        if dangerButton("Move Selected .cpmfolder File to Trash##trashFolderBundle",
            ImGui.GetContentRegionAvail(), actionButtonHeight) then
          trashSelectedFolderBundle()
        end
        if bundleActionUnavailable then ImGui.EndDisabled() end
        preview = state.library.folderBundlePreview
        previewVisible = preview and state.library.selectedBundleFile
          and preview.filename:lower() == state.library.selectedBundleFile:lower()
        if previewVisible then
          ImGui.Spacing()
          ImGui.TextColored(0.97, 0.72, 0.20, 1.0, "Selected File Contents")
          ImGui.TextWrapped("Main folder: " .. preview.root)
          ImGui.TextWrapped(("Nested folders: %d    Presets: %d")
            :format(#preview.folders, #preview.presets))
          local previewRows = { "Folder: " .. preview.root }
          for _, folder in ipairs(preview.folders) do
            previewRows[#previewRows + 1] = "Folder: " ..
              joinFolder(preview.root, folder)
          end
          for _, preset in ipairs(preview.presets) do
            previewRows[#previewRows + 1] = "Preset: " ..
              joinFolder(preview.root, preset)
          end
          drawPageControls("folderBundlePreview", #previewRows,
            UI_LIST_PAGE_SIZE, "Contents")
          ImGui.BeginChild("##folderBundleContents", 0, ImGui.GetFontSize() * 7, true)
          local firstPreview, lastPreview = pagedRange("folderBundlePreview",
            #previewRows, UI_LIST_PAGE_SIZE)
          for index = firstPreview, lastPreview do
            ImGui.TextWrapped(previewRows[index])
          end
          ImGui.EndChild()
        end
        ImGui.TextWrapped("You can restore the file later under Delete & Restore Items.")
      end
      finishCompactSubsection()
    end
    if state.status.sections.folder.message ~= "" then
      if state.status.lastLoggedFolder ~= state.status.sections.folder.message then
        local level = state.status.sections.folder.error and "error" or "info"
        log(("[FOLDER STATUS] %s"):format(state.status.sections.folder.message), level)
        state.status.lastLoggedFolder = state.status.sections.folder.message
      end
    end
    end
end

return _ENV
