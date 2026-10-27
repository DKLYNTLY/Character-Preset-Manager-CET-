# Stage 3 original state inventory

This record was generated before extraction. It includes every assignment to `state.load` and `state.app`, including indexed writes inside matching and write loops. Those algorithm-owned writes stay in place; lifecycle assignment groups move without changing their conditions. Lua fields declared as nil are absent from the table.

## Fresh declarations

```lua
  app = {
    overlayOpen = false,
    windowOpen = true,
    ready = false,
    inCustomization = false,
    optionsMemo = nil,
    loadInvocation = 0,
    nativeBridge = nil,
    nativeBridgeSequence = 0,
    nativeBridgeUnavailableLogged = false,
    nativeBridgeRetryTimer = 0,
    nativeBusy = nil,
    nativeStatus = nil,
    nativeStatusError = nil,
    nativePanelStatus = NATIVE_READY_STATUS,
    nativePanelStatusError = false,
    nativePanelShowDetails = false,
    nativeLoadSummary = nil,
    nativeListRevision = -1,
    nativeListSelection = nil,
    nativeRequestPollTimer = 0,
  },
  load = {
    presetName = nil,
    overridePreset = nil,
    overrideName = nil,
    pass = 0,
    remaining = 0,
    needsContinue = false,
    stalled = false,
    previousUnresolvedSignature = nil,
    unresolvedRepeatCount = 0,
    satisfied = {},
    values = nil,
    savedCounts = nil,
    orderedEntries = nil,
    savedEntryByKey = nil,
    savedSlotCounts = nil,
    valueCount = 0,
    forcedKeys = {},
    resolvedChoiceIndexes = {},
    applyAttempts = {},
    unconfirmed = {},
    cleanupAttempts = {},
    cleanupSkipped = {},
    loggedWarnings = {},
    optionIdentityCache = {},
    targetPolls = 0,
    targetPollSeconds = 0,
    targetFallbacks = 0,
    pendingChange = nil,
    pendingElapsed = 0,
    phase = "apply",
    elapsed = 0,
    optionsSeconds = 0,
    scanCalls = 0,
    longestUpdate = 0,
    scanSeconds = 0,
    choiceSeconds = 0,
    applySeconds = 0,
    waitSeconds = 0,
    optionCalls = 0,
    structureChanges = 0,
    lastStructureSignature = nil,
    lastOptionCount = nil,
    forceStructureScan = true,
    scanResult = nil,
    targetPollingDisabled = false,
    returnToCleanup = false,
    dependencyKeys = {},
    dependencyRemaps = {},
    nextInterval = AUTO_LOAD_TIMING.passInterval,
    forceFull = false,
    forceFullPresetName = nil,
    resetBefore = false,
    auto = false,
    autoTimer = 0,
    autoPasses = 0,
    preflight = nil,
    preflightDirty = true,
    preflightPresetName = nil,
    recoverySnapshotAvailable = nil,
    comparison = nil,
  },
```

## All original assignment sites

| File and line | Assignment |
|---|---|
| `comparison.lua:149` | <code>state.load.comparison = nil</code> |
| `comparison.lua:153` | <code>state.load.comparison = result</code> |
| `comparison.lua:154` | <code>state.load.preflight = {     total = result.total,     available = result.matching + result.changing,     unavailable = result.missing,     ambiguous = result.ambiguous,     invalid = result.invalid,   }</code> |
| `comparison.lua:161` | <code>state.load.preflightDirty = false</code> |
| `comparison.lua:162` | <code>state.load.preflightPresetName = name</code> |
| `editor.lua:125` | <code>state.app.inCustomization = helpers.isCustomizationActive()</code> |
| `events.lua:51` | <code>state.app.optionsMemo = nil</code> |
| `events.lua:98` | <code>state.app.inCustomization = true</code> |
| `events.lua:120` | <code>state.app.inCustomization = false</code> |
| `events.lua:266` | <code>state.app.ready = true</code> |
| `events.lua:285` | <code>state.app.ready = false</code> |
| `events.lua:286` | <code>state.app.inCustomization = false</code> |
| `events.lua:302` | <code>state.app.optionsMemo = nil</code> |
| `events.lua:323` | <code>state.load.elapsed = state.load.elapsed + elapsed</code> |
| `events.lua:325` | <code>state.load.pendingElapsed = math.max(0,       state.load.elapsed - state.load.pendingChange.startedAt)</code> |
| `events.lua:330` | <code>state.load.auto = false</code> |
| `events.lua:331` | <code>state.load.autoTimer = 0</code> |
| `events.lua:332` | <code>state.load.autoPasses = 0</code> |
| `events.lua:336` | <code>state.load.autoTimer = state.load.autoTimer + elapsed</code> |
| `events.lua:338` | <code>state.load.autoTimer = 0</code> |
| `events.lua:341` | <code>state.load.auto = false</code> |
| `events.lua:342` | <code>state.load.autoTimer = 0</code> |
| `events.lua:343` | <code>state.load.autoPasses = 0</code> |
| `events.lua:347` | <code>state.load.autoPasses = state.load.autoPasses + 1</code> |
| `events.lua:352` | <code>state.load.auto = false</code> |
| `events.lua:365` | <code>state.load.auto = false</code> |
| `events.lua:366` | <code>state.load.autoPasses = 0</code> |
| `events.lua:384` | <code>state.app.overlayOpen = true</code> |
| `events.lua:385` | <code>state.app.windowOpen = true</code> |
| `events.lua:386` | <code>state.app.optionsMemo = nil</code> |
| `events.lua:399` | <code>state.app.overlayOpen = false</code> |
| `filesystem.lua:66` | <code>state.load.presetName = nil</code> |
| `filesystem.lua:67` | <code>state.load.overridePreset = nil</code> |
| `filesystem.lua:68` | <code>state.load.overrideName = nil</code> |
| `filesystem.lua:69` | <code>state.load.pass = 0</code> |
| `filesystem.lua:70` | <code>state.load.remaining = 0</code> |
| `filesystem.lua:71` | <code>state.load.needsContinue = false</code> |
| `filesystem.lua:72` | <code>state.load.stalled = false</code> |
| `filesystem.lua:73` | <code>state.load.previousUnresolvedSignature = nil</code> |
| `filesystem.lua:74` | <code>state.load.unresolvedRepeatCount = 0</code> |
| `filesystem.lua:75` | <code>state.load.satisfied = {}</code> |
| `filesystem.lua:76` | <code>state.load.values = nil</code> |
| `filesystem.lua:77` | <code>state.load.savedCounts = nil</code> |
| `filesystem.lua:78` | <code>state.load.orderedEntries = nil</code> |
| `filesystem.lua:79` | <code>state.load.savedEntryByKey = nil</code> |
| `filesystem.lua:80` | <code>state.load.savedSlotCounts = nil</code> |
| `filesystem.lua:81` | <code>state.load.valueCount = 0</code> |
| `filesystem.lua:82` | <code>state.load.forcedKeys = {}</code> |
| `filesystem.lua:83` | <code>state.load.resolvedChoiceIndexes = {}</code> |
| `filesystem.lua:84` | <code>state.load.applyAttempts = {}</code> |
| `filesystem.lua:85` | <code>state.load.unconfirmed = {}</code> |
| `filesystem.lua:86` | <code>state.load.cleanupAttempts = {}</code> |
| `filesystem.lua:87` | <code>state.load.cleanupSkipped = {}</code> |
| `filesystem.lua:88` | <code>state.load.loggedWarnings = {}</code> |
| `filesystem.lua:89` | <code>state.load.optionIdentityCache = {}</code> |
| `filesystem.lua:90` | <code>state.load.targetPolls = 0</code> |
| `filesystem.lua:91` | <code>state.load.targetPollSeconds = 0</code> |
| `filesystem.lua:92` | <code>state.load.targetFallbacks = 0</code> |
| `filesystem.lua:93` | <code>state.load.batch = nil</code> |
| `filesystem.lua:94` | <code>state.load.stageApplied = nil</code> |
| `filesystem.lua:95` | <code>state.load.stagePending = nil</code> |
| `filesystem.lua:96` | <code>state.load.choiceStage = nil</code> |
| `filesystem.lua:97` | <code>state.load.pendingChange = nil</code> |
| `filesystem.lua:98` | <code>state.load.pendingElapsed = 0</code> |
| `filesystem.lua:99` | <code>state.load.phase = "apply"</code> |
| `filesystem.lua:100` | <code>state.load.elapsed = 0</code> |
| `filesystem.lua:101` | <code>state.load.optionsSeconds = 0</code> |
| `filesystem.lua:102` | <code>state.load.scanCalls = 0</code> |
| `filesystem.lua:103` | <code>state.load.longestUpdate = 0</code> |
| `filesystem.lua:104` | <code>state.load.scanSeconds = 0</code> |
| `filesystem.lua:105` | <code>state.load.choiceSeconds = 0</code> |
| `filesystem.lua:106` | <code>state.load.applySeconds = 0</code> |
| `filesystem.lua:107` | <code>state.load.waitSeconds = 0</code> |
| `filesystem.lua:108` | <code>state.load.optionCalls = 0</code> |
| `filesystem.lua:109` | <code>state.load.structureChanges = 0</code> |
| `filesystem.lua:110` | <code>state.load.lastStructureSignature = nil</code> |
| `filesystem.lua:111` | <code>state.load.lastOptionCount = nil</code> |
| `filesystem.lua:112` | <code>state.load.forceStructureScan = true</code> |
| `filesystem.lua:113` | <code>state.load.targetPollingDisabled = false</code> |
| `filesystem.lua:114` | <code>state.load.returnToCleanup = false</code> |
| `filesystem.lua:115` | <code>state.load.dependencyKeys = {}</code> |
| `filesystem.lua:116` | <code>state.load.dependencyRemaps = {}</code> |
| `filesystem.lua:117` | <code>state.load.nextInterval = AUTO_LOAD_TIMING.passInterval</code> |
| `filesystem.lua:118` | <code>state.load.auto = false</code> |
| `filesystem.lua:119` | <code>state.load.autoTimer = 0</code> |
| `filesystem.lua:120` | <code>state.load.autoPasses = 0</code> |
| `filesystem.lua:121` | <code>state.load.resetBefore = false</code> |
| `history.lua:77` | <code>state.load.recoverySnapshotAvailable = #state.history.entries &gt; 0     or fileExists(LAST_APPEARANCE_FILE)</code> |
| `history.lua:135` | <code>state.load.overridePreset = preset</code> |
| `history.lua:136` | <code>state.load.overrideName = "Appearance History " .. tostring(index)</code> |
| `history.lua:137` | <code>state.load.autoTimer = 0</code> |
| `history.lua:138` | <code>state.load.autoPasses = 0</code> |
| `history.lua:139` | <code>state.load.resetBefore = true</code> |
| `history.lua:141` | <code>state.load.auto = true</code> |
| `load_engine.lua:9` | <code>state.load.loggedWarnings[key] = true</code> |
| `load_engine.lua:18` | <code>state.load.optionIdentityCache[cacheKey] = identity</code> |
| `load_engine.lua:76` | <code>state.load.scanResult = result</code> |
| `load_engine.lua:97` | <code>state.load.forceStructureScan = false</code> |
| `load_engine.lua:160` | <code>state.load.structureChanges = state.load.structureChanges + 1</code> |
| `load_engine.lua:161` | <code>state.load.resolvedChoiceIndexes = {}</code> |
| `load_engine.lua:162` | <code>state.load.optionIdentityCache = {}</code> |
| `load_engine.lua:163` | <code>state.load.dependencyRemaps = {}</code> |
| `load_engine.lua:167` | <code>state.load.dependencyKeys[pending.trackingKey] = true</code> |
| `load_engine.lua:175` | <code>state.load.lastStructureSignature = result.signature</code> |
| `load_engine.lua:176` | <code>state.load.lastOptionCount = optionCount</code> |
| `load_engine.lua:177` | <code>state.load.scanCalls = state.load.scanCalls + 1</code> |
| `load_engine.lua:178` | <code>state.load.scanSeconds = state.load.scanSeconds + math.max(0, helpers.loadClock() - started)</code> |
| `load_engine.lua:188` | <code>state.load.choiceSeconds = state.load.choiceSeconds     + math.max(0, helpers.loadClock() - started)</code> |
| `load_engine.lua:215` | <code>state.load.targetPolls = state.load.targetPolls + 1</code> |
| `load_engine.lua:233` | <code>state.load.targetPollSeconds = state.load.targetPollSeconds     + math.max(0, helpers.loadClock() - started)</code> |
| `load_engine.lua:236` | <code>state.load.targetFallbacks = state.load.targetFallbacks + 1</code> |
| `load_engine.lua:237` | <code>state.load.targetPollingDisabled = true</code> |
| `load_engine.lua:238` | <code>state.load.resolvedChoiceIndexes = {}</code> |
| `load_engine.lua:239` | <code>state.load.optionIdentityCache = {}</code> |
| `load_engine.lua:240` | <code>state.load.dependencyRemaps = {}</code> |
| `load_engine.lua:251` | <code>state.load.nextInterval = AUTO_LOAD_TIMING.pollInterval</code> |
| `load_engine.lua:252` | <code>state.load.pendingElapsed = math.max(0, state.load.elapsed - pending.startedAt)</code> |
| `load_engine.lua:262` | <code>state.load.applySeconds = state.load.applySeconds     + math.max(0, helpers.loadClock() - started)</code> |
| `load_engine.lua:265` | <code>state.app.optionsMemo = nil</code> |
| `load_engine.lua:275` | <code>state.load.pendingChange = {     kind = kind,     trackingKey = trackingKey,     optionKey = exposedOption.key,     position = exposedOption.position,     label = exposedOption.label,     occurrence = exposedOption.occurrence,     slot = exposedOption.slot,     choiceShape = exposedOption.choiceShape,     target = target,     previous = current,     identity = identity,     startedAt = state.load.elapsed,     attemptStartedAt = state.load.elapsed,     structureSignature = state.load.lastStructureSignature,     confirmedAt = nil,     confirmedSignature = nil,     confirmedDisappeared = false,     longSettle = longSettle,   }</code> |
| `load_engine.lua:295` | <code>state.load.pendingElapsed = 0</code> |
| `load_engine.lua:296` | <code>state.load.nextInterval = AUTO_LOAD_TIMING.pollInterval</code> |
| `load_engine.lua:297` | <code>state.load.forceStructureScan = true</code> |
| `load_engine.lua:298` | <code>state.load.needsContinue = true</code> |
| `load_engine.lua:299` | <code>state.load.previousUnresolvedSignature = nil</code> |
| `load_engine.lua:300` | <code>state.load.unresolvedRepeatCount = 0</code> |
| `load_engine.lua:306` | <code>state.load.satisfied[key] = nil</code> |
| `load_engine.lua:308` | <code>state.load.applyAttempts = {}</code> |
| `load_engine.lua:309` | <code>state.load.previousUnresolvedSignature = nil</code> |
| `load_engine.lua:310` | <code>state.load.unresolvedRepeatCount = 0</code> |
| `load_engine.lua:321` | <code>state.load.targetPollingDisabled = true</code> |
| `load_engine.lua:322` | <code>state.load.resolvedChoiceIndexes = {}</code> |
| `load_engine.lua:323` | <code>state.load.optionIdentityCache = {}</code> |
| `load_engine.lua:324` | <code>state.load.dependencyRemaps = {}</code> |
| `load_engine.lua:329` | <code>state.load.targetPollingDisabled = true</code> |
| `load_engine.lua:330` | <code>state.load.resolvedChoiceIndexes = {}</code> |
| `load_engine.lua:331` | <code>state.load.optionIdentityCache = {}</code> |
| `load_engine.lua:332` | <code>state.load.dependencyRemaps = {}</code> |
| `load_engine.lua:353` | <code>state.load.nextInterval = AUTO_LOAD_TIMING.pollInterval</code> |
| `load_engine.lua:361` | <code>state.load.nextInterval = AUTO_LOAD_TIMING.pollInterval</code> |
| `load_engine.lua:366` | <code>state.load.waitSeconds = state.load.waitSeconds + waited</code> |
| `load_engine.lua:367` | <code>state.load.pendingElapsed = waited</code> |
| `load_engine.lua:368` | <code>state.load.pendingChange = nil</code> |
| `load_engine.lua:369` | <code>state.load.nextInterval = AUTO_LOAD_TIMING.passInterval</code> |
| `load_engine.lua:370` | <code>state.load.forceStructureScan = true</code> |
| `load_engine.lua:372` | <code>state.load.satisfied[pending.trackingKey] = true</code> |
| `load_engine.lua:373` | <code>state.load.unconfirmed[pending.trackingKey] = nil</code> |
| `load_engine.lua:374` | <code>state.load.forcedKeys[pending.trackingKey] = true</code> |
| `load_engine.lua:376` | <code>state.load.phase = "precleanup"</code> |
| `load_engine.lua:378` | <code>state.load.phase = "verify"</code> |
| `load_engine.lua:379` | <code>state.load.returnToCleanup = true</code> |
| `load_engine.lua:390` | <code>state.load.nextInterval = AUTO_LOAD_TIMING.pollInterval</code> |
| `load_engine.lua:391` | <code>state.load.pendingElapsed = math.max(0, state.load.elapsed - pending.startedAt)</code> |
| `load_engine.lua:395` | <code>state.load.waitSeconds = state.load.waitSeconds + waited</code> |
| `load_engine.lua:396` | <code>state.load.pendingChange = nil</code> |
| `load_engine.lua:397` | <code>state.load.nextInterval = AUTO_LOAD_TIMING.passInterval</code> |
| `load_engine.lua:398` | <code>state.load.forceStructureScan = true</code> |
| `load_engine.lua:400` | <code>state.load.cleanupSkipped[pending.trackingKey] = true</code> |
| `load_engine.lua:402` | <code>state.load.phase = "precleanup"</code> |
| `load_engine.lua:404` | <code>state.load.phase = "verify"</code> |
| `load_engine.lua:405` | <code>state.load.returnToCleanup = true</code> |
| `load_engine.lua:412` | <code>state.load.satisfied[pending.trackingKey] = true</code> |
| `load_engine.lua:413` | <code>state.load.unconfirmed[pending.trackingKey] = true</code> |
| `load_engine.lua:414` | <code>state.load.forcedKeys[pending.trackingKey] = true</code> |
| `load_engine.lua:426` | <code>state.load.longestUpdate = math.max(state.load.longestUpdate, current)</code> |
| `load_engine.lua:436` | <code>state.app.optionsMemo = nil</code> |
| `load_engine.lua:437` | <code>state.load.batch = nil</code> |
| `load_engine.lua:438` | <code>state.load.stageApplied = nil</code> |
| `load_engine.lua:439` | <code>state.load.stagePending = nil</code> |
| `load_engine.lua:440` | <code>state.load.choiceStage = nil</code> |
| `load_engine.lua:441` | <code>state.load.overridePreset = nil</code> |
| `load_engine.lua:442` | <code>state.load.values = nil</code> |
| `load_engine.lua:443` | <code>state.load.savedCounts = nil</code> |
| `load_engine.lua:444` | <code>state.load.orderedEntries = nil</code> |
| `load_engine.lua:445` | <code>state.load.savedEntryByKey = nil</code> |
| `load_engine.lua:446` | <code>state.load.savedSlotCounts = nil</code> |
| `load_engine.lua:447` | <code>state.load.satisfied = {}</code> |
| `load_engine.lua:448` | <code>state.load.forcedKeys = {}</code> |
| `load_engine.lua:449` | <code>state.load.resolvedChoiceIndexes = {}</code> |
| `load_engine.lua:450` | <code>state.load.applyAttempts = {}</code> |
| `load_engine.lua:451` | <code>state.load.unconfirmed = {}</code> |
| `load_engine.lua:452` | <code>state.load.cleanupAttempts = {}</code> |
| `load_engine.lua:453` | <code>state.load.cleanupSkipped = {}</code> |
| `load_engine.lua:454` | <code>state.load.loggedWarnings = {}</code> |
| `load_engine.lua:455` | <code>state.load.optionIdentityCache = {}</code> |
| `load_engine.lua:456` | <code>state.load.pendingChange = nil</code> |
| `load_engine.lua:457` | <code>state.load.lastStructureSignature = nil</code> |
| `load_engine.lua:458` | <code>state.load.lastOptionCount = nil</code> |
| `load_engine.lua:459` | <code>state.load.scanResult = nil</code> |
| `load_engine.lua:460` | <code>state.load.dependencyKeys = {}</code> |
| `load_engine.lua:461` | <code>state.load.dependencyRemaps = {}</code> |
| `load_engine.lua:462` | <code>state.load.auto = false</code> |
| `load_engine.lua:463` | <code>state.load.autoTimer = 0</code> |
| `load_engine.lua:464` | <code>state.load.autoPasses = 0</code> |
| `load_engine.lua:483` | <code>state.load.forceFull = preset ~= nil     and format &lt; FORCE_FULL_LOAD_FORMAT_THRESHOLD</code> |
| `load_engine.lua:485` | <code>state.load.forceFullPresetName = selected</code> |
| `load_engine.lua:496` | <code>state.load.optionsSeconds = state.load.optionsSeconds     + math.max(0, helpers.loadClock() - optionsStarted)</code> |
| `load_engine.lua:498` | <code>state.load.optionCalls = state.load.optionCalls + 1</code> |
| `load_engine.lua:539` | <code>state.load.unconfirmed[key] = nil</code> |
| `load_engine.lua:559` | <code>state.load.unconfirmed[savedKey] = nil</code> |
| `load_engine.lua:579` | <code>state.load.batch = nil</code> |
| `load_engine.lua:581` | <code>state.load.pendingChange = pending</code> |
| `load_engine.lua:586` | <code>state.load.pendingChange = nil</code> |
| `load_engine.lua:587` | <code>state.load.waitSeconds = waitSeconds + math.max(0, state.load.elapsed - accountedAt)</code> |
| `load_engine.lua:594` | <code>state.load.batch = waiting</code> |
| `load_engine.lua:595` | <code>state.load.nextInterval = AUTO_LOAD_TIMING.pollInterval</code> |
| `load_engine.lua:598` | <code>state.load.nextInterval = 0</code> |
| `load_engine.lua:625` | <code>state.load.resolvedChoiceIndexes[key] = target</code> |
| `load_engine.lua:635` | <code>state.load.stageApplied = {}</code> |
| `load_engine.lua:637` | <code>state.load.choiceStage = "secondary"</code> |
| `load_engine.lua:640` | <code>state.load.choiceStage = "verify"</code> |
| `load_engine.lua:643` | <code>state.load.needsContinue = true</code> |
| `load_engine.lua:661` | <code>state.load.forceStructureScan = true</code> |
| `load_engine.lua:662` | <code>state.load.needsContinue = true</code> |
| `load_engine.lua:663` | <code>state.load.nextInterval = 0</code> |
| `load_engine.lua:670` | <code>state.load.needsContinue = false</code> |
| `load_engine.lua:671` | <code>state.load.stalled = true</code> |
| `load_engine.lua:676` | <code>state.load.values[candidate.key] = change.target</code> |
| `load_engine.lua:680` | <code>state.load.stageApplied[candidate.key] = true</code> |
| `load_engine.lua:681` | <code>state.load.pendingChange = nil</code> |
| `load_engine.lua:686` | <code>state.load.stagePending = {}</code> |
| `load_engine.lua:691` | <code>state.load.batch = pending</code> |
| `load_engine.lua:692` | <code>state.load.nextInterval = AUTO_LOAD_TIMING.pollInterval</code> |
| `load_engine.lua:693` | <code>state.load.needsContinue = true</code> |
| `load_engine.lua:698` | <code>state.load.stagePending[#state.load.stagePending + 1] = pending</code> |
| `load_engine.lua:700` | <code>state.load.nextInterval = 0</code> |
| `load_engine.lua:701` | <code>state.load.needsContinue = true</code> |
| `load_engine.lua:713` | <code>state.load.presetName = loadName</code> |
| `load_engine.lua:714` | <code>state.load.pass = 1</code> |
| `load_engine.lua:715` | <code>state.load.previousUnresolvedSignature = nil</code> |
| `load_engine.lua:716` | <code>state.load.unresolvedRepeatCount = 0</code> |
| `load_engine.lua:717` | <code>state.load.satisfied = {}</code> |
| `load_engine.lua:718` | <code>state.load.forcedKeys = {}</code> |
| `load_engine.lua:719` | <code>state.load.resolvedChoiceIndexes = {}</code> |
| `load_engine.lua:720` | <code>state.load.applyAttempts = {}</code> |
| `load_engine.lua:721` | <code>state.load.unconfirmed = {}</code> |
| `load_engine.lua:722` | <code>state.load.cleanupAttempts = {}</code> |
| `load_engine.lua:723` | <code>state.load.cleanupSkipped = {}</code> |
| `load_engine.lua:724` | <code>state.load.phase = state.load.resetBefore and "precleanup" or "apply"</code> |
| `load_engine.lua:725` | <code>state.load.choiceStage = "main"</code> |
| `load_engine.lua:726` | <code>state.load.stageApplied = {}</code> |
| `load_engine.lua:727` | <code>state.load.stagePending = {}</code> |
| `load_engine.lua:728` | <code>state.load.needsContinue = true</code> |
| `load_engine.lua:729` | <code>state.load.returnToCleanup = false</code> |
| `load_engine.lua:732` | <code>state.load.values = values</code> |
| `load_engine.lua:733` | <code>state.load.savedCounts = savedCounts</code> |
| `load_engine.lua:734` | <code>state.load.orderedEntries = orderedEntries</code> |
| `load_engine.lua:735` | <code>state.load.savedEntryByKey = savedEntryByKey</code> |
| `load_engine.lua:736` | <code>state.load.savedSlotCounts = savedSlotCounts</code> |
| `load_engine.lua:737` | <code>state.load.valueCount = valueCount</code> |
| `load_engine.lua:743` | <code>state.load.stalled = false</code> |
| `load_engine.lua:745` | <code>state.load.needsContinue = false</code> |
| `load_engine.lua:773` | <code>state.load.nextInterval = 0</code> |
| `load_engine.lua:776` | <code>state.load.remaining = valueCount</code> |
| `load_engine.lua:777` | <code>state.load.needsContinue = true</code> |
| `load_engine.lua:783` | <code>state.load.remaining = valueCount</code> |
| `load_engine.lua:784` | <code>state.load.needsContinue = true</code> |
| `load_engine.lua:791` | <code>state.load.phase = "verify"</code> |
| `load_engine.lua:792` | <code>state.load.returnToCleanup = true</code> |
| `load_engine.lua:793` | <code>state.load.remaining = valueCount</code> |
| `load_engine.lua:794` | <code>state.load.needsContinue = true</code> |
| `load_engine.lua:829` | <code>state.load.dependencyRemaps[cleanupKey] = nil</code> |
| `load_engine.lua:852` | <code>state.load.phase = "apply"</code> |
| `load_engine.lua:853` | <code>state.load.stageApplied = {}</code> |
| `load_engine.lua:854` | <code>state.load.remaining = valueCount</code> |
| `load_engine.lua:855` | <code>state.load.needsContinue = true</code> |
| `load_engine.lua:856` | <code>state.load.previousUnresolvedSignature = nil</code> |
| `load_engine.lua:857` | <code>state.load.unresolvedRepeatCount = 0</code> |
| `load_engine.lua:862` | <code>state.load.phase = "verify"</code> |
| `load_engine.lua:863` | <code>state.load.returnToCleanup = false</code> |
| `load_engine.lua:864` | <code>state.load.resetBefore = false</code> |
| `load_engine.lua:865` | <code>state.load.remaining = valueCount</code> |
| `load_engine.lua:866` | <code>state.load.needsContinue = true</code> |
| `load_engine.lua:886` | <code>state.load.resolvedChoiceIndexes[key] = resolvedIndex</code> |
| `load_engine.lua:917` | <code>state.load.resolvedChoiceIndexes[key] = nil</code> |
| `load_engine.lua:920` | <code>state.load.resolvedChoiceIndexes[key] = resolvedIndex</code> |
| `load_engine.lua:960` | <code>state.load.satisfied[key] = true</code> |
| `load_engine.lua:961` | <code>state.load.unconfirmed[key] = nil</code> |
| `load_engine.lua:980` | <code>state.load.remaining = math.max(0, valueCount - satisfiedBefore - 1)</code> |
| `load_engine.lua:990` | <code>state.load.needsContinue = false</code> |
| `load_engine.lua:991` | <code>state.load.stalled = true</code> |
| `load_engine.lua:1009` | <code>state.load.satisfied[key] = true</code> |
| `load_engine.lua:1033` | <code>state.load.resolvedChoiceIndexes[savedKey] = target</code> |
| `load_engine.lua:1036` | <code>state.load.dependencyRemaps[candidate.key] = {             savedKey = savedKey,             label = candidate.label,             occurrence = candidate.occurrence,             position = candidate.position,             slot = candidate.slot,             slotOccurrence = candidate.slotOccurrence,             slotCount = savedSlotCounts[entry.slot] or 0,             choice = entry.choice,             target = target,           }</code> |
| `load_engine.lua:1049` | <code>state.load.satisfied[savedKey] = true</code> |
| `load_engine.lua:1050` | <code>state.load.unconfirmed[savedKey] = nil</code> |
| `load_engine.lua:1059` | <code>state.load.dependencyKeys[savedKey] = true</code> |
| `load_engine.lua:1063` | <code>state.load.remaining = math.max(0, valueCount - satisfiedBefore - 1)</code> |
| `load_engine.lua:1071` | <code>state.load.needsContinue = false</code> |
| `load_engine.lua:1072` | <code>state.load.stalled = true</code> |
| `load_engine.lua:1121` | <code>state.load.dependencyRemaps[candidate.key] = {               savedKey = savedKey,               label = candidate.label,               occurrence = candidate.occurrence,               position = candidate.position,               slot = candidate.slot,               slotOccurrence = candidate.slotOccurrence,               slotCount = candidate.slot                 and (activeSlotCounts[candidate.slot] or 0) or 0,               choice = entry.choice,               target = target,             }</code> |
| `load_engine.lua:1135` | <code>state.load.satisfied[savedKey] = true</code> |
| `load_engine.lua:1136` | <code>state.load.unconfirmed[savedKey] = nil</code> |
| `load_engine.lua:1137` | <code>state.load.forcedKeys[savedKey] = true</code> |
| `load_engine.lua:1139` | <code>state.load.forcedKeys[savedKey] = true</code> |
| `load_engine.lua:1141` | <code>state.load.forcedKeys[savedKey] = nil</code> |
| `load_engine.lua:1149` | <code>state.load.pendingChange.forced = true</code> |
| `load_engine.lua:1150` | <code>state.load.remaining = math.max(0, valueCount - satisfiedBefore - 1)</code> |
| `load_engine.lua:1159` | <code>state.load.forcedKeys[savedKey] = nil</code> |
| `load_engine.lua:1163` | <code>state.load.needsContinue = false</code> |
| `load_engine.lua:1164` | <code>state.load.stalled = true</code> |
| `load_engine.lua:1182` | <code>state.load.satisfied[key] = nil</code> |
| `load_engine.lua:1208` | <code>state.load.remaining = missing + ambiguous + invalid</code> |
| `load_engine.lua:1212` | <code>state.load.unresolvedRepeatCount = state.load.unresolvedRepeatCount + 1</code> |
| `load_engine.lua:1214` | <code>state.load.previousUnresolvedSignature = signature</code> |
| `load_engine.lua:1215` | <code>state.load.unresolvedRepeatCount = 1</code> |
| `load_engine.lua:1218` | <code>state.load.needsContinue = false</code> |
| `load_engine.lua:1219` | <code>state.load.stalled = true</code> |
| `load_engine.lua:1234` | <code>state.load.needsContinue = true</code> |
| `load_engine.lua:1240` | <code>state.load.phase = "cleanup"</code> |
| `load_engine.lua:1241` | <code>state.load.stageApplied = {}</code> |
| `load_engine.lua:1242` | <code>state.load.remaining = valueCount</code> |
| `load_engine.lua:1243` | <code>state.load.needsContinue = true</code> |
| `load_engine.lua:1244` | <code>state.load.previousUnresolvedSignature = nil</code> |
| `load_engine.lua:1245` | <code>state.load.unresolvedRepeatCount = 0</code> |
| `load_engine.lua:1251` | <code>state.load.phase = "cleanup"</code> |
| `load_engine.lua:1252` | <code>state.load.stageApplied = {}</code> |
| `load_engine.lua:1253` | <code>state.load.returnToCleanup = false</code> |
| `load_engine.lua:1254` | <code>state.load.remaining = valueCount</code> |
| `load_engine.lua:1255` | <code>state.load.needsContinue = true</code> |
| `load_engine.lua:1256` | <code>state.load.previousUnresolvedSignature = nil</code> |
| `load_engine.lua:1257` | <code>state.load.unresolvedRepeatCount = 0</code> |
| `load_engine.lua:1269` | <code>state.load.needsContinue = false</code> |
| `load_engine.lua:1270` | <code>state.load.stalled = false</code> |
| `load_engine.lua:1271` | <code>state.load.previousUnresolvedSignature = nil</code> |
| `load_engine.lua:1272` | <code>state.load.unresolvedRepeatCount = 0</code> |
| `load_engine.lua:1282` | <code>state.app.nativeLoadSummary = ("Loaded %d options. %d could not be confirmed; check the appearance.")         :format(valueCount, unconfirmed + cleanupSkipped)</code> |
| `load_engine.lua:1284` | <code>state.app.nativePanelShowDetails = true</code> |
| `load_engine.lua:1298` | <code>state.app.nativeLoadSummary = ("Loaded %d options. %d used less certain matching; check the appearance.")         :format(valueCount, forced)</code> |
| `load_engine.lua:1300` | <code>state.app.nativePanelShowDetails = true</code> |
| `load_engine.lua:1307` | <code>state.app.nativeLoadSummary = ("Loaded %d options. The game confirmed every saved value.")         :format(valueCount)</code> |
| `load_engine.lua:1309` | <code>state.app.nativePanelShowDetails = false</code> |
| `load_engine.lua:1338` | <code>state.load.optionsSeconds = state.load.optionsSeconds     + math.max(0, helpers.loadClock() - optionsStarted)</code> |
| `load_engine.lua:1340` | <code>state.load.optionCalls = state.load.optionCalls + 1</code> |
| `load_engine.lua:1343` | <code>state.load.batch = nil</code> |
| `load_engine.lua:1344` | <code>state.load.pendingChange = nil</code> |
| `load_engine.lua:1345` | <code>state.load.needsContinue = false</code> |
| `load_engine.lua:1346` | <code>state.load.auto = false</code> |
| `load_engine.lua:1347` | <code>state.load.stalled = true</code> |
| `load_engine.lua:1356` | <code>state.load.pass = state.load.pass + 1</code> |
| `load_engine.lua:1381` | <code>state.app.loadInvocation = state.app.loadInvocation + 1</code> |
| `load_engine.lua:1383` | <code>state.load.updateStarted = started</code> |
| `load_engine.lua:1385` | <code>state.app.presetCameraHold = true</code> |
| `load_engine.lua:1387` | <code>state.app.presetCameraHold = previousCameraHold</code> |
| `load_engine.lua:1388` | <code>state.load.longestUpdate = math.max(state.load.longestUpdate,     math.max(0, helpers.loadClock() - started))</code> |
| `load_engine.lua:1390` | <code>state.load.updateStarted = nil</code> |
| `load_engine.lua:1400` | <code>state.load.recoverySnapshotAvailable = false</code> |
| `load_engine.lua:1405` | <code>state.load.overridePreset = preset</code> |
| `load_engine.lua:1406` | <code>state.load.overrideName = "Appearance Before Last Load"</code> |
| `load_engine.lua:1407` | <code>state.load.autoTimer = 0</code> |
| `load_engine.lua:1408` | <code>state.load.autoPasses = 0</code> |
| `load_engine.lua:1409` | <code>state.load.resetBefore = true</code> |
| `load_engine.lua:1411` | <code>state.load.auto = true</code> |
| `load_engine.lua:1422` | <code>state.load.preflight = nil</code> |
| `load_engine.lua:1423` | <code>state.load.preflightDirty = false</code> |
| `load_engine.lua:1424` | <code>state.load.preflightPresetName = state.library.selected</code> |
| `load_engine.lua:1438` | <code>state.app.inCustomization = options ~= nil</code> |
| `load_engine.lua:1511` | <code>state.load.preflight = {     total = state.presetEntryCount(preset),     available = available,     unavailable = unavailable,     ambiguous = ambiguous,     invalid = invalid,   }</code> |
| `native_bridge.lua:44` | <code>state.app.nativePanelStatus = overlayFallback</code> |
| `native_bridge.lua:45` | <code>state.app.nativePanelStatusError = true</code> |
| `native_bridge.lua:63` | <code>state.app.nativeBridge = nil</code> |
| `native_bridge.lua:84` | <code>state.app.nativePanelStatus = tostring(message or "")</code> |
| `native_bridge.lua:85` | <code>state.app.nativePanelStatusError = isError == true</code> |
| `native_bridge.lua:107` | <code>state.app.nativePanelStatus = message</code> |
| `native_bridge.lua:108` | <code>state.app.nativePanelStatusError = isError</code> |
| `native_bridge.lua:238` | <code>state.app.nativeLoadSummary = nil</code> |
| `native_bridge.lua:239` | <code>state.app.nativePanelShowDetails = false</code> |
| `native_bridge.lua:241` | <code>state.load.autoTimer = 0</code> |
| `native_bridge.lua:242` | <code>state.load.autoPasses = 0</code> |
| `native_bridge.lua:243` | <code>state.load.resetBefore = true</code> |
| `native_bridge.lua:245` | <code>state.load.auto = true</code> |
| `native_bridge.lua:271` | <code>state.app.optionsMemo = nil</code> |
| `native_bridge.lua:374` | <code>state.app.nativeLoadSummary = nil</code> |
| `native_bridge.lua:375` | <code>state.app.nativePanelShowDetails = false</code> |
| `native_bridge.lua:381` | <code>state.app.nativeLoadSummary = nil</code> |
| `native_bridge.lua:382` | <code>state.app.nativePanelShowDetails = false</code> |
| `native_bridge.lua:388` | <code>state.app.nativeLoadSummary = nil</code> |
| `native_bridge.lua:389` | <code>state.app.nativePanelShowDetails = false</code> |
| `native_bridge.lua:399` | <code>state.app.windowOpen = true</code> |
| `native_bridge.lua:410` | <code>state.app.windowOpen = true</code> |
| `native_bridge.lua:429` | <code>state.app.nativeBridge = preferredBridge or findNativeBridge()</code> |
| `native_bridge.lua:433` | <code>state.app.nativeBridgeUnavailableLogged = true</code> |
| `native_bridge.lua:437` | <code>state.app.nativeBridgeUnavailableLogged = false</code> |
| `native_bridge.lua:438` | <code>state.app.nativeBridgeRetryTimer = 0</code> |
| `native_bridge.lua:442` | <code>state.app.nativeBridgeSequence = sequenceOk     and math.max(0, tonumber(sequence) or 0) or 0</code> |
| `native_bridge.lua:444` | <code>state.app.nativeListRevision = -1</code> |
| `native_bridge.lua:445` | <code>state.app.nativeListSelection = nil</code> |
| `native_bridge.lua:449` | <code>state.app.nativeListRevision = state.cache.revision</code> |
| `native_bridge.lua:450` | <code>state.app.nativeListSelection = tostring(state.library.selected or "") .. "\31" ..       tostring(state.trash.nativePendingDeleteName or "") .. "\31" ..       tostring(state.library.selectedFolder or "") .. "\31" ..       tostring(state.app.nativePanelShowDetails == true) .. "\31" ..       tostring(state.load.recoverySnapshotAvailable == true)</code> |
| `native_bridge.lua:467` | <code>state.app.nativeBridge = bridge</code> |
| `native_bridge.lua:479` | <code>state.app.nativeBridgeRetryTimer = state.app.nativeBridgeRetryTimer       + math.max(0, tonumber(delta) or 0)</code> |
| `native_bridge.lua:482` | <code>state.app.nativeBridgeRetryTimer = 0</code> |
| `native_bridge.lua:494` | <code>state.app.nativePanelStatus = status</code> |
| `native_bridge.lua:495` | <code>state.app.nativePanelStatusError = statusError</code> |
| `native_bridge.lua:496` | <code>state.app.nativePanelShowDetails = state.app.nativePanelShowDetails       or statusError</code> |
| `native_bridge.lua:502` | <code>state.app.nativeBusy = busy</code> |
| `native_bridge.lua:503` | <code>state.app.nativeStatus = status</code> |
| `native_bridge.lua:504` | <code>state.app.nativeStatusError = statusError</code> |
| `native_bridge.lua:520` | <code>state.app.nativeListRevision = state.cache.revision</code> |
| `native_bridge.lua:521` | <code>state.app.nativeListSelection = listSelection</code> |
| `native_bridge.lua:523` | <code>state.app.nativeRequestPollTimer = state.app.nativeRequestPollTimer + elapsed</code> |
| `native_bridge.lua:525` | <code>state.app.nativeRequestPollTimer = 0</code> |
| `native_bridge.lua:531` | <code>state.app.nativeBridgeSequence = sequence</code> |
| `options.lua:81` | <code>state.app.optionCatalog = nil</code> |
| `options.lua:82` | <code>state.app.optionChoiceBindings = nil</code> |
| `options.lua:83` | <code>state.app.optionsMemo = nil</code> |
| `options.lua:103` | <code>state.app.optionCatalog = previous</code> |
| `options.lua:104` | <code>state.app.optionChoiceBindings = bindings</code> |
| `options.lua:112` | <code>state.app.optionCatalog.hits = state.app.optionCatalog.hits + 1</code> |
| `options.lua:132` | <code>state.app.optionCatalog.builds = state.app.optionCatalog.builds + 1</code> |
| `options.lua:281` | <code>state.app.optionsMemo = { error = message }</code> |
| `options.lua:298` | <code>state.app.optionsMemo = { error = message }</code> |
| `options.lua:302` | <code>state.app.optionsMemo = { system = system, options = options }</code> |
| `presets.lua:155` | <code>state.load.preflight = nil</code> |
| `presets.lua:156` | <code>state.load.preflightDirty = true</code> |
| `presets.lua:157` | <code>state.load.preflightPresetName = nil</code> |
| `presets.lua:504` | <code>state.load.recoverySnapshotAvailable = wrote == true     or state.load.recoverySnapshotAvailable == true</code> |
| `ui/sections_load.lua:248` | <code>state.load.autoTimer = 0</code> |
| `ui/sections_load.lua:249` | <code>state.load.autoPasses = 0</code> |
| `ui/sections_load.lua:250` | <code>state.load.resetBefore = true</code> |
| `ui/sections_load.lua:252` | <code>state.load.auto = true</code> |
| `ui/sections_load.lua:324` | <code>state.load.forceFull = not state.load.forceFull</code> |

## Extracted lifecycle footprints

The footprints below use explicit parameter names in place of shared-state prefixes. The assignment-site table above preserves the original expressions and source lines.

### newLoad

Original source: state.lua:54-115.

```lua
return {
    presetName = nil,
    overridePreset = nil,
    overrideName = nil,
    pass = 0,
    remaining = 0,
    needsContinue = false,
    stalled = false,
    previousUnresolvedSignature = nil,
    unresolvedRepeatCount = 0,
    satisfied = {},
    values = nil,
    savedCounts = nil,
    orderedEntries = nil,
    savedEntryByKey = nil,
    savedSlotCounts = nil,
    valueCount = 0,
    forcedKeys = {},
    resolvedChoiceIndexes = {},
    applyAttempts = {},
    unconfirmed = {},
    cleanupAttempts = {},
    cleanupSkipped = {},
    loggedWarnings = {},
    optionIdentityCache = {},
    targetPolls = 0,
    targetPollSeconds = 0,
    targetFallbacks = 0,
    pendingChange = nil,
    pendingElapsed = 0,
    phase = "apply",
    elapsed = 0,
    optionsSeconds = 0,
    scanCalls = 0,
    longestUpdate = 0,
    scanSeconds = 0,
    choiceSeconds = 0,
    applySeconds = 0,
    waitSeconds = 0,
    optionCalls = 0,
    structureChanges = 0,
    lastStructureSignature = nil,
    lastOptionCount = nil,
    forceStructureScan = true,
    scanResult = nil,
    targetPollingDisabled = false,
    returnToCleanup = false,
    dependencyKeys = {},
    dependencyRemaps = {},
    nextInterval = passInterval,
    forceFull = false,
    forceFullPresetName = nil,
    resetBefore = false,
    auto = false,
    autoTimer = 0,
    autoPasses = 0,
    preflight = nil,
    preflightDirty = true,
    preflightPresetName = nil,
    recoverySnapshotAvailable = nil,
    comparison = nil,
  }
```

### newApp

Original source: state.lua:7-28.

```lua
return {
    overlayOpen = false,
    windowOpen = true,
    ready = false,
    inCustomization = false,
    optionsMemo = nil,
    loadInvocation = 0,
    nativeBridge = nil,
    nativeBridgeSequence = 0,
    nativeBridgeUnavailableLogged = false,
    nativeBridgeRetryTimer = 0,
    nativeBusy = nil,
    nativeStatus = nil,
    nativeStatusError = nil,
    nativePanelStatus = readyStatus,
    nativePanelStatusError = false,
    nativePanelShowDetails = false,
    nativeLoadSummary = nil,
    nativeListRevision = -1,
    nativeListSelection = nil,
    nativeRequestPollTimer = 0,
  }
```

### resetLoad

Original source: filesystem.lua:65-123.

```lua
load.presetName = nil
load.overridePreset = nil
load.overrideName = nil
load.pass = 0
load.remaining = 0
load.needsContinue = false
load.stalled = false
load.previousUnresolvedSignature = nil
load.unresolvedRepeatCount = 0
load.satisfied = {}
load.values = nil
load.savedCounts = nil
load.orderedEntries = nil
load.savedEntryByKey = nil
load.savedSlotCounts = nil
load.valueCount = 0
load.forcedKeys = {}
load.resolvedChoiceIndexes = {}
load.applyAttempts = {}
load.unconfirmed = {}
load.cleanupAttempts = {}
load.cleanupSkipped = {}
load.loggedWarnings = {}
load.optionIdentityCache = {}
load.targetPolls = 0
load.targetPollSeconds = 0
load.targetFallbacks = 0
load.batch = nil
load.stageApplied = nil
load.stagePending = nil
load.choiceStage = nil
load.pendingChange = nil
load.pendingElapsed = 0
load.phase = "apply"
load.elapsed = 0
load.optionsSeconds = 0
load.scanCalls = 0
load.longestUpdate = 0
load.scanSeconds = 0
load.choiceSeconds = 0
load.applySeconds = 0
load.waitSeconds = 0
load.optionCalls = 0
load.structureChanges = 0
load.lastStructureSignature = nil
load.lastOptionCount = nil
load.forceStructureScan = true
load.targetPollingDisabled = false
load.returnToCleanup = false
load.dependencyKeys = {}
load.dependencyRemaps = {}
load.nextInterval = passInterval
load.auto = false
load.autoTimer = 0
load.autoPasses = 0
load.resetBefore = false
```

### releaseLoadWorkingData

Original source: load_engine.lua:435-463.

```lua
app.optionsMemo = nil
load.batch = nil
load.stageApplied = nil
load.stagePending = nil
load.choiceStage = nil
load.overridePreset = nil
load.values = nil
load.savedCounts = nil
load.orderedEntries = nil
load.savedEntryByKey = nil
load.savedSlotCounts = nil
load.satisfied = {}
load.forcedKeys = {}
load.resolvedChoiceIndexes = {}
load.applyAttempts = {}
load.unconfirmed = {}
load.cleanupAttempts = {}
load.cleanupSkipped = {}
load.loggedWarnings = {}
load.optionIdentityCache = {}
load.pendingChange = nil
load.lastStructureSignature = nil
load.lastOptionCount = nil
load.scanResult = nil
load.dependencyKeys = {}
load.dependencyRemaps = {}
load.auto = false
load.autoTimer = 0
load.autoPasses = 0
```

### beginLoad

Original source: load_engine.lua:713-729.

```lua
load.presetName = loadName
load.pass = 1
load.previousUnresolvedSignature = nil
load.unresolvedRepeatCount = 0
load.satisfied = {}
load.forcedKeys = {}
load.resolvedChoiceIndexes = {}
load.applyAttempts = {}
load.unconfirmed = {}
load.cleanupAttempts = {}
load.cleanupSkipped = {}
load.phase = load.resetBefore and "precleanup" or "apply"
load.choiceStage = "main"
load.stageApplied = {}
load.stagePending = {}
load.needsContinue = true
load.returnToCleanup = false
```

### setLoadEntries

Original source: load_engine.lua:732-737.

```lua
load.values = values
load.savedCounts = savedCounts
load.orderedEntries = orderedEntries
load.savedEntryByKey = savedEntryByKey
load.savedSlotCounts = savedSlotCounts
load.valueCount = valueCount
```

### completeLoad

Original source: load_engine.lua:1269-1272.

```lua
load.needsContinue = false
load.stalled = false
load.previousUnresolvedSignature = nil
load.unresolvedRepeatCount = 0
```

### stopForUnavailableOptions

Original source: load_engine.lua:1343-1347.

```lua
load.batch = nil
load.pendingChange = nil
load.needsContinue = false
load.auto = false
load.stalled = true
```

### markStalled

Original source: load_engine.lua:670-671.

```lua
load.needsContinue = false
load.stalled = true
```

### resetChoiceCaches

Original source: load_engine.lua:161-163.

```lua
load.resolvedChoiceIndexes = {}
load.optionIdentityCache = {}
load.dependencyRemaps = {}
```

### clearVisibleTracking

Original source: load_engine.lua:308-310.

```lua
load.applyAttempts = {}
load.previousUnresolvedSignature = nil
load.unresolvedRepeatCount = 0
```

### beginApplyAfterCleanup

Original source: load_engine.lua:852-857.

```lua
load.phase = "apply"
load.stageApplied = {}
load.remaining = valueCount
load.needsContinue = true
load.previousUnresolvedSignature = nil
load.unresolvedRepeatCount = 0
```

### beginVerification

Original source: load_engine.lua:862-866.

```lua
load.phase = "verify"
load.returnToCleanup = false
load.resetBefore = false
load.remaining = valueCount
load.needsContinue = true
```

### beginCleanup

Original source: load_engine.lua:1240-1245.

```lua
load.phase = "cleanup"
load.stageApplied = {}
load.remaining = valueCount
load.needsContinue = true
load.previousUnresolvedSignature = nil
load.unresolvedRepeatCount = 0
```

### returnToCleanup

Original source: load_engine.lua:1251-1257.

```lua
load.phase = "cleanup"
load.stageApplied = {}
load.returnToCleanup = false
load.remaining = valueCount
load.needsContinue = true
load.previousUnresolvedSignature = nil
load.unresolvedRepeatCount = 0
```

### prepareAutomaticLoad

Original source: native_bridge.lua:241-243.

```lua
load.autoTimer = 0
load.autoPasses = 0
load.resetBefore = true
```

### prepareRecoveryLoad

Original source: load_engine.lua:1405-1409.

```lua
load.overridePreset = preset
load.overrideName = overrideName
load.autoTimer = 0
load.autoPasses = 0
load.resetBefore = true
```

### invalidatePreflight

Original source: presets.lua:155-157.

```lua
load.preflight = nil
load.preflightDirty = true
load.preflightPresetName = nil
```

### clearPreflightForSelection

Original source: load_engine.lua:1422-1424.

```lua
load.preflight = nil
load.preflightDirty = false
load.preflightPresetName = selectedName
```

### stopAutomatic

Original source: events.lua:330-332.

```lua
load.auto = false
load.autoTimer = 0
load.autoPasses = 0
```

### finishAutomaticPass

Original source: events.lua:365-366.

```lua
load.auto = false
load.autoPasses = 0
```

### stopAutomaticAtTimeout

Original source: events.lua:352-352.

```lua
load.auto = false
```

### clearOptionCatalog

Original source: options.lua:81-83.

```lua
app.optionCatalog = nil
app.optionChoiceBindings = nil
app.optionsMemo = nil
```


## Scratch tables owned by matching and writes

The generic `helpers.clearLoadScanTable(target)` clears every key in its explicit target while keeping the table identity. Its original field rule is:

```lua
for key in pairs(target) do target[key] = nil end
```

There is no fixed field list for that scratch collection. It now forwards to `clearScanCollection`; its empty-table result and zero-return legacy contract were captured before moving it.

The scratch-model initializers below stay in the matching and write code. Their direct assignments are included in the original inventory, but the local table fields are shown here too. This stage moves lifecycle resets without changing the algorithms that build these models.

### Option scan collections

Original `load_engine.lua:58-85`.

```lua
helpers.scanLoadOptions = function(options, relevantLabels, relevantSlots)
  local started = helpers.loadClock()
  relevantLabels = relevantLabels or {}
  relevantSlots = relevantSlots or {}
  local result = state.load.scanResult
  if not result then
    result = {
      exposed = {},
      activeExposed = {},
      activeByKey = {},
      activeKeySet = {},
      activeCounts = {},
      exposedBySlot = {},
      activeSlotCounts = {},
      occurrences = {},
      signatureParts = {},
      records = {},
    }
    state.load.scanResult = result
  end
  helpers.clearLoadScanTable(result.exposed)
  helpers.clearLoadScanTable(result.activeExposed)
  helpers.clearLoadScanTable(result.activeByKey)
  helpers.clearLoadScanTable(result.activeKeySet)
  helpers.clearLoadScanTable(result.activeCounts)
  helpers.clearLoadScanTable(result.exposedBySlot)
  helpers.clearLoadScanTable(result.activeSlotCounts)
  helpers.clearLoadScanTable(result.occurrences)
```

### Pending choice after a successful game write

Original `load_engine.lua:274-300`.

```lua
  end
  state.load.pendingChange = {
    kind = kind,
    trackingKey = trackingKey,
    optionKey = exposedOption.key,
    position = exposedOption.position,
    label = exposedOption.label,
    occurrence = exposedOption.occurrence,
    slot = exposedOption.slot,
    choiceShape = exposedOption.choiceShape,
    target = target,
    previous = current,
    identity = identity,
    startedAt = state.load.elapsed,
    attemptStartedAt = state.load.elapsed,
    structureSignature = state.load.lastStructureSignature,
    confirmedAt = nil,
    confirmedSignature = nil,
    confirmedDisappeared = false,
    longSettle = longSettle,
  }
  state.load.pendingElapsed = 0
  state.load.nextInterval = AUTO_LOAD_TIMING.pollInterval
  state.load.forceStructureScan = true
  state.load.needsContinue = true
  state.load.previousUnresolvedSignature = nil
  state.load.unresolvedRepeatCount = 0
```

### Waiting batch references and timing

Original `load_engine.lua:569-598`.

```lua
helpers.confirmLoadGroup = function(system, scan)
  local group = state.load.batch
  if not group then return end
  local waiting = {}
  local waitSeconds = state.load.waitSeconds
  local accountedAt = group.accountedAt or (group[1] and group[1].startedAt) or state.load.elapsed
  if group.stage and scan.structureChanged then
    group.settleUntil = math.min(group.deadline,
      state.load.elapsed + AUTO_LOAD_TIMING.dependencyStableTime)
  end
  state.load.batch = nil
  for _, pending in ipairs(group) do
    state.load.pendingChange = pending
    if helpers.checkPendingChange(system, scan) == "waiting" then
      waiting[#waiting + 1] = pending
    end
  end
  state.load.pendingChange = nil
  state.load.waitSeconds = waitSeconds + math.max(0, state.load.elapsed - accountedAt)
  local settling = group.stage and state.load.elapsed < group.settleUntil
  if #waiting > 0 or settling then
    waiting.stage = group.stage
    waiting.settleUntil = group.settleUntil
    waiting.deadline = group.deadline
    waiting.accountedAt = state.load.elapsed
    state.load.batch = waiting
    state.load.nextInterval = AUTO_LOAD_TIMING.pollInterval
    return "waiting"
  end
  state.load.nextInterval = 0
```

### Stage batch references and timing

Original `load_engine.lua:683-698`.

```lua
  if #group == 0 then
    if #state.load.stagePending == 0 then return false end
    local pending = state.load.stagePending
    state.load.stagePending = {}
    pending.stage = true
    pending.accountedAt = state.load.elapsed
    pending.settleUntil = state.load.elapsed + AUTO_LOAD_TIMING.dependencyStableTime
    pending.deadline = state.load.elapsed + AUTO_LOAD_TIMING.dependencyTimeout
    state.load.batch = pending
    state.load.nextInterval = AUTO_LOAD_TIMING.pollInterval
    state.load.needsContinue = true
    setStatus("load", "Stage applied. Waiting for the editor to finish updating.")
    return true
  end
  for _, pending in ipairs(group) do
    state.load.stagePending[#state.load.stagePending + 1] = pending
```
