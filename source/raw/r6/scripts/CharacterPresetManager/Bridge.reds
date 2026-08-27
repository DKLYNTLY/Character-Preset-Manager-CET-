module CPM

public enum PresetSort {
  Name = 0,
  Modified = 1
}

public class NativeBridge extends ScriptableSystem {
  @runtimeProperty("ModSettings.mod", "Character Preset Manager")
  @runtimeProperty("ModSettings.category", "Preset list")
  @runtimeProperty("ModSettings.displayName", "Preset Sort Order")
  @runtimeProperty("ModSettings.description", "Sort presets by name or by the date they were last changed.")
  @runtimeProperty("ModSettings.displayValues.Name", "Name")
  @runtimeProperty("ModSettings.displayValues.Modified", "Last modified")
  public let presetSort: PresetSort = PresetSort.Name;

  private let configRevision: Int32;
  private let requestSequence: Int32;
  private let requestAction: String;
  private let requestPayload: String;
  private let luaReady: Bool;
  private let luaVersion: String;
  private let protocolVersion: Int32;
  private let busy: Bool;
  private let panels: array<wref<PresetPanel>>;

  private func OnAttach() -> Void {
    ModSettings.RegisterListenerToClass(this);
    this.configRevision += 1;
  }

  private func OnDetach() -> Void {
    ModSettings.UnregisterListenerToClass(this);
  }

  public cb func OnModSettingsChange() -> Void {
    this.configRevision += 1;
  }

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
    if this.busy && NotEquals(action, "list") { return; };
    this.requestAction = action;
    this.requestPayload = payload;
    this.requestSequence += 1;
  }

  public func Respond(sequence: Int32, kind: String, payload: String, isBusy: Bool) -> Void {
    if sequence != this.requestSequence { return; };
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

  public func SetBusy(isBusy: Bool, message: String) -> Void {
    if Equals(this.busy, isBusy) && StrLen(message) == 0 { return; };
    this.busy = isBusy;
    let index: Int32 = 0;
    while index < ArraySize(this.panels) {
      if IsDefined(this.panels[index]) {
        this.panels[index].OnBusyChanged(isBusy, message);
      };
      index += 1;
    };
  }

  public func ApplyPreferences(modifiedSort: Bool) -> Void {
    this.presetSort = modifiedSort ? PresetSort.Modified : PresetSort.Name;
  }

  public func SetLuaReady(ready: Bool, version: String, protocol: Int32) -> Void {
    this.luaReady = ready;
    this.luaVersion = version;
    this.protocolVersion = protocol;
  }

  public func GetRequestSequence() -> Int32 { return this.requestSequence; }
  public func GetRequestAction() -> String { return this.requestAction; }
  public func GetRequestPayload() -> String { return this.requestPayload; }
  public func GetConfigRevision() -> Int32 { return this.configRevision; }
  public func GetPresetSort() -> Int32 { return EnumInt(this.presetSort); }
  public func IsLuaReady() -> Bool { return this.luaReady && this.protocolVersion == 1; }
  public func IsBusy() -> Bool { return this.busy; }
}
