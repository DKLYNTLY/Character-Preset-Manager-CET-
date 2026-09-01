from pathlib import Path
from tempfile import TemporaryDirectory
from lupa import LuaRuntime


root = Path(__file__).resolve().parents[2]
module = root / "source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/modules/presets.lua"
fixtures = root / "native/verification/fixtures"
default_presets = root / "source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Character Presets/Default Presets"
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
  validatedPresetName = function(value) return value end,
  validRelativePath = function(value) return type(value) == "string" end,
  writeFileSafely = function(path, mode, callback)
    local file = io.open(path, mode)
    if not file then return false end
    local ok, result = pcall(callback, file)
    file:close()
    return ok and result == true
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

legacy = read_preset((fixtures / "cpm-legacy.preset").as_posix(), False)
assert legacy.entryCount == 2
assert legacy.entries[1].key == "LocKey#101"
assert legacy.entries[2].index == 7

current = read_preset((fixtures / "cpm-format-8.preset").as_posix(), False)
assert current.format == 8
assert current.presetName == "Format Eight Test"
assert current.libraryFolder == "Tests/Current"
assert current.favorite is True
assert current.entries[1].slot == "hairstyle"
assert current.entries[1].choice == "options:10"
assert current.entries[1].label == "Hairstyle"
assert lua.globals().runtime.presetTypeName(current) == "CPM"
assert lua.globals().runtime.presetTypeName(legacy) == "ACU"
assert lua.globals().runtime.presetTypeName(old_json) == "ACU"
assert lua.globals().runtime.presetTypeName(lua.table_from({"format": 7})) == "CPM"
assert lua.globals().runtime.presetTypeName(lua.table_from({"format": 9})) == "ACU"

with TemporaryDirectory() as temporary:
    written_path = Path(temporary) / "readable-format-8.preset"
    written = lua.globals().runtime.writePresetContents(
        written_path.as_posix(),
        lua.table_from({
            "format": 8,
            "source": "Character Preset Manager (CET)",
            "presetName": "Readable Test",
            "libraryFolder": "",
            "entries": lua.table_from([
                lua.table_from({
                    "key": "LocKey#404",
                    "index": 15,
                    "label": "Jaw",
                    "slot": "jaw",
                })
            ]),
        }),
    )
    assert written is True
    written_contents = written_path.read_text(encoding="utf-8")
    assert "# Format: 8" in written_contents
    assert "LocKey#404:15\n# Option: Jaw 15\n# Editor slot: jaw" in written_contents
    written_preset = read_preset(written_path.as_posix(), False)
    assert written_preset.entries[1].label == "Jaw"

malformed = read_preset((fixtures / "malformed.preset").as_posix(), False)
assert malformed is None

for default_path in default_presets.glob("*.preset"):
    default_preset = read_preset(default_path.as_posix(), False)
    assert default_preset.format == 8
    assert default_preset.entryCount > 0
    assert all(default_preset.entries[index].label for index in range(1, default_preset.entryCount + 1))

import_module = root / "source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/modules/acu_import.lua"
import_lua = LuaRuntime(unpack_returned_tuples=True)
import_lua.execute(
    r"""
resultContents = "generation\told\nsummary\t0\t0\n"
readCount = 0
headerReadCount = 0
fullResultReadCount = 0
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
    nativeCatalog = { serviceAvailable = false, serviceProbePending = false,
      serviceProbeTimer = 0 },
  },
  readBoundedFile = function(_, maximum)
    if maximum == 128 then
      headerReadCount = headerReadCount + 1
      return resultContents:sub(1, 128)
    end
    fullResultReadCount = fullResultReadCount + 1
    return resultContents
  end,
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
assert import_lua.globals().fullResultReadCount == 1
assert import_runtime.requestAcuImport("startup service check", True) is True
assert import_runtime.state.acuImport.requested is False
assert import_runtime.state.nativeCatalog.serviceProbePending is True
assert import_runtime.state.nativeCatalog.serviceProbeTimer == 0
import_lua.globals().resultContents = (
    "generation\tnew\nsummary\t3\t0\n"
    "file\tACU Presets/female/A.preset\n"
    "file\tACU Presets/female/B.preset\n"
    "file\tACU Presets/male/C.preset\n"
)
import_runtime.updateAcuImport(0.25)
assert import_lua.globals().readCount == 0
assert import_lua.globals().headerReadCount == 1
assert import_lua.globals().fullResultReadCount == 2
assert import_runtime.state.nativeCatalog.serviceAvailable is True
assert import_runtime.state.nativeCatalog.serviceProbePending is False
assert import_runtime.state.nativeCatalog.serviceProbeTimer == 0
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
import_runtime.updateAcuImport(0.25)
assert import_lua.globals().headerReadCount == 2
assert import_lua.globals().fullResultReadCount == 2
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
