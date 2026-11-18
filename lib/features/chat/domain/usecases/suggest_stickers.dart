import '../entities/chat_sticker.dart';
import '../value_objects/sticker_keywords.dart';
import 'sticker_matching.dart';

/// Stickers that could stand for what is being typed, and whether one would
/// say all of it ([replacesDraft]: the draft is only the matched words or
/// emoji), in which case sending one clears the draft.
typedef StickerSuggestions = ({List<ChatSticker> stickers, bool replacesDraft});

/// Suggests stickers for a draft, the way messengers do while you type: the
/// emoji in it, the words it ends with ([kStickerKeywordEmoji]) and its
/// punctuation or emoticons ([kStickerSymbolEmoji]: `?`, `=))`) and a
/// number typed alone ([kStickerNumberEmoji]: `1` yes, `0` no) pick
/// stickers carrying those emoji; a sticker's own words (`ship it`) pick it
/// first. Only short drafts get suggestions — a long message is not about to
/// become a sticker.
class SuggestStickers {
  const SuggestStickers({this.max = 8, this.maxWords = 6});

  final int max;
  final int maxWords;

  static const none = (stickers: <ChatSticker>[], replacesDraft: false);

  StickerSuggestions call(String draft, List<ChatSticker> stickers) {
    final words = StickerMatching.words(draft);
    final typed = StickerMatching.emojiIn(draft);
    final symbols = StickerMatching.symbolsIn(draft);
    final number = StickerMatching.wholeIn(draft, kStickerNumberEmoji);
    final count = words.isEmpty ? 0 : words.split(' ').length;
    if ((count == 0 && typed.isEmpty && symbols.isEmpty) || count > maxWords) {
      return none;
    }

    final keys = StickerMatching.keysIn(words, kStickerKeywordEmoji.keys);
    final targets = [
      ...number,
      ...typed,
      // Typed on its own (`?`, `=))`) it is the point; ending a sentence it
      // only colours it, after what the words say.
      if (count == 0) ...symbols,
      for (final key in keys)
        ...StickerMatching.emojiIn(kStickerKeywordEmoji[key]!),
      if (count > 0) ...symbols,
    ];
    // A sticker named for the very words typed beats any emoji match.
    final bonus = <ChatSticker, int>{};
    final hits = <String>{};
    for (final sticker in stickers) {
      final own = StickerMatching.keysIn(words, sticker.keywords);
      if (own.isNotEmpty) {
        bonus[sticker] = 1000 + own.first.length;
        hits.addAll(own);
      }
    }
    final ranked = StickerMatching.rank(
      stickers,
      targets,
      max: max,
      bonus: bonus,
    );
    if (ranked.isEmpty) return none;
    return (
      stickers: ranked,
      replacesDraft:
          words.isEmpty ||
          number.isNotEmpty ||
          keys.contains(words) ||
          hits.contains(words),
    );
  }
}
