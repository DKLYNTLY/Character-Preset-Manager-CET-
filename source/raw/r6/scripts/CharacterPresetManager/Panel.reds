module CPM
import Codeware.UI.*

public class PanelButton extends CustomButton {
  protected let frame: wref<inkRectangle>;
  protected let fill: wref<inkRectangle>;
  protected let style: Int32;
  protected let selected: Bool;

  protected func CreateWidgets() -> Void {
    let root: ref<inkCanvas> = new inkCanvas();
    root.SetSize(270.0, 52.0);
    root.SetInteractive(true);
    root.SetSupportFocus(true);
    let fill: ref<inkRectangle> = new inkRectangle();
    fill.SetAnchor(inkEAnchor.Fill);
    fill.SetTintColor(HDRColor(0.10, 0.025, 0.030, 0.94));
    fill.Reparent(root);
    let frame: ref<inkRectangle> = new inkRectangle();
    frame.SetAnchor(inkEAnchor.Fill);
    frame.SetTintColor(HDRColor(1.0, 0.18, 0.20, 1.0));
    frame.SetOpacity(0.72);
    frame.Reparent(root);
    let label: ref<inkText> = new inkText();
    label.SetAnchor(inkEAnchor.Fill);
    label.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    label.SetFontStyle(n"Semi-Bold");
    label.SetFontSize(34);
    label.SetLetterCase(textLetterCase.UpperCase);
    label.SetHorizontalAlignment(textHorizontalAlignment.Center);
    label.SetVerticalAlignment(textVerticalAlignment.Center);
    label.SetTintColor(HDRColor(1.0, 1.0, 1.0, 1.0));
    label.SetText("BUTTON");
    label.Reparent(root);
    this.m_root = root;
    this.m_label = label;
    this.frame = frame;
    this.fill = fill;
    this.SetRootWidget(root);
  }

  protected func ApplyDisabledState() -> Void { this.m_root.SetOpacity(this.m_isDisabled ? 0.32 : 1.0); }
  protected func ApplyHoveredState() -> Void { this.frame.SetOpacity(this.m_isHovered && !this.m_isDisabled ? 1.0 : (this.selected ? 1.0 : 0.72)); }
  protected func ApplyPressedState() -> Void {
    if this.selected {
      this.fill.SetTintColor(HDRColor(0.03, 0.27, 0.32, 0.96));
    } else {
      if this.style == 2 {
        this.fill.SetTintColor(this.m_isPressed ? HDRColor(0.62, 0.08, 0.10, 1.0) : HDRColor(0.30, 0.035, 0.045, 0.96));
      } else {
        if this.style == 1 {
          this.fill.SetTintColor(this.m_isPressed ? HDRColor(0.42, 0.045, 0.055, 1.0) : HDRColor(0.20, 0.025, 0.035, 0.96));
        } else {
          if this.style == 3 {
            this.fill.SetTintColor(this.m_isPressed ? HDRColor(0.08, 0.25, 0.29, 1.0) : HDRColor(0.055, 0.08, 0.10, 0.98));
          } else {
            this.fill.SetTintColor(this.m_isPressed ? HDRColor(0.26, 0.045, 0.055, 1.0) : HDRColor(0.10, 0.025, 0.030, 0.94));
          };
        };
      };
    };
  }
  public func SetSelected(selected: Bool) -> Void {
    this.selected = selected;
    this.frame.SetTintColor(selected ? HDRColor(0.22, 0.92, 1.0, 1.0) : HDRColor(1.0, 0.18, 0.20, 1.0));
    this.frame.SetOpacity(selected ? 1.0 : 0.72);
    this.ApplyPressedState();
  }
  public func SetStyle(value: Int32) -> Void {
    this.style = value;
    if value == 3 {
      this.m_label.SetTintColor(HDRColor(0.22, 0.92, 1.0, 1.0));
    } else {
      this.m_label.SetTintColor(value > 0 ? HDRColor(1.0, 0.28, 0.30, 1.0) : HDRColor(1.0, 1.0, 1.0, 1.0));
    };
    this.ApplyPressedState();
  }
  public static func Create(text: String) -> ref<PanelButton> {
    let button: ref<PanelButton> = new PanelButton();
    button.CreateInstance();
    button.SetText(text);
    return button;
  }
}

public class PresetPanel extends inkCustomController {
  private let bridge: wref<NativeBridge>;
  private let search: ref<HubTextInput>;
  private let presetName: ref<HubTextInput>;
  private let statusText: wref<inkText>;
  private let scrollThumb: wref<inkRectangle>;
  private let locationButton: ref<PanelButton>;
  private let saveAction: ref<PanelButton>;
  private let trashAction: ref<PanelButton>;
  private let listButtons: array<ref<PanelButton>>;
  private let actionButtons: array<ref<PanelButton>>;
  private let rowKinds: array<String>;
  private let rowValues: array<String>;
  private let rowLabels: array<String>;
  private let saveLocations: array<String>;
  private let selectedName: String;
  private let selectedSaveLocation: String;
  private let scrollOffset: Int32;
  private let busy: Bool;

  protected cb func OnCreate() -> Bool {
    let root: ref<inkCanvas> = new inkCanvas();
    root.SetName(n"CharacterPresetManagerPanel");
    root.SetAnchor(inkEAnchor.TopLeft);
    root.SetAnchorPoint(new Vector2(0.0, 0.0));
    root.SetMargin(new inkMargin(120.0, 220.0, 0.0, 0.0));
    root.SetSize(940.0, 1390.0);
    root.SetInteractive(true);
    root.SetSupportFocus(true);
    let background: ref<inkRectangle> = new inkRectangle();
    background.SetAnchor(inkEAnchor.Fill);
    background.SetTintColor(HDRColor(0.025, 0.012, 0.018, 0.97));
    background.Reparent(root);
    let rail: ref<inkRectangle> = new inkRectangle();
    rail.SetSize(7.0, 1390.0);
    rail.SetTintColor(HDRColor(1.0, 0.16, 0.18, 1.0));
    rail.Reparent(root);
    let title: ref<inkText> = this.MakeText("CHARACTER PRESET MANAGER", 46, 34.0, 24.0, 864.0, 58.0);
    title.SetTintColor(HDRColor(1.0, 0.22, 0.24, 1.0));
    title.Reparent(root);
    let subtitle: ref<inkText> = this.MakeText("PRESETS AVAILABLE DURING CHARACTER CUSTOMIZATION", 27, 34.0, 82.0, 864.0, 40.0);
    subtitle.SetTintColor(HDRColor(0.22, 0.92, 1.0, 1.0));
    subtitle.Reparent(root);

    let advancedText: ref<inkText> = this.MakeText("For rename, permanent delete, Help, compatibility checks, Favorites, folders, backups, and Trash recovery, open the CET menu.", 27, 34.0, 132.0, 864.0, 82.0);
    advancedText.SetWrapping(true, 854.0);
    advancedText.SetTintColor(HDRColor(1.0, 1.0, 1.0, 1.0));
    advancedText.Reparent(root);

    this.search = HubTextInput.Create();
    this.search.SetName(n"PresetSearch");
    this.search.SetDefaultText("SEARCH");
    this.search.SetWidth(864.0);
    this.search.SetMaxLength(64);
    this.search.GetRootWidget().SetMargin(new inkMargin(34.0, 220.0, 0.0, 0.0));
    this.search.RegisterToCallback(n"OnInput", this, n"OnSearchChanged");
    this.search.Reparent(root, this.GetGameController());
    let index: Int32 = 0;
    while index < 9 {
      let listButton: ref<PanelButton> = PanelButton.Create("");
      listButton.SetPosition(34.0, 306.0 + Cast<Float>(index) * 74.0);
      listButton.SetWidth(864.0);
      listButton.RegisterToCallback(n"OnBtnClick", this, n"OnListClick");
      listButton.GetRootWidget().RegisterToCallback(n"OnAxis", this, n"OnPanelScroll");
      listButton.GetRootWidget().RegisterToCallback(n"OnRelative", this, n"OnPanelScroll");
      listButton.Reparent(root, this.GetGameController());
      ArrayPush(this.listButtons, listButton);
      index += 1;
    };
    let scrollTrack: ref<inkRectangle> = new inkRectangle();
    scrollTrack.SetSize(7.0, 666.0);
    scrollTrack.SetMargin(new inkMargin(912.0, 306.0, 0.0, 0.0));
    scrollTrack.SetTintColor(HDRColor(0.28, 0.04, 0.05, 0.9));
    scrollTrack.Reparent(root);
    this.scrollThumb = new inkRectangle();
    this.scrollThumb.SetSize(7.0, 666.0);
    this.scrollThumb.SetMargin(new inkMargin(912.0, 306.0, 0.0, 0.0));
    this.scrollThumb.SetTintColor(HDRColor(0.22, 0.92, 1.0, 1.0));
    this.scrollThumb.Reparent(root);
    this.statusText = this.MakeText("Select a preset to load it.", 28, 34.0, 992.0, 864.0, 82.0);
    this.statusText.SetWrapping(true, 854.0);
    this.statusText.SetTintColor(HDRColor(1.0, 1.0, 1.0, 1.0));
    this.statusText.Reparent(root);
    this.presetName = HubTextInput.Create();
    this.presetName.SetName(n"PresetName");
    this.presetName.SetDefaultText("PRESET NAME");
    this.presetName.SetWidth(864.0);
    this.presetName.SetMaxLength(64);
    this.presetName.GetRootWidget().SetMargin(new inkMargin(34.0, 1082.0, 0.0, 0.0));
    this.presetName.RegisterToCallback(n"OnInput", this, n"OnPresetNameChanged");
    this.presetName.Reparent(root, this.GetGameController());
    this.locationButton = this.AddAction(root, "SAVE LOCATION: ALL PRESETS", 34.0, 1170.0, n"OnSaveLocation");
    this.locationButton.SetWidth(864.0);
    this.saveAction = this.AddAction(root, "SAVE PRESET", 34.0, 1244.0, n"OnSave");
    this.saveAction.SetWidth(864.0);
    this.trashAction = this.AddAction(root, "MOVE PRESET TO TRASH", 34.0, 1318.0, n"OnMoveToTrash");
    this.trashAction.SetWidth(864.0);
    this.trashAction.SetStyle(2);
    this.SetRootWidget(root);
    return true;
  }

  protected cb func OnInitialize() -> Bool {
    this.RegisterToGlobalInputCallback(n"OnPostOnRelease", this, n"OnGlobalRelease");
    if IsDefined(this.bridge) {
      this.bridge.RegisterPanel(this);
      if this.bridge.IsLuaReady() { this.bridge.Request("list", ""); }
      else { this.statusText.SetText("The Lua preset library is not ready. Use the CET interface instead."); };
    };
    return true;
  }
  protected cb func OnUninitialize() -> Bool {
    this.UnregisterFromGlobalInputCallback(n"OnPostOnRelease", this, n"OnGlobalRelease");
    if IsDefined(this.bridge) { this.bridge.UnregisterPanel(this); };
    return true;
  }

  private func MakeText(text: String, size: Int32, x: Float, y: Float, width: Float, height: Float) -> ref<inkText> {
    let widget: ref<inkText> = new inkText();
    widget.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    widget.SetFontStyle(n"Medium");
    widget.SetFontSize(size);
    widget.SetText(text);
    widget.SetMargin(new inkMargin(x, y, 0.0, 0.0));
    widget.SetSize(width, height);
    widget.SetTintColor(HDRColor(0.882353, 0.913725, 0.901961, 1.0));
    return widget;
  }
  private func AddAction(parent: ref<inkCanvas>, text: String, x: Float, y: Float, callback: CName) -> ref<PanelButton> {
    let button: ref<PanelButton> = PanelButton.Create(text);
    button.SetPosition(x, y);
    button.SetWidth(270.0);
    button.SetStyle(1);
    button.RegisterToCallback(n"OnBtnClick", this, callback);
    button.Reparent(parent, this.GetGameController());
    ArrayPush(this.actionButtons, button);
    return button;
  }

  protected cb func OnSearchChanged(widget: wref<inkWidget>) -> Bool {
    this.scrollOffset = 0;
    this.bridge.Request("list", this.search.GetText());
    return true;
  }
  protected cb func OnListClick(target: wref<inkWidget>) -> Bool {
    let index: Int32 = 0;
    while index < ArraySize(this.listButtons) {
      if this.listButtons[index].GetRootWidget() == target {
        let absolute: Int32 = this.scrollOffset + index;
        if absolute < ArraySize(this.rowKinds) {
          if Equals(this.rowKinds[absolute], "FOLDER") {
            this.bridge.Request("toggle_folder", this.rowValues[absolute]);
          } else {
            if Equals(this.rowKinds[absolute], "PRESET") {
              this.trashAction.SetText("MOVE PRESET TO TRASH");
              this.selectedName = this.rowValues[absolute];
              this.statusText.SetText(this.selectedName + " selected. Loading started.");
              this.UpdateRows();
              this.bridge.Request("select_load", this.selectedName);
            };
          };
        };
        return true;
      };
      index += 1;
    };
    return false;
  }
  protected cb func OnSave(widget: wref<inkWidget>) -> Bool { this.bridge.Request("save", this.presetName.GetText()); return true; }
  protected cb func OnPresetNameChanged(widget: wref<inkWidget>) -> Bool {
    this.saveAction.SetText("SAVE PRESET");
    this.bridge.Request("cancel_save_confirmation", "");
    return true;
  }
  protected cb func OnMoveToTrash(widget: wref<inkWidget>) -> Bool { this.bridge.Request("delete", ""); return true; }
  protected cb func OnSaveLocation(widget: wref<inkWidget>) -> Bool {
    let count: Int32 = ArraySize(this.saveLocations);
    if count == 0 { return true; };
    let current: Int32 = 0;
    let index: Int32 = 0;
    while index < count {
      if Equals(this.saveLocations[index], this.selectedSaveLocation) { current = index; };
      index += 1;
    };
    current = (current + 1) % count;
    this.selectedSaveLocation = this.saveLocations[current];
    this.saveAction.SetText("SAVE PRESET");
    this.trashAction.SetText("MOVE PRESET TO TRASH");
    this.UpdateSaveLocation();
    this.bridge.Request("save_location", this.selectedSaveLocation);
    return true;
  }

  protected cb func OnPanelScroll(evt: ref<inkPointerEvent>) -> Bool {
    if (evt.IsAction(n"mouse_wheel") || evt.IsAction(n"right_stick_y"))
        && evt.GetAxisData() != 0.0 {
      this.ScrollBy(evt.GetAxisData() > 0.0 ? -3 : 3);
      return true;
    };
    return false;
  }
  protected cb func OnGlobalRelease(evt: ref<inkPointerEvent>) -> Bool {
    if !this.IsPanelWidget(evt.GetTarget()) { return false; };
    if evt.IsAction(n"navigate_down") {
      this.ScrollBy(1);
      evt.Handle();
      return true;
    };
    if evt.IsAction(n"navigate_up") {
      this.ScrollBy(-1);
      evt.Handle();
      return true;
    };
    return false;
  }
  private func IsPanelWidget(widget: wref<inkWidget>) -> Bool {
    while IsDefined(widget) {
      if widget == this.GetRootWidget() { return true; };
      widget = widget.GetParentWidget();
    };
    return false;
  }
  private func ScrollBy(amount: Int32) -> Void {
    let maximum: Int32 = Max(0, ArraySize(this.rowKinds) - 9);
    this.scrollOffset = Max(0, Min(maximum, this.scrollOffset + amount));
    this.UpdateRows();
  }

  public func OnBusyChanged(isBusy: Bool, message: String) -> Void {
    this.busy = isBusy;
    let index: Int32 = 0;
    while index < ArraySize(this.actionButtons) {
      this.actionButtons[index].SetDisabled(isBusy);
      index += 1;
    };
    index = 0;
    while index < ArraySize(this.listButtons) {
      this.listButtons[index].SetDisabled(isBusy || this.scrollOffset + index >= ArraySize(this.rowKinds));
      index += 1;
    };
    if StrLen(message) > 0 { this.statusText.SetText(message); };
  }
  public func OnBridgeResponse(kind: String, payload: String, isBusy: Bool) -> Void {
    this.OnBusyChanged(isBusy, "");
    if Equals(kind, "list") { this.ReadPresetList(payload); return; };
    if Equals(kind, "confirm_state") {
      if Equals(payload, "SAVE\t0") { this.saveAction.SetText("SAVE PRESET"); };
      return;
    };
    this.statusText.SetText(payload);
  }
  private func ReadPresetList(payload: String) -> Void {
    ArrayClear(this.rowKinds);
    ArrayClear(this.rowValues);
    ArrayClear(this.rowLabels);
    ArrayClear(this.saveLocations);
    let lines: array<String> = StrSplit(payload, "\n", false);
    let index: Int32 = 0;
    while index < ArraySize(lines) {
      let fields: array<String> = StrSplit(lines[index], "\t", true);
      if ArraySize(fields) > 3 && Equals(fields[0], "ROW") {
        ArrayPush(this.rowKinds, fields[1]);
        ArrayPush(this.rowValues, fields[2]);
        ArrayPush(this.rowLabels, fields[3]);
      };
      if ArraySize(fields) > 2 && Equals(fields[0], "LOCATION") {
        ArrayPush(this.saveLocations, fields[1]);
        if Equals(fields[2], "1") { this.selectedSaveLocation = fields[1]; };
      };
      if ArraySize(fields) > 2 && Equals(fields[0], "STATUS") { this.statusText.SetText(fields[2]); };
      if ArraySize(fields) > 2 && Equals(fields[0], "CONFIRM") {
        if Equals(fields[1], "SAVE") { this.saveAction.SetText(Equals(fields[2], "1") ? "CONFIRM OVERWRITE" : "SAVE PRESET"); };
        if Equals(fields[1], "TRASH") { this.trashAction.SetText(Equals(fields[2], "1") ? "CONFIRM MOVE TO TRASH" : "MOVE PRESET TO TRASH"); };
      };
      if ArraySize(fields) > 5 && Equals(fields[0], "SELECTED") {
        this.selectedName = fields[1];
      };
      index += 1;
    };
    this.UpdateSaveLocation();
    this.ScrollBy(0);
  }
  private func UpdateSaveLocation() -> Void {
    let label: String = StrLen(this.selectedSaveLocation) > 0 ? this.selectedSaveLocation : "ALL PRESETS";
    this.locationButton.SetText("SAVE LOCATION: " + (StrLen(label) > 48 ? StrLeft(label, 45) + "..." : label));
  }
  private func UpdateRows() -> Void {
    let count: Int32 = ArraySize(this.rowKinds);
    let maximum: Int32 = Max(0, count - 9);
    if this.scrollOffset > maximum { this.scrollOffset = maximum; };
    let thumbHeight: Float = count > 9 ? MaxF(44.0, 666.0 * 9.0 / Cast<Float>(count)) : 666.0;
    let thumbOffset: Float = maximum > 0 ? (666.0 - thumbHeight) * Cast<Float>(this.scrollOffset) / Cast<Float>(maximum) : 0.0;
    this.scrollThumb.SetSize(7.0, thumbHeight);
    this.scrollThumb.SetMargin(new inkMargin(912.0, 306.0 + thumbOffset, 0.0, 0.0));
    let index: Int32 = 0;
    while index < ArraySize(this.listButtons) {
      let absolute: Int32 = this.scrollOffset + index;
      let visible: Bool = absolute < count;
      this.listButtons[index].GetRootWidget().SetVisible(visible);
      this.listButtons[index].SetDisabled(this.busy || !visible);
      if visible {
        let label: String = this.rowLabels[absolute];
        let kind: String = this.rowKinds[absolute];
        this.listButtons[index].SetText(StrLen(label) > 50 ? StrLeft(label, 47) + "..." : label);
        this.listButtons[index].SetStyle(Equals(kind, "FOLDER") || Equals(kind, "HEADING") ? 3 : 0);
        this.listButtons[index].SetSelected(Equals(kind, "PRESET") && Equals(this.rowValues[absolute], this.selectedName));
      };
      index += 1;
    };
  }

  public static func Create(bridge: ref<NativeBridge>) -> ref<PresetPanel> {
    let panel: ref<PresetPanel> = new PresetPanel();
    panel.bridge = bridge;
    panel.CreateInstance();
    return panel;
  }
  public func Detach() -> Void {
    if IsDefined(this.bridge) { this.bridge.UnregisterPanel(this); };
    let root: ref<inkWidget> = this.GetRootWidget();
    let parent: ref<inkCompoundWidget> = root.GetParentWidget() as inkCompoundWidget;
    if IsDefined(parent) { parent.RemoveChild(root); };
  }
}

@addField(characterCreationBodyMorphMenu)
private let cpmPresetPanel: ref<PresetPanel>;

@wrapMethod(characterCreationBodyMorphMenu)
protected cb func OnInitialize() -> Bool {
  wrappedMethod();
  inkWidgetRef.SetTranslation(this.m_randomizeGroup, new Vector2(0.0, 700.0));
  let player: wref<GameObject> = this.GetPlayerControlledObject();
  if IsDefined(player) {
    let bridge: ref<NativeBridge> = GameInstance.GetScriptableSystemsContainer(player.GetGame()).Get(n"CPM.NativeBridge") as NativeBridge;
    if IsDefined(bridge) && bridge.IsLuaReady() {
      this.cpmPresetPanel = PresetPanel.Create(bridge);
      this.cpmPresetPanel.Reparent(this.GetRootCompoundWidget(), this);
      inkWidgetRef.SetVisible(this.m_presetsLabel, false);
      inkWidgetRef.SetVisible(this.m_preset1, false);
      inkWidgetRef.SetVisible(this.m_preset2, false);
      inkWidgetRef.SetVisible(this.m_preset3, false);
      inkWidgetRef.SetVisible(this.m_preset1Group, false);
      inkWidgetRef.SetVisible(this.m_preset2Group, false);
      inkWidgetRef.SetVisible(this.m_preset3Group, false);
      inkWidgetRef.SetInteractive(this.m_preset1, false);
      inkWidgetRef.SetInteractive(this.m_preset2, false);
      inkWidgetRef.SetInteractive(this.m_preset3, false);
    };
  };
}

@wrapMethod(characterCreationBodyMorphMenu)
protected cb func OnUninitialize() -> Bool {
  if IsDefined(this.cpmPresetPanel) {
    this.cpmPresetPanel.Detach();
    this.cpmPresetPanel = null;
  };
  wrappedMethod();
}
