/// Native ZenTao task board columns.
///
/// Separate from `UnifiedStatus` because ZenTao task lifecycle distinguishes
/// finished-but-unclosed tasks from closed and canceled tasks.
enum ZenTaoTaskColumn {
  notStarted(order: 0),
  inProgress(order: 1),
  paused(order: 2),
  doneVerify(order: 3),
  closed(order: 4),
  canceled(order: 5);

  const ZenTaoTaskColumn({required this.order});

  final int order;

  static List<ZenTaoTaskColumn> get columns =>
      List.of(values)..sort((a, b) => a.order.compareTo(b.order));
}
