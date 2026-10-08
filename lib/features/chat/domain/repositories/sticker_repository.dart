import 'dart:typed_data';

import '../../../../core/error/result.dart';
import '../entities/chat_sticker.dart';

/// Sticker sets bundled with the app plus the user's own stickers.
abstract class StickerRepository {
  /// Every sticker: bundled sets first, then the user's own (newest first).
  Future<Result<List<ChatSticker>>> stickers();

  /// The image of [sticker], to send.
  Future<Result<Uint8List>> bytes(ChatSticker sticker);

  /// Keeps [bytes] as one of the user's own stickers.
  Future<Result<ChatSticker>> add(Uint8List bytes, {required String name});

  /// Removes one of the user's own stickers.
  Future<Result<void>> remove(ChatSticker sticker);
}
