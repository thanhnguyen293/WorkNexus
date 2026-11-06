import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/mini_apps/domain/entities/browser_cookie.dart';
import 'package:work_nexus/features/mini_apps/domain/entities/cookie_import.dart';
import 'package:work_nexus/features/mini_apps/domain/entities/cookie_source.dart';
import 'package:work_nexus/features/mini_apps/domain/repositories/browser_cookie_repository.dart';
import 'package:work_nexus/features/mini_apps/domain/repositories/cookie_import_repository.dart';
import 'package:work_nexus/features/mini_apps/domain/repositories/web_view_cookie_repository.dart';
import 'package:work_nexus/features/mini_apps/domain/usecases/check_cookie_imports.dart';
import 'package:work_nexus/features/mini_apps/domain/usecases/group_cookies_by_site.dart';
import 'package:work_nexus/features/mini_apps/domain/usecases/import_browser_cookies.dart';
import 'package:work_nexus/features/mini_apps/domain/value_objects/cookie_browser.dart';
import 'package:work_nexus/features/mini_apps/domain/value_objects/cookie_key.dart';
import 'package:work_nexus/features/mini_apps/domain/value_objects/cookie_site_of.dart';

class _Browsers extends Mock implements BrowserCookieRepository {}

class _WebView extends Mock implements WebViewCookieRepository {}

class _Imports extends Mock implements CookieImportRepository {}

final _now = DateTime.utc(2026, 11, 6);
const _source = CookieSource(
  browser: CookieBrowser.chrome,
  profileId: '/chrome/Default',
  profileName: 'Me',
);

BrowserCookie _cookie(
  String name,
  String domain, {
  bool httpOnly = false,
  DateTime? expires,
  String value = 'v',
}) => BrowserCookie(
  name: name,
  value: value,
  domain: domain,
  httpOnly: httpOnly,
  expires: expires,
);

void main() {
  setUpAll(() {
    registerFallbackValue(_source);
    registerFallbackValue(<BrowserCookie>[]);
    registerFallbackValue(<CookieImport>[]);
    registerFallbackValue(<CookieKey>[]);
  });

  group('cookieSiteOf', () {
    test('keeps the registrable part of a host', () {
      expect(cookieSiteOf('.mail.google.com'), 'google.com');
      expect(cookieSiteOf('github.com'), 'github.com');
      expect(cookieSiteOf('shop.example.com.vn'), 'example.com.vn');
      expect(cookieSiteOf('a.b.co.uk'), 'b.co.uk');
    });

    test('an address or a single label is its own site', () {
      expect(cookieSiteOf('192.168.1.20'), '192.168.1.20');
      expect(cookieSiteOf('localhost'), 'localhost');
    });
  });

  group('GroupCookiesBySite', () {
    test('groups by site, mini apps first, drops expired and empty', () {
      final sites = const GroupCookiesBySite()(
        [
          _cookie('a', '.zeta.com'),
          _cookie('b', 'app.zeta.com'),
          _cookie('c', 'alpha.com'),
          _cookie('d', 'work.io'),
          _cookie('old', 'beta.com', expires: DateTime.utc(2020)),
          _cookie('blank', 'gamma.com', value: ''),
        ],
        miniAppUrls: ['https://work.io/board'],
        now: _now,
      );
      expect(
        [for (final s in sites) s.site],
        ['work.io', 'alpha.com', 'zeta.com'],
      );
      expect(sites.first.usedByMiniApp, isTrue);
      expect(sites.last.cookies, hasLength(2));
    });
  });

  group('ImportBrowserCookies', () {
    late _Browsers browsers;
    late _WebView webView;
    late _Imports imports;
    late ImportBrowserCookies importCookies;

    setUp(() {
      browsers = _Browsers();
      webView = _WebView();
      imports = _Imports();
      importCookies = ImportBrowserCookies(
        browsers,
        webView,
        imports,
        now: () => _now,
      );
      when(() => webView.write(any())).thenAnswer((_) async => const Ok(null));
      when(() => imports.save(any())).thenAnswer(
        (i) async => Ok(i.positionalArguments.first as List<CookieImport>),
      );
    });

    test(
      'writes only the picked sites and remembers their sign-in keys',
      () async {
        when(() => browsers.read(_source)).thenAnswer(
          (_) async => Ok([
            _cookie('session', '.work.io', httpOnly: true),
            _cookie('_ga', '.work.io'),
            _cookie('other', 'elsewhere.com', httpOnly: true),
            _cookie('gone', 'work.io', expires: DateTime.utc(2021)),
          ]),
        );

        final result = await importCookies(_source, {'work.io'});

        expect(result.valueOrNull, 2);
        final written =
            verify(() => webView.write(captureAny())).captured.single
                as List<BrowserCookie>;
        expect([for (final c in written) c.name], ['session', '_ga']);
        final saved =
            verify(() => imports.save(captureAny())).captured.single
                as List<CookieImport>;
        expect(saved.single.site, 'work.io');
        expect(saved.single.source, _source);
        expect(saved.single.importedAt, _now);
        // Only the HttpOnly cookie is watched: analytics come and go.
        expect(saved.single.keys, [
          const CookieKey(host: 'work.io', path: '/', name: 'session'),
        ]);
      },
    );

    test('fails without touching the web view when nothing matches', () async {
      when(
        () => browsers.read(_source),
      ).thenAnswer((_) async => Ok([_cookie('x', 'other.com')]));

      final result = await importCookies(_source, {'work.io'});

      expect(result.failureOrNull, isA<NotFoundFailure>());
      verifyNever(() => webView.write(any()));
    });

    test('passes on a refused read', () async {
      when(
        () => browsers.read(_source),
      ).thenAnswer((_) async => const Err(AuthFailure('denied')));

      final result = await importCookies(_source, {'work.io'});

      expect(result.failureOrNull, isA<AuthFailure>());
    });
  });

  group('CheckCookieImports', () {
    test('counts the sign-in cookies the web view no longer has', () async {
      final imports = _Imports();
      final webView = _WebView();
      const kept = CookieKey(host: 'work.io', path: '/', name: 'session');
      const lost = CookieKey(host: 'work.io', path: '/', name: 'refresh');
      final record = CookieImport(
        site: 'work.io',
        source: _source,
        importedAt: _now,
        keys: const [kept, lost],
      );
      when(imports.all).thenAnswer((_) async => Ok([record]));
      when(() => webView.present(any())).thenAnswer((_) async => Ok({kept}));

      final states = (await CheckCookieImports(imports, webView)()).valueOrNull;

      expect(states?.single.missing, 1);
      expect(states?.single.expired, isTrue);
    });
  });
}
