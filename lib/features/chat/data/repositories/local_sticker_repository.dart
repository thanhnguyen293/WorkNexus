import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/chat_sticker.dart';
import '../../domain/repositories/sticker_pack_source.dart';
import '../../domain/repositories/sticker_repository.dart';

/// Where bundled sets live: one folder per set (each folder is listed in
/// pubspec.yaml).
const String kStickerAssetRoot = 'assets/stickers/';

const _imageExtensions = {'png', 'gif', 'webp', 'jpg', 'jpeg'};

/// Bundled sets come from the asset manifest; the user's own stickers are
/// files in [directory], named `<epoch ms>_<name>` so the newest sort first;
/// an imported set is a folder under `packs/` holding its images and a
/// `pack.json` with its id and title.
class LocalStickerRepository implements StickerRepository {
  LocalStickerRepository({
    required AssetBundle bundle,
    required Future<Directory> Function() directory,
    StickerConverter? converter,
  }) : _bundle = bundle,
       _directory = directory,
       _converter = converter;

  final AssetBundle _bundle;
  final Future<Directory> Function() _directory;

  /// Fits a sticker the user adds to the bundled sets' size; without one
  /// (tests) it is kept as it came.
  final StickerConverter? _converter;

  @override
  Future<Result<List<ChatSticker>>> stickers() async {
    try {
      return Ok([
        ...await _bundled(),
        ...await _imported(),
        ...await _custom(),
      ]);
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

  Future<Directory> _packsDir() async =>
      Directory('${(await _directory()).path}${Platform.pathSeparator}packs');

  /// Where set [pack] is kept: its id made safe as a folder name.
  Future<Directory> _packDir(String pack) async => Directory(
    '${(await _packsDir()).path}${Platform.pathSeparator}'
    '${pack.replaceAll(RegExp(r'[^\w.\-]'), '_')}',
  );

  Future<List<ChatSticker>> _imported() async {
    final root = await _packsDir();
    if (!root.existsSync()) return const [];
    final folders =
        root
            .listSync()
            .whereType<Directory>()
            .where((d) => !_nameOf(d).startsWith('.'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    return [for (final folder in folders) ...await _packStickers(folder)];
  }

  Future<List<ChatSticker>> _packStickers(Directory folder) async {
    final meta = File('${folder.path}${Platform.pathSeparator}$_packMeta');
    if (!meta.existsSync()) return const [];
    final json = jsonDecode(await meta.readAsString());
    if (json is! Map || json['id'] is! String) return const [];
    final pack = json['id'] as String;
    final title = json['title'] is String ? json['title'] as String : pack;
    final files =
        folder
            .listSync()
            .whereType<File>()
            .where((f) => _isImage(f.path))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    return [
      for (final f in files)
        ChatSticker(
          id: f.path,
          pack: pack,
          packTitle: title,
          name: f.uri.pathSegments.last,
          location: f.path,
          custom: true,
        ),
    ];
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
    // An image that cannot be fitted is still worth keeping as it came.
    final fitted = (await _converter?.imageToWebp(bytes))?.valueOrNull;
    if (fitted != null) {
      bytes = fitted;
      final dot = name.lastIndexOf('.');
      name = '${dot > 0 ? name.substring(0, dot) : name}.webp';
    }
    try {
      final dir = await _directory();
      await dir.create(recursive: true);
      final safe = name.replaceAll(RegExp(r'[^\w.\-]'), '_');
      final sep = Platform.pathSeparator;
      final file = File(
        '${dir.path}$sep${DateTime.now().millisecondsSinceEpoch}_'
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

  @override
  Future<Result<void>> addPack(
    String pack, {
    required String title,
    required List<StickerFile> stickers,
  }) async {
    if (stickers.isEmpty) {
      return const Err(UnexpectedFailure('Cannot keep an empty set'));
    }
    try {
      final target = await _packDir(pack);
      final sep = Platform.pathSeparator;
      // Written beside the set first, so a failed write never leaves a half
      // set (or loses the one it replaces).
      final staging = Directory(
        '${target.parent.path}$sep.${_nameOf(target)}.tmp',
      );
      if (staging.existsSync()) await staging.delete(recursive: true);
      await staging.create(recursive: true);
      for (final sticker in stickers) {
        final safe = sticker.name.replaceAll(RegExp(r'[^\w.\-]'), '_');
        await File('${staging.path}$sep$safe').writeAsBytes(sticker.bytes);
      }
      await File(
        '${staging.path}$sep$_packMeta',
      ).writeAsString(jsonEncode({'id': pack, 'title': title}), flush: true);
      if (target.existsSync()) await target.delete(recursive: true);
      await staging.rename(target.path);
      return const Ok(null);
    } on Exception catch (e) {
      return Err(StorageFailure('Could not keep the sticker set', cause: e));
    }
  }

  @override
  Future<Result<void>> removePack(String pack) async {
    try {
      final dir = await _packDir(pack);
      if (dir.existsSync()) await dir.delete(recursive: true);
      return const Ok(null);
    } on Exception catch (e) {
      return Err(StorageFailure('Could not remove the sticker set', cause: e));
    }
  }

  @override
  Future<Result<String?>> lastPack() async {
    try {
      final file = await _lastPackFile();
      return Ok(file.existsSync() ? await file.readAsString() : null);
    } on Exception catch (e) {
      return Err(
        StorageFailure('Could not read the last sticker set', cause: e),
      );
    }
  }

  @override
  Future<Result<void>> rememberPack(String pack) async {
    try {
      final file = await _lastPackFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(pack, flush: true);
      return const Ok(null);
    } on Exception catch (e) {
      return Err(
        StorageFailure('Could not keep the last sticker set', cause: e),
      );
    }
  }

  Future<File> _lastPackFile() async => File(
    '${(await _directory()).path}${Platform.pathSeparator}$_lastPackName',
  );

  static const _packMeta = 'pack.json';

  /// Holds the id of the set last picked from; not an image, so never listed.
  static const _lastPackName = 'last_pack';

  /// The last part of [entity]'s path (a folder's own name).
  static String _nameOf(FileSystemEntity entity) => entity.path
      .split(Platform.pathSeparator)
      .lastWhere((part) => part.isNotEmpty);

  static bool _isImage(String path) =>
      _imageExtensions.contains(path.split('.').last.toLowerCase());
}
