part of 'sync_service.dart';

/// Account syncs, the sidebar source lists and the per-source board slices
/// ([SourceSyncService]).
mixin _SourceSync on _SyncCore {
  /// Returns the number of tickets synced, or a [Failure].
  @override
  Future<Result<int>> syncAccount(Account account) async {
    final ref = account.credentialsRef;
    if (ref == null) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final secret = await _credentials.read(ref);
    if (secret == null) {
      return const Err(AuthFailure('Stored credentials not found in keychain'));
    }
    final adapter = _buildAdapter(account, secret);
    if (adapter == null) {
      return Err(
        UnexpectedFailure(
          '${account.providerType.displayName} sync is not implemented yet',
        ),
      );
    }

    final res = await adapter.listAssignedTickets();
    switch (res) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        await _upsert(account, value.tickets);
        return Ok(value.tickets.length);
    }
  }

  @override
  Future<Result<List<ProviderProduct>>> listProducts(String accountId) async {
    final adapter = await _adapterFor(accountId);
    if (adapter == null) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    return adapter.listProducts();
  }

  Future<Result<int>> syncProductBugs(ProviderProduct product) async {
    final accountRow = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(product.accountId))).getSingleOrNull();
    if (accountRow == null) {
      return const Err(AuthFailure('ZenTao account not found'));
    }
    final account = accountFromRow(accountRow);
    final adapter = await _adapterFor(product.accountId);
    if (adapter == null) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final res = await adapter.listProductBugs(product.id);
    switch (res) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        await _upsert(account, value.tickets);
        return Ok(value.tickets.length);
    }
  }

  /// Fetches one ZenTao bug **tab** ([browseType]) for a product — a server-side
  /// filtered view (unclosed / assigned-to-me / resolved-by-me / …) — upserts
  /// its bugs into drift (local-first: the board still renders from the DB), and
  /// returns the ids of the bugs in that tab so the board can show just that
  /// slice. Successful tab slices are cached briefly per account/product/tab so
  /// switching back and forth does not immediately hit ZenTao again.
  @override
  Future<Result<List<String>>> syncProductBugsTab({
    required String accountId,
    required String productId,
    required String browseType,
  }) async {
    final cacheKey = '$accountId:$productId:$browseType';
    return _cached(
      cache: _zentaoBugTabCache,
      key: cacheKey,
      load: () => _syncProductBugsTabUncached(
        accountId: accountId,
        productId: productId,
        browseType: browseType,
      ),
    );
  }

  /// Drops the cached slice for one bug tab so the next [syncProductBugsTab]
  /// goes to the server — a manual board refresh must not replay a TTL-cached
  /// answer.
  @override
  void invalidateProductBugsTab({
    required String accountId,
    required String productId,
    required String browseType,
  }) => _zentaoBugTabCache.invalidate('$accountId:$productId:$browseType');

  Future<Result<List<String>>> _syncProductBugsTabUncached({
    required String accountId,
    required String productId,
    required String browseType,
  }) async {
    final accountRow = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (accountRow == null) {
      return const Err(AuthFailure('ZenTao account not found'));
    }
    final account = accountFromRow(accountRow);
    final adapter = await _adapterFor(accountId);
    if (adapter == null) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final res = await adapter.listProductBugs(
      productId,
      browseType: browseType,
    );
    switch (res) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        await _upsert(account, value.tickets);
        return Ok([for (final t in value.tickets) t.id]);
    }
  }

  @override
  Future<Result<List<ProviderProject>>> listProjects(String accountId) async {
    final adapter = await _adapterFor(accountId);
    if (adapter == null) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    return adapter.listProjects();
  }

  @override
  Future<Result<List<ProviderExecution>>> listProjectExecutions(
    String accountId,
    String projectId,
  ) async {
    final adapter = await _adapterFor(accountId);
    if (adapter == null) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    return adapter.listProjectExecutions(projectId);
  }

  @override
  Future<Result<int>> syncExecutionTasks(ProviderExecution execution) async {
    final cacheKey = '${execution.accountId}:${execution.id}';
    return _cached(
      cache: _zentaoExecutionTaskCache,
      key: cacheKey,
      load: () => _syncExecutionTasksUncached(execution),
    );
  }

  /// Drops the cached task slice for one execution so the next
  /// [syncExecutionTasks] goes to the server (manual board refresh).
  @override
  void invalidateExecutionTasks({
    required String accountId,
    required String executionId,
  }) => _zentaoExecutionTaskCache.invalidate('$accountId:$executionId');

  Future<Result<int>> _syncExecutionTasksUncached(
    ProviderExecution execution,
  ) async {
    final accountRow = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(execution.accountId))).getSingleOrNull();
    if (accountRow == null) {
      return const Err(AuthFailure('ZenTao account not found'));
    }
    final account = accountFromRow(accountRow);
    final adapter = await _adapterFor(execution.accountId);
    if (adapter == null) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final res = await adapter.listExecutionTasks(execution.id);
    switch (res) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        await _upsert(account, value.tickets);
        return Ok(value.tickets.length);
    }
  }

  Future<Result<T>> _cached<T>({
    required TimedSliceCache<T> cache,
    required String key,
    required Future<Result<T>> Function() load,
  }) async {
    try {
      final value = await cache.get(key, () async {
        final res = await load();
        return switch (res) {
          Ok(:final value) => value,
          Err(:final failure) => throw _CachedLoadFailure(failure),
        };
      });
      return Ok(value);
    } on _CachedLoadFailure catch (err) {
      return Err(err.failure);
    }
  }

  /// Fetches one GitLab project's recent issues OR merge requests (chosen by
  /// [mergeRequests]), tags each with a synthetic `gitlab-project:<id>` label,
  /// upserts them into drift (local-first), and returns their ids so the board
  /// renders just that slice. Mirrors [syncProductBugsTab] for GitLab; routes
  /// through the concrete [GitLabAdapter] (GitLab-specific fetch, not on the
  /// shared interface).
  @override
  Future<Result<List<String>>> syncGitLabProjectItems({
    required String accountId,
    required String projectId,
    required bool mergeRequests,
  }) async {
    final accountRow = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (accountRow == null) {
      return const Err(AuthFailure('GitLab account not found'));
    }
    final account = accountFromRow(accountRow);
    final adapter = await _adapterFor(accountId);
    if (adapter is! GitLabAdapter) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final res = await adapter.listProjectItems(
      projectId,
      kind: mergeRequests ? GitLabKind.mergeRequest : GitLabKind.issue,
    );
    switch (res) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final label = gitlabProjectLabel(projectId);
        final tagged = [
          for (final t in value) t.copyWith(labels: [...t.labels, label]),
        ];
        await _upsert(account, tagged);
        return Ok([for (final t in tagged) t.id]);
    }
  }

  /// Fetches one GitHub repo's recent issues OR pull requests (chosen by
  /// [pullRequests]), tags each with a synthetic `github-repo:<repo>` label,
  /// upserts them into drift (local-first), and returns their ids so the board
  /// renders just that slice. Mirrors [syncGitLabProjectItems] for GitHub; routes
  /// through the concrete [GitHubAdapter] (GitHub-specific fetch, not on the
  /// shared interface). [repoId] is the `owner/name` slug.
  @override
  Future<Result<List<String>>> syncGitHubRepoItems({
    required String accountId,
    required String repoId,
    required bool pullRequests,
  }) async {
    final accountRow = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (accountRow == null) {
      return const Err(AuthFailure('GitHub account not found'));
    }
    final account = accountFromRow(accountRow);
    final adapter = await _adapterFor(accountId);
    if (adapter is! GitHubAdapter) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final res = await adapter.listRepoItems(
      repoId,
      kind: pullRequests ? GitHubKind.pullRequest : GitHubKind.issue,
    );
    switch (res) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final label = githubRepoLabel(repoId);
        final tagged = [
          for (final t in value) t.copyWith(labels: [...t.labels, label]),
        ];
        await _upsert(account, tagged);
        return Ok([for (final t in tagged) t.id]);
    }
  }

  /// Fetches the current user's assigned + review-requested merge requests across
  /// all GitLab projects (the "my merge requests" board), tags each with a
  /// synthetic `gitlab-mine:<accountId>` label, upserts them into drift, and
  /// returns their ids. The label lets the board render this slice from the DB
  /// when offline (the slice id set reconciles it once a sync succeeds).
  @override
  Future<Result<List<String>>> syncGitLabMine(String accountId) async {
    final accountRow = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (accountRow == null) {
      return const Err(AuthFailure('GitLab account not found'));
    }
    final account = accountFromRow(accountRow);
    final adapter = await _adapterFor(accountId);
    if (adapter is! GitLabAdapter) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final res = await adapter.listMyMergeRequests();
    switch (res) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final label = gitlabMineLabel(accountId);
        final tagged = [
          for (final t in value) t.copyWith(labels: [...t.labels, label]),
        ];
        await _upsert(account, tagged);
        return Ok([for (final t in tagged) t.id]);
    }
  }

  /// Fetches the current user's assigned + review-requested pull requests across
  /// all GitHub repos (the "my pull requests" board), tags each with a synthetic
  /// `github-mine:<accountId>` label, upserts them, and returns their ids. The
  /// label lets the board render this slice from the DB when offline (the slice
  /// id set reconciles it once a sync succeeds).
  @override
  Future<Result<List<String>>> syncGitHubMine(String accountId) async {
    final accountRow = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (accountRow == null) {
      return const Err(AuthFailure('GitHub account not found'));
    }
    final account = accountFromRow(accountRow);
    final adapter = await _adapterFor(accountId);
    if (adapter is! GitHubAdapter) {
      return const Err(AuthFailure('No stored credentials for this account'));
    }
    final res = await adapter.listMyPullRequests();
    switch (res) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final label = githubMineLabel(accountId);
        final tagged = [
          for (final t in value) t.copyWith(labels: [...t.labels, label]),
        ];
        await _upsert(account, tagged);
        return Ok([for (final t in tagged) t.id]);
    }
  }
}

class _CachedLoadFailure implements Exception {
  const _CachedLoadFailure(this.failure);

  final Failure failure;
}
