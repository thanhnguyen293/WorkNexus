/// Turns the readable `@Name` mentions the composer inserted into xxd's
/// mention markup, `[@Name](@#id)`, which every client renders as a
/// mention and uses to notify that user. `@all` is sent as is.
class EncodeMentions {
  const EncodeMentions();

  /// [mentions] maps each inserted display name to its user id. Longer
  /// names are replaced first so "@An Nguyen" wins over "@An".
  String call(String text, Map<String, int> mentions) {
    if (mentions.isEmpty) return text;
    final names = mentions.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final pattern = RegExp(
      '@(${names.map(RegExp.escape).join('|')})(?![\\w-])',
    );
    return text.replaceAllMapped(
      pattern,
      (m) => '[@${m[1]}](@#${mentions[m[1]]})',
    );
  }
}
