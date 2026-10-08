import '../../../../core/database/database.dart';
import '../datasources/chat_local_datasource.dart';
import '../datasources/xxd/xxd_packet.dart';
import '../mappers/chat_mappers.dart';

/// Follow-up requests a packet calls for (data the local DB is missing).
final class IngestFollowUp {
  const IngestFollowUp({this.userIds = const {}, this.chatGids = const {}});

  /// Users to fetch with `usergetlist`.
  final Set<int> userIds;

  /// Unknown conversations to fetch with `chatgetbygid`.
  final Set<String> chatGids;

  bool get isEmpty => userIds.isEmpty && chatGids.isEmpty;
}

/// Writes xxd packets into the local DB (local-first: the UI only reads the
/// DB). Stateless apart from the datasource; callers serialise calls per
/// account so packets apply in arrival order.
class ChatPacketIngestor {
  ChatPacketIngestor(this._local);

  final ChatLocalDatasource _local;

  /// Applies [packet]; returns what should be fetched next.
  Future<IngestFollowUp> ingest(
    String accountId,
    XxdResponse packet, {
    required int? selfUserId,
  }) async {
    if (!packet.isSuccess) return const IngestFollowUp();
    final data = packet.data;
    switch (packet.apiName) {
      case 'chatgetlist':
        final chats = _maps(data);
        await _storeChats(accountId, chats);
        return IngestFollowUp(
          userIds: await _unknownUsers(accountId, {
            for (final c in chats) ?peerOf('${c['gid']}', selfUserId),
          }),
        );
      case 'chatgetbygid':
        if (data is! Map) break;
        final chat = Map<String, Object?>.from(data);
        await _storeChats(accountId, [chat]);
        return IngestFollowUp(
          userIds: await _unknownUsers(accountId, {
            ?peerOf('${chat['gid']}', selfUserId),
          }),
        );
      case 'messagesend':
        return storeMessages(
          accountId,
          _maps(data is Map ? [data] : data),
          selfUserId: selfUserId,
        );
      case 'usergetlist':
        await _local.upsertUsers([
          for (final u in _maps(data))
            if (u['id'] != null) userFromXxd(accountId, u),
        ]);
    }
    return const IngestFollowUp();
  }

  /// Stores messages (pushed or fetched) and advances their conversations.
  Future<IngestFollowUp> storeMessages(
    String accountId,
    List<Map<String, Object?>> messages, {
    required int? selfUserId,
  }) async {
    final valid = [
      for (final m in messages)
        if (m['gid'] is String && m['cgid'] is String) m,
    ];
    if (valid.isEmpty) return const IngestFollowUp();
    final rows = [for (final m in valid) messageFromXxd(accountId, m)];
    await _local.upsertMessages(rows);

    final unknownChats = <String>{};
    for (final row in rows) {
      final cgid = row.cgid.value;
      if (await _local.conversation(accountId, cgid) == null) {
        unknownChats.add(cgid);
        continue;
      }
      await _local.recordMessage(
        accountId,
        cgid,
        serverId: row.serverId.value,
        index: row.messageIndex.value,
        sentAt: row.sentAt.value,
        fromSelf: row.senderId.value == selfUserId,
      );
    }
    return IngestFollowUp(
      chatGids: unknownChats,
      userIds: await _unknownUsers(accountId, {
        for (final r in rows) r.senderId.value,
      }),
    );
  }

  Future<void> _storeChats(
    String accountId,
    List<Map<String, Object?>> chats,
  ) async {
    final valid = [
      for (final c in chats)
        if (c['gid'] is String) c,
    ];
    await _local.upsertConversationsWithMessages(
      [for (final c in valid) conversationFromXxd(accountId, c)],
      [for (final c in valid) ?_lastMessageRow(accountId, c)],
    );
  }

  ChatMessagesCompanion? _lastMessageRow(
    String accountId,
    Map<String, Object?> chat,
  ) {
    final last = lastMessageOf(chat);
    return last == null || last['cgid'] is! String
        ? null
        : messageFromXxd(accountId, last);
  }

  Future<Set<int>> _unknownUsers(String accountId, Set<int> ids) async {
    final wanted = ids.where((id) => id > 0).toSet();
    if (wanted.isEmpty) return const {};
    return wanted.difference(await _local.knownUserIds(accountId));
  }

  static List<Map<String, Object?>> _maps(Object? data) => [
    if (data is List)
      for (final e in data)
        if (e is Map) Map<String, Object?>.from(e),
  ];
}
