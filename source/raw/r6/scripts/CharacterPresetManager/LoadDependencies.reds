module CPM

public class LoadParents extends IScriptable {
  public let positions: array<Int32>;
}

public class LoadDependencies extends IScriptable {
  public let ordered: array<Int32>;
  public let parents: array<ref<LoadParents>>;
  public let cyclic: array<Int32>;

  public static func Build(intents: array<ref<LoadIntent>>) -> ref<LoadDependencies> {
    let result = new LoadDependencies();
    let emitted: array<Bool>;
    let position: Int32 = 0;
    while position < ArraySize(intents) {
      ArrayPush(result.parents, new LoadParents());
      ArrayPush(emitted, false);
      position += 1;
    };
    position = 0;
    while position < ArraySize(intents) {
      let intent = intents[position];
      if Equals(intent.outcome, "resolve") && IsDefined(intent.identity) {
        if Equals(intent.identity.kind, "switcher") {
          let nameIndex: Int32 = 0;
          while nameIndex < ArraySize(intent.identity.names) {
            let child: Int32 = 0;
            while child < ArraySize(intents) {
              if child != position && intents[child].hasInternalName
                && Equals(intents[child].internalName, intent.identity.names[nameIndex])
                && Equals(intents[child].outcome, "resolve") {
                if !ArrayContains(result.parents[child].positions, position) {
                  ArrayPush(result.parents[child].positions, position);
                };
              };
              child += 1;
            };
            nameIndex += 1;
          };
        };
      };
      position += 1;
    };
    let pass: Int32 = 0;
    while pass < ArraySize(intents) {
      let progressed: Bool = false;
      position = 0;
      while position < ArraySize(intents) {
        if !emitted[position] {
          let blocked: Bool = false;
          let parent: Int32 = 0;
          while parent < ArraySize(result.parents[position].positions) {
            if !emitted[result.parents[position].positions[parent]] { blocked = true; };
            parent += 1;
          };
          if !blocked {
            emitted[position] = true;
            ArrayPush(result.ordered, position);
            progressed = true;
          };
        };
        position += 1;
      };
      if !progressed { break; };
      pass += 1;
    };
    position = 0;
    while position < ArraySize(intents) {
      if !emitted[position] { ArrayPush(result.cyclic, position); };
      position += 1;
    };
    return result;
  }
}
