module CPM

public enum EditorKey {
  Unbound = 0,
  F10 = 1,
  F11 = 2
}

public class EditorLaunchTimeout extends DelayCallback {
  public let launcher: wref<CoreLauncher>;
  public let generation: Int32;

  public func Call() -> Void {
    if IsDefined(this.launcher) { this.launcher.Expire(this.generation); };
  }
}

public class CoreLauncher extends ScriptableService {
  @runtimeProperty("ModSettings.mod", "Character Preset Manager")
  @runtimeProperty("ModSettings.displayName", "Open Character Creator")
  public let launchKey: EditorKey = EditorKey.Unbound;

  public let controller: wref<gameuiInGameMenuGameController>;
  public let pending: Bool;
  public let redirected: Bool;
  private let generation: Int32;
  private let input: ref<CallbackSystemHandler>;
  private let wardrobeOwner: wref<PlayerPuppet>;
  private let editor: wref<characterCreationBodyMorphMenu>;

  public static func Get() -> ref<CoreLauncher> {
    return GameInstance.GetScriptableServiceContainer().GetService(n"CPM.CoreLauncher") as CoreLauncher;
  }

  private cb func OnLoad() -> Void {
    this.RegisterSettings();
    this.input = GameInstance.GetCallbackSystem().RegisterCallback(n"Input/Key", this, n"OnKey");
  }

  private cb func OnUninitialize() -> Void {
    if IsDefined(this.input) { this.input.Unregister(); };
    this.UnregisterSettings();
  }

  @if(ModuleExists("ModSettingsModule"))
  private func RegisterSettings() -> Void { ModSettings.RegisterListenerToClass(this); }

  @if(!ModuleExists("ModSettingsModule"))
  private func RegisterSettings() -> Void {}

  @if(ModuleExists("ModSettingsModule"))
  private func UnregisterSettings() -> Void { ModSettings.UnregisterListenerToClass(this); }

  @if(!ModuleExists("ModSettingsModule"))
  private func UnregisterSettings() -> Void {}

  private cb func OnKey(evt: ref<KeyInputEvent>) -> Void {
    if !CPMCoreTestEnabled() || !IsDefined(this.controller) || this.pending || this.redirected { return; };
    if NotEquals(evt.GetAction(), EInputAction.IACT_Press) || Equals(this.launchKey, EditorKey.Unbound) { return; };
    if Equals(this.launchKey, EditorKey.F10) && NotEquals(evt.GetKey(), EInputKey.IK_F10)
      || Equals(this.launchKey, EditorKey.F11) && NotEquals(evt.GetKey(), EInputKey.IK_F11) { return; };
    let game = GetGameInstance();
    let player = GetPlayer(game);
    if !IsDefined(player) || player.IsDead() || IsDefined(this.editor) { return; };
    let bridge = GameInstance.GetScriptableSystemsContainer(game).Get(n"CPM.NativeBridge") as NativeBridge;
    if IsDefined(bridge) && bridge.HasPanels() { return; };
    this.pending = true;
    this.generation += 1;
    let timer = new EditorLaunchTimeout();
    timer.launcher = this;
    timer.generation = this.generation;
    GameInstance.GetDelaySystem(game).DelayCallback(timer, 5.0, false);
    this.DisableWardrobe();
    this.controller.CPMRequestEditor();
  }

  public func Expire(generation: Int32) -> Void {
    if this.generation != generation { return; };
    this.pending = false;
    this.redirected = false;
    if !IsDefined(this.editor) { this.RestoreWardrobe(); };
  }

  public func EditorOpened(menu: ref<characterCreationBodyMorphMenu>) -> Void {
    this.editor = menu;
    this.pending = false;
    this.redirected = false;
    this.DisableWardrobe();
  }

  public func EditorClosed(menu: ref<characterCreationBodyMorphMenu>) -> Void {
    if this.editor != menu { return; };
    this.editor = null;
    this.RestoreWardrobe();
  }

  private func DisableWardrobe() -> Void {
    if IsDefined(this.wardrobeOwner) { return; };
    let game = GetGameInstance();
    let player = GetPlayer(game);
    if !IsDefined(player) || Equals(EquipmentSystem.GetActiveWardrobeSetID(player), gameWardrobeClothingSetIndex.INVALID) { return; };
    let equipment = GameInstance.GetScriptableSystemsContainer(game).Get(n"EquipmentSystem") as EquipmentSystem;
    if !IsDefined(equipment) { return; };
    let request = new QuestDisableWardrobeSetRequest();
    request.owner = player;
    request.blockReequipping = true;
    equipment.QueueRequest(request);
    this.wardrobeOwner = player;
  }

  private func RestoreWardrobe() -> Void {
    if !IsDefined(this.wardrobeOwner) { return; };
    let equipment = GameInstance.GetScriptableSystemsContainer(GetGameInstance()).Get(n"EquipmentSystem") as EquipmentSystem;
    if !IsDefined(equipment) { return; };
    let request = new QuestRestoreWardrobeSetRequest();
    request.owner = this.wardrobeOwner;
    equipment.QueueRequest(request);
    this.wardrobeOwner = null;
  }
}

@addMethod(gameuiInGameMenuGameController)
public func CPMRequestEditor() -> Void {
  this.SpawnMenuInstanceEvent(n"OnOpenPauseMenu");
}

@wrapMethod(gameuiInGameMenuGameController)
protected cb func OnInitialize() -> Bool {
  let result = wrappedMethod();
  let launcher = CoreLauncher.Get();
  if IsDefined(launcher) { launcher.controller = this; };
  return result;
}

@wrapMethod(MenuScenario_PauseMenu)
protected cb func OnEnterScenario(previousScenario: CName, userData: ref<IScriptable>) -> Bool {
  let launcher = CoreLauncher.Get();
  if IsDefined(launcher) && launcher.pending {
    launcher.pending = false;
    launcher.redirected = true;
    this.SwitchToScenario(n"MenuScenario_CharacterCustomizationMirror");
    return true;
  };
  return wrappedMethod(previousScenario, userData);
}

@wrapMethod(MenuScenario_CharacterCustomizationMirror)
protected cb func OnCCOPuppetReady() -> Bool {
  let launcher = CoreLauncher.Get();
  if !IsDefined(launcher) || !launcher.redirected { return wrappedMethod(); };
  launcher.redirected = false;
  let userData = new MorphMenuUserData();
  userData.m_optionsListInitialized = false;
  userData.m_updatingFinalizedState = true;
  userData.m_editMode = gameuiCharacterCustomizationEditTag.NewGame;
  this.m_currMenuName = n"character_customization";
  let menus = this.GetMenusState();
  menus.OpenMenu(n"player_puppet");
  menus.OpenMenu(n"character_customization", userData);
  return true;
}
