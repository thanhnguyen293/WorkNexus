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
    final page = await _syncPage(session, accountId, chatGid, from: last);
    return switch (page) {
      Ok() => const Ok(null),
      Err(:final failure) => Err(failure),
    };
  }

  /// Fetches the page before the oldest stored message; returns how many
  /// older messages arrived.
  Future<Result<int>> loadOlder(
    ChatSession? session,
    String accountId,
    String chatGid,
  ) async {
    if (session == null) return const Err(NetworkFailure('Chat is offline'));
    final oldest = await _local.oldestServerId(accountId, chatGid);
    if (oldest == null) {
      final refreshed = await refresh(session, accountId, chatGid);
      return switch (refreshed) {
        Ok() => const Ok(0),
        Err(:final failure) => Err(failure),
      };
    }
    if (oldest <= 1) return const Ok(0);
    final page = await _syncPage(session, accountId, chatGid, from: oldest - 1);
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
        await _store(session, accountId, value.data);
        return const Ok(null);
      case Err(:final failure):
        return Err(failure);
    }
  }

  /// `messageSync` backwards from server message id [from] (inclusive).
  Future<Result<List<Map<String, Object?>>>> _syncPage(
    ChatSession session,
    String accountId,
    String chatGid, {
    required int from,
  }) async {
    final reply = await session.connection.request(
      XxdRequest('messageSync', params: [chatGid, from, true, pageSize, false]),
    );
    switch (reply) {
      case Ok(:final value):
        return Ok(await _store(session, accountId, value.data));
      case Err(:final failure):
        return Err(failure);
    }
  }

  /// Stores fetched messages through the session's write queue.
  Future<List<Map<String, Object?>>> _store(
    ChatSession session,
    String accountId,
    Object? data,
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
      );
      session.fetchMissing(followUp);
    });
    return messages;
  }
}
