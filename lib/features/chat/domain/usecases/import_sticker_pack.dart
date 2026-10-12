import 'dart:typed_data';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/remote_sticker_set.dart';
import '../repositories/sticker_pack_source.dart';
import '../repositories/sticker_repository.dart';
import 'parse_sticker_pack_link.dart';

/// What importing a set did: the set kept, how many stickers it got, how
/// many of those are a still stand-in for an animation, and how many could
/// not be fetched at all.
typedef ImportedStickerPack = ({
  String pack,
  String title,
  int added,
  int stills,
  int failed,
});

/// Imports a Telegram sticker set from its link as one of the user's sets.
///
/// Everything is kept as WebP at the app's sticker size, the image a chat
/// message can carry: still stickers scaled down, animated (`.tgs`) ones
/// converted to an animated WebP, and video (`.webm`) ones — which nothing
/// here can decode — as their still thumbnail. An animation that cannot be
/// converted falls back to its thumbnail too.
class ImportStickerPack {
  const ImportStickerPack(this._source, this._converter, this._stickers);

  final StickerPackSource _source;
  final StickerConverter _converter;
  final StickerRepository _stickers;

  /// The pack id an imported set is kept under.
  static String packIdOf(String setName) => 'tg:$setName';

  Future<Result<ImportedStickerPack>> call(
    String link, {
    required String token,
    void Function(int done, int total)? onProgress,
  }) async {
    final name = const ParseStickerPackLink()(link);
    if (name == null) {
      return const Err(ValidationFailure('Not a Telegram sticker link'));
    }
    final RemoteStickerSet set;
    switch (await _source.stickerSet(name, token: token)) {
      case Ok(:final value):
        set = value;
      case Err(:final failure):
        return Err(failure);
    }
    final files = <StickerFile>[];
    var stills = 0;
    var failed = 0;
    Failure? lastFailure;
    final total = set.stickers.length;
    for (final (i, sticker) in set.stickers.indexed) {
      switch (await _webp(sticker, token)) {
        case Ok(value: (:final bytes, :final still)):
          final number = '${i + 1}'.padLeft(3, '0');
          files.add((name: '$number.webp', bytes: bytes));
          if (still) stills++;
        case Err(:final failure):
          failed++;
          lastFailure = failure;
      }
      onProgress?.call(i + 1, total);
    }
    if (files.isEmpty) {
      return Err(lastFailure ?? const NotFoundFailure('The set is empty'));
    }
    final pack = packIdOf(set.name);
    final saved = await _stickers.addPack(
      pack,
      title: set.title,
      stickers: files,
    );
    return switch (saved) {
      Ok() => Ok((
        pack: pack,
        title: set.title,
        added: files.length,
        stills: stills,
        failed: failed,
      )),
      Err(:final failure) => Err(failure),
    };
  }

  /// [sticker] as WebP, and whether that is a still stand-in.
  Future<Result<({Uint8List bytes, bool still})>> _webp(
    RemoteSticker sticker,
    String token,
  ) async {
    if (sticker.kind == RemoteStickerKind.still) {
      return _fetch(sticker.fileId, token, still: false);
    }
    if (sticker.kind == RemoteStickerKind.animated) {
      final tgs = await _source.file(sticker.fileId, token: token);
      if (tgs case Ok(:final value)) {
        if (await _converter.animatedToWebp(value) case Ok(value: final webp)) {
          return Ok((bytes: webp, still: false));
        }
      }
    }
    final thumbnail = sticker.thumbnailFileId;
    if (thumbnail == null) {
      return const Err(NotFoundFailure('No still image of this sticker'));
    }
    return _fetch(thumbnail, token, still: true);
  }

  Future<Result<({Uint8List bytes, bool still})>> _fetch(
    String fileId,
    String token, {
    required bool still,
  }) async {
    final Uint8List bytes;
    switch (await _source.file(fileId, token: token)) {
      case Ok(:final value):
        bytes = value;
      case Err(:final failure):
        return Err(failure);
    }
    // An image that cannot be scaled is still worth keeping as it came.
    final fitted = (await _converter.stillToWebp(bytes)).valueOrNull;
    return Ok((bytes: fitted ?? bytes, still: still));
  }
}
