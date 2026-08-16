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

requireText('local VERSION = "3.0.4"', "The mod version changed unexpectedly.");
requireText("readableFormatConfirmed and readableKey == \"Saved choice\"",
  "Format-8 choice details are no longer gated by the format header.");
requireText("readableFormatConfirmed and readableKey == \"Editor slot\"",
  "Format-8 editor positions are no longer gated by the format header.");
requireText("readBoundedFile(INVENTORY_FILE, MAX_CATALOG_BYTES)",
  "The startup preset list is no longer size-limited.");
requireText("AUTO_LOAD_PASSES_PER_OPTION",
  "Automatic loading no longer scales with the preset size.");
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
  luaparse.parse(source, { luaVersion: "5.3" });
}

console.log("Release regression checks: OK");
