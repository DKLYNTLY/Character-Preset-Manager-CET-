const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "../..");
const installedParser = path.join(root, ".audit_lua_parser/node_modules/luaparse");
const parser = require(fs.existsSync(installedParser) ? installedParser : "luaparse");
const mod = path.join(root, "source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)");
let count = 0;

function check(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const filename = path.join(directory, entry.name);
    if (entry.isDirectory()) check(filename);
    else if (entry.name.endsWith(".lua")) {
      parser.parse(fs.readFileSync(filename, "utf8"), { luaVersion: "5.1" });
      count++;
    }
  }
}

check(mod);
console.log(`Lua code parsing passed: ${count} files.`);
