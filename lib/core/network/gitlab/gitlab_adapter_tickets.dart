part of 'gitlab_adapter.dart';

/// Ticket reads: the connection check, the assigned-ticket sync, a single
/// issue/MR detail, its comments and system-note activity, and the
/// GitLab-specific project / "my merge requests" board slices.
mixin _GitLabTicketReads on _GitLabAdapterBase {
  @override
  Future<Result<ConnectionCheck>> testConnection() async {
    return _guard(() async {
      final user = await _client.currentUser();
      return ConnectionCheck(ok: true, account: user.username);
    });
  }

  @override
  Future<Result<TicketPage>> listAssignedTickets({String? sinceCursor}) async {
    return _guard(() async {
      final issues = await _client.assignedIssues();
      final assignedMrs = await _client.assignedMergeRequests();
      final me = await _client.currentUser();
      final reviewMrs = me.username == null
          ? const <GitLabMergeRequest>[]
          : await _client.reviewMergeRequests(me.username!);

      // Dedupe by unified ticket id (an MR can be both assigned to me and
      // awaiting my review).
      final byId = <String, Ticket>{};
      for (final i in issues) {
        final t = normalizeGitLabIssue(i, accountId: accountId);
        byId[t.id] = t;
      }
      for (final m in [...assignedMrs, ...reviewMrs]) {
        final t = normalizeGitLabMergeRequest(m, accountId: accountId);
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
      final ref = _projectRef(ticket);
      if (_kindOf(ticket) == GitLabKind.issue) {
        final issue = await _client.issue(ref, ticket.externalKey);
        return normalizeGitLabIssue(issue, accountId: accountId);
      }
      final mr = await _client.mergeRequest(ref, ticket.externalKey);
      return normalizeGitLabMergeRequest(
        await _withCommitsBehind(ref, mr),
        accountId: accountId,
      );
    });
  }

  @override
  Future<Result<List<Comment>>> listComments(Ticket ticket) async {
    return _guard(() async {
      final notes = await _notes(ticket);
      final comments = <Comment>[];
      for (final n in notes) {
        // System notes are activity rows, not comment bubbles.
        if (n.system) continue;
        final body = n.body ?? '';
        if (body.trim().isEmpty) continue;
        comments.add(
          Comment(
            id: '${ticket.id}:${n.id}',
            ticketId: ticket.id,
            authorName: n.author?.display ?? 'unknown',
            body: body,
            createdAt: parseGitLabDate(n.createdAt) ?? DateTime.now(),
          ),
        );
      }
      return comments;
    });
  }

  @override
  Future<Result<Comment>> postComment(Ticket ticket, String body) async {
    return _guard(() async {
      final ref = _projectRef(ticket);
      final note = _kindOf(ticket) == GitLabKind.issue
          ? await _client.postIssueNote(ref, ticket.externalKey, body)
          : await _client.postMrNote(ref, ticket.externalKey, body);
      return Comment(
        id: '${ticket.id}:${note.id}',
        ticketId: ticket.id,
        authorName: note.author?.display ?? 'You',
        body: note.body ?? body,
        createdAt: parseGitLabDate(note.createdAt) ?? DateTime.now(),
      );
    });
  }

  @override
  Future<Result<List<ActivityEvent>>> listActivity(Ticket ticket) async {
    return _guard(() async {
      final notes = await _notes(ticket);
      final events = <ActivityEvent>[];
      for (final n in notes) {
        // Only system notes describe activity (assigned, closed, …); user
        // comments render as bubbles via [listComments].
        if (!n.system) continue;
        final summary = _activitySummary(n.body ?? '');
        events.add(
          ActivityEvent(
            id: '${ticket.id}:${n.id}',
            ticketId: ticket.id,
            actor: n.author?.display ?? 'unknown',
            action: summary.isEmpty ? 'updated' : summary,
            at: parseGitLabDate(n.createdAt) ?? DateTime.now(),
          ),
        );
      }
      return events;
    });
  }

  // ---- GitLab-specific (not on the shared interface) ----

  /// All recent issues OR MRs for one project — the dedicated GitLab board's
  /// per-project slice. Fetches the ~200 most-recently-updated items
  /// (`state=all`, `order_by=updated_at`) so the lifecycle columns show recent
  /// merged/closed activity, not just currently-open work.
  Future<Result<List<Ticket>>> listProjectItems(
    String projectId, {
    required GitLabKind kind,
  }) async {
    return _guard(() async {
      if (kind == GitLabKind.mergeRequest) {
        final mrs = await _client.projectMergeRequests(
          projectId,
          state: 'all',
          orderBy: 'updated_at',
          sort: 'desc',
          maxPages: 2,
        );
        return [
          for (final m in mrs)
            normalizeGitLabMergeRequest(m, accountId: accountId),
        ];
      }
      final issues = await _client.projectIssues(
        projectId,
        state: 'all',
        orderBy: 'updated_at',
        sort: 'desc',
        maxPages: 2,
      );
      return [
        for (final i in issues) normalizeGitLabIssue(i, accountId: accountId),
      ];
    });
  }

  /// Merge requests assigned to me OR awaiting my review, across all projects —
  /// the account-wide "my merge requests" dashboard slice. Deduped (an MR can be
  /// both assigned and review-requested).
  Future<Result<List<Ticket>>> listMyMergeRequests() => _guard(() async {
    final assigned = await _client.assignedMergeRequests();
    final me = await _client.currentUser();
    final review = me.username == null
        ? const <GitLabMergeRequest>[]
        : await _client.reviewMergeRequests(me.username!);
    final byId = <String, Ticket>{};
    for (final m in [...assigned, ...review]) {
      final t = normalizeGitLabMergeRequest(m, accountId: accountId);
      byId[t.id] = t;
    }
    return byId.values.toList();
  });
}

/// GitLab system-note bodies carry the human summary on the first line, then may
/// append a markdown/HTML detail block (e.g. the commit list on "added N
/// commits", a "Compare with previous version" link). Keep just that summary
/// line and strip markdown emphasis / stray HTML so the activity row reads
/// cleanly instead of dumping raw `<ul><li>…` markup.
String _activitySummary(String body) {
  final line = body
      .split('\n')
      .map((l) => l.trim())
      .firstWhere((l) => l.isNotEmpty, orElse: () => '');
  return line
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll(RegExp(r'\*\*|__|`'), '')
      .trim();
}
