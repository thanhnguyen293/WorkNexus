/// Native GitHub pull-request board columns, following a PR's lifecycle
/// (draft → ready-for-review → merged / closed). Kept separate from
/// `UnifiedStatus` the same way the ZenTao/GitLab columns are.
enum GitHubPrColumn {
  draft(order: 0),
  review(order: 1),
  merged(order: 2),
  closed(order: 3);

  const GitHubPrColumn({required this.order});

  final int order;

  static List<GitHubPrColumn> get columns =>
      List.of(values)..sort((a, b) => a.order.compareTo(b.order));
}
