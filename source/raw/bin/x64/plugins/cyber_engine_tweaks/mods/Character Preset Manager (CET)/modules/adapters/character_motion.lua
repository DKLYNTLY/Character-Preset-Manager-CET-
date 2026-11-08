local editorModel = require("modules/application/editor")

local function install(runtime)
  local state = runtime.state
  local typeWarning = false
  local function active()
    return editorModel.cameraBlocked(state.app.inCustomization, state.app.presetCameraHold,
      state.load.auto, state.load.needsContinue)
  end
  local function register(class, method, handler)
    local ok = pcall(runtime.Override, class, method, handler)
    if not ok then
      runtime.log("[MOTION] Character motion could not be paused at " .. method .. ". Preset loading is still available.", "warn")
    end
    return ok
  end
  local registered = 0
  for _, method in ipairs({"OnPanDown", "OnRelativeInput"}) do
    if register("inkCharacterCreationPuppetPreviewGameController", method, function(_, event, wrappedMethod)
      if active() then return false end
      return wrappedMethod(event)
    end) then registered = registered + 1 end
  end
  if register("inkCharacterCreationPuppetPreviewGameController", "OnSetCameraSetupEvent",
      function(_, index, slotName, wrappedMethod)
        if active() then return false end
        return wrappedMethod(index, slotName)
      end) then registered = registered + 1 end
  if register("inkPreviewGameController", "OnAxisInput", function(preview, event, wrappedMethod)
    if active() then
      local ok, customization = pcall(function() return preview:CPMIsCharacterCreationPreview() end)
      if ok and customization == true then return false end
      if not ok and not typeWarning then
        typeWarning = true
        runtime.log("[MOTION] Controller turning could not be paused. Restart with the updated scripts; preset loading is still available.", "warn")
      end
    end
    return wrappedMethod(event)
  end) then registered = registered + 1 end
  if registered == 4 then
    runtime.log("[HOOK] Character turning and option poses pause during preset loading.", "info")
  end
end

return {install=install}
