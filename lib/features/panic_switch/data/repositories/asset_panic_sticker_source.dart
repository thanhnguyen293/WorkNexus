import 'package:flutter/services.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/repositories/panic_sticker_source.dart';

/// The sticker from the bundled WorkNexus sticker set.
class AssetPanicStickerSource implements PanicStickerSource {
  AssetPanicStickerSource(this._bundle);

  static const _asset = 'assets/stickers/WorkNexus/thay_vo.png';

  final AssetBundle _bundle;

  @override
  Future<Result<Uint8List>> bytes() async {
    try {
      final data = await _bundle.load(_asset);
      return Ok(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } on Object catch (e) {
      return Err(StorageFailure('Could not load the panic sticker', cause: e));
    }
  }
}
