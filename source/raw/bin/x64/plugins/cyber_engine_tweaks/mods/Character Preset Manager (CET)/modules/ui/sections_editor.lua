local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime
local commands = require("modules/ui/commands")

drawEditorSection = function(presetListHeight, statusHeight, actionButtonHeight, extraHeight, narrowTopRow)
if collapsibleSectionHeader("OPEN & EDIT APPEARANCE", "editor") then
    ImGui.TextWrapped("Open the full character editor here or use an apartment mirror. Both show the same options.")
    local editorUnavailable = state.editor.openPending or state.app.inCustomization
      or not state.editor.hooksAvailable
    local editorStatus = state.editor.openPending
      and "Opening the full appearance editor."
      or (state.app.inCustomization
        and "A character editor is already open."
        or (not state.editor.hooksAvailable
          and "This game or CET version does not support the full editor."
          or "Ready to open the full editor."))
    drawSectionStatus("editor", "##editorStatus", statusHeight, editorStatus,
      not state.editor.openPending and not state.app.inCustomization
        and state.editor.hooksAvailable and "ready" or "info",
      "Editor state: " .. (state.editor.openPending and "Opening"
        or (state.app.inCustomization and "Open"
          or (state.editor.hooksAvailable and "Available" or "Unavailable"))))
    ImGui.Spacing()
    local randomizerAvailable = canRunAppearanceRandomizer()
    if not randomizerAvailable then ImGui.BeginDisabled() end
    if fullWidthButton("Randomize##appearanceRandomize", actionButtonHeight) then
      commands.run(runtime, "randomize", {available = randomizerAvailable})
    end
    if fullWidthButton("Randomize Settings##appearanceRandomizeSettings", actionButtonHeight) then
      commands.run(runtime, "randomize_settings", {available = randomizerAvailable})
    end
    if not randomizerAvailable then ImGui.EndDisabled() end
    if state.editor.pendingRandomizeSettings then
      ImGui.TextWrapped("Close CET to open the game's Randomize Settings.")
    end
    ImGui.Spacing()
    if editorUnavailable then ImGui.BeginDisabled() end
    if fullWidthButton("Open Full Appearance Editor##openEditor", actionButtonHeight) then
      commands.run(runtime, "open_editor")
    end
    if editorUnavailable then ImGui.EndDisabled() end
    end
end

return _ENV
