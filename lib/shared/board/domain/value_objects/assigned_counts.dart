/// How many open tickets are assigned to the account's own user, for every
/// node of the sources tree. A parent is the sum of the children it shows, so
/// each ticket is counted once on its way up: a pinned product, execution or
/// project counts toward "Pinned", not toward its group.
class AssignedCounts {
  const AssignedCounts([this._counts = const {}]);

  final Map<String, int> _counts;

  static const empty = AssignedCounts();

  int _of(String key) => _counts[key] ?? 0;

  /// Every workspace together (the tree's root).
  int get total => _of(totalKey);
  int workspace(String id) => _of(workspaceKey(id));
  int account(String accountId) => _of(accountKey(accountId));
  int pinned(String accountId) => _of(pinnedKey(accountId));

  /// ZenTao: the "Bugs" group, its products, the "Tasks" group, its projects
  /// and their executions.
  int zentaoBugs(String accountId) => _of(zentaoBugsKey(accountId));
  int zentaoProduct(String accountId, String productId) =>
      _of(zentaoProductKey(accountId, productId));
  int zentaoTasks(String accountId) => _of(zentaoTasksKey(accountId));
  int zentaoProject(String accountId, String projectId) =>
      _of(zentaoProjectKey(accountId, projectId));
  int zentaoExecution(String accountId, String executionId) =>
      _of(zentaoExecutionKey(accountId, executionId));

  /// GitLab / GitHub: the "Projects" / "Repositories" group ([projects]) and
  /// one project or repository.
  int projects(String accountId) => _of(projectsKey(accountId));
  int project(String accountId, String projectId) =>
      _of(projectKey(accountId, projectId));

  static const totalKey = 'total';
  static String workspaceKey(String id) => 'workspace:$id';
  static String accountKey(String a) => 'account:$a';
  static String pinnedKey(String a) => 'pinned:$a';
  static String zentaoBugsKey(String a) => 'bugs:$a';
  static String zentaoProductKey(String a, String id) => 'product:$a:$id';
  static String zentaoTasksKey(String a) => 'tasks:$a';
  static String zentaoProjectKey(String a, String id) => 'zproject:$a:$id';
  static String zentaoExecutionKey(String a, String id) => 'execution:$a:$id';
  static String projectsKey(String a) => 'projects:$a';
  static String projectKey(String a, String id) => 'project:$a:$id';
}
