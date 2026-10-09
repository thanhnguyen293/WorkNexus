part of 'github_adapter.dart';

/// Directory lookups: users, products, repos (as projects) and executions
/// (no-oped where GitHub has no ZenTao analogue), and the per-repo assignees
/// the assignee picker offers.
mixin _GitHubDirectory on _GitHubAdapterBase {
  @override
  Future<Result<List<ProviderUser>>> listUsers() async {
    // GitHub's assignable users are repo-scoped; the assignee picker resolves
    // them through [listRepoAssignees] instead.
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
      final repos = await _client.repos();
      return [
        for (final r in repos)
          ProviderProject(
            id: r.fullName,
            name: r.display,
            accountId: accountId,
          ),
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

  /// Repo members the ticket can be assigned to. GitHub has no account-wide
  /// assignable list, so the assignee picker resolves per-repo assignees here.
  Future<Result<List<ProviderUser>>> listRepoAssignees(Ticket ticket) {
    return _guard(() async {
      final users = await _client.assignees(_repoRef(ticket));
      final seen = <String>{};
      final out = <ProviderUser>[];
      for (final u in users) {
        final login = u.login;
        if (login == null || login.isEmpty || !seen.add(login)) continue;
        out.add(ProviderUser(account: login, displayName: u.display));
      }
      out.sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
      return out;
    });
  }
}
