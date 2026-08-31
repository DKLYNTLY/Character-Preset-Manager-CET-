from pathlib import Path
from lupa import LuaRuntime


root = Path(__file__).resolve().parents[2]
module = root / "source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/modules/presets.lua"
fixtures = root / "native/verification/fixtures"
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(
    """
runtime = {
  state = {}, helpers = {}, MAX_PRESET_BYTES = 1048576,
  MAX_PRESET_LINES = 16448, MAX_PRESET_ENTRIES = 4096,
  MAX_PRESET_KEY_BYTES = 256, CURRENT_PRESET_FORMAT = 8,
  MAX_OPTION_INDEX = 4294967295,
  log = function() end,
  optionIndexValidationError = function(index)
    if type(index) ~= "number" or index ~= math.floor(index)
        or index < 0 or index > 4294967295 then return "invalid" end
    return nil
  end,
  catalogDecode = function(value) return value end,
  stableChoiceIdentity = function(value) return value end,
  sanitizeMetadata = function(value, maximum)
    value = tostring(value or "")
    return value:sub(1, maximum)
  end,
}
setmetatable(runtime, { __index = _G })
package.preload["modules/runtime"] = function() return runtime end
"""
)
lua.execute(f'dofile([[{module.as_posix()}]])')
read_preset = lua.globals().runtime.readPresetFile

old_json = read_preset((fixtures / "acu-3.0.0.preset").as_posix(), False)
assert old_json.entryCount == 1
assert old_json.entries[1].key == "LocKey#100"
assert old_json.entries[1].index == 4
assert old_json.source == "ACU 3.0.0 JSON preset"

new_json = read_preset((fixtures / "acu-3.0.1.preset").as_posix(), False)
assert new_json.entryCount == 1
assert new_json.entries[1].key == "LocKey#300"
assert new_json.entries[1].index == 7
assert new_json.source == "ACU 3.0.1 or newer JSON preset"

text = read_preset((fixtures / "acu-3.2.1.preset").as_posix(), False)
assert text.entryCount == 2
assert text.entries[1].key == "LocKey#500"
assert text.entries[2].index == 3

import_module = root / "source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/modules/acu_import.lua"
import_lua = LuaRuntime(unpack_returned_tuples=True)
import_lua.execute(
    r"""
resultContents = "generation\told\nsummary\t0\t0\n"
readCount = 0
messages = {}
presetCount = function(presets)
  local count = 0
  for _ in pairs(presets) do count = count + 1 end
  return count
end
runtime = {
  MAX_PRESET_BYTES = 1048576, ACU_IMPORT_RESULTS_FILE = "results",
  ACU_IMPORT_REQUEST_FILE = "request", ACU_IMPORT_FILES_PER_FRAME = 2,
  ACU_IMPORT_POLL_SECONDS = 0.25, PRESET_DIR = "Character Presets",
  state = {
    acuImport = { pollTimer = 0, generation = nil, queue = {}, queueIndex = 1,
      imported = 0, rejected = 0, skipped = 0, requestSequence = 0,
      requested = false },
    library = { presets = {}, folders = {}, manualFolders = {},
      ignoredPhysicalFolders = {} },
    load = { auto = false, needsContinue = false, pendingChange = nil },
  },
  readBoundedFile = function() return resultContents end,
  validRelativePath = function(value)
    return type(value) == "string" and value ~= "" and not value:find("\\", 1, true)
  end,
  parentFolder = function(value) return value:match("^(.*)/[^/]+$") or "" end,
  baseName = function(value) return value:match("([^/]+)$") or value end,
  joinFolder = function(folder, leaf)
    return folder == "" and leaf or folder .. "/" .. leaf
  end,
  readPresetFile = function()
    readCount = readCount + 1
    return { entryCount = 1 }
  end,
  fileFingerprint = function() return "fingerprint" end,
  addFolderAncestors = function(folders, folder)
    if folder ~= "" then folders[folder] = true end
  end,
  writeCatalog = function() return true end,
  writeInventory = function() return true end,
  invalidateViewCache = function() end,
  resetLoadState = function() end,
  setStatus = function() end,
  optionKey = function(option) return option.key end,
  log = function(message) messages[#messages + 1] = message end,
  atomicReplace = function() return true end,
  writeFileSafely = function() return true end,
}
setmetatable(runtime, { __index = _G })
package.preload["modules/runtime"] = function() return runtime end
"""
)
import_lua.execute(f'dofile([[{import_module.as_posix()}]])')
import_runtime = import_lua.globals().runtime
import_runtime.initializeAcuImport()
import_lua.globals().resultContents = (
    "generation\tnew\nsummary\t3\t0\n"
    "file\tACU Presets/female/A.preset\n"
    "file\tACU Presets/female/B.preset\n"
    "file\tACU Presets/male/C.preset\n"
)
import_runtime.updateAcuImport(0.25)
assert import_lua.globals().readCount == 0
import_runtime.updateAcuImport(0)
assert import_lua.globals().readCount == 0
assert import_lua.globals().presetCount(import_runtime.state.library.presets) == 2
first_import = import_runtime.state.library.presets["ACU Presets/female/A"]
assert first_import.lazy is True
assert first_import.metadataLoaded is False
assert first_import.entryCountKnown is False
import_runtime.updateAcuImport(0)
assert import_lua.globals().readCount == 0
assert import_lua.globals().presetCount(import_runtime.state.library.presets) == 3
assert len(import_runtime.state.acuImport.queue) == 0
import_lua.execute("messages = {}")

dangerous_preset = import_lua.table_from({
    "storage": "ACU Presets/female/Dangerous",
    "fingerprint": "dangerous-fingerprint",
    "entries": import_lua.table_from([
        import_lua.table_from({"key": "lockEyes", "index": 1}),
        import_lua.table_from({"key": "LocKey#700", "index": 2}),
        import_lua.table_from({"key": "LocKey#800", "index": 3}),
        import_lua.table_from({"key": "LocKey#900", "index": 4}),
    ]),
})
live_options = import_lua.table_from([
    import_lua.table_from({"key": "LocKey#700", "isEditable": False, "isActive": True}),
    import_lua.table_from({"key": "LocKey#800", "isEditable": True, "isActive": True}),
])
dangerous_count = import_runtime.logAcuDangerousOptions(
    dangerous_preset, live_options, "ACU Presets/female/Dangerous"
)
assert dangerous_count == 2
assert len(import_lua.globals().messages) == 2
assert "lockEyes" in import_lua.globals().messages[1]
assert "LocKey#700" in import_lua.globals().messages[2]
assert "LocKey#900" not in "\n".join(import_lua.globals().messages.values())
import_runtime.logAcuDangerousOptions(
    dangerous_preset, live_options, "ACU Presets/female/Dangerous"
)
assert len(import_lua.globals().messages) == 2
