import 'dart:typed_data';

import '../../../../core/error/result.dart';
import '../entities/remote_sticker_set.dart';

/// Where sticker sets are imported from (Telegram, through a bot token).
abstract interface class StickerPackSource {
  /// The set called [name], as listed (no files fetched yet).
  Future<Result<RemoteStickerSet>> stickerSet(
    String name, {
    required String token,
  });

  /// The file [fileId] of a sticker or its thumbnail.
  Future<Result<Uint8List>> file(String fileId, {required String token});
}

/// Turns imported stickers into WebP at the app's sticker size — the image a
/// chat message can carry, matching the bundled sets.
abstract interface class StickerConverter {
  /// An animated (`.tgs`) sticker as an animated WebP.
  Future<Result<Uint8List>> animatedToWebp(Uint8List tgs);

  /// An image (WebP, PNG, GIF…) fitted into the sticker size, as WebP; an
  /// animated one stays animated.
  Future<Result<Uint8List>> imageToWebp(Uint8List image);
}

/// The Telegram bot token sets are fetched with, kept on this device.
abstract interface class TelegramTokenStore {
  Future<String?> read();
  Future<void> write(String token);
}
