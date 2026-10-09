import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/app_update/presentation/widgets/update_settings_card.dart';

import 'support/update_test_app.dart';

void main() {
  late MockUpdateRepository repository;

  setUp(() => repository = mockUpdateRepository());

  testWidgets(
    'a manual check shows the update dialog once, also when the release '
    'was already found',
    (tester) async {
      const headline = 'A new version of WorkNexus is available';
      when(
        () => repository.fetchLatestStableRelease(),
      ).thenAnswer((_) async => const Ok(manualRelease));
      await tester.pumpWidget(
        updateTestApp(
          repository: repository,
          home: const Scaffold(body: UpdateSettingsCard()),
        ),
      );
      // The check that runs with the app already knows about the release.
      await tester.pumpAndSettle();
      expect(find.text(headline), findsNothing);

      await tester.tap(find.text('Check for updates'));
      await tester.pumpAndSettle();
      expect(find.text(headline), findsOneWidget);
      expect(find.text('v1.1.0'), findsOneWidget);

      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(find.text(headline), findsNothing);

      await tester.tap(find.text('Check for updates'));
      await tester.pumpAndSettle();
      expect(find.text(headline), findsOneWidget);
    },
  );

  testWidgets('manual update check reports when the app is up to date', (
    tester,
  ) async {
    when(
      () => repository.fetchLatestStableRelease(),
    ).thenAnswer((_) async => const Ok(null));
    await tester.pumpWidget(
      updateTestApp(
        repository: repository,
        home: const Scaffold(body: UpdateSettingsCard()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();

    expect(find.text('Version 1.4.1'), findsOneWidget);
    expect(
      find.text("You're using the latest stable version."),
      findsOneWidget,
    );
  });
}
