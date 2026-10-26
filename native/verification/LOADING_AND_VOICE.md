# Code and package checks

This build adds only file and data work to the existing native worker.
It does not register game classes, call game functions, or change the working
loading, cleanup, camera, or voice code.

The DLL reads library CPM and ACU presets, writes compact caches under
`Data/Catalog/Parsed Presets`, and adds entry counts to the native file index.
CET checks the current source fingerprint before using a cache; missing or
stale caches use the original reader immediately.
Original preset files are never rewritten by the parser.

The cache keeps source metadata, saved order, editor slots, saved choices,
and malformed-line warnings. The existing file size, entry-count, line-count,
and choice limits remain in place; recovery and temporary-file validation
still have direct reads available.

I checked DLL compilation, isolated DLL entry and unload, Lua parsing,
LuaJIT compilation, and game-script compilation for this build.
The compiler reported the existing Codeware warning about one return path.
No simulated gameplay tests were run.

The next in-game check covers startup, preset lists and loading, imported ACU
presets, saving and overwriting, notes and tags, recovery, and sharing.
Actual speed and memory changes still need that game session.
The Activity Log records `[NATIVE PRESET]` when a full preset read uses the cache.

Run `node native/verification/check_code.js` for Lua syntax checks.
