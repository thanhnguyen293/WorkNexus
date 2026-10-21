import '../value_objects/message_content.dart';
import 'chat_message.dart';

/// A reaction is a reply whose whole content is one emoji: xxd has no
/// reactions of its own, so this app reads such a reply as "reacted with it"
/// to the message it answers (the official client shows a plain emoji reply).
extension ChatMessageReaction on ChatMessage {
  bool get isReaction => replyToId != null && content is EmojiContent;

  /// The emoji of a reaction, else null.
  String? get reactionEmoji => switch (content) {
    EmojiContent(:final emoji) when replyToId != null => emoji,
    _ => null,
  };
}
