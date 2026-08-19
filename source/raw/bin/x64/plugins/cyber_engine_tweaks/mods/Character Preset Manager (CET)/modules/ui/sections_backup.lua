local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

drawBackupSection = function(presetListHeight, statusHeight, actionButtonHeight, extraHeight,
    narrowTopRow)
  if collapsibleSectionHeader("BACKUP & RECOVERY", "backup") then
    ImGui.TextWrapped("Save or restore the complete preset library, including folders and settings.")
    if fullWidthButton("Export Complete Library Backup##exportLibraryBackup",
        actionButtonHeight) then
      exportLibraryBackup()
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
    if ImGui.BeginCombo("Backup file to import##libraryBackupFile", selectedBackupLabel) then
      for _, backupPath in ipairs(backupFiles) do
        local label = backupPath:match("([^/]+)$") or backupPath
        if ImGui.Selectable(label .. "##backup:" .. backupPath,
            state.backup.selectedFile == backupPath) then
          state.backup.selectedFile = backupPath
          state.status.backup = ""
        end
      end
      ImGui.EndCombo()
    end
    if #backupFiles == 0 then ImGui.BeginDisabled() end
    if fullWidthButton("Import Selected Library Backup##importLibraryBackup",
        actionButtonHeight) then
      importLibraryBackup()
    end
    if #backupFiles == 0 then ImGui.EndDisabled() end
    if state.status.backup ~= "" then
      coloredWrapped(0.64, 0.67, 0.73, 1.0, state.status.backup)
    end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()
    ImGui.TextColored(0.97, 0.72, 0.20, 1.0, "Recover the previous appearance")
    ImGui.TextWrapped("Before a normal preset load, the mod saves the appearance that was active. Use this if you want to undo the most recent preset load.")
    if not fileExists(LAST_APPEARANCE_FILE) then ImGui.BeginDisabled() end
    if fullWidthButton("Restore Appearance from Before Last Load##restoreAppearance",
        actionButtonHeight) then
      state.backup.restoreStatusVisible = true
      restoreLastAppearance()
    end
    if not fileExists(LAST_APPEARANCE_FILE) then ImGui.EndDisabled() end
    if state.backup.restoreStatusVisible then
      drawSectionStatus("load", "##backupRestoreStatus", statusHeight)
    end
  end
end

return _ENV
