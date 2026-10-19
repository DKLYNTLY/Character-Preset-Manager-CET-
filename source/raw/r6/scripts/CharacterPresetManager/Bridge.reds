module CPM

public class NativeBridge extends ScriptableSystem {
  private let session: Uint64;
  private let operation: Uint64;
  private let panels: array<wref<PresetPanel>>;
  private let manager: wref<PresetManager>;
  private let editor: wref<characterCreationBodyMorphMenu>;
  private let system: ref<gameuiICharacterCustomizationSystem>;
  private let loading: Bool;
  private let cancelRequested: Bool;
  private let loadSteps: Int32;
  private let waiting: Bool;
  private let pendingChoice: ref<NativeReply>;
  private let settleTime: Float;
  private let stableTime: Float;
  private let lastHash: Uint64;
  private let command: String;
  private let queuedSearch: String;
  private let hasQueuedSearch: Bool;
  private let ready: Bool;
  private let diagnostics: String;
  private let overlayOpen: Bool;

  public func AttachEditor(menu: ref<characterCreationBodyMorphMenu>, system: ref<gameuiICharacterCustomizationSystem>) -> Void {
    this.editor = menu;
    this.system = system;
    this.loading = false;
    this.cancelRequested = false;
    this.waiting = false;
    this.operation = 0ul;
    this.pendingChoice = null;
    let request: ref<NativeRequest> = new NativeRequest();
    request.command = "begin";
    let reply: ref<NativeReply> = new NativeReply();
    if CPMNativeExchange(request, reply) && reply.accepted && Equals(reply.version, "3.1.3") {
      this.session = reply.session;
      this.ready = true;
    } else {
      this.ready = false;
      this.Sync("error", "Update all Character Preset Manager files together, then restart the game.", false);
    };
    this.Request("open", "");
  }

  public func DetachEditor() -> Void {
    this.loading = false;
    this.cancelRequested = false;
    this.waiting = false;
    this.pendingChoice = null;
    this.hasQueuedSearch = false;
    this.manager = null;
    if this.session != 0ul {
      let request: ref<NativeRequest> = new NativeRequest();
      request.command = "close";
      request.session = this.session;
      let reply: ref<NativeReply> = new NativeReply();
      CPMNativeExchange(request, reply);
    };
    this.session = 0ul;
    this.operation = 0ul;
    this.ready = false;
    this.editor = null;
    this.system = null;
  }

  public func Capture() -> array<ref<OptionSnapshot>> {
    let copied: array<ref<OptionSnapshot>>;
    if !IsDefined(this.system) { return copied; };
    let options: array<ref<CharacterCustomizationOption>> = this.system.GetUnitedOptions(true, true, true);
    let i: Int32 = 0;
    while i < ArraySize(options) && i < 4097 {
      let option: ref<CharacterCustomizationOption> = options[i];
      let snapshot: ref<OptionSnapshot> = new OptionSnapshot();
      if IsDefined(option) && IsDefined(option.info) {
        snapshot.key = LocKeyToString(option.info.name);
        snapshot.label = GetLocalizedText(option.info.localizedName);
        snapshot.slot = NameToString(option.info.uiSlot);
        snapshot.index = option.currIndex;
        snapshot.active = option.isActive;
        snapshot.editable = option.isEditable;
        let appearance: ref<gameuiAppearanceInfo> = option.info as gameuiAppearanceInfo;
        let morph: ref<gameuiMorphInfo> = option.info as gameuiMorphInfo;
        let switcher: ref<gameuiSwitcherInfo> = option.info as gameuiSwitcherInfo;
        let j: Int32 = 0;
        if IsDefined(appearance) {
          while j < ArraySize(appearance.definitions) && j < 65537 {
            ArrayPush(snapshot.definitions, NameToString(appearance.definitions[j].name));
            j += 1;
          };
        };
        j = 0;
        if IsDefined(morph) {
          while j < ArraySize(morph.morphNames) && j < 65537 {
            ArrayPush(snapshot.morphs, NameToString(morph.morphNames[j].morphName));
            j += 1;
          };
        };
        j = 0;
        if IsDefined(switcher) {
          while j < ArraySize(switcher.options) && j < 65537 {
            ArrayPush(snapshot.switches, switcher.options[j].localizedName);
            j += 1;
          };
        };
      };
      ArrayPush(copied, snapshot);
      i += 1;
    };
    return copied;
  }

  private func SnapshotHash() -> Uint64 {
    let request: ref<NativeRequest> = new NativeRequest();
    request.command = "snapshot";
    request.options = this.Capture();
    let reply: ref<NativeReply> = new NativeReply();
    if CPMNativeExchange(request, reply) && reply.accepted { return reply.snapshotHash; };
    return 0ul;
  }

  public func Request(action: String, payload: String) -> Void {
    this.RequestExtended(action, payload, "", false);
  }

  public func RequestExtended(action: String, payload: String, extra: String, confirmed: Bool) -> Void {
    if Equals(action, "cancel_load") {
      this.cancelRequested = this.operation != 0ul;
      this.loading = false;
      this.waiting = false;
      this.pendingChoice = null;
      if this.operation != 0ul {
        let cancel: ref<NativeRequest> = new NativeRequest();
        cancel.command = "cancel";
        cancel.session = this.session;
        cancel.operation = this.operation;
        let result: ref<NativeReply> = new NativeReply();
        CPMNativeExchange(cancel, result);
        this.Sync("status", "Loading canceled. Choices already applied remain visible.", false);
        return;
      };
    };
    if this.operation != 0ul || this.waiting || (this.loading && NotEquals(action, "step")) {
      if Equals(action, "list") { this.queuedSearch = payload; this.hasQueuedSearch = true; } else { this.Sync("status", "Wait for the current action, or cancel the load.", true); };
      return;
    };
    if !this.ready || this.session == 0ul {
      this.Sync("error", "Install matching native files, redscript, RED4ext and Codeware, then restart the game.", false);
      return;
    };
    if Equals(action, "step") {
      this.loadSteps += 1;
      if this.loadSteps > 8192 { this.Request("cancel_load", ""); return; };
    };
    let request: ref<NativeRequest> = new NativeRequest();
    request.command = action;
    request.text = payload;
    request.extra = extra;
    request.confirmed = confirmed;
    request.unconfirmed = Equals(action, "step") && IsDefined(this.pendingChoice) && this.settleTime >= 1.25;
    request.session = this.session;
    if Equals(action, "save") || Equals(action, "load") || Equals(action, "force_load") || Equals(action, "compare") || Equals(action, "diagnostics") || Equals(action, "step") || Equals(action, "restore_previous") || Equals(action, "restore_history") {
      request.options = this.Capture();
    };
    let reply: ref<NativeReply> = new NativeReply();
    if CPMNativeExchange(request, reply) && reply.accepted && Equals(reply.version, "3.1.3") {
      this.operation = reply.operation;
      this.command = action;
      this.SetBusy(true, "Working...", false);
    } else {
      this.loading = false;
      this.Sync("error", StrLen(reply.payload) > 0 ? reply.payload : "The native preset service is unavailable. Restart the game after installing the complete package.", false);
    };
  }

  public func Tick() -> Void {
    if this.operation != 0ul {
      let request: ref<NativeRequest> = new NativeRequest();
      request.command = "poll";
      request.session = this.session;
      request.operation = this.operation;
      let reply: ref<NativeReply> = new NativeReply();
      if !CPMNativeExchange(request, reply) { return; };
      if Equals(reply.status, "queued") || Equals(reply.status, "running") { return; };
      this.operation = 0ul;
      if this.cancelRequested { this.cancelRequested = false; this.Request("cancel_load", ""); return; };
      if !reply.accepted || Equals(reply.status, "failed") || Equals(reply.kind, "error") {
        this.loading = false;
        this.Sync("error", reply.payload, false);
        return;
      };
      if Equals(reply.status, "canceled") {
        this.Request("cancel_load", "");
        return;
      };
      if Equals(reply.kind, "start_load") { this.loading = true; this.loadSteps = 0; this.Request("step", ""); return; };
      if Equals(reply.kind, "continue") { this.Request("step", ""); return; };
      if Equals(reply.kind, "change") {
        if this.SnapshotHash() != reply.snapshotHash { this.Request("step", ""); return; };
        let options: array<ref<CharacterCustomizationOption>> = this.system.GetUnitedOptions(true, true, true);
        if reply.position < 0 || reply.position >= ArraySize(options) { this.loading = false; this.Sync("error", "The editor changed. Select the preset and try again.", false); return; };
        let option: ref<CharacterCustomizationOption> = options[reply.position];
        if !option.isActive || !option.isEditable || NotEquals(LocKeyToString(option.info.name), reply.key) || NotEquals(NameToString(option.info.uiSlot), reply.slot) || option.currIndex != reply.current {
          this.Request("step", ""); return;
        };
        this.system.ApplyChangeToOption(option, reply.target);
        this.pendingChoice = reply;
        this.waiting = true;
        this.settleTime = 0.0;
        this.stableTime = 0.0;
        this.lastHash = this.SnapshotHash();
        this.Sync("status", reply.payload, true);
        return;
      };
      this.pendingChoice = null;
      if Equals(reply.kind, "complete") || Equals(reply.kind, "partial") || Equals(reply.kind, "failed") {
        if this.SnapshotHash() != reply.snapshotHash { this.loading = true; this.Request("step", ""); return; };
        if IsDefined(this.editor) { this.editor.RefreshList(); };
        this.loading = false;
        this.diagnostics = reply.payload;
        this.Sync(Equals(reply.kind, "failed") ? "error" : "status", reply.payload, false);
      } else {
        this.loading = false;
        this.Sync(reply.kind, reply.payload, false);
      };
    };
    if this.waiting && IsDefined(this.pendingChoice) {
      this.settleTime += 0.05;
      let hash: Uint64 = this.SnapshotHash();
      if hash == this.lastHash { this.stableTime += 0.05; } else { this.stableTime = 0.0; this.lastHash = hash; };
      if (this.settleTime >= 0.225 && this.stableTime >= 0.20) || this.settleTime >= 1.25 {
        let options: array<ref<CharacterCustomizationOption>> = this.system.GetUnitedOptions(true, true, true);
        let position: Int32 = this.pendingChoice.position;
        let reached: Bool = position >= 0 && position < ArraySize(options) && Equals(LocKeyToString(options[position].info.name), this.pendingChoice.key) && Equals(NameToString(options[position].info.uiSlot), this.pendingChoice.slot) && options[position].currIndex == this.pendingChoice.target;
        if reached || this.settleTime >= 1.25 {
          this.waiting = false;
          if reached { this.pendingChoice = null; };
          this.Request("step", "");
        };
      };
    };
    if this.operation == 0ul && !this.loading && this.hasQueuedSearch {
      this.hasQueuedSearch = false;
      this.Request("list", this.queuedSearch);
    };
  }

  public func RegisterPanel(panel: ref<PresetPanel>) -> Void { ArrayPush(this.panels, panel); }
  public func UnregisterPanel(panel: ref<PresetPanel>) -> Void {
    let i: Int32 = ArraySize(this.panels) - 1;
    while i >= 0 { if !IsDefined(this.panels[i]) || this.panels[i] == panel { ArrayErase(this.panels, i); }; i -= 1; };
  }
  public func RegisterManager(manager: ref<PresetManager>) -> Void { this.manager = manager; }
  public func HasPanels() -> Bool { return ArraySize(this.panels) > 0; }
  public func IsReady() -> Bool { return this.ready; }
  public func IsBusy() -> Bool { return this.loading || this.operation != 0ul; }
  public func GetDiagnostics() -> String { return this.diagnostics; }
  public func SetOverlayOpen(value: Bool) -> Void { this.overlayOpen = value; }
  public func IsTyping() -> Bool {
    let i: Int32 = 0;
    if IsDefined(this.manager) && this.manager.IsEnteringText() { return true; };
    while i < ArraySize(this.panels) { if IsDefined(this.panels[i]) && this.panels[i].IsEnteringText() { return true; }; i += 1; };
    return false;
  }
  public func TogglePanelVisibility() -> Bool {
    if this.overlayOpen || this.IsTyping() { return false; };
    let i: Int32 = 0;
    while i < ArraySize(this.panels) { if IsDefined(this.panels[i]) { this.panels[i].ToggleVisibility(); }; i += 1; };
    return this.HasPanels();
  }
  public func SetBusy(value: Bool, message: String, error: Bool) -> Void {
    let i: Int32 = 0;
    while i < ArraySize(this.panels) { if IsDefined(this.panels[i]) { this.panels[i].OnBusyChanged(value, message, error); }; i += 1; };
    if IsDefined(this.manager) { this.manager.OnBusy(value, message); };
  }
  public func Sync(kind: String, payload: String, busy: Bool) -> Void {
    let i: Int32 = 0;
    this.diagnostics = payload;
    let managerVisible: Bool = IsDefined(this.manager) && this.manager.GetRootWidget().IsVisible();
    let panelResponse: Bool = NotEquals(kind, "manager_list") && NotEquals(kind, "manager_text") && (!managerVisible || (NotEquals(kind, "history") && NotEquals(kind, "comparison")));
    while i < ArraySize(this.panels) { if panelResponse && IsDefined(this.panels[i]) { this.panels[i].OnBridgeResponse(kind, payload, busy); }; i += 1; };
    if IsDefined(this.manager) { this.manager.OnResponse(kind, payload, busy); };
  }
}
