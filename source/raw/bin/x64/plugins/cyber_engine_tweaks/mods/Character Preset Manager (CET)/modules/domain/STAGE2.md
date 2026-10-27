# Stage 2 codec extraction

I captured the existing adapter results before extracting code. The fixtures compare returned models, log messages, write chunks, and file closes using in-memory files.

## Functions and current callers

| Entry point | Callers before extraction |
|---|---|
| `decodeJsonPreset` | `presets.lua:160` |
| `readAcuJsonPreset` | `presets.lua:224` |
| `readPresetFile` | `backup.lua:387`; `bundles.lua:517`; `catalog.lua:78,81`; `history.lua:65,97,104`; `load_engine.lua:1398`; `presets.lua:383,452,582,628`; `trash.lua:513,622` |
| `writePresetContents` | `presets.lua:581` |
| `readConfig` | `backup.lua:438`; `events.lua:72` |
| `writeConfig` | `backup.lua:442`; `events.lua:75`; `native_bridge.lua:422` |

## What moved

| New module | Responsibility |
|---|---|
| `preset_codec.lua` | Parse legacy and readable preset text, map decoded ACU JSON options, and produce the existing preset text. |
| `json.lua` | Parse JSON strings with the same number, escape, depth, and surrogate rules. |
| `config_codec.lua` | Parse configuration strings, return defaults and warnings, ignore retired keys, and produce the `presetSort` line. |

The modules return explicit function tables and never access `runtime`, game objects, or file handles. The public text parsers receive strings and return plain models and diagnostic tables. The writer returns its text and the original write chunks, so the adapter keeps its existing write-failure results and output boundaries.

The text parser keeps its per-line parsing state inside the domain module. The adapter now supplies the bounded file contents as a string. It still opens and closes files, checks their sizes, handles protected seek calls, and writes log messages.

Unicode conversion stays behind the existing JSON adapter. It passes an explicit conversion function into the JSON parser and keeps `pcall` around the runtime's Unicode conversion. No new game API was introduced.

The format value, entry limit, line limit, and key-byte limit now live in the preset codec. The old constants forward those same values. The config limit remains 16,384 bytes; all format names, metadata limits, error messages, and retired settings keep their values.

The loader, UI, redscript, native source, save fields, file formats, bridge protocol, and release version are unchanged. I left README and changelog text alone because this stage adds no user-visible behavior.

## Temporary entry points and remaining callers

Keep each entry point until its callers move. The two JSON functions remain local; all file readers and writers keep their shared names.

| Entry point | Remaining callers |
|---|---|
| `decodeJsonPreset` | `presets.lua:22` |
| `readAcuJsonPreset` | `presets.lua:52` |
| `readPresetFile` | `backup.lua:387`; `bundles.lua:517`; `catalog.lua:78,81`; `history.lua:65,97,104`; `load_engine.lua:1398`; `presets.lua:72,141,219,265`; `trash.lua:513,622` |
| `writePresetContents` | `presets.lua:218` |
| `readConfig` | `backup.lua:438`; `events.lua:72` |
| `writeConfig` | `backup.lua:442`; `events.lua:75`; `native_bridge.lua:422` |

## Baseline and validation

I captured the first 128 cases before extracting production code. I then expanded the suite using the original `presets.lua` from commit `e37c02b`, running it in a fresh Lua 5.1 environment. The expected results are frozen in `stage2_fixtures.lua`.

The suite now has 183 cases. It covers numbered CPM metadata headers from 1 through 8, bare legacy and ACU text, readable format 8, metadata-only reads, duplicate keys and identities, malformed and truncated input, Unicode text and escapes, size and index limits, seek failures, and failures at each tested write boundary. Config cases include `name`, `modified`, defaults, missing and oversized files, retired keys, unsupported lines, and write failures.

Results on Lua 5.1:

- Stage 1: all 833 recorded fixtures pass, along with compatibility, byte-codec, naming-limit, and storage-fallback checks.
- Stage 2: all 183 adapter fixtures pass with the same models, log messages, write chunks, and file-close counts as the original.
- All 62 accepted full preset fixtures produce exactly the same write result and output chunks as the old writer.
- All seven canonical format-8 samples pass read/write comparisons with identical output bytes. These include Unicode, duplicate identities, and field limits.
- Every preset read leaves the fixture string unchanged and records no write. This includes every legacy and malformed fixture.
- All six tracked default preset files return the same models through the old and new real-file adapters. Their SHA256 values remain unchanged after both reads.
- The Lua 5.1 syntax check passes for all 43 Lua files.

The canonical samples come from the old writer. Arbitrary hand-edited spacing and old layouts were already normalized by that writer, so I compare their rewritten text against the baseline rather than claiming it must match the source file. Reading never performs that rewrite.

Run these from the repository root with Lua 5.1, then run the existing syntax checker with Node:

```text
lua "source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/modules/domain/stage1_tests.lua"
lua "source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/modules/domain/stage2_tests.lua"
node native/verification/check_code.js
```

No dependency was added. The validation here used the installed Lua 5.1 library through Python's standard-library interface and the repository's installed `luaparse` parser.

## Install and packaging

Install the changed `modules/presets.lua` and `modules/constants.lua` with these new files under the existing CET mod's `modules/domain/` folder:

- `json.lua`
- `preset_codec.lua`
- `config_codec.lua`
- `stage2_tests.lua`
- `stage2_fixtures.lua`
- `STAGE2.md`

The first three files are required at runtime. The other three preserve the test suite and review record. Keep every stage 1 domain file as well.

The test archive includes all tracked files under the same three shipped roots: the CET mod, `r6/scripts/CharacterPresetManager`, and `red4ext/plugins/CharacterPresetManager`. Archive checks compare each entry with its source, verify every new file is present, and reject paths outside those roots. Install through Vortex or extract into the game folder and allow overwrites.

## Defects found

I left these existing behaviors unchanged:

- Byte limits can split a UTF-8 character. The stage 1 truncation fixtures still pass.
- General, bundle, and native path validators accept different values. Stage 1 fixtures preserve each rule.
- The JSON parser accepts some nonstandard number spellings, including `01` and `1.`.
- JSON `null` uses the same Lua value as `false`. The old ACU mapping and rejection behavior remain in the fixtures.
- Unicode escapes fall back to `?` when runtime conversion is unavailable or fails. The adapter still makes that decision through its protected conversion call.

I made no corrective change to these rules. Fixes need a separate review so they cannot hide inside this move.

## Stage 1 log review

The installed domain files matched the stage 1 test build. The October 27 session showed successful startup, saves, Trash restore, and redscript compilation, with no CPM script error.

That session also reported two unavailable eyelash options while loading a preset: 48 of 50 choices applied before the loader stopped. The native service reported unavailable ACU folder watching. These messages do not establish a stage 1 regression, and I left those systems unchanged.

## In-game checklist

Use a copy of the library when testing writes. Keep a copy of the corrupted fixture so its warning can be compared with the stage 1 log.

1. **Format 8:** Load a current preset, check its appearance and metadata, then inspect its file. Reading must not change its bytes.
2. **Older CPM:** Load an older preset with encoded metadata and any saved slot or choice details. Check the same available choices and warnings as stage 1, and confirm that the source file stays unchanged.
3. **ACU text:** Import or select a compatible text preset and load it. Check its option count, appearance, and compatibility warnings without installing ACU itself.
4. **ACU JSON:** Load a supported JSON preset, including Unicode names if available. Compare active options and any rejected entries with stage 1.
5. **Save:** Save a new preset with notes, tags, and a nested library folder. Confirm readable format-8 headings, `Editor slot`, `Saved choice`, and successful reload. Accept the editor changes, save the game, and reload that save.
6. **Sort:** Change `presetSort` through the menu, restart the game, and check that the chosen order persists. Repeat for `name` and `modified`.
7. **Corrupted input:** Load the same malformed or truncated preset used with stage 1. Compare the warning text, any salvaged entries, and the rejection result. The damaged source file must remain unchanged.

**UNVERIFIED:** the stage 2 build still needs these in-game checks. The user confirmed stage 1; that confirmation does not validate this new build.

I stopped after stage 2. Stage 3 requires the user's confirmation.
