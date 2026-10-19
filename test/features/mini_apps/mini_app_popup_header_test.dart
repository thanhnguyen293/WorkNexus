import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/mini_apps/presentation/widgets/mini_app_popup.dart';
import 'package:work_nexus/features/mini_apps/presentation/widgets/mini_app_popup_header.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

Widget _app(Widget header) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildAppTheme(
    variant: AppThemeVariant.light,
    surface: SurfaceStyle.outline,
    density: AppDensity.comfortable,
  ),
  home: Scaffold(body: header),
);

/// The button whose tooltip is [tooltip], as the framework's own button, so
/// whether it is enabled can be read off it.
IconButton _button(WidgetTester tester, String tooltip) =>
    tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip(tooltip),
        matching: find.byType(IconButton),
      ),
    );

void main() {
  testWidgets('shows the title with back, forward, browser and close', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(MiniAppPopupHeader(title: 'Miro', onClose: () {})),
    );

    expect(find.text('Miro'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.byTooltip('Forward'), findsOneWidget);
    expect(find.byTooltip('Open in browser'), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);
  });

  testWidgets('a button with nothing to go to is disabled', (tester) async {
    await tester.pumpWidget(
      _app(MiniAppPopupHeader(title: '', onClose: () {})),
    );

    expect(_button(tester, 'Back').onPressed, isNull);
    expect(_button(tester, 'Forward').onPressed, isNull);
    expect(_button(tester, 'Open in browser').onPressed, isNull);
    expect(_button(tester, 'Close').onPressed, isNotNull);
  });

  testWidgets('the buttons call what they are given', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(
      _app(
        MiniAppPopupHeader(
          title: 'Miro',
          onClose: () => calls.add('close'),
          onBack: () => calls.add('back'),
          onForward: () => calls.add('forward'),
          onOpenExternal: () => calls.add('browser'),
        ),
      ),
    );

    for (final tooltip in ['Back', 'Forward', 'Open in browser', 'Close']) {
      await tester.tap(find.byTooltip(tooltip));
    }
    expect(calls, ['back', 'forward', 'browser', 'close']);
  });

  group('MiniAppPopup.isWebAddress', () {
    test('only a web address can be opened in the browser', () {
      expect(
        MiniAppPopup.isWebAddress(Uri.parse('https://miro.com/x')),
        isTrue,
      );
      expect(MiniAppPopup.isWebAddress(Uri.parse('http://a.io')), isTrue);
      expect(MiniAppPopup.isWebAddress(Uri.parse('about:blank')), isFalse);
      expect(
        MiniAppPopup.isWebAddress(Uri.parse('chrome-error://chromewebdata/')),
        isFalse,
      );
      expect(MiniAppPopup.isWebAddress(null), isFalse);
    });
  });
}
