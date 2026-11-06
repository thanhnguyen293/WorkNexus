import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/mini_apps/domain/entities/browser_cookie.dart';
import 'package:work_nexus/features/mini_apps/domain/entities/cookie_site.dart';
import 'package:work_nexus/features/mini_apps/domain/entities/cookie_source.dart';
import 'package:work_nexus/features/mini_apps/domain/value_objects/cookie_browser.dart';
import 'package:work_nexus/features/mini_apps/presentation/providers/cookie_import_controller.dart';
import 'package:work_nexus/features/mini_apps/presentation/widgets/cookie_import_dialog.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

const _chrome = CookieSource(
  browser: CookieBrowser.chrome,
  profileId: '/chrome/Default',
  profileName: 'Me',
);
const _firefox = CookieSource(
  browser: CookieBrowser.firefox,
  profileId: '/firefox/p',
  profileName: 'main',
);

CookieSite _site(String site, {bool app = false}) => CookieSite(
  site: site,
  usedByMiniApp: app,
  cookies: [BrowserCookie(name: 'sid', value: 'v', domain: site)],
);

Future<void> _pump(WidgetTester tester, Widget dialog) => tester.pumpWidget(
  ProviderScope(
    overrides: [
      cookieSourcesProvider.overrideWith((ref) async => [_chrome, _firefox]),
      cookieSitesProvider.overrideWith(
        (ref, source) async => [
          _site('alpha.com', app: true),
          _site('mac-mini-2.local', app: true),
          _site('zeta.com'),
        ],
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      theme: buildAppTheme(
        variant: AppThemeVariant.light,
        surface: SurfaceStyle.outline,
        density: AppDensity.comfortable,
      ),
      home: Scaffold(body: dialog),
    ),
  ),
);

bool _checked(WidgetTester tester, String site) => tester
    .widget<Checkbox>(
      find.descendant(
        of: find.ancestor(of: find.text(site), matching: find.byType(Row)),
        matching: find.byType(Checkbox),
      ),
    )
    .value!;

void main() {
  testWidgets('from settings, every mini app site is picked', (tester) async {
    await _pump(tester, const CookieImportDialog());
    await tester.pumpAndSettle();

    expect(find.text('Chrome · Me'), findsOneWidget);
    expect(_checked(tester, 'alpha.com'), isTrue);
    expect(_checked(tester, 'mac-mini-2.local'), isTrue);
    expect(_checked(tester, 'zeta.com'), isFalse);
  });

  testWidgets('from a mini app, its site alone is picked, first, from its '
      'last browser', (tester) async {
    await _pump(
      tester,
      const CookieImportDialog(site: 'mac-mini-2.local', source: _firefox),
    );
    await tester.pumpAndSettle();

    expect(find.text('Firefox · main'), findsOneWidget);
    expect(_checked(tester, 'mac-mini-2.local'), isTrue);
    expect(_checked(tester, 'alpha.com'), isFalse);
    expect(
      tester.getTopLeft(find.text('mac-mini-2.local')).dy,
      lessThan(tester.getTopLeft(find.text('alpha.com')).dy),
    );
    expect(find.text('Import 1 site'), findsOneWidget);
  });
}
