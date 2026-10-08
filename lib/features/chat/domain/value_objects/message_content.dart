import 'package:freezed_annotation/freezed_annotation.dart';

part 'message_content.freezed.dart';

/// A button under a notification: open [url].
@freezed
abstract class NotificationAction with _$NotificationAction {
  const factory NotificationAction({
    required String label,
    required String url,
  }) = _NotificationAction;
}

/// What a chat message carries, parsed from xxd's `contentType` + `content`
/// (see `ParseMessageContent`).
@freezed
sealed class MessageContent with _$MessageContent {
  /// Text. xxd's `text` content type is Markdown ([markdown]), `plain` is
  /// literal. Mentions stay in their wire form `[@Name](@#userId)` (which is
  /// also a Markdown link); rendering them is a presentation concern.
  const factory MessageContent.text(
    String text, {
    @Default(false) bool markdown,
  }) = TextContent;

  /// An image. [time] is the upload time in milliseconds, which the signed
  /// download URL needs. Small images are sent inline instead of uploaded:
  /// then [inlineBase64] holds the bytes and [fileId] is 0.
  const factory MessageContent.image({
    required int fileId,
    required String name,
    required int size,
    required int time,
    String? mimeType,
    int? width,
    int? height,
    String? inlineBase64,

    /// The server stored a smaller preview (`thumb_<name>`) to show inline.
    @Default(false) bool hasThumb,
  }) = ImageContent;

  /// Any other uploaded file; same download rules as an image.
  const factory MessageContent.file({
    required int fileId,
    required String name,
    required int size,
    required int time,
    String? mimeType,
  }) = FileContent;

  /// One emoji sent large, without a bubble (the official client's
  /// emoticon message); [emoji] is the character itself.
  const factory MessageContent.emoji(String emoji) = EmojiContent;

  /// A notification from ZenTao or xuanbot (the bot chat): a [title] and
  /// [subtitle] over Markdown [text], a link to the item ([url]) and
  /// further [actions]. [sender] names who it is from when not the bot.
  const factory MessageContent.notification({
    String? title,
    String? subtitle,
    @Default('') String text,
    @Default(true) bool markdown,
    String? url,
    @Default(<NotificationAction>[]) List<NotificationAction> actions,
    String? sender,
  }) = NotificationContent;

  /// A shared link card (`object` content of type `url`), e.g. a ZenTao task.
  const factory MessageContent.link({required String url, String? title}) =
      LinkContent;

  /// Anything v1 does not render (emoticons, cards, conference invites, …).
  const factory MessageContent.unsupported(String contentType) =
      UnsupportedContent;
}
