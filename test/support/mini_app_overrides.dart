import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:work_nexus/core/di/providers.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/platform/desktop_notifier.dart';
import 'package:work_nexus/features/mini_apps/domain/entities/browser_cookie.dart';
import 'package:work_nexus/features/mini_apps/domain/entities/mini_app.dart';
import 'package:work_nexus/features/mini_apps/domain/repositories/web_view_cookie_repository.dart';
import 'package:work_nexus/features/mini_apps/domain/value_objects/cookie_key.dart';
import 'package:work_nexus/features/mini_apps/presentation/providers/cookie_import_controller.dart';
import 'package:work_nexus/features/mini_apps/presentation/providers/mini_app_providers.dart';

class _QuietNotifier extends DesktopNotifier {
  @override
  Stream<String> get taps => const Stream.empty();

  @override
  Future<bool> initialize() async => true;
}

/// A web view that takes no cookies from outside, so the shell offers no
/// cookie import.
class _NoCookieWebView implements WebViewCookieRepository {
  @override
  bool get canWrite => false;

  @override
  Future<Result<void>> write(List<BrowserCookie> cookies) async =>
      const Ok(null);

  @override
  Future<Result<Set<CookieKey>>> present(List<CookieKey> keys) async =>
      const Ok({});
}

/// The shell keeps the mini apps mounted (see `MiniAppsHost`): a test that
/// pumps the viewport or the rail gives them an empty list, a notifier that
/// shows nothing and a web view without cookie import, instead of the DI
/// registrations.
List<Override> miniAppShellOverrides({List<MiniApp> apps = const []}) => [
  miniAppsProvider.overrideWith((ref) => Stream.value(apps)),
  desktopNotifierProvider.overrideWithValue(_QuietNotifier()),
  webViewCookieRepositoryProvider.overrideWithValue(_NoCookieWebView()),
];
