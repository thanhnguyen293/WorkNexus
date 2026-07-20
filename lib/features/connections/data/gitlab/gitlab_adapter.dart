import 'package:dio/dio.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/activity_event.dart';
import '../../../../core/domain/entities/comment.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import 'gitlab_client.dart';
import 'gitlab_models.dart';
import 'gitlab_normalize.dart';

/// GitLab implementation of [ProviderAdapter], bound to one account.
///
/// The shared interface is ZenTao-shaped, so the product/execution/bug-resolution
/// methods that have no GitLab analogue are no-oped (empty results / unsupported).
/// GitLab-specific richness (project-scoped issue/MR boards, MR merge, issue
/// close/reopen) lives on this concrete class as extra public methods, called
/// through GitLab-specific `SyncService` paths — not through the interface.
class GitLabAdapter implements ProviderAdapter {
  GitLabAdapter({required this.accountId, required GitLabClient client})
    : _client = client;

  final String accountId;
  final GitLabClient _client;

  @override
  ProviderType get providerType => ProviderType.gitlab;

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
      return normalizeGitLabMergeRequest(mr, accountId: accountId);
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
  Future<Result<bool>> assignTicket(
    Ticket ticket, {
    required String assignee,
    String? comment,
  }) async {
    // Resolve the assignee login → numeric id (what `assignee_ids` expects).
    final userRes = await _guard(() => _client.userByUsername(assignee));
    switch (userRes) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final id = value?.id;
        if (id == null) {
          return Err(NotFoundFailure('No GitLab user "$assignee"'));
        }
        return _guard(() async {
          final ref = _projectRef(ticket);
          if (_kindOf(ticket) == GitLabKind.issue) {
            await _client.updateIssue(
              ref,
              ticket.externalKey,
              assigneeIds: [id],
            );
          } else {
            await _client.updateMergeRequest(
              ref,
              ticket.externalKey,
              assigneeIds: [id],
            );
          }
          if (comment != null && comment.trim().isNotEmpty) {
            _kindOf(ticket) == GitLabKind.issue
                ? await _client.postIssueNote(ref, ticket.externalKey, comment)
                : await _client.postMrNote(ref, ticket.externalKey, comment);
          }
          return true;
        });
    }
  }

  @override
  Future<Result<bool>> resolveBug(
    Ticket ticket, {
    required String resolution,
    String? resolvedBuild,
    String? assignee,
    String? comment,
  }) async => const Err(
    UnexpectedFailure('resolveBug is ZenTao-only; GitLab uses close/reopen'),
  );

  @override
  Future<Result<bool>> activateBug(
    Ticket ticket, {
    String? openedBuild,
    String? assignee,
    String? comment,
  }) async => const Err(
    UnexpectedFailure('activateBug is ZenTao-only; GitLab uses close/reopen'),
  );

  @override
  Future<Result<bool>> confirmBug(
    Ticket ticket, {
    String? assignee,
    String? comment,
  }) async => const Err(
    UnexpectedFailure('confirmBug is ZenTao-only; GitLab has no bug workflow'),
  );

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

  /// Close / reopen an issue via `state_event` on the issue update endpoint.
  Future<Result<bool>> closeIssue(Ticket ticket) =>
      _issueStateEvent(ticket, 'close');
  Future<Result<bool>> reopenIssue(Ticket ticket) =>
      _issueStateEvent(ticket, 'reopen');

  /// Close / reopen a merge request via `state_event`.
  Future<Result<bool>> closeMergeRequest(Ticket ticket) =>
      _mrStateEvent(ticket, 'close');
  Future<Result<bool>> reopenMergeRequest(Ticket ticket) =>
      _mrStateEvent(ticket, 'reopen');

  /// Merge a merge request.
  Future<Result<bool>> mergeMergeRequest(Ticket ticket) => _guard(() async {
    await _client.mergeMergeRequest(_projectRef(ticket), ticket.externalKey);
    return true;
  });

  /// Rebase a merge request onto its target branch (resolves a `need_rebase`
  /// detailed merge status).
  Future<Result<bool>> rebaseMergeRequest(Ticket ticket) => _guard(() async {
    await _client.rebaseMergeRequest(_projectRef(ticket), ticket.externalKey);
    return true;
  });

  /// Set the MR reviewers (replaces the current set). Resolves the selected
  /// logins to member ids via the project member list.
  Future<Result<bool>> setReviewers(
    Ticket ticket,
    List<String> logins,
  ) => _guard(() async {
    final ref = _projectRef(ticket);
    final selected = logins.toSet();
    final members = await _client.members(ref);
    final ids = <int>[
      for (final m in members)
        if (m.username != null && m.id != null && selected.contains(m.username))
          m.id!,
    ];
    await _client.updateMergeRequest(ref, ticket.externalKey, reviewerIds: ids);
    return true;
  });

  /// Project members the ticket can be assigned to. GitLab has no account-wide
  /// assignable list, so the assignee picker resolves per-project members here.
  Future<Result<List<ProviderUser>>> listProjectMembers(Ticket ticket) {
    return _guard(() async {
      final members = await _client.members(_projectRef(ticket));
      final seen = <String>{};
      final users = <ProviderUser>[];
      for (final m in members) {
        final account = m.username;
        if (account == null || account.isEmpty || !seen.add(account)) continue;
        users.add(ProviderUser(account: account, displayName: m.display));
      }
      users.sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
      return users;
    });
  }

  Future<Result<bool>> _issueStateEvent(Ticket ticket, String event) =>
      _guard(() async {
        await _client.updateIssue(
          _projectRef(ticket),
          ticket.externalKey,
          stateEvent: event,
        );
        return true;
      });

  Future<Result<bool>> _mrStateEvent(Ticket ticket, String event) =>
      _guard(() async {
        await _client.updateMergeRequest(
          _projectRef(ticket),
          ticket.externalKey,
          stateEvent: event,
        );
        return true;
      });

  // ---- helpers ----

  /// Issue/MR notes (comments + system activity) for a ticket.
  Future<List<GitLabNote>> _notes(Ticket ticket) {
    final ref = _projectRef(ticket);
    return _kindOf(ticket) == GitLabKind.issue
        ? _client.issueNotes(ref, ticket.externalKey)
        : _client.mrNotes(ref, ticket.externalKey);
  }

  GitLabKind _kindOf(Ticket t) =>
      (t.externalType ?? '').toLowerCase() == 'mergerequest'
      ? GitLabKind.mergeRequest
      : GitLabKind.issue;

  /// The URL-encoded project ref (`group%2Fweb` or a numeric id) parsed from the
  /// ticket's `projectId` (`<accountId>:<path>`), used in `/projects/:ref/…`.
  String _projectRef(Ticket ticket) {
    final prefix = '$accountId:';
    final path = ticket.projectId.startsWith(prefix)
        ? ticket.projectId.substring(prefix.length)
        : ticket.projectId;
    return Uri.encodeComponent(path);
  }

  Future<Result<T>> _guard<T>(Future<T> Function() run) async {
    try {
      return Ok(await run());
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        return Err(AuthFailure('GitLab authentication failed', cause: e));
      }
      if (code == 404) {
        return Err(NotFoundFailure('GitLab resource not found', cause: e));
      }
      final cause = e.error ?? e.message ?? e.type.name;
      return Err(
        NetworkFailure(
          'GitLab request failed [${e.type.name}]: $cause',
          cause: e,
        ),
      );
    } catch (e) {
      return Err(
        ParseFailure('GitLab response could not be parsed: $e', cause: e),
      );
    }
  }
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
