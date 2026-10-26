# Current test build

This build keeps the staged loader from e7de974 and the automatic camera guard.
The file-service DLL and preset reader use the original 4.0.0 implementation.

The later option caches, background preset parser, and reset-everything cleanup are removed.
Voice hooks are also removed because changing Voice Tone mid-game is unsupported.
The empty Voice.reds and Options.reds files replace scripts shipped in earlier test builds.

Run check_code.js to parse the shipped Lua files.
Compile the game scripts before packaging, then check the appearance and camera in game.
Game behavior needs the user's test; code checks cannot establish crash recovery.
