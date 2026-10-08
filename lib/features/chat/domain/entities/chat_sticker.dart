import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_sticker.freezed.dart';

/// A sticker image: one of a set bundled with the app ([custom] false,
/// [location] is the asset key) or one the user added ([custom] true,
/// [location] is the file path). Sent as an ordinary image message, so
/// every client shows it.
@freezed
abstract class ChatSticker with _$ChatSticker {
  const factory ChatSticker({
    /// Unique among all stickers (the location).
    required String id,

    /// The set it belongs to: a bundled folder name, or empty for the
    /// user's own stickers.
    required String pack,

    /// File name sent with the image.
    required String name,
    required String location,
    @Default(false) bool custom,
  }) = _ChatSticker;
}
