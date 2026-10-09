import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../datasources/chat_local_datasource.dart';
import '../datasources/xxd/xxd_packet.dart';
import 'chat_packet_ingestor.dart';
import 'chat_session.dart';

/// Pages a chat's history from xxd into the local DB (`messageSync`).
class ChatHistorySync {
  ChatHistorySync(this._local, this._ingestor);

  static const pageSize = 50;

  final ChatLocalDatasource _local;
  final ChatPacketIngestor _ingestor;

  /// Fetches the newest page of [chatGid].
  Future<Result<void>> refresh(
    ChatSession? session,
    String accountId,
    String chatGid,
  ) async {
    if (session == null) return const Err(NetworkFailure('Chat is offline'));
    final info = await session.connection.request(
      XxdRequest('chatGetMessageInfo', params: [chatGid]),
    );
    final int last;
    switch (info) {
      case Ok(:final value):
        final data = value.data;
        final lastMessage = data is Map ? data['lastMessage'] : null;
        last = lastMessage is num ? lastMessage.toInt() : 0;
      case Err(:final failure):
        return Err(failure);
    }
    if (last <= 0) return const Ok(null);
    final page = await _syncPage(
      session,
      accountId,
      chatGid,
      from: last,
      link: MessageLink.linked,
    );
    switch (page) {
      case Ok(:final value):
        final oldest = _indexes(
          value,
        ).fold<int?>(null, (min, i) => min == null || i < min ? i : min);
        if (oldest != null) {
          await session.enqueue(
            () =>
                _local.timeline.detachIfCutOffBelow(accountId, chatGid, oldest),
          );
        }
        return const Ok(null);
      case Err(:final failure):
        return Err(failure);
    }
  }

  /// Fetches the page before server message [before] (default: the oldest
  /// stored one); returns how many older messages arrived. Pass the oldest
  /// message *shown*: stored messages need not be contiguous (pinned ones and
  /// reply parents are fetched by id), so the oldest stored one can sit far
  /// before a gap.
  ///
  /// Pages continue the timeline, unless [inWindow]: then they extend a
  /// jump window and stay out of it.
  Future<Result<int>> loadOlder(
    ChatSession? session,
    String accountId,
    String chatGid, {
    int? before,
    bool inWindow = false,
  }) async {
    if (session == null) return const Err(NetworkFailure('Chat is offline'));
    final oldest = before ?? await _local.oldestServerId(accountId, chatGid);
    if (oldest == null) {
      final refreshed = await refresh(session, accountId, chatGid);
      return switch (refreshed) {
        Ok() => const Ok(0),
        Err(:final failure) => Err(failure),
      };
    }
    if (oldest <= 1) return const Ok(0);
    final page = await _syncPage(
      session,
      accountId,
      chatGid,
      from: oldest - 1,
      link: inWindow ? MessageLink.detached : MessageLink.linked,
    );
    return switch (page) {
      Ok(:final value) => Ok(
        value
            .where((m) => ((m['id'] as num?)?.toInt() ?? oldest) < oldest)
            .length,
      ),
      Err(:final failure) => Err(failure),
    };
  }

  /// `messageGetList`: specific messages by server id (e.g. a reply's parent
  /// that is older than the loaded pages).
  Future<Result<void>> fetchByIds(
    ChatSession? session,
    String accountId,
    String chatGid,
    List<int> serverIds,
  ) async {
    if (serverIds.isEmpty) return const Ok(null);
    if (session == null) return const Err(NetworkFailure('Chat is offline'));
    final reply = await session.connection.request(
      XxdRequest('messageGetList', params: [chatGid, serverIds]),
    );
    switch (reply) {
      case Ok(:final value):
        await _store(session, accountId, value.data, MessageLink.detached);
        return const Ok(null);
      case Err(:final failure):
        return Err(failure);
    }
  }

  /// The pages around server message [serverId] — it and older, then newer
  /// — as a jump window outside the timeline. Returns the window's index
  /// span, or null when the message has no index to place it by.
  Future<Result<({int from, int to})?>> loadAround(
    ChatSession? session,
    String accountId,
    String chatGid,
    int serverId,
  ) async {
    if (session == null) return const Err(NetworkFailure('Chat is offline'));
    final older = await _syncPage(
      session,
      accountId,
      chatGid,
      from: serverId,
      link: MessageLink.detached,
    );
    if (older case Err(:final failure)) return Err(failure);
    final newer = await _syncPage(
      session,
      accountId,
      chatGid,
      from: serverId,
      link: MessageLink.detached,
      reverse: false,
    );
    final indexes = [
      if (older case Ok(:final value)) ..._indexes(value),
      // Newer is a bonus: without it the window still holds the target.
      if (newer case Ok(:final value)) ..._indexes(value),
    ];
    if (indexes.isEmpty) return const Ok(null);
    indexes.sort();
    return Ok((from: indexes.first, to: indexes.last));
  }

  /// The page after server message [after], extending a jump window;
  /// returns how many newer messages arrived (0 = none: the newest).
  Future<Result<int>> loadNewer(
    ChatSession? session,
    String accountId,
    String chatGid, {
    required int after,
  }) async {
    if (session == null) return const Err(NetworkFailure('Chat is offline'));
    final page = await _syncPage(
      session,
      accountId,
      chatGid,
      from: after + 1,
      link: MessageLink.detached,
      reverse: false,
    );
    return switch (page) {
      Ok(:final value) => Ok(
        value.where((m) => ((m['id'] as num?)?.toInt() ?? 0) > after).length,
      ),
      Err(:final failure) => Err(failure),
    };
  }

  /// `messageSync` from server message id [from] (inclusive): backwards, or
  /// forwards when not [reverse].
  Future<Result<List<Map<String, Object?>>>> _syncPage(
    ChatSession session,
    String accountId,
    String chatGid, {
    required int from,
    required MessageLink link,
    bool reverse = true,
  }) async {
    final reply = await session.connection.request(
      XxdRequest(
        'messageSync',
        params: [chatGid, from, reverse, pageSize, false],
      ),
    );
    switch (reply) {
      case Ok(:final value):
        return Ok(await _store(session, accountId, value.data, link));
      case Err(:final failure):
        return Err(failure);
    }
  }

  /// The per-chat indexes of fetched messages that carry one.
  static Iterable<int> _indexes(List<Map<String, Object?>> messages) => [
    for (final m in messages)
      if (m['index'] case final num i) i.toInt(),
  ];

  /// Stores fetched messages through the session's write queue.
  Future<List<Map<String, Object?>>> _store(
    ChatSession session,
    String accountId,
    Object? data,
    MessageLink link,
  ) async {
    final messages = [
      if (data is List)
        for (final m in data)
          if (m is Map) Map<String, Object?>.from(m),
    ];
    await session.enqueue(() async {
      final followUp = await _ingestor.storeMessages(
        accountId,
        messages,
        selfUserId: session.selfUserId,
        link: link,
      );
      session.fetchMissing(followUp);
    });
    return messages;
  }
}
