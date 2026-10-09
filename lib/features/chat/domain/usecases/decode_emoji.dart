import '../value_objects/emoji_shortnames.dart';
import '../value_objects/emojione_shortnames.dart';

/// Shows what [EncodeEmoji] and the official client send as emoji again:
/// Emojione `:shortname:`s (the client's full set: flags, skin tones…) and
/// HTML numeric entities (`&#x1F44D;`, `&#128077;`). Unknown shortnames are
/// left as typed.
class DecodeEmoji {
  const DecodeEmoji();

  static final _token = RegExp(
    r':([a-z0-9_+\-]+):|&#x([0-9a-fA-F]{1,6});|&#([0-9]{1,7});',
  );

  String call(String text) {
    if (!text.contains(':') && !text.contains('&#')) return text;
    return text.replaceAllMapped(_token, (m) {
      if (m[1] case final name?) {
        return kEmojioneShortnames[name] ??
            kEmojioneShortnames[kEmojiAliases[name]] ??
            m[0]!;
      }
      final rune = m[2] != null
          ? int.tryParse(m[2]!, radix: 16)
          : int.tryParse(m[3] ?? '');
      return rune != null && rune > 0 && rune <= 0x10FFFF
          ? String.fromCharCode(rune)
          : m[0]!;
    });
  }
}
