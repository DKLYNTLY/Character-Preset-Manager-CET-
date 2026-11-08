local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime
local commands = require("modules/ui/commands")

drawFoldersSection = function(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
if compactSubsectionButton("Folders", "Hide Folders", "folders") then
    ImGui.Indent(8)
    ImGui.TextColored(1.0, 1.0, 1.0, 1.0,
      "Create folders or move presets between them")
    ImGui.Spacing()
    local folderNames = sortedFolderNames()
    drawPageControls("organizeFolders", #folderNames, UI_LIST_PAGE_SIZE, "Folders")
    ImGui.BeginChild("##folderList", 0, ImGui.GetFontSize() * 4.5, true)
    if ImGui.Selectable("All Presets##rootFolder", state.library.selectedFolder == "")
        and state.library.selectedFolder ~= "" then
      commands.run(runtime, "folder_root")
    end
    local firstFolder, lastFolder = pagedRange("organizeFolders",
      #folderNames, UI_LIST_PAGE_SIZE)
    for index = firstFolder, lastFolder do
      local folder = folderNames[index]
      local label = string.rep("  ", folderDepth(folder)) .. baseName(folder) ..
        (state.library.manualFolders[folder] and " (imported)" or "")
      if ImGui.Selectable(label .. "##folder:" .. folder, state.library.selectedFolder == folder)
          and state.library.selectedFolder ~= folder then
        commands.run(runtime, "folder_select", {folder = folder})
      end
    end
    ImGui.EndChild()
    ImGui.PushItemWidth(-1)
    state.library.folderName = ImGui.InputTextWithHint("##newFolder", "New folder name", state.library.folderName, 65)
    ImGui.PopItemWidth()
    local addFolderUnavailable = validatedFolderName(state.library.folderName) == nil
    if addFolderUnavailable then ImGui.BeginDisabled() end
    if fullWidthButton("Add Folder", actionButtonHeight) then commands.run(runtime, "folder_create") end
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
      if fullWidthButton("Rename Folder", actionButtonHeight) then commands.run(runtime, "folder_rename") end
      if folderRenameUnavailable then ImGui.EndDisabled() end
      if fullWidthButton("Duplicate Selected Folder", actionButtonHeight) then commands.run(runtime, "folder_duplicate") end
      local moveUnavailable = not state.library.selected
        or parentFolder(state.library.selected) == state.library.selectedFolder
      if moveUnavailable then ImGui.BeginDisabled() end
      if fullWidthButton("Move Selected Preset Here", actionButtonHeight) then commands.run(runtime, "move") end
      if moveUnavailable then ImGui.EndDisabled() end
      local removeFolderLabel = state.library.pendingRemoveFolder == state.library.selectedFolder
        and "Confirm Remove Folder, Keep Presets"
        or "Remove Folder, Keep Presets"
      if fullWidthButton(removeFolderLabel .. "##removeFolder", actionButtonHeight) then
        commands.run(runtime, "folder_remove")
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
        commands.run(runtime, "folder_trash", {folderBulkNames = folderBulkNames})
      end
      if folderTrashUnavailable then ImGui.EndDisabled() end
      coloredWrapped(1.0, 1.0, 1.0, 1.0,
        ("This also sends %d nested folder%s to Trash. You can restore the group later.")
          :format(nestedFolderCount, nestedFolderCount == 1 and "" or "s"))
      finishCompactSubsection()
      end
    else
      local rootMoveUnavailable = not state.library.selected or parentFolder(state.library.selected) == ""
      if rootMoveUnavailable then ImGui.BeginDisabled() end
      if fullWidthButton("Move Selected Preset to All Presets", actionButtonHeight) then commands.run(runtime, "move_root") end
      if rootMoveUnavailable then ImGui.EndDisabled() end
    end
    if state.status.sections.folder.message ~= "" then
      if state.status.lastLoggedFolder ~= state.status.sections.folder.message then
        local level = state.status.sections.folder.error and "error" or "info"
        log(("[FOLDER STATUS] %s"):format(state.status.sections.folder.message), level)
        state.status.lastLoggedFolder = state.status.sections.folder.message
      end
    end
    finishCompactSubsection()
    end
end

return _ENV
