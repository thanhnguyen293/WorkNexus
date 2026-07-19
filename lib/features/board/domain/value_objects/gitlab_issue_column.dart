/// Native GitLab issue board columns: open, in-progress (an open issue with a
/// "doing/wip" board label → `UnifiedStatus.inprogress`), and closed.
enum GitLabIssueColumn {
  open(order: 0),
  inProgress(order: 1),
  closed(order: 2);

  const GitLabIssueColumn({required this.order});

  final int order;

  static List<GitLabIssueColumn> get columns =>
      List.of(values)..sort((a, b) => a.order.compareTo(b.order));
}
