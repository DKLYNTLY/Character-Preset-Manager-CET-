module CPM

public class RestoreWardrobe extends DelayCallback {
  public let service: wref<InputService>;
  public func Call() -> Void { if IsDefined(this.service) { this.service.RestoreWardrobe(); }; }
}

public class EditorTimeout extends DelayCallback {
  public let service: wref<InputService>;
  public func Call() -> Void {
    if IsDefined(this.service) && this.service.launchPending { this.service.launchPending = false; this.service.fullEditor = false; this.service.RestoreWardrobe(); };
  }
}

public class InputService extends ScriptableService {
  public let controller: wref<gameuiInGameMenuGameController>;
  public let launchPending: Bool;
  public let fullEditor: Bool;
  private let binding: Bool;
  private let bindingEditor: Bool;
  private let wardrobeOwner: wref<GameObject>;
  private let wardrobeChanged: Bool;
  private let editorOpen: Bool;
  private let lastEditorPress: Float;
  private let lastPanelPress: Float;
  private let overlayOpen: Bool;
  private let keysDown: array<EInputKey>;

  public static func Get() -> ref<InputService> {
    return GameInstance.GetScriptableServiceContainer().GetService(n"CPM.InputService") as InputService;
  }
  public static func Bridge() -> ref<NativeBridge> {
    return GameInstance.GetScriptableSystemsContainer(GetGameInstance()).Get(n"CPM.NativeBridge") as NativeBridge;
  }
  private cb func OnLoad() -> Void {
    GameInstance.GetCallbackSystem().RegisterCallback(n"Input/Key", this, n"OnKey");
    this.lastEditorPress = -1.0;
    this.lastPanelPress = -1.0;
  }
  public func BindingsText() -> String {
    return "Editor key: " + ToString(IntEnum<EInputKey>(CPMNativeInputKey(true))) + " | Panel key: " + ToString(IntEnum<EInputKey>(CPMNativeInputKey(false)));
  }
  public func BindKey(editor: Bool) -> Void { this.binding = true; this.bindingEditor = editor; }
  public func SetOverlayOpen(value: Bool) -> Void {
    this.overlayOpen = value;
    let bridge: ref<NativeBridge> = InputService.Bridge();
    if IsDefined(bridge) { bridge.SetOverlayOpen(value); };
  }
  private cb func OnKey(event: ref<KeyInputEvent>) -> Void {
    if Equals(event.GetAction(), EInputAction.IACT_Release) { ArrayRemove(this.keysDown, event.GetKey()); return; };
    if NotEquals(event.GetAction(), EInputAction.IACT_Press) || this.overlayOpen || ArrayContains(this.keysDown, event.GetKey()) { return; };
    ArrayPush(this.keysDown, event.GetKey());
    let bridge: ref<NativeBridge> = InputService.Bridge();
    if this.binding {
      this.binding = false;
      let key: Int32 = Equals(event.GetKey(), EInputKey.IK_Backspace) ? 0 : EnumInt(event.GetKey());
      if IsDefined(bridge) { bridge.RequestExtended("keys_save", IntToString(key), this.bindingEditor ? "editor" : "panel", false); };
      return;
    };
    if IsDefined(bridge) && bridge.IsTyping() { return; };
    if CPMNativeInputKey(false) != 0 && EnumInt(event.GetKey()) == CPMNativeInputKey(false) { this.TogglePanel(); };
    if CPMNativeInputKey(true) != 0 && EnumInt(event.GetKey()) == CPMNativeInputKey(true) { this.OpenEditor(); };
  }
  public func TogglePanel() -> Void {
    let bridge: ref<NativeBridge> = InputService.Bridge();
    let now: Float = EngineTime.ToFloat(GameInstance.GetEngineTime(GetGameInstance()));
    if this.overlayOpen || now - this.lastPanelPress < 0.15 { return; };
    this.lastPanelPress = now;
    if IsDefined(bridge) { bridge.TogglePanelVisibility(); };
  }
  public func OpenEditor() -> Void {
    let bridge: ref<NativeBridge> = InputService.Bridge();
    let now: Float = EngineTime.ToFloat(GameInstance.GetEngineTime(GetGameInstance()));
    if this.overlayOpen || now - this.lastEditorPress < 0.15 || this.editorOpen || this.launchPending || !IsDefined(this.controller) { return; };
    if IsDefined(bridge) && bridge.IsTyping() { return; };
    this.lastEditorPress = now;
    this.DisableWardrobe();
    this.launchPending = true;
    this.fullEditor = true;
    this.controller.CPMOpenEditor();
    let timeout: ref<EditorTimeout> = new EditorTimeout();
    timeout.service = this;
    GameInstance.GetDelaySystem(GetGameInstance()).DelayCallback(timeout, 10.0, false);
  }
  public func EditorOpened() -> Void { this.editorOpen = true; this.launchPending = false; this.DisableWardrobe(); }
  public func EditorClosed() -> Void { this.editorOpen = false; this.fullEditor = false; this.launchPending = false; this.RestoreWardrobe(); }
  private func DisableWardrobe() -> Void {
    let player: ref<GameObject> = GetPlayer(GetGameInstance());
    if this.wardrobeChanged || !IsDefined(player) { return; };
    if Equals(EquipmentSystem.GetActiveWardrobeSetID(player), gameWardrobeClothingSetIndex.INVALID) { return; };
    let system: ref<EquipmentSystem> = GameInstance.GetScriptableSystemsContainer(GetGameInstance()).Get(n"EquipmentSystem") as EquipmentSystem;
    if !IsDefined(system) { return; };
    let data: ref<EquipmentSystemPlayerData> = system.GetPlayerData(player);
    if !IsDefined(data) || !data.IsWardrobeEnabled() { return; };
    let request: ref<QuestDisableWardrobeSetRequest> = new QuestDisableWardrobeSetRequest();
    request.owner = player;
    request.blockReequipping = true;
    system.QueueRequest(request);
    this.wardrobeOwner = player;
    this.wardrobeChanged = true;
  }
  public func RestoreWardrobe() -> Void {
    if !this.wardrobeChanged || this.editorOpen { return; };
    if !IsDefined(this.wardrobeOwner) { this.wardrobeChanged = false; return; };
    let player: ref<GameObject> = GetPlayer(GetGameInstance());
    let system: ref<EquipmentSystem> = GameInstance.GetScriptableSystemsContainer(GetGameInstance()).Get(n"EquipmentSystem") as EquipmentSystem;
    if !IsDefined(player) || !IsDefined(system) || player != this.wardrobeOwner {
      let callback: ref<RestoreWardrobe> = new RestoreWardrobe();
      callback.service = this;
      GameInstance.GetDelaySystem(GetGameInstance()).DelayCallback(callback, 0.5, false);
      return;
    };
    let request: ref<QuestRestoreWardrobeSetRequest> = new QuestRestoreWardrobeSetRequest();
    request.owner = player;
    system.QueueRequest(request);
    this.wardrobeChanged = false;
    this.wardrobeOwner = null;
  }
}

@addMethod(gameuiInGameMenuGameController)
public func CPMOpenEditor() -> Void { this.SpawnMenuInstanceEvent(n"OnOpenPauseMenu"); }

@wrapMethod(gameuiInGameMenuGameController)
protected cb func OnInitialize() -> Bool {
  wrappedMethod();
  InputService.Get().controller = this;
  return true;
}

@wrapMethod(gameuiInGameMenuGameController)
protected cb func OnUninitialize() -> Bool {
  if InputService.Get().controller == this { InputService.Get().controller = null; };
  return wrappedMethod();
}

@wrapMethod(MenuScenario_PauseMenu)
protected cb func OnEnterScenario(previous: CName, userData: ref<IScriptable>) -> Bool {
  if InputService.Get().launchPending {
    this.SwitchToScenario(n"MenuScenario_CharacterCustomizationMirror");
    return true;
  };
  return wrappedMethod(previous, userData);
}

@wrapMethod(MenuScenario_CharacterCustomizationMirror)
protected cb func OnCCOPuppetReady() -> Bool {
  if !InputService.Get().fullEditor { return wrappedMethod(); };
  let data: ref<MorphMenuUserData> = new MorphMenuUserData();
  data.m_optionsListInitialized = false;
  data.m_updatingFinalizedState = true;
  data.m_editMode = gameuiCharacterCustomizationEditTag.NewGame;
  this.m_currMenuName = n"character_customization";
  this.GetMenusState().OpenMenu(n"player_puppet");
  this.GetMenusState().OpenMenu(n"character_customization", data);
  return true;
}
