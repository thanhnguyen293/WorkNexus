import 'package:dio/dio.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/activity_event.dart';
import '../../../../core/domain/entities/comment.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import 'zentao_client.dart';
import 'zentao_models.dart';
import 'zentao_normalize.dart';

/// ZenTao implementation of [ProviderAdapter], bound to one account.
class ZenTaoAdapter implements ProviderAdapter {
  ZenTaoAdapter({required this.accountId, required ZenTaoClient client})
    : _client = client;

  final String accountId;
  final ZenTaoClient _client;

  @override
  ProviderType get providerType => ProviderType.zentao;

  @override
  Future<Result<ConnectionCheck>> testConnection() async {
    return _guard(() async {
      final account = await _client.authenticate();
      return ConnectionCheck(ok: true, account: account);
    });
  }

  @override
  Future<Result<TicketPage>> listAssignedTickets({String? sinceCursor}) async {
    return _guard(() async {
      // REST v1 "assigned to me" per type. Each `/user` group is paginated and
      // reports a `total`, so we page through it — otherwise only the first
      // (most-recent) page comes back and older items are silently dropped.
      final tickets = <Ticket>[
        ...await _fetchAssigned('bug', ZenTaoType.bug),
        ...await _fetchAssigned('task', ZenTaoType.task),
      ];

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
    const limit = 100;
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
            body: htmlToMarkdown(body),
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
        final note = stripHtml(a.commentText);
        events.add(
          ActivityEvent(
            id: '${ticket.id}:${a.id ?? events.length}',
            ticketId: ticket.id,
            actor: accountName(a.actor) ?? 'unknown',
            action: zentaoActionText(a),
            at: parseZenTaoDate(a.date) ?? DateTime.now(),
            detail: note.isEmpty ? null : note,
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
  Future<Result<List<ProviderProduct>>> listProducts() async {
    return _guard(() async {
      const limit = 100;
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
  Future<Result<TicketPage>> listProductBugs(String productId) async {
    return _guard(() async {
      const limit = 100;
      final out = <Ticket>[];
      final seen = <String>{};
      var total = 0;
      for (var page = 1; page <= 50; page++) {
        final res = await _client.productBugs(
          productId,
          page: page,
          limit: limit,
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
              labels: [...ticket.labels, 'zentao-product:$productId'],
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
  Future<Result<bool>> assignTicket(
    Ticket ticket, {
    required String assignee,
    String? comment,
  }) async {
    return _guard(() async {
      final type = _typeOf(ticket);
      await _client.api.assignTo(_plural(type), ticket.externalKey, {
        'assignedTo': assignee,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment,
      });
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
      final today = DateTime.now().toIso8601String().split('T').first;
      await _client.api.resolve(ticket.externalKey, {
        'resolution': resolution,
        'resolvedBuild': (resolvedBuild == null || resolvedBuild.trim().isEmpty)
            ? 'trunk'
            : resolvedBuild.trim(),
        'resolvedDate': today,
        if (assignee != null && assignee.isNotEmpty) 'assignedTo': assignee,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment,
      });
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
      await _client.api.activate(ticket.externalKey, {
        'openedBuild': [
          (openedBuild == null || openedBuild.trim().isEmpty)
              ? 'trunk'
              : openedBuild.trim(),
        ],
        if (assignee != null && assignee.isNotEmpty) 'assignedTo': assignee,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment,
      });
      return true;
    });
  }

  // ---- helpers ----

  /// Fetches a ticket's full detail (with its embedded `actions`), preferring
  /// REST v1 and falling back to the classic `{type}-view-{id}.json` endpoint
  /// when v1 returns an empty body.
  Future<ZenTaoEntity> _fetchDetail(Ticket ticket) async {
    final type = _typeOf(ticket);
    final entity = await _client.api.entity(_plural(type), ticket.externalKey);
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
