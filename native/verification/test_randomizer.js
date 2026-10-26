const fs = require("fs");
const path = require("path");
const assert = require("assert");
const { spawnSync } = require("child_process");

const root = path.resolve(__dirname, "../..");
const mod = path.join(root, "source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)");
const parserPath = path.join(root, ".audit_lua_parser/node_modules/luaparse");
const parser = require(fs.existsSync(parserPath) ? parserPath : "luaparse");
const installedCli = path.join(root, ".audit_lua_runtime/node_modules/fengari-node-cli/src/lua-cli.js");
const cli = fs.existsSync(installedCli) ? installedCli : require.resolve("fengari-node-cli/src/lua-cli.js");
const read = name => fs.readFileSync(path.join(mod, name), "utf8");
function parseDirectory(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const filename = path.join(directory, entry.name);
    if (entry.isDirectory()) parseDirectory(filename);
    else if (entry.name.endsWith(".lua")) parser.parse(fs.readFileSync(filename, "utf8"), { luaVersion: "5.3" });
  }
}
parseDirectory(path.join(mod, "modules"));
parser.parse(read("init.lua"), { luaVersion: "5.3" });
const panel = fs.readFileSync(path.join(root, "source/raw/r6/scripts/CharacterPresetManager/Panel.reds"), "utf8");
const bridge = read("modules/native_bridge.lua");
const editor = read("modules/ui/sections_editor.lua");
const events = read("modules/events.lua");
for (const source of [read("init.lua"), events, read("modules/ui/help_panel.lua")]) {
  assert(!source.includes("vanilla_character_presets_toggle"), "removed binding remains");
  assert(!source.includes("events.toggleWindow"), "removed handler remains");
}
for (const action of ["randomize", "randomize_settings"]) {
  assert(panel.includes(`this.bridge.Request("${action}", "")`), `missing panel action: ${action}`);
  assert(bridge.includes(`if action == "${action}" then return runAppearanceRandomizer(`), `missing shared action: ${action}`);
}
for (const required of ["runAppearanceRandomizer(false)", "runAppearanceRandomizer(true)", "canRunAppearanceRandomizer()"]) {
  assert(editor.includes(required), `missing CET action: ${required}`);
}
for (const required of ["bridge.IsLuaReady()", "SetVisible(this.m_randomizeGroup, !ready)",
    "SetNavigable(!ready)", "settings.Reparent(this.GetRootCompoundWidget())",
    "GetRandomizerData()", "bridge.IsBusy()", "this.m_introComplete",
    "BusySwitchingReason.AVAILABLE", "PanelFrame.Create(root)", "index < 4",
    "inkEAnchor.BottomFillHorizontaly", "inkEAnchor.RightFillVerticaly", "evt.Handle()"] ) {
  assert(panel.includes(required), `missing native guard or frame: ${required}`);
}
assert(!panel.includes("SetTranslation(this.m_randomizeGroup"), "original controls are still moved downward");
const result = spawnSync(process.execPath,
  [cli, path.join(__dirname, "randomizer_runtime.lua"), path.join(mod, "init.lua")],
  { cwd: mod, encoding: "utf8" });
const output = `${result.stdout || ""}${result.stderr || ""}`;
assert.strictEqual(result.status, 0, output);
assert(output.includes("Randomizer runtime smoke test: OK") && !output.includes("stack traceback:"), output);
process.stdout.write(output);
const appearance = spawnSync(process.execPath,
  [cli, path.join(__dirname, "appearance_load_runtime.lua"), path.join(mod, "init.lua")],
  { cwd: mod, encoding: "utf8" });
const appearanceOutput = `${appearance.stdout || ""}${appearance.stderr || ""}`;
assert.strictEqual(appearance.status, 0, appearanceOutput);
assert(appearanceOutput.includes("Appearance load runtime test: OK") && !appearanceOutput.includes("stack traceback:"), appearanceOutput);
process.stdout.write(appearanceOutput);
const uncached = spawnSync(process.execPath,
  [cli, path.join(__dirname, "appearance_load_runtime.lua"), path.join(mod, "init.lua"), "uncached"],
  { cwd: mod, encoding: "utf8" });
const uncachedOutput = `${uncached.stdout || ""}${uncached.stderr || ""}`;
assert.strictEqual(uncached.status, 0, uncachedOutput);
assert(uncachedOutput.includes("Appearance load runtime test: OK") && !uncachedOutput.includes("stack traceback:"), uncachedOutput);
console.log("Uncached appearance load comparison: OK");
const advanced = spawnSync(process.execPath,
  [cli, path.join(__dirname, "advanced_menu_runtime.lua"), path.join(mod, "init.lua")],
  { cwd: mod, encoding: "utf8" });
const advancedOutput = `${advanced.stdout || ""}${advanced.stderr || ""}`;
assert.strictEqual(advanced.status, 0, advancedOutput);
assert(advancedOutput.includes("Advanced menu runtime test: OK") && !advancedOutput.includes("stack traceback:"), advancedOutput);
process.stdout.write(advancedOutput);
console.log("Lua parsing and randomizer panel checks: OK");
const groups = spawnSync(process.execPath,
  [cli, path.join(__dirname, "loading_groups_runtime.lua"), path.join(mod, "init.lua")],
  { cwd: mod, encoding: "utf8" });
const groupsOutput = `${groups.stdout || ""}${groups.stderr || ""}`;
assert.strictEqual(groups.status, 0, groupsOutput);
assert(groupsOutput.includes("Loading groups runtime test: OK") && !groupsOutput.includes("stack traceback:"), groupsOutput);
process.stdout.write(groupsOutput);
