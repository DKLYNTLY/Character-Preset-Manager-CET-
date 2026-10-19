local constants = require("modules/constants")
local advanced = {}
local overlayOpen = false
local confirmation = false
local function service()
  local ok, value = pcall(function()
    return Game.GetScriptableServiceContainer():GetService(CName.new("CPM.InputService"))
  end)
  return ok and value or nil
end
local function bridge()
  local ok, value = pcall(function()
    return Game.GetScriptableSystemsContainer():Get(CName.new("CPM.NativeBridge"))
  end)
  return ok and value or nil
end
function advanced.overlay(value)
  overlayOpen = value
  local input = service()
  if input then pcall(function() input:SetOverlayOpen(value) end) end
end
function advanced.togglePanel(isDown)
  if isDown == false then return end
  local input = service()
  if input and not overlayOpen then pcall(function() input:TogglePanel() end) end
end
function advanced.openEditor(isDown)
  if isDown == false then return end
  local input = service()
  if input and not overlayOpen then pcall(function() input:OpenEditor() end) end
end
function advanced.draw()
  if not overlayOpen then return end
  if ImGui.Begin("Character Preset Manager - Technical Tools " .. constants.version) then
    ImGui.TextWrapped("Save, load and manage presets inside an appearance editor. This optional menu contains force loading and technical details.")
    local native = bridge()
    if not native or not native:IsReady() then
      ImGui.TextWrapped("Open an appearance editor. If the preset tools do not appear, install matching native files, redscript, RED4ext and Codeware, then restart the game.")
    else
      ImGui.Separator()
      ImGui.TextWrapped("Force Full Load uses less certain matching where it can do so safely. It cannot replace missing named custom choices. Check the appearance afterward.")
      if native:IsBusy() then
        ImGui.Text("Wait for the current action to finish.")
      elseif ImGui.Button(confirmation and "Confirm Force Full Load" or "Force Full Load") then
        if confirmation then native:Request("force_load", ""); confirmation = false
        else confirmation = true end
      end
      if confirmation then
        ImGui.SameLine()
        if ImGui.Button("Cancel") then confirmation = false end
      end
      if ImGui.Button("Read Activity Log") and not native:IsBusy() then native:Request("log", "") end
      if ImGui.Button("Read Editor Options") and not native:IsBusy() then native:Request("diagnostics", "") end
      ImGui.Separator()
      ImGui.TextWrapped(tostring(native:GetDiagnostics() or ""))
    end
  end
  ImGui.End()
end
return advanced
