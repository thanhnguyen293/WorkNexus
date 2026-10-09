import '../entities/chat_conversation.dart';

/// Whether the user may post in a chat, following xxd's `committers`: empty
/// or `$ALL` lets everyone, `$ADMINS` only the owner and admins, anything
/// else is a comma list of the user ids (or accounts) that may.
class CanSendToChat {
  const CanSendToChat();

  bool call(
    ChatConversation chat, {
    required int? selfUserId,
    required String? selfAccount,
  }) {
    final committers = chat.committers.trim();
    if (committers.isEmpty || committers == r'$ALL') return true;
    final isOwner = selfAccount != null && selfAccount == chat.ownerAccount;
    final isAdmin = selfUserId != null && chat.adminIds.contains(selfUserId);
    if (committers == r'$ADMINS') return isOwner || isAdmin;
    final allowed = committers.split(',').map((c) => c.trim()).toSet();
    return isOwner ||
        (selfUserId != null && allowed.contains('$selfUserId')) ||
        (selfAccount != null && allowed.contains(selfAccount));
  }
}
