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
    drawSectionStatus("editor", "##editorStatus", statusHeight)
    end
end

return _ENV
