const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "../..");
const installedParser = path.join(root, ".audit_lua_parser/node_modules/luaparse");
const parser = require(fs.existsSync(installedParser) ? installedParser : "luaparse");
const mod = path.join(root, "source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)");
let count = 0;
const stage5Modules = [
  "domain/library", "domain/library_view", "domain/folders",
  "domain/catalog_codec", "application/library",
  "domain/bundle_codec", "domain/backup_codec", "domain/trash",
  "domain/appearance_history", "application/recovery_items",
];
const stage5Globals = new Set(["require", "pairs", "ipairs", "tonumber", "tostring", "type", "math", "table"]);
const stage5Members = { math: new Set(["max"]), table: new Set(["insert", "sort", "concat"]) };

function checkStage5(node, filename) {
  if (!node || typeof node !== "object") return;
  if (node.type === "MemberExpression" && node.base.type === "Identifier"
      && node.base.isLocal === false && stage5Members[node.base.name]
      && !stage5Members[node.base.name].has(node.identifier.name)) {
    throw new Error(`Unverified library member in ${filename}: ${node.base.name}.${node.identifier.name}`);
  }
  for (const value of Object.values(node)) {
    if (Array.isArray(value)) value.forEach(item => checkStage5(item, filename));
    else if (value && typeof value === "object") checkStage5(value, filename);
  }
}

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
for (const name of stage5Modules) {
  const filename = path.join(mod, "modules", `${name}.lua`);
  const ast = parser.parse(fs.readFileSync(filename, "utf8"), { luaVersion: "5.1", scope: true });
  for (const global of ast.globals) {
    if (!stage5Globals.has(global.name)) throw new Error(`Unverified global in ${name}: ${global.name}`);
  }
  checkStage5(ast, name);
  console.log(`${name} globals verified: ${ast.globals.map(global => global.name).sort().join(", ")}`);
}
