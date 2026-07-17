import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/app/shell/title_bar.dart';
import 'package:work_nexus/core/settings/app_settings.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

void main() {
  Future<ProviderContainer> pumpTitleBar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _SettingsHarness(child: TitleBar()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> openQuickSettings(WidgetTester tester) async {
    await tester.tap(
      find.byKey(const ValueKey<String>('quick-settings-trigger')),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('title bar opens all quick settings from one trigger', (
    tester,
  ) async {
    await pumpTitleBar(tester);

    expect(find.text('EN'), findsNothing);
    expect(find.text('VI'), findsNothing);
    await openQuickSettings(tester);

    expect(
      find.byKey(const ValueKey<String>('quick-settings-panel')),
      findsOneWidget,
    );
    for (final label in <String>[
      'Quick settings',
      'Language',
      'Appearance',
      'Theme',
      'Surface',
      'Density',
      'Company tint',
      'Font',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('language changes immediately and keeps the popover open', (
    tester,
  ) async {
    final container = await pumpTitleBar(tester);
    await openQuickSettings(tester);

    await tester.tap(find.text('Vietnamese'));
    await tester.pumpAndSettle();

    expect(container.read(appSettingsProvider).locale.languageCode, 'vi');
    expect(find.text('Cài đặt nhanh'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('quick-settings-panel')),
      findsOneWidget,
    );
  });

  testWidgets('appearance changes immediately and keeps the popover open', (
    tester,
  ) async {
    final container = await pumpTitleBar(tester);
    await openQuickSettings(tester);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(container.read(appSettingsProvider).variant, AppThemeVariant.dark);
    expect(
      find.byKey(const ValueKey<String>('quick-settings-panel')),
      findsOneWidget,
    );
  });

  testWidgets('outside click closes the quick settings popover', (
    tester,
  ) async {
    await pumpTitleBar(tester);
    await openQuickSettings(tester);

    await tester.tapAt(const Offset(20, 100));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('quick-settings-panel')),
      findsNothing,
    );
  });

  testWidgets('second trigger click closes the quick settings popover', (
    tester,
  ) async {
    await pumpTitleBar(tester);
    await openQuickSettings(tester);

    final trigger = find.byKey(
      const ValueKey<String>('quick-settings-trigger'),
    );
    await tester.tapAt(tester.getCenter(trigger));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('quick-settings-panel')),
      findsNothing,
    );
  });

  testWidgets('Escape closes the quick settings popover', (tester) async {
    await pumpTitleBar(tester);
    await openQuickSettings(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('quick-settings-panel')),
      findsNothing,
    );
  });
}

class _SettingsHarness extends ConsumerWidget {
  const _SettingsHarness({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return MaterialApp(
      locale: settings.locale,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      theme: buildAppTheme(
        variant: settings.variant,
        surface: settings.surface,
        density: settings.density,
        fontFamily: settings.fontFamily,
      ),
      home: Scaffold(body: child),
    );
  }
}
