module CPM

public class PanelTextInput extends IScriptable {
  private let root: ref<inkCanvas>;
  private let input: ref<inkTextInput>;
  private let placeholder: ref<inkText>;
  private let frame: ref<PanelFrame>;
  private let enabled: Bool;
  private let focused: Bool;
  private let maxLength: Int32;
  private let value: String;
  private let listener: wref<IScriptable>;
  private let listenerEvent: CName;
  private let listenerCallback: CName;

  public static func Create() -> ref<PanelTextInput> {
    let field: ref<PanelTextInput> = new PanelTextInput();
    field.enabled = true;
    field.maxLength = 64;
    field.root = new inkCanvas();
    field.root.SetSize(654.0, 80.0);
    field.root.SetInteractive(true);
    let fill: ref<inkRectangle> = new inkRectangle();
    fill.SetAnchor(inkEAnchor.Fill);
    fill.SetTintColor(HDRColor(0.045, 0.008, 0.012, 1.0));
    fill.SetOpacity(0.48);
    fill.SetInteractive(false);
    fill.Reparent(field.root);
    field.frame = PanelFrame.Create(field.root);
    field.input = new inkTextInput();
    field.input.SetAnchor(inkEAnchor.Fill);
    field.input.SetMargin(new inkMargin(18.0, 0.0, 18.0, 0.0));
    field.input.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    field.input.SetFontStyle(n"Medium");
    field.input.SetFontSize(38);
    field.input.SetText("");
    field.input.EnableAutoScroll(true);
    field.input.SetHorizontalAlignment(textHorizontalAlignment.Center);
    field.input.SetVerticalAlignment(textVerticalAlignment.Center);
    field.input.SetTintColor(HDRColor(0.94, 0.97, 1.0, 1.0));
    field.input.SetInteractive(true);
    field.input.SetSupportFocus(true);
    field.input.SetMaxChars(64u);
    field.input.Reparent(field.root);
    field.placeholder = new inkText();
    field.placeholder.SetAnchor(inkEAnchor.Fill);
    field.placeholder.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    field.placeholder.SetFontStyle(n"Medium");
    field.placeholder.SetFontSize(38);
    field.placeholder.SetHorizontalAlignment(textHorizontalAlignment.Center);
    field.placeholder.SetVerticalAlignment(textVerticalAlignment.Center);
    field.placeholder.SetTintColor(HDRColor(0.882353, 0.913725, 0.901961, 1.0));
    field.placeholder.SetInteractive(false);
    field.placeholder.Reparent(field.root);
    field.root.RegisterToCallback(n"OnRelease", field, n"OnRelease");
    field.input.RegisterToCallback(n"OnTextChanged", field, n"OnTextChanged");
    field.input.RegisterToCallback(n"OnFocusReceived", field, n"OnFocusReceived");
    field.input.RegisterToCallback(n"OnFocusLost", field, n"OnFocusLost");
    return field;
  }

  public func GetRootWidget() -> ref<inkCanvas> { return this.root; }
  public func GetText() -> String { return this.value; }
  public func SetName(name: CName) -> Void { this.root.SetName(name); }
  public func SetDefaultText(text: String) -> Void { this.placeholder.SetText(text); }
  public func SetWidth(width: Float) -> Void { this.root.SetWidth(width); }
  public func SetMaxLength(length: Int32) -> Void {
    this.maxLength = Max(0, length);
    this.input.SetMaxChars(Cast<Uint32>(this.maxLength));
  }
  public func Reparent(parent: ref<inkCompoundWidget>) -> Void { this.root.Reparent(parent); }
  public func RegisterToCallback(eventName: CName, target: ref<IScriptable>, callback: CName) -> Void {
    this.listener = target;
    this.listenerEvent = eventName;
    this.listenerCallback = callback;
    this.root.RegisterToCallback(eventName, target, callback);
  }
  public func IsFocused() -> Bool { return this.focused; }
  public func Blur() -> Void {
    this.input.RequestUnfocus();
    this.focused = false;
    this.UpdateFocus();
  }
  public func HandleRelease(evt: ref<inkPointerEvent>) -> Bool {
    if !this.focused { return false; };
    if evt.IsAction(n"back") || evt.IsAction(n"confirm") {
      this.Blur();
      evt.Handle();
      return true;
    };
    if evt.IsAction(n"click") {
      let target: wref<inkWidget> = evt.GetTarget();
      while IsDefined(target) {
        if target == this.root { return false; };
        target = target.GetParentWidget();
      };
      this.Blur();
    };
    return false;
  }
  public func SetEnabled(enabled: Bool) -> Void {
    this.enabled = enabled;
    if !enabled { this.input.RequestUnfocus(); this.focused = false; };
    this.root.SetInteractive(enabled);
    this.input.SetInteractive(enabled);
    this.input.SetSupportFocus(enabled);
    this.root.SetOpacity(enabled ? 1.0 : 0.32);
    this.UpdateFocus();
  }
  private func UpdateFocus() -> Void {
    this.placeholder.SetVisible(StrLen(this.value) == 0 && !this.focused);
    this.frame.SetTintColor(this.focused ? HDRColor(0.22, 0.92, 1.0, 1.0) : HDRColor(1.0, 0.22, 0.20, 1.0));
  }
  protected cb func OnRelease(evt: ref<inkPointerEvent>) -> Bool {
    if this.enabled && evt.IsAction(n"click") {
      this.input.RequestFocus();
      this.focused = true;
      this.UpdateFocus();
      evt.Handle();
      return true;
    };
    return false;
  }
  protected cb func OnFocusReceived(evt: ref<inkEvent>) -> Bool {
    this.focused = this.enabled;
    this.UpdateFocus();
    return false;
  }
  protected cb func OnFocusLost(evt: ref<inkEvent>) -> Bool {
    this.focused = false;
    this.UpdateFocus();
    return false;
  }
  protected cb func OnTextChanged(text: String) -> Bool {
    let limited: String = StrLeft(text, this.maxLength);
    if NotEquals(text, limited) { this.input.SetText(limited); };
    if Equals(this.value, limited) { return false; };
    this.value = limited;
    this.UpdateFocus();
    this.root.CallCustomCallback(n"OnInput");
    return true;
  }
  public func Dispose() -> Void {
    this.SetEnabled(false);
    if IsDefined(this.listener) {
      this.root.UnregisterFromCallback(this.listenerEvent, this.listener, this.listenerCallback);
      this.listener = null;
    };
    this.root.UnregisterFromCallback(n"OnRelease", this, n"OnRelease");
    this.input.UnregisterFromCallback(n"OnTextChanged", this, n"OnTextChanged");
    this.input.UnregisterFromCallback(n"OnFocusReceived", this, n"OnFocusReceived");
    this.input.UnregisterFromCallback(n"OnFocusLost", this, n"OnFocusLost");
  }
}
