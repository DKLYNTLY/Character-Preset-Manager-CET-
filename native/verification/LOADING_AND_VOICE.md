# Recovery build checks

The failed launches stopped at CPM plugin loading before script compilation.
Deferring native class creation did not resolve startup; an isolated DLL-load
check passed, so the native registration calls remain the suspect path.

This recovery build restores the pre-catalog file-service entry point.
It does not register native game types or functions, and CET matches choices
directly without the removed large choice tables or action copies.
The compatibility `Options.reds` file overwrites the previous native-class
declaration when this ZIP is installed over the failed build.

The camera guard, staged loading, and voice confirmation change remain included.
Cleanup again clears only old choices the selected preset does not use; the
reset-everything step has been removed. CET and Codeware are still required.

I checked the DLL build, isolated DLL loading, Lua code parsing, LuaJIT
compilation, and redscript compilation. The game-script compiler has one
existing Codeware warning about a missing return on one path.
Game startup, loading behavior, and voice persistence still need confirmation.

Run `node native/verification/check_code.js` for Lua syntax checks.
The simulated gameplay tests remain removed; native migration is unfinished.
