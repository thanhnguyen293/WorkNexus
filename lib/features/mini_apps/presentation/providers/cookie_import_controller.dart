import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/cookie_import.dart';
import '../../domain/entities/cookie_site.dart';
import '../../domain/entities/cookie_source.dart';
import '../../domain/repositories/browser_cookie_repository.dart';
import '../../domain/repositories/cookie_import_repository.dart';
import '../../domain/repositories/web_view_cookie_repository.dart';
import '../../domain/usecases/check_cookie_imports.dart';
import '../../domain/usecases/group_cookies_by_site.dart';
import '../../domain/usecases/import_browser_cookies.dart';
import '../../domain/value_objects/cookie_site_of.dart';
import 'mini_app_browser_controller.dart';
import 'mini_app_providers.dart';

// The cookie import's dependencies, as providers over the composition root so
// a test replaces one with a fake.
final browserCookieRepositoryProvider = Provider<BrowserCookieRepository>(
  (ref) => getIt<BrowserCookieRepository>(),
);

final webViewCookieRepositoryProvider = Provider<WebViewCookieRepository>(
  (ref) => getIt<WebViewCookieRepository>(),
);

final cookieImportRepositoryProvider = Provider<CookieImportRepository>(
  (ref) => getIt<CookieImportRepository>(),
);

final importBrowserCookiesProvider = Provider<ImportBrowserCookies>(
  (ref) => getIt<ImportBrowserCookies>(),
);

final checkCookieImportsProvider = Provider<CheckCookieImports>(
  (ref) => getIt<CheckCookieImports>(),
);

/// The browser profiles here whose cookies can be read (a pass-through to
/// [BrowserCookieRepository]).
final cookieSourcesProvider = FutureProvider.autoDispose<List<CookieSource>>(
  (ref) async =>
      switch (await ref.read(browserCookieRepositoryProvider).sources()) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      },
);

/// [CookieSource]'s cookies grouped into sites, the mini apps' first. Fails
/// with the read's failure, e.g. an AuthFailure when the system refused.
final cookieSitesProvider = FutureProvider.autoDispose
    .family<List<CookieSite>, CookieSource>((ref, source) async {
      final apps = await ref.watch(miniAppsProvider.future);
      final read = await ref.read(browserCookieRepositoryProvider).read(source);
      return switch (read) {
        Ok(:final value) => const GroupCookiesBySite()(
          value,
          miniAppUrls: [for (final a in apps) a.url],
          now: DateTime.now(),
        ),
        Err(:final failure) => throw failure,
      };
    });

/// The imported sites and whether their sign-in is still in the web view.
/// Importing reloads the open mini apps of those sites, so they show the
/// sign-in at once.
class CookieImportsController extends AsyncNotifier<List<CookieImportState>> {
  @override
  Future<List<CookieImportState>> build() async =>
      switch (await ref.read(checkCookieImportsProvider)()) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      };

  bool get canImport => ref.read(webViewCookieRepositoryProvider).canWrite;

  /// Imports [sites] from [source]; answers how many cookies went in.
  Future<Result<int>> import(CookieSource source, Set<String> sites) async {
    final result = await ref.read(importBrowserCookiesProvider)(source, sites);
    if (!ref.mounted) return result;
    if (result.isOk) {
      await _reloadApps(sites);
      ref.invalidateSelf();
    }
    return result;
  }

  /// Imports [state]'s site again from where it came from.
  Future<Result<int>> reimport(CookieImportState state) =>
      import(state.import.source, {state.import.site});

  Future<Result<void>> forget(String site) async {
    final result = await ref.read(cookieImportRepositoryProvider).forget(site);
    if (ref.mounted && result.isOk) ref.invalidateSelf();
    return result;
  }

  Future<void> _reloadApps(Set<String> sites) async {
    final apps = await ref.read(miniAppsProvider.future);
    for (final app in apps) {
      final host = Uri.tryParse(app.url)?.host ?? '';
      if (host.isEmpty || !sites.contains(cookieSiteOf(host))) continue;
      if (ref.exists(miniAppBrowserProvider(app.id))) {
        ref.read(miniAppBrowserProvider(app.id).notifier).reload();
      }
    }
  }
}

final cookieImportsProvider =
    AsyncNotifierProvider.autoDispose<
      CookieImportsController,
      List<CookieImportState>
    >(CookieImportsController.new);
