import 'package:freezed_annotation/freezed_annotation.dart';

part 'remote_sticker_set.freezed.dart';

/// How a Telegram sticker is drawn: a still image, a Lottie animation
/// (`.tgs`) or a short video (`.webm`).
enum RemoteStickerKind { still, animated, video }

/// A sticker set as Telegram lists it, before any file is fetched.
@freezed
abstract class RemoteStickerSet with _$RemoteStickerSet {
  const factory RemoteStickerSet({
    /// The set's short name, as in `t.me/addstickers/<name>`.
    required String name,
    required String title,
    required List<RemoteSticker> stickers,
  }) = _RemoteStickerSet;
}

@freezed
abstract class RemoteSticker with _$RemoteSticker {
  const factory RemoteSticker({
    required String fileId,
    required RemoteStickerKind kind,

    /// A small still image of the sticker, when Telegram has one.
    String? thumbnailFileId,
    @Default('') String emoji,
  }) = _RemoteSticker;
}
