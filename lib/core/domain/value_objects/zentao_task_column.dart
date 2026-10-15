/// Native ZenTao task board columns.
///
/// Separate from `UnifiedStatus` because ZenTao task lifecycle distinguishes
/// finished-but-unclosed tasks from closed and canceled tasks.
enum ZenTaoTaskColumn {
  notStarted(order: 0, browseType: 'wait'),
  inProgress(order: 1, browseType: 'doing'),
  paused(order: 2, browseType: 'pause'),
  doneVerify(order: 3, browseType: 'done'),
  closed(order: 4, browseType: 'closed'),
  canceled(order: 5, browseType: 'cancel');

  const ZenTaoTaskColumn({required this.order, required this.browseType});

  final int order;

  /// The ZenTao task status view (`execution-task` browse type) holding exactly
  /// this column's tasks, so each column pages its own view.
  final String browseType;

  static List<ZenTaoTaskColumn> get columns =>
      List.of(values)..sort((a, b) => a.order.compareTo(b.order));
}
