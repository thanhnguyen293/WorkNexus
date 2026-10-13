/// Moves whitespace at the end of emphasis out of its markers:
/// `**word **` → `**word** `. Markdown does not count emphasis that ends in
/// a space; the composer writes its own formatting tidily (see
/// `BuildMessageText`), this catches Markdown typed by hand.
class TidyMarkdownEmphasis {
  const TidyMarkdownEmphasis();

  /// Longest markers first, so bold is tidied before italic looks at it.
  static final _patterns = [
    RegExp(r'(\*\*)(?!\s)([^\n]*?\S)(\s+)(\*\*)'),
    RegExp(r'(~~)(?!\s)([^\n]*?\S)(\s+)(~~)'),
    RegExp(r'(<u>)(?!\s)([^\n]*?\S)(\s+)(</u>)'),
    RegExp(r'(?<!\*)(\*)(?![\s*])([^\n]*?\S)(\s+)(\*)(?!\*)'),
  ];

  String call(String text) => _patterns.fold(
    text,
    (out, pattern) =>
        out.replaceAllMapped(pattern, (m) => '${m[1]}${m[2]}${m[4]}${m[3]}'),
  );
}
