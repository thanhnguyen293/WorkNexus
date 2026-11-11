import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/widgets/app_icon_button.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/shared/board/presentation/widgets/board_refresh_button.dart';

/// The board Refresh answers ⌘R (macOS) / Ctrl+R and names the key in its
/// tooltip; a board kept off screen leaves the key alone.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required VoidCallback onPressed,
    bool loading = false,
    bool onScreen = true,
  }) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      theme: buildAppTheme(
        variant: AppThemeVariant.light,
        surface: SurfaceStyle.outline,
        density: AppDensity.comfortable,
      ),
      home: Scaffold(
        body: TickerMode(
          enabled: onScreen,
          child: BoardRefreshButton(loading: loading, onPressed: onPressed),
        ),
      ),
    ),
  );

  Future<void> pressShortcut(WidgetTester tester, {required bool mac}) async {
    final modifier = mac
        ? LogicalKeyboardKey.metaLeft
        : LogicalKeyboardKey.controlLeft;
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.sendKeyUpEvent(modifier);
  }

  testWidgets('⌘R refreshes on macOS, and the tooltip says so', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    var taps = 0;
    await pump(tester, onPressed: () => taps++);
    expect(
      tester.widget<AppIconButton>(find.byType(AppIconButton)).tooltip,
      'Refresh (⌘R)',
    );

    await pressShortcut(tester, mac: true);
    expect(taps, 1);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Ctrl+R refreshes elsewhere', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    var taps = 0;
    await pump(tester, onPressed: () => taps++);
    expect(
      tester.widget<AppIconButton>(find.byType(AppIconButton)).tooltip,
      'Refresh (Ctrl+R)',
    );

    await pressShortcut(tester, mac: false);
    expect(taps, 1);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('no refresh while loading or off screen', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    var taps = 0;
    await pump(tester, onPressed: () => taps++, loading: true);
    await pressShortcut(tester, mac: false);
    expect(taps, 0);

    await pump(tester, onPressed: () => taps++, onScreen: false);
    await pressShortcut(tester, mac: false);
    expect(taps, 0);
    debugDefaultTargetPlatformOverride = null;
  });
}
