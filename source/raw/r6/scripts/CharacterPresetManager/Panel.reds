module CPM
import Codeware.UI.*

public class PanelButton extends CustomButton {
  protected let frame: wref<inkRectangle>;
  protected let fill: wref<inkRectangle>;
  protected let style: Int32;

  protected func CreateWidgets() -> Void {
    let root: ref<inkCanvas> = new inkCanvas();
    root.SetSize(270.0, 52.0);
    root.SetInteractive(true);
    root.SetSupportFocus(true);
    let fill: ref<inkRectangle> = new inkRectangle();
    fill.SetAnchor(inkEAnchor.Fill);
    fill.SetTintColor(HDRColor(0.13, 0.14, 0.17, 1.0));
    fill.Reparent(root);
    let frame: ref<inkRectangle> = new inkRectangle();
    frame.SetAnchor(inkEAnchor.Fill);
    frame.SetTintColor(HDRColor(0.95, 0.72, 0.20, 1.0));
    frame.SetOpacity(0.55);
    frame.Reparent(root);
    let label: ref<inkText> = new inkText();
    label.SetAnchor(inkEAnchor.Fill);
    label.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    label.SetFontStyle(n"Semi-Bold");
    label.SetFontSize(24);
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
  protected func ApplyHoveredState() -> Void { this.frame.SetOpacity(this.m_isHovered && !this.m_isDisabled ? 0.90 : 0.55); }
  protected func ApplyPressedState() -> Void {
    if this.style == 2 {
      this.fill.SetTintColor(this.m_isPressed ? HDRColor(0.48, 0.11, 0.09, 1.0) : HDRColor(0.62, 0.16, 0.13, 0.92));
    } else {
      if this.style == 1 {
        this.fill.SetTintColor(this.m_isPressed ? HDRColor(0.36, 0.19, 0.03, 1.0) : HDRColor(0.72, 0.42, 0.08, 0.92));
      } else {
        this.fill.SetTintColor(this.m_isPressed ? HDRColor(0.22, 0.23, 0.28, 1.0) : HDRColor(0.13, 0.14, 0.17, 1.0));
      };
    };
  }
  public func SetSelected(selected: Bool) -> Void {
    this.frame.SetTintColor(selected ? HDRColor(0.97, 0.72, 0.20, 1.0) : HDRColor(0.95, 0.72, 0.20, 1.0));
    this.frame.SetOpacity(selected ? 1.0 : 0.55);
  }
  public func SetStyle(value: Int32) -> Void {
    this.style = value;
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
  private let confirmTrashAction: ref<PanelButton>;
  private let listButtons: array<ref<PanelButton>>;
  private let actionButtons: array<ref<PanelButton>>;
  private let presetNames: array<String>;
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
    root.SetMargin(new inkMargin(600.0, 300.0, 0.0, 0.0));
    root.SetSize(760.0, 1220.0);
    root.SetInteractive(true);
    root.SetSupportFocus(true);
    let background: ref<inkRectangle> = new inkRectangle();
    background.SetAnchor(inkEAnchor.Fill);
    background.SetTintColor(HDRColor(0.055, 0.059, 0.078, 0.98));
    background.Reparent(root);
    let rail: ref<inkRectangle> = new inkRectangle();
    rail.SetSize(7.0, 1220.0);
    rail.SetTintColor(HDRColor(0.95, 0.72, 0.20, 1.0));
    rail.Reparent(root);
    let title: ref<inkText> = this.MakeText("CHARACTER PRESET MANAGER", 34, 28.0, 20.0, 700.0, 48.0);
    title.SetTintColor(HDRColor(0.97, 0.72, 0.20, 1.0));
    title.Reparent(root);
    let subtitle: ref<inkText> = this.MakeText("PRESETS AVAILABLE DURING CHARACTER CUSTOMIZATION", 19, 28.0, 64.0, 700.0, 32.0);
    subtitle.SetTintColor(HDRColor(0.64, 0.67, 0.73, 1.0));
    subtitle.Reparent(root);

    let advancedText: ref<inkText> = this.MakeText("For rename, permanent delete, Help, compatibility checks, Favorites, folders, backups, and Trash recovery, open the CET menu.", 19, 28.0, 104.0, 700.0, 76.0);
    advancedText.SetWrapping(true, 690.0);
    advancedText.SetTintColor(HDRColor(1.0, 1.0, 1.0, 1.0));
    advancedText.Reparent(root);

    this.search = HubTextInput.Create();
    this.search.SetName(n"PresetSearch");
    this.search.SetDefaultText("SEARCH");
    this.search.SetWidth(700.0);
    this.search.SetMaxLength(64);
    this.search.GetRootWidget().SetMargin(new inkMargin(28.0, 194.0, 0.0, 0.0));
    this.search.RegisterToCallback(n"OnInput", this, n"OnSearchChanged");
    this.search.Reparent(root, this.GetGameController());
    let index: Int32 = 0;
    while index < 9 {
      let listButton: ref<PanelButton> = PanelButton.Create("");
      listButton.SetPosition(28.0, 264.0 + Cast<Float>(index) * 58.0);
      listButton.SetWidth(700.0);
      listButton.RegisterToCallback(n"OnBtnClick", this, n"OnListClick");
      listButton.Reparent(root, this.GetGameController());
      ArrayPush(this.listButtons, listButton);
      index += 1;
    };
    let scrollTrack: ref<inkRectangle> = new inkRectangle();
    scrollTrack.SetSize(4.0, 516.0);
    scrollTrack.SetMargin(new inkMargin(742.0, 264.0, 0.0, 0.0));
    scrollTrack.SetTintColor(HDRColor(0.30, 0.28, 0.22, 0.9));
    scrollTrack.Reparent(root);
    this.scrollThumb = new inkRectangle();
    this.scrollThumb.SetSize(4.0, 516.0);
    this.scrollThumb.SetMargin(new inkMargin(742.0, 264.0, 0.0, 0.0));
    this.scrollThumb.SetTintColor(HDRColor(0.97, 0.72, 0.20, 1.0));
    this.scrollThumb.Reparent(root);
    this.statusText = this.MakeText("Select a preset to load it.", 20, 28.0, 802.0, 700.0, 70.0);
    this.statusText.SetWrapping(true, 690.0);
    this.statusText.SetTintColor(HDRColor(1.0, 1.0, 1.0, 1.0));
    this.statusText.Reparent(root);
    this.presetName = HubTextInput.Create();
    this.presetName.SetName(n"PresetName");
    this.presetName.SetDefaultText("PRESET NAME");
    this.presetName.SetWidth(700.0);
    this.presetName.SetMaxLength(64);
    this.presetName.GetRootWidget().SetMargin(new inkMargin(28.0, 884.0, 0.0, 0.0));
    this.presetName.Reparent(root, this.GetGameController());
    this.locationButton = this.AddAction(root, "SAVE LOCATION: ALL PRESETS", 28.0, 954.0, n"OnSaveLocation");
    this.locationButton.SetWidth(700.0);
    this.saveAction = this.AddAction(root, "SAVE PRESET / CONFIRM REPLACE", 28.0, 1014.0, n"OnSave");
    this.saveAction.SetWidth(700.0);
    this.trashAction = this.AddAction(root, "MOVE PRESET TO TRASH", 28.0, 1094.0, n"OnMoveToTrash");
    this.trashAction.SetWidth(340.0);
    this.trashAction.SetStyle(2);
    this.confirmTrashAction = this.AddAction(root, "CONFIRM", 388.0, 1094.0, n"OnConfirmTrash");
    this.confirmTrashAction.SetWidth(340.0);
    this.confirmTrashAction.SetStyle(2);
    this.SetRootWidget(root);
    return true;
  }

  protected cb func OnInitialize() -> Bool {
    this.RegisterToGlobalInputCallback(n"OnPostOnRelease", this, n"OnGlobalRelease");
    this.RegisterToGlobalInputCallback(n"OnPostOnRelative", this, n"OnGlobalRelative");
    if IsDefined(this.bridge) {
      this.bridge.RegisterPanel(this);
      if this.bridge.IsLuaReady() { this.bridge.Request("list", ""); }
      else { this.statusText.SetText("The Lua preset library is not ready. Use the CET interface instead."); };
    };
    return true;
  }
  protected cb func OnUninitialize() -> Bool {
    this.UnregisterFromGlobalInputCallback(n"OnPostOnRelease", this, n"OnGlobalRelease");
    this.UnregisterFromGlobalInputCallback(n"OnPostOnRelative", this, n"OnGlobalRelative");
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
        if absolute < ArraySize(this.presetNames) {
          this.selectedName = this.presetNames[absolute];
          this.statusText.SetText(this.selectedName + " selected. Loading started.");
          this.UpdateRows();
          this.bridge.Request("select_load", this.selectedName);
        };
        return true;
      };
      index += 1;
    };
    return false;
  }
  protected cb func OnSave(widget: wref<inkWidget>) -> Bool { this.bridge.Request("save", this.presetName.GetText()); return true; }
  protected cb func OnMoveToTrash(widget: wref<inkWidget>) -> Bool { this.bridge.Request("delete_prepare", ""); return true; }
  protected cb func OnConfirmTrash(widget: wref<inkWidget>) -> Bool { this.bridge.Request("delete_confirm", ""); return true; }
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
    this.UpdateSaveLocation();
    this.bridge.Request("save_location", this.selectedSaveLocation);
    return true;
  }

  protected cb func OnGlobalRelative(evt: ref<inkPointerEvent>) -> Bool {
    if evt.IsAction(n"mouse_wheel") && this.IsPanelWidget(evt.GetTarget()) {
      this.ScrollBy(evt.GetAxisData() > 0.0 ? -1 : 1);
      evt.Handle();
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
    let maximum: Int32 = Max(0, ArraySize(this.presetNames) - 9);
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
      this.listButtons[index].SetDisabled(isBusy || this.scrollOffset + index >= ArraySize(this.presetNames));
      index += 1;
    };
    if StrLen(message) > 0 { this.statusText.SetText(message); };
  }
  public func OnBridgeResponse(kind: String, payload: String, isBusy: Bool) -> Void {
    this.OnBusyChanged(isBusy, "");
    if Equals(kind, "list") { this.ReadPresetList(payload); return; };
    this.statusText.SetText(payload);
  }
  private func ReadPresetList(payload: String) -> Void {
    ArrayClear(this.presetNames);
    ArrayClear(this.saveLocations);
    let lines: array<String> = StrSplit(payload, "\n", false);
    let index: Int32 = 0;
    while index < ArraySize(lines) {
      let fields: array<String> = StrSplit(lines[index], "\t", true);
      if ArraySize(fields) > 1 && Equals(fields[0], "PRESET") { ArrayPush(this.presetNames, fields[1]); };
      if ArraySize(fields) > 2 && Equals(fields[0], "LOCATION") {
        ArrayPush(this.saveLocations, fields[1]);
        if Equals(fields[2], "1") { this.selectedSaveLocation = fields[1]; };
      };
      if ArraySize(fields) > 2 && Equals(fields[0], "STATUS") { this.statusText.SetText(fields[2]); };
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
    let count: Int32 = ArraySize(this.presetNames);
    let maximum: Int32 = Max(0, count - 9);
    if this.scrollOffset > maximum { this.scrollOffset = maximum; };
    let thumbHeight: Float = count > 9 ? MaxF(34.0, 516.0 * 9.0 / Cast<Float>(count)) : 516.0;
    let thumbOffset: Float = maximum > 0 ? (516.0 - thumbHeight) * Cast<Float>(this.scrollOffset) / Cast<Float>(maximum) : 0.0;
    this.scrollThumb.SetSize(4.0, thumbHeight);
    this.scrollThumb.SetMargin(new inkMargin(742.0, 264.0 + thumbOffset, 0.0, 0.0));
    let index: Int32 = 0;
    while index < ArraySize(this.listButtons) {
      let absolute: Int32 = this.scrollOffset + index;
      let visible: Bool = absolute < count;
      this.listButtons[index].GetRootWidget().SetVisible(visible);
      this.listButtons[index].SetDisabled(this.busy || !visible);
      if visible {
        let label: String = this.presetNames[absolute];
        this.listButtons[index].SetText(StrLen(label) > 54 ? StrLeft(label, 51) + "..." : label);
        this.listButtons[index].SetSelected(Equals(label, this.selectedName));
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
