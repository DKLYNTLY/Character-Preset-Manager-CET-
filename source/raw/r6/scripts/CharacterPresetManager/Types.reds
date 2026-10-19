module CPM

public class OptionSnapshot extends IScriptable {
  public let key: String;
  public let label: String;
  public let slot: String;
  public let index: Uint32;
  public let active: Bool;
  public let editable: Bool;
  public let definitions: array<String>;
  public let switches: array<String>;
  public let morphs: array<String>;
}

public class NativeRequest extends IScriptable {
  public let session: Uint64;
  public let operation: Uint64;
  public let command: String;
  public let text: String;
  public let extra: String;
  public let confirmed: Bool;
  public let unconfirmed: Bool;
  public let options: array<ref<OptionSnapshot>>;
}

public class NativeReply extends IScriptable {
  public let accepted: Bool;
  public let session: Uint64;
  public let operation: Uint64;
  public let status: String;
  public let version: String;
  public let kind: String;
  public let payload: String;
  public let position: Int32;
  public let target: Uint32;
  public let current: Uint32;
  public let key: String;
  public let slot: String;
  public let snapshotHash: Uint64;
}
