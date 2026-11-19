import 'dart:io';

import 'package:injectable/injectable.dart';

import '../../core/database/database.dart';
import '../../core/domain/repositories/pinned_certificate_repository.dart';
import '../../features/mini_apps/data/datasources/browser_cookies/chromium_cookie_reader.dart';
import '../../features/mini_apps/data/datasources/browser_cookies/firefox_cookie_reader.dart';
import '../../features/mini_apps/data/datasources/browser_cookies/safari_cookie_reader.dart';
import '../../features/mini_apps/data/datasources/cookie_import_store.dart';
import '../../features/mini_apps/data/datasources/favicon_fetcher.dart';
import '../../features/mini_apps/data/datasources/mini_app_icon_storage.dart';
import '../../features/mini_apps/data/datasources/mini_app_local_datasource.dart';
import '../../features/mini_apps/data/datasources/mini_app_permission_local_datasource.dart';
import '../../features/mini_apps/data/datasources/trusted_certificate_store.dart';
import '../../features/mini_apps/data/datasources/web_profile_datasource.dart';
import '../../features/mini_apps/data/datasources/web_view_cookie_datasource.dart';
import '../../features/mini_apps/data/repositories/local_browser_cookie_repository.dart';
import '../../features/mini_apps/data/repositories/local_cookie_import_repository.dart';
import '../../features/mini_apps/data/repositories/local_mini_app_browsing_data_repository.dart';
import '../../features/mini_apps/data/repositories/local_mini_app_permission_repository.dart';
import '../../features/mini_apps/data/repositories/local_mini_app_repository.dart';
import '../../features/mini_apps/data/repositories/local_trusted_certificate_repository.dart';
import '../../features/mini_apps/data/repositories/local_web_view_cookie_repository.dart';
import '../../features/mini_apps/domain/repositories/browser_cookie_repository.dart';
import '../../features/mini_apps/domain/repositories/cookie_import_repository.dart';
import '../../features/mini_apps/domain/repositories/mini_app_browsing_data_repository.dart';
import '../../features/mini_apps/domain/repositories/mini_app_permission_repository.dart';
import '../../features/mini_apps/domain/repositories/mini_app_repository.dart';
import '../../features/mini_apps/domain/repositories/trusted_certificate_repository.dart';
import '../../features/mini_apps/domain/repositories/web_view_cookie_repository.dart';
import '../../features/mini_apps/domain/usecases/add_mini_app.dart';
import '../../features/mini_apps/domain/usecases/check_cookie_imports.dart';
import '../../features/mini_apps/domain/usecases/import_browser_cookies.dart';
import '../../features/mini_apps/domain/usecases/is_pinned_certificate.dart';
import '../../features/mini_apps/domain/usecases/move_mini_app.dart';
import '../../features/mini_apps/domain/usecases/refresh_mini_app_icon.dart';
import '../../features/mini_apps/domain/usecases/resolve_mini_app_permission.dart';
import '../../features/mini_apps/domain/usecases/update_mini_app.dart';
import 'app_support_path.dart';

/// Wiring for mini apps, kept out of the main composition root
/// (`service_locator.dart`) so that file stays within its size budget.
@module
abstract class MiniAppsModule {
  @lazySingleton
  TrustedCertificateRepository trustedCertificateRepository() =>
      LocalTrustedCertificateRepository(
        TrustedCertificateStore(
          file: () async =>
              File(await appSupportPath('trusted_certificates.json')),
        ),
      );

  @lazySingleton
  MiniAppRepository miniAppRepository(AppDatabase db) => LocalMiniAppRepository(
    MiniAppLocalDatasource(db),
    MiniAppIconStorage(
      () async => Directory(await appSupportPath('mini_app_icons')),
    ),
    FaviconFetcher(),
  );

  @lazySingleton
  RefreshMiniAppIcon refreshMiniAppIcon(MiniAppRepository repository) =>
      RefreshMiniAppIcon(repository);

  @lazySingleton
  AddMiniApp addMiniApp(
    MiniAppRepository repository,
    RefreshMiniAppIcon refreshIcon,
  ) => AddMiniApp(repository, refreshIcon);

  @lazySingleton
  MiniAppPermissionRepository miniAppPermissionRepository(AppDatabase db) =>
      LocalMiniAppPermissionRepository(MiniAppPermissionLocalDatasource(db));

  @lazySingleton
  ResolveMiniAppPermission resolveMiniAppPermission(
    MiniAppPermissionRepository repository,
  ) => ResolveMiniAppPermission(repository);

  @lazySingleton
  UpdateMiniApp updateMiniApp(
    MiniAppRepository repository,
    RefreshMiniAppIcon refreshIcon,
  ) => UpdateMiniApp(repository, refreshIcon);

  @lazySingleton
  MoveMiniApp moveMiniApp(MiniAppRepository repository) =>
      MoveMiniApp(repository);

  @lazySingleton
  MiniAppBrowsingDataRepository miniAppBrowsingDataRepository() =>
      const LocalMiniAppBrowsingDataRepository(WebProfileDatasource());

  @lazySingleton
  BrowserCookieRepository browserCookieRepository() =>
      LocalBrowserCookieRepository(
        chromium: ChromiumCookieReader(),
        firefox: const FirefoxCookieReader(),
        safari: const SafariCookieReader(),
      );

  @lazySingleton
  WebViewCookieRepository webViewCookieRepository() =>
      const LocalWebViewCookieRepository(WebViewCookieDatasource());

  @lazySingleton
  CookieImportRepository cookieImportRepository() =>
      LocalCookieImportRepository(
        CookieImportStore(
          file: () async => File(await appSupportPath('cookie_imports.json')),
        ),
      );

  @lazySingleton
  ImportBrowserCookies importBrowserCookies(
    BrowserCookieRepository browsers,
    WebViewCookieRepository webView,
    CookieImportRepository imports,
  ) => ImportBrowserCookies(browsers, webView, imports);

  @lazySingleton
  IsPinnedCertificate isPinnedCertificate(PinnedCertificateRepository pins) =>
      IsPinnedCertificate(pins);

  @lazySingleton
  CheckCookieImports checkCookieImports(
    CookieImportRepository imports,
    WebViewCookieRepository webView,
  ) => CheckCookieImports(imports, webView);
}
