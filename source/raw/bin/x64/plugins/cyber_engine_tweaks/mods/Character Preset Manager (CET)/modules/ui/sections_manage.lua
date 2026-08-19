local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

drawManageSection = function(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
if collapsibleSectionHeader("RENAME & COPY PRESETS", "manage") then
      if not state.library.selected or not state.library.presets[state.library.selected] then
        coloredWrapped(0.64, 0.67, 0.73, 1.0,
          "Select a preset under Load & Restore Appearance to rename, copy, or edit it.")
      else
        ImGui.TextColored(0.97, 0.72, 0.20, 1.0,
          "Selected preset")
        ImGui.TextWrapped(state.library.selected)
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
        if compactSubsectionButton("Optional: Tags, Notes & File",
            "Hide Optional Preset Tools",
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
          ImGui.Unindent(8)
        end
        drawSectionStatus("rename", "##renameStatus", statusHeight)
      end
    end
end

return _ENV
