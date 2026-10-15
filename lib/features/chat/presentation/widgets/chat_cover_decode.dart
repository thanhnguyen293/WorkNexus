import '../../domain/value_objects/message_content.dart';

/// How large to decode [content]'s bytes for a square tile of [side] device
/// pixels drawn with `BoxFit.cover`: the source's *shorter* side ends up at
/// [side], so nothing is decoded smaller than drawn (which `cover` would
/// then blow up, blurred), yet a photo is not decoded at its full size.
///
/// Only one of the two is set: `Image.memory` with both distorts. With a
/// photo's dimensions unknown, it decodes in full as before.
({int? cacheWidth, int? cacheHeight}) coverDecodeSize(
  MessageContent content,
  int side,
) => switch (content) {
  ImageContent(:final width?, :final height?) when width > 0 && height > 0 =>
    width > height
        ? (cacheWidth: null, cacheHeight: side)
        : (cacheWidth: side, cacheHeight: null),
  // A video's preview frame is landscape (480 px wide, see the thumbnailer).
  FileContent() => (cacheWidth: null, cacheHeight: side),
  _ => (cacheWidth: null, cacheHeight: null),
};
