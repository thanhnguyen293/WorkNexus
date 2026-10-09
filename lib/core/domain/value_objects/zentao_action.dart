/// A status action on a ZenTao bug, in the order its toolbar shows them.
enum ZenTaoBugAction { confirm, resolve, close, activate }

/// What can be done to a ZenTao bug or task now: whether it can be reassigned,
/// and which status [actions] apply.
typedef ZenTaoActionMenu<T extends Enum> = ({bool canAssign, List<T> actions});

/// A status action on a ZenTao task, in toolbar order, and what its ZenTao
/// form asks for.
enum ZenTaoTaskAction {
  start(asksSpent: true, asksLeft: true, asksAssignee: true),
  restart(asksSpent: true, asksLeft: true, asksAssignee: true),
  pause(),
  finish(asksSpent: true, asksAssignee: true),
  activate(asksLeft: true, asksAssignee: true),
  close(),
  cancel();

  const ZenTaoTaskAction({
    this.asksSpent = false,
    this.asksLeft = false,
    this.asksAssignee = false,
  });

  /// Takes the hours worked this time (added to what is already logged).
  final bool asksSpent;

  /// Takes the hours left.
  final bool asksLeft;

  /// Takes who the task goes to next.
  final bool asksAssignee;
}
