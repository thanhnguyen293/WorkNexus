import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/error/result.dart';
import '../../../../core/settings/app_settings.dart';
import '../../domain/repositories/wallpaper_repository.dart';

final wallpaperRepositoryProvider = Provider<WallpaperRepository>(
  (ref) => getIt<WallpaperRepository>(),
);

/// The user's wallpaper images, newest first.
final chatWallpapersProvider = FutureProvider.autoDispose<Result<List<String>>>(
  (ref) => ref.watch(wallpaperRepositoryProvider).wallpapers(),
);

final wallpaperControllerProvider = Provider<WallpaperController>(
  (ref) => WallpaperController(
    ref.watch(wallpaperRepositoryProvider),
    settings: ref.read(appSettingsProvider.notifier),
    current: () => ref.read(appSettingsProvider).chatWallpaper,
    onChanged: () => ref.invalidate(chatWallpapersProvider),
  ),
);

/// Adding, picking and removing wallpaper images (CRUD over the repository
/// plus the setting that names the one in use).
class WallpaperController {
  WallpaperController(
    this._repository, {
    required AppSettingsController settings,
    required String Function() current,
    required void Function() onChanged,
  }) : _settings = settings,
       _current = current,
       _onChanged = onChanged;

  final WallpaperRepository _repository;
  final AppSettingsController _settings;
  final String Function() _current;
  final void Function() _onChanged;

  /// Keeps the image and uses it right away.
  Future<Result<void>> add(Uint8List bytes, String name) async {
    final result = await _repository.add(bytes, name: name);
    if (result case Ok(:final value)) {
      _settings.setChatWallpaper(value);
      _onChanged();
    }
    return result;
  }

  /// Removes an image; the chat falls back to the style's own background
  /// when it was the one in use.
  Future<Result<void>> remove(String path) async {
    final result = await _repository.remove(path);
    if (result is Ok) {
      if (_current() == path) _settings.setChatWallpaper('');
      _onChanged();
    }
    return result;
  }
}
