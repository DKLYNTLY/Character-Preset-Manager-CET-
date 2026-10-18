local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
if setfenv then setfenv(1, runtime) end
local _ENV = runtime

function parentFolder(name)
  return name:match("^(.*)/[^/]+$") or ""
end

function folderDepth(name)
  local depth = 0
  for _ in tostring(name or ""):gmatch("/") do depth = depth + 1 end
  return depth
end

function folderAncestorsExpanded(name, expandedFolders)
  local current = parentFolder(tostring(name or ""))
  while current ~= "" do
    if not (expandedFolders or {})[current] then return false end
    current = parentFolder(current)
  end
  return true
end

function presetPath(name)
  local preset = state.library.presets[name]
  local storage = preset and preset.storage or name
  return PRESET_DIR .. "/" .. storage .. ".preset"
end

function folderPath(name)
  return name == "" and PRESET_DIR or (PRESET_DIR .. "/" .. name)
end


return _ENV
