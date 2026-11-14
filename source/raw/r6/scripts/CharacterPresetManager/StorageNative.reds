public static native func CPMStorageRead(id: Uint64, session: Uint64, relative: String) -> Bool;
public static native func CPMStorageSave(id: Uint64, session: Uint64, relative: String, contents: String, fingerprint: String) -> Bool;
public static native func CPMStoragePoll() -> Bool;
public static native func CPMStorageResult(field: String) -> String;
