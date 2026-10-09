part of 'zentao_adapter.dart';

/// Catalog reads: the user directory, the paged product / project / execution
/// lists, and the product-bug and execution-task board slices.
mixin _ZenTaoCatalog on _ZenTaoAdapterBase {
  @override
  Future<Result<List<ProviderUser>>> listUsers() async {
    return _guard(() async {
      final res = await _client.api.users(1000);
      final users = <ProviderUser>[];
      for (final u in res.users) {
        final account = u.account ?? '';
        if (account.isEmpty) continue;
        final realname = u.realname;
        users.add(
          ProviderUser(
            account: account,
            displayName: (realname == null || realname.isEmpty)
                ? account
                : realname,
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

  @override
  Future<Result<List<ProviderProduct>>> listProducts() async {
    return _guard(() async {
      const limit = kDefaultApiPageLimit;
      final out = <ProviderProduct>[];
      final seen = <String>{};
      var total = 0;
      for (var page = 1; page <= 50; page++) {
        final res = await _client.products(page: page, limit: limit);
        if (res.total > 0) total = res.total;
        var added = 0;
        for (final product in res.products) {
          if (product.id.isEmpty || !seen.add(product.id)) continue;
          out.add(
            ProviderProduct(
              id: product.id,
              name: product.name.isEmpty ? product.id : product.name,
              accountId: accountId,
            ),
          );
          added++;
        }
        if (added == 0) break;
        if (total > 0 && out.length >= total) break;
      }
      return out;
    });
  }

  @override
  Future<Result<TicketPage>> listProductBugs(
    String productId, {
    String? browseType,
  }) async {
    return _guard(() async {
      const limit = kDefaultApiPageLimit;
      final out = <Ticket>[];
      final seen = <String>{};
      var total = 0;
      for (var page = 1; page <= 50; page++) {
        // REST v1 ignores `browseType`, so the tab views go through the classic
        // `bug-browse-…json` channel; a null browseType keeps the plain REST list.
        final res = (browseType == null || browseType.isEmpty)
            ? await _client.productBugs(productId, page: page, limit: limit)
            : await _client.classicProductBugs(
                productId,
                browseType: browseType,
                pageID: page,
              );
        if (res.total > 0) total = res.total;
        var added = 0;
        for (final bug in res.bugs) {
          final id = bug.idString;
          if (id.isEmpty || !seen.add(id)) continue;
          final ticket = normalizeZenTao(
            bug,
            type: ZenTaoType.bug,
            accountId: accountId,
            baseUrl: _client.baseUrl,
          );
          out.add(
            ticket.copyWith(
              labels: [...ticket.labels, zentaoProductLabel(productId)],
            ),
          );
          added++;
        }
        if (added == 0) break;
        if (total > 0 && out.length >= total) break;
      }
      final maxUpdated = out
          .map((t) => t.updatedAt)
          .whereType<DateTime>()
          .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
      return TicketPage(
        tickets: out,
        nextCursor: maxUpdated?.toIso8601String(),
      );
    });
  }

  @override
  Future<Result<List<ProviderProject>>> listProjects() async {
    return _guard(() async {
      const limit = kDefaultApiPageLimit;
      final out = <ProviderProject>[];
      final seen = <String>{};
      var total = 0;
      for (var page = 1; page <= 50; page++) {
        final res = await _client.projects(page: page, limit: limit);
        if (res.total > 0) total = res.total;
        var added = 0;
        for (final project in res.projects) {
          if (project.id.isEmpty || !seen.add(project.id)) continue;
          out.add(
            ProviderProject(
              id: project.id,
              name: project.name.isEmpty ? project.id : project.name,
              accountId: accountId,
            ),
          );
          added++;
        }
        if (added == 0) break;
        if (total > 0 && out.length >= total) break;
      }
      return out;
    });
  }

  @override
  Future<Result<List<ProviderExecution>>> listProjectExecutions(
    String projectId,
  ) async {
    return _guard(() async {
      const limit = kDefaultApiPageLimit;
      final out = <ProviderExecution>[];
      final seen = <String>{};
      var total = 0;
      for (var page = 1; page <= 50; page++) {
        final res = await _client.projectExecutions(
          projectId,
          page: page,
          limit: limit,
        );
        if (res.total > 0) total = res.total;
        var added = 0;
        for (final execution in res.executions) {
          if (execution.id.isEmpty || !seen.add(execution.id)) continue;
          out.add(
            ProviderExecution(
              id: execution.id,
              name: execution.name.isEmpty ? execution.id : execution.name,
              projectId: projectId,
              accountId: accountId,
            ),
          );
          added++;
        }
        if (added == 0) break;
        if (total > 0 && out.length >= total) break;
      }
      return out;
    });
  }

  @override
  Future<Result<TicketPage>> listExecutionTasks(String executionId) async {
    return _guard(() async {
      const limit = kDefaultApiPageLimit;
      final out = <Ticket>[];
      final seen = <String>{};
      var total = 0;
      for (var page = 1; page <= 50; page++) {
        final res = await _client.executionTasks(
          executionId,
          page: page,
          limit: limit,
        );
        if (res.total > 0) total = res.total;
        var added = 0;
        for (final task in res.tasks) {
          final id = task.idString;
          if (id.isEmpty || !seen.add(id)) continue;
          final ticket = normalizeZenTao(
            task,
            type: ZenTaoType.task,
            accountId: accountId,
            baseUrl: _client.baseUrl,
          );
          out.add(
            ticket.copyWith(
              labels: [...ticket.labels, zentaoExecutionLabel(executionId)],
            ),
          );
          added++;
        }
        if (added == 0) break;
        if (total > 0 && out.length >= total) break;
      }
      final maxUpdated = out
          .map((t) => t.updatedAt)
          .whereType<DateTime>()
          .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
      return TicketPage(
        tickets: out,
        nextCursor: maxUpdated?.toIso8601String(),
      );
    });
  }
}
