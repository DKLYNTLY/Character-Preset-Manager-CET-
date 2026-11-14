module CPM

public class LoadStepEvent extends IScriptable {
  public let now: Float;
  public let editorOpen: Bool;
  public let cancel: String;
  public let writeFailed: Bool;
  public let position: Int32;
  public let hasPosition: Bool;
  public let status: String;
  public let target: Uint32;
}

public class LoadStep extends IScriptable {
  public let kind: String;
  public let reason: String;
  public let position: Int32;
  public let target: Uint32;
}

public class LoadExecution extends IScriptable {
  private let graph: ref<LoadDependencies>;
  private let outcomes: array<String>;
  private let hasChildren: array<Bool>;
  private let cursor: Int32;
  private let started: Bool;
  private let deadline: Float;
  private let timeout: Float;
  private let stopped: String;

  public static func Create(graph: ref<LoadDependencies>, timeout: Float) -> ref<LoadExecution> {
    let job = new LoadExecution();
    job.graph = graph;
    job.timeout = timeout;
    let index: Int32 = 0;
    while index < ArraySize(graph.parents) {
      ArrayPush(job.outcomes, "");
      ArrayPush(job.hasChildren, false);
      index += 1;
    };
    index = 0;
    while index < ArraySize(graph.parents) {
      let parent: Int32 = 0;
      while parent < ArraySize(graph.parents[index].positions) {
        job.hasChildren[graph.parents[index].positions[parent]] = true;
        parent += 1;
      };
      index += 1;
    };
    return job;
  }

  private func Finish(reason: String) -> ref<LoadStep> {
    this.stopped = reason;
    let result = new LoadStep();
    result.kind = "finished";
    result.reason = reason;
    return result;
  }

  public func Step(event: ref<LoadStepEvent>) -> ref<LoadStep> {
    if StrLen(this.stopped) > 0 { return this.Finish(this.stopped); };
    if StrLen(event.cancel) > 0 { return this.Finish(event.cancel); };
    if !event.editorOpen { return this.Finish("editor-closed"); };
    if event.writeFailed { return this.Finish("write-failed"); };
    if !this.started {
      this.started = true;
      this.deadline = event.now + this.timeout;
    };
    if event.now >= this.deadline { return this.Finish("timeout"); };
    if this.cursor >= ArraySize(this.graph.ordered) { return this.Finish("complete"); };
    let position = this.graph.ordered[this.cursor];
    let result = new LoadStep();
    result.position = position;
    let parent: Int32 = 0;
    while parent < ArraySize(this.graph.parents[position].positions) {
      if NotEquals(this.outcomes[this.graph.parents[position].positions[parent]], "confirmed") {
        this.outcomes[position] = "dependency-unresolved";
        this.cursor += 1;
        result.kind = "warn";
        result.reason = "dependency-unresolved";
        return result;
      };
      parent += 1;
    };
    if !event.hasPosition || event.position != position { result.kind = "resolve"; return result; };
    this.cursor += 1;
    if Equals(event.status, "matching") {
      this.outcomes[position] = "confirmed";
      result.kind = "continue";
    } else {
      if Equals(event.status, "ready") {
        this.outcomes[position] = this.hasChildren[position] ? "confirmed" : "applied";
        result.kind = "write";
        result.target = event.target;
      } else {
        this.outcomes[position] = StrLen(event.status) > 0 ? event.status : "unresolved";
        result.kind = "warn";
        result.reason = this.outcomes[position];
      };
    };
    return result;
  }
}
