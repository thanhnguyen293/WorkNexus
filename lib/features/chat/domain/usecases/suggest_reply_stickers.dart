import '../entities/chat_message.dart';
import '../entities/chat_sticker.dart';
import '../value_objects/message_content.dart';
import '../value_objects/sticker_keywords.dart';
import 'sticker_matching.dart';

/// Stickers to answer the latest message with, when it is someone else's
/// and recent: what it says picks them ([kStickerReplyEmoji] — thanks is
/// answered with a smile; [kStickerNumberReplyEmoji] — a lone `1` with a
/// thumbs up), and an emoji or emoticon in it (`=))`, `?`) is echoed.
/// Nothing for the user's own message, a notice, or one older than [maxAge].
class SuggestReplyStickers {
  const SuggestReplyStickers({
    this.max = 6,
    this.maxAge = const Duration(hours: 12),
  });

  final int max;
  final Duration maxAge;

  /// Mentions are sent as `[@Name](@#id)`; the name is not what it says.
  static final _mention = RegExp(r'\[@[^\]]+\]\(@#\d+\)');

  List<ChatSticker> call(
    ChatMessage? latest,
    List<ChatSticker> stickers, {
    DateTime? now,
  }) {
    if (latest == null ||
        latest.isMine ||
        latest.deleted ||
        latest.isNotice ||
        (now ?? DateTime.now()).difference(latest.sentAt) > maxAge) {
      return const [];
    }
    final text = switch (latest.content) {
      TextContent(:final text) => text.replaceAll(_mention, ' '),
      EmojiContent(:final emoji) => emoji,
      _ => null,
    };
    if (text == null) return const [];
    final words = StickerMatching.words(text);
    final keys = StickerMatching.keysIn(words, kStickerReplyEmoji.keys);
    final targets = [
      ...StickerMatching.wholeIn(text, kStickerNumberReplyEmoji),
      for (final key in keys)
        ...StickerMatching.emojiIn(kStickerReplyEmoji[key]!),
      ...StickerMatching.emojiIn(text),
      ...StickerMatching.symbolsIn(text),
    ];
    return StickerMatching.rank(stickers, targets, max: max);
  }
}
