local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
require("modules/adapters/editor").install(runtime)
return runtime
