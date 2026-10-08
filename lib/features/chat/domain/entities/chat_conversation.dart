import 'package:freezed_annotation/freezed_annotation.dart';

import 'chat_message.dart';

part 'chat_conversation.freezed.dart';

enum ChatType { group, one2one, bot, system, other }

/// A chat the account belongs to. One-to-one chats have no [name]; their title
/// comes from [peerUserId] (see `ResolveChatTitle`).
@freezed
abstract class ChatConversation with _$ChatConversation {
  const factory ChatConversation({
    required String accountId,
    required String gid,
    required ChatType type,
    required String name,
    @Default(0) int unreadCount,
    DateTime? lastActiveAt,
    ChatMessage? lastMessage,
    int? peerUserId,
    @Default(false) bool hidden,
    @Default(false) bool archived,

    /// Pinned to the top of the chat list.
    @Default(false) bool starred,

    /// Notifications silenced (kept on this device only).
    @Default(false) bool muted,

    /// Server ids of pinned messages, oldest pin first.
    @Default(<int>[]) List<int> pinnedMessageIds,

    /// User ids of the group's admins (they and the owner may pin).
    @Default(<int>[]) List<int> adminIds,

    /// Group owner's account and creation time (groups only).
    String? ownerAccount,

    /// The group's avatar as stored (xxd JSON); see `ChatGroupAvatar`.
    String? avatarJson,
    DateTime? createdAt,
  }) = _ChatConversation;
}
