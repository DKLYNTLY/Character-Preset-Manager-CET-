# Stage 8 Part B: reported preview leftovers

Baseline: 889836120309aa9311474caa732536b03895eb74 (stage 9). Investigation first; a small hypothesis test patch follows. Stages 1â€“9 are not re-extracted. Stage 10 is not started.

**Status: the user reproduced the visible issue after stage 9. Selected values and the preview disagree. The native trigger is UNVERIFIED. This patch is a hypothesis, not a confirmed native-renderer fix.**

## Evidence and scope

I preserved the session log before further testing. It starts at 21:15:15 and ends at 21:17:08 on October 29, 2026, America/New_York. Activity.log SHA-256: `fb8635eebbd555d6a90222eee68e04bc646c2417861216a2914298783afdbe05`.

The installed loading.lua, state.lua, game_options.lua, options.lua and native_bridge.lua matched the repository before the patch. The per-mod error file contains only the old October 27 coroutine errors, not an error from this session. The preserved Activity Log has no ERROR line. Old error entries do not establish a new stage 9 failure.

The user confirms the screenshot is after the last ss/ss load. Leaving the editor clears the visible leftovers; loading other presets can leave or add items. The option list shows Off or a different selected choice while old components stay visible. The user also reports that CET Refresh options followed by another load does not clear them.

A second preserved log, starting 21:22:43, independently shows native library Refresh actions at 21:23:06â€“08 and another successful ss/ss SUMMARY at 21:23:08 (59 confirmed, zero unconfirmed/cleanupUnconfirmed, six passes). Those library refresh entries are not proof of the CET option-cache command. The actual Refresh options result is recorded as the user's report. No further repetition of that test is required.

The follow-up requests are ddd 21:22:59–21:23:01 (59 confirmed, complete); ss 21:23:02–21:23:05 (59, complete); ss again 21:23:08 (59, complete); Female/Mariko 1.0 21:23:12–21:23:13 (47 applied, 2 unresolved, stopped); Alina 21:23:23–21:23:25 (48 applied, 2 unresolved, stopped). These requests also do not overlap at the printed terminal boundaries.

## Every load in the original sequence

Timestamps have one-second precision. None of the five requests begins before its predecessor's terminal SUMMARY. The end-to-next-request gaps below are differences between printed timestamps, not precise subsecond measurements.

| Preset | Requested | Terminal | Physical log lines request / SUMMARY | Next printed gap | Overlap |
|---|---|---|---|---|---|
| Alina | 21:16:18 | 21:16:19 | 28 / 85 | 5 s | No |
| ss/ddd | 21:16:24 | 21:16:27 | 93 / 263 | 1 s | No |
| ss/ss | 21:16:28 | 21:16:30 | 269 / 474 | 14 s | No |
| ss/ddd | 21:16:44 | 21:16:47 | 480 / 656 | 2 s | No |
| ss/ss | 21:16:49 | 21:16:51 | 662 / 834 | Session ends later | No |

Exact SUMMARY lines:

```text
[2026-10-29 21:16:19] [#0085] [WARN] SUMMARY | preset='Alina' | applied=48 | unresolved=2 | passes=26 | result=stopped
[2026-10-29 21:16:27] [#0262] [COMPLETE] SUMMARY | preset='ss/ddd' | processed=59 | confirmed=59 | unconfirmed=0 | forced=0 | cleanupUnconfirmed=0 | failed=0 | unavailable=0 | ambiguous=0 | passes=42 | result=complete
[2026-10-29 21:16:30] [#0473] [COMPLETE] SUMMARY | preset='ss/ss' | processed=59 | confirmed=59 | unconfirmed=0 | forced=0 | cleanupUnconfirmed=0 | failed=0 | unavailable=0 | ambiguous=0 | passes=41 | result=complete
[2026-10-29 21:16:47] [#0655] [COMPLETE] SUMMARY | preset='ss/ddd' | processed=59 | confirmed=59 | unconfirmed=0 | forced=0 | cleanupUnconfirmed=0 | failed=0 | unavailable=0 | ambiguous=0 | passes=42 | result=complete
[2026-10-29 21:16:51] [#0833] [COMPLETE] SUMMARY | preset='ss/ss' | processed=59 | confirmed=59 | unconfirmed=0 | forced=0 | cleanupUnconfirmed=0 | failed=0 | unavailable=0 | ambiguous=0 | passes=36 | result=complete
```

Alina's older stopped-summary shape does not report forced or cleanupUnconfirmed counts. They are not assumed zero. Its two skipped options are eyelashes_options and eyelash_color at lines 80â€“81. Every completed ss preset reports forced=0, cleanupUnconfirmed=0 and no unresolved failure. There is no UNCONFIRMED entry in this original log.

## Visible items and their selectors

The current files confirm that ss/ddd saves cyberware_switcher at 24 (bby_xtra_cyberware_08), piercings at 1 (options:01) and nipple_piercings at 1. ss/ss saves cyberware_switcher=0 (Common-Off), piercings=12 (options:12) and nipple_piercings=0. It also saves tongue_piercings=1. Therefore ss/ss is not a no-piercings preset. Which individual nose/lip/brow mesh belongs to choice 1 versus 12 is UNVERIFIED without those asset definitions; the log records selector identity, not component attachment names.

The facial cyberware and general piercing selector transitions are explicit. The earlier pair does the same thing, at lines 130/205 and 135/208 for ddd, then 321/427 and 326/430 for ss. The final pair is quoted below.

```text
521: [2026-10-29 21:16:45] [#0520] [INFO] CHANGE | pass=14 | Cyberware | LocKey=LocKey#6426888875968525879 | occurrence=1 | preset format=8 | saved LocKey='LocKey#6426888875968525879' | editor slot='cyberware_switcher' | saved choice='options:UI-Customization-bby_xtra_cyberware_08' | saved index=24 | target=24
523: [2026-10-29 21:16:45] [#0522] [INFO] CHANGE | pass=14 | Piercings | LocKey=LocKey#9633374630979636519 | occurrence=1 | preset format=8 | saved LocKey='LocKey#9633374630979636519' | editor slot='piercings' | saved choice='options:01' | saved index=1 | target=1
597: [2026-10-29 21:16:46] [#0596] [INFO] SETTLED | apply | Cyberware | LocKey=LocKey#6426888875968525879 | occurrence=1 | preset format=8 | saved LocKey='LocKey#6426888875968525879' | editor slot='cyberware_switcher' | saved choice='options:UI-Customization-bby_xtra_cyberware_08' | saved index=24 | target=24 | result=value confirmed | currIndex wait=0.459s | structureChanged=true
599: [2026-10-29 21:16:46] [#0598] [INFO] SETTLED | apply | Piercings | LocKey=LocKey#9633374630979636519 | occurrence=1 | preset format=8 | saved LocKey='LocKey#9633374630979636519' | editor slot='piercings' | saved choice='options:01' | saved index=1 | target=1 | result=value confirmed | currIndex wait=0.459s | structureChanged=true
714: [2026-10-29 21:16:50] [#0713] [INFO] CHANGE | pass=14 | Cyberware | LocKey=LocKey#6426888875968525879 | occurrence=1 | preset format=8 | saved LocKey='LocKey#6426888875968525879' | editor slot='cyberware_switcher' | saved choice='options:Common-Off' | saved index=0 | target=0
719: [2026-10-29 21:16:50] [#0718] [INFO] CHANGE | pass=15 | Piercings | LocKey=LocKey#9633374630979636519 | occurrence=1 | preset format=8 | saved LocKey='LocKey#9633374630979636519' | editor slot='piercings' | saved choice='options:12' | saved index=12 | target=12
729: [2026-10-29 21:16:50] [#0728] [INFO] CHANGE | pass=17 | Custom/CCXL option (no display name) | LocKey=LocKey#13713838855884025456 | occurrence=1 | preset format=8 | saved LocKey='LocKey#13713838855884025456' | editor slot='nipple_piercings' | saved choice='options:Common-Off' | saved index=0 | target=0
787: [2026-10-29 21:16:50] [#0786] [INFO] SETTLED | apply | Cyberware | LocKey=LocKey#6426888875968525879 | occurrence=1 | preset format=8 | saved LocKey='LocKey#6426888875968525879' | editor slot='cyberware_switcher' | saved choice='options:Common-Off' | saved index=0 | target=0 | result=value confirmed | currIndex wait=0.525s | structureChanged=true
790: [2026-10-29 21:16:50] [#0789] [INFO] SETTLED | apply | Piercings | LocKey=LocKey#9633374630979636519 | occurrence=1 | preset format=8 | saved LocKey='LocKey#9633374630979636519' | editor slot='piercings' | saved choice='options:12' | saved index=12 | target=12 | result=value confirmed | currIndex wait=0.457s | structureChanged=true
796: [2026-10-29 21:16:50] [#0795] [INFO] SETTLED | apply | Custom/CCXL option (no display name) | LocKey=LocKey#13713838855884025456 | occurrence=1 | preset format=8 | saved LocKey='LocKey#13713838855884025456' | editor slot='nipple_piercings' | saved choice='options:Common-Off' | saved index=0 | target=0 | result=value confirmed | currIndex wait=0.347s | structureChanged=true
831: [2026-10-29 21:16:51] [#0830] [INFO] CLEANUP | No more visible old choices need clearing. Checking the saved preset values.
833: [2026-10-29 21:16:51] [#0832] [INFO] [UI] Refreshed the editor's visible controls using the loaded preset values.
```

These are saved-option APPLY writes, not unused-choice cleanup writes. Their saved keys are present, so cleanupNeeded correctly does not classify them as extra unused selectors. The requested Off/different choice was already written and confirmed through currIndex. The final cleanup then says no more visible old choices need clearing. It is not proof that the preview has removed every native component.

Precleanup in the final ss load confirms five other selectors at zero (lines 680â€“684): three mch_hair_part fields, a dependent color field and nipple_piercings_color. No cleanup-skip or unconfirmed-clear entry is reported. There is no next load interrupting this cleanup. Refresh of the visible option controls is logged at line 833, immediately before the final SUMMARY.

## Code trace

| Path | Evidence / meaning |
|---|---|
| application/loading.lua load_request (baseline line 228) | Same-name continuation versus begin. The native start resets presetName first, so repeated ss requests start a new operation. |
| domain/state.lua beginLoad (190) | Partial begin intentionally retains some old fields. It is not the whole native preparation. |
| native_bridge.lua startSelectedLoad (248) | Resets load state, prepares automatic loading, then invokes loadPreset. |
| domain/state.lua releaseLoadWorkingData (157) | A terminal load clears pendingChange, batch, scan and working maps. The original sequence reaches terminal state before every subsequent request. |
| adapters/game_options.lua writeLoadGroup (567) | Previously submits up to four ApplyChangeToOption calls per group without checking a native appearance-completion event between them. |
| application/loading.lua group_append/group_finish_write | Marks keys staged, clears pendingChange and originally accumulates stagePending until the stage has no more writes. Reducing the burst alone would still allow pending writes across consecutive frames. |
| application/loading.lua pending (89) | Confirms currIndex plus existing option-list settle rules. It does not observe rendered mesh removal. |
| application/loading.lua finish_pass | Advances apply/cleanup/verify after data checks. |
| adapters/game_options.lua cleanup eligibility/write (baseline 714/721) | Extra-choice decisions come from unchanged matching.cleanupNeeded. Known saved Off choices are handled by APPLY. |
| options.lua refreshCustomizationUi (250) | Calls InitializeList; success logs that visible controls were refreshed. It is not a renderer-completion acknowledgment. |

The local decompiled characterCreationBodyMorphMenu.script shows selector input using BusySwitchingReason.SWAPPING and OnAppearanceAppliedEvent to release its busy condition. InitializeList rebuilds option controls and applies the edit tag; it has no explicit puppet respawn in that script body. The native implementation of ApplyChangeToOption and ApplyEditTag is not present. The exact version match of this decompiled reference to the running engine is UNVERIFIED. It motivates a test; it does not prove an engine defect.

## Hypotheses

| Candidate | Finding |
|---|---|
| a. Superseded accepted write lands later | No superseded request exists in the observed sequence. Late native work after a data-level terminal SUMMARY cannot be ruled out, because the log has no render-completion timestamps. The specific supersede explanation is unsupported here. |
| b. cleanupSkipped suppresses another clear | Unsupported for this sequence: completed loads report zero cleanupUnconfirmed, there are no UNCONFIRMED lines, and the relevant selectors are explicit saved APPLY targets. No retry policy is changed. |
| c. Old beginLoad pending/batch/signature leaks | Not shown here: all requests follow terminal release, and native preparation additionally resets state. The earlier direct-ingress supersede differences stay documented and unchanged. |
| d. Preview stale despite correct selected data | The data/preview disagreement is confirmed by the user's checks. Absence of a control refresh is ruled out by the logged successful refreshes. Whether the native preview failed to process a change or retained old components is UNVERIFIED. |
| e. In-stage appearance requests overlap | Hypothesis: the old stage accumulator and four-write bursts can submit multiple changes before native appearance work finishes. There is code evidence for overlapping submissions, not proof of a native race. This is the mechanism the conditional fake and patch test. |
| CPM option cache | Still UNVERIFIED as a contributing cause. Refreshing it reportedly does not repair the issue. The live option reference is overwritten on each scan; per-frame optionsMemo is cleared; choice indexes are checked against live values. Per-binding checked flags can still reuse data within a frame, and native caches are outside CPM's control. The patch also creates fresh polling between writes, so a successful test alone will not distinguish all cache/timing mechanisms. |

No unrelated earlier change is assigned as the cause.

## Scripted reproduction and its limits

stage8b_fixtures.lua contains the three original readable preset texts. The fake runs Alina -> ss/ddd -> ss/ss -> ss/ddd -> ss/ss, with the printed end-to-next gaps and no supersede. It preserves the observed Alina hairstyle remap and two unavailable saved keys. It checks Alina applied=48/unresolved=2 and each later preset processed=59/confirmed=59/zero unconfirmed, forced and cleanupUnconfirmed. This reproduces the counts and requested choices, not the original pass counts.

**The ordinary data-only fake does not reproduce the visual bug.** It has no native renderer. The real editor exposes 1,576 options; the fixture reconstructs only known saved selectors, identities and required choices. Unrecorded option ordering, all dynamic definitions, actual subsecond scheduling, Codeware/CCXL callbacks and mesh/component lifetime are not captured by the log. Exact full-game action replay is impossible from this evidence alone.

The conditional extension models a separate preview transaction. It updates currIndex immediately, commits a tracked geometry request after a named 0.10-second test delay, and retains previous visible choices if another tracked request overlaps that transaction. InitializeList only records a control refresh. Those renderer rules and latency are **UNVERIFIED assumptions**, not observed game internals.

Under that assumption, the old policy leaves cyberware choice 24 and old hair choices visible after the final data says cyberware=0/piercings=12. The fake records every write, preview request/commit, confirmation and SUMMARY when CPM_STAGE8B_REPORT is set to an output prefix. It does not establish the exact nose/lip/brow component membership from the screenshot.

The regression demonstrably fails under the original production setting with the assertion that the preview contains an old choice. Replaying the original state machine with only the limit lowered to one also fails the tracked-geometry check; immediate per-group confirmation is needed in this model. It also explicitly replays the old four-write policy in the current test and requires that conditional failure. The patched policy must match every tracked geometry selector to its selected data. The full five-load sequence, normal single ss/ss load and paused ddd-to-ss pair pass. This is conditional bug reproduction, not native confirmation.

## Small hypothesis patch

Only two runtime files change:

1. constants.lua: AUTO_LOAD_TIMING.maximumGroupChanges changes from 4 to 1.
2. application/loading.lua: when the configured group size is one, immediately promote that accepted group to the existing batch confirmation/settle path. Do not accumulate more accepted writes until the end of the stage.

No matching, cache, cleanup eligibility, supersede/reset policy, event hook, redscript, native code, setting or saved format is changed. No game API is added. No renderer-reset API is guessed. The existing 0.20-second stable time, 0.05 poll interval, 1.25 dependency timeout and automatic safety threshold stay unchanged. The loader still confirms selected data rather than native appearance completion.

This removes four-write bursts and waits for the existing data/settle criteria after each request. It also allows fresh option validation between requests. It can make loads substantially slower and adds confirmation polls/groups across the load. It does not cancel accepted native work, retry cleanupSkipped keys or repair an already-corrupted preview whose selected values already match.

The new SINGLE_CHANGE_GROUP_SIZE is a local constant, not a user setting or persistent field. It uses the existing plain batch fields and actions. There are no new production globals or dependencies. The historical group-of-four path remains intact for the recorded extraction fixtures.

## Logs and validation

No log message template or new log category is added. Expect the same CHANGE, SETTLED, PRECLEANUP/APPLY/CLEANUP, UI-refresh and SUMMARY messages. Pass numbers, elapsed time, wait metrics and repeated existing waiting statuses will change. A SETTLED or complete SUMMARY still does not certify rendered geometry. No new preview-recovered claim is logged.

The historical stage 7/8 trace oracles assume groups of four. They intentionally differ if run unmodified against the new policy. stage7_tests now pins its named RECORDED_GROUP_LIMIT=4 in the test setup used by those historical replays; their goldens, including all eight supersede cases, are not regenerated. New Part B tests capture and restore the actual production limit before exercising it.

Validation:

- Restricted stages 1â€“9 pass, with historical stage 7/8 batch-of-four traces kept explicit. This does not claim unchanged new-policy timing/action traces.
- The additional current-policy run of all 46 loader scenarios matches baseline final choices, terminal/busy/camera flags, remaining counts, readiness, error classification and scan retention. Timing/pass counts may change intentionally.
- The full-data conditional regression fails under the old policy and passes under the new policy. Normal single and paused-pair cases pass.
- All 89 Lua files parse as Lua 5.1. The existing redscript signature/body checks pass.
- Isolated redscript compilation succeeds; no redscript source changes are included.

## Exact install files

Exit the game completely, then install the test archive into the Cyberpunk 2077 folder. A clean preview is important: this tests prevention and is not a repair command for an already-stale preview. Keep Data and Character Presets.

Runtime files, both under bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/modules:

```text
constants.lua
application/loading.lua
```

The package also contains the changed domain/stage7_tests.lua historical setup, updated STAGE8.md status, and new domain/STAGE8B.md, stage8b_tests.lua, stage8b_loader_tests.lua and stage8b_fixtures.lua. They are not loaded by init.lua. No DLL or redscript installation change is required; packaged copies remain byte-identical to stage 9. The root CHANGELOG.md is repository-only. No release/version change is made.

## In-game retest

1. Restart the game after installation. Open a fresh editor preview and confirm the preset list and normal controls work. Keep the Activity Log from the test.
2. Repeat the original order: Alina, ss/ddd, ss/ss, ss/ddd, ss/ss. Remain in the editor between requests. Let each finish, then use roughly the original printed gaps (5, 1, 14 and 2 seconds). Expect the existing request/CHANGE/SETTLED/SUMMARY lines. Alina may still stop at 48/2 for the same missing dependencies; that is not changed.
3. After each ss load, compare the visible face to a clean single ss load and the selector values. Cyberware should be Off. Piercings should be the preset's choice 12, with no older choice-1 components added. The same 59-confirmed/zero-warning complete SUMMARY is expected when all dependencies are present, with more passes and longer loading.
4. Run ss/ss once from a clean preview. Check the correct appearance, normal completion, free camera and released busy state.
5. Load ss/ddd, wait at least five seconds after its SUMMARY, then load ss/ss. Confirm the face clears the old cyberware and shows only the selected piercing style. Keep both summaries and compare to the rapid sequence.
6. If any stale items remain with the selector Off/different, keep screenshots and the log before closing. That would show this hypothesis is insufficient. Do not infer that the native cause is proven if the patch helps; serialized timing and fresh validation both changed together.

## Defects found

- Visible old cyberware/piercing components are reported again after stage 9 while selected data is Off/different. Cause remains UNVERIFIED. The old unreproduced status is superseded by this report.
- The loader's data/list confirmation is not a native rendered-appearance acknowledgment. The test patch reduces in-stage overlap using existing settling; it does not add such an acknowledgment.
- The specific individual mesh mapping and native timing remain unrecorded. The conditional model cannot prove them.

Stop after Part B and wait for in-game confirmation. Stage 10 is not started.
