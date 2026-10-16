import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/adapters/zentao_messages_adapter.dart';
import '../../../../core/domain/entities/activity_event.dart';
import '../../../../core/domain/entities/comment.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/domain/value_objects/ticket_sort.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_paging.dart';
import '../../../../core/util/cancel_signal.dart';
import '../../../../core/util/synthetic_labels.dart';
import '../datasources/zentao_client.dart';
import '../mappers/zentao_normalize.dart';
import '../models/zentao_action_result.dart';
import '../models/zentao_models.dart';
import '../models/zentao_order_by.dart';
import '../models/zentao_workflow.dart';
import 'zentao_source_lists.dart';

/// What [ZenTaoAdapter.listTaskBugs] read: the bugs, and how far they cover
/// the execution's bug list — all of it ([complete]), or the bugs of every
/// task above [above]; neither when ZenTao did not sort them by task.
typedef TaskBugsRead = ({List<Ticket> bugs, bool complete, int? above});

/// ZenTao implementation of [ProviderAdapter], bound to one account.
class ZenTaoAdapter implements ProviderAdapter, ZenTaoMessagesAdapter {
  ZenTaoAdapter({required this.accountId, required this._client})
    : _lists = ZenTaoSourceLists(_client, accountId: accountId);

  final String accountId;
  final ZenTaoClient _client;
  final ZenTaoSourceLists _lists;

  @override
  Future<Uint8List?> fetchBytes(
    String url, {
    String? projectPath,
    String? projectId,
  }) => _client.fetchBytes(url);

  @override
  Future<Uint8List?> downloadBytes(String url) => _client.downloadBytes(url);

  @override
  Object? get rawClient => _client;

  /// Detail replies fetched by this adapter, keyed by type + id. Opening a
  /// ticket asks for its detail, comments and activity in turn, and all three
  /// come from the same reply — without this the endpoint is hit three times.
  /// Adapters are built per operation, so the memo never outlives one sync.
  final _details = <String, Future<ZenTaoEntity>>{};

  @override
  ProviderType get providerType => ProviderType.zentao;

  @override
  Future<Result<ConnectionCheck>> testConnection() async {
    return _guard(() async {
      final baseUrl = await _client.detectBaseUrl();
      final account = await _client.authenticate();
      return ConnectionCheck(ok: true, account: account, baseUrl: baseUrl);
    });
  }

  @override
  Future<Result<TicketPage>> listAssignedTickets({String? sinceCursor}) async {
    return _guard(() async {
      // REST v1 "assigned to me" per type. Each `/user` group is paginated and
      // reports a `total`, so we page through it — otherwise only the first
      // (most-recent) page comes back and older items are silently dropped.
      // Bugs and tasks page independently, so they are fetched side by side.
      final [bugs, tasks] = await Future.wait([
        _fetchAssigned('bug', ZenTaoType.bug),
        _fetchAssigned('task', ZenTaoType.task),
      ]);
      final tickets = <Ticket>[...bugs, ...tasks];

      // Incremental cursor: max updatedAt seen, filtered client-side.
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

  /// Fetches every "assigned to me" item of one [type], paging through
  /// `GET /user?type=assignedTo&fields=<field>` until the reported `total` is
  /// reached. A seen-set dedupes by id, which both prevents duplicates and
  /// safely stops a server that ignores the `page` parameter (a page that adds
  /// nothing new ends the loop instead of looping forever).
  Future<List<Ticket>> _fetchAssigned(String field, ZenTaoType type) async {
    const limit = kDefaultApiPageLimit;
    final out = <Ticket>[];
    final seen = <String>{};
    var total = 0;
    for (var page = 1; page <= 50; page++) {
      final res = await _client.api.assigned('assignedTo', field, page, limit);
      final group = res.groupFor(field);
      if (group == null || group.items.isEmpty) break;
      if (group.total > 0) total = group.total;

      var added = 0;
      for (final entity in group.items) {
        final id = entity.idString;
        if (id.isNotEmpty && !seen.add(id)) continue; // already have it
        out.add(
          normalizeZenTao(
            entity,
            type: type,
            accountId: accountId,
            baseUrl: _client.baseUrl,
          ),
        );
        added++;
      }
      if (added == 0) break; // server ignored `page` — stop before looping
      if (total > 0 && out.length >= total) break;
    }
    return out;
  }

  @override
  Future<Result<Ticket>> getTicket(Ticket ticket) async {
    return _guard(() async {
      _details.remove('${ticket.externalType}:${ticket.externalKey}')?.ignore();
      final type = _typeOf(ticket);
      final entity = await _fetchDetail(ticket);
      return normalizeZenTao(
        entity,
        type: type,
        accountId: accountId,
        baseUrl: _client.baseUrl,
      );
    });
  }

  @override
  Future<Result<List<Comment>>> listComments(Ticket ticket) async {
    return _guard(() async {
      final entity = await _fetchDetail(ticket);
      final comments = <Comment>[];
      for (final a in entity.actions) {
        // Only pure comments are bubbles; notes attached to a state change
        // (e.g. "activated" + a message) are shown inline on the activity row.
        if (a.actionType != 'commented') continue;
        final body = a.commentText;
        if (body.isEmpty) continue;
        comments.add(
          Comment(
            id: '${ticket.id}:${a.id ?? comments.length}',
            ticketId: ticket.id,
            authorName: accountName(a.actor) ?? 'unknown',
            // HTML, as written in ZenTao's editor.
            body: body,
            createdAt: parseZenTaoDate(a.date) ?? DateTime.now(),
          ),
        );
      }
      return comments;
    });
  }

  @override
  Future<Result<Comment>> postComment(Ticket ticket, String body) async {
    return _guard(() async {
      final type = _typeOf(ticket);
      await _client.classicActionPost(
        'action-comment-${type.pathSegment}-${ticket.externalKey}',
        {'comment': body},
      );
      return Comment(
        id: '${ticket.id}:${DateTime.now().microsecondsSinceEpoch}',
        ticketId: ticket.id,
        authorName: 'You',
        body: body,
        createdAt: DateTime.now(),
      );
    });
  }

  @override
  Future<Result<List<ActivityEvent>>> listActivity(Ticket ticket) async {
    return _guard(() async {
      final entity = await _fetchDetail(ticket);
      final events = <ActivityEvent>[];
      for (final a in entity.actions) {
        // Pure comments render as bubbles, not activity rows.
        if (a.actionType == 'commented') continue;
        final parsed = zentaoActionAttachments(a.commentText);
        final note = parsed.note;
        events.add(
          ActivityEvent(
            id: '${ticket.id}:${a.id ?? events.length}',
            ticketId: ticket.id,
            actor: accountName(a.actor) ?? 'unknown',
            action: zentaoActionText(a),
            at: parseZenTaoDate(a.date) ?? DateTime.now(),
            detail: note.isEmpty ? null : note,
            attachments: parsed.files,
          ),
        );
      }
      return events;
    });
  }

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
  Future<Result<List<ProviderProduct>>> listProducts() =>
      _guard(_lists.products);

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
  Future<Result<ViewPage>> listProductBugsPage(
    String productId, {
    required String browseType,
    required int page,
    required int limit,
    TicketSort sort = TicketSort.newest,
    CancelSignal? cancel,
  }) async {
    return _guard(() async {
      final res = await _client.classicProductBugs(
        productId,
        browseType: browseType,
        recPerPage: limit,
        pageID: page,
        orderBy: zentaoOrderBy(sort, bug: true),
        cancel: cancel,
      );
      // ZenTao's pager answers a page past the end with the first page again,
      // so "more" comes from the view's total, never from a page being full.
      final hasMore = page * limit < res.total;
      return ViewPage(
        total: res.total,
        hasMore: hasMore,
        tickets: [
          for (final bug in res.bugs)
            if (bug.idString.isNotEmpty)
              _productBug(
                normalizeZenTao(
                  bug,
                  type: ZenTaoType.bug,
                  accountId: accountId,
                  baseUrl: _client.baseUrl,
                ),
                productId,
              ),
        ],
      );
    });
  }

  /// The bugs of execution [executionId] that task [taskId] may have, read
  /// from its bug list sorted by task, highest first: reading stops at the
  /// first bug of a lower task, so a recent task costs one page. Says how
  /// far the pages read cover — the whole list ([TaskBugsRead.complete]), or
  /// every task above [TaskBugsRead.above]. When ZenTao does not sort by
  /// task, it reads on until the end, or [maxPages] pages of [limit].
  Future<Result<TaskBugsRead>> listTaskBugs(
    String executionId, {
    required int taskId,
    int limit = 100,
    int maxPages = 5,
  }) => _guard(() async {
    final bugs = <Ticket>[];
    var sorted = true;
    int? lowest;
    for (var page = 1; page <= maxPages; page++) {
      final res = await _client.classicExecutionBugs(
        executionId,
        recPerPage: limit,
        pageID: page,
        orderBy: 'task_desc,id_desc',
      );
      for (final bug in res.bugs) {
        if (bug.idString.isEmpty) continue;
        final task = zentaoInt(bug.task) ?? 0;
        if (lowest != null && task > lowest) sorted = false;
        lowest = task;
        bugs.add(
          normalizeZenTao(
            bug,
            type: ZenTaoType.bug,
            accountId: accountId,
            baseUrl: _client.baseUrl,
          ),
        );
      }
      // A page past the end answers the first page again, so the total
      // ends the list, not a short page.
      if (page * limit >= res.total) {
        return (bugs: bugs, complete: true, above: null);
      }
      // Bugs with the task's id cannot come after a lower task's.
      if (sorted && lowest != null && lowest < taskId) break;
    }
    return (bugs: bugs, complete: false, above: sorted ? lowest : null);
  });

  Ticket _productBug(Ticket ticket, String productId) => ticket.copyWith(
    labels: [...ticket.labels, zentaoProductLabel(productId)],
  );

  /// The raw view of the web notification menu (`allMessages` by day).
  @override
  Future<Result<Map<String, dynamic>>> fetchMessages() =>
      _guard(_client.messages);

  /// Runs a classic message action, e.g. `ajaxMarkRead-all`.
  @override
  Future<Result<void>> messageAction(String action) =>
      _guard(() => _client.messageAction(action));

  /// The raw `GET /user?fields=…` reply (profile + "my work" blocks) that the
  /// dashboard is built from.
  @override
  Future<Result<Map<String, dynamic>>> fetchUserInfo({
    required String fields,
    required int limit,
  }) async {
    final res = await _guard(
      () => _client.userInfo(fields: fields, limit: limit),
    );
    // The client lets 4xx through as data; an error body has no profile.
    if (res case Ok(:final value) when value['profile'] is! Map) {
      final error = value['error'] ?? value['message'] ?? 'no profile';
      return Err(AuthFailure('ZenTao user info unavailable: $error'));
    }
    return res;
  }

  @override
  Future<Result<List<ProviderProject>>> listProjects() =>
      _guard(_lists.projects);

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
  Future<Result<ViewPage>> listExecutionTasksPage(
    String executionId, {
    required String browseType,
    required int page,
    required int limit,
    TicketSort sort = TicketSort.newest,
    CancelSignal? cancel,
  }) async {
    return _guard(() async {
      final res = await _client.classicExecutionTasks(
        executionId,
        browseType: browseType,
        recPerPage: limit,
        pageID: page,
        orderBy: zentaoOrderBy(sort, bug: false),
        cancel: cancel,
      );
      final seen = <String>{};
      return ViewPage(
        total: res.total,
        // As with bugs, ZenTao's pager answers a page past the end with the
        // first page again, so "more" comes from the view's total.
        hasMore: page * limit < res.total,
        tickets: [
          for (final task in res.tasks)
            if (task.idString.isNotEmpty && seen.add(task.idString))
              _executionTask(
                normalizeZenTao(
                  task,
                  type: ZenTaoType.task,
                  accountId: accountId,
                  baseUrl: _client.baseUrl,
                ),
                executionId,
              ),
        ],
      );
    });
  }

  Ticket _executionTask(Ticket ticket, String executionId) => ticket.copyWith(
    labels: [...ticket.labels, zentaoExecutionLabel(executionId)],
  );

  @override
  Future<Result<bool>> assignTicket(
    Ticket ticket, {
    required String assignee,
    String? comment,
  }) async {
    return _guard(() async {
      // Classic web action `{type}-assignTo-{id}` (no REST v1 endpoint on this
      // build); mirrors the web client's assign request.
      final type = _typeOf(ticket);
      final task = ticket.providerEntity;
      // A task's assign form also carries its hours left, which ZenTao 20+
      // resets to 0 when the field is missing.
      final left = switch (task) {
        ZenTaoTaskEntity(:final left?) => zentaoHours(left),
        _ => null,
      };
      // `task::assignTo` takes the execution BEFORE the task id; with the id
      // alone ZenTao reads it as the execution and answers task 0's HTML page.
      // The execution only picks the form's member list, so `0` is fine.
      final target = type == ZenTaoType.task
          ? '${task is ZenTaoTaskEntity ? task.execution ?? '0' : '0'}'
                '-${ticket.externalKey}'
          : ticket.externalKey;
      final resp = await _client.classicActionPost(
        '${type.pathSegment}-assignTo-$target',
        {
          'assignedTo': assignee,
          'left': ?left,
          if (comment != null && comment.trim().isNotEmpty) 'comment': comment,
        },
      );
      ensureZenTaoActionOk(resp, 'assign');
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
  }) async {
    return _guard(() async {
      // Classic web action `bug-resolve-{id}` (REST /bugs/{id}/resolve 404s on
      // this build).
      final today = DateTime.now().toIso8601String().split('T').first;
      final resp = await _client.classicActionPost(
        'bug-resolve-${ticket.externalKey}',
        {
          'resolution': resolution,
          'resolvedBuild':
              (resolvedBuild == null || resolvedBuild.trim().isEmpty)
              ? 'trunk'
              : resolvedBuild.trim(),
          'resolvedDate': today,
          if (assignee != null && assignee.isNotEmpty) 'assignedTo': assignee,
          if (comment != null && comment.trim().isNotEmpty) 'comment': comment,
        },
      );
      ensureZenTaoActionOk(resp, 'resolve');
      return true;
    });
  }

  @override
  Future<Result<bool>> activateBug(
    Ticket ticket, {
    String? openedBuild,
    String? assignee,
    String? comment,
  }) async {
    return _guard(() async {
      // ZenTao's activate wants `openedBuild` as a non-empty STRING (like
      // resolve's `resolvedBuild`), NOT an array.
      final build = (openedBuild == null || openedBuild.trim().isEmpty)
          ? 'trunk'
          : openedBuild.trim();
      // Reopen assigns to the acting user (me) by default; otherwise ZenTao
      // leaves the bug on whoever it was parked on (the reporter, at resolve).
      final target = (assignee != null && assignee.trim().isNotEmpty)
          ? assignee.trim()
          : _client.account;
      final resp = await _client.classicActionPost(
        'bug-activate-${ticket.externalKey}',
        {
          'openedBuild': build,
          if (target.isNotEmpty) 'assignedTo': target,
          if (comment != null && comment.trim().isNotEmpty) 'comment': comment,
        },
      );
      ensureZenTaoActionOk(resp, 'activate');
      return true;
    });
  }

  @override
  Future<Result<bool>> confirmBug(
    Ticket ticket, {
    String? assignee,
    String? comment,
  }) async {
    return _guard(() async {
      // No REST v1 bug actions on these builds (they 404): confirm goes
      // through the classic web action. Keep the bug on the acting user by
      // default so it stays on their board.
      final target = (assignee != null && assignee.trim().isNotEmpty)
          ? assignee.trim()
          : _client.account;
      await ZenTaoWorkflow(
        _client,
      ).confirmBug(ticket.externalKey, assignee: target, comment: comment);
      return true;
    });
  }

  // ---- helpers ----

  /// Fetches a ticket's full detail (with its embedded `actions`), preferring
  /// REST v1 and falling back to the classic `{type}-view-{id}.json` endpoint
  /// when v1 returns an empty body.
  Future<ZenTaoEntity> _fetchDetail(Ticket ticket) {
    final key = '${ticket.externalType}:${ticket.externalKey}';
    final cached = _details[key];
    if (cached != null) return cached;
    final future = _details[key] = _loadDetail(ticket);
    // Remove memo shortly after completion so concurrent operations in a single
    // sync pass share the reply, but subsequent syncs fetch fresh data from ZenTao.
    future.then<void>(
      (_) {
        unawaited(
          Future<void>.delayed(const Duration(seconds: 4), () {
            if (identical(_details[key], future)) _details.remove(key);
          }),
        );
      },
      onError: (Object _) {
        if (identical(_details[key], future)) _details.remove(key);
      },
    );
    return future;
  }

  Future<ZenTaoEntity> _loadDetail(Ticket ticket) async {
    final type = _typeOf(ticket);
    final entity = await _client.entity(_plural(type), ticket.externalKey);
    if (entity.idString.isNotEmpty) return entity;
    final fallback = await _client.classicViewJson(
      type.pathSegment,
      ticket.externalKey,
    );
    return fallback == null ? entity : ZenTaoEntity.fromJson(fallback);
  }

  ZenTaoType _typeOf(Ticket t) => switch (t.externalType) {
    'Task' => ZenTaoType.task,
    'Story' => ZenTaoType.story,
    _ => ZenTaoType.bug,
  };

  String _plural(ZenTaoType t) => switch (t) {
    ZenTaoType.bug => 'bugs',
    ZenTaoType.task => 'tasks',
    ZenTaoType.story => 'stories',
  };

  Future<Result<T>> _guard<T>(Future<T> Function() run) async {
    try {
      return Ok(await run());
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        return Err(CancelledFailure('ZenTao request cancelled', cause: e));
      }
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        return Err(AuthFailure('ZenTao authentication failed', cause: e));
      }
      // Surface the real cause (e.g. HandshakeException / SocketException / 404).
      final cause = e.error ?? e.message ?? e.type.name;
      return Err(
        NetworkFailure(
          'ZenTao request failed [${e.type.name}]: $cause',
          cause: e,
        ),
      );
    } catch (e) {
      return Err(
        ParseFailure('ZenTao response could not be parsed: $e', cause: e),
      );
    }
  }
}
