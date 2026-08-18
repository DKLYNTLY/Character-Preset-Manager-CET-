local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

drawManageSection = function(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
if collapsibleSectionHeader("RENAME & COPY", "manage") then
      if not state.selected or not state.presets[state.selected] then
        coloredWrapped(0.64, 0.67, 0.73, 1.0,
          "Select a preset under Load Preset to rename, duplicate, or edit its details.")
      else
        ImGui.TextColored(0.97, 0.72, 0.20, 1.0,
          "Selected preset")
        ImGui.TextWrapped(state.selected)
        ImGui.Spacing()
        local selectedPresetPath =
          "bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/" ..
          presetPath(state.selected)
        ui.pathCallout("##selectedPresetPath", "Preset File", selectedPresetPath)
        if fullWidthButton("Copy File Path##copyPresetPath", actionButtonHeight) then
          ImGui.SetClipboardText(selectedPresetPath)
        end
        ImGui.Spacing()
        ImGui.PushItemWidth(-1)
        state.renameName = ImGui.InputTextWithHint(
          "##renamePreset", "New preset name", state.renameName, 65)
        ImGui.PopItemWidth()
        local renameUnavailable = sanitizeName(state.renameName) == ""
        local manageButtonWidth = (ImGui.GetContentRegionAvail() - 8) * 0.5
        if renameUnavailable then ImGui.BeginDisabled() end
        if ImGui.Button("Rename Preset##renameSelected",
            manageButtonWidth, actionButtonHeight) then renamePreset() end
        if renameUnavailable then ImGui.EndDisabled() end
        ImGui.SameLine()
        if ImGui.Button("Duplicate Preset##duplicateSelected",
            manageButtonWidth, actionButtonHeight) then duplicatePreset() end
        if compactSubsectionButton("Optional Preset Details", "Hide Preset Details",
            "presetDetails") then
          ImGui.Indent(8)
          ImGui.PushItemWidth(-1)
          state.presetTags = ImGui.InputTextWithHint("##presetTags", "Tags", state.presetTags, 129)
          state.presetNotes = ImGui.InputTextWithHint("##presetNotes", "Notes", state.presetNotes, 513)
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
