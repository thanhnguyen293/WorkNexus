import '../value_objects/emoji_shortnames.dart';

/// Shows what [EncodeEmoji] and the official client send as emoji again:
/// known `:shortname:`s and HTML numeric entities (`&#x1F44D;`, `&#128077;`).
/// Unknown shortnames are left as typed.
class DecodeEmoji {
  const DecodeEmoji();

  static final _token = RegExp(
    r':([a-z0-9_+\-]+):|&#x([0-9a-fA-F]{1,6});|&#([0-9]{1,7});',
  );

  String call(String text) {
    if (!text.contains(':') && !text.contains('&#')) return text;
    return text.replaceAllMapped(_token, (m) {
      final int? rune;
      if (m[1] case final name?) {
        rune = kEmojiShortnames[kEmojiAliases[name] ?? name];
      } else if (m[2] case final hex?) {
        rune = int.tryParse(hex, radix: 16);
      } else {
        rune = int.tryParse(m[3] ?? '');
      }
      return rune != null && rune > 0 && rune <= 0x10FFFF
          ? String.fromCharCode(rune)
          : m[0]!;
    });
  }
}
