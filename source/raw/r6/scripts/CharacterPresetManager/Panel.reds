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
    fill.SetTintColor(HDRColor(0.018, 0.022, 0.028, 1.0));
    fill.SetOpacity(0.48);
    fill.Reparent(root);
    let frame: ref<inkRectangle> = new inkRectangle();
    frame.SetAnchor(inkEAnchor.Fill);
    frame.SetTintColor(HDRColor(0.05, 0.06, 0.07, 1.0));
    frame.SetOpacity(0.16);
    frame.Reparent(root);
    let label: ref<inkText> = new inkText();
    label.SetAnchor(inkEAnchor.Fill);
    label.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    label.SetFontStyle(n"Semi-Bold");
    label.SetFontSize(34);
    label.SetLetterCase(textLetterCase.UpperCase);
    label.SetHorizontalAlignment(textHorizontalAlignment.Center);
    label.SetVerticalAlignment(textVerticalAlignment.Center);
    label.SetTintColor(HDRColor(1.0, 0.24, 0.22, 1.0));
    label.SetText("BUTTON");
    label.Reparent(root);
    this.m_root = root;
    this.m_label = label;
    this.frame = frame;
    this.fill = fill;
    this.SetRootWidget(root);
  }

  protected func ApplyDisabledState() -> Void { this.m_root.SetOpacity(this.m_isDisabled ? 0.32 : 1.0); }
  protected func ApplyHoveredState() -> Void { this.frame.SetOpacity(this.m_isHovered && !this.m_isDisabled ? 0.34 : (this.selected ? 0.28 : 0.16)); }
  protected func ApplyPressedState() -> Void {
    if this.selected {
      this.fill.SetTintColor(HDRColor(0.012, 0.07, 0.08, 1.0));
    } else {
      if this.style == 2 {
        this.fill.SetTintColor(this.m_isPressed ? HDRColor(0.11, 0.12, 0.14, 1.0) : HDRColor(0.025, 0.03, 0.038, 1.0));
      } else {
        if this.style == 1 {
          this.fill.SetTintColor(this.m_isPressed ? HDRColor(0.10, 0.11, 0.13, 1.0) : HDRColor(0.022, 0.027, 0.034, 1.0));
        } else {
          if this.style == 3 {
            this.fill.SetTintColor(this.m_isPressed ? HDRColor(0.03, 0.16, 0.18, 1.0) : HDRColor(0.015, 0.045, 0.052, 1.0));
          } else {
            this.fill.SetTintColor(this.m_isPressed ? HDRColor(0.10, 0.11, 0.13, 1.0) : HDRColor(0.018, 0.022, 0.028, 1.0));
          };
        };
      };
    };
    this.fill.SetOpacity(this.m_isPressed ? 0.68 : 0.48);
  }
  public func SetSelected(selected: Bool) -> Void {
    this.selected = selected;
    this.frame.SetTintColor(selected ? HDRColor(0.10, 0.72, 0.80, 1.0) : HDRColor(0.05, 0.06, 0.07, 1.0));
    this.frame.SetOpacity(selected ? 0.28 : 0.16);
    this.m_label.SetTintColor(selected ? HDRColor(0.22, 0.92, 1.0, 1.0) : (this.style == 3 ? HDRColor(0.22, 0.92, 1.0, 1.0) : HDRColor(1.0, 0.24, 0.22, 1.0)));
    this.ApplyPressedState();
  }
  public func SetStyle(value: Int32) -> Void {
    this.style = value;
    if value == 3 {
      this.m_label.SetTintColor(HDRColor(0.22, 0.92, 1.0, 1.0));
    } else {
      this.m_label.SetTintColor(HDRColor(1.0, 0.24, 0.22, 1.0));
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
  private let statusText: ref<inkText>;
  private let statusRail: ref<inkRectangle>;
  private let selectedInfo: ref<inkText>;
  private let openCETAction: ref<PanelButton>;
  private let refreshAction: ref<PanelButton>;
  private let locationButton: ref<PanelButton>;
  private let saveAction: ref<PanelButton>;
  private let cancelLoadAction: ref<PanelButton>;
  private let trashAction: ref<PanelButton>;
  private let undoAction: ref<PanelButton>;
  private let historyAction: ref<PanelButton>;
  private let detailsAction: ref<PanelButton>;
  private let listButtons: array<ref<PanelButton>>;
  private let actionButtons: array<ref<PanelButton>>;
  private let rowKinds: array<String>;
  private let rowValues: array<String>;
  private let rowLabels: array<String>;
  private let saveLocations: array<String>;
  private let saveLocationLabels: array<String>;
  private let historyIndexes: array<String>;
  private let historyLabels: array<String>;
  private let selectedName: String;
  private let selectedInfoValue: String;
  private let selectedSaveLocation: String;
  private let presetNameValue: String;
  private let scrollOffset: Int32;
  private let busy: Bool;
  private let cancelRequested: Bool;
  private let mode: Int32;
  private let recoveryAvailable: Bool;
  private let showLoadDetails: Bool;

  protected cb func OnCreate() -> Bool {
    let root: ref<inkCanvas> = new inkCanvas();
    root.SetName(n"CharacterPresetManagerPanel");
    root.SetAnchor(inkEAnchor.TopLeft);
    root.SetAnchorPoint(new Vector2(0.0, 0.0));
    root.SetMargin(new inkMargin(120.0, 220.0, 0.0, 0.0));
    root.SetSize(730.0, 1538.0);
    root.SetInteractive(true);
    root.SetSupportFocus(true);
    this.AddSurface(root, 18.0, -20.0, 688.0, 1558.0);
    let rail: ref<inkRectangle> = new inkRectangle();
    rail.SetSize(7.0, 1538.0);
    rail.SetTintColor(HDRColor(1.0, 0.22, 0.20, 1.0));
    rail.Reparent(root);
    let title: ref<inkText> = this.MakeText("CHARACTER PRESET MANAGER", 46, 34.0, -16.0, 654.0, 58.0);
    title.SetTintColor(HDRColor(0.22, 0.92, 1.0, 1.0));
    title.Reparent(root);

    let advancedText: ref<inkText> = this.MakeText("Choose a preset to load it. Use the advanced manager to organize, share, or troubleshoot presets.", 29, 34.0, 52.0, 654.0, 58.0);
    advancedText.SetWrapping(true, 644.0);
    advancedText.SetTintColor(HDRColor(1.0, 1.0, 1.0, 1.0));
    advancedText.Reparent(root);

    this.search = HubTextInput.Create();
    this.search.SetName(n"PresetSearch");
    this.search.SetDefaultText("SEARCH");
    this.search.SetWidth(492.0);
    this.search.SetMaxLength(64);
    this.SetInputTransparency(this.search);
    this.search.GetRootWidget().SetMargin(new inkMargin(34.0, 144.0, 0.0, 0.0));
    this.search.RegisterToCallback(n"OnInput", this, n"OnSearchChanged");
    this.search.Reparent(root, this.GetGameController());
    this.refreshAction = this.AddAction(root, "REFRESH", 534.0, 144.0, n"OnRefresh");
    this.refreshAction.SetWidth(154.0);
    let index: Int32 = 0;
    while index < 9 {
      let listButton: ref<PanelButton> = PanelButton.Create("");
      listButton.SetPosition(34.0, 220.0 + Cast<Float>(index) * 54.0);
      listButton.SetWidth(654.0);
      listButton.RegisterToCallback(n"OnBtnClick", this, n"OnListClick");
      listButton.GetRootWidget().RegisterToCallback(n"OnAxis", this, n"OnPanelScroll");
      listButton.GetRootWidget().RegisterToCallback(n"OnRelative", this, n"OnPanelScroll");
      listButton.Reparent(root, this.GetGameController());
      ArrayPush(this.listButtons, listButton);
      index += 1;
    };
    this.selectedInfo = this.MakeText("SELECTED PRESET - NONE", 27, 34.0, 716.0, 654.0, 54.0);
    this.selectedInfo.SetWrapping(true, 644.0);
    this.selectedInfo.SetTintColor(HDRColor(0.22, 0.92, 1.0, 1.0));
    this.selectedInfo.Reparent(root);
    this.cancelLoadAction = PanelButton.Create("CANCEL LOAD");
    this.cancelLoadAction.SetPosition(34.0, 782.0);
    this.cancelLoadAction.SetWidth(654.0);
    this.cancelLoadAction.SetStyle(2);
    this.cancelLoadAction.SetDisabled(true);
    this.cancelLoadAction.RegisterToCallback(n"OnBtnClick", this, n"OnCancelLoad");
    this.cancelLoadAction.Reparent(root, this.GetGameController());
    this.undoAction = this.AddAction(root, "UNDO LAST LOAD", 34.0, 840.0, n"OnRestorePrevious");
    this.undoAction.SetWidth(323.0);
    this.historyAction = this.AddAction(root, "RECOVERY HISTORY", 365.0, 840.0, n"OnHistory");
    this.historyAction.SetWidth(323.0);
    this.historyAction.SetStyle(3);
    this.statusRail = new inkRectangle();
    this.statusRail.SetSize(5.0, 166.0);
    this.statusRail.SetMargin(new inkMargin(34.0, 910.0, 0.0, 0.0));
    this.statusRail.SetTintColor(HDRColor(0.22, 0.92, 1.0, 1.0));
    this.statusRail.SetVisible(false);
    this.statusRail.Reparent(root);
    this.statusText = this.MakeText("", 28, 52.0, 900.0, 636.0, 176.0);
    this.statusText.SetWrapping(true, 626.0);
    this.statusText.SetTintColor(HDRColor(0.94, 0.97, 1.0, 1.0));
    this.statusText.SetVisible(false);
    this.statusText.Reparent(root);
    this.detailsAction = this.AddAction(root, "VIEW LOAD DETAILS IN CET", 34.0, 1088.0, n"OnLoadDetails");
    this.detailsAction.SetWidth(654.0);
    this.detailsAction.SetStyle(3);
    this.detailsAction.GetRootWidget().SetVisible(false);
    this.presetName = HubTextInput.Create();
    this.presetName.SetName(n"PresetName");
    this.presetName.SetDefaultText("PRESET NAME");
    this.presetName.SetWidth(654.0);
    this.presetName.SetMaxLength(64);
    this.SetInputTransparency(this.presetName);
    this.presetName.GetRootWidget().SetMargin(new inkMargin(34.0, 1148.0, 0.0, 0.0));
    this.presetName.RegisterToCallback(n"OnInput", this, n"OnPresetNameChanged");
    this.presetName.Reparent(root, this.GetGameController());
    this.locationButton = this.AddAction(root, "SAVE LOCATION: ALL PRESETS", 34.0, 1236.0, n"OnSaveLocation");
    this.locationButton.SetWidth(654.0);
    this.locationButton.SetStyle(3);
    this.saveAction = this.AddAction(root, "SAVE PRESET", 34.0, 1294.0, n"OnSave");
    this.saveAction.SetWidth(654.0);
    this.trashAction = this.AddAction(root, "MOVE PRESET TO TRASH", 34.0, 1352.0, n"OnMoveToTrash");
    this.trashAction.SetWidth(654.0);
    this.trashAction.SetStyle(2);
    this.openCETAction = this.AddAction(root, "ADVANCED PRESET MANAGER", 34.0, 1410.0, n"OnOpenCET");
    this.openCETAction.SetWidth(654.0);
    this.SetRootWidget(root);
    return true;
  }

  protected cb func OnInitialize() -> Bool {
    this.RegisterToGlobalInputCallback(n"OnPostOnRelease", this, n"OnGlobalRelease");
    if IsDefined(this.bridge) {
      this.bridge.RegisterPanel(this);
      this.bridge.Request("open", "");
      if !this.bridge.IsLuaReady() { this.SetStatus("The preset library is connecting.", false); };
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
  private func SetInputTransparency(input: ref<HubTextInput>) -> Void {
    let root: ref<inkCompoundWidget> = input.GetRootWidget() as inkCompoundWidget;
    if IsDefined(root) {
      let background: ref<inkWidget> = root.GetWidgetByPathName(n"theme/bg");
      if IsDefined(background) { background.SetOpacity(0.0); };
      let fill: ref<inkRectangle> = new inkRectangle();
      fill.SetAnchor(inkEAnchor.Fill);
      fill.SetTintColor(HDRColor(0.018, 0.022, 0.028, 1.0));
      fill.SetOpacity(0.48);
      fill.Reparent(root, 0);
      let frame: ref<inkRectangle> = new inkRectangle();
      frame.SetAnchor(inkEAnchor.Fill);
      frame.SetTintColor(HDRColor(0.05, 0.06, 0.07, 1.0));
      frame.SetOpacity(0.16);
      frame.Reparent(root, 1);
    };
  }
  private func AddSurface(parent: ref<inkCanvas>, x: Float, y: Float, width: Float, height: Float) -> Void {
    let fill: ref<inkRectangle> = new inkRectangle();
    fill.SetSize(width, height);
    fill.SetMargin(new inkMargin(x, y, 0.0, 0.0));
    fill.SetTintColor(HDRColor(0.018, 0.022, 0.028, 1.0));
    fill.SetOpacity(0.48);
    fill.Reparent(parent);
    let frame: ref<inkRectangle> = new inkRectangle();
    frame.SetSize(width, height);
    frame.SetMargin(new inkMargin(x, y, 0.0, 0.0));
    frame.SetTintColor(HDRColor(0.05, 0.06, 0.07, 1.0));
    frame.SetOpacity(0.16);
    frame.Reparent(parent);
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
  private func SetStatus(message: String, isError: Bool) -> Void {
    this.statusText.SetVisible(true);
    this.statusRail.SetVisible(true);
    this.statusText.SetText("PANEL STATUS - " + message);
    this.statusText.SetTintColor(isError ? HDRColor(1.0, 0.32, 0.26, 1.0) : HDRColor(0.94, 0.97, 1.0, 1.0));
    this.statusRail.SetTintColor(isError ? HDRColor(1.0, 0.24, 0.22, 1.0) : HDRColor(0.22, 0.92, 1.0, 1.0));
  }
  private func ClearStatus() -> Void {
    this.statusText.SetText("");
    this.statusText.SetVisible(false);
    this.statusRail.SetVisible(false);
  }
  private func ReleaseButtonFocus() -> Void {
    this.GetGameController().RequestSetFocus(null);
  }

  protected cb func OnSearchChanged(widget: wref<inkWidget>) -> Bool {
    if this.mode != 0 { return true; };
    this.scrollOffset = 0;
    this.bridge.Request("list", this.search.GetText());
    return true;
  }
  protected cb func OnRefresh(widget: wref<inkWidget>) -> Bool {
    if this.mode != 0 {
      this.mode = 0;
      this.scrollOffset = 0;
      this.UpdateMode();
      this.UpdateRows();
    } else {
      this.bridge.Request("refresh", "");
    };
    this.ReleaseButtonFocus();
    return true;
  }
  protected cb func OnOpenCET(widget: wref<inkWidget>) -> Bool {
    this.bridge.Request("open_advanced", "");
    this.ReleaseButtonFocus();
    return true;
  }
  protected cb func OnListClick(target: wref<inkWidget>) -> Bool {
    let index: Int32 = 0;
    while index < ArraySize(this.listButtons) {
      if this.listButtons[index].GetRootWidget() == target {
        let absolute: Int32 = this.scrollOffset + index;
        if this.mode == 1 && absolute < ArraySize(this.saveLocations) {
          this.selectedSaveLocation = this.saveLocations[absolute];
          this.mode = 0;
          this.scrollOffset = 0;
          this.UpdateSaveLocation();
          this.UpdateMode();
          this.UpdateRows();
          this.bridge.Request("save_location", this.selectedSaveLocation);
          this.ReleaseButtonFocus();
          return true;
        };
        if this.mode == 2 && absolute < ArraySize(this.historyIndexes) {
          this.mode = 0;
          this.scrollOffset = 0;
          this.UpdateMode();
          this.UpdateRows();
          this.bridge.Request("restore_history", this.historyIndexes[absolute]);
          this.ReleaseButtonFocus();
          return true;
        };
        if absolute < ArraySize(this.rowKinds) {
          if Equals(this.rowKinds[absolute], "FOLDER") {
            this.bridge.Request("toggle_folder", this.rowValues[absolute]);
            this.ReleaseButtonFocus();
          } else {
            if Equals(this.rowKinds[absolute], "PRESET") {
              let clickedName: String = this.rowValues[absolute];
              this.trashAction.SetText("MOVE PRESET TO TRASH");
              this.selectedName = clickedName;
              this.SetStatus(clickedName + " loading started.", false);
              this.UpdateRows();
              this.bridge.Request("select_load", clickedName);
              this.ReleaseButtonFocus();
            };
          };
        };
        return true;
      };
      index += 1;
    };
    return false;
  }
  protected cb func OnSave(widget: wref<inkWidget>) -> Bool {
    this.presetNameValue = this.presetName.GetText();
    this.bridge.Request("save", this.presetNameValue);
    this.ReleaseButtonFocus();
    return true;
  }
  protected cb func OnPresetNameChanged(widget: wref<inkWidget>) -> Bool {
    let currentValue: String = this.presetName.GetText();
    if Equals(currentValue, this.presetNameValue) { return true; };
    this.presetNameValue = currentValue;
    this.saveAction.SetText("SAVE PRESET");
    this.saveAction.SetStyle(StrLen(currentValue) > 0 ? 3 : 1);
    this.bridge.Request("cancel_save_confirmation", "");
    return true;
  }
  protected cb func OnMoveToTrash(widget: wref<inkWidget>) -> Bool { this.bridge.Request("delete", ""); this.ReleaseButtonFocus(); return true; }

  protected cb func OnCancelLoad(widget: wref<inkWidget>) -> Bool {
    if !this.busy || this.cancelRequested { return true; };
    this.cancelRequested = true;
    this.cancelLoadAction.SetText("CANCELING LOAD...");
    this.cancelLoadAction.SetDisabled(true);
    this.SetStatus("Canceling load...", false);
    this.bridge.Request("cancel_load", "");
    this.ReleaseButtonFocus();
    return true;
  }

  protected cb func OnRestorePrevious(widget: wref<inkWidget>) -> Bool {
    this.bridge.Request("restore_previous", "");
    this.ReleaseButtonFocus();
    return true;
  }
  protected cb func OnHistory(widget: wref<inkWidget>) -> Bool {
    if this.mode == 2 {
      this.mode = 0;
      this.scrollOffset = 0;
      this.UpdateMode();
      this.UpdateRows();
    } else {
      this.bridge.Request("history", "");
    };
    this.ReleaseButtonFocus();
    return true;
  }
  protected cb func OnLoadDetails(widget: wref<inkWidget>) -> Bool {
    this.bridge.Request("open_load_details", "");
    this.ReleaseButtonFocus();
    return true;
  }

  private func UpdateActionAvailability() -> Void {
    this.saveAction.SetDisabled(this.busy || this.mode != 0);
    this.trashAction.SetDisabled(this.busy || this.mode != 0 || StrLen(this.selectedName) == 0);
    this.undoAction.SetDisabled(this.busy || this.mode != 0 || !this.recoveryAvailable);
    this.historyAction.SetDisabled(this.busy);
    this.refreshAction.SetDisabled(this.busy);
    this.locationButton.SetDisabled(this.busy);
    this.cancelLoadAction.SetDisabled(!this.busy || this.cancelRequested);
    this.search.GetRootWidget().SetInteractive(!this.busy && this.mode == 0);
    this.presetName.GetRootWidget().SetInteractive(!this.busy && this.mode == 0);
  }
  protected cb func OnSaveLocation(widget: wref<inkWidget>) -> Bool {
    this.mode = this.mode == 1 ? 0 : 1;
    this.scrollOffset = 0;
    this.saveAction.SetText("SAVE PRESET");
    this.trashAction.SetText("MOVE PRESET TO TRASH");
    this.UpdateMode();
    this.UpdateRows();
    this.ReleaseButtonFocus();
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
    let count: Int32 = ArraySize(this.rowKinds);
    if this.mode == 1 { count = ArraySize(this.saveLocations); };
    if this.mode == 2 { count = ArraySize(this.historyIndexes); };
    let maximum: Int32 = Max(0, count - 9);
    this.scrollOffset = Max(0, Min(maximum, this.scrollOffset + amount));
    this.UpdateRows();
  }

  public func OnBusyChanged(isBusy: Bool, message: String, isError: Bool) -> Void {
    this.busy = isBusy;
    if !isBusy {
      this.cancelRequested = false;
      this.cancelLoadAction.SetText("CANCEL LOAD");
    };
    let index: Int32 = 0;
    while index < ArraySize(this.actionButtons) {
      this.actionButtons[index].SetDisabled(isBusy);
      index += 1;
    };
    this.UpdateRows();
    this.UpdateActionAvailability();
    if StrLen(message) > 0 { this.SetStatus(message, isError); };
  }
  public func OnBridgeResponse(kind: String, payload: String, isBusy: Bool) -> Void {
    this.OnBusyChanged(isBusy, "", false);
    if Equals(kind, "list") { this.ReadPresetList(payload); return; };
    if Equals(kind, "history") { this.ReadHistory(payload); return; };
    if Equals(kind, "confirm_state") {
      if Equals(payload, "SAVE\t0") { this.saveAction.SetText("SAVE PRESET"); };
      if Equals(payload, "TRASH\t0") { this.trashAction.SetText("MOVE PRESET TO TRASH"); };
      return;
    };
    this.SetStatus(payload, Equals(kind, "error"));
  }
  private func ReadPresetList(payload: String) -> Void {
    ArrayClear(this.rowKinds);
    ArrayClear(this.rowValues);
    ArrayClear(this.rowLabels);
    ArrayClear(this.saveLocations);
    ArrayClear(this.saveLocationLabels);
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
        ArrayPush(this.saveLocationLabels, fields[2]);
      };
      if ArraySize(fields) > 1 && Equals(fields[0], "SELECTED_LOCATION") {
        this.selectedSaveLocation = fields[1];
      };
      if ArraySize(fields) > 2 && Equals(fields[0], "STATUS") {
        if StrLen(fields[2]) > 0 { this.SetStatus(fields[2], Equals(fields[1], "1")); }
        else { this.ClearStatus(); };
        this.showLoadDetails = ArraySize(fields) > 4 && Equals(fields[4], "1");
        this.detailsAction.GetRootWidget().SetVisible(this.showLoadDetails);
      };
      if ArraySize(fields) > 2 && Equals(fields[0], "CONFIRM") {
        if Equals(fields[1], "SAVE") { this.saveAction.SetText(Equals(fields[2], "1") ? "CONFIRM OVERWRITE" : "SAVE PRESET"); };
        if Equals(fields[1], "TRASH") { this.trashAction.SetText(Equals(fields[2], "1") && StrLen(this.selectedName) > 0 ? "CONFIRM MOVE TO TRASH" : "MOVE PRESET TO TRASH"); };
      };
      if ArraySize(fields) > 7 && Equals(fields[0], "SELECTED") {
        this.selectedName = fields[1];
        if StrLen(this.selectedName) == 0 {
          this.selectedInfoValue = "SELECTED PRESET - NONE";
        } else {
          let details: String = fields[7] + " | " + fields[4] + " OPTIONS | FORMAT " + fields[6];
          if StrLen(fields[3]) > 0 { details = details + " | " + fields[3]; };
          let selectedLine: String = this.selectedName + " | " + details;
          this.selectedInfoValue = StrLen(selectedLine) > 92 ? StrLeft(selectedLine, 89) + "..." : selectedLine;
        };
      };
      if ArraySize(fields) > 1 && Equals(fields[0], "RECOVERY") {
        this.recoveryAvailable = Equals(fields[1], "1");
      };
      index += 1;
    };
    this.UpdateSaveLocation();
    this.UpdateMode();
    this.UpdateActionAvailability();
    this.ScrollBy(0);
  }
  private func ReadHistory(payload: String) -> Void {
    ArrayClear(this.historyIndexes);
    ArrayClear(this.historyLabels);
    let lines: array<String> = StrSplit(payload, "\n", false);
    let index: Int32 = 0;
    while index < ArraySize(lines) {
      let fields: array<String> = StrSplit(lines[index], "\t", true);
      if ArraySize(fields) > 4 && Equals(fields[0], "HISTORY") {
        ArrayPush(this.historyIndexes, fields[1]);
        ArrayPush(this.historyLabels, fields[2] + " | " + fields[3] + " OPTIONS | " + fields[4]);
      };
      if ArraySize(fields) > 1 && Equals(fields[0], "EMPTY") {
        this.SetStatus(fields[1], false);
      };
      index += 1;
    };
    this.mode = 2;
    this.scrollOffset = 0;
    this.UpdateMode();
    this.UpdateRows();
  }
  private func UpdateSaveLocation() -> Void {
    let label: String = StrLen(this.selectedSaveLocation) > 0 ? this.selectedSaveLocation : "ALL PRESETS";
    if this.mode != 1 {
      this.locationButton.SetText("SAVE LOCATION: " + (StrLen(label) > 48 ? StrLeft(label, 45) + "..." : label));
    };
  }
  private func UpdateMode() -> Void {
    this.refreshAction.SetText(this.mode == 0 ? "REFRESH" : "BACK");
    this.historyAction.SetText(this.mode == 2 ? "BACK TO PRESETS" : "RECOVERY HISTORY");
    if this.mode == 1 {
      this.locationButton.SetText("CANCEL LOCATION PICKER");
      this.selectedInfo.SetText("CHOOSE A SAVE LOCATION");
    } else {
      if this.mode == 2 {
        this.selectedInfo.SetText("RECOVERY HISTORY - NEWEST FIRST");
      } else {
        this.selectedInfo.SetText(this.selectedInfoValue);
      };
      this.UpdateSaveLocation();
    };
    this.UpdateActionAvailability();
  }
  private func UpdateRows() -> Void {
    let count: Int32 = ArraySize(this.rowKinds);
    if this.mode == 1 { count = ArraySize(this.saveLocations); };
    if this.mode == 2 { count = ArraySize(this.historyIndexes); };
    let maximum: Int32 = Max(0, count - 9);
    if this.scrollOffset > maximum { this.scrollOffset = maximum; };
    let index: Int32 = 0;
    while index < ArraySize(this.listButtons) {
      let absolute: Int32 = this.scrollOffset + index;
      let visible: Bool = absolute < count;
      this.listButtons[index].GetRootWidget().SetVisible(visible);
      this.listButtons[index].SetDisabled(this.busy || !visible);
      if visible {
        let label: String;
        let kind: String;
        let value: String;
        if this.mode == 1 {
          label = this.saveLocationLabels[absolute];
          kind = "LOCATION";
          value = this.saveLocations[absolute];
        } else {
          if this.mode == 2 {
            label = this.historyLabels[absolute];
            kind = "HISTORY";
            value = this.historyIndexes[absolute];
          } else {
            label = this.rowLabels[absolute];
            kind = this.rowKinds[absolute];
            value = this.rowValues[absolute];
          };
        };
        this.listButtons[index].SetText(StrLen(label) > 50 ? StrLeft(label, 47) + "..." : label);
        this.listButtons[index].SetStyle(Equals(kind, "FOLDER") || Equals(kind, "HEADING") || Equals(kind, "LOCATION") || Equals(kind, "HISTORY") ? 3 : 0);
        this.listButtons[index].SetSelected((Equals(kind, "PRESET") && Equals(value, this.selectedName)) || (Equals(kind, "LOCATION") && Equals(value, this.selectedSaveLocation)));
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

@addMethod(characterCreationBodyMorphMenu)
public func CPMGetNativeBridge() -> ref<NativeBridge> {
  return GameInstance.GetScriptableSystemsContainer(GetGameInstance()).Get(n"CPM.NativeBridge") as NativeBridge;
}

@wrapMethod(characterCreationBodyMorphMenu)
protected cb func OnInitialize() -> Bool {
  wrappedMethod();
  inkWidgetRef.SetTranslation(this.m_randomizeGroup, new Vector2(0.0, 700.0));
  let bridge: ref<NativeBridge> = this.CPMGetNativeBridge();
  if IsDefined(bridge) {
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
}

@wrapMethod(characterCreationBodyMorphMenu)
protected cb func OnUninitialize() -> Bool {
  if IsDefined(this.cpmPresetPanel) {
    this.cpmPresetPanel.Detach();
    this.cpmPresetPanel = null;
  };
  wrappedMethod();
}
