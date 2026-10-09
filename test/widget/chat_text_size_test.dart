import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/settings/app_settings.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_text_scale.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_text_size_setting.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

import '../support/di_test_harness.dart';

void main() {
  late AppDatabase db;

  setUp(() async => db = await setUpTestLocator());
  tearDown(() async => resetTestLocator(db));

  testWidgets('picking a size scales the chat text, not the rest', (
    tester,
  ) async {
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
            body: SizedBox(
              width: 360,
              child: Column(
                children: [
                  ChatTextSizeSetting(),
                  ChatTextScale(child: Text('message')),
                  Text('chat list'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    double scaleOf(String text) =>
        MediaQuery.textScalerOf(tester.element(find.text(text))).scale(10);

    expect(scaleOf('message'), 10);
    await tester.tap(find.text('Larger'));
    await tester.pump();

    expect(container.read(appSettingsProvider).chatTextScale, 1.3);
    expect(scaleOf('message'), closeTo(13, 0.001));
    expect(scaleOf('chat list'), 10);
    expect(tester.takeException(), isNull);
  });
}
