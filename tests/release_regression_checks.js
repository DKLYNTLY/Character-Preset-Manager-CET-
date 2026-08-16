const fs = require("fs");
const path = require("path");
const childProcess = require("child_process");

const root = path.resolve(__dirname, "..");
const sourcePath = path.join(root, "source", "raw", "bin", "x64", "plugins",
  "cyber_engine_tweaks", "mods", "Character Preset Manager (CET)", "init.lua");
const source = fs.readFileSync(sourcePath, "utf8");

function requireText(text, message) {
  if (!source.includes(text)) throw new Error(message);
}

function rejectText(text, message) {
  if (source.includes(text)) throw new Error(message);
}

function requireMatch(pattern, message) {
  if (!pattern.test(source)) throw new Error(message);
}

requireText('local VERSION = "3.0.4"', "The mod version changed unexpectedly.");
requireText("local helpers = {}",
  "Shared low-use helpers no longer use the main helper table.");
rejectText("local closeActivityLog\n\ndo\n",
  "Core helpers are scoped away from the menu and event handlers.");
requireMatch(/local helpers = \{\}\s+local closeActivityLog\s+local activityLogFile/,
  "Core helpers are no longer in the menu's visible Lua scope.");
for (const helper of ["auditSection", "breadcrumb", "sortedPresetNames", "setStatus"]) {
  requireText(`local function ${helper}`,
    `${helper} is no longer a visible local helper.`);
}
requireText("helpers.clearSectionStatuses()",
  "Overlay status cleanup can no longer reach its shared helper.");
requireMatch(/not metadataOnly and readableFormatConfirmed\s+and readableKey == "Saved choice"/,
  "Format-8 choice details are no longer gated by the format header.");
requireMatch(/not metadataOnly and readableFormatConfirmed\s+and readableKey == "Editor slot"/,
  "Format-8 editor positions are no longer gated by the format header.");
requireText("readBoundedFile(INVENTORY_FILE, MAX_CATALOG_BYTES)",
  "The startup preset list is no longer size-limited.");
requireText("AUTO_LOAD_LIMITS.passesPerOption",
  "Automatic loading no longer scales with the preset size.");
rejectText("loadSnapshot",
  "Automatic loading must rescan the live editor instead of retaining game option references.");
rejectText("loadCursor",
  "Automatic loading must restart from the live editor list after every change.");
rejectText("AUTO_LOAD_FAST_INTERVAL",
  "Automatic loading must not use the removed fast snapshot interval.");
requireText("state.loadCleanupAttempts[cleanupKey] = attempts + 1",
  "Cleanup can retry the same editor option forever.");
requireText('state.logLoadOnce("cleanup-not-sticking:" .. cleanupKey',
  "Cleanup no longer reports and skips an option that refuses to stay cleared.");
requireText("state.logLoadOnce",
  "Repeated loading warnings are no longer deduplicated.");
requireText("readPresetFile(path, metadataOnly)",
  "Preset files no longer support lightweight startup records.");
requireText("entries = not metadataOnly and entries or nil",
  "Metadata-only reads can incorrectly keep an empty entries table.");
rejectText("entries = metadataOnly and nil or entries",
  "The broken metadata-only Lua expression returned.");
rejectText("selectedForBulk and nil or true",
  "Selected presets can no longer be removed from a bulk selection.");
requireText("state.hydratePreset",
  "Lightweight presets can no longer be loaded fully on demand.");
requireText("hydrateNamedPreset",
  "Named preset hydration is no longer shared by preset actions.");
requireText('type(previousPresets[inventoryName]) == "table"',
  "Startup no longer reuses lightweight records for known presets.");
requireText('preset = readPresetFile(path .. "/" .. filename, true)',
  "New presets are no longer checked safely during startup.");
requireText('line:match("^P2\\t',
  "The startup inventory no longer stores lightweight preset details.");
requireText('count ~= "-" and not entryCount',
  "Malformed preset counts can be accepted as unknown inventory values.");
requireText('format ~= "-" and not presetFormat',
  "Malformed preset formats can be accepted as unknown inventory values.");
requireMatch(/preset and preset\.entryCountKnown == true\s+and state\.presetEntryCount\(preset\) or nil/,
  "Unknown preset counts can be written to the inventory as real zeroes.");
requireMatch(/local entryCount = preset\.entryCountKnown == true\s+and state\.presetEntryCount\(preset\) or 0/,
  "Preset scans can treat an unknown option count as a real zero.");
rejectText('readPresetFile(TRASH_DIR .. "/" .. entry.name',
  "Startup Trash discovery parses every trashed preset again.");
requireText("maximumScannedEntries",
  "Preset scanning no longer has a total saved-option limit.");
requireText("local entries, listError = safeDirectoryEntries(TRASH_DIR, 0)",
  "Trash refresh no longer checks directory-read failures before replacing state.");
requireText("The last good Trash list was kept.",
  "Trash refresh no longer explains that it preserves the last good state.");
requireText("local function writeHexFile(output, path)",
  "Shared-folder export no longer streams preset contents.");
requireText("local function inspectFolderBundle(filename)",
  "Shared-folder import no longer validates bundles without reading the whole file.");
rejectText("readBoundedFile(filename, MAX_FOLDER_BUNDLE_BYTES)",
  "Shared-folder import reads the complete bundle into memory again.");
requireText("state.ensureTrashViewCache()",
  "The Trash panel no longer uses its cached sorted view.");
requireText("invalidatePresetAndTrashCaches",
  "Preset and Trash cache invalidation is no longer consolidated.");
requireText("state.hydratePreset(preset, presetPath(name))",
  "Folder duplication no longer loads lightweight source presets before checking copies.");
requireText("readVerifiedPresetCopy",
  "Copied presets no longer share full read-back verification.");
requireText("cleanupFailureMessage",
  "Partial-copy cleanup no longer shares its result handling.");
requireText("clearStatus(section)",
  "Repeated panel status resets are no longer consolidated.");
rejectText('invalidateViewCache()\n  state.invalidateTrashViewCache()',
  "Preset and Trash caches are invalidated separately again.");
rejectText('state.bulkStatus = ""\n    state.bulkStatusError = false',
  "Bulk panel status resets are duplicated again.");
requireText("local _, refreshed, changes = refreshPresets(\"external\")",
  "Refresh no longer reuses the scan's change counts.");
requireText("PREFLIGHT_REFRESH_INTERVAL",
  "Selected-preset compatibility text no longer refreshes automatically.");
requireText("closeActivityLog()",
  "The buffered activity log no longer has a close and flush checkpoint.");
rejectText("advancedDiagnosticsOpen",
  "Unused advanced diagnostics state returned.");
rejectText("activePosition",
  "Unused exposed-option position state returned.");
requireText('return "2:" .. legacy .. ":" .. tostring(secondHash), legacy',
  "The stronger file check or its older-format result is missing.");
requireText('item.fingerprint:match("^%d+:%d+$")',
  "Older shared-folder records are no longer accepted.");
rejectText("local statusSuccess = {}",
  "Status colors depend on message wording again.");

const overlayStart = source.indexOf('registerForEvent("onOverlayOpen"');
const overlayEnd = source.indexOf('registerForEvent("onOverlayClose"', overlayStart);
if (overlayStart < 0 || overlayEnd < 0) throw new Error("Overlay events could not be found.");
const overlayHandler = source.slice(overlayStart, overlayEnd);
if (overlayHandler.includes("refreshPresets(") || overlayHandler.includes("refreshTrash(")) {
  throw new Error("Opening the overlay performs a full preset or Trash scan again.");
}

const parserPath = path.join(root, ".audit_lua_parser", "node_modules", "luaparse");
if (fs.existsSync(parserPath)) {
  const luaparse = require(parserPath);
  const syntaxTree = luaparse.parse(source, {
    luaVersion: "5.3", scope: true, locations: true,
  });
  function mainBlockLocalUsage(statements, startingLocals) {
    let active = startingLocals;
    let maximum = startingLocals;
    for (const statement of statements || []) {
      if (statement.type === "LocalStatement") {
        active += (statement.variables || []).length;
        maximum = Math.max(maximum, active);
      } else if (statement.type === "FunctionDeclaration" && statement.isLocal) {
        active += 1;
        maximum = Math.max(maximum, active);
      } else if (statement.type === "DoStatement" || statement.type === "WhileStatement" ||
          statement.type === "RepeatStatement") {
        maximum = Math.max(maximum,
          mainBlockLocalUsage(statement.body, active).maximum);
      } else if (statement.type === "IfStatement") {
        for (const clause of statement.clauses || []) {
          maximum = Math.max(maximum,
            mainBlockLocalUsage(clause.body, active).maximum);
        }
      } else if (statement.type === "ForNumericStatement") {
        maximum = Math.max(maximum,
          mainBlockLocalUsage(statement.body, active + 1).maximum);
      } else if (statement.type === "ForGenericStatement") {
        maximum = Math.max(maximum, mainBlockLocalUsage(
          statement.body, active + (statement.variables || []).length).maximum);
      }
    }
    return { active, maximum };
  }
  const mainLocals = mainBlockLocalUsage(syntaxTree.body, 0).maximum;
  if (mainLocals > 190) {
    throw new Error(`The main Lua function uses ${mainLocals} active locals; keep it at 190 or fewer to stay safely below CET's 200-local limit.`);
  }

  const allowedGlobals = new Set([
    "EquipmentSystem", "Game", "GetBind", "GetDisplayResolution",
    "GetLocalizedTextByKey", "ImGui", "ImGuiCol", "ImGuiCond",
    "ImGuiStyleVar", "ImGuiWindowFlags", "IsBound", "ItemID",
    "LocKeyToString", "MorphMenuUserData", "NameToString", "Observe",
    "Override", "QuestDisableWardrobeSetRequest", "QuestRestoreWardrobeSetRequest",
    "ToCName", "assert", "bit32", "dir", "gameWardrobeClothingSetIndex",
    "gamedataEquipmentArea", "gameuiCharacterCustomizationEditTag", "io",
    "ipairs", "math", "next", "os", "pairs", "pcall", "registerForEvent",
    "registerHotkey", "registerInput", "string", "table", "tonumber",
    "tostring", "type",
  ]);
  const unexpectedGlobals = new Map();
  function findUnexpectedGlobals(node, parent, parentKey) {
    if (!node || typeof node !== "object") return;
    if (node.type === "Identifier" && !node.isLocal) {
      const propertyName = parent && parent.type === "MemberExpression" &&
        parentKey === "identifier";
      const tableKey = parent && parent.type === "TableKeyString" &&
        parentKey === "key";
      const declarationName = parent && parent.type === "FunctionDeclaration" &&
        parentKey === "identifier";
      if (!propertyName && !tableKey && !declarationName &&
          !allowedGlobals.has(node.name)) {
        if (!unexpectedGlobals.has(node.name)) unexpectedGlobals.set(node.name, []);
        unexpectedGlobals.get(node.name).push(node.loc.start.line);
      }
    }
    for (const [key, value] of Object.entries(node)) {
      if (key === "loc" || key === "range") continue;
      if (Array.isArray(value)) {
        for (const child of value) findUnexpectedGlobals(child, node, key);
      } else {
        findUnexpectedGlobals(value, node, key);
      }
    }
  }
  findUnexpectedGlobals(syntaxTree, null, "");
  if (unexpectedGlobals.size > 0) {
    const details = [...unexpectedGlobals]
      .map(([name, lines]) => `${name} at ${lines.join(", ")}`).join("; ");
    throw new Error(`Lua references names outside their visible scope: ${details}`);
  }
}

const fengariPath = path.join(root, ".audit_lua_runtime", "node_modules",
  "fengari-node-cli", "src", "lua-cli.js");
if (fs.existsSync(fengariPath)) {
  const smokePath = path.join(root, "tests", "runtime_smoke.lua");
  const result = childProcess.spawnSync(process.execPath,
    [fengariPath, smokePath, sourcePath], {
    cwd: root,
    encoding: "utf8",
  });
  if (result.status !== 0) {
    throw new Error(`Lua behavior smoke test failed:\n${result.stdout || ""}${result.stderr || ""}`);
  }
  process.stdout.write(result.stdout);
}

console.log("Release regression checks: OK");
