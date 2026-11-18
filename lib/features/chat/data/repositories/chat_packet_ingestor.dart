import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../../../../core/database/database.dart';
import '../../domain/usecases/is_reaction_row.dart';
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
/// DB). Stateless apart from the datasource and the [reactions] setting;
/// callers serialise calls per account so packets apply in arrival order.
class ChatPacketIngestor {
  ChatPacketIngestor(this._local);

  final ChatLocalDatasource _local;

  /// Whether an emoji reply is a reaction, which never counts as unread.
  /// Off, it is a message like any other.
  bool reactions = false;

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
      case 'chatgetbygid' || 'chatcreate':
        if (data is! Map) break;
        final chat = Map<String, Object?>.from(data);
        await _storeChats(accountId, [chat]);
        return IngestFollowUp(
          userIds: await _unknownUsers(accountId, {
            ?peerOf('${chat['gid']}', selfUserId),
          }),
        );
      // A retracted/edited message arrives whole (e.g. `deleted: true`).
      case 'messagesend' || 'messageretract' || 'messageupdate':
        return storeMessages(
          accountId,
          _maps(data is Map ? [data] : data),
          selfUserId: selfUserId,
        );
      case 'chatsetlastreadmessagebyindex':
        // Pushed when this account reads a chat anywhere (including here).
        if (data is Map && data['gid'] is String && data['id'] is num) {
          await _local.setLastReadIndex(
            accountId,
            data['gid']! as String,
            (data['id']! as num).toInt(),
          );
        }
      // Someone (un)pinned messages: the reply carries the full new list.
      case 'chatpinmessages' || 'chatunpinmessages':
        if (data is Map && data['cgid'] is String) {
          await _local.setPinned(
            accountId,
            data['cgid']! as String,
            pinnedJsonOf(data['allPinned']),
          );
        }
      // Someone signed in (their user record, with `status`) or out.
      case 'userlogin':
        if (data is Map && data['id'] != null) {
          await _local.upsertUsers([
            userFromXxd(accountId, Map<String, Object?>.from(data)),
          ]);
        }
      // Someone (this account included) changed their status or picture;
      // `userchange` on servers before 7.x.
      case 'userupdate' || 'userchange':
        if (data is! Map || data['id'] is! num) break;
        final userId = (data['id']! as num).toInt();
        if (data['status'] is String) {
          await _local.setUserStatus(
            accountId,
            userId,
            data['status']! as String,
          );
        }
        // A picture change is announced this way too (ZenTao web sets it
        // behind xxd's back). A reply without the picture gets the user
        // reloaded, so the new one shows without a reconnect.
        final avatar = data['avatar'];
        if (avatar is! String) return IngestFollowUp(userIds: {userId});
        await _local.setUserAvatar(
          accountId,
          userId,
          avatar.isEmpty ? null : avatar,
        );
      case 'userlogout':
        if (data is Map && data['id'] is num) {
          await _local.setUserStatus(
            accountId,
            (data['id']! as num).toInt(),
            'offline',
          );
        }
      case 'chatstar':
        if (data is Map && data['gid'] is String) {
          await _local.setStarred(
            accountId,
            data['gid']! as String,
            starred: data['star'] == true || data['star'] == 1,
          );
        }
      case 'chatsetavatar':
        if (data is Map && data['gid'] is String && data['avatar'] is Map) {
          await _local.setChatAvatar(
            accountId,
            data['gid']! as String,
            jsonEncode(data['avatar']),
          );
        }
      // Members joined or left: the reply is the group itself. This account
      // leaving or being removed takes the group off its list, as the
      // official client does.
      case 'chatinvite' || 'chatkick' || 'chatleave':
        if (data is! Map || data['gid'] is! String) break;
        final chat = Map<String, Object?>.from(data);
        await _storeChats(accountId, [chat]);
        // Ids or user objects, depending on the server.
        final members = {
          if (chat['members'] case final List<Object?> list)
            for (final m in list)
              ?(m is Map ? num.tryParse('${m['id']}') : num.tryParse('$m'))
                  ?.toInt(),
        };
        if (selfUserId != null &&
            members.isNotEmpty &&
            !members.contains(selfUserId)) {
          await _local.setArchived(
            accountId,
            chat['gid']! as String,
            archived: true,
          );
        }
      // The group's settings changed (`chatsetconfig`), or one of them on
      // older servers; each carries only what it changed.
      case 'chatsetconfig' || 'chatsetcommitters' || 'chatsetvisibility':
        if (data is! Map || data['gid'] is! String) break;
        await _local.setGroupSettings(
          accountId,
          data['gid']! as String,
          committers: data.containsKey('committers')
              ? '${data['committers'] ?? ''}'
              : null,
          isPublic: data.containsKey('public') ? flagOf(data['public']) : null,
          adminInvite: data.containsKey('adminInvite')
              ? flagOf(data['adminInvite'])
              : null,
        );
      // Also pushed when the user files chats from another client.
      case 'chatsetcategory':
        if (data is Map && data['gids'] is List) {
          await _local.setCategory(accountId, [
            for (final g in data['gids']! as List<Object?>)
              if (g is String) g,
          ], '${data['category'] ?? ''}');
        }
      case 'chataddadmins' || 'chatremoveadmins':
        if (data is Map && data['gid'] is String) {
          await _local.setAdmins(
            accountId,
            data['gid']! as String,
            pinnedJsonOf(data['admins']),
          );
        }
      // The whole group, with its new owner.
      case 'chatchangeownership':
        if (data is Map && data['gid'] is String) {
          await _storeChats(accountId, [Map<String, Object?>.from(data)]);
        }
      case 'chatrename':
        if (data is Map && data['gid'] is String && data['name'] is String) {
          await _local.setChatName(
            accountId,
            data['gid']! as String,
            data['name']! as String,
          );
        }
      // A dismissed group is archived, as the chat list maps `dismissDate`.
      case 'chatdismiss':
        if (data is Map && data['gid'] is String) {
          await _local.setArchived(
            accountId,
            data['gid']! as String,
            archived: (num.tryParse('${data['dismissDate']}') ?? 1) > 0,
          );
        }
      // ZenTao's notifications and xuanbot replies (official client: kh).
      case 'syncnotifications':
        if (selfUserId == null) break;
        return storeNotifications(accountId, data, selfUserId: selfUserId);
      case 'usergetlist':
        await _local.upsertUsers([
          for (final u in _maps(data))
            if (u['id'] != null) userFromXxd(accountId, u),
        ]);
    }
    return const IngestFollowUp();
  }

  /// Stores notifications in the xuanbot chat, created locally when the
  /// server's chat list did not include it (as the official client does).
  Future<IngestFollowUp> storeNotifications(
    String accountId,
    Object? data, {
    required int selfUserId,
  }) async {
    final rows = notificationsFromXxd(accountId, data, selfUserId: selfUserId);
    if (rows.isEmpty) return const IngestFollowUp();
    final bot = xuanbotGid(selfUserId);
    if (rows.any((r) => r.cgid.value == bot) &&
        await _local.conversation(accountId, bot) == null) {
      await _storeChats(accountId, [
        {'gid': bot, 'type': 'bot', 'name': 'Xuanbot'},
      ]);
    }
    await _local.upsertMessages(rows);
    for (final row in rows) {
      await _local.touchConversation(
        accountId,
        row.cgid.value,
        row.sentAt.value,
      );
    }
    return const IngestFollowUp();
  }

  /// Stores messages (pushed or fetched) and advances their conversations.
  Future<IngestFollowUp> storeMessages(
    String accountId,
    List<Map<String, Object?>> messages, {
    required int? selfUserId,
    MessageLink link = MessageLink.keep,
  }) async {
    final valid = [
      for (final m in messages)
        if (m['gid'] is String && m['cgid'] is String) m,
    ];
    if (valid.isEmpty) return const IngestFollowUp();
    final rows = [
      for (final m in valid)
        await _keepReactionContent(accountId, messageFromXxd(accountId, m)),
    ];
    // Per chat, so a 50-message page is one batch, one read and one write
    // per chat inside one transaction — not a hundred round trips, each
    // re-running every open watch.
    final byChat = <String, List<RecordedMessage>>{};
    for (final row in rows) {
      byChat.putIfAbsent(row.cgid.value, () => []).add((
        serverId: row.serverId.value,
        index: row.messageIndex.value,
        sentAt: row.sentAt.value,
        fromSelf: row.senderId.value == selfUserId,
        reaction: reactions && _isReaction(row),
      ));
    }
    final unknownChats = <String>{};
    await _local.transaction(() async {
      await _local.upsertMessages(rows, link: link);
      for (final MapEntry(key: cgid, value: messages) in byChat.entries) {
        if (await _local.conversation(accountId, cgid) == null) {
          unknownChats.add(cgid);
          continue;
        }
        await _local.recordMessages(accountId, cgid, messages);
      }
    });
    return IngestFollowUp(
      chatGids: unknownChats,
      userIds: await _unknownUsers(accountId, {
        for (final r in rows) r.senderId.value,
      }),
    );
  }

  /// The server sends a retracted message back without its content. A
  /// retracted reaction keeps its emoji here, so it stays known as one (and
  /// out of the timeline); any other retracted reply loses its content as
  /// the server wants, and shows as retracted.
  Future<ChatMessagesCompanion> _keepReactionContent(
    String accountId,
    ChatMessagesCompanion row,
  ) async {
    if (!row.deleted.value ||
        row.content.value.isNotEmpty ||
        row.replyToId.value == null) {
      return row;
    }
    final stored = await _local.message(accountId, row.gid.value);
    if (stored == null ||
        !const IsReactionRow()(
          replyToId: stored.replyToId,
          deleted: stored.deleted,
          contentType: stored.contentType,
          content: stored.content,
        )) {
      return row;
    }
    return row.copyWith(
      contentType: Value(stored.contentType),
      content: Value(stored.content),
    );
  }

  static bool _isReaction(ChatMessagesCompanion row) => const IsReactionRow()(
    replyToId: row.replyToId.value,
    deleted: row.deleted.value,
    contentType: row.contentType.value,
    content: row.content.value,
  );

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
