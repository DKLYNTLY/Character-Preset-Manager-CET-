module CPM

@addMethod(inkPreviewGameController)
public func CPMIsCharacterCreationPreview() -> Bool {
  return IsDefined(this as inkCharacterCreationPuppetPreviewGameController);
}
