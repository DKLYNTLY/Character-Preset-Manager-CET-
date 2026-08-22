local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

drawManageSection = function(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
if collapsibleSectionHeader("RENAME & COPY PRESETS", "manage") then
      local selectedPresetAvailable = state.library.selected
        and state.library.presets[state.library.selected]
      ImGui.TextWrapped("Rename, copy, or edit the selected preset.")
      local manageStatus = state.library.selected
        and "Ready to rename, copy, or edit this preset."
        or "Select a preset under Load & Restore Appearance to rename, copy, or edit it."
      drawSectionStatus("rename", "##renameStatus", statusHeight, manageStatus,
        state.library.selected and "ready" or "info",
        "Selected preset: " .. tostring(state.library.selected or "None"))
      if selectedPresetAvailable then
        local selectedPresetPath =
          "bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/" ..
          presetPath(state.library.selected)
        ImGui.Spacing()
        ImGui.PushItemWidth(-1)
        state.library.renameName = ImGui.InputTextWithHint(
          "##renamePreset", "New preset name", state.library.renameName, 65)
        ImGui.PopItemWidth()
        local renameUnavailable = sanitizeName(state.library.renameName) == ""
        local manageButtonWidth = (ImGui.GetContentRegionAvail() - 8) * 0.5
        if renameUnavailable then ImGui.BeginDisabled() end
        if ImGui.Button("Rename Preset##renameSelected",
            manageButtonWidth, actionButtonHeight) then renamePreset() end
        if renameUnavailable then ImGui.EndDisabled() end
        ImGui.SameLine()
        if ImGui.Button("Copy Preset##duplicateSelected",
            manageButtonWidth, actionButtonHeight) then duplicatePreset() end
        if compactSubsectionButton("Tags, Notes & File",
            "Hide Tags, Notes & File",
            "presetDetails") then
          ImGui.Indent(8)
          ui.pathCallout("##selectedPresetPath", "Preset File", selectedPresetPath)
          if fullWidthButton("Copy File Path##copyPresetPath", actionButtonHeight) then
            ImGui.SetClipboardText(selectedPresetPath)
          end
          ImGui.PushItemWidth(-1)
          state.library.presetTags = ImGui.InputTextWithHint("##presetTags", "Tags", state.library.presetTags, 129)
          state.library.presetNotes = ImGui.InputTextWithHint("##presetNotes", "Notes", state.library.presetNotes, 513)
          ImGui.PopItemWidth()
          if fullWidthButton("Save Preset Details", actionButtonHeight) then
            savePresetMetadata()
          end
          finishCompactSubsection()
        end
      end
    end
end

return _ENV
