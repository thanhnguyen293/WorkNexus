/// Native GitHub issue board columns: open, in-progress (an open issue with a
/// "doing/wip" board label → `UnifiedStatus.inprogress`), and closed.
enum GitHubIssueColumn {
  open(order: 0),
  inProgress(order: 1),
  closed(order: 2);

  const GitHubIssueColumn({required this.order});

  final int order;

  static List<GitHubIssueColumn> get columns =>
      List.of(values)..sort((a, b) => a.order.compareTo(b.order));
}
