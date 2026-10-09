part of 'xxd_chat_repository.dart';

/// Users, members and server role names.
mixin _ChatMembers on _XxdChatCore {
  /// Role names by account, asked once per session.
  final _roleNames = <String, Map<String, String>>{};

  @override
  Future<Result<Map<String, String>>> roleNames(String accountId) async {
    if (_roleNames[accountId] case final names?) return Ok(names);
    final session = _sessions[accountId];
    if (session == null) return const Err(NetworkFailure('Chat is offline'));
    // The official client's `sysgetdepts`: departments and the role list.
    appTalker.info('Chat roles: asking sysgetdepts');
    final reply = await session.connection.request(
      const XxdRequest('sysgetdepts'),
    );
    final Object? roles;
    switch (reply) {
      // The official client reads `data.roles` (beside `data.depts`); the
      // reply's own `roles` field is left empty by xxd 9.
      case Ok(:final value):
        final data = _decodeRoles(value.data);
        final nested = data is Map ? _decodeRoles(data['roles']) : null;
        roles = nested is Map && nested.isNotEmpty
            ? nested
            : _decodeRoles(value.raw['roles']);
        appTalker.info(
          'Chat roles: sysgetdepts data keys '
          '${data is Map ? data.keys.toList() : data.runtimeType}; '
          'roles: $roles',
        );
      case Err(:final failure):
        appTalker.warning(
          'Chat roles: sysgetdepts failed — ${failure.message}',
        );
        return Err(failure);
    }
    final names = <String, String>{
      if (roles is Map)
        for (final MapEntry(:key, :value) in roles.entries)
          if (value is String && value.trim().isNotEmpty)
            '$key'.trim(): value.trim(),
    };
    return Ok(_roleNames[accountId] = names);
  }

  /// A map as sent, or the same map as a JSON string (as xxd may send it).
  static Object? _decodeRoles(Object? roles) {
    if (roles is! String) return roles;
    try {
      return jsonDecode(roles);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<Result<int>> memberCount(String accountId, String chatGid) async =>
      switch (await members(accountId, chatGid)) {
        Ok(:final value) => Ok(value.length),
        Err(:final failure) => Err(failure),
      };

  @override
  Future<Result<void>> setMyAvatar(String accountId, Uint8List image) async {
    final result = await _avatars.setMyAvatar(_sessions[accountId], image);
    if (result case Err()) return result;
    // The new picture lives at a new URL, carried by the user list.
    return refreshUsers(accountId);
  }

  @override
  Future<Result<void>> refreshUsers(String accountId) async {
    final session = _sessions[accountId];
    if (session == null) return const Err(NetworkFailure('Chat is offline'));
    // An empty id list asks xxd for every user.
    return _requestAndStore(
      accountId,
      session,
      const XxdRequest('usergetlist', params: [<int>[]]),
    );
  }

  @override
  Future<Result<List<int>>> members(String accountId, String chatGid) async {
    final session = _sessions[accountId];
    if (session == null) return const Err(NetworkFailure('Chat is offline'));
    final reply = await session.connection.request(
      XxdRequest('chatGetMembers', params: [chatGid]),
    );
    final Object? data;
    switch (reply) {
      case Ok(:final value):
        data = value.data;
      case Err(:final failure):
        return Err(failure);
    }
    final raw = data is Map ? data['members'] : data;
    if (raw is! List) {
      return const Err(ParseFailure('Unexpected chat members reply'));
    }
    // Members come as ids or as user objects depending on the server.
    final ids = <int>[
      for (final m in raw)
        if (m is num)
          m.toInt()
        else if (m is String && int.tryParse(m) != null)
          int.parse(m)
        else if (m is Map && m['id'] is num)
          (m['id']! as num).toInt(),
    ];
    final known = await _local.knownUserIds(accountId);
    session.fetchMissing(
      IngestFollowUp(userIds: ids.toSet().difference(known)),
    );
    return Ok(ids);
  }
}
