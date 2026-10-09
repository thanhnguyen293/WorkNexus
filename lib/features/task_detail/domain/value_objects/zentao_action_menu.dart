/// What can be done to a ZenTao bug or task now: whether it can be reassigned,
/// and which status [actions] apply.
typedef ZenTaoActionMenu<T extends Enum> = ({bool canAssign, List<T> actions});
