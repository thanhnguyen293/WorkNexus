import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_sticker.freezed.dart';

/// A sticker image: one of a set bundled with the app ([custom] false,
/// [location] is the asset key) or one kept on this device ([custom] true,
/// [location] is the file path) — added by the user one by one ([pack]
/// empty) or as an imported set. Sent as an ordinary image message, so every
/// client shows it.
@freezed
abstract class ChatSticker with _$ChatSticker {
  const factory ChatSticker({
    /// Unique among all stickers (the location).
    required String id,

    /// The set it belongs to: a bundled folder name, an imported set's id, or
    /// empty for the user's own stickers.
    required String pack,

    /// The set's name to show, when it is not [pack] itself (an imported
    /// set's title).
    String? packTitle,

    /// File name sent with the image.
    required String name,
    required String location,
    @Default(false) bool custom,

    /// The emoji it stands for, most fitting first (`😂🤣`): from the
    /// Telegram set it was imported from, or the bundled set's tags. Empty
    /// for the user's own stickers, which are then never suggested.
    @Default('') String emoji,

    /// Words it is suggested for besides its emoji, folded (lower case, no
    /// diacritics): `cam on`, `ship it`.
    @Default(<String>[]) List<String> keywords,
  }) = _ChatSticker;
}
