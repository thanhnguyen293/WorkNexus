import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/mini_apps/presentation/util/mini_app_shortcuts.dart';
import 'package:work_nexus/features/mini_apps/presentation/widgets/mini_app_toolbar.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

/// The mini app bar's Home button goes back to the app's own address.
void main() {
  testWidgets('Home is offered beside reload and calls onHome', (tester) async {
    var home = 0;
    final address = TextEditingController();
    final focus = FocusNode();
    addTearDown(address.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        home: Scaffold(
          body: MiniAppToolbar(
            address: address,
            addressFocus: focus,
            onSubmitted: (_) {},
            onOpenExternal: () {},
            onHome: () => home++,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(LucideIcons.house300));

    expect(home, 1);
    expect(find.byTooltip('Home'), findsOneWidget);
  });

  test('Alt+Home is the shortcut for it', () {
    var home = 0;
    final keys = miniAppShortcuts(
      reload: () {},
      hardReload: () {},
      back: () {},
      forward: () {},
      home: () => home++,
      focusAddress: () {},
      devTools: () {},
    );
    keys[const SingleActivator(LogicalKeyboardKey.home, alt: true)]!();
    expect(home, 1);
  });
}
