from pathlib import Path

from lupa import LuaRuntime


root = Path(__file__).resolve().parents[2]
catalog = root / "source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/modules/catalog.lua"
bridge = root / "source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/modules/native_bridge.lua"
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(
    r"""
runtime = {
  VERSION = "3.1.0", NATIVE_BRIDGE_PROTOCOL = 1, NATIVE_LIST_LIMIT = 100,
  NATIVE_READY_STATUS = "Ready", NATIVE_REQUEST_POLL_SECONDS = 0.1,
  EMPTY_LIST = {},
  state = {
    app = { nativePanelStatus = "", nativePanelStatusError = false,
      nativePanelShowDetails = false, nativeBridgeUnavailableLogged = false },
    library = { selected = nil, selectedFolder = "", pendingOverwriteName = nil,
      presets = {
        ["ACU Presets/Female/Alina"] = { storage = "ACU Presets/Female/Alina" },
        ["Default Presets/Female/Default"] = { storage = "Default Presets/Female/Default" },
      },
      folders = {
        ["ACU Presets"] = true, ["ACU Presets/Female"] = true,
        ["Default Presets"] = true, ["Default Presets/Female"] = true,
      },
      expandedLoadFolders = {},
    },
    cache = { revision = 1, folderPresetCounts = {
      ["ACU Presets"] = 1, ["ACU Presets/Female"] = 1,
      ["Default Presets"] = 1, ["Default Presets/Female"] = 1,
    } },
    load = { auto = false, needsContinue = false,
      recoverySnapshotAvailable = false },
    trash = { nativePendingDeleteName = nil },
    ui = { openSections = {} },
    status = { sections = { load = { message = "", error = false } } },
  },
  helpers = {},
  log = function() end,
  clean = function(value) return value end,
  sortedFolderNames = function()
    return { "ACU Presets", "ACU Presets/Female",
      "Default Presets", "Default Presets/Female" }
  end,
  baseName = function(value) return value:match("([^/]+)$") or value end,
  folderNameExists = function(value) return runtime.state.library.folders[value] == true end,
}
runtime.helpers.sortedPresetNames = function()
  return { "ACU Presets/Female/Alina", "Default Presets/Female/Default" }
end
runtime.helpers.breadcrumb = function(value) return value end
runtime.helpers.presetsInFolder = function(folder)
  if folder == "ACU Presets/Female" then return { "ACU Presets/Female/Alina" } end
  if folder == "Default Presets/Female" then return { "Default Presets/Female/Default" } end
  return {}
end
runtime.state.presetEntryCount = function() return 0 end
setmetatable(runtime, { __index = _G })
package.preload["modules/runtime"] = function() return runtime end
captured = ""
fakeBridge = {
  SetLuaReady = function() return true end,
  GetRequestSequence = function() return 0 end,
  HasPanels = function() return true end,
  Sync = function(_, _, payload) captured = payload return true end,
}
"""
)
lua.execute(f'dofile([[{catalog.as_posix()}]])')
lua.execute(f'dofile([[{bridge.as_posix()}]])')
runtime = lua.globals().runtime

assert runtime.folderAncestorsExpanded("ACU Presets", lua.table()) is True
assert runtime.folderAncestorsExpanded("ACU Presets/Female", lua.table()) is False

runtime.initializeNativeBridge(True, lua.globals().fakeBridge)
collapsed = lua.globals().captured
assert "ROW\tFOLDER\tACU Presets\t[+] ACU Presets (1)" in collapsed
assert "ROW\tSUBFOLDER\tACU Presets/Female" not in collapsed
assert "ROW\tSUBFOLDER\tDefault Presets/Female" not in collapsed

runtime.state.library.expandedLoadFolders["ACU Presets"] = True
runtime.state.cache.revision = 2
runtime.initializeNativeBridge(True, lua.globals().fakeBridge)
parent_open = lua.globals().captured
assert "ROW\tSUBFOLDER\tACU Presets/Female\t> [+] Female (1)" in parent_open
assert "ROW\tPRESET\tACU Presets/Female/Alina" not in parent_open
assert "ROW\tSUBFOLDER\tDefault Presets/Female" not in parent_open

runtime.state.library.expandedLoadFolders["ACU Presets/Female"] = True
runtime.state.cache.revision = 3
runtime.initializeNativeBridge(True, lua.globals().fakeBridge)
child_open = lua.globals().captured
assert "ROW\tPRESET\tACU Presets/Female/Alina" in child_open
