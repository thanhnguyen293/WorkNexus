/// A run of raw mentions jammed together (`@User1@User2`). Only plain names,
/// standing alone: a package (`@types/node@20`), a fediverse handle
/// (`@user@mastodon.social`) or an e-mail continues with `/`, `.domain` or
/// a word before the `@`, and is left be.
final _adjacentAt = RegExp(
  r'(?<![\w./@])@[\p{L}\p{N}_]+(?:@[\p{L}\p{N}_]+)+'
  r'(?=$|[^\p{L}\p{N}_./@-]|\.(?!\w))',
  unicode: true,
);

/// Puts a space between raw mentions jammed together in [text]
/// (`@A@B` → `@A @B`).
String splitAdjacentMentions(String text) => text.replaceAllMapped(
  _adjacentAt,
  (m) => m[0]!.substring(1).split('@').map((n) => '@$n').join(' '),
);
