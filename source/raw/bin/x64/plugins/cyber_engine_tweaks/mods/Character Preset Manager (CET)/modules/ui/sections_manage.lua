local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime
local commands = require("modules/ui/commands")

drawManageSection = function(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
local detailsOpen=compactSubsectionButton("Advanced Preset Actions","Hide Advanced Preset Actions","presetDetails")
coloredWrapped(0.64,0.67,0.73,1.0,"Rename, copy, favorite, tags, notes, and file details.")
if detailsOpen then
      ImGui.Indent(8)
      local selectedPresetAvailable = state.library.selected
        and state.library.presets[state.library.selected]
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
        local stackActions = ImGui.GetContentRegionAvail() < math.max(ImGui.CalcTextSize("Rename Preset"),ImGui.CalcTextSize("Copy Preset"))*2+48
        local manageButtonWidth = stackActions and ImGui.GetContentRegionAvail() or (ImGui.GetContentRegionAvail()-8)*0.5
        if renameUnavailable then ImGui.BeginDisabled() end
        if ImGui.Button("Rename Preset##renameSelected",
            manageButtonWidth, actionButtonHeight) then commands.run(runtime, "rename") end
        if renameUnavailable then ImGui.EndDisabled() end
        if not stackActions then ImGui.SameLine() end
        if ImGui.Button("Copy Preset##duplicateSelected",
            manageButtonWidth, actionButtonHeight) then commands.run(runtime, "duplicate") end
        do
          ui.pathCallout("##selectedPresetPath", "Preset File", selectedPresetPath)
          if fullWidthButton("Copy File Path##copyPresetPath", actionButtonHeight) then
            commands.run(runtime, "copy_path", {selectedPresetPath = selectedPresetPath})
          end
          ImGui.PushItemWidth(-1)
          state.library.presetTags = ImGui.InputTextWithHint("##presetTags", "Tags", state.library.presetTags, 129)
          state.library.presetNotes = ImGui.InputTextWithHint("##presetNotes", "Notes", state.library.presetNotes, 513)
          ImGui.PopItemWidth()
          if fullWidthButton("Save Preset Details", actionButtonHeight) then
            commands.run(runtime, "metadata")
          end
          local favorite = state.library.presets[state.library.selected].favorite == true
          if fullWidthButton(favorite and "Remove from Favorites##detailFavorite" or "Add to Favorites##detailFavorite", actionButtonHeight) then
            commands.run(runtime,"favorite")
          end
        end
      end
      finishCompactSubsection()
    end
end

return _ENV
