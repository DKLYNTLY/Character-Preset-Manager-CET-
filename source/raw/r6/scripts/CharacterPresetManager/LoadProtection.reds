module CPM

public class LoadProtection extends ScriptableSystem {
  private let owner: wref<characterCreationBodyMorphMenu>;

  public static func Get() -> ref<LoadProtection> {
    return GameInstance.GetScriptableSystemsContainer(GetGameInstance()).Get(n"CPM.LoadProtection") as LoadProtection;
  }

  public func Acquire(menu: ref<characterCreationBodyMorphMenu>) -> Bool {
    if IsDefined(this.owner) && this.owner != menu { return false; };
    this.owner = menu;
    return IsDefined(this.owner);
  }

  public func Release(menu: ref<characterCreationBodyMorphMenu>) -> Void {
    if this.owner == menu { this.owner = null; };
  }

  public func IsActive() -> Bool { return IsDefined(this.owner); }
  public func IsOwner(menu: ref<characterCreationBodyMorphMenu>) -> Bool { return this.owner == menu; }
}

@addMethod(characterCreationBodyMorphMenu)
public func CPMIsLoadProtected() -> Bool {
  let protection: ref<LoadProtection> = LoadProtection.Get();
  return IsDefined(protection) && protection.IsOwner(this);
}

@addMethod(characterCreationBodyMorphMenu)
public func CPMSetLoadProtected(active: Bool) -> Bool {
  let protection: ref<LoadProtection> = LoadProtection.Get();
  let controller: ref<CharacterCreationBodyMorphBaseOption>;
  let index: Int32 = 0;
  if !IsDefined(protection) { return false; };
  if active {
    if !protection.Acquire(this) { return false; };
  } else {
    protection.Release(this);
  };
  while index < inkCompoundRef.GetNumChildren(this.m_optionsList) {
    controller = inkCompoundRef.GetWidgetByIndex(this.m_optionsList, index).GetController() as CharacterCreationBodyMorphBaseOption;
    if IsDefined(controller) { controller.CPMRefreshLoadInput(); };
    index += 1;
  };
  return true;
}

@addField(CharacterCreationBodyMorphBaseOption)
private let cpmInputKnown: Bool;

@addField(CharacterCreationBodyMorphBaseOption)
private let cpmRequestedInputDisabled: Bool;

@addField(CharacterCreationBodyMorphBaseOption)
private let cpmApplyingLoadInput: Bool;

@addMethod(CharacterCreationBodyMorphBaseOption)
public func CPMRefreshLoadInput() -> Void {
  let selector: ref<characterCreationBodyMorphOption> = this as characterCreationBodyMorphOption;
  let color: ref<characterCreationBodyMorphColorOption> = this as characterCreationBodyMorphColorOption;
  let voice: ref<characterCreationVoiceOverSwitcher> = this as characterCreationVoiceOverSwitcher;
  if !this.cpmInputKnown {
    if IsDefined(selector) { this.cpmRequestedInputDisabled = selector.m_inputDisabled; }
    else {
      if IsDefined(color) { this.cpmRequestedInputDisabled = color.m_inputDisabled; }
      else { if IsDefined(voice) { this.cpmRequestedInputDisabled = voice.m_inputDisabled; }; };
    };
    this.cpmInputKnown = true;
  };
  this.cpmApplyingLoadInput = true;
  if IsDefined(selector) { selector.SetInputDisabled(this.cpmRequestedInputDisabled); }
  else {
    if IsDefined(color) { color.SetInputDisabled(this.cpmRequestedInputDisabled); }
    else { if IsDefined(voice) { voice.SetInputDisabled(this.cpmRequestedInputDisabled); }; };
  };
  this.cpmApplyingLoadInput = false;
}

@wrapMethod(characterCreationBodyMorphOption)
public final func SetInputDisabled(disabled: Bool) -> Void {
  let protection: ref<LoadProtection> = LoadProtection.Get();
  if !this.cpmApplyingLoadInput {
    this.cpmInputKnown = true;
    this.cpmRequestedInputDisabled = disabled;
  };
  wrappedMethod(disabled || (IsDefined(protection) && protection.IsActive()));
}

@wrapMethod(characterCreationBodyMorphColorOption)
public final func SetInputDisabled(disabled: Bool) -> Void {
  let protection: ref<LoadProtection> = LoadProtection.Get();
  if !this.cpmApplyingLoadInput {
    this.cpmInputKnown = true;
    this.cpmRequestedInputDisabled = disabled;
  };
  wrappedMethod(disabled || (IsDefined(protection) && protection.IsActive()));
}

@wrapMethod(characterCreationVoiceOverSwitcher)
public final func SetInputDisabled(disabled: Bool) -> Void {
  let protection: ref<LoadProtection> = LoadProtection.Get();
  if !this.cpmApplyingLoadInput {
    this.cpmInputKnown = true;
    this.cpmRequestedInputDisabled = disabled;
  };
  wrappedMethod(disabled || (IsDefined(protection) && protection.IsActive()));
}

@wrapMethod(characterCreationBodyMorphOption)
public final func SetOption(const option: wref<CharacterCustomizationOption>) -> Void {
  let protection: ref<LoadProtection> = LoadProtection.Get();
  wrappedMethod(option);
  if IsDefined(protection) && protection.IsActive() { this.CPMRefreshLoadInput(); };
}

@wrapMethod(characterCreationBodyMorphColorOption)
public final func SetOption(const option: wref<CharacterCustomizationOption>) -> Void {
  let protection: ref<LoadProtection> = LoadProtection.Get();
  wrappedMethod(option);
  if IsDefined(protection) && protection.IsActive() { this.CPMRefreshLoadInput(); };
}

@wrapMethod(characterCreationBodyMorphMenu)
protected cb func OnSliderChange(widget: wref<inkWidget>) -> Bool {
  if this.CPMIsLoadProtected() { return false; };
  return wrappedMethod(widget);
}

@wrapMethod(characterCreationBodyMorphMenu)
protected cb func OnColorPickerTriggered(widget: wref<inkWidget>) -> Bool {
  if this.CPMIsLoadProtected() { return false; };
  return wrappedMethod(widget);
}

@wrapMethod(characterCreationBodyMorphMenu)
protected cb func OnColorSelected(widget: wref<inkWidget>) -> Bool {
  if this.CPMIsLoadProtected() { return false; };
  return wrappedMethod(widget);
}

@wrapMethod(characterCreationBodyMorphMenu)
protected cb func OnColorChange(widget: wref<inkWidget>) -> Bool {
  if this.CPMIsLoadProtected() { return false; };
  return wrappedMethod(widget);
}

@wrapMethod(characterCreationBodyMorphMenu)
protected cb func OnVoiceOverSwitched(widget: wref<inkWidget>) -> Bool {
  if this.CPMIsLoadProtected() { return false; };
  return wrappedMethod(widget);
}

@wrapMethod(characterCreationBodyMorphMenu)
protected cb func OnPreset1(e: ref<inkPointerEvent>) -> Bool {
  if this.CPMIsLoadProtected() { return false; };
  return wrappedMethod(e);
}

@wrapMethod(characterCreationBodyMorphMenu)
protected cb func OnPreset2(e: ref<inkPointerEvent>) -> Bool {
  if this.CPMIsLoadProtected() { return false; };
  return wrappedMethod(e);
}

@wrapMethod(characterCreationBodyMorphMenu)
protected cb func OnPreset3(e: ref<inkPointerEvent>) -> Bool {
  if this.CPMIsLoadProtected() { return false; };
  return wrappedMethod(e);
}

@wrapMethod(characterCreationBodyMorphMenu)
public final func ConfirmCustomizedCharacter() -> Void {
  if this.CPMIsLoadProtected() { return; };
  wrappedMethod();
}
