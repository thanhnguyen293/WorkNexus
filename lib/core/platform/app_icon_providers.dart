import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_icon_service.dart';

/// The icon service; `main` wires it to the tray, anything else gets one with
/// no tray to follow.
final appIconServiceProvider = Provider<AppIconService>(
  (ref) => AppIconService(),
);

/// The picture the user chose as the app's icon; null while it has its own.
final appIconProvider = AsyncNotifierProvider<AppIconController, File?>(
  AppIconController.new,
);

class AppIconController extends AsyncNotifier<File?> {
  AppIconService get _service => ref.read(appIconServiceProvider);

  @override
  Future<File?> build() => _service.current();

  /// Uses the image at [path]; false when it is not an image.
  Future<bool> choose(String path) async {
    final done = await _service.choose(path);
    if (done && ref.mounted) state = AsyncData(await _service.current());
    return done;
  }

  Future<void> reset() async {
    await _service.reset();
    if (ref.mounted) state = const AsyncData(null);
  }
}
