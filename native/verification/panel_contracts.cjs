const fs = require("fs");
const path = require("path");
const assert = require("assert");
const root = path.resolve(__dirname, "../..");
const mod = path.join(root, "source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)");
const read = name => fs.readFileSync(path.join(root, name), "utf8");
const panel = read("source/raw/r6/scripts/CharacterPresetManager/Panel.reds");
const bridge = read("source/raw/r6/scripts/CharacterPresetManager/Bridge.reds");
const init = fs.readFileSync(path.join(mod, "init.lua"), "utf8");
const loader = fs.readFileSync(path.join(mod, "modules/native_loader.lua"), "utf8");
const client = fs.readFileSync(path.join(mod, "modules/native_service.lua"), "utf8");
assert(init.includes('registerInput("vanilla_character_presets_toggle"'));
assert(init.includes('"Show/Hide Preset Panel"'));
assert(init.includes('require("modules/native_manager")'));
for (const name of ["SetVisible", "SetInteractive", "SetSupportFocus"]) {
  assert(panel.includes("this.content." + name + "(!this.collapsed)"));
}
assert(panel.includes("this.search.IsFocused() || this.presetName.IsFocused()"));
assert(panel.includes("this.compactStatus.SetVisible(this.collapsed && this.busy)"));
assert(panel.includes("this.compactCancel.GetRootWidget().SetVisible(this.collapsed && this.busy)"));
assert(panel.includes('this.bridge.Request("select", clickedName)'));
assert(panel.includes('this.bridge.Request("load", "")'));
assert(!panel.includes('this.bridge.Request("select_load", clickedName)'));
assert(!panel.includes("SetTranslation(this.m_randomizeGroup"));
assert(panel.includes('this.bridge.Request("compare", "")'));
assert(panel.includes('Equals(fields[0], "SERVICE")'));
assert(panel.includes("!this.serviceReady || this.busy"));
assert(bridge.includes('Equals(this.requestAction, "cancel_load")'));
const toggle = bridge.slice(bridge.indexOf("public func TogglePanelVisibility"), bridge.indexOf("public func UnregisterPanel"));
assert(toggle.includes("IsEnteringText"));
assert(!toggle.includes("this.requestAction ="));
assert(client.includes("status.protocol ~= 1 or status.version ~= VERSION"));
assert(loader.includes("helpers.checkPendingChange"));
assert(loader.includes("helpers.beginPendingChange"));
assert(loader.includes("helpers.finalVerifyUnconfirmed"));
assert(!read("native/src/Main.cpp").includes("ACU Import Request"));
for (const filename of ["catalog", "presets", "comparison", "native_manager"]) {
  const text = fs.readFileSync(path.join(mod, "modules", filename + ".lua"), "utf8");
  assert(!text.includes("io.open("), filename + " performs preset file access in Lua");
}
console.log("Panel contracts passed: explicit loading, visibility/focus guards, collapsed cancellation, compatibility, required service, and staged verification.");
