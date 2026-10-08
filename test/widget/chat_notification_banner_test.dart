import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/platform/desktop_notifier.dart';
import 'package:work_nexus/core/settings/app_settings.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/presentation/providers/chat_providers.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_notification_banner.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

class _MockNotifier extends Mock implements DesktopNotifier {}

void main() {
  late _MockNotifier notifier;

  setUp(() {
    notifier = _MockNotifier();
    when(notifier.requestPermission).thenAnswer((_) async => false);
    when(notifier.openSystemSettings).thenAnswer((_) async {});
  });

  Future<void> pump(WidgetTester tester, {bool notifications = true}) async {
    await tester.pumpWidget(
      ProviderScope(
        // A fresh container per pump, so the permission is checked again.
        key: UniqueKey(),
        overrides: [
          desktopNotifierProvider.overrideWithValue(notifier),
          initialAppSettingsProvider.overrideWithValue(
            AppSettings(chatNotifications: notifications),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const Scaffold(body: ChatNotificationBanner()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('warns while the OS blocks notifications', (tester) async {
    when(notifier.permissionGranted).thenAnswer((_) async => false);
    await pump(tester);
    expect(find.text('Turn on'), findsOneWidget);

    // macOS will not ask again: the settings page opens instead.
    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();
    verify(notifier.requestPermission).called(1);
    verify(notifier.openSystemSettings).called(1);

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.text('Turn on'), findsNothing);
  });

  testWidgets('quiet when allowed, unknown, or turned off in the app', (
    tester,
  ) async {
    when(notifier.permissionGranted).thenAnswer((_) async => true);
    await pump(tester);
    expect(find.text('Turn on'), findsNothing);

    when(notifier.permissionGranted).thenAnswer((_) async => null);
    await pump(tester);
    expect(find.text('Turn on'), findsNothing);

    when(notifier.permissionGranted).thenAnswer((_) async => false);
    await pump(tester, notifications: false);
    expect(find.text('Turn on'), findsNothing);
  });
}
