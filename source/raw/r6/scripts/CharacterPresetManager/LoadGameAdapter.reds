module CPM

public class LoadGameAdapter extends IScriptable {
  public static func Read(system: ref<gameuiICharacterCustomizationSystem>) -> array<ref<LoadOption>> {
    let catalog: array<ref<LoadOption>>;
    let options = system.GetUnitedOptions(true, true, true);
    let position: Int32 = 0;
    while position < ArraySize(options) {
      let source = options[position];
      let option = new LoadOption();
      option.name = NameToString(source.info.name);
      option.slot = NameToString(source.info.uiSlot);
      option.current = source.currIndex;
      option.active = source.isActive;
      option.editable = source.isEditable;
      let appearance = source.info as gameuiAppearanceInfo;
      let morph = source.info as gameuiMorphInfo;
      let switcher = source.info as gameuiSwitcherInfo;
      let index: Int32 = 0;
      if IsDefined(appearance) {
        while index < ArraySize(appearance.definitions) {
          let choice = new LoadChoice();
          choice.index = Cast<Uint32>(index);
          choice.identity = new LoadIdentity();
          choice.identity.kind = "appearance";
          choice.identity.name = NameToString(appearance.definitions[index].name);
          choice.identity.hasName = true;
          ArrayPush(option.choices, choice);
          index += 1;
        };
      } else {
        if IsDefined(morph) {
          while index < ArraySize(morph.morphNames) {
            let choice = new LoadChoice();
            choice.index = Cast<Uint32>(index);
            choice.identity = new LoadIdentity();
            choice.identity.kind = "morph";
            choice.identity.name = NameToString(morph.morphNames[index].morphName);
            choice.identity.hasName = true;
            ArrayPush(option.choices, choice);
            index += 1;
          };
        } else {
          if IsDefined(switcher) {
            while index < ArraySize(switcher.options) {
              let choice = new LoadChoice();
              choice.index = Cast<Uint32>(index);
              choice.identity = new LoadIdentity();
              choice.identity.kind = "switcher";
              let member: Int32 = 0;
              while member < ArraySize(switcher.options[index].names) {
                ArrayPush(choice.identity.names, NameToString(switcher.options[index].names[member]));
                member += 1;
              };
              ArrayPush(option.choices, choice);
              index += 1;
            };
          };
        };
      };
      ArrayPush(catalog, option);
      position += 1;
    };
    return catalog;
  }
}
