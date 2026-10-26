@addField(characterCreationBodyMorphMenu)
private let cpm_voicePending: Bool;

@addField(characterCreationBodyMorphMenu)
private let cpm_voiceMale: Bool;

@addField(characterCreationBodyMorphMenu)
private let cpm_voicePlayer: wref<PlayerPuppet>;

@addMethod(PlayerPuppet)
public final func CPMCommitVoiceGender(isMale: Bool) -> Bool {
  let ps = this.GetPS();
  if !IsDefined(ps) {
    return false;
  };
  ps.gender = isMale ? n"Male" : n"Female";
  return Equals(ps.GetGender(), isMale ? n"Male" : n"Female");
}

@wrapMethod(characterCreationBodyMorphMenu)
protected cb func OnInitializeOptionsList(evt: ref<gameuiCharacterCustomizationSystem_OnInitializeOptionsListEvent>) -> Bool {
  let player: ref<PlayerPuppet>;
  let gender: CName;
  wrappedMethod(evt);
  if this.m_updatingFinalizedState {
    player = this.GetPlayerControlledObject() as PlayerPuppet;
    if IsDefined(player) && IsDefined(this.m_characterCustomizationState) {
      gender = player.GetGender();
      if Equals(gender, n"Male") || Equals(gender, n"Female") {
        this.m_characterCustomizationState.SetIsBrainGenderMale(Equals(gender, n"Male"));
        this.UpdateVoiceOverWidget();
      };
    };
  };
}

@wrapMethod(characterCreationBodyMorphMenu)
public final func ConfirmCustomizedCharacter() -> Void {
  this.cpm_voicePending = false;
  this.cpm_voicePlayer = null;
  if this.m_updatingFinalizedState && IsDefined(this.m_characterCustomizationState) {
    this.cpm_voicePlayer = this.GetPlayerControlledObject() as PlayerPuppet;
    if IsDefined(this.cpm_voicePlayer) {
      this.cpm_voiceMale = this.m_characterCustomizationState.IsBrainGenderMale();
      this.cpm_voicePending = NotEquals(this.cpm_voicePlayer.GetGender(),
        this.cpm_voiceMale ? n"Male" : n"Female");
    };
  };
  wrappedMethod();
}

@wrapMethod(characterCreationBodyMorphMenu)
protected cb func OnReFinalizeComplete(evt: ref<gameuiCharacterCustomizationSystem_OnReFinalizeStateCompleteEvent>) -> Bool {
  if this.cpm_voicePending && this.m_updatingFinalizedState
      && IsDefined(this.cpm_voicePlayer)
      && this.cpm_voicePlayer == this.GetPlayerControlledObject() as PlayerPuppet {
    this.cpm_voicePlayer.CPMCommitVoiceGender(this.cpm_voiceMale);
  };
  this.cpm_voicePending = false;
  this.cpm_voicePlayer = null;
  wrappedMethod(evt);
}

@wrapMethod(characterCreationBodyMorphMenu)
public final func ConfirmBackConfirmation() -> Void {
  this.cpm_voicePending = false;
  this.cpm_voicePlayer = null;
  wrappedMethod();
}

@wrapMethod(characterCreationBodyMorphMenu)
protected cb func OnCancelFinalizedStateUpdate(evt: ref<gameuiCharacterCustomizationSystem_OnCancelFinalizedStateUpdateEvent>) -> Bool {
  this.cpm_voicePending = false;
  this.cpm_voicePlayer = null;
  wrappedMethod(evt);
}

@wrapMethod(characterCreationBodyMorphMenu)
protected cb func OnUninitialize() -> Bool {
  this.cpm_voicePending = false;
  this.cpm_voicePlayer = null;
  wrappedMethod();
}
