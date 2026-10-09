part of 'xxd_chat_repository.dart';

/// Creating chats and changing their settings: direct and group chats, group
/// avatar, star, mute and pinned messages.
mixin _ChatActions on _XxdChatCore {
  @override
  Future<Result<String>> openDirectChat(String accountId, int userId) async {
    final session = _sessions[accountId];
    final self = session?.selfUserId;
    if (session == null || self == null) {
      return const Err(NetworkFailure('Chat is offline'));
    }
    // The official client sorts the ids as strings ("40" < "9").
    final gid = (['$self', '$userId']..sort()).join('&');
    if (await _local.conversation(accountId, gid) != null) return Ok(gid);
    final reply = await _requestAndStore(
      accountId,
      session,
      XxdRequest(
        'chatCreate',
        params: [
          gid,
          '',
          'one2one',
          [self, userId],
          0,
          false,
        ],
      ),
    );
    return switch (reply) {
      Ok() => Ok(gid),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<void>> setGroupAvatar(
    String accountId,
    String chatGid, {
    String? text,
    String? color,
    Uint8List? image,
  }) => _avatars.setGroupAvatar(
    _sessions[accountId],
    chatGid,
    send: (session, request) => _requestAndStore(accountId, session, request),
    text: text,
    color: color,
    image: image,
  );

  @override
  Future<Result<String>> createGroupChat(
    String accountId, {
    required String name,
    required List<int> memberIds,
  }) async {
    final session = _sessions[accountId];
    final self = session?.selfUserId;
    if (session == null || self == null) {
      return const Err(NetworkFailure('Chat is offline'));
    }
    final gid = const Uuid().v4();
    final reply = await _requestAndStore(
      accountId,
      session,
      XxdRequest(
        'chatCreate',
        params: [
          gid,
          name,
          'group',
          {self, ...memberIds}.toList(),
          0,
          false,
        ],
      ),
    );
    return switch (reply) {
      Ok() => Ok(gid),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<void>> setChatStarred(
    String accountId,
    String chatGid, {
    required bool starred,
  }) async {
    final session = _sessions[accountId];
    if (session == null) return const Err(NetworkFailure('Chat is offline'));
    // Moves at once; the server's reply confirms it (or the change is undone).
    await _local.setStarred(accountId, chatGid, starred: starred);
    final result = await _requestAndStore(
      accountId,
      session,
      XxdRequest('chatStar', params: [starred, chatGid]),
    );
    if (result is Err) {
      await _local.setStarred(accountId, chatGid, starred: !starred);
    }
    return result;
  }

  @override
  Future<Result<void>> setChatMuted(
    String accountId,
    String chatGid, {
    required bool muted,
  }) async {
    await _local.setMuted(accountId, chatGid, muted: muted);
    return const Ok(null);
  }

  @override
  Future<Result<void>> setMessagePinned(
    String accountId,
    String chatGid,
    int serverId, {
    required bool pinned,
  }) async {
    final session = _sessions[accountId];
    final self = session?.selfUserId;
    if (session == null || self == null) {
      return const Err(NetworkFailure('Chat is offline'));
    }
    return _requestAndStore(
      accountId,
      session,
      XxdRequest(
        pinned ? 'chatPinMessages' : 'chatUnpinMessages',
        params: [
          chatGid,
          [serverId],
          self,
        ],
      ),
    );
  }
}
