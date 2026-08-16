const fs = require("fs");
const path = require("path");

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
requireMatch(/not metadataOnly and readableFormatConfirmed\s+and readableKey == "Saved choice"/,
  "Format-8 choice details are no longer gated by the format header.");
requireMatch(/not metadataOnly and readableFormatConfirmed\s+and readableKey == "Editor slot"/,
  "Format-8 editor positions are no longer gated by the format header.");
requireText("readBoundedFile(INVENTORY_FILE, MAX_CATALOG_BYTES)",
  "The startup preset list is no longer size-limited.");
requireText("AUTO_LOAD_LIMITS.passesPerOption",
  "Automatic loading no longer scales with the preset size.");
requireText("state.loadSnapshot = snapshot",
  "Automatic loading no longer preserves its exposed-option snapshot.");
requireText("usingSnapshot and state.loadCursor or 1",
  "Automatic loading no longer resumes from its saved work cursor.");
requireText("AUTO_LOAD_FAST_INTERVAL",
  "Automatic loading no longer uses its faster interval while reusing safe work.");
requireText("state.logLoadOnce",
  "Repeated loading warnings are no longer deduplicated.");
requireText("readPresetFile(path, metadataOnly)",
  "Preset files no longer support lightweight startup records.");
requireText("state.hydratePreset",
  "Lightweight presets can no longer be loaded fully on demand.");
requireText('scanReason == "startup" and {',
  "Startup opens every preset instead of using lightweight inventory records.");
requireText('line:match("^P2\\t',
  "The startup inventory no longer stores lightweight preset details.");
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
  const syntaxTree = luaparse.parse(source, { luaVersion: "5.3" });
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
}

console.log("Release regression checks: OK");
