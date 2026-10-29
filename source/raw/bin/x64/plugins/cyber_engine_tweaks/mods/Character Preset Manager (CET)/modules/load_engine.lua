local runtime = assert(require("modules/runtime"),
  "Character Preset Manager runtime did not load")
local gameOptions = require("modules/adapters/game_options")
gameOptions.install(runtime)
return runtime
