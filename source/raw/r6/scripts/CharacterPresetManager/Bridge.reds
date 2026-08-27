module CPM

public enum HistorySize {
  One = 1,
  Five = 5,
  Ten = 10
}

public enum PresetSort {
  Name = 0,
  Modified = 1
}

public enum ActivityLogDetail {
  Normal = 0,
  Technical = 1
}

public class NativeBridge extends ScriptableSystem {
  @runtimeProperty("ModSettings.mod", "Character Preset Manager")
  @runtimeProperty("ModSettings.category", "Character screen")
  @runtimeProperty("ModSettings.displayName", "Character-Screen Preset Panel")
  @runtimeProperty("ModSettings.description", "Show the preset panel inside supported character customization screens.")
  public let nativePanel: Bool = true;

  @runtimeProperty("ModSettings.mod", "Character Preset Manager")
  @runtimeProperty("ModSettings.category", "Character screen")
  @runtimeProperty("ModSettings.displayName", "Customization Reminder")
  @runtimeProperty("ModSettings.description", "Show a reminder when character customization opens.")
  public let customizationReminder: Bool = true;

  @runtimeProperty("ModSettings.mod", "Character Preset Manager")
  @runtimeProperty("ModSettings.category", "Appearance history")
  @runtimeProperty("ModSettings.displayName", "Appearance History Size")
  @runtimeProperty("ModSettings.description", "Choose how many automatic appearance recovery entries to keep.")
  @runtimeProperty("ModSettings.displayValues.One", "1")
  @runtimeProperty("ModSettings.displayValues.Five", "5")
  @runtimeProperty("ModSettings.displayValues.Ten", "10")
  public let historySize: HistorySize = HistorySize.Five;

  @runtimeProperty("ModSettings.mod", "Character Preset Manager")
  @runtimeProperty("ModSettings.category", "Appearance history")
  @runtimeProperty("ModSettings.displayName", "Save Before Restoring History")
  @runtimeProperty("ModSettings.description", "Save the current appearance before restoring an older history entry.")
  public let saveBeforeHistoryRestore: Bool = true;

  @runtimeProperty("ModSettings.mod", "Character Preset Manager")
  @runtimeProperty("ModSettings.category", "Preset list")
  @runtimeProperty("ModSettings.displayName", "Preset Sort Order")
  @runtimeProperty("ModSettings.description", "Sort presets by name or by the date they were last changed.")
  @runtimeProperty("ModSettings.displayValues.Name", "Name")
  @runtimeProperty("ModSettings.displayValues.Modified", "Last modified")
  public let presetSort: PresetSort = PresetSort.Name;

  @runtimeProperty("ModSettings.mod", "Character Preset Manager")
  @runtimeProperty("ModSettings.category", "Comparison and warnings")
  @runtimeProperty("ModSettings.displayName", "Show Comparison Details Automatically")
  @runtimeProperty("ModSettings.description", "Open the detailed option list after comparing a preset.")
  public let comparisonDetails: Bool = false;

  @runtimeProperty("ModSettings.mod", "Character Preset Manager")
  @runtimeProperty("ModSettings.category", "Comparison and warnings")
  @runtimeProperty("ModSettings.displayName", "Show Missing-Option Warnings")
  @runtimeProperty("ModSettings.description", "Warn when the current editor does not provide an option saved in a preset.")
  public let missingWarnings: Bool = true;

  @runtimeProperty("ModSettings.mod", "Character Preset Manager")
  @runtimeProperty("ModSettings.category", "Comparison and warnings")
  @runtimeProperty("ModSettings.displayName", "Show Clothing Warning")
  @runtimeProperty("ModSettings.description", "Show the clothing notice before appearance changes when it may help.")
  public let clothingWarning: Bool = true;

  @runtimeProperty("ModSettings.mod", "Character Preset Manager")
  @runtimeProperty("ModSettings.category", "Fallback and activity log")
  @runtimeProperty("ModSettings.displayName", "Keep CET Window as Fallback")
  @runtimeProperty("ModSettings.description", "Keep the full CET preset manager available for advanced library work and recovery.")
  public let cetFallback: Bool = true;

  @runtimeProperty("ModSettings.mod", "Character Preset Manager")
  @runtimeProperty("ModSettings.category", "Fallback and activity log")
  @runtimeProperty("ModSettings.displayName", "Activity Log Detail")
  @runtimeProperty("ModSettings.description", "Normal is easier to read. Technical includes extra details for troubleshooting.")
  @runtimeProperty("ModSettings.displayValues.Normal", "Normal")
  @runtimeProperty("ModSettings.displayValues.Technical", "Technical")
  public let activityLogDetail: ActivityLogDetail = ActivityLogDetail.Normal;

  private persistent let configurationInitialized: Bool;
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

  public func ImportLegacyConfig(reminder: Bool, modifiedSort: Bool) -> Void {
    if this.configurationInitialized { return; };
    this.customizationReminder = reminder;
    this.presetSort = modifiedSort ? PresetSort.Modified : PresetSort.Name;
    this.configurationInitialized = true;
    this.configRevision += 1;
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
  public func GetNativePanel() -> Bool { return this.nativePanel; }
  public func GetCustomizationReminder() -> Bool { return this.customizationReminder; }
  public func GetHistorySize() -> Int32 { return EnumInt(this.historySize); }
  public func GetSaveBeforeHistoryRestore() -> Bool { return this.saveBeforeHistoryRestore; }
  public func GetPresetSort() -> Int32 { return EnumInt(this.presetSort); }
  public func GetComparisonDetails() -> Bool { return this.comparisonDetails; }
  public func GetMissingWarnings() -> Bool { return this.missingWarnings; }
  public func GetClothingWarning() -> Bool { return this.clothingWarning; }
  public func GetCetFallback() -> Bool { return this.cetFallback; }
  public func GetActivityLogDetail() -> Int32 { return EnumInt(this.activityLogDetail); }
  public func IsLuaReady() -> Bool { return this.luaReady && this.protocolVersion == 1; }
  public func IsBusy() -> Bool { return this.busy; }
}
