import 'package:freezed_annotation/freezed_annotation.dart';

part 'link_preview.freezed.dart';

/// What a shared web page says about itself (OpenGraph / oEmbed), shown as a
/// card under the message that links to it.
@freezed
abstract class LinkPreview with _$LinkPreview {
  const factory LinkPreview({
    required String url,
    String? siteName,
    String? title,
    String? description,
    String? imageUrl,
  }) = _LinkPreview;
}
