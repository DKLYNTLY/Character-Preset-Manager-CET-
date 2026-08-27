module CPM
import Codeware.UI.*

public class PanelButton extends CustomButton {
  protected let frame: wref<inkRectangle>;
  protected let fill: wref<inkRectangle>;

  protected func CreateWidgets() -> Void {
    let root: ref<inkCanvas> = new inkCanvas();
    root.SetSize(270.0, 52.0);
    root.SetInteractive(true);
    root.SetSupportFocus(true);
    let fill: ref<inkRectangle> = new inkRectangle();
    fill.SetAnchor(inkEAnchor.Fill);
    fill.SetTintColor(HDRColor(0.062745, 0.098039, 0.125490, 0.921569));
    fill.Reparent(root);
    let frame: ref<inkRectangle> = new inkRectangle();
    frame.SetAnchor(inkEAnchor.Fill);
    frame.SetTintColor(HDRColor(0.439216, 0.690196, 0.721569, 1.0));
    frame.SetOpacity(0.22);
    frame.Reparent(root);
    let label: ref<inkText> = new inkText();
    label.SetAnchor(inkEAnchor.Fill);
    label.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    label.SetFontStyle(n"Semi-Bold");
    label.SetFontSize(24);
    label.SetLetterCase(textLetterCase.UpperCase);
    label.SetHorizontalAlignment(textHorizontalAlignment.Center);
    label.SetVerticalAlignment(textVerticalAlignment.Center);
    label.SetTintColor(HDRColor(0.854902, 0.921569, 0.909804, 1.0));
    label.SetText("BUTTON");
    label.Reparent(root);
    this.m_root = root;
    this.m_label = label;
    this.frame = frame;
    this.fill = fill;
    this.SetRootWidget(root);
  }

  protected func ApplyDisabledState() -> Void { this.m_root.SetOpacity(this.m_isDisabled ? 0.32 : 1.0); }
  protected func ApplyHoveredState() -> Void { this.frame.SetOpacity(this.m_isHovered && !this.m_isDisabled ? 0.90 : 0.22); }
  protected func ApplyPressedState() -> Void {
    this.fill.SetTintColor(this.m_isPressed ? HDRColor(0.372549, 0.078431, 0.113725, 0.960784) : HDRColor(0.062745, 0.098039, 0.125490, 0.921569));
  }
  public func SetSelected(selected: Bool) -> Void {
    this.frame.SetTintColor(selected ? HDRColor(1.0, 0.301961, 0.368627, 1.0) : HDRColor(0.439216, 0.690196, 0.721569, 1.0));
    this.frame.SetOpacity(selected ? 0.82 : 0.22);
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
  private let statusText: wref<inkText>;
  private let detailsText: wref<inkText>;
  private let scrollThumb: wref<inkRectangle>;
  private let loadTab: ref<PanelButton>;
  private let saveTab: ref<PanelButton>;
  private let deleteTab: ref<PanelButton>;
  private let loadAction: ref<PanelButton>;
  private let restoreAction: ref<PanelButton>;
  private let saveAction: ref<PanelButton>;
  private let replaceAction: ref<PanelButton>;
  private let deleteAction: ref<PanelButton>;
  private let listButtons: array<ref<PanelButton>>;
  private let actionButtons: array<ref<PanelButton>>;
  private let presetNames: array<String>;
  private let selectedName: String;
  private let scrollOffset: Int32;
  private let mode: Int32;
  private let busy: Bool;

  protected cb func OnCreate() -> Bool {
    let root: ref<inkCanvas> = new inkCanvas();
    root.SetName(n"CharacterPresetManagerPanel");
    root.SetAnchor(inkEAnchor.TopRight);
    root.SetAnchorPoint(new Vector2(1.0, 0.0));
    root.SetMargin(new inkMargin(0.0, 54.0, 38.0, 0.0));
    root.SetSize(620.0, 1170.0);
    root.SetInteractive(true);
    root.SetSupportFocus(true);
    let background: ref<inkRectangle> = new inkRectangle();
    background.SetAnchor(inkEAnchor.Fill);
    background.SetTintColor(HDRColor(0.019608, 0.039216, 0.054902, 0.956863));
    background.Reparent(root);
    let rail: ref<inkRectangle> = new inkRectangle();
    rail.SetSize(7.0, 1170.0);
    rail.SetTintColor(HDRColor(0.909804, 0.196078, 0.262745, 1.0));
    rail.Reparent(root);
    let title: ref<inkText> = this.MakeText("CHARACTER PRESET MANAGER", 32, 26.0, 20.0, 560.0, 48.0);
    title.SetTintColor(HDRColor(0.909804, 0.266667, 0.321569, 1.0));
    title.Reparent(root);
    let subtitle: ref<inkText> = this.MakeText("PRESETS AVAILABLE DURING CHARACTER CUSTOMIZATION", 18, 28.0, 62.0, 560.0, 32.0);
    subtitle.SetTintColor(HDRColor(0.517647, 0.709804, 0.729412, 1.0));
    subtitle.Reparent(root);

    this.loadTab = this.AddAction(root, "LOAD", 28.0, 104.0, n"OnLoadTab");
    this.loadTab.SetWidth(178.0);
    this.saveTab = this.AddAction(root, "SAVE", 220.0, 104.0, n"OnSaveTab");
    this.saveTab.SetWidth(178.0);
    this.deleteTab = this.AddAction(root, "DELETE", 412.0, 104.0, n"OnDeleteTab");
    this.deleteTab.SetWidth(178.0);

    this.search = HubTextInput.Create();
    this.search.SetName(n"PresetSearch");
    this.search.SetWidth(562.0);
    this.search.SetMaxLength(64);
    this.search.GetRootWidget().SetMargin(new inkMargin(28.0, 174.0, 0.0, 0.0));
    this.search.RegisterToCallback(n"OnInput", this, n"OnSearchChanged");
    this.search.Reparent(root, this.GetGameController());
    this.statusText = this.MakeText("Connecting to the CET preset library...", 20, 28.0, 244.0, 562.0, 64.0);
    this.statusText.SetWrapping(true, 550.0);
    this.statusText.Reparent(root);

    let index: Int32 = 0;
    while index < 10 {
      let listButton: ref<PanelButton> = PanelButton.Create("");
      listButton.SetPosition(28.0, 322.0 + Cast<Float>(index) * 58.0);
      listButton.SetWidth(562.0);
      listButton.RegisterToCallback(n"OnBtnClick", this, n"OnListClick");
      listButton.Reparent(root, this.GetGameController());
      ArrayPush(this.listButtons, listButton);
      index += 1;
    };
    let scrollTrack: ref<inkRectangle> = new inkRectangle();
    scrollTrack.SetSize(4.0, 574.0);
    scrollTrack.SetMargin(new inkMargin(602.0, 322.0, 0.0, 0.0));
    scrollTrack.SetTintColor(HDRColor(0.215686, 0.305882, 0.321569, 0.823529));
    scrollTrack.Reparent(root);
    this.scrollThumb = new inkRectangle();
    this.scrollThumb.SetSize(4.0, 574.0);
    this.scrollThumb.SetMargin(new inkMargin(602.0, 322.0, 0.0, 0.0));
    this.scrollThumb.SetTintColor(HDRColor(0.909804, 0.266667, 0.321569, 1.0));
    this.scrollThumb.Reparent(root);
    this.detailsText = this.MakeText("Select a preset to see its saved details.", 19, 28.0, 916.0, 562.0, 76.0);
    this.detailsText.SetWrapping(true, 550.0);
    this.detailsText.SetTintColor(HDRColor(0.745098, 0.823529, 0.811765, 1.0));
    this.detailsText.Reparent(root);
    this.loadAction = this.AddAction(root, "LOAD PRESET", 28.0, 1008.0, n"OnLoad");
    this.restoreAction = this.AddAction(root, "RESTORE PRESET", 320.0, 1008.0, n"OnRestore");
    this.saveAction = this.AddAction(root, "SAVE NEW PRESET", 28.0, 1008.0, n"OnSave");
    this.replaceAction = this.AddAction(root, "REPLACE SELECTED", 320.0, 1008.0, n"OnReplace");
    this.deleteAction = this.AddAction(root, "DELETE SELECTED / CONFIRM", 28.0, 1008.0, n"OnDelete");
    this.deleteAction.SetWidth(562.0);
    this.SetRootWidget(root);
    return true;
  }

  protected cb func OnInitialize() -> Bool {
    this.RegisterToGlobalInputCallback(n"OnPostOnRelease", this, n"OnGlobalRelease");
    this.RegisterToGlobalInputCallback(n"OnPostOnRelative", this, n"OnGlobalRelative");
    this.ApplyMode();
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
    button.RegisterToCallback(n"OnBtnClick", this, callback);
    button.Reparent(parent, this.GetGameController());
    ArrayPush(this.actionButtons, button);
    return button;
  }

  protected cb func OnLoadTab(widget: wref<inkWidget>) -> Bool { this.SetMode(0); return true; }
  protected cb func OnSaveTab(widget: wref<inkWidget>) -> Bool { this.SetMode(1); return true; }
  protected cb func OnDeleteTab(widget: wref<inkWidget>) -> Bool { this.SetMode(2); return true; }
  private func SetMode(value: Int32) -> Void {
    if this.busy { return; };
    this.mode = value;
    this.scrollOffset = 0;
    this.ApplyMode();
    this.bridge.Request("list", value == 1 ? "" : this.search.GetText());
  }
  private func ApplyMode() -> Void {
    this.loadTab.SetSelected(this.mode == 0);
    this.saveTab.SetSelected(this.mode == 1);
    this.deleteTab.SetSelected(this.mode == 2);
    this.loadAction.GetRootWidget().SetVisible(this.mode == 0);
    this.restoreAction.GetRootWidget().SetVisible(this.mode == 0);
    this.saveAction.GetRootWidget().SetVisible(this.mode == 1);
    this.replaceAction.GetRootWidget().SetVisible(this.mode == 1);
    this.deleteAction.GetRootWidget().SetVisible(this.mode == 2);
    if this.mode == 0 { this.statusText.SetText("Select a preset to load it. Restore Preset returns to the appearance from before the last load."); }
    else {
      if this.mode == 1 { this.statusText.SetText("Enter a name to save a new preset, or select a preset to replace it."); }
      else { this.statusText.SetText("Select a preset, then select Delete Selected twice to move it to Trash."); };
    };
  }

  protected cb func OnSearchChanged(widget: wref<inkWidget>) -> Bool {
    if this.mode != 1 {
      this.scrollOffset = 0;
      this.bridge.Request("list", this.search.GetText());
    };
    return true;
  }
  protected cb func OnListClick(target: wref<inkWidget>) -> Bool {
    let index: Int32 = 0;
    while index < ArraySize(this.listButtons) {
      if this.listButtons[index].GetRootWidget() == target {
        let absolute: Int32 = this.scrollOffset + index;
        if absolute < ArraySize(this.presetNames) {
          this.selectedName = this.presetNames[absolute];
          this.detailsText.SetText(this.selectedName + " selected.");
          this.UpdateRows();
          this.bridge.Request(this.mode == 0 ? "select_load" : "select", this.selectedName);
        };
        return true;
      };
      index += 1;
    };
    return false;
  }
  protected cb func OnSave(widget: wref<inkWidget>) -> Bool { this.bridge.Request("save", this.search.GetText()); return true; }
  protected cb func OnReplace(widget: wref<inkWidget>) -> Bool { this.bridge.Request("replace", ""); return true; }
  protected cb func OnLoad(widget: wref<inkWidget>) -> Bool { this.bridge.Request("load", ""); return true; }
  protected cb func OnRestore(widget: wref<inkWidget>) -> Bool { this.bridge.Request("restore_previous", ""); return true; }
  protected cb func OnDelete(widget: wref<inkWidget>) -> Bool { this.bridge.Request("delete", ""); return true; }

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
    let maximum: Int32 = Max(0, ArraySize(this.presetNames) - 10);
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
    let lines: array<String> = StrSplit(payload, "\n", false);
    let index: Int32 = 0;
    while index < ArraySize(lines) {
      let fields: array<String> = StrSplit(lines[index], "\t", true);
      if ArraySize(fields) > 1 && Equals(fields[0], "PRESET") { ArrayPush(this.presetNames, fields[1]); };
      if ArraySize(fields) > 2 && Equals(fields[0], "STATUS") { this.statusText.SetText(fields[2]); };
      if ArraySize(fields) > 5 && Equals(fields[0], "SELECTED") {
        this.selectedName = fields[1];
        this.detailsText.SetText(StrLen(fields[1]) > 0 ? fields[1] + " | " + fields[4] + " saved options\nTags: " + fields[3] + "\n" + fields[2] : "Select a preset to see its saved details.");
      };
      index += 1;
    };
    this.ScrollBy(0);
  }
  private func UpdateRows() -> Void {
    let count: Int32 = ArraySize(this.presetNames);
    let maximum: Int32 = Max(0, count - 10);
    if this.scrollOffset > maximum { this.scrollOffset = maximum; };
    let thumbHeight: Float = count > 10 ? MaxF(34.0, 574.0 * 10.0 / Cast<Float>(count)) : 574.0;
    let thumbOffset: Float = maximum > 0 ? (574.0 - thumbHeight) * Cast<Float>(this.scrollOffset) / Cast<Float>(maximum) : 0.0;
    this.scrollThumb.SetSize(4.0, thumbHeight);
    this.scrollThumb.SetMargin(new inkMargin(602.0, 322.0 + thumbOffset, 0.0, 0.0));
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
