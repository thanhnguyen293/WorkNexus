import 'dart:io';

import 'package:flutter/services.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/chat_sticker.dart';
import '../../domain/repositories/sticker_repository.dart';

/// Where bundled sets live: one folder per set (each folder is listed in
/// pubspec.yaml).
const String kStickerAssetRoot = 'assets/stickers/';

const _imageExtensions = {'png', 'gif', 'webp', 'jpg', 'jpeg'};

/// Bundled sets come from the asset manifest; the user's own stickers are
/// files in [directory], named `<epoch ms>_<name>` so the newest sort first.
class LocalStickerRepository implements StickerRepository {
  LocalStickerRepository({
    required AssetBundle bundle,
    required Future<Directory> Function() directory,
  }) : _bundle = bundle,
       _directory = directory;

  final AssetBundle _bundle;
  final Future<Directory> Function() _directory;

  @override
  Future<Result<List<ChatSticker>>> stickers() async {
    try {
      return Ok([...await _bundled(), ...await _custom()]);
    } on Exception catch (e) {
      return Err(StorageFailure('Could not list stickers', cause: e));
    }
  }

  Future<List<ChatSticker>> _bundled() async {
    final manifest = await AssetManifest.loadFromAssetBundle(_bundle);
    final keys =
        manifest
            .listAssets()
            .where((k) => k.startsWith(kStickerAssetRoot) && _isImage(k))
            .toList()
          ..sort();
    return [
      for (final key in keys)
        if (key.substring(kStickerAssetRoot.length).split('/') case [
          final pack,
          final name,
        ])
          ChatSticker(id: key, pack: pack, name: name, location: key),
    ];
  }

  Future<List<ChatSticker>> _custom() async {
    final dir = await _directory();
    if (!dir.existsSync()) return const [];
    final files =
        dir.listSync().whereType<File>().where((f) => _isImage(f.path)).toList()
          ..sort((a, b) => b.path.compareTo(a.path));
    return [for (final f in files) _customSticker(f)];
  }

  ChatSticker _customSticker(File file) {
    final base = file.uri.pathSegments.last;
    final cut = base.indexOf('_');
    return ChatSticker(
      id: file.path,
      pack: '',
      name: cut < 0 ? base : base.substring(cut + 1),
      location: file.path,
      custom: true,
    );
  }

  @override
  Future<Result<Uint8List>> bytes(ChatSticker sticker) async {
    try {
      if (sticker.custom) return Ok(await File(sticker.location).readAsBytes());
      final data = await _bundle.load(sticker.location);
      return Ok(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } on Exception catch (e) {
      return Err(StorageFailure('Could not read the sticker', cause: e));
    }
  }

  @override
  Future<Result<ChatSticker>> add(
    Uint8List bytes, {
    required String name,
  }) async {
    if (bytes.isEmpty) {
      return const Err(UnexpectedFailure('Cannot keep an empty sticker'));
    }
    try {
      final dir = await _directory();
      await dir.create(recursive: true);
      final safe = name.replaceAll(RegExp(r'[^\w.\-]'), '_');
      final file = File(
        // The platform separator, so this path equals the one a later directory
        // listing returns for the same file (it is the item's id).
        '${dir.path}${Platform.pathSeparator}'
        '${DateTime.now().millisecondsSinceEpoch}_'
        '${_isImage(safe) ? safe : '$safe.png'}',
      );
      await file.writeAsBytes(bytes, flush: true);
      return Ok(_customSticker(file));
    } on Exception catch (e) {
      return Err(StorageFailure('Could not keep the sticker', cause: e));
    }
  }

  @override
  Future<Result<void>> remove(ChatSticker sticker) async {
    if (!sticker.custom) {
      return const Err(UnexpectedFailure('Bundled stickers stay'));
    }
    try {
      final file = File(sticker.location);
      if (file.existsSync()) await file.delete();
      return const Ok(null);
    } on Exception catch (e) {
      return Err(StorageFailure('Could not remove the sticker', cause: e));
    }
  }

  static bool _isImage(String path) =>
      _imageExtensions.contains(path.split('.').last.toLowerCase());
}
