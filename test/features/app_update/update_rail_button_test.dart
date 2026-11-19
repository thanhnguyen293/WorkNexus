import 'dart:async';

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
    // Installing spins the ring until the app restarts, so it never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    verify(() => repository.install('/staged')).called(1);
  });

  testWidgets('shows how far the download is with a ring', (tester) async {
    final done = Completer<Result<String>>();
    when(
      () => repository.fetchLatestStableRelease(),
    ).thenAnswer((_) async => const Ok(installableRelease));
    when(
      () => repository.download(any(), onProgress: any(named: 'onProgress')),
    ).thenAnswer((call) {
      final onProgress =
          call.namedArguments[#onProgress] as void Function(double);
      onProgress(0.42);
      return done.future;
    });
    await tester.pumpWidget(
      updateTestApp(
        repository: repository,
        home: const Scaffold(body: UpdateRailButton()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Downloading the update… 42%'), findsOneWidget);
    final ring = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(ring.value, closeTo(0.42, 0.001));

    done.complete(const Ok('/staged'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Restart to update to v1.1.0'), findsOneWidget);
  });
}
