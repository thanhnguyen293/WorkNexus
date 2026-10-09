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
