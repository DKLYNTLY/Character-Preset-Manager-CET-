# Stage 8 Part A loader extraction

Baseline: `64b9c7414a61a7e72180fda38c4cb575cad6f5a4`. Part B is skipped at the user's request. No leftover-hair/cyberware fix is included.

## Before extraction: boundaries and callers

The loader facade will remain load_engine.lua. application/loading.lua will own plain event transitions; adapters/game_options.lua will execute game actions and retain logging/status boundaries. Editor-hook source and earlier stage modules remain unchanged.

| Boundary | Existing callers (module-relative lines) |
|---|---|
| `logLoadOnce` | `load_engine.lua:395`; `load_engine.lua:402`; `load_engine.lua:843`; `load_engine.lua:850`; `load_engine.lua:860`; `load_engine.lua:1082`; `load_engine.lua:1107` |
| `loadOptionIdentity` | `load_engine.lua:264`; `load_engine.lua:501`; `load_engine.lua:516`; `load_engine.lua:845`; `load_engine.lua:853`; `load_engine.lua:862`; `load_engine.lua:884`; `load_engine.lua:894`; `load_engine.lua:904`; `load_engine.lua:1109` |
| `savedEntryAuditIdentity` | `load_engine.lua:267`; `load_engine.lua:1110` |
| `loadClock` | `load_engine.lua:62`; `load_engine.lua:179`; `load_engine.lua:184`; `load_engine.lua:190`; `load_engine.lua:211`; `load_engine.lua:231`; `load_engine.lua:254`; `load_engine.lua:258`; `load_engine.lua:412`; `load_engine.lua:453`; `load_engine.lua:456`; `load_engine.lua:600`; `load_engine.lua:603`; `load_engine.lua:1228`; `load_engine.lua:1234`; `load_engine.lua:1273`; `load_engine.lua:1280`; `load_engine.lua:1307`; `load_engine.lua:1320`; `load_engine.lua:1322`; `load_engine.lua:1334`; `load_engine.lua:1397`; `load_engine.lua:1399` |
| `loadChoiceShape` | `load_engine.lua:138`; `load_engine.lua:228`; `load_engine.lua:263`; `load_engine.lua:609` |
| `clearLoadScanTable` | `load_engine.lua:81`; `load_engine.lua:82`; `load_engine.lua:83`; `load_engine.lua:84`; `load_engine.lua:85`; `load_engine.lua:86`; `load_engine.lua:87`; `load_engine.lua:88` |
| `scanLoadOptions` | `load_engine.lua:691` |
| `resolveLoadChoice` | `load_engine.lua:574`; `load_engine.lua:792`; `load_engine.lua:823`; `load_engine.lua:940`; `load_engine.lua:1024` |
| `loadOptionNeedsLongSettle` | `load_engine.lua:262` |
| `pollPendingOption` | `load_engine.lua:690` |
| `beginPendingChange` | `load_engine.lua:618`; `load_engine.lua:888`; `load_engine.lua:971`; `load_engine.lua:1056` |
| `clearVisibleLoadSatisfaction` | `load_engine.lua:367`; `load_engine.lua:393`; `load_engine.lua:724`; `load_engine.lua:776` |
| `checkPendingChange` | `load_engine.lua:536`; `load_engine.lua:699` |
| `logLoadMeasurements` | `editor.lua:128`; `events.lua:95`; `events.lua:116`; `events.lua:349`; `load_engine.lua:911`; `load_engine.lua:986`; `load_engine.lua:1074`; `load_engine.lua:1135`; `load_engine.lua:1175` |
| `releaseFinishedLoadWorkingData` | `events.lua:45`; `events.lua:351`; `load_engine.lua:1265` |
| `forceFullLoadWarning` | `ui/sections_load.lua:39` |
| `syncForceFullLoadSelection` | `load_engine.lua:1213`; `load_engine.lua:1308`; `ui/sections_load.lua:7` |
| `finalVerifyUnconfirmed` | `load_engine.lua:1159` |
| `confirmLoadGroup` | `load_engine.lua:701` |
| `isSecondaryLoadOption` | `load_engine.lua:569` |
| `applyLoadGroup` | `load_engine.lua:782` |
| `writeLoadGroup` | `load_engine.lua:585`; `load_engine.lua:768` |
| `beginLoadPass` | `load_engine.lua:1259` |
| `continueLoadPass` | `load_engine.lua:1261` |
| `performPresetLoad` | `loadPreset` passes it to `pcall`; baseline `load_engine.lua:1277`. |
| `loadPreset` | `events.lua:362`; `history.lua:108`; `load_engine.lua:1297`; `native_bridge.lua:255`; `ui/sections_load.lua:251` |
| `restoreLastAppearance` | `native_bridge.lua:394`; `ui/sections_load.lua:261` |
| `refreshPreflight` | `ui/sections_load.lua:311` |
| `resetLoadState` | `acu_import.lua:156`; `backup.lua:376`; `bundles.lua:461`; `catalog.lua:201`; `catalog.lua:212`; `editor.lua:130`; `events.lua:97`; `events.lua:118`; `events.lua:290`; `events.lua:350`; `folders.lua:120`; `folders.lua:296`; `history.lua:106`; `load_engine.lua:1218`; `load_engine.lua:1224`; `load_engine.lua:1295`; `native_bridge.lua:253`; `native_bridge.lua:304`; `native_bridge.lua:315`; `presets.lua:272`; `presets.lua:406`; `presets.lua:548`; `presets.lua:593`; `presets.lua:752`; `trash.lua:287`; `trash.lua:470`; `trash.lua:661`; `ui/sections_load.lua:181`; `ui/sections_load.lua:246`; `ui/sections_load.lua:320` |
| `onUpdate` | Framework callback or compatibility entry. |
| `releaseIdleMemory` | `events.lua:367`; `events.lua:406` |

## Architecture and compatibility boundary

The machine is an incremental reducer: transition(plainState, plainEvent) returns the same caller-owned state table and a read-only action list. It uses the stage 3 constructors unchanged and receives timing/config values explicitly. There is no runtime, logging, filesystem or Game access in application/loading.lua.

Each checkpoint emits one directive. The adapter performs the next observation/effect at the old boundary, then feeds the result back. This keeps reads and writes interleaved as before instead of capturing a new complete option list each frame. Action payloads come from explicit event/state values and the adapter's existing locals. Before-call references remain tied to their original observation even if a callback resets state during a game call.

adapters/game_options.lua owns those boundaries, the original caches and matching loops, pcall/null checks, metrics, camera handling, status messages and logs. load_engine.lua is a compatibility facade that installs the old names. events.onUpdate retains its unrelated work and delegates the automatic-load portion. The existing editor-open watchdog remains in events.lua for stage 9.

The private control view contains only the fields needed by a checkpoint. Game-bearing scanResult and optionsMemo objects are excluded from its input. Plain pending/batch records and saved-entry maps may be shared explicitly; no game option object enters the machine. Published values stay in state.load and state.app at their existing locations. No persistent fields are added.

State, event and action tables are reused. Event/control key storage is reserved during installation; borrowed maps and private scratch references are cleared at the original release/reset boundaries. The reset directive calls the captured stage 4 resetLoadState once, then clears only the new private scratch. It adds no second reset, preserves the original zero-value return, and keeps that function's implementation unchanged. A headless executor applies the same directive with the stage 3 reset constructor; the next observation supplies the reset result.

| Event family | Pure responsibility |
|---|---|
| load_request, begin, entries | Same-name continuation versus a new request; exact partial begin reset; prepared entries. |
| update, finish_update | Invocation guard, elapsed/timer progression, safety timeout, automatic stop and idle-release decision. |
| scan_begin, scan_dependency, scan_finish | Signature rebuild/exposure policy and dependency invalidation. Game reads and scan records remain in the adapter. |
| attempt, begin_pending | Acknowledged-write counters and the existing plain pending record. |
| pending_identity, pending, poll_* | Identity/shape fallback, confirmation, disappearance, settle waits and unconfirmed classification. |
| group_begin/member/collect/finish | Batch observations and existing wait accounting. |
| group_budget/invalid/values/append/finish_write | Capacity/time limits, interrupted preparation, staging and accepted-write bookkeeping. |
| choice_gate/stage, pass_start/gate, finish_pass | Main/secondary/verify stages and precleanup/apply/cleanup/verify progression. |
| count_remaining, unresolved, complete | Repeated-signature stop and terminal counts/flags. |
| release_gate/release, reset | Release directive or the legacy reset action, including existing omissions. |
| invocation, camera_enter/exit | Invocation count and per-call guard restoration. |

The action catalog is read-only after module initialization. Independent headless states do not share constructor-owned maps. The adapter does not copy game objects into a synthetic per-frame snapshot or introduce a new retry policy.

## Timing and thresholds, unchanged

| Value | Baseline location | Meaning |
|---|---|---|
| maximumGroupChanges = 4 | constants.lua:37 | Maximum accepted writes in a prepared group. |
| groupBudgetSeconds = 0.004 | constants.lua:38 | Soft CPU-clock budget for that group. |
| passInterval = 0.225 | constants.lua:39 | Existing normal pass interval. |
| pollInterval = 0.05 | constants.lua:40 | Pending/dependency poll interval. |
| dependencyTimeout = 1.25 | constants.lua:41 | Existing unconfirmed/deadline threshold. |
| dependencyStableTime = 0.20 | constants.lua:42 | Existing dependency settle wait. |
| FORCE_FULL_LOAD_FORMAT_THRESHOLD = 7 | constants.lua:44 | Automatic legacy force selection. |
| minimumSeconds = 60 | constants.lua:49 | Automatic-load safety minimum. |
| secondsPerOption = 2 | constants.lua:50 | Per-saved-option safety allowance. |
| Safety margin = 10 seconds | events.lua, old maximumSeconds expression | Moved literal to adapter-local AUTO_LOAD_SAFETY_MARGIN, with the same value. |
| STALL_CONFIRMATION_PASSES = 3 | constants.lua:54 | Identical unresolved signatures needed to stop. |
| EDITOR_OPEN_TIMEOUT = 5.0 | constants.lua:55 | Editor-open watchdog, unchanged in events.lua. |
| maximumScannedPresets = 8192; maximumScannedEntries = 1048576 | constants.lua:51–52 | Requester scan limits, unchanged. |
| OPTION_CHOICE_CACHE_LIMIT = 16384 | constants.lua:35 | Existing stage 7 choice-cache cutoff. |

The safety formula remains max(60, valueCount * 2 + 10), with elapsed > maximumSeconds. Pending waits use the same < 1.25 and < 0.20 comparisons. Group settling remains capped by its existing deadline. The baseline has attempt counters but no separate retry-limit constant; an unconfirmed saved change is not immediately repeated, and cleanupSkipped suppresses another cleanup attempt in that context.

## Fixture provenance and results

An initial set of 26 scenarios was recorded before production extraction. Expanded cases were recorded from immutable load_engine.lua and events.lua sources at commit 64b9c7414a61a7e72180fda38c4cb575cad6f5a4, supplied directly to the restricted loader. The recorded outputs were not generated from the extracted loader.

All 46 scenarios match the baseline. Fixtures retain complete external action/log/status order, ordered game-field reads, matching calls, every observed phase/pending/batch state, per-update call counts, and complete final state.load/state.app graphs. Known fake game references are represented by stable IDs, including weak option bindings. This normalization does not turn a real game capture into evidence; the game adapter and timing inputs are scripted fakes.

Coverage includes normal and delayed loads, ten-option groups, exhausted group budgets, missing/repeated-unresolved stops, failed writes including a failure after an earlier accepted write, unconfirmed writes, safety boundaries, option disappearance, choice/slot/label changes, fast-poll fallback, screen close, shutdown and Lua reload. Both old menu ingress paths are stressed during precleanup, apply, cleanup and settle. Extra callback cases replace an attempt map inside a write and close the editor inside an option observation, preserving the old captured references.

The CET widget is disabled while auto is true. Its direct-ingress stress scenarios call the same Lua load-button body to exercise the requested supersede paths; they do not prove that a normal click can enter that path while disabled. Native request processing uses the actual existing startSelectedLoad/updateNativeBridge logic with a fake bridge. Real input reachability and Codeware reentrancy remain UNVERIFIED.

| Validation | Result |
|---|---|
| Stage 1 | 833 fixtures; binary/naming/fallback checks pass. |
| Stage 2 | 183 fixtures, 62 accepted writes and 7 format-8 round trips pass. |
| Stage 3 | 63 state fixtures and existing timeout regressions pass. |
| Stage 4 | 2,981 comparisons, including 396 interruption/recovery cases, pass. |
| Stage 5 | 6,349 comparisons pass. |
| Stage 6 | 9,039 comparisons, including 426 interruptions, pass. |
| Stage 7 | 67 baseline comparisons pass. |
| Stage 8 Part A | 46 timed scenarios, callback stress and headless isolation pass. |
| Lua 5.1 syntax | All 80 Lua files parse with installed luaparse; tests execute in the installed Lua 5.1 DLL. |
| redscript | Isolated scc compilation succeeds. Compiler, vanilla cache, five Codeware declarations and four CPM scripts match the installed inputs. |

Editor-hook source, shutdown/overlay callbacks and unrelated event paths match the baseline. Stage 3 state and stage 7 matching modules are unchanged. The packaging comparison also checks earlier production modules, UI, redscript, native plugin and presets byte-for-byte.

## Every scenario: original versus extracted

All action/log/read sequences, full final states and the per-update profiles match, not just these totals. Tables counts cover production Lua table constructors across all loaded production modules. The stored allocation metadata also asserts each individual OnUpdate count. Clock means the existing loadClock boundary; it is not a wall-time benchmark.

| Scenario | Updates old/new | loadPreset old/new | Clock calls old/new | Production tables old/new | Baseline result |
|---|---:|---:|---:|---:|---|
| normal full load | 22/22 | 23/23 | 178/178 | 835/835 | complete |
| counter map replaced inside write | 22/22 | 23/23 | 178/178 | 834/834 | complete |
| editor closes inside option observation | 2/2 | 3/3 | 24/24 | 194/194 | No SUMMARY emitted |
| choice shape changes during settle | 40/40 | 41/41 | 286/286 | 1378/1378 | complete-with-warning |
| option label changes during settle | 22/22 | 23/23 | 178/178 | 839/839 | complete |
| option slot changes during settle | 22/22 | 23/23 | 178/178 | 857/857 | complete |
| option disappears during settle | 22/22 | 23/23 | 178/178 | 735/735 | complete |
| single remap and fast polling | 11/11 | 12/12 | 87/87 | 364/364 | complete |
| target poll identity fallback | 12/12 | 13/13 | 93/93 | 404/404 | complete |
| unset camera guard | 22/22 | 23/23 | 178/178 | 834/834 | complete |
| ten-option grouped load | 19/19 | 20/20 | 280/280 | 2062/2062 | complete |
| ten-option delayed groups | 24/24 | 25/25 | 310/310 | 2503/2503 | complete |
| exhausted group time budget | 7/7 | 8/8 | 95/95 | 343/343 | complete |
| choice structure changed | 22/22 | 23/23 | 178/178 | 834/834 | complete |
| dependent option disappears | 23/23 | 24/24 | 184/184 | 749/749 | complete |
| choices reordered after write | 22/22 | 23/23 | 178/178 | 834/834 | complete |
| timeout immediately below threshold | 3/3 | 3/3 | 23/23 | 205/205 | No SUMMARY emitted |
| timeout exactly at threshold | 3/3 | 3/3 | 23/23 | 205/205 | No SUMMARY emitted |
| timeout above threshold | 2/2 | 2/2 | 17/17 | 175/175 | No SUMMARY emitted |
| delayed several passes | 28/28 | 29/29 | 214/214 | 1020/1020 | complete |
| unavailable and repeated unresolved | 22/22 | 23/23 | 185/185 | 832/832 | stopped |
| failed write | 1/1 | 1/1 | 10/10 | 121/121 | No SUMMARY emitted |
| failure after earlier accepted write | 14/14 | 15/15 | 110/110 | 596/596 | No SUMMARY emitted |
| write never confirmed | 82/82 | 83/83 | 540/540 | 2660/2660 | complete-with-warning |
| automatic timeout | 2/2 | 2/2 | 17/17 | 175/175 | No SUMMARY emitted |
| editor closed mid-load | 1/1 | 2/2 | 17/17 | 175/175 | No SUMMARY emitted |
| shutdown mid-load | 1/1 | 2/2 | 17/17 | 164/164 | No SUMMARY emitted |
| CET reload mid-load | 1/1 | 2/2 | 17/17 | 188/188 | No SUMMARY emitted |
| game read unavailable | 1/1 | 1/1 | 4/4 | 36/36 | No SUMMARY emitted |
| options disappear during load | 2/2 | 3/3 | 21/21 | 154/154 | No SUMMARY emitted |
| no selection during update | 2/2 | 2/2 | 17/17 | 153/153 | No SUMMARY emitted |
| no selected preset | 1/1 | 1/1 | 2/2 | 35/35 | No SUMMARY emitted |
| unreadable selected preset | 1/1 | 1/1 | 2/2 | 46/46 | No SUMMARY emitted |
| empty preset | 1/1 | 1/1 | 4/4 | 79/79 | No SUMMARY emitted |
| idle update | 1/1 | 0/0 | 0/0 | 24/24 | No SUMMARY emitted |
| editor-open timeout | 1/1 | 0/0 | 0/0 | 24/24 | No SUMMARY emitted |
| supersede cet during precleanup | 23/23 | 25/25 | 194/194 | 925/925 | complete |
| supersede cet during apply | 23/23 | 25/25 | 191/191 | 899/899 | complete |
| supersede cet during cleanup | 36/36 | 38/38 | 293/293 | 1323/1323 | complete |
| supersede cet during settle | 23/23 | 25/25 | 190/190 | 899/899 | complete |
| supersede native during precleanup | 23/23 | 25/25 | 194/194 | 938/938 | complete |
| supersede native during apply | 24/24 | 26/26 | 197/197 | 940/940 | complete |
| supersede native during cleanup | 37/37 | 39/39 | 299/299 | 1371/1371 | complete |
| supersede native during settle | 23/23 | 25/25 | 195/195 | 930/930 | complete |
| native request invocation guard | 18/18 | 19/19 | 154/154 | 737/737 | complete |
| preexisting camera guard | 22/22 | 23/23 | 178/178 | 834/834 | complete |

No new option scans, game reads, writes, clock calls or production table constructors appear in the recorded runs. Per-update constructor/call profiles match as well as full-run totals. One-time module tables are created at installation. Thin dispatch and scalar projection add overhead; VM table resizing, GC behavior and real CET frame time remain UNVERIFIED. These checks do not claim a measured zero CPU cost for separation.

The fake clock can cross the group budget and safety boundary without changing thresholds. Allocation instrumentation wraps source table constructors in both the original and extracted modules; expected whole-run and per-update counts live in stage8_fixtures.allocations. Trusted instrumentation and fixture/trace allocations are outside that count. The new reducer makes 398 internal checkpoint calls in the normal scenario; the old loader had no separate reducer call. Those internal counters are excluded from external-trace equality. The public OnUpdate/loadPreset counts remain 22/23 in both builds, and the projection/dispatch cost is not a measured zero.

## Permanent supersede regression coverage

Keep all eight phase/entry-path cases in stage8_tests.lua and their original outputs in stage8_fixtures.lua as permanent regression tests. They are part of the required 46-case comparison, so removing or changing one fails the fixture-name/count or output assertions. Do not regenerate their expected output from the extracted loader. The baseline is stage 7 commit 64b9c7414a61a7e72180fda38c4cb575cad6f5a4, including cancel removal and the timeout fix.

The table records the original behavior. Pending/batch columns describe the sample immediately after starting the second load, which already executes its first synchronous pass; they are not observations taken between reset and that pass. All eight finish with indices Eyes=1, SkinColor=2 and unused Hair=0, busy=false and camera suppression=false. Each emits one terminal SUMMARY for Second, with processed=2, confirmed=2 and every warning/failure count zero. The first operation has no terminal SUMMARY in these cases.

| Entry | Interrupted phase | Phase after new call | Pending | Batch | Second preset passes | Result |
|---|---|---|---|---|---:|---|
| cet | precleanup | precleanup | false | false | 24 | complete |
| cet | apply | apply | false | false | 16 | complete |
| cet | cleanup | apply | false | false | 16 | complete |
| cet | settle | precleanup | false | true | 23 | complete |
| native | precleanup | precleanup | false | false | 24 | complete |
| native | apply | apply | false | false | 17 | complete |
| native | cleanup | apply | false | false | 17 | complete |
| native | settle | precleanup | false | false | 23 | complete |

Full action/log order, per-update phase and pending/batch snapshots, counts and final state graphs remain in the immutable fixtures. Real visual equipment/rendering is not modeled. The CET disabled-button limitation still applies to direct-ingress stress cases.

Baseline logging has no dedicated superseded-load message. No new runtime log line is added. Scripted start/superseded trace markers are test observations, not game logging. The lack of a first-load SUMMARY is preserved as recorded.

## Exit-release evidence

Busy means both the load flags used by the bridge and its cached nativeBusy value. Camera guard means presetCameraHold; suppression is separately queried through the unchanged RequestCameraChange hook. A cleared Lua record does not cancel a write already accepted by the game. The fake queued writes make this distinction visible.

| Exit | Busy status | Camera guard / suppression | Pending writes | Batch | Working data | Evidence |
|---|---|---|---|---|---|---|
| Completion | auto/needsContinue/pending cleared; SetBusy(false) on the next bridge update | Per-call guard restored; suppression off for the normal initial guard | Lua pending cleared; accepted changes remain applied | Cleared | releaseLoadWorkingData clears load work and memo | normal full load; performPresetLoad release gate, release handler, finish_update; native_bridge.lua busy update |
| Unresolved stop | Same normal release; stopped SUMMARY retained | Guard restored; suppression off in the normal case | Pending nil | Cleared by terminal release | Released | unavailable and repeated unresolved; unresolved -> markStalled -> release gate |
| Timeout | Full reset/release; immediate finishTimedOutNativeLoad SetBusy(false) | Explicit false plus cleared load flags | Pending nil; no new cancellation API | Cleared | Reset plus full release; preflight invalidated; updateStarted nil | automatic timeout and boundary scenarios; update timeout branch |
| Failed write | markStalled then existing terminal release; bridge clears busy | Protected-call wrapper restores the old guard | New failed write has no pending record; an earlier accepted write is not rolled back | Cleared by release | Released in these scenarios | failed write; failure after earlier accepted write |
| Editor close/reopen between updates | Flags reset; cached bridge busy clears on its next active update | Guard not forced false by reset; normal false restored already; inCustomization=false permits the camera | Lua record reset; fake accepted delayed write remains queued | Reset | values/stage work reset; scanResult retained | editor closed mid-load; unchanged OnUninitialize; legacy reset constructor |
| Supersede via CET ingress | New operation stays busy | Per-call guard restored; new operation still suppresses automatic focus | Old pending can survive beginLoad; accepted writes are not canceled | Existing batch can survive beginLoad | New entry maps replace some work; elapsed/signature/dependency/warning data can carry over | four supersede cet scenarios; unchanged CET request body and stage 3 beginLoad omissions |
| Supersede via native ingress | Reset then new operation stays busy | New load takes its normal guard | Old Lua pending reset; accepted delayed writes remain | Old batch reset; new work can exist immediately | Existing reset omissions remain; new operation repopulates work | four supersede native scenarios; native_bridge.lua startSelectedLoad |
| Shutdown | Flags reset; nativeBusy is not explicitly cleared and remains true in the fake because ready=false stops later bridge updates | inCustomization=false permits the camera; no extra guard clear | Lua pending reset; accepted delayed write remains queued | Reset | scanResult retained; catalog/memo cleared separately | shutdown mid-load; unchanged events.onShutdown |
| CET reload model | Fresh load/app plus init; next bridge update is not busy | Fresh app guard nil; suppression off | Lua state replaced; fake accepted write remains queued | New state has no batch | Fresh constructor drops scan cache | CET reload mid-load; shutdown + fresh constructors + init/open callbacks |
| Selection lost during update | Only auto stops; needsContinue and busy can remain true | Guard restored but suppression remains through needsContinue | Existing pending/accepted work can remain | Retained in this scenario | Retained | no selection during update; update -> stopAutomatic |
| Options unavailable during an active load | stopForUnavailableOptions clears busy flags | Guard restored; suppression off | Lua pending cleared | Cleared | values/scan/stage work can remain because performPresetLoad returns before full release | options disappear during load |
| Close injected inside option observation | Flags can be reset, but old batch processing resumes afterward | Normal guard restored; inCustomization=false permits camera | Old observed pending can enter the old waiting list after reset | Re-created waiting batch retained | scan cache retained | editor closes inside option observation; captured pending/group locals preserved |
| Preexisting true camera guard | Load completes normally | Previous true guard is restored; suppression stays on while in customization | Normal release | Normal release | Normal release | preexisting camera guard; this is not changed to a forced false |

Key current code locations:

- Automatic scheduling/timeout: `application/loading.lua:64`.
- Pending confirmation/unconfirmed policy: `application/loading.lua:89`.
- Batch wait accounting: `application/loading.lua:172`.
- Continue versus begin: `application/loading.lua:228`.
- Terminal release decision: `application/loading.lua:232`.
- Stage 3 full release: `application/loading.lua:267`.
- Legacy reset directive: `application/loading.lua:275`.
- Reset compatibility interpreter: `adapters/game_options.lua:74`.
- Load request and terminal boundary: `adapters/game_options.lua:1156`.
- Automatic-load effects and timeout cleanup: `adapters/game_options.lua:1352`.
- Existing partial reset: `domain/state.lua:97`.
- Existing partial begin: `domain/state.lua:190`.
- Existing bridge busy derivation: `native_bridge.lua:490`.

The reload scenario reinitializes Lua load/app state and runs the existing callbacks while the fake game stays alive. It does not prove actual CET cache teardown, panel registry lifetime or Codeware callbacks. Those remain UNVERIFIED and need the in-game reload check. The shutdown cached-busy observation does not prove a visible panel remains after shutdown.

## Defects found, unchanged

- Losing the selection can stop auto while needsContinue/batch/work remain active. The camera hook and bridge still see busy state. This is the old no-selection update branch and is not the earlier timeout bug.
- resetLoadState delegates to stage 3 resetLoad, which does not clear scanResult. Close/reopen and shutdown retain that cache in the fixtures. It also preserves the existing omitted preflight/comparison/force-selection fields; this is not a new full reset.
- CET and native new-load preparation differ. beginLoad keeps pendingChange, batch, elapsed, signature/dependency and warning state that a native reset clears. The scripted supersede sequences preserve that difference. The CET widget's busy disable and real request timing are separate from a direct ingress call.
- An unavailable option collection during a running load clears some flags but returns before full working-data release. No cleanup was added to that early return.
- An unconfirmed saved write is counted as processed without being repeated. Unconfirmed cleanup sets cleanupSkipped, so the same cleanup key is not retried in that context. Existing status/SUMMARY warnings are preserved.
- Resetting logical work does not undo or cancel an accepted Game write. The fake delayed queue remains pending across close/shutdown/reload. Real Codeware completion and rendering behavior are UNVERIFIED.
- The injected close-inside-observation case can recreate a waiting batch after the close reset, as in the baseline. Whether real Codeware can call the close observer at that exact boundary is UNVERIFIED. It is a callback stress case, not a diagnosis of the reported visual bug.
- A preexisting camera guard is restored rather than forced false. Normal guards are false/nil on exit; the explicit timeout path still forces false. Shutdown does not separately clear the cached bridge busy flag.
- Missing preset dependencies can explain the old eyelash/unavailable-choice stops. No matching or mod-installation fix is included.
- Rapid-load leftover hair/cyberware: **could not be reproduced after the cancel removal and timeout fix (UNVERIFIED cause)**. Part B is skipped. Relevant paths remain `application/loading.lua:228` (new request), `application/loading.lua:262` and `domain/state.lua:190` (partial begin), `application/loading.lua:89` (pending settle/unconfirmed), `application/loading.lua:247` (cleanup progression), `adapters/game_options.lua:714` (cleanup eligibility), `adapters/game_options.lua:721` (cleanup writes), and `native_bridge.lua:248` (native reset before a new load). These paths identify where state and cleanup are handled; they do not establish the cause of the former visual issue.

Real error payloads and stack-trace source locations are UNVERIFIED. Moving code changes traceback locations; application message formats and the supplied fake error payloads match the baseline. No new game API or guessed Codeware method was added.

## Old entry points and remaining callers

The old exported functions/helpers keep their names, argument order and return behavior. Functions now defined in the adapter are installed through the compatibility facade. resetLoadState forwards to its original implementation; other stage modules are not rewritten. These are the current callers, with module-relative lines.

| Entry | Remaining callers |
|---|---|
| `logLoadOnce` | `adapters/game_options.lua:385`; `adapters/game_options.lua:389`; `adapters/game_options.lua:798`; `adapters/game_options.lua:805`; `adapters/game_options.lua:815`; `adapters/game_options.lua:1037`; `adapters/game_options.lua:1062` |
| `loadOptionIdentity` | `adapters/game_options.lua:322`; `adapters/game_options.lua:487`; `adapters/game_options.lua:502`; `adapters/game_options.lua:800`; `adapters/game_options.lua:808`; `adapters/game_options.lua:817`; `adapters/game_options.lua:839`; `adapters/game_options.lua:849`; `adapters/game_options.lua:859`; `adapters/game_options.lua:1064` |
| `savedEntryAuditIdentity` | `adapters/game_options.lua:325`; `adapters/game_options.lua:1065` |
| `loadClock` | `adapters/game_options.lua:136`; `adapters/game_options.lua:246`; `adapters/game_options.lua:251`; `adapters/game_options.lua:257`; `adapters/game_options.lua:274`; `adapters/game_options.lua:294`; `adapters/game_options.lua:309`; `adapters/game_options.lua:313`; `adapters/game_options.lua:398`; `adapters/game_options.lua:439`; `adapters/game_options.lua:442`; `adapters/game_options.lua:569`; `adapters/game_options.lua:574`; `adapters/game_options.lua:1172`; `adapters/game_options.lua:1178`; `adapters/game_options.lua:1216`; `adapters/game_options.lua:1224`; `adapters/game_options.lua:1251`; `adapters/game_options.lua:1264`; `adapters/game_options.lua:1266`; `adapters/game_options.lua:1278`; `adapters/game_options.lua:1341`; `adapters/game_options.lua:1343` |
| `loadChoiceShape` | `adapters/game_options.lua:206`; `adapters/game_options.lua:291`; `adapters/game_options.lua:321`; `adapters/game_options.lua:581` |
| `clearLoadScanTable` | `adapters/game_options.lua:155`; `adapters/game_options.lua:156`; `adapters/game_options.lua:157`; `adapters/game_options.lua:158`; `adapters/game_options.lua:159`; `adapters/game_options.lua:160`; `adapters/game_options.lua:161`; `adapters/game_options.lua:162` |
| `scanLoadOptions` | `adapters/game_options.lua:654` |
| `resolveLoadChoice` | `adapters/game_options.lua:546`; `adapters/game_options.lua:747`; `adapters/game_options.lua:778`; `adapters/game_options.lua:895`; `adapters/game_options.lua:979` |
| `loadOptionNeedsLongSettle` | `adapters/game_options.lua:320` |
| `pollPendingOption` | `adapters/game_options.lua:653` |
| `beginPendingChange` | `adapters/game_options.lua:588`; `adapters/game_options.lua:843`; `adapters/game_options.lua:926`; `adapters/game_options.lua:1011` |
| `clearVisibleLoadSatisfaction` | `adapters/game_options.lua:377`; `adapters/game_options.lua:384`; `adapters/game_options.lua:678`; `adapters/game_options.lua:731` |
| `checkPendingChange` | `adapters/game_options.lua:518`; `adapters/game_options.lua:662` |
| `logLoadMeasurements` | `editor.lua:128`; `events.lua:95`; `events.lua:116`; `adapters/game_options.lua:866`; `adapters/game_options.lua:941`; `adapters/game_options.lua:1029`; `adapters/game_options.lua:1085`; `adapters/game_options.lua:1119`; `adapters/game_options.lua:1359` |
| `releaseFinishedLoadWorkingData` | `events.lua:45`; `adapters/game_options.lua:1208`; `adapters/game_options.lua:1361` |
| `forceFullLoadWarning` | `ui/sections_load.lua:39` |
| `syncForceFullLoadSelection` | `ui/sections_load.lua:7`; `adapters/game_options.lua:1157`; `adapters/game_options.lua:1252` |
| `finalVerifyUnconfirmed` | `adapters/game_options.lua:1108` |
| `confirmLoadGroup` | `adapters/game_options.lua:664` |
| `isSecondaryLoadOption` | `adapters/game_options.lua:541` |
| `applyLoadGroup` | `adapters/game_options.lua:737` |
| `writeLoadGroup` | `adapters/game_options.lua:557`; `adapters/game_options.lua:721` |
| `beginLoadPass` | `adapters/game_options.lua:1203` |
| `continueLoadPass` | `adapters/game_options.lua:1205` |
| `performPresetLoad` | `adapters/game_options.lua:1220`, through `pcall` in `loadPreset`. |
| `loadPreset` | `history.lua:108`; `native_bridge.lua:255`; `ui/sections_load.lua:251`; `adapters/game_options.lua:1241`; `adapters/game_options.lua:1371` |
| `restoreLastAppearance` | `native_bridge.lua:394`; `ui/sections_load.lua:261` |
| `refreshPreflight` | `ui/sections_load.lua:311` |
| `resetLoadState` | `acu_import.lua:156`; `backup.lua:376`; `bundles.lua:461`; `catalog.lua:201`; `catalog.lua:212`; `editor.lua:130`; `events.lua:97`; `events.lua:118`; `events.lua:290`; `folders.lua:120`; `folders.lua:296`; `history.lua:106`; `native_bridge.lua:253`; `native_bridge.lua:304`; `native_bridge.lua:315`; `presets.lua:272`; `presets.lua:406`; `presets.lua:548`; `presets.lua:593`; `presets.lua:752`; `trash.lua:287`; `trash.lua:470`; `trash.lua:661`; `ui/sections_load.lua:181`; `ui/sections_load.lua:246`; `ui/sections_load.lua:320`; `adapters/game_options.lua:1162`; `adapters/game_options.lua:1168`; `adapters/game_options.lua:1239`; `adapters/game_options.lua:1360` |
| `onUpdate` | Framework callback or retained compatibility entry. |

## CET sandbox

The full stages 1–8 suite runs with the restricted loader. The new machine is additionally checked at every observed transition: state/events/results must contain only plain data, with no metatables, functions or userdata. The adapter's game objects remain outside that boundary.

| New production module | Globals | Baseline proof |
|---|---|---|
| application/loading | require, ipairs, pairs, tonumber; math.max/min | These are used by old load_engine.lua/events.lua. math.min already caps group settling in the old loader. |
| adapters/game_options | Full list below | Every name is in the union of those same two baseline modules, which share the existing runtime environment. |

```text
AUTO_LOAD_LIMITS, AUTO_LOAD_TIMING, FORCE_FULL_LOAD_FORMAT_THRESHOLD, LAST_APPEARANCE_FILE,
SLOW_PREFLIGHT_SECONDS, STALL_CONFIRMATION_PASSES, beginLoadPass, compareSelectedPreset,
continueLoadPass, error, getOptions, helpers, hydrateNamedPreset, ipairs, loadPreset, log,
logAcuDangerousOptions, math, next, occurrenceKeyParts, optionAuditIdentity, optionChoiceIndex,
optionChoiceMatchesIndex, optionIndexIsValid, optionKey, optionSlot, os, pairs, pcall,
readPresetFile, refreshAppearanceHistory, refreshCustomizationUi, refreshPreflight, require,
resetLoadState, restoreAppearanceHistory, restoreLastAppearance, saveAppearanceHistorySnapshot,
savedEntryAuditIdentity, setStatus, setfenv, state, table, tonumber, tostring, unresolvedSignature,
writeInventory
```

The pure stage 5–8 allowlist is:

```text
ipairs, pairs, require, tonumber, tostring, type
math.floor, math.max, math.min
table.concat, table.insert, table.sort
```

The machine's only dependency is unchanged domain/state. Earlier pure-module dependencies remain allowed as before. The game adapter uses the old runtime globals and existing os.clock boundary. The gate denies new global/library/dependency access and self-tests coroutine, debug, package, io, os and _G rejection for pure modules. Tests use host debug/source tools and fake files; that is not permission for production modules to use them.

Legacy modules retain the 297-name allowlist and old namespace-member restrictions from stage8_sandbox.lua. No new io/os member is permitted. The previous fake directory entry shape is still UNVERIFIED; stage 8 does not change directory handling.

The complete inherited legacy allowlist is:

```text
ACTIVITY_LOG_PAGE_SIZE ACU_IMPORT_FILES_PER_FRAME ACU_IMPORT_POLL_SECONDS ACU_IMPORT_REQUEST_FILE
ACU_IMPORT_RESULTS_FILE APPEARANCE_HISTORY_LIMIT AUTO_LOAD_LIMITS AUTO_LOAD_TIMING CATALOG_DIR
CATALOG_FILE CName CONFIG_DIR CONFIG_FILE CURRENT_PRESET_FORMAT DATA_DIR EDITOR_OPEN_TIMEOUT
EMPTY_LIST EquipmentSystem FALLBACK_NOTICE_CET_MESSAGE FALLBACK_NOTICE_DELAY_SECONDS
FALLBACK_NOTICE_MESSAGE FALLBACK_NOTICE_TITLE FILE_COPY_CHUNK_SIZE FOLDER_BUNDLE_EXTENSION
FORCE_FULL_LOAD_FORMAT_THRESHOLD Game GetBind GetDisplayResolution GetLocalizedTextByKey HISTORY_DIR
HISTORY_FILE_PREFIX IMPORTED_BUNDLES_FILE INVENTORY_FILE ImGui ImGuiCol ImGuiCond ImGuiStyleVar
ImGuiWindowFlags IsBound LAST_APPEARANCE_FILE LIBRARY_BACKUP_EXTENSION LOG_ARCHIVE_DIR
LOG_ARCHIVE_LIMIT LOG_ARCHIVE_PREFIX LOG_DIR LOG_FILE LocKeyToString MAX_CATALOG_BYTES
MAX_CATALOG_LINES MAX_FOLDER_BUNDLE_BYTES MAX_FOLDER_BUNDLE_PRESETS MAX_LIBRARY_BACKUP_BYTES
MAX_OPTION_INDEX MAX_PRESET_BYTES MAX_PRESET_ENTRIES MAX_PRESET_KEY_BYTES MAX_PRESET_LINES
MAX_TRANSACTION_BYTES MAX_TRANSACTION_LINES MAX_TREE_DEPTH MOD_NAME MorphMenuUserData
NATIVE_BRIDGE_PROTOCOL NATIVE_FILE_CATALOG NATIVE_FILE_PROTOCOL NATIVE_LIST_LIMIT
NATIVE_READY_STATUS NATIVE_REQUEST_POLL_SECONDS NameToString OPTION_CHOICE_CACHE_LIMIT Observe
Override PRESET_DIR QuestDisableWardrobeSetRequest QuestRestoreWardrobeSetRequest RECOVERY_DIR
SLOW_PREFLIGHT_SECONDS STALL_CONFIRMATION_PASSES STATUS_SECTIONS THEME_COLORS THEME_VARS
TRANSACTION_FILE TRASH_CATALOG_FILE TRASH_DIR ToCName UI_LIST_PAGE_SIZE VERSION
WINDOW_POSITION_STATUS_FILE _G activityLogFile activitySequence addFolderAncestors assert
atomicReplace baseName beginLoadPass bit32 bulkPresetNamesInFolder canRunAppearanceRandomizer
cancelConfirmations catalogDecode catalogEncode choiceCollectionValue cleanupFailureMessage
clearAppearanceHistory clearFolderBundlePreview clearStatus cloneMap closeActivityLog
collapsibleSectionHeader coloredWrapped compactSubsectionButton comparePresetWithCurrent
compareSelectedPreset completeTransaction connectNativeBridgeForMenu continueLoadPass copyFile
createFolder dangerButton deleteFile deleteSelectedLibraryBackup dir directoryTreeContainsFiles draw
drawBackupSection drawBulkSection drawEditorSection drawFallbackHudNotice drawFoldersSection
drawHelpPanel drawLoadSection drawManageSection drawPageControls drawSaveSection drawSectionStatus
drawSettingsPanel drawTrashSection duplicateFolder duplicatePreset emptyCustomizationName emptyTrash
ensureFilteredViewCache ensureViewCache equipmentSystem error events exportLibraryBackup
exportSelectedBulkPresetBundle exportSelectedFolderBundle fileExists fileFingerprint
findExistingFolderName findPresetCollision finishCompactSubsection folderAncestorsExpanded
folderBundleFiles folderDepth folderNameExists folderPath fullWidthButton
gameWardrobeClothingSetIndex gameuiCharacterCustomizationEditTag getOptions helpHeading helpers
hydrateNamedPreset hydrateNamedPresetMetadata importAvailableFolderBundles importLibraryBackup
initializeAcuImport initializeNativeBridge invalidateBulkSelectionCache invalidateFilteredViewCache
invalidatePresetAndTrashCaches invalidateViewCache io ipairs isFolderBundleFilename isInFolderTree
isRuntimePointerText joinFolder libraryBackupFiles loadPreset log logAcuDangerousOptions
logTimestamp math movePresetToSelectedFolder moveSelectedBulkPresetsToFolder
nativeCatalogDirectoryEntries next normalizeSearch occurrenceKeyParts openFullAppearanceEditor
optionAuditIdentity optionChoiceIndex optionChoiceMatchesIndex optionIndexIsValid
optionIndexValidationError optionKey optionSlot os pagedRange pairs parentFolder pcall
persistVirtualState popFoldingHeaderTheme popTheme presetPath presetsMatch pushFoldingHeaderTheme
pushTheme readBoundedFile readConfig readNativeFileCatalog readPresetFile readVerifiedPresetCopy
recoverTransaction refreshAppearanceHistory refreshCustomizationUi refreshEditorState
refreshPreflight refreshPresets refreshTrash remapFolderTreePath removeEmptyDirectoryTree
removeFileList removeVirtualFolder renameFile renameFolder renamePreset requestAcuImport
requestBulkTrash require resetLoadState restoreAppearanceHistory restoreLastAppearance
restoreTemporarilyDisabledWardrobe restoreTrashBundle restoreTrashGroup restoreTrashPreset
runAppearanceRandomizer safeDirectoryEntries sanitizeMetadata sanitizeName
saveAppearanceHistorySnapshot saveLastAppearanceSnapshot savePreset savePresetMetadata
savedEntryAuditIdentity selectedBulkPresetNames setEditorOpenStatus setPresetSortPreference
setStatus setfenv setmetatable sortedFolderNames stableChoiceIdentity stableRuntimeValue state
storageFilenamesInUse string table temporarilyDisableWardrobe textMatches
toggleSelectedPresetFavorite tonumber tostring trashPreset trashSelectedFolderBundle
trimAppearanceHistory type ui uniqueFolderCopyName uniquePresetCopyName uniqueStorageName
unresolvedSignature updateAcuImport updateNativeBridge utf8 validModifiedTimestamp validRelativePath
validatedFolderName validatedPresetName verifiedNativeFileCatalog viewSelectedFolderBundleContents
writeCatalog writeConfig writeFileSafely writeInventory writeLinesIfChanged writeLog
writePresetContents writePresetPath writeTransaction
```

The inherited namespace members are io.open; os.clock/date/time/rename/remove; math.ceil/floor/max/min; table.concat/insert/remove/sort; and string.char/rep. They remain separate from the narrower pure-module allowlist.

## Exact install delta

Exit the game and extract the Stage 8 Part A Test archive into the Cyberpunk 2077 folder. Keep Character Presets and Data. These four runtime files live under bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/modules:

```text
load_engine.lua
events.lua
application/loading.lua
adapters/game_options.lua
```

New audit/test files in the full archive are domain/STAGE8.md, domain/stage8_tests.lua, domain/stage8_fixtures.lua and domain/stage8_sandbox.lua. init.lua does not load those tests. Repository-only CHANGELOG.md and native/verification/check_code.js are not installed. The package retains all previous files in the three approved roots, with no release or version change. Format 8, backups, catalogs, settings and bridge protocol 1 are untouched.

## In-game Part A checklist

Keep the Stage 7 Activity Log and use the same presets/mod setup. Check Data/Logs/Activity.log, the per-mod CET error log, CET scripting/engine logs and the redscript log. Do not treat a changed mod list as the same matching input.

1. Start the game. Expect `[CONFIG] Loaded ...`, `Preset files loaded: presets=...`, and `[NATIVE PANEL] Native bridge connected.` Confirm both menus respond and no require, forbidden-global, runtime or compile error appears. The new modules do not add loaded messages.
2. Load a known working preset. Compare CHANGE targets/order, SETTLED results, PRECLEANUP/APPLY/CLEANUP progression, and the final SUMMARY to Stage 7. A fully confirmed load should keep processed/confirmed counts and result=complete, with the same unconfirmed/forced/cleanupUnconfirmed counts. Real pass totals/wait times can vary with scheduling; do not infer a matching regression from timing alone.
3. Load a preset with known unavailable choices under the same dependency setup. Expect the same `[SKIPPED] Saved choice is no longer exposed ...` or `[SKIPPED] Saved option unavailable in current editor/body setup ...` lines and the old `applied=... unresolved=... result=stopped` SUMMARY. Missing eyelash mods can be a preset dependency issue. Confirm normal camera/busy release after the stop; do not expect all saved values to have applied.
4. Start two loads quickly using the menus as their current controls allow. Keep both `[PRESET] Load requested: name='...'` lines and any SUMMARY lines. Compare the old cleanup/write order and resulting counts, without expecting the visible-leftover bug to be fixed. A superseded operation may not have its own terminal SUMMARY. Do not force a console ingress and describe it as a normal enabled button click.
5. Close the character screen while a load is active, then reopen it and load again. Expect `[MEASURE] Load editor-closed ...` when the old active-load condition applies, followed by `[UI] The character editor opened; ...` on reopening. Cancellation messages stay removed. Confirm the menu becomes usable and camera focus works; retain any new errors or stuck flags for comparison.
6. Load several presets in succession. Check the camera after each terminal result and verify the next load is available. Warning completion can retain `[UNCONFIRMED] ...` and result=complete-with-warning with the same counts as Stage 7. Clearing Lua state is not visual confirmation that hair/cyberware changed.
7. Reload CET mods while the editor is open. Expect the existing session-end diagnostics and new startup/config/preset/bridge lines, then confirm a fresh load works. Actual framework teardown and panel re-registration are UNVERIFIED by the fake test. Keep the error and activity logs if the menu fails to reconnect.
8. If the safety limit happens naturally, expect `[MEASURE] Load safety-limit ...` and `Loading took longer than the safety limit allows. Please report this and include the Activity Log so I can check what happened.` Both busy and automatic camera suppression should release as in the existing fix. Do not change the timeout constants to manufacture this test.

Part A changes no recovery policy for the listed baseline gaps. Part B is skipped. Stop after Part A; no further loader fix is authorized by this update.
