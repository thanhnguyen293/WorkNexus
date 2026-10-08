import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_user.dart';
import '../../domain/usecases/parse_message_content.dart';

// ---- xxd packet data → drift ---------------------------------------------------

/// A chat from `chatgetlist` / `chatgetbygid`. Leaves [lastMessageIndex]
/// untouched when the packet has no `lastMessageInfo`.
ChatConversationsCompanion conversationFromXxd(
  String accountId,
  Map<String, Object?> chat,
) {
  final info = chat['lastMessageInfo'];
  final lastIndex = info is Map ? _int(info['index']) : null;
  return ChatConversationsCompanion(
    accountId: Value(accountId),
    gid: Value(chat['gid']! as String),
    type: Value('${chat['type'] ?? ''}'),
    name: Value('${chat['name'] ?? ''}'),
    lastActiveAt: Value(_date(chat['lastActiveTime'])),
    lastMessageId: Value(_int(chat['lastMessage'])),
    lastMessageIndex: lastIndex == null
        ? const Value.absent()
        : Value(lastIndex),
    lastReadIndex: Value(_int(chat['lastReadMessageIndex']) ?? 0),
    hidden: Value(chat['hide'] == true),
    archived: Value(
      (_int(chat['archiveDate']) ?? 0) > 0 ||
          (_int(chat['dismissDate']) ?? 0) > 0,
    ),
  );
}

/// The chat's `lastMessageInfo`, when present (used as the list preview).
Map<String, Object?>? lastMessageOf(Map<String, Object?> chat) {
  final info = chat['lastMessageInfo'];
  return info is Map && info['gid'] is String
      ? Map<String, Object?>.from(info)
      : null;
}

/// A stored message from `messagesend`, `messageSync` or `lastMessageInfo`.
ChatMessagesCompanion messageFromXxd(String accountId, Map<String, Object?> m) {
  final content = m['content'];
  return ChatMessagesCompanion(
    accountId: Value(accountId),
    gid: Value(m['gid']! as String),
    cgid: Value(m['cgid']! as String),
    serverId: Value(_int(m['id'])),
    messageIndex: Value(_int(m['index'])),
    senderId: Value(_int(m['user']) ?? _int(m['senderId']) ?? 0),
    sentAt: Value(_date(m['date']) ?? DateTime.now()),
    contentType: Value('${m['contentType'] ?? 'plain'}'),
    content: Value(
      content is String
          ? content
          : (content == null ? '' : jsonEncode(content)),
    ),
    sendState: Value(SendState.sent.name),
    deleted: Value(m['deleted'] == true),
    replyToId: Value(replyToOf(m['data'])),
  );
}

/// `replyTo` from a message's `data` (a JSON string or an already-decoded map).
int? replyToOf(Object? data) {
  Object? decoded = data;
  if (data is String && data.isNotEmpty) {
    try {
      decoded = jsonDecode(data);
    } on FormatException {
      return null;
    }
  }
  return decoded is Map ? _int(decoded['replyTo']) : null;
}

/// The `data` field to send for a message (empty unless it is a reply).
String messageDataFor({int? replyToId}) =>
    replyToId == null ? '' : jsonEncode({'replyTo': replyToId});

ChatUsersCompanion userFromXxd(String accountId, Map<String, Object?> u) {
  final avatar = u['avatar'];
  return ChatUsersCompanion(
    accountId: Value(accountId),
    userId: Value(_int(u['id'])!),
    account: Value('${u['account'] ?? ''}'),
    realname: Value('${u['realname'] ?? ''}'),
    avatar: Value(avatar is String && avatar.isNotEmpty ? avatar : null),
    deleted: Value(u['deleted'] == true),
  );
}

/// The other member of a one-to-one chat (`"<idA>&<idB>"`).
int? peerOf(String gid, int? selfUserId) {
  final ids = gid.split('&').map(int.tryParse).whereType<int>().toList();
  if (ids.length != 2) return null;
  return ids.first == selfUserId ? ids.last : ids.first;
}

// ---- drift → domain ------------------------------------------------------------

ChatConversation conversationFromRow(
  ChatConversationRow row, {
  ChatMessageRow? lastMessage,
  int? selfUserId,
  ParseMessageContent parse = const ParseMessageContent(),
}) {
  final type = _chatType(row.type);
  final unread = row.lastMessageIndex - row.lastReadIndex;
  return ChatConversation(
    accountId: row.accountId,
    gid: row.gid,
    type: type,
    name: row.name,
    unreadCount: unread > 0 ? unread : 0,
    lastActiveAt: row.lastActiveAt,
    lastMessage: lastMessage == null
        ? null
        : messageFromRow(lastMessage, selfUserId: selfUserId, parse: parse),
    peerUserId: type == ChatType.one2one ? peerOf(row.gid, selfUserId) : null,
    hidden: row.hidden,
    archived: row.archived,
  );
}

ChatMessage messageFromRow(
  ChatMessageRow row, {
  int? selfUserId,
  ParseMessageContent parse = const ParseMessageContent(),
}) => ChatMessage(
  accountId: row.accountId,
  gid: row.gid,
  chatGid: row.cgid,
  senderId: row.senderId,
  sentAt: row.sentAt,
  content: parse(row.contentType, row.content),
  isMine: selfUserId != null && row.senderId == selfUserId,
  sendState: SendState.values.asNameMap()[row.sendState] ?? SendState.sent,
  serverId: row.serverId,
  replyToId: row.replyToId,
  deleted: row.deleted,
);

ChatUser userFromRow(ChatUserRow row) => ChatUser(
  accountId: row.accountId,
  userId: row.userId,
  account: row.account,
  realname: row.realname,
  avatarUrl: row.avatar,
  deleted: row.deleted,
);

ChatType _chatType(String type) =>
    ChatType.values.asNameMap()[type] ?? ChatType.other;

int? _int(Object? v) =>
    v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

/// xxd sends Unix seconds; 0 means "never".
DateTime? _date(Object? v) {
  final n = _int(v);
  if (n == null || n <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(n < 100000000000 ? n * 1000 : n);
}
