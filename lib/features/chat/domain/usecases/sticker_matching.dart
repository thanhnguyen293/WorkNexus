import '../entities/chat_sticker.dart';
import '../value_objects/sticker_keywords.dart';
import 'fold_search_text.dart';

/// Shared by the sticker suggestions: folding, finding words in text and
/// ranking stickers by the emoji they carry.
abstract final class StickerMatching {
  static const _fold = FoldSearchText();

  /// Emoji in text, each one whole (`👨‍💻` stays one, skin tones kept).
  static final emojiPattern = RegExp(
    r'\p{Extended_Pictographic}(?:\u{FE0F}|[\u{1F3FB}-\u{1F3FF}])?'
    r'(?:\u{200D}\p{Extended_Pictographic}\u{FE0F}?)*',
    unicode: true,
  );

  /// Anything that is neither a letter nor a digit, made a space, so words
  /// can be found by the spaces around them.
  static final _punctuation = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

  /// [text] folded to the words in it, space separated, no punctuation.
  static String words(String text) =>
      _fold(text).replaceAll(_punctuation, ' ').trim();

  /// The emoji in [text], in order.
  static List<String> emojiIn(String text) => [
    for (final m in emojiPattern.allMatches(text)) _bare(m[0]!),
  ];

  /// The keys of [lexicon] that are whole words or phrases of [words], the
  /// one nearest the end first (what was typed last matters most).
  static List<String> keysIn(String words, Iterable<String> lexicon) {
    final padded = ' $words ';
    final found = <(String, int)>[
      for (final key in lexicon)
        if (padded.lastIndexOf(' $key ') case final at when at >= 0) (key, at),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final (key, _) in found) key];
  }

  static final _symbols = [
    for (final (pattern, emoji) in kStickerSymbolEmoji)
      (RegExp(pattern), emojiIn(emoji)),
  ];

  /// What the punctuation and emoticons in [text] stand for
  /// ([kStickerSymbolEmoji]), the last typed first: tokens of their own
  /// (`?`, `=))`) and the run a message ends with (`không??`).
  static List<String> symbolsIn(String text) {
    final tokens = text.trim().split(RegExp(r'\s+'));
    final last = tokens.isEmpty ? '' : tokens.last;
    final ending = RegExp(r'[?!.…]+$').firstMatch(last)?[0];
    final found = <String>[];
    for (final token in [?ending, ...tokens.reversed]) {
      for (final (pattern, emoji) in _symbols) {
        if (pattern.hasMatch(token)) {
          found.addAll(emoji);
          break;
        }
      }
    }
    return found;
  }

  /// The emoji [lexicon] gives [text] when it is one of its entries as a
  /// whole (`1`, `0`: [kStickerNumberEmoji]); none otherwise.
  static List<String> wholeIn(String text, Map<String, String> lexicon) =>
      switch (lexicon[text.trim()]) {
        final emoji? => emojiIn(emoji),
        null => const [],
      };

  /// The emoji of [sticker], one by one.
  static List<String> stickerEmoji(ChatSticker sticker) =>
      emojiIn(sticker.emoji);

  /// Stickers that carry [targets] (most wanted first), best first: one whose
  /// own first emoji is wanted beats one that only carries it, and an earlier
  /// target beats a later one. [bonus] adds to a sticker's score (keyword
  /// hits); stickers that score nothing are left out. Ties keep the set's
  /// order.
  static List<ChatSticker> rank(
    List<ChatSticker> stickers,
    List<String> targets, {
    int max = 8,
    Map<ChatSticker, int> bonus = const {},
  }) {
    final weight = <String, int>{};
    for (final (i, emoji) in targets.indexed) {
      weight.putIfAbsent(emoji, () => (targets.length - i) * 10);
    }
    final scored = <(ChatSticker, int, int)>[];
    for (final (order, sticker) in stickers.indexed) {
      var score = bonus[sticker] ?? 0;
      for (final (i, emoji) in stickerEmoji(sticker).indexed) {
        final w = weight[emoji];
        if (w != null) score += i == 0 ? w * 2 : w;
      }
      if (score > 0) scored.add((sticker, score, order));
    }
    scored.sort(
      (a, b) => a.$2 != b.$2 ? b.$2.compareTo(a.$2) : a.$3.compareTo(b.$3),
    );
    return [for (final (sticker, _, _) in scored.take(max)) sticker];
  }

  /// [emoji] without the presentation selector, so `❤️` and `❤` match.
  static String _bare(String emoji) => emoji.replaceAll('\u{FE0F}', '');
}
