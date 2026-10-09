import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/settings/app_settings.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_notification_settings.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

import '../support/di_test_harness.dart';

void main() {
  late AppDatabase db;

  setUp(() async => db = await setUpTestLocator());
  tearDown(() async => resetTestLocator(db));

  testWidgets('notifying while viewing is off by default, and only '
      'changeable while notifications are on', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          home: const Scaffold(
            body: SizedBox(width: 360, child: ChatNotificationSettings()),
          ),
        ),
      ),
    );
    AppSettings settings() => container.read(appSettingsProvider);
    final whileViewing = find.text('Notify while viewing the chat');
    // On by default.
    expect(settings().chatNotifyWhileViewing, isTrue);

    await tester.tap(whileViewing);
    await tester.pump();
    expect(settings().chatNotifyWhileViewing, isFalse);

    await tester.tap(find.text('New message notifications'));
    await tester.pump();
    expect(settings().chatNotifications, isFalse);

    await tester.tap(whileViewing);
    await tester.pump();
    expect(settings().chatNotifyWhileViewing, isFalse, reason: 'disabled');
  });
}
