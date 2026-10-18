from pathlib import Path

from lupa import LuaRuntime

root = Path(__file__).resolve().parents[2]
modules = root / 'source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/modules'
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
runtime = {
  state = { app = {inCustomization=true, overlayOpen=false},
    editor = {}, load = {}, nativeCatalog = {}, ui = {} },
  helpers = {}, log = function() end,
  nativeManager = {update=function() end},
  nativeService = {available=true},
  nativeAppearance = {},
  updateAcuImport = function() end,
  updateNativeBridge = function() end,
}
setmetatable(runtime, {__index=_G})
package.preload['modules/runtime'] = function() return runtime end
''')
lua.execute(f'dofile([[{modules.as_posix()}/native_bridge.lua]])')
lua.execute(f'events = dofile([[{modules.as_posix()}/events.lua]])')
lua.execute('''
local state = runtime.state
local toggles = 0
local typing = false
local panel = {selected='A', search='hair', scroll=4, collapsed=false}
state.app.nativeBridge = {TogglePanelVisibility=function()
  if typing then return false end
  panel.collapsed = not panel.collapsed
  toggles = toggles + 1
  return true
end}
events.toggleWindow(true)
events.toggleWindow(true)
events.toggleWindow(false)
assert(toggles == 1 and panel.collapsed)
assert(panel.selected == 'A' and panel.search == 'hair' and panel.scroll == 4)
events.toggleWindow(true)
events.toggleWindow(false)
assert(toggles == 2 and not panel.collapsed)
typing = true
events.toggleWindow(true)
events.toggleWindow(false)
assert(toggles == 2)
typing = false
state.app.overlayOpen = true
events.toggleWindow(true)
events.toggleWindow(false)
assert(toggles == 2)
state.app.overlayOpen = false
state.app.inCustomization = false
events.toggleWindow(true)
events.toggleWindow(false)
assert(toggles == 2)
state.app.inCustomization = true
state.load.auto = true
state.load.needsContinue = true
state.app.nativeBridgeSequence = 17
events.toggleWindow(true)
events.toggleWindow(false)
assert(toggles == 3 and state.load.auto and state.load.needsContinue)
assert(state.app.nativeBridgeSequence == 17)
state.app.nativeBridge = nil
events.toggleWindow(true)
events.toggleWindow(false)
assert(toggles == 3)
''')
lua.execute(f'dofile([[{modules.as_posix()}/editor.lua]])')
lua.execute('''
local state = runtime.state
local available, enabled, active, fail = true, true, true, false
local queued = {}
local player = {}
local data = {IsWardrobeEnabled=function() return enabled end}
local system = {
  GetPlayerData=function() return data end,
  QueueRequest=function(_, request)
    if fail then error('equipment busy') end
    table.insert(queued, request.kind)
  end,
}
Game = {
  GetPlayer=function() return player end,
  GetScriptableSystemsContainer=function()
    return {Get=function() return available and system or nil end}
  end,
}
EquipmentSystem = {GetActiveWardrobeSetID=function() return active and 1 or -1 end}
gameWardrobeClothingSetIndex = {INVALID=-1}
QuestDisableWardrobeSetRequest = {new=function() return {kind='disable'} end}
QuestRestoreWardrobeSetRequest = {new=function() return {kind='restore'} end}
assert(runtime.restoreTemporarilyDisabledWardrobe() and #queued == 0)
enabled = false
assert(not runtime.temporarilyDisableWardrobe() and #queued == 0)
enabled = true
fail = true
assert(not runtime.temporarilyDisableWardrobe() and not state.editor.wardrobeTemporarilyDisabled)
fail = false
assert(runtime.temporarilyDisableWardrobe() and #queued == 1)
assert(runtime.temporarilyDisableWardrobe() and #queued == 1)
available = false
assert(not runtime.restoreTemporarilyDisabledWardrobe())
assert(state.editor.wardrobeTemporarilyDisabled)
available = true
fail = true
assert(not runtime.restoreTemporarilyDisabledWardrobe())
assert(state.editor.wardrobeTemporarilyDisabled)
fail = false
state.app.inCustomization = false
state.app.nativeBridge = nil
state.load.auto = false
events.onUpdate(1)
assert(not state.editor.wardrobeTemporarilyDisabled and #queued == 2)
assert(runtime.restoreTemporarilyDisabledWardrobe() and #queued == 2)
active = false
assert(runtime.temporarilyDisableWardrobe() and #queued == 2)
''')
print('Control input and wardrobe behavior passed.')
