import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:work_nexus/core/platform/desktop_notifier.dart';
import 'package:work_nexus/features/mini_apps/domain/entities/mini_app.dart';
import 'package:work_nexus/features/mini_apps/presentation/providers/mini_app_providers.dart';

class _QuietNotifier extends DesktopNotifier {
  @override
  Stream<String> get taps => const Stream.empty();

  @override
  Future<bool> initialize() async => true;
}

/// The shell keeps the mini apps mounted (see `MiniAppsHost`): a test that
/// pumps the viewport or the rail gives them an empty list and a notifier
/// that shows nothing, instead of the DI registrations.
List<Override> miniAppShellOverrides({List<MiniApp> apps = const []}) => [
  miniAppsProvider.overrideWith((ref) => Stream.value(apps)),
  miniAppNotifierProvider.overrideWithValue(_QuietNotifier()),
];
