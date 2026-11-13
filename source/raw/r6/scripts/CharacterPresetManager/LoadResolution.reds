module CPM

public class LoadIdentity extends IScriptable {
  public let kind: String;
  public let name: String;
  public let hasName: Bool;
  public let names: array<String>;
}

public class LoadChoice extends IScriptable {
  public let index: Uint32;
  public let label: String;
  public let identity: ref<LoadIdentity>;
}

public class LoadOption extends IScriptable {
  public let name: String;
  public let label: String;
  public let slot: String;
  public let active: Bool;
  public let editable: Bool;
  public let current: Uint32;
  public let choices: array<ref<LoadChoice>>;
}

public class LoadIntent extends IScriptable {
  public let internalName: String;
  public let hasInternalName: Bool;
  public let label: String;
  public let hasLabel: Bool;
  public let slot: String;
  public let hasSlot: Bool;
  public let outcome: String;
  public let reason: String;
  public let identity: ref<LoadIdentity>;
}

public class LoadResolution extends IScriptable {
  public let status: String;
  public let reason: String;
  public let position: Int32;
  public let target: Uint32;

  public static func SameIdentity(left: ref<LoadIdentity>, right: ref<LoadIdentity>) -> Bool {
    if !IsDefined(left) || !IsDefined(right) { return false; };
    if NotEquals(left.kind, right.kind) { return false; };
    if Equals(left.kind, "switcher") {
      if ArraySize(left.names) == 0 || ArraySize(left.names) != ArraySize(right.names) { return false; };
      let index: Int32 = 0;
      while index < ArraySize(left.names) {
        if NotEquals(left.names[index], right.names[index]) { return false; };
        index += 1;
      };
      return true;
    };
    return left.hasName && right.hasName && Equals(left.name, right.name);
  }

  public static func Resolve(intent: ref<LoadIntent>, catalog: array<ref<LoadOption>>) -> ref<LoadResolution> {
    let result = new LoadResolution();
    result.position = -1;
    result.status = intent.outcome;
    result.reason = intent.reason;
    if NotEquals(intent.outcome, "resolve") { return result; };
    let index: Int32 = 0;
    let matched: Int32 = -1;
    while index < ArraySize(catalog) {
      let option = catalog[index];
      let same = intent.hasInternalName && Equals(option.name, intent.internalName)
        || !intent.hasInternalName && intent.hasLabel && Equals(option.label, intent.label);
      if same && (!intent.hasSlot || Equals(option.slot, intent.slot)) {
        if matched >= 0 { result.status = "ambiguous-option"; return result; };
        matched = index;
      };
      index += 1;
    };
    if matched < 0 { result.status = "missing-option"; return result; };
    let option = catalog[matched];
    if !option.active || !option.editable { result.status = "unavailable-option"; return result; };
    let found: Bool = false;
    index = 0;
    while index < ArraySize(option.choices) {
      let choice = option.choices[index];
      let identity = choice.identity;
      if Equals(intent.identity.kind, "legacy-label") {
        identity = new LoadIdentity();
        identity.kind = "legacy-label";
        identity.name = choice.label;
        identity.hasName = true;
      };
      if LoadResolution.SameIdentity(intent.identity, identity) {
        if found { result.status = "ambiguous-choice"; return result; };
        found = true;
        result.target = choice.index;
      };
      index += 1;
    };
    if !found { result.status = "missing-choice"; return result; };
    result.position = matched;
    result.status = option.current == result.target ? "matching" : "ready";
    return result;
  }
}
