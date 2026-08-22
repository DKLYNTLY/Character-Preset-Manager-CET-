local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

drawBackupSection = function(presetListHeight, statusHeight, actionButtonHeight, extraHeight,
    narrowTopRow)
  if collapsibleSectionHeader("EXPORT & IMPORT BACKUPS", "backup") then
    ImGui.TextWrapped("Save or restore the complete preset library, including folders and settings, or permanently delete a selected backup file.")
    if fullWidthButton("Export Complete Library Backup##exportLibraryBackup",
        actionButtonHeight) then
      exportLibraryBackup()
    end
    if fullWidthButton("Refresh Backup File List##refreshLibraryBackups",
        actionButtonHeight) then
      libraryBackupFiles(true)
      clearStatus("backup")
    end
    local backupFiles = libraryBackupFiles()
    local selectedBackupAvailable = false
    for _, backupPath in ipairs(backupFiles) do
      if backupPath == state.backup.selectedFile then
        selectedBackupAvailable = true
        break
      end
    end
    if #backupFiles > 0 and not selectedBackupAvailable then
      state.backup.selectedFile = backupFiles[#backupFiles]
    elseif #backupFiles == 0 then
      state.backup.selectedFile = nil
    end
    local selectedBackupLabel = state.backup.selectedFile
      and state.backup.selectedFile:match("([^/]+)$") or "No library backup found"
    drawPageControls("backupFiles", #backupFiles, UI_LIST_PAGE_SIZE, "Backups")
    if ImGui.BeginCombo("Backup file##libraryBackupFile", selectedBackupLabel) then
      local firstBackup, lastBackup = pagedRange("backupFiles",
        #backupFiles, UI_LIST_PAGE_SIZE)
      for index = firstBackup, lastBackup do
        local backupPath = backupFiles[index]
        local label = backupPath:match("([^/]+)$") or backupPath
        if ImGui.Selectable(label .. "##backup:" .. backupPath,
            state.backup.selectedFile == backupPath) then
          state.backup.selectedFile = backupPath
          cancelConfirmations()
          clearStatus("backup")
        end
      end
      ImGui.EndCombo()
    end
    if #backupFiles == 0 then ImGui.BeginDisabled() end
    if fullWidthButton("Import Selected Library Backup##importLibraryBackup",
        actionButtonHeight) then
      importLibraryBackup()
    end
    local deleteBackupLabel = state.backup.selectedFile
      and state.backup.pendingDeleteFile == state.backup.selectedFile
      and "Confirm Delete Selected Backup Permanently##deleteLibraryBackup"
      or "Delete Selected Backup Permanently##deleteLibraryBackup"
    if dangerButton(deleteBackupLabel, ImGui.GetContentRegionAvail(),
        actionButtonHeight) then
      deleteSelectedLibraryBackup()
    end
    if #backupFiles == 0 then ImGui.EndDisabled() end
    local backupStatus = #backupFiles == 0
      and "Export a complete library backup to create your first backup file."
      or "Choose a backup file to import or permanently delete, or export a new complete backup."
    drawSectionStatus("backup", "##backupStatus", statusHeight, backupStatus,
      #backupFiles > 0 and "ready" or "info")

  end
end

return _ENV
