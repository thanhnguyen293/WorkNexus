import '../value_objects/emojione_shortnames.dart';

/// Whether [text] is just one emoji the official client knows (surrounding
/// whitespace and variation selectors aside) — such a message is sent as a
/// large emoji instead of a text bubble.
class IsSingleEmoji {
  const IsSingleEmoji();

  bool call(String text) {
    final bare = String.fromCharCodes(
      text.trim().runes.where((r) => r != 0xFE0F),
    );
    return kEmojioneCanonicalNames.containsKey(bare);
  }
}
