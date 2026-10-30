local adapter = require("modules/adapters/commands")
local instances = {}
local function forRuntime(runtime)
  local instance = instances[runtime]
  if not instance then
    instance = adapter.new(runtime)
    instances[runtime] = instance
  end
  return instance
end
local function run(runtime, name, input)
  return forRuntime(runtime).run("cet", name, input)
end
return {run = run, forRuntime = forRuntime}
