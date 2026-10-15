/// What can be done to a ZenTao bug or task now: whether it can be reassigned,
/// which status [actions] apply, and the one that moves it on — the detail
/// header's main button (null when no action is the obvious next step).
typedef ZenTaoActionMenu<T extends Enum> = ({
  bool canAssign,
  List<T> actions,
  T? primary,
});
