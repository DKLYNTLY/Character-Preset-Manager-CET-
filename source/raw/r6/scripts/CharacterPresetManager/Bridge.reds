module CPM

public class CoreStorageTick extends DelayCallback {
  public let bridge: wref<NativeBridge>;
  public let session: Uint64;

  public func Call() -> Void {
    if IsDefined(this.bridge) { this.bridge.CollectCoreList(this.session); };
  }
}

public class NativeBridge extends ScriptableSystem {
  private let requestSequence: Int32;
  private let requestAction: String;
  private let requestPayload: String;
  private let luaReady: Bool;
  private let luaVersion: String;
  private let protocolVersion: Int32;
  private let busy: Bool;
  private let trashFollowup: Bool;
  private let panels: array<wref<PresetPanel>>;
  private let coreSession: Uint64;
  private let coreRequest: Uint64;
  private let coreDeadline: Float;
  private let coreReadingPreset: Bool;
  private let coreSaving: Bool;
  private let coreSaveName: String;
  private let coreFilter: String;
  private let coreSaveFingerprint: String;
  private let coreMenu: wref<characterCreationBodyMorphMenu>;
  private let coreIntents: array<ref<LoadIntent>>;
  private let coreGraph: ref<LoadDependencies>;
  private let coreExecution: ref<LoadExecution>;
  private let coreSkipped: Int32;
  private let coreVerification: ref<LoadVerification>;
  private let coreGeneration: Int32;
  private let coreQuietUntil: Float;
  private let coreVerifyDeadline: Float;
  private let coreVerifyNext: Float;
  private let coreSampled: Bool;

  public func CoreAppearanceChanged() -> Void {
    if !IsDefined(this.coreVerification) { return; };
    this.coreGeneration += 1;
    this.coreVerification.Invalidate(this.coreGeneration);
    this.coreQuietUntil = EngineTime.ToFloat(GameInstance.GetEngineTime(GetGameInstance())) + 0.20;
  }

  public func AttachCoreMenu(menu: ref<characterCreationBodyMorphMenu>) -> Void {
    this.coreMenu = menu;
  }

  public func RegisterPanel(panel: ref<PresetPanel>) -> Void {
    let index: Int32 = 0;
    while index < ArraySize(this.panels) {
      if this.panels[index] == panel { return; };
      index += 1;
    };
    ArrayPush(this.panels, panel);
    this.coreSession += Cast<Uint64>(1);
    panel.SetTrashFollowup(this.trashFollowup);
  }

  public func UnregisterPanel(panel: ref<PresetPanel>) -> Void {
    let index: Int32 = ArraySize(this.panels) - 1;
    while index >= 0 {
      if !IsDefined(this.panels[index]) || this.panels[index] == panel {
        ArrayErase(this.panels, index);
      };
      index -= 1;
    };
    if !this.HasPanels() && CPMCoreTestEnabled() {
      this.coreSession += Cast<Uint64>(1);
      this.busy = false;
      this.coreExecution = null;
      this.coreVerification = null;
      this.coreMenu = null;
      this.coreSaveFingerprint = "";
    };
  }

  public func SetTrashFollowup(active: Bool) -> Void {
    let index: Int32 = 0;
    this.trashFollowup = active;
    while index < ArraySize(this.panels) {
      if IsDefined(this.panels[index]) { this.panels[index].SetTrashFollowup(active); };
      index += 1;
    };
  }

  public func Request(action: String, payload: String) -> Void {
    if CPMCoreTestEnabled() {
      if Equals(action, "open") || Equals(action, "list") || Equals(action, "refresh") {
        if Equals(action, "list") { this.coreFilter = UTF8StrLower(payload); };
        if !this.busy { this.RequestCoreList(); };
      } else {
        if Equals(action, "select_load") {
          this.coreSaveFingerprint = "";
          if !this.busy { this.RequestCoreRead(payload); };
          return;
        };
        if Equals(action, "cancel_save_confirmation") {
          this.coreSaveFingerprint = "";
          return;
        };
        if Equals(action, "save") {
          if !this.busy { this.RequestCoreSave(payload); };
          return;
        };
        this.NotifyPanels("error", "This action is not available in the core test build.", this.busy);
      };
      return;
    };
    if this.busy && NotEquals(action, "list") { return; };
    this.requestAction = action;
    this.requestPayload = payload;
    this.requestSequence += 1;
  }

  private func RequestCoreList() -> Void {
    this.coreSaving = false;
    this.coreSaveFingerprint = "";
    this.coreReadingPreset = false;
    this.coreRequest += Cast<Uint64>(1);
    if !CPMStorageList(this.coreRequest, this.coreSession) {
      this.NotifyPanels("error", "Could not request the preset list.", false);
      return;
    };
    this.coreDeadline = EngineTime.ToFloat(GameInstance.GetEngineTime(GetGameInstance())) + 5.0;
    this.SetBusy(true, "Reading presets…", false);
    this.ScheduleCoreList(this.coreSession);
  }

  private func RequestCoreRead(path: String) -> Void {
    this.coreSaving = false;
    this.coreRequest += Cast<Uint64>(1);
    if !CPMStorageRead(this.coreRequest, this.coreSession, path) {
      this.NotifyPanels("error", "Could not request the preset.", false);
      return;
    };
    this.coreReadingPreset = true;
    this.coreDeadline = EngineTime.ToFloat(GameInstance.GetEngineTime(GetGameInstance())) + 5.0;
    this.SetBusy(true, "Reading preset…", false);
    this.ScheduleCoreList(this.coreSession);
  }

  private func RequestCoreSave(name: String) -> Void {
    if !IsDefined(this.coreMenu) { return; };
    let system = this.coreMenu.CPMCoreCustomizationSystem();
    if !IsDefined(system) { return; };
    if !Equals(name, this.coreSaveName) { this.coreSaveFingerprint = ""; };
    let contents = CoreCapture.Capture(system, name);
    this.coreRequest += Cast<Uint64>(1);
    if StrLen(contents) == 0 || !CPMStorageSave(this.coreRequest, this.coreSession, name + ".preset", contents, this.coreSaveFingerprint) {
      this.NotifyPanels("error", "Could not capture this appearance or use that preset name.", false);
      return;
    };
    this.coreSaveName = name;
    this.coreSaving = true;
    this.coreDeadline = EngineTime.ToFloat(GameInstance.GetEngineTime(GetGameInstance())) + 5.0;
    this.SetBusy(true, "Saving preset…", false);
    this.ScheduleCoreList(this.coreSession);
  }

  private func ScheduleCoreList(session: Uint64) -> Void {
    let tick = new CoreStorageTick();
    tick.bridge = this;
    tick.session = session;
    GameInstance.GetDelaySystem(GetGameInstance()).DelayCallbackNextFrame(tick);
  }

  public func CollectCoreList(session: Uint64) -> Void {
    if session != this.coreSession { return; };
    if !this.HasPanels() { this.busy = false; return; };
    if IsDefined(this.coreVerification) {
      this.VerifyCoreLoad(session);
      return;
    };
    if IsDefined(this.coreExecution) {
      this.ExecuteCoreLoad(session);
      return;
    };
    while CPMStoragePoll() {
      if Equals(CPMStorageResult("session"), ToString(session))
        && Equals(CPMStorageResult("id"), ToString(this.coreRequest)) {
        this.busy = false;
        if this.coreSaving {
          let status = CPMStorageResult("status");
          this.coreSaveFingerprint = "";
          if Equals(status, "conflict") {
            this.coreSaveFingerprint = CPMStorageResult("fingerprint");
            if StrLen(this.coreSaveFingerprint) > 0 {
              this.NotifyPanels("confirm_state", "SAVE\t1", false);
              return;
            };
          };
          if Equals(status, "success") {
            this.NotifyPanels("confirm_state", "SAVE\t0", false);
            this.RequestCoreList();
          } else {
            this.NotifyPanels("error", "Could not save the preset.", false);
          };
          return;
        };
        if Equals(CPMStorageResult("status"), "success") {
          if this.coreReadingPreset {
            this.coreIntents = LoadInput.Decode(CPMStorageResult("intents"));
            if ArraySize(this.coreIntents) == 0 || !IsDefined(this.coreMenu) {
              this.NotifyPanels("error", "No supported appearance choices were found.", false);
              return;
            };
            let savedBody = CPMStorageResult("body");
            let system = this.coreMenu.CPMCoreCustomizationSystem();
            if !IsDefined(system) {
              this.NotifyPanels("error", "The character editor is no longer available.", false);
              return;
            };
            let state = system.GetState();
            if IsDefined(state) && (Equals(savedBody, "Male") || Equals(savedBody, "Female")) {
              let currentBody = state.IsBodyGenderMale() ? "Male" : "Female";
              if NotEquals(savedBody, currentBody) {
                this.NotifyPanels("error", "This preset uses a different body type. Select a preset for the current body.", false);
                return;
              };
            };
            this.coreGraph = LoadDependencies.Build(this.coreIntents);
            this.coreSkipped = ArraySize(this.coreGraph.cyclic);
            this.coreExecution = LoadExecution.Create(this.coreGraph, 30.0);
            this.SetBusy(true, "Applying preset…", false);
            this.ScheduleCoreList(session);
            return;
          };
          let paths = StrSplit(CPMStorageResult("contents"), "\n", false);
          let list: String = "";
          let index: Int32 = 0;
          while index < ArraySize(paths) {
            let path = paths[index];
            let lower = UTF8StrLower(path);
            if StrLen(path) > 0 && (StrLen(this.coreFilter) == 0 || StrContains(lower, this.coreFilter)) {
              list += "ROW\tpreset\t" + path + "\t" + path + "\n";
            };
            index += 1;
          };
          this.NotifyPanels("list", list, false);
          this.SetBusy(false, "Choose a preset.", false);
        } else {
          this.NotifyPanels("error", "Could not read the preset library.", false);
        };
        return;
      };
    };
    if EngineTime.ToFloat(GameInstance.GetEngineTime(GetGameInstance())) >= this.coreDeadline {
      this.busy = false;
      this.NotifyPanels("error", "The preset library did not respond.", false);
      return;
    };
    this.ScheduleCoreList(session);
  }

  private func ExecuteCoreLoad(session: Uint64) -> Void {
    let started = CPMMonotonicTime();
    let steps: Int32 = 0;
    while steps < 8 && CPMMonotonicTime() - started < 0.004d {
      if !this.ExecuteCoreStep(session) { return; };
      steps += 1;
    };
    this.ScheduleCoreList(session);
  }

  private func ExecuteCoreStep(session: Uint64) -> Bool {
    let event = new LoadStepEvent();
    event.now = EngineTime.ToFloat(GameInstance.GetEngineTime(GetGameInstance()));
    event.editorOpen = IsDefined(this.coreMenu);
    let step = this.coreExecution.Step(event);
    if Equals(step.kind, "resolve") {
      let system = this.coreMenu.CPMCoreCustomizationSystem();
      if !IsDefined(system) {
        this.coreExecution = null;
        this.SetBusy(false, "The character editor is no longer available.", true);
        return false;
      };
      let parent: Bool = false;
      let child: Int32 = 0;
      while child < ArraySize(this.coreGraph.parents) {
        if ArrayContains(this.coreGraph.parents[child].positions, step.position) { parent = true; break; };
        child += 1;
      };
      let resolution = LoadGameAdapter.ApplyFresh(system, this.coreIntents[step.position], parent);
      event.hasPosition = true;
      event.position = step.position;
      event.target = resolution.target;
      event.status = Equals(resolution.status, "applied") ? "ready" : resolution.status;
      step = this.coreExecution.Step(event);
    };
    if Equals(step.kind, "warn") { this.coreSkipped += 1; };
    if Equals(step.kind, "finished") {
      this.coreExecution = null;
      if Equals(step.reason, "complete") {
        this.coreVerification = LoadVerification.Create(ArraySize(this.coreIntents), this.coreGeneration);
        this.coreQuietUntil = event.now + 0.20;
        this.coreVerifyDeadline = event.now + 0.20 + 1.25;
        this.coreVerifyNext = this.coreQuietUntil;
        this.coreSampled = false;
        this.SetBusy(true, "Checking appearance…", false);
        this.ScheduleCoreList(session);
      } else {
        this.SetBusy(false, "Preset loading stopped: " + step.reason, true);
      };
      return false;
    };
    if Equals(step.kind, "write") {
      this.ScheduleCoreList(session);
      return false;
    };
    return true;
  }

  private func VerifyCoreLoad(session: Uint64) -> Void {
    let now = EngineTime.ToFloat(GameInstance.GetEngineTime(GetGameInstance()));
    if !IsDefined(this.coreMenu) {
      this.coreVerification = null;
      this.SetBusy(false, "The character editor closed.", true);
      return;
    };
    if now >= this.coreQuietUntil && now >= this.coreVerifyNext && now < this.coreVerifyDeadline {
      let system = this.coreMenu.CPMCoreCustomizationSystem();
      if !IsDefined(system) {
        this.coreVerification = null;
        this.SetBusy(false, "The character editor is no longer available.", true);
        return;
      };
      let catalog = LoadGameAdapter.Read(system);
      let position: Int32 = 0;
      while position < ArraySize(this.coreIntents) {
        if !this.coreSampled || this.coreVerification.entries[position].pending {
          let resolution = LoadResolution.Resolve(this.coreIntents[position], catalog);
          let observation = new LoadObservation();
          observation.status = resolution.status;
          observation.target = resolution.target;
          observation.hasTarget = resolution.position >= 0;
          if observation.hasTarget {
            observation.hasCurrent = true;
            observation.current = catalog[resolution.position].current;
          };
          this.coreVerification.Observe(position, observation, this.coreSampled);
        };
        position += 1;
      };
      this.coreSampled = true;
      this.coreVerifyNext = now + 0.05;
    };
    let pending = this.coreVerification.Pending();
    if now >= this.coreVerifyDeadline || this.coreSampled && ArraySize(pending) == 0 {
      let verified: Int32 = 0;
      let position: Int32 = 0;
      while position < ArraySize(this.coreVerification.entries) {
        if this.coreVerification.entries[position].verified { verified += 1; };
        position += 1;
      };
      let total = ArraySize(this.coreIntents);
      let partial = verified != total || this.coreSkipped > 0;
      this.coreVerification = null;
      FTLog(s"[CPM Core] Load verification: \(verified) of \(total), skipped during execution: \(this.coreSkipped)");
      this.SetBusy(false, ToString(verified) + " of " + ToString(total) + " appearance choices verified.", partial);
      return;
    };
    this.ScheduleCoreList(session);
  }

  public func Respond(sequence: Int32, kind: String, payload: String, isBusy: Bool) -> Void {
    if sequence != this.requestSequence { return; };
    this.requestAction = "";
    this.requestPayload = "";
    this.busy = isBusy;
    this.NotifyPanels(kind, payload, isBusy);
  }

  public func Sync(kind: String, payload: String, isBusy: Bool) -> Void {
    this.busy = isBusy;
    this.NotifyPanels(kind, payload, isBusy);
  }

  private func NotifyPanels(kind: String, payload: String, isBusy: Bool) -> Void {
    let index: Int32 = ArraySize(this.panels) - 1;
    while index >= 0 {
      if IsDefined(this.panels[index]) {
        this.panels[index].OnBridgeResponse(kind, payload, isBusy);
      } else {
        ArrayErase(this.panels, index);
      };
      index -= 1;
    };
  }

  public func SetBusy(isBusy: Bool, message: String, isError: Bool) -> Void {
    if Equals(this.busy, isBusy) && StrLen(message) == 0 { return; };
    this.busy = isBusy;
    let index: Int32 = 0;
    while index < ArraySize(this.panels) {
      if IsDefined(this.panels[index]) {
        this.panels[index].OnBusyChanged(isBusy, message, isError);
      };
      index += 1;
    };
  }

  public func SetLuaReady(ready: Bool, version: String, protocol: Int32) -> Void {
    this.luaReady = ready;
    this.luaVersion = version;
    this.protocolVersion = protocol;
  }

  public func GetRequestSequence() -> Int32 { return this.requestSequence; }
  public func GetRequestAction() -> String { return this.requestAction; }
  public func GetRequestPayload() -> String { return this.requestPayload; }
  public func HasPanels() -> Bool {
    let index: Int32 = 0;
    while index < ArraySize(this.panels) {
      if IsDefined(this.panels[index]) { return true; };
      index += 1;
    };
    return false;
  }
  public func IsLuaReady() -> Bool { return this.luaReady && this.protocolVersion == 1; }
  public func IsBusy() -> Bool { return this.busy; }
}
