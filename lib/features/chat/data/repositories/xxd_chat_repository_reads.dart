part of 'xxd_chat_repository.dart';

/// Reads watched from drift, history paging and read state.
mixin _ChatReads on _XxdChatCore {
  // ---- reads -------------------------------------------------------------------

  @override
  Stream<List<ChatConversation>> watchConversations(String accountId) =>
      withSelfUserId(
        _local.watchSelfUserId(accountId),
        _local.watchConversations(accountId),
        (rows, self) => [
          for (final (conv, last) in rows)
            conversationFromRow(
              conv,
              lastMessage: last,
              selfUserId: self,
              parse: _parse,
            ),
        ],
      );

  @override
  Stream<List<ChatMessage>> watchMessages(
    String accountId,
    String chatGid, {
    int limit = XxdChatRepository.pageSize,
  }) => withSelfUserId(
    _local.watchSelfUserId(accountId),
    _local.watchMessages(accountId, chatGid, limit: limit),
    (rows, self) => [
      for (final r in rows) messageFromRow(r, selfUserId: self, parse: _parse),
    ],
  );

  @override
  Stream<ChatMessage?> watchMessage(
    String accountId,
    String chatGid,
    int serverId,
  ) => withSelfUserId(
    _local.watchSelfUserId(accountId),
    _local.watchMessageByServerId(accountId, chatGid, serverId),
    (row, self) => row == null
        ? null
        : messageFromRow(row, selfUserId: self, parse: _parse),
  );

  @override
  Stream<List<ChatMessage>> watchReplies(String accountId, String chatGid) =>
      withSelfUserId(
        _local.watchSelfUserId(accountId),
        _local.watchReplies(accountId, chatGid),
        (rows, self) => [
          for (final r in rows)
            messageFromRow(r, selfUserId: self, parse: _parse),
        ],
      );

  @override
  Stream<List<ChatMessage>> watchAttachments(
    String accountId,
    String chatGid,
  ) => withSelfUserId(
    _local.watchSelfUserId(accountId),
    _local.watchAttachments(accountId, chatGid),
    (rows, self) => [
      for (final r in rows) messageFromRow(r, selfUserId: self, parse: _parse),
    ],
  );

  @override
  Stream<List<ChatUser>> watchUsers(String accountId) => _local
      .watchUsers(accountId)
      .map((rows) => rows.map(userFromRow).toList());

  @override
  Stream<int?> watchSelfUserId(String accountId) =>
      _local.watchSelfUserId(accountId);

  // ---- history & read state ----------------------------------------------------

  @override
  Future<Result<void>> refreshMessages(String accountId, String chatGid) =>
      _history.refresh(_sessions[accountId], accountId, chatGid);

  @override
  Future<Result<int>> loadOlderMessages(
    String accountId,
    String chatGid, {
    int? beforeServerId,
  }) => _history.loadOlder(
    _sessions[accountId],
    accountId,
    chatGid,
    before: beforeServerId,
  );

  @override
  Future<Result<int>> countOlderMessages(
    String accountId,
    String chatGid, {
    required DateTime before,
  }) async {
    try {
      return Ok(await _local.countOlder(accountId, chatGid, before));
    } on Exception catch (e) {
      return Err(StorageFailure('Could not read stored messages', cause: e));
    }
  }

  @override
  Future<Result<void>> fetchMessages(
    String accountId,
    String chatGid,
    List<int> serverIds,
  ) => _history.fetchByIds(_sessions[accountId], accountId, chatGid, serverIds);

  @override
  Future<Result<void>> markRead(String accountId, String chatGid) async {
    final ChatConversationRow? row;
    try {
      row = await _local.conversation(accountId, chatGid);
      if (row == null || row.lastReadIndex >= row.lastMessageIndex) {
        return const Ok(null);
      }
      await _local.setLastReadIndex(accountId, chatGid, row.lastMessageIndex);
    } on Exception catch (e) {
      return Err(StorageFailure('Could not mark the chat read', cause: e));
    }
    final session = _sessions[accountId];
    // Offline: read locally now; the server keeps its own value until the
    // chat is read again while connected.
    if (session == null || !session.isOnline) return const Ok(null);
    final reply = await session.connection.request(
      XxdRequest(
        'chatSetLastReadMessageByIndex',
        params: [chatGid, row.lastMessageIndex],
      ),
    );
    return switch (reply) {
      Ok() => const Ok(null),
      Err(:final failure) => Err(failure),
    };
  }
}
