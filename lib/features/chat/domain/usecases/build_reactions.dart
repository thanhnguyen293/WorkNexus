import '../entities/chat_message.dart';
import '../entities/chat_message_reaction.dart';
import '../entities/message_reaction.dart';

/// Gathers the reactions among [replies] under the message each answers:
/// one entry per emoji, in the order it was first used. A retracted reaction
/// is gone, and one person's repeated emoji counts once.
class BuildReactions {
  const BuildReactions();

  Map<int, List<MessageReaction>> call(List<ChatMessage> replies) {
    final ordered = [
      for (final r in replies)
        if (r.isReaction && !r.deleted) r,
    ]..sort((a, b) => a.sentAt.compareTo(b.sentAt));
    final byTarget = <int, Map<String, List<ChatMessage>>>{};
    for (final r in ordered) {
      final people = byTarget
          .putIfAbsent(r.replyToId!, () => {})
          .putIfAbsent(r.reactionEmoji!, () => []);
      if (people.every((p) => p.senderId != r.senderId)) people.add(r);
    }
    return {
      for (final MapEntry(key: target, value: byEmoji) in byTarget.entries)
        target: [
          for (final MapEntry(key: emoji, value: list) in byEmoji.entries)
            MessageReaction(
              emoji: emoji,
              userIds: [for (final m in list) m.senderId],
              mine: list.where((m) => m.isMine).firstOrNull,
            ),
        ],
    };
  }
}
