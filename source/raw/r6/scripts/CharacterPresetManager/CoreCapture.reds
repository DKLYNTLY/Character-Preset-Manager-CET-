module CPM

public class CoreCapture extends IScriptable {
  public static func Capture(system: ref<gameuiICharacterCustomizationSystem>, presetName: String) -> String {
    let intents: array<ref<LoadIntent>>;
    return CoreCapture.Snapshot(system, presetName, intents);
  }

  public static func Snapshot(system: ref<gameuiICharacterCustomizationSystem>, presetName: String, out intents: array<ref<LoadIntent>>) -> String {
    let catalog = LoadGameAdapter.Read(system);
    let state = system.GetState();
    let body = "Unknown";
    let voice = "Unknown";
    if IsDefined(state) {
      body = state.IsBodyGenderMale() ? "Male" : "Female";
      voice = state.IsBrainGenderMale() ? "Male" : "Female";
    };
    let result = "# CPM Preset\n# Format: 9\n# Name: " + presetName
      + "\n# Source body: " + body + "\n# Source voice: " + voice + "\n";
    let count: Int32 = 0;
    let position: Int32 = 0;
    while position < ArraySize(catalog) {
      let option = catalog[position];
      let slot = StrLen(option.slot) > 0 && StrLen(option.slot) <= 256 ? option.slot : "[unavailable]";
      let name = StrLen(option.name) > 0 && StrLen(option.name) <= 256 ? option.name : "[unavailable]";
      let occurrence: Int32 = 1;
      let duplicate: Bool = false;
      let other: Int32 = 0;
      while other < ArraySize(catalog) {
        if other != position && Equals(catalog[other].name, option.name) && Equals(catalog[other].slot, option.slot) {
          duplicate = true;
          if other < position { occurrence += 1; };
        };
        other += 1;
      };
      let captured: Bool = false;
      if option.active && option.editable && !duplicate && NotEquals(name, "[unavailable]") && NotEquals(slot, "[unavailable]") {
        let current = Cast<Int32>(option.current);
        if current >= 0 && current < ArraySize(option.choices) {
          let identity = option.choices[current].identity;
          let matches: Int32 = 0;
          let choice: Int32 = 0;
          while choice < ArraySize(option.choices) {
            if LoadResolution.SameIdentity(identity, option.choices[choice].identity) { matches += 1; };
            choice += 1;
          };
          if matches == 1 {
            let kind: String;
            let identities: String;
            if Equals(identity.kind, "switcher") {
              kind = "Switcher";
              let member: Int32 = 0;
              while member < ArraySize(identity.names) {
                identities += "# Choice identity: " + identity.names[member] + "\n";
                member += 1;
              };
            } else {
              kind = Equals(identity.kind, "morph") ? "Morph" : "Appearance";
              identities = "# Choice identity: " + identity.name + "\n";
            };
            let label = option.choices[current].label;
            let selected = Equals(kind, "Switcher") && Equals(label, "Common-Off") ? "Off" : "Selected";
            let details = "# Detail unavailable: localized_name\n";
            if StrLen(label) <= 1024 && !StrContains(label, "\n") && !StrContains(label, "\r") && !StrContains(label, "\t") {
              details = "# Localized name: " + label + "\n";
            };
            if Equals(kind, "Appearance") {
              details += "# Detail unavailable: tags\n# Detail unavailable: actions\n";
            };
            result += "# Editor slot: " + slot + "\n# Option name: " + name
              + "\n# Option occurrence: " + ToString(occurrence) + "\n# Selection state: " + selected + "\n# Identity kind: "
              + kind + "\n" + identities + "# Source active: true\n# Source editable: true\n# Source value: "
              + ToString(option.current) + "\n" + details + "\n";
            count += 1;
            captured = true;
            let intent = new LoadIntent();
            intent.internalName = name;
            intent.hasInternalName = true;
            intent.slot = slot;
            intent.hasSlot = true;
            intent.identity = identity;
            intent.outcome = "resolve";
            ArrayPush(intents, intent);
          };
        };
      };
      if !captured {
        let rosterState = option.active ? "Not captured" : "Inactive";
        let reason = "No supported unique choice identity.";
        if !option.active { reason = "Inactive option. Choice was not captured."; }
        else {
          if !option.editable { reason = "Option is not editable."; }
          else { if duplicate { reason = "Duplicate option identity."; }; };
        };
        result += "# Roster\t" + slot + "\t" + name + "\t" + ToString(occurrence) + "\t" + rosterState
          + "\t" + (option.active ? "true" : "false") + "\t" + ToString(option.current) + "\t\t"
          + (option.editable ? "true" : "false") + "\t" + reason + "\n";
      };
      position += 1;
    };
    return count > 0 ? result : "";
  }
}
