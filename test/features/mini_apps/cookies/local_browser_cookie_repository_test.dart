import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/mini_apps/data/datasources/browser_cookies/chromium_cookie_reader.dart';
import 'package:work_nexus/features/mini_apps/data/datasources/browser_cookies/firefox_cookie_reader.dart';
import 'package:work_nexus/features/mini_apps/data/datasources/browser_cookies/safari_cookie_reader.dart';
import 'package:work_nexus/features/mini_apps/data/datasources/browser_cookies/sqlite_snapshot.dart';
import 'package:work_nexus/features/mini_apps/data/repositories/local_browser_cookie_repository.dart';
import 'package:work_nexus/features/mini_apps/domain/entities/cookie_source.dart';
import 'package:work_nexus/features/mini_apps/domain/value_objects/cookie_browser.dart';
import 'package:work_nexus/features/mini_apps/domain/value_objects/cookie_read_problem.dart';

class _Chromium extends Mock implements ChromiumCookieReader {}

class _Firefox extends Mock implements FirefoxCookieReader {}

class _Safari extends Mock implements SafariCookieReader {}

void main() {
  late _Chromium chromium;
  late _Firefox firefox;
  late _Safari safari;
  late LocalBrowserCookieRepository repository;

  setUpAll(() => registerFallbackValue(CookieBrowser.chrome));

  setUp(() {
    chromium = _Chromium();
    firefox = _Firefox();
    safari = _Safari();
    when(() => chromium.profiles(any())).thenAnswer((_) async => const []);
    when(() => firefox.profiles()).thenAnswer((_) async => const []);
    when(() => safari.installed).thenReturn(false);
    repository = LocalBrowserCookieRepository(
      chromium: chromium,
      firefox: firefox,
      safari: safari,
    );
  });

  group('sources', () {
    test(
      'a browser that cannot be looked at does not hide the others',
      () async {
        when(
          () => chromium.profiles(CookieBrowser.chrome),
        ).thenThrow(const FileSystemException('refused'));
        when(
          () => chromium.profiles(CookieBrowser.edge),
        ).thenAnswer((_) async => [(path: '/edge/Default', name: 'Work')]);
        when(
          () => firefox.profiles(),
        ).thenThrow(const FormatException('bad profiles.ini'));

        final result = await repository.sources();

        expect(result, isA<Ok<List<CookieSource>>>());
        final sources = (result as Ok<List<CookieSource>>).value;
        expect(sources.single.browser, CookieBrowser.edge);
        expect(sources.single.profileName, 'Work');
      },
    );

    test('fails, not "none found", when nothing could be looked at', () async {
      when(
        () => chromium.profiles(any()),
      ).thenThrow(const FileSystemException('refused'));

      final result = await repository.sources();

      expect(result, isA<Err<List<CookieSource>>>());
    });

    test('nothing installed is an empty list', () async {
      expect(
        (await repository.sources() as Ok<List<CookieSource>>).value,
        isEmpty,
      );
    });
  });

  group('read', () {
    const edge = CookieSource(
      browser: CookieBrowser.edge,
      profileId: '/edge/Default',
      profileName: 'Default',
    );

    Future<Failure> failureOf(Object error) async {
      when(() => chromium.read(any(), any())).thenThrow(error);
      final result = await repository.read(edge);
      return (result as Err).failure;
    }

    test('a locked cookie file says the browser is busy', () async {
      final failure = await failureOf(const CookieStoreInUseException('x'));
      expect(failure.cause, CookieReadProblem.browserBusy);
    });

    test('app-bound cookies say only the browser can read them', () async {
      final failure = await failureOf(
        const AppBoundEncryptionException(CookieBrowser.chrome),
      );
      expect(failure.cause, CookieReadProblem.appBoundEncryption);
    });
  });
}
