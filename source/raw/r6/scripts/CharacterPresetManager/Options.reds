public native class CPMOptionCatalog extends IScriptable {
  public static native func Ready() -> Int32;
  public static native func Clear() -> Void;
  public static native func Invalidate(option: ref<CharacterCustomizationOption>) -> Void;
  public static native func Warm(options: array<ref<CharacterCustomizationOption>>, budget: Int32) -> Int32;
  public static native func Match(option: ref<CharacterCustomizationOption>, choice: String) -> Int32;
  public static native func Matches(option: ref<CharacterCustomizationOption>, choice: String, index: Int32) -> Bool;
  public static native func Cleanup(option: ref<CharacterCustomizationOption>) -> Int32;
  public static native func Role(option: ref<CharacterCustomizationOption>) -> Int32;
  public static native func Statistics() -> String;
}
