local function new(ports)
  local active = false

  local function reset()
    active = false
    ports.identityBatch.reset()
  end

  local function changed()
    ports.identityBatch.changed()
  end

  local function run(system, options, preset, ...)
    if not active then
      active = true
      ports.log(("[LEGACY ACU LOAD] Loading ACU preset format %s.")
        :format(tostring(preset.format or 4)), "info")
    end
    if preset.importKind == "acu-v2" then
      return ports.identityBatch.run(system, options, preset)
    end
    return ports.loadEntries(system, options, preset, ...)
  end

  return {run=run,reset=reset,changed=changed}
end

return {new=new}
