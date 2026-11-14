module CPM

public class LoadObservation extends IScriptable {
  public let status: String;
  public let target: Uint32;
  public let hasTarget: Bool;
  public let current: Uint32;
  public let hasCurrent: Bool;
}

public class LoadVerificationEntry extends IScriptable {
  public let verified: Bool;
  public let delayed: Bool;
  public let pending: Bool;
  public let sampleCount: Int32;
  public let sampleTarget: Uint32;
  public let sampleHasTarget: Bool;
  public let result: ref<LoadObservation>;
}

public class LoadVerification extends IScriptable {
  public let generation: Int32;
  public let entries: array<ref<LoadVerificationEntry>>;

  public static func Create(count: Int32, generation: Int32) -> ref<LoadVerification> {
    let state = new LoadVerification();
    state.generation = generation;
    let position: Int32 = 0;
    while position < count {
      ArrayPush(state.entries, new LoadVerificationEntry());
      position += 1;
    };
    return state;
  }

  public func Invalidate(generation: Int32) -> Bool {
    if this.generation == generation { return false; };
    this.generation = generation;
    let position: Int32 = 0;
    while position < ArraySize(this.entries) {
      let entry = this.entries[position];
      entry.verified = false;
      entry.delayed = false;
      entry.sampleCount = 0;
      entry.pending = true;
      position += 1;
    };
    return true;
  }

  public func Observe(position: Int32, result: ref<LoadObservation>, retry: Bool) -> Void {
    let entry = this.entries[position];
    entry.result = new LoadObservation();
    entry.result.status = result.status;
    entry.result.target = result.target;
    entry.result.hasTarget = result.hasTarget;
    entry.result.current = result.current;
    entry.result.hasCurrent = result.hasCurrent;
    entry.verified = false;
    entry.delayed = false;
    if Equals(result.status, "matching") {
      if !retry {
        entry.verified = true;
        entry.pending = false;
        return;
      };
      let same = entry.sampleCount > 0 && Equals(entry.sampleHasTarget, result.hasTarget)
        && (!result.hasTarget || entry.sampleTarget == result.target);
      entry.sampleCount = same ? entry.sampleCount + 1 : 1;
      entry.sampleTarget = result.target;
      entry.sampleHasTarget = result.hasTarget;
      entry.pending = entry.sampleCount < 2;
      if !entry.pending {
        entry.verified = true;
        entry.delayed = true;
      };
    } else {
      entry.sampleCount = 0;
      entry.pending = Equals(result.status, "ready");
    };
  }

  public func Pending() -> array<Int32> {
    let positions: array<Int32>;
    let position: Int32 = 0;
    while position < ArraySize(this.entries) {
      if this.entries[position].pending { ArrayPush(positions, position); };
      position += 1;
    };
    return positions;
  }
}
