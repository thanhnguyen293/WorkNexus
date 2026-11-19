import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/mini_apps/domain/entities/cookie_source.dart';
import 'package:work_nexus/features/mini_apps/domain/value_objects/cookie_browser.dart';
import 'package:work_nexus/features/mini_apps/presentation/util/cookie_import_support.dart';

void main() {
  CookieSource of(CookieBrowser browser) =>
      CookieSource(browser: browser, profileId: 'p', profileName: 'Default');

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('Chrome cannot be imported from on Windows; the others can', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(cookieImportSupported(of(CookieBrowser.chrome)), isFalse);
    expect(cookieImportSupported(of(CookieBrowser.edge)), isTrue);
    expect(cookieImportSupported(of(CookieBrowser.firefox)), isTrue);
  });

  test('Chrome can be imported from on macOS', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(cookieImportSupported(of(CookieBrowser.chrome)), isTrue);
  });
}
