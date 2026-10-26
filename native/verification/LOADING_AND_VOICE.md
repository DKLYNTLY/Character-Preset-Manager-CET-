# Loading and voice checks

## Follow-up after the in-game report

The saved Activity Log shows CORPO - Female taking about 18 seconds and 225
passes in build `d3c852a`. Cleanup waited about two-thirds of a second per
old choice, while group confirmation waited separately for linked changes.
Some values were reported as unconfirmed after only 0.02 to 0.08 seconds.
Other warnings named eyelash selectors that the editor did not expose.

The follow-up build clears old choices, applies main choices, then applies
colors and linked details. Each stage writes small groups across updates
and confirms its pending choices together, with a shared settling period.
Missing selectors remain warnings; the loader does not substitute another choice.

At the user's request, I am checking code compilation and package contents
for this build and leaving behavior checks to the next in-game test.
The earlier simulation results below describe `d3c852a`, not this follow-up.

## Earlier automated checks

I ran `node native/verification/test_randomizer.js` after these changes.
It parses the shipped Lua files and checks the randomizer, menu actions,
delayed hair and cyberware updates, and unconfirmed values.
The group tests cover the four-change limit, the time budget,
cancellation, editor closure, failed writes, and changed option lists.
They check empty presets, missing choices, ambiguous labels, and matching values too.

Run `node native/verification/compare_loading.js` to compare the same synthetic
96-choice preset against both older loaders. The script reads 3.1.5 from its
local tag and 4.0.0 from commit `6f226bb`; it leaves their source under
`.audit_loading_baselines`.

| Loader | Simulated time | Option reads | Full scans | Most writes in one update |
|---|---:|---:|---:|---:|
| 3.1.5 | 4.800 s | 97 | 97 | 1 |
| 4.0.0 | 0.700 s | 127 | 113 | 96 |
| Revised | 0.400 s | 25 | 25 | 4 |
| 3.1.5, with cleanup | 5.500 s | 100 | 100 | 1 |
| 4.0.0, with cleanup | 0.800 s | 129 | 115 | 96 |
| Revised, with cleanup | 0.450 s | 28 | 28 | 4 |

These times count scheduled updates at 60 updates per second with simulated
game choices. They do not measure game performance or promise a loading time.
The revised loader logs full scan counts and its longest loading call so I
can compare results from a real game session.
One expensive game call can exceed the four-millisecond group budget;
the loader checks that budget between calls.

The older, locally ignored `tests/native_panel_regression_checks.js` still
expects an earlier Trash status message. I reproduced its failure against
unchanged commit `6f226bb`, so it is not a new regression.

I also ran the loading fixtures under LuaJIT 2.1, which passed.
The ACU parser checks passed for the supported file fixtures too.

## Voice compilation

I compiled all CPM scripts with Codeware 1.21.1 against the installed game
script bundle. Compilation passed, with one existing warning in Codeware
about a function that may return without a value.

The confirmation hook captures Voice Tone before appearance confirmation.
It writes Codeware's persistent `GamePuppetPS.gender` field only after the
game reports that confirmation finished, and only when the voice changed.
Cancellation and menu closure discard the pending selection.
Opening an existing character reads that saved voice back into the selector;
new-game creation keeps its original path.

## Checks still needed in game

No game was running during these checks. I have not verified voice playback,
save/reload persistence, or loading frame times in game yet.

Repeat these checks through a physical apartment mirror and the Full Appearance
Editor, using both body types. Try both feminine-to-masculine and
masculine-to-feminine voice changes.

| Action | Expected result | Status |
|---|---|---|
| Change Voice Tone, then Confirm | The selected voice plays during normal dialogue; body type stays the same | Pending |
| Reopen the editor | Voice Tone shows the confirmed voice | Pending |
| Save, exit, and reload that save | The chosen voice and appearance remain | Pending |
| Change voice and hair, then Confirm | Both changes remain after reopening and reloading | Pending |
| Change voice, then cancel | The previous voice and appearance remain | Pending |
| Confirm without changing voice | Voice stays the same | Pending |
| Cancel, reopen, and confirm another selection | The cancelled voice does not return | Pending |
| Create a new character | The original voice selection and confirmation still work | Pending |
| Load the same preset from each preset menu | Both menus reach the same appearance without long freezes | Pending |

For a voice report, record the selected Voice Tone and the result of
`Game.GetPlayer():GetGender()` before confirmation, after confirmation,
and after loading the saved game. Keep the Activity Log from performance
checks and record the preset, game version, and character mods used.
