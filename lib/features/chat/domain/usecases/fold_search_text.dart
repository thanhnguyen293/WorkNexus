import 'decode_emoji.dart';
import 'parse_message_content.dart';

/// Reduces text to the form message search compares: lower case, without
/// Vietnamese diacritics (`Đường` → `duong`) and with runs of whitespace
/// collapsed. SQLite's `LIKE` folds case for ASCII only and never strips
/// accents, so both the stored message and the query go through this.
class FoldSearchText {
  const FoldSearchText();

  static const _decodeEmoji = DecodeEmoji();

  /// `[@Name](@#40)` → `@Name`.
  static final _mention = RegExp(r'\[@([^\]]+)\]\(@#\d+\)');

  /// `[label](url)` → `label url`.
  static final _link = RegExp(r'\[([^\]]*)\]\(([^)\s]*)\)');

  /// Markdown emphasis and code markers. `_` is kept: it is part of too many
  /// identifiers (`snake_case`) people search for.
  static final _markdownMarks = RegExp(r'[*~`]');

  /// Combining diacritics, for text typed in decomposed form (NFD).
  static final _combining = RegExp(r'[̀-ͯ]');

  static final _space = RegExp(r'\s+');

  static const _object = '\u{FFFC}';

  static const _bases = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };

  static final _baseOf = {
    for (final MapEntry(key: base, value: accented) in _bases.entries)
      for (final rune in accented.runes) rune: base.codeUnitAt(0),
  };

  /// The searchable text of a stored message, or null for one that is not
  /// text (an image or file row's content is a JSON payload).
  String? ofMessage(String contentType, String content) {
    if (contentType != 'plain' && contentType != 'text') return null;
    var text = ParseMessageContent.repairMentions(
      content.replaceAll(_object, ''),
    );
    text = text
        .replaceAllMapped(_mention, (m) => '@${m[1]}')
        .replaceAllMapped(_link, (m) => '${m[1]} ${m[2]}');
    if (contentType == 'text') text = text.replaceAll(_markdownMarks, '');
    return call(_decodeEmoji(text));
  }

  String call(String text) {
    final out = StringBuffer();
    for (final rune in text.toLowerCase().runes) {
      out.writeCharCode(_baseOf[rune] ?? rune);
    }
    return out
        .toString()
        .replaceAll(_combining, '')
        .replaceAll(_space, ' ')
        .trim();
  }
}
