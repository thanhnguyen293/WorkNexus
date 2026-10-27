import '../value_objects/message_content.dart';
import 'parse_message_content.dart';

/// Whether a stored message is a reaction (see `ChatMessageReaction`): a
/// reply that is just an emoji. The one definition the ingestor (what counts
/// as unread) and the mapper (what the timeline shows) both go by.
class IsReactionRow {
  const IsReactionRow([this._parse = const ParseMessageContent()]);

  final ParseMessageContent _parse;

  /// The server sends a retracted message back without its content, so a
  /// retracted reaction is an empty reply of the emoji's content type
  /// (`image` for the wire form, `emotion` for newer clients). A retracted
  /// image reply looks the same and is treated alike.
  bool retracted({
    required int? replyToId,
    required bool deleted,
    required String contentType,
    required String content,
  }) =>
      deleted &&
      replyToId != null &&
      content.isEmpty &&
      (contentType == 'image' || contentType == 'emotion');

  bool call({
    required int? replyToId,
    required bool deleted,
    required String contentType,
    required String content,
  }) =>
      replyToId != null &&
      (retracted(
            replyToId: replyToId,
            deleted: deleted,
            contentType: contentType,
            content: content,
          ) ||
          _parse(contentType, content) is EmojiContent);
}
