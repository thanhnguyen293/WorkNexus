import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_name_service.dart';

/// The name service; `main` wires it to the tray, anything else gets one with
/// no tray to follow.
final appNameServiceProvider = Provider<AppNameService>(
  (ref) => AppNameService(),
);

/// The name the user gave the app; null while it has its own.
final appNameProvider = AsyncNotifierProvider<AppNameController, String?>(
  AppNameController.new,
);

class AppNameController extends AsyncNotifier<String?> {
  AppNameService get _service => ref.read(appNameServiceProvider);

  @override
  Future<String?> build() => _service.current();

  /// Keeps [name]; blank gives the app its own name back.
  Future<void> rename(String name) async {
    await _service.rename(name);
    if (ref.mounted) state = AsyncData(await _service.current());
  }
}
