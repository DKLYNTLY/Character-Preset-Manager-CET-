# Code and package checks

The check setup now covers source parsing and compilation.
The simulated game sessions, benchmarks, old fixtures, and standalone test
executable have been removed; I kept a local copy under
`.audit_retired_tests` before removing them.

Run `node native/verification/check_code.js` to parse all shipped Lua files
as Lua 5.1. It uses the installed `luaparse` dependency.

Build `CharacterPresetManagerNative` in Release mode with CMake and the
matching RED4ext SDK. Compile the shipped redscript files against the game
bundle with Codeware included as a dependency.

I checked the DLL build, Lua parsing and LuaJIT compilation, and redscript
compilation for this update. The compiler reported one existing Codeware
warning about a function that may return without a value.

The option catalog now lives in the DLL, with a limit of 65,536 cached choice
identities. It warms active lists while the editor is idle and reads other
lists when needed; unused action copies are no longer stored in Lua.
The camera guard, staged loading, Off-or-first-choice cleanup, and voice
confirmation changes remain included.

Game option data is accessed through calls on the game thread.
The existing file watcher continues to run separately, without reading game
objects from its worker thread.

I am leaving camera behavior, loading speed, voice playback, save/reload
persistence, and actual memory use for the next in-game check.
The test ZIP must contain the matching DLL and scripts together.
