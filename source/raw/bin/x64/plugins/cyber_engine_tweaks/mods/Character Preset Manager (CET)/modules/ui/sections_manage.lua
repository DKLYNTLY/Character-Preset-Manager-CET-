local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

drawManageSection = function(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
if collapsibleSectionHeader("MANAGE PRESET", "manage") then
      if not state.library.selected or not state.library.presets[state.library.selected] then
        coloredWrapped(0.64, 0.67, 0.73, 1.0,
          "Select a preset under Load Preset to favorite, rename, duplicate, or edit it.")
      else
        local preset = state.library.presets[state.library.selected]
        ImGui.TextColored(0.97, 0.72, 0.20, 1.0,
          "Selected preset")
        ImGui.TextWrapped(state.library.selected)
        local favoriteLabel = preset.favorite == true
          and "Remove Selected Preset from Favorites##favoritePreset"
          or "Add Selected Preset to Favorites##favoritePreset"
        if fullWidthButton(favoriteLabel, actionButtonHeight) then
          toggleSelectedPresetFavorite()
        end
        ImGui.Spacing()
        local selectedPresetPath =
          "bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/" ..
          presetPath(state.library.selected)
        ui.pathCallout("##selectedPresetPath", "Preset File", selectedPresetPath)
        if fullWidthButton("Copy File Path##copyPresetPath", actionButtonHeight) then
          ImGui.SetClipboardText(selectedPresetPath)
        end
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
        if ImGui.Button("Duplicate Preset##duplicateSelected",
            manageButtonWidth, actionButtonHeight) then duplicatePreset() end
        if compactSubsectionButton("Edit Tags & Notes", "Hide Tags & Notes",
            "presetDetails") then
          ImGui.Indent(8)
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
