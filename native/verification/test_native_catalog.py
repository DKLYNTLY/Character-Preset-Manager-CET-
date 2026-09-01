from pathlib import Path
from lupa import LuaRuntime


root = Path(__file__).resolve().parents[2]
module = root / "source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/modules/native_catalog.lua"
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(
    r'''
catalogContents = table.concat({
  "protocol\t1",
  "generation\t123",
  "summary\t2\t2\t0",
  "directory\tFolder",
  "directory\tFolder/Nested",
  "file\tFolder/Old.preset\t12\t44\t2:12:123:456",
  "file\tFolder/Nested/Share.cpmfolder\t24\t45\t2:24:789:1011",
}, "\n") .. "\n"
runtime = {
  NATIVE_FILE_CATALOG = "catalog", MAX_CATALOG_BYTES = 8388608,
  MAX_LIBRARY_BACKUP_BYTES = 268435456, NATIVE_FILE_PROTOCOL = 1,
  MAX_TREE_DEPTH = 12, PRESET_DIR = "Character Presets",
  state = { nativeCatalog = {} },
  readBoundedFile = function() return catalogContents end,
  validRelativePath = function(value)
    return type(value) == "string" and value ~= "" and not value:find("\\", 1, true)
      and not value:find("..", 1, true)
  end,
  parentFolder = function(value) return value:match("^(.*)/[^/]+$") or "" end,
  baseName = function(value) return value:match("([^/]+)$") or value end,
  joinFolder = function(folder, leaf) return folder == "" and leaf or folder .. "/" .. leaf end,
  folderPath = function(relative) return relative == "" and "Character Presets" or "Character Presets/" .. relative end,
  readFiles = {
    [""] = { { name = "Folder", type = "directory" } },
    ["Folder"] = {
      { name = "Nested", type = "directory" },
      { name = "Old.preset", type = "file" },
    },
    ["Folder/Nested"] = { { name = "Share.cpmfolder", type = "file" } },
  },
  safeDirectoryEntries = function(path)
    local relative = path:gsub("^Character Presets/?", "")
    return runtime.readFiles[relative]
  end,
  log = function() end,
}
setmetatable(runtime, { __index = _G })
package.preload["modules/runtime"] = function() return runtime end
'''
)
lua.execute(f'dofile([[{module.as_posix()}]])')
runtime = lua.globals().runtime

catalog = runtime.readNativeFileCatalog()
assert catalog.protocol == 1
assert len(catalog.files) == 2
assert len(catalog.directories) == 2
root_entries = runtime.nativeCatalogDirectoryEntries(catalog, "", 0)
assert len(root_entries) == 1
assert root_entries[1].name == "Folder"
verified = runtime.verifiedNativeFileCatalog()
assert verified.generation == "123"
assert runtime.state.nativeCatalog.available is True

runtime.readFiles["Folder"][2] = None
fallback = runtime.verifiedNativeFileCatalog()
assert fallback is None
assert runtime.state.nativeCatalog.available is False
assert "stale" in runtime.state.nativeCatalog.fallbackReason
runtime.readFiles["Folder"][2] = lua.table_from({"name": "Old.preset", "type": "file"})

lua.globals().catalogContents = lua.globals().catalogContents.replace(
    "protocol\t1", "protocol\t2"
)
invalid, reason = runtime.readNativeFileCatalog()
assert invalid is None
assert "protocol" in reason

lua.globals().catalogContents = lua.globals().catalogContents.replace(
    "protocol\t2", "protocol\t1"
).replace("summary\t2\t2\t0", "summary\t3\t2\t0")
invalid, reason = runtime.readNativeFileCatalog()
assert invalid is None
assert "summary" in reason
