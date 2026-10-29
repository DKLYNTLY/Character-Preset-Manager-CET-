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
  "domain/matching", "domain/comparison", "application/loading", "application/editor",
];
const stage5Globals = new Set(["require", "pairs", "ipairs", "tonumber", "tostring", "type", "math", "table"]);
const stage5Members = { math: new Set(["max", "floor", "min"]), table: new Set(["insert", "sort", "concat"]) };

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

const cp = require("child_process");
const baseline = "0398e1c0dbca93bc3effcc78c019eba6627b6f89";
const redscriptRoot = "source/raw/r6/scripts/CharacterPresetManager/";
function previous(filename) {
  return cp.execFileSync("git", ["show", `${baseline}:${filename}`], {cwd:root, encoding:"utf8"}).replace(/\r\n/g,"\n");
}
function hooks(source) {
  return [...source.matchAll(/@(wrapMethod|replaceMethod|addMethod|replaceGlobal|addField)\(([^)]*)\)\s*([^;{]+)[;{]/g)]
    .map(match => `${match[1]}(${match[2]}):${match[3].replace(/\s+/g," ").trim()}`);
}
for (const filename of ["Panel.reds","Bridge.reds","Options.reds","Voice.reds"]) {
  const before = previous(redscriptRoot+filename);
  const after = fs.readFileSync(path.join(root,redscriptRoot,filename),"utf8").replace(/\r\n/g,"\n");
  const retained = hooks(after);
  for (const hook of hooks(before)) if (!retained.includes(hook)) throw new Error(`Changed redscript hook: ${hook}`);
  if (filename !== "Panel.reds" && before !== after) throw new Error(`Unrelated redscript changed: ${filename}`);
  if (filename === "Panel.reds") {
    function body(text,signature) {
      const start=text.indexOf(signature);if(start<0)throw new Error(`Missing ${signature}`);
      const opening=text.indexOf("{",start);let depth=1,end=opening+1;
      for(;depth && end<text.length;end++){if(text[end]==="{")depth++;if(text[end]==="}")depth--;}
      return text.slice(opening+1,end-1);
    }
    for (const [callback,helper] of [["OnInitialize() -> Bool","CPMInitializePresetPanel() -> Void"],["OnUninitialize() -> Bool","CPMTeardownPresetPanel() -> Void"]]) {
      const signature=`protected cb func ${callback}`;
      const wrapperStart=after.indexOf("@wrapMethod(characterCreationBodyMorphMenu)\n"+signature);
      const oldStart=before.indexOf("@wrapMethod(characterCreationBodyMorphMenu)\n"+signature);
      const expanded=body(after.slice(wrapperStart),signature).replace(`this.${helper.split(" -> ")[0]};`,body(after,`private func ${helper}`));
      if (expanded.replace(/\s/g,"")!==body(before.slice(oldStart),signature).replace(/\s/g,"")) throw new Error(`Changed lifecycle body/order: ${callback}`);
    }
    const blockStart="@wrapMethod(characterCreationBodyMorphMenu)\nprotected cb func OnInitialize()";
    const blockEnd="@addMethod(characterCreationBodyMorphMenu)\npublic func CPMCanRandomize()";
    if(before.slice(0,before.indexOf(blockStart))!==after.slice(0,after.indexOf(blockStart)) || before.slice(before.indexOf(blockEnd))!==after.slice(after.indexOf(blockEnd))) throw new Error("Unrelated panel layout/hook changed");
    const added=retained.filter(hook=>!hooks(before).includes(hook));
    if(added.length!==2 || added.some(hook=>!hook.startsWith("addMethod(characterCreationBodyMorphMenu):private func CPM"))) throw new Error("Unexpected new redscript declaration");
  }
}
console.log("All original redscript targets/signatures retained; expanded lifecycle calls/order and unrelated panel source match baseline.");

const oldLifecycleGlobals = new Set(["editor.lua","events.lua","adapters/game_options.lua"].flatMap(filename =>
  parser.parse(previous("source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/modules/"+filename), {luaVersion:"5.1",scope:true}).globals.map(global=>global.name)));
for(const name of ["adapters/editor","adapters/cet_hooks"]){
  const ast=parser.parse(fs.readFileSync(path.join(mod,"modules",name+".lua"),"utf8"),{luaVersion:"5.1",scope:true});
  for(const global of ast.globals)if(!oldLifecycleGlobals.has(global.name))throw new Error(`New editor adapter global: ${global.name}`);
  console.log(`${name} baseline globals verified: ${ast.globals.map(global=>global.name).sort().join(", ")}`);
}
