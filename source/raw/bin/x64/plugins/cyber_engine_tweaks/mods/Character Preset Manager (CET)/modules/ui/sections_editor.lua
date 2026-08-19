local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

drawEditorSection = function(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
if collapsibleSectionHeader("OPEN & EDIT APPEARANCE", "editor") then
    ImGui.TextWrapped("Opens the game's full character editor. Apartment mirrors offer the same options.")
    ImGui.Spacing()
    local editorUnavailable = state.editor.openPending or state.app.inCustomization
      or not state.editor.hooksAvailable
    if editorUnavailable then ImGui.BeginDisabled() end
    if fullWidthButton("Open Full Appearance Editor##openEditor", actionButtonHeight) then
      openFullAppearanceEditor()
    end
    if editorUnavailable then ImGui.EndDisabled() end
    local editorStatus = state.editor.openPending
      and "The full appearance editor is opening."
      or (state.app.inCustomization
        and "A character customization screen is already open."
        or (not state.editor.hooksAvailable
          and "The full editor is not available with this game or CET version."
          or "Ready to open the full appearance editor."))
    drawSectionStatus("editor", "##editorStatus", statusHeight, editorStatus,
      not state.editor.openPending and not state.app.inCustomization
        and state.editor.hooksAvailable and "ready" or "info")
    end
end

return _ENV
