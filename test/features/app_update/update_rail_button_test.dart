import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/app_update/presentation/widgets/update_rail_button.dart';

import 'support/update_test_app.dart';

void main() {
  late MockUpdateRepository repository;

  setUp(() => repository = mockUpdateRepository());

  testWidgets('stays out of the rail while there is nothing to install', (
    tester,
  ) async {
    when(
      () => repository.fetchLatestStableRelease(),
    ).thenAnswer((_) async => const Ok(null));
    await tester.pumpWidget(
      updateTestApp(
        repository: repository,
        home: const Scaffold(body: UpdateRailButton()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Tooltip), findsNothing);
  });

  testWidgets('offers a restart once the release is downloaded', (
    tester,
  ) async {
    when(
      () => repository.fetchLatestStableRelease(),
    ).thenAnswer((_) async => const Ok(installableRelease));
    await tester.pumpWidget(
      updateTestApp(
        repository: repository,
        home: const Scaffold(body: UpdateRailButton()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Restart to update to v1.1.0'), findsOneWidget);
    verifyNever(() => repository.install(any()));

    await tester.tap(find.byType(UpdateRailButton));
    await tester.pumpAndSettle();

    verify(() => repository.install('/staged')).called(1);
  });
}
