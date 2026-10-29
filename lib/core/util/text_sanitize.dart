/// Pattern matching control characters and invisible non-character code points
/// that should be stripped from user input and table cells.
///
/// Note: U+200D (Zero Width Joiner, ZWJ) is explicitly excluded from this pattern
/// to keep compound emojis (e.g. 👨‍👩‍👧‍👦, professions, flags) intact.
final invisibleCharsPattern = RegExp(
  r'[\uFFFC\uFFFD\uFEFF\u200B\u200C\u0000-\u0008\u000B\u000C\u000E-\u001F]',
);

/// Strips unwanted invisible control code points while keeping compound emoji ZWJ.
String sanitizeInvisibleChars(String text) =>
    text.replaceAll(invisibleCharsPattern, '');
