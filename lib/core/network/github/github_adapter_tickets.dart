part of 'github_adapter.dart';

/// Ticket reads: the connection check, the assigned-ticket sync, a single
/// issue/PR detail, its comments and event activity, and the GitHub-specific
/// repo / "my pull requests" board slices.
mixin _GitHubTicketReads on _GitHubAdapterBase {
  @override
  Future<Result<ConnectionCheck>> testConnection() async {
    return _guard(() async {
      final user = await _client.currentUser();
      return ConnectionCheck(ok: true, account: user.login);
    });
  }

  @override
  Future<Result<TicketPage>> listAssignedTickets({String? sinceCursor}) async {
    return _guard(() async {
      final issues = await _client.assignedIssues();
      final assignedPulls = await _client.assignedPulls();
      final reviewPulls = await _client.reviewPulls();

      // Dedupe by unified ticket id (a PR can be both assigned to me and
      // awaiting my review).
      final byId = <String, Ticket>{};
      for (final i in issues) {
        final t = normalizeGitHubIssue(i, accountId: accountId);
        byId[t.id] = t;
      }
      for (final p in [...assignedPulls, ...reviewPulls]) {
        final t = normalizeGitHubPullFromIssue(p, accountId: accountId);
        byId[t.id] = t;
      }
      final tickets = byId.values.toList();

      final cursor = sinceCursor == null
          ? null
          : DateTime.tryParse(sinceCursor);
      final filtered = cursor == null
          ? tickets
          : tickets
                .where(
                  (t) => t.updatedAt == null || t.updatedAt!.isAfter(cursor),
                )
                .toList();
      final maxUpdated = tickets
          .map((t) => t.updatedAt)
          .whereType<DateTime>()
          .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
      return TicketPage(
        tickets: filtered,
        nextCursor: maxUpdated?.toIso8601String(),
      );
    });
  }

  @override
  Future<Result<Ticket>> getTicket(Ticket ticket) async {
    return _guard(() async {
      final ref = _repoRef(ticket);
      if (_kindOf(ticket) == GitHubKind.issue) {
        final issue = await _client.issue(ref, ticket.externalKey);
        return normalizeGitHubIssue(issue, accountId: accountId, repoPath: ref);
      }
      final pull = await _client.pull(ref, ticket.externalKey);
      return normalizeGitHubPull(pull, accountId: accountId, repoPath: ref);
    });
  }

  @override
  Future<Result<List<Comment>>> listComments(Ticket ticket) async {
    return _guard(() async {
      final ref = _repoRef(ticket);
      final notes = await _client.issueComments(ref, ticket.externalKey);
      final comments = <Comment>[];
      for (final n in notes) {
        final body = n.body ?? '';
        if (body.trim().isEmpty) continue;
        comments.add(
          Comment(
            id: '${ticket.id}:${n.id}',
            ticketId: ticket.id,
            authorName: n.user?.display ?? 'unknown',
            body: body,
            createdAt: parseGitHubDate(n.createdAt) ?? DateTime.now(),
          ),
        );
      }
      return comments;
    });
  }

  @override
  Future<Result<Comment>> postComment(Ticket ticket, String body) async {
    return _guard(() async {
      final ref = _repoRef(ticket);
      final note = await _client.postIssueComment(
        ref,
        ticket.externalKey,
        body,
      );
      return Comment(
        id: '${ticket.id}:${note.id}',
        ticketId: ticket.id,
        authorName: note.user?.display ?? 'You',
        body: note.body ?? body,
        createdAt: parseGitHubDate(note.createdAt) ?? DateTime.now(),
      );
    });
  }

  @override
  Future<Result<List<ActivityEvent>>> listActivity(Ticket ticket) async {
    return _guard(() async {
      final ref = _repoRef(ticket);
      final events = await _client.issueEvents(ref, ticket.externalKey);
      return [
        for (final e in events)
          ActivityEvent(
            id: '${ticket.id}:${e.id}',
            ticketId: ticket.id,
            actor: e.actor?.display ?? 'unknown',
            action: (e.event ?? 'updated').replaceAll('_', ' '),
            at: parseGitHubDate(e.createdAt) ?? DateTime.now(),
          ),
      ];
    });
  }

  // ---- GitHub-specific (not on the shared interface) ----

  /// All recent issues OR PRs for one repo — the dedicated GitHub board's
  /// per-repo slice. Fetches the most-recently-updated items (`state=all`,
  /// `sort=updated`) so the lifecycle columns show recent merged/closed activity,
  /// not just open work. The `/issues` endpoint also returns PRs, so those are
  /// filtered out of the issue slice.
  Future<Result<List<Ticket>>> listRepoItems(
    String repo, {
    required GitHubKind kind,
  }) async {
    return _guard(() async {
      if (kind == GitHubKind.pullRequest) {
        final pulls = await _client.repoPulls(
          repo,
          state: 'all',
          sort: 'updated',
          direction: 'desc',
          maxPages: 2,
        );
        return [
          for (final p in pulls)
            normalizeGitHubPull(p, accountId: accountId, repoPath: repo),
        ];
      }
      final issues = await _client.repoIssues(
        repo,
        state: 'all',
        sort: 'updated',
        direction: 'desc',
        maxPages: 2,
      );
      return [
        for (final i in issues)
          if (!i.isPullRequest)
            normalizeGitHubIssue(i, accountId: accountId, repoPath: repo),
      ];
    });
  }

  /// Pull requests assigned to me OR requesting my review, across all repos —
  /// the account-wide "my pull requests" dashboard slice. Deduped (a PR can be
  /// both assigned and review-requested).
  Future<Result<List<Ticket>>> listMyPullRequests() => _guard(() async {
    final assigned = await _client.assignedPulls();
    final review = await _client.reviewPulls();
    final byId = <String, Ticket>{};
    for (final p in [...assigned, ...review]) {
      final t = normalizeGitHubPullFromIssue(p, accountId: accountId);
      byId[t.id] = t;
    }
    return byId.values.toList();
  });
}
