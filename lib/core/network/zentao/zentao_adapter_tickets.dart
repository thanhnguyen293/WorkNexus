part of 'zentao_adapter.dart';

/// Ticket reads: the connection check, the paged "assigned to me" sync, and a
/// single ticket's detail, comments and activity (all from one detail payload).
mixin _ZenTaoTicketReads on _ZenTaoAdapterBase {
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
}
