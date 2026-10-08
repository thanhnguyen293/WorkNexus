import '../value_objects/emoji_shortnames.dart';

/// Makes text safe for the xxd server, whose database keeps only 3-byte
/// UTF-8: a 4-byte character such as 👍 is stored as "????". Known emoji
/// become Emojione shortnames (`:thumbsup:`), as the official client sends
/// them; any other 4-byte character becomes an HTML numeric entity, which
/// the official client's Markdown renderer shows as the character.
class EncodeEmoji {
  const EncodeEmoji();

  static final Map<int, String> _names = {
    for (final MapEntry(:key, :value) in kEmojiShortnames.entries) value: key,
  };

  String call(String text) {
    if (!text.runes.any((r) => r > 0xFFFF)) return text;
    final out = StringBuffer();
    for (final rune in text.runes) {
      if (rune <= 0xFFFF) {
        out.writeCharCode(rune);
      } else if (_names[rune] case final name?) {
        out.write(':$name:');
      } else {
        out.write('&#x${rune.toRadixString(16).toUpperCase()};');
      }
    }
    return out.toString();
  }
}
