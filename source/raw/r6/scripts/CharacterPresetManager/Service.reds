public static native func CPMNativeStatus() -> String
public static native func CPMNativeBegin() -> Uint64
public static native func CPMNativeClose(session: Uint64) -> Bool
public static native func CPMNativeSubmit(session: Uint64, action: String, payload: String) -> String
public static native func CPMNativePoll(session: Uint64, operation: Uint64, consume: Bool) -> String
public static native func CPMNativeCancel(session: Uint64, operation: Uint64) -> String
public static native func CPMNativeEndAppearance(session: Uint64, operation: Uint64) -> String
