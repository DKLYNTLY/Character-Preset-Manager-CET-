module CPM

public class NativeBridge extends ScriptableSystem {
  private let requestSequence: Int32;
  private let requestAction: String;
  private let requestPayload: String;
  private let luaReady: Bool;
  private let luaVersion: String;
  private let protocolVersion: Int32;
  private let busy: Bool;
  private let panels: array<wref<PresetPanel>>;

  public func RegisterPanel(panel: ref<PresetPanel>) -> Void {
    let index: Int32 = 0;
    while index < ArraySize(this.panels) {
      if this.panels[index] == panel { return; };
      index += 1;
    };
    ArrayPush(this.panels, panel);
  }

  public func UnregisterPanel(panel: ref<PresetPanel>) -> Void {
    let index: Int32 = ArraySize(this.panels) - 1;
    while index >= 0 {
      if !IsDefined(this.panels[index]) || this.panels[index] == panel {
        ArrayErase(this.panels, index);
      };
      index -= 1;
    };
  }

  public func Request(action: String, payload: String) -> Void {
    if this.busy && NotEquals(action, "list") && NotEquals(action, "cancel_load") { return; };
    if this.busy && Equals(this.requestAction, "cancel_load") && NotEquals(action, "cancel_load") { return; };
    this.requestAction = action;
    this.requestPayload = payload;
    this.requestSequence += 1;
  }

  public func Respond(sequence: Int32, kind: String, payload: String, isBusy: Bool) -> Void {
    if sequence != this.requestSequence { return; };
    this.requestAction = "";
    this.requestPayload = "";
    this.busy = isBusy;
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

  public func Sync(kind: String, payload: String, isBusy: Bool) -> Void {
    this.busy = isBusy;
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
