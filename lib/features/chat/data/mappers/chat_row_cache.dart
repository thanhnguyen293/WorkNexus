import '../../../../core/database/database.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/usecases/parse_message_content.dart';
import 'chat_mappers.dart';

/// Rows mapped to their entities, reused while the row reads the same.
///
/// Drift re-runs a watch on every write to its tables, and mapping a message
/// parses its content (JSON for images and files, regexes and emoji for text),
/// a conversation its pinned and admin lists; with a page of messages and the
/// whole chat list re-emitted per incoming message, that is hundreds of parses
/// for one new row. Rows compare by value, so a row equal to the one mapped
/// last time keeps its entity — which also lets consumers compare entities by
/// identity. Bounded, oldest out first.
class ChatRowCache {
  ChatRowCache(this._parse, {this.capacity = 4000});

  final ParseMessageContent _parse;

  /// Entries kept per kind; a chat's visible window plus the chat list stay
  /// well within it, and anything older is simply mapped again.
  final int capacity;

  final _messages = <String, (ChatMessageRow, int?, ChatMessage)>{};
  final _conversations =
      <
        String,
        (ChatConversationRow, ChatMessageRow?, int?, ChatConversation)
      >{};

  ChatMessage message(ChatMessageRow row, {int? selfUserId}) {
    final key = '${row.accountId}/${row.gid}';
    // Removing and re-adding keeps the map in least-recently-used order.
    final hit = _messages.remove(key);
    if (hit != null && hit.$1 == row && hit.$2 == selfUserId) {
      _messages[key] = hit;
      return hit.$3;
    }
    final message = messageFromRow(row, selfUserId: selfUserId, parse: _parse);
    _messages[key] = (row, selfUserId, message);
    _trim(_messages);
    return message;
  }

  ChatConversation conversation(
    ChatConversationRow row, {
    ChatMessageRow? lastMessage,
    int? selfUserId,
  }) {
    final key = '${row.accountId}/${row.gid}';
    final hit = _conversations.remove(key);
    if (hit != null &&
        hit.$1 == row &&
        hit.$2 == lastMessage &&
        hit.$3 == selfUserId) {
      _conversations[key] = hit;
      return hit.$4;
    }
    final conversation = conversationFromRow(
      row,
      lastMessage: lastMessage,
      selfUserId: selfUserId,
      messageOf: message,
    );
    _conversations[key] = (row, lastMessage, selfUserId, conversation);
    _trim(_conversations);
    return conversation;
  }

  void _trim(Map<String, Object> entries) {
    while (entries.length > capacity) {
      entries.remove(entries.keys.first);
    }
  }
}
