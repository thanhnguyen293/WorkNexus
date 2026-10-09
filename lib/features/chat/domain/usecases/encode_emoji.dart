import '../value_objects/emojione_shortnames.dart';

/// Makes text safe for the xxd server, whose database keeps only 3-byte
/// UTF-8: a 4-byte character such as 👍 is stored as "????". Emoji the
/// official client knows become its Emojione shortnames (`:thumbsup:`,
/// `:flag_vn:`, `:metal_tone5:` — whole sequences, not code point by code
/// point); any other 4-byte character becomes an HTML numeric entity, which
/// the official client's Markdown renderer shows as the character.
class EncodeEmoji {
  const EncodeEmoji();

  /// Longest emoji sequence in the table, in code points.
  static final int _longest = kEmojioneCanonicalNames.keys.fold(
    0,
    (most, emoji) => emoji.runes.length > most ? emoji.runes.length : most,
  );

  static const _variationSelector = 0xFE0F;

  String call(String text) {
    final runes = text.runes.toList();
    if (!runes.any((r) => r > 0xFFFF)) return text;
    final out = StringBuffer();
    var i = 0;
    while (i < runes.length) {
      final match = _match(runes, i);
      if (match != null) {
        out.write(':${match.name}:');
        i += match.length;
        continue;
      }
      final rune = runes[i++];
      if (rune <= 0xFFFF) {
        out.writeCharCode(rune);
      } else {
        out.write('&#x${rune.toRadixString(16).toUpperCase()};');
      }
    }
    return out.toString();
  }

  /// The longest known emoji starting at [start] that needs encoding (has
  /// a 4-byte code point); variation selectors are ignored, as the table
  /// keys go without them.
  ({String name, int length})? _match(List<int> runes, int start) {
    if (runes[start] == _variationSelector) return null;
    final end = (start + _longest + 4).clamp(0, runes.length);
    for (var stop = end; stop > start; stop--) {
      final part = runes.sublist(start, stop);
      if (!part.any((r) => r > 0xFFFF)) continue;
      final key = String.fromCharCodes(
        part.where((r) => r != _variationSelector),
      );
      if (kEmojioneCanonicalNames[key] case final name?) {
        return (name: name, length: stop - start);
      }
    }
    return null;
  }
}
