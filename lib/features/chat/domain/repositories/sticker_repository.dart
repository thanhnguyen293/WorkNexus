import 'dart:typed_data';

import '../../../../core/error/result.dart';
import '../entities/chat_sticker.dart';

/// A sticker file to keep: its name and image.
typedef StickerFile = ({String name, Uint8List bytes});

/// Sticker sets bundled with the app, imported sets and the user's own
/// stickers.
abstract class StickerRepository {
  /// Every sticker: bundled sets first, then imported sets, then the user's
  /// own (newest first).
  Future<Result<List<ChatSticker>>> stickers();

  /// The image of [sticker], to send.
  Future<Result<Uint8List>> bytes(ChatSticker sticker);

  /// Keeps [bytes] as one of the user's own stickers.
  Future<Result<ChatSticker>> add(Uint8List bytes, {required String name});

  /// Removes one of the user's own stickers.
  Future<Result<void>> remove(ChatSticker sticker);

  /// Keeps an imported set as [pack] (replacing one with that id), shown as
  /// [title].
  Future<Result<void>> addPack(
    String pack, {
    required String title,
    required List<StickerFile> stickers,
  });

  /// Removes an imported set.
  Future<Result<void>> removePack(String pack);
}
