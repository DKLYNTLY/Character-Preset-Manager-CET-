# Historical Lua reference

These files preserve the previous Lua runtime for regression comparisons. They
are not packaged, loaded by the current mod, or used as a fallback. The current
production runtime is in native/src and source/raw/r6/scripts/CharacterPresetManager.
Only the test version handshake is updated to match the native service used by
the regression harness. Passing these older adapter checks does not verify the
new redscript adapter or its behavior inside the game.
