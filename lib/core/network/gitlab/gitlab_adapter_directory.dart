part of 'gitlab_adapter.dart';

/// Directory lookups: users, products, projects, executions (no-oped where
/// GitLab has no ZenTao analogue) and the per-project members, labels and
/// milestones the detail pickers offer.
mixin _GitLabDirectory on _GitLabAdapterBase {
  @override
  Future<Result<List<ProviderUser>>> listUsers() async {
    // The interface is account-scoped, but GitLab's assignable users are
    // project-scoped and `GET /users` is instance-wide (huge on gitlab.com).
    // The assignee picker resolves project members through a GitLab-specific
    // path instead, so this returns empty.
    return const Ok(<ProviderUser>[]);
  }

  @override
  Future<Result<List<ProviderProduct>>> listProducts() async =>
      const Ok(<ProviderProduct>[]);

  @override
  Future<Result<TicketPage>> listProductBugs(
    String productId, {
    String? browseType,
  }) async => const Ok(TicketPage(tickets: <Ticket>[]));

  @override
  Future<Result<List<ProviderProject>>> listProjects() async {
    return _guard(() async {
      final projects = await _client.projects();
      return [
        for (final p in projects)
          ProviderProject(id: '${p.id}', name: p.display, accountId: accountId),
      ];
    });
  }

  @override
  Future<Result<List<ProviderExecution>>> listProjectExecutions(
    String projectId,
  ) async => const Ok(<ProviderExecution>[]);

  @override
  Future<Result<TicketPage>> listExecutionTasks(String executionId) async =>
      const Ok(TicketPage(tickets: <Ticket>[]));

  @override
  Future<Result<List<ProviderLabelOption>>> listProjectLabels(Ticket ticket) =>
      _guard(() async {
        final labels = await _client.projectLabels(_projectRef(ticket));
        final options = [
          for (final label in labels)
            ProviderLabelOption(name: label.name, color: label.color),
        ];
        options.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        return options;
      });

  @override
  Future<Result<List<ProviderMilestoneOption>>> listProjectMilestones(
    Ticket ticket,
  ) => _guard(() async {
    final milestones = await _client.projectMilestones(_projectRef(ticket));
    return [
      for (final milestone in milestones)
        ProviderMilestoneOption(
          id: milestone.id,
          title: milestone.title ?? '#${milestone.iid ?? milestone.id}',
        ),
    ];
  });

  /// Project members the ticket can be assigned to. GitLab has no account-wide
  /// assignable list, so the assignee picker resolves per-project members here.
  @override
  Future<Result<List<ProviderUser>>> listProjectMembers(Ticket ticket) {
    return _guard(() async {
      final members = await _client.members(_projectRef(ticket));
      final seen = <String>{};
      final users = <ProviderUser>[];
      for (final m in members) {
        final account = m.username;
        if (account == null || account.isEmpty || !seen.add(account)) continue;
        users.add(
          ProviderUser(
            account: account,
            displayName: m.display,
            avatarUrl: m.avatarUrl,
          ),
        );
      }
      users.sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
      return users;
    });
  }
}
