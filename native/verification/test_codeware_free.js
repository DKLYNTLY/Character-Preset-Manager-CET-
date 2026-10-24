const assert = require("assert");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");

const root = path.resolve(__dirname, "../..");
const scripts = path.join(root, "source/raw/r6/scripts/CharacterPresetManager");
const sources = fs.readdirSync(scripts).filter(name => name.endsWith(".reds"))
  .map(name => fs.readFileSync(path.join(scripts, name), "utf8"));
for (const source of sources) {
  assert(!/\bCodeware\b|\binkCustomController\b|\bCustomButton\b|\bHubTextInput\b|\bCreateInstance\b/.test(source),
    "A shipped script still needs the removed UI framework");
  const registrations = [...source.matchAll(/\.RegisterTo(?:GlobalInput)?Callback\(n"([^"]+)", (?:this|field|panel), n"([^"]+)"\)/g)];
  for (const [, event, callback] of registrations) {
    assert(source.includes(`func ${callback}(`), `Missing callback method: ${callback}`);
    if (event === "OnInput" || event === "OnBtnClick") continue;
    assert(new RegExp(`\\.UnregisterFrom(?:GlobalInput)?Callback\\(n"${event}", this, n"${callback}"\\)`).test(source),
      `Listener survives cleanup: ${event}/${callback}`);
  }
  if (source.includes("this.listener = target")) {
    assert(source.includes("UnregisterFromCallback(this.listenerEvent, this.listener, this.listenerCallback)"),
      "A helper leaves its caller registered during disposal");
  }
}

const [compiler, bundle] = process.argv.slice(2);
assert(compiler && bundle, "Usage: node native/verification/test_codeware_free.js <redscript-cli> <2.5 base final.redscripts>");
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "cpm-codeware-free-"));
try {
  const output = path.join(temporary, "compiled.redscripts");
  const result = spawnSync(path.resolve(compiler), ["compile", "-s", scripts,
    "-b", path.resolve(bundle), "-o", output], { encoding: "utf8" });
  const log = `${result.stdout || ""}${result.stderr || ""}`;
  assert.strictEqual(result.status, 0, log);
  assert(!/\bERROR\b|Build failed/.test(log), log);
  assert(fs.existsSync(output) && fs.statSync(output).size > 0, log);
  const decompiled = path.join(temporary, "compiled.script");
  const inspect = spawnSync(path.resolve(compiler), ["decompile", "-i", output,
    "-o", decompiled], { encoding: "utf8" });
  assert.strictEqual(inspect.status, 0, `${inspect.stdout}${inspect.stderr}`);
  const compiled = fs.readFileSync(decompiled, "utf8");
  assert(!compiled.includes("Codeware"), "The test bundle contains Codeware; use a clean base cache");
  for (const name of ["CPM.PresetPanel", "CPM.PanelButton", "CPM.PanelTextInput", "CPM.NativeBridge"]) {
    assert(compiled.includes(name), `${name} did not compile into the bundle`);
  }
  for (const name of ["gameuiInGameMenuGameController", "MenuScenario_PauseMenu",
    "MenuScenario_CharacterCustomizationMirror", "MorphMenuUserData"]) {
    assert(compiled.includes(`class ${name} `), `Missing full-editor class: ${name}`);
  }
  for (const name of ["RegisterGlobalBlackboards", "SpawnMenuInstanceEvent", "OnCCOPuppetReady",
    "GetUnitedOptions", "ApplyChangeToOption", "GetRandomizerData"]) {
    assert(compiled.includes(`func ${name}(`), `Missing editor interface: ${name}`);
  }
  console.log("Codeware-free base-game compile and callback cleanup checks: OK");
} finally {
  fs.rmSync(temporary, { recursive: true, force: true });
}
