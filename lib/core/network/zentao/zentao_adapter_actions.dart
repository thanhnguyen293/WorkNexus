part of 'zentao_adapter.dart';

/// Workflow actions through the classic web channel: assign, and the bug
/// resolve / activate / confirm transitions, each checked for a real success.
mixin _ZenTaoActions on _ZenTaoAdapterBase {
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
      final resp = await _client.classicActionPost(
        '${type.pathSegment}-assignTo-${ticket.externalKey}',
        {
          'assignedTo': assignee,
          if (comment != null && comment.trim().isNotEmpty) 'comment': comment,
        },
      );
      _ensureClassicActionOk(resp, 'assign');
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
      _ensureClassicActionOk(resp, 'resolve');
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
      _ensureClassicActionOk(resp, 'activate');
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
      // This ZenTao build exposes no REST v1 bug-action endpoints (they 404),
      // so confirm goes through the classic web action `bug-confirmBug-<id>` —
      // the same channel the board's bug browsing uses. It sets confirmed = 1
      // and (re)assigns the bug; keep it on the acting user by default so it
      // stays on their board.
      final target = (assignee != null && assignee.trim().isNotEmpty)
          ? assignee.trim()
          : _client.account;
      final resp = await _client.classicActionPost(
        'bug-confirmBug-${ticket.externalKey}',
        {
          if (target.isNotEmpty) 'assignedTo': target,
          if (comment != null && comment.trim().isNotEmpty) 'comment': comment,
        },
      );
      _ensureClassicActionOk(resp, 'confirm');
      return true;
    });
  }

  /// Success check for a classic (`index.php`) action [Response]. Unlike the
  /// REST channel, a POST that ZenTao did NOT process comes back as the action
  /// page's HTML (a String) or a login redirect rather than a
  /// `{result: 'success'}` JSON object — so anything that isn't a non-`fail`
  /// JSON object is treated as a failure. (The old lenient check let a
  /// silently-ignored action read as success, so the change was lost on the
  /// next sync — which looked like "confirm does nothing".)
  void _ensureClassicActionOk(Response<dynamic> resp, String action) {
    final code = resp.statusCode ?? 0;
    Object? data = resp.data;
    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        try {
          data = jsonDecode(trimmed);
        } catch (_) {
          // Not JSON → leave as String, treated as a failure below.
        }
      }
    }
    final ok =
        code < 400 &&
        data is Map &&
        data['result']?.toString() != 'fail' &&
        data['status']?.toString() != 'fail';
    if (ok) return;
    final detail = data is Map
        ? (data['message'] ?? data['error'])?.toString()
        : 'ZenTao did not process the action '
              '(auth/permission, CSRF, or the action does not exist)';
    throw DioException(
      requestOptions: resp.requestOptions,
      response: resp,
      message:
          'ZenTao $action failed (HTTP $code)'
          '${detail == null || detail.isEmpty ? '' : ': $detail'}',
    );
  }
}
