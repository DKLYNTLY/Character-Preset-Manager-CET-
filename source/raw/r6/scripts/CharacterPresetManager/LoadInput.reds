module CPM

public class LoadInput extends IScriptable {
  public static func Decode(payload: String) -> array<ref<LoadIntent>> {
    let intents: array<ref<LoadIntent>>;
    let lines = StrSplit(payload, "\n", false);
    let index: Int32 = 0;
    while index < ArraySize(lines) {
      let fields = StrSplit(lines[index], "\t", true);
      if ArraySize(fields) >= 5 {
        let intent = new LoadIntent();
        intent.slot = fields[0];
        intent.hasSlot = NotEquals(fields[0], "[unavailable]");
        intent.internalName = fields[1];
        intent.hasInternalName = NotEquals(fields[1], "[unavailable]");
        intent.label = fields[3];
        intent.hasLabel = StrLen(fields[3]) > 0;
        intent.outcome = "unresolved";
        let identity = new LoadIdentity();
        if Equals(fields[2], "Appearance") { identity.kind = "appearance"; };
        if Equals(fields[2], "Morph") { identity.kind = "morph"; };
        if Equals(fields[2], "Legacy label") { identity.kind = "legacy-label"; };
        if Equals(fields[2], "Switcher") {
          identity.kind = "switcher";
          let member: Int32 = 4;
          while member < ArraySize(fields) {
            ArrayPush(identity.names, fields[member]);
            member += 1;
          };
        };
        if StrLen(identity.kind) > 0 && (intent.hasInternalName || intent.hasLabel) {
          identity.name = fields[4];
          identity.hasName = true;
          intent.identity = identity;
          intent.outcome = "resolve";
        };
        ArrayPush(intents, intent);
      };
      index += 1;
    };
    return intents;
  }
}
