import 'package:freezed_annotation/freezed_annotation.dart';

part 'message_content.freezed.dart';

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

  /// A shared link card (`object` content of type `url`), e.g. a ZenTao task.
  const factory MessageContent.link({required String url, String? title}) =
      LinkContent;

  /// Anything v1 does not render (emoticons, cards, conference invites, …).
  const factory MessageContent.unsupported(String contentType) =
      UnsupportedContent;
}
