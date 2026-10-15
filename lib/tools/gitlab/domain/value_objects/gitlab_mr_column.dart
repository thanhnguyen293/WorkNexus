/// Native GitLab merge-request board columns, following an MR's lifecycle
/// (draft → ready-for-review → merged / closed). Kept separate from
/// `UnifiedStatus` the same way the ZenTao bug columns are.
enum GitLabMrColumn {
  draft(order: 0),
  review(order: 1),
  merged(order: 2),
  closed(order: 3);

  const GitLabMrColumn({required this.order});

  final int order;

  static List<GitLabMrColumn> get columns =>
      List.of(values)..sort((a, b) => a.order.compareTo(b.order));
}
