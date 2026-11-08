local function new(runtime)
  local owner
  local generation = 0
  local function release()
    generation = generation + 1
    local previous = owner
    owner = nil
    if not previous then return true end
    local ok, released = pcall(function() return previous:CPMSetLoadProtected(false) end)
    if not ok or released ~= true then
      runtime.log("[LOAD INPUT] Input protection could not be released. Back and editor close remain available.", "warn")
      return false
    end
    return true
  end
  local function acquire()
    local menu = runtime.state.editor.activeBodyMorphMenu
    if menu and owner == menu then return true end
    if not release() then return false end
    local acquiredGeneration = generation
    if menu then
      local ok, acquired = pcall(function() return menu:CPMSetLoadProtected(true) end)
      if ok and acquired == true and generation == acquiredGeneration
          and runtime.state.editor.activeBodyMorphMenu == menu
          and runtime.state.app.inCustomization then
        owner = menu
        return true
      end
      pcall(function() menu:CPMSetLoadProtected(false) end)
    end
    runtime.setStatus("load", "Loading stopped because input protection is unavailable. Restart the game with the updated scripts.", true)
    return false
  end
  return {acquire=acquire,release=release,active=function() return owner ~= nil end}
end

return {new=new}
