import 'package:dio/dio.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/activity_event.dart';
import '../../../../core/domain/entities/comment.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import 'github_client.dart';
import 'github_normalize.dart';

/// GitHub implementation of [ProviderAdapter], bound to one account.
///
/// The shared interface is ZenTao-shaped, so the product/execution/bug-resolution
/// methods with no GitHub analogue are no-oped. GitHub-specific richness
/// (repo-scoped issue/PR boards, PR merge, issue close/reopen) lives on this
/// concrete class as extra public methods, called through GitHub-specific
/// `SyncService` paths — not through the interface. A PR is an issue with extra
/// fields, so comment/assign/close/reopen all route through the issues endpoints;
/// only merge and the rich PR board use the `/pulls` endpoints.
class GitHubAdapter implements ProviderAdapter {
  GitHubAdapter({required this.accountId, required GitHubClient client})
    : _client = client;

  final String accountId;
  final GitHubClient _client;

  @override
  ProviderType get providerType => ProviderType.github;

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

  @override
  Future<Result<bool>> assignTicket(
    Ticket ticket, {
    required String assignee,
    String? comment,
  }) async {
    // GitHub assigns by login string directly — no username→id lookup needed.
    return _guard(() async {
      final ref = _repoRef(ticket);
      await _client.updateIssue(ref, ticket.externalKey, assignees: [assignee]);
      if (comment != null && comment.trim().isNotEmpty) {
        await _client.postIssueComment(ref, ticket.externalKey, comment);
      }
      return true;
    });
  }

  @override
  Future<Result<bool>> resolveBug(
    Ticket ticket, {
    required String resolution,
    String? resolvedBuild,
    String? assignee,
    String? comment,
  }) async => const Err(
    UnexpectedFailure('resolveBug is ZenTao-only; GitHub uses close/reopen'),
  );

  @override
  Future<Result<bool>> activateBug(
    Ticket ticket, {
    String? openedBuild,
    String? assignee,
    String? comment,
  }) async => const Err(
    UnexpectedFailure('activateBug is ZenTao-only; GitHub uses close/reopen'),
  );

  @override
  Future<Result<bool>> confirmBug(
    Ticket ticket, {
    String? assignee,
    String? comment,
  }) async => const Err(
    UnexpectedFailure('confirmBug is ZenTao-only; GitHub has no bug workflow'),
  );

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

  /// Close / reopen an issue or PR via the issues `state` field (a PR is an
  /// issue, so this works for both).
  Future<Result<bool>> closeItem(Ticket ticket) => _setState(ticket, 'closed');
  Future<Result<bool>> reopenItem(Ticket ticket) => _setState(ticket, 'open');

  /// Merge a pull request.
  Future<Result<bool>> mergePull(Ticket ticket) => _guard(() async {
    await _client.mergePull(_repoRef(ticket), ticket.externalKey);
    return true;
  });

  /// Update a PR branch with its base ("Update branch"; resolves a `behind`
  /// mergeable state — GitHub has no true rebase via the API).
  Future<Result<bool>> updateBranch(Ticket ticket) => _guard(() async {
    await _client.updateBranch(_repoRef(ticket), ticket.externalKey);
    return true;
  });

  /// Request [logins] as reviewers on a PR (additive — GitHub ignores logins
  /// already requested; removing a reviewer isn't supported through this path).
  Future<Result<bool>> setReviewers(Ticket ticket, List<String> logins) =>
      _guard(() async {
        if (logins.isNotEmpty) {
          await _client.requestReviewers(
            _repoRef(ticket),
            ticket.externalKey,
            logins,
          );
        }
        return true;
      });

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

  Future<Result<bool>> _setState(Ticket ticket, String state) =>
      _guard(() async {
        await _client.updateIssue(
          _repoRef(ticket),
          ticket.externalKey,
          state: state,
        );
        return true;
      });

  // ---- helpers ----

  GitHubKind _kindOf(Ticket t) =>
      (t.externalType ?? '').toLowerCase() == 'pullrequest'
      ? GitHubKind.pullRequest
      : GitHubKind.issue;

  /// The `owner/name` repo ref parsed from the ticket's `projectId`
  /// (`<accountId>:<owner/name>`), used in `/repos/:ref/…`. GitHub takes the
  /// slash literally, so (unlike GitLab's numeric id) it is NOT URL-encoded.
  String _repoRef(Ticket ticket) {
    final prefix = '$accountId:';
    return ticket.projectId.startsWith(prefix)
        ? ticket.projectId.substring(prefix.length)
        : ticket.projectId;
  }

  Future<Result<T>> _guard<T>(Future<T> Function() run) async {
    try {
      return Ok(await run());
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        return Err(AuthFailure('GitHub authentication failed', cause: e));
      }
      if (code == 404) {
        return Err(NotFoundFailure('GitHub resource not found', cause: e));
      }
      final cause = e.error ?? e.message ?? e.type.name;
      return Err(
        NetworkFailure(
          'GitHub request failed [${e.type.name}]: $cause',
          cause: e,
        ),
      );
    } catch (e) {
      return Err(
        ParseFailure('GitHub response could not be parsed: $e', cause: e),
      );
    }
  }
}
