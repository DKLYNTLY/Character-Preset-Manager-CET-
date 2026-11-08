local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime
local commands = require("modules/ui/commands")

drawEditorSection = function(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
if collapsibleSectionHeader("OPEN IN-GAME CHARACTER CREATOR", "editor") then
    ImGui.TextWrapped("Open the full character editor here or use an apartment mirror. Both show the same options.")
    local editorUnavailable = state.editor.openPending or state.app.inCustomization
      or not state.editor.hooksAvailable
    ImGui.Spacing()
    if editorUnavailable then ImGui.BeginDisabled() end
    if fullWidthButton("Open In-Game Character Creator##openEditor", actionButtonHeight) then
      commands.run(runtime, "open_editor")
    end
    if editorUnavailable then ImGui.EndDisabled() end
    end
end

return _ENV
