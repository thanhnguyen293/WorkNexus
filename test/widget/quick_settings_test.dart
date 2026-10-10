import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/translation/presentation/translation_api_providers.dart';
import 'package:work_nexus/app/shell/title_bar.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/debug/talker_debug_overlay.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/settings/app_settings.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/theme/fonts.dart';
import 'package:work_nexus/core/widgets/quick_settings_font_control.dart';
import 'package:work_nexus/core/widgets/quick_settings_side_panel.dart';
import 'package:work_nexus/features/connections/presentation/settings_page.dart';
import 'package:work_nexus/features/translation/presentation/translation_providers.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

import '../support/di_test_harness.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestLocator();
  });

  tearDown(() async {
    await resetTestLocator(db);
  });

  Future<ProviderContainer> pumpTitleBar(
    WidgetTester tester, {
    Size physicalSize = const Size(1200, 900),
  }) async {
    tester.view.physicalSize = physicalSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _SettingsHarness(child: _ShellHarness()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  // "System" is also a theme option; this is the font menu's entry.
  final systemFontInMenu = find.descendant(
    of: find.byType(PopupMenuItem<String>),
    matching: find.text('System'),
  );

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
      'Theme',
      'Surface',
      'Density',
      'Detail layout',
      'Company tint',
      'Font',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('detail layout toggle updates settings and keeps panel open', (
    tester,
  ) async {
    final container = await pumpTitleBar(tester);
    await openQuickSettings(tester);

    expect(
      container.read(appSettingsProvider).detailLayout,
      DetailLayout.twoPane,
    );

    await tester.tap(find.text('Document'));
    await tester.pumpAndSettle();

    expect(
      container.read(appSettingsProvider).detailLayout,
      DetailLayout.document,
    );
    expect(
      find.byKey(const ValueKey<String>('quick-settings-panel')),
      findsOneWidget,
    );
  });

  testWidgets('quick settings slides over the right edge', (tester) async {
    await pumpTitleBar(tester);

    final trigger = find.byKey(
      const ValueKey<String>('quick-settings-trigger'),
    );
    final iconFinder = find.byIcon(LucideIcons.settings300);
    expect(iconFinder, findsOneWidget);
    expect(tester.widget<Icon>(iconFinder).size, 16);
    expect(tester.getSize(trigger), const Size(28, 28));

    await openQuickSettings(tester);

    final panel = tester.getRect(
      find.byKey(const ValueKey<String>('quick-settings-side-panel')),
    );
    expect(panel.right, 1200);
    expect(panel.width, lessThanOrEqualTo(400));
    expect(panel.bottom, 900);
    // Label left, its control right on the same row.
    expect(
      (tester.getCenter(find.text('Language')).dy -
              tester.getCenter(find.text('English')).dy)
          .abs(),
      lessThan(2),
    );
  });

  testWidgets('triple tapping quick settings opens Talker debug panel', (
    tester,
  ) async {
    await pumpTitleBar(tester);

    final trigger = find.byKey(
      const ValueKey<String>('quick-settings-trigger'),
    );
    await tester.tap(trigger);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(trigger);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(trigger);
    await tester.pumpAndSettle();

    expect(find.text('WorkNexus Debug'), findsOneWidget);
    final panel = find.byKey(const ValueKey<String>('talker-debug-panel'));
    expect(panel, findsOneWidget);
    expect(tester.getSize(panel).width, lessThan(900));
  });

  testWidgets('segmented options have readable horizontal gaps', (
    tester,
  ) async {
    await pumpTitleBar(tester);
    await openQuickSettings(tester);

    double gapBetween(String left, String right) {
      final leftRect = tester.getRect(find.text(left));
      final rightRect = tester.getRect(find.text(right));
      return rightRect.left - leftRect.right;
    }

    expect(gapBetween('Comfortable', 'Compact'), greaterThanOrEqualTo(8));
    expect(gapBetween('Light', 'Dark'), greaterThanOrEqualTo(8));
  });

  testWidgets('system font selection stays in the open panel', (tester) async {
    final container = await pumpTitleBar(tester);
    await openQuickSettings(tester);

    expect(kFontChoices.first, kSystemFont);
    await tester.tap(find.text('Be Vietnam Pro'));
    await tester.pumpAndSettle();
    expect(systemFontInMenu, findsOneWidget);

    await tester.tap(systemFontInMenu);
    await tester.pumpAndSettle();

    expect(container.read(appSettingsProvider).fontFamily, kSystemFont);
    expect(
      find.descendant(
        of: find.byType(QuickSettingsFontControl),
        matching: find.text('System'),
      ),
      findsOneWidget,
    );
    expect(find.text(kSystemFont), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('quick-settings-panel')),
      findsOneWidget,
    );
  });

  testWidgets('nested tooltip inside the panel lays out without errors', (
    tester,
  ) async {
    await pumpTitleBar(tester);
    await openQuickSettings(tester);

    // Hovering the font picker shows its Tooltip — an OverlayPortal nested in
    // the panel's overlay child, which needs the panel's paint transform
    // during layout.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Be Vietnam Pro')));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(tester.takeException(), isNull);
    expect(find.byType(Tooltip), findsWidgets);
  });

  testWidgets('System menu item previews the platform font', (tester) async {
    await pumpTitleBar(tester);
    await openQuickSettings(tester);

    await tester.tap(find.text('Be Vietnam Pro'));
    await tester.pumpAndSettle();

    final systemFinder = systemFontInMenu;
    final systemText = tester.widget<Text>(systemFinder);
    final systemContext = tester.element(systemFinder);
    final theme = Theme.of(systemContext);
    final platformTypography = Typography.material2021(
      platform: defaultTargetPlatform,
      colorScheme: theme.colorScheme,
    );
    final expectedFamily =
        (theme.brightness == Brightness.dark
                ? platformTypography.white
                : platformTypography.black)
            .bodyMedium
            ?.fontFamily;

    expect(systemText.style?.fontFamily, expectedFamily);
  });

  testWidgets('language changes immediately and keeps the panel open', (
    tester,
  ) async {
    final container = await pumpTitleBar(tester);
    await openQuickSettings(tester);

    // Language is a dropdown: the menu opens from the current choice.
    expect(find.text('Vietnamese'), findsNothing);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vietnamese'));
    await tester.pumpAndSettle();

    expect(container.read(appSettingsProvider).locale.languageCode, 'vi');
    expect(find.text('Cài đặt nhanh'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('quick-settings-panel')),
      findsOneWidget,
    );
  });

  testWidgets('appearance changes immediately and keeps the panel open', (
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

  testWidgets('theme defaults to light and can follow the system', (
    tester,
  ) async {
    final container = await pumpTitleBar(tester);
    await openQuickSettings(tester);
    AppSettings settings() => container.read(appSettingsProvider);

    expect(settings().variant, AppThemeVariant.light);
    expect(settings().themeFollowsSystem, isFalse);

    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();
    expect(settings().themeFollowsSystem, isTrue);

    // Picking a theme by hand stops following the OS.
    await tester.tap(find.text('Midnight'));
    await tester.pumpAndSettle();
    expect(settings().themeFollowsSystem, isFalse);
    expect(settings().variant, AppThemeVariant.midnight);
  });

  testWidgets('a custom primary color comes from the picker', (tester) async {
    final container = await pumpTitleBar(tester);
    await openQuickSettings(tester);

    await tester.tap(find.byTooltip('Custom color'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '#123abc');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(container.read(appSettingsProvider).accentColorValue, 0xFF123ABC);
  });

  testWidgets('a click outside closes the quick settings panel', (
    tester,
  ) async {
    await pumpTitleBar(tester);
    await openQuickSettings(tester);

    await tester.tapAt(const Offset(20, 300));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('quick-settings-panel')),
      findsNothing,
    );
  });

  testWidgets('the close button closes the quick settings panel', (
    tester,
  ) async {
    await pumpTitleBar(tester);
    await openQuickSettings(tester);

    await tester.tap(find.byIcon(LucideIcons.x300));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('quick-settings-panel')),
      findsNothing,
    );
  });

  testWidgets('second trigger click closes the quick settings panel', (
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

  testWidgets('Escape closes the quick settings panel', (tester) async {
    await pumpTitleBar(tester);
    await openQuickSettings(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('quick-settings-panel')),
      findsNothing,
    );
  });

  testWidgets('the title bar and panel fit the smallest window', (
    tester,
  ) async {
    await pumpTitleBar(tester, physicalSize: const Size(680, 480));
    await openQuickSettings(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('quick settings panel stays within a short viewport', (
    tester,
  ) async {
    await pumpTitleBar(tester, physicalSize: const Size(1200, 200));
    await openQuickSettings(tester);

    final panel = find.byKey(
      const ValueKey<String>('quick-settings-side-panel'),
    );

    expect(tester.getRect(panel).bottom, lessThanOrEqualTo(200));
    expect(tester.takeException(), isNull);
  });

  Future<void> pumpPanelWithChat(WidgetTester tester, MainView view) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(mainViewProvider.notifier).state = view;
    container.read(quickSettingsOpenProvider.notifier).state = true;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _SettingsHarness(
          child: QuickSettingsSidePanel(chatSections: [Text('chat-section')]),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('chat settings live on their own tab', (tester) async {
    await pumpPanelWithChat(tester, MainView.board);

    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('chat-section'), findsNothing);

    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();

    expect(find.text('chat-section'), findsOneWidget);
    expect(find.text('Theme'), findsNothing);

    await tester.tap(find.text('General'));
    await tester.pumpAndSettle();
    expect(find.text('Theme'), findsOneWidget);
  });

  testWidgets('opened from the chat view, the panel starts on the Chat tab', (
    tester,
  ) async {
    await pumpPanelWithChat(tester, MainView.chat);

    expect(find.text('chat-section'), findsOneWidget);
    expect(find.text('Theme'), findsNothing);
  });

  testWidgets('Integrations page no longer contains appearance settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Stub the model list: the real provider shells out to the `opencode` CLI,
    // which a widget test must never do (and would never settle).
    final container = ProviderContainer(
      overrides: [
        openCodeModelsProvider.overrideWith((ref) async => const <String>[]),
        translationApiConfigProvider.overrideWith(
          (ref) async => const Ok(null),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _SettingsHarness(child: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Connected accounts'), findsOneWidget);
    expect(find.text('APPEARANCE'), findsNothing);
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
      home: Scaffold(
        body: Stack(children: [child, const TalkerDebugOverlay()]),
      ),
    );
  }
}

/// The title bar above the main area, with the Quick Settings panel over
/// it — as the app shell lays them out.
class _ShellHarness extends StatelessWidget {
  const _ShellHarness();

  @override
  Widget build(BuildContext context) => const Column(
    children: [
      TitleBar(),
      Expanded(
        child: Stack(children: [SizedBox.expand(), QuickSettingsSidePanel()]),
      ),
    ],
  );
}
