const fs = require("fs");
const path = require("path");
const assert = require("assert");
const { execFileSync, spawnSync } = require("child_process");

const root = path.resolve(__dirname, "../..");
const mod = "source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)";
const cli = path.join(root, ".audit_lua_runtime/node_modules/fengari-node-cli/src/lua-cli.js");
const fixture = path.join(__dirname, "loading_groups_runtime.lua");

for (const [label, ref] of [["3.1.5", "v3.1.5"], ["4.0.0", "6f226bb"]]) {
  const directory = path.join(root, ".audit_loading_baselines", label);
  const files = execFileSync("git", ["ls-tree", "-r", "--name-only", ref, "--", mod],
    { cwd: root, encoding: "utf8" }).trim().split("\n").filter(file => file.endsWith(".lua"));
  assert(files.length > 0, `No Lua source found for ${ref}`);
  for (const file of files) {
    const destination = path.join(directory, file.slice(mod.length + 1));
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    fs.writeFileSync(destination, execFileSync("git", ["show", `${ref}:${file}`], { cwd: root }));
  }
  run(directory, label);
}
run(path.join(root, mod), "revised");

function run(directory, label) {
  const result = spawnSync(process.execPath, [cli, fixture, path.join(directory, "init.lua"), label],
    { cwd: directory, encoding: "utf8" });
  const output = `${result.stdout || ""}${result.stderr || ""}`;
  assert.strictEqual(result.status, 0, output);
  assert(output.includes(`BENCHMARK ${label}`) && !output.includes("stack traceback:"), output);
  process.stdout.write(output);
}
