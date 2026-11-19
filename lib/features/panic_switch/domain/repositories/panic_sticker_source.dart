import 'dart:typed_data';

import '../../../../core/error/result.dart';

/// The "Thầy vô" sticker image.
abstract interface class PanicStickerSource {
  Future<Result<Uint8List>> bytes();
}
