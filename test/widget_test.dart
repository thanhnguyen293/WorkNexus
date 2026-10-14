import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/app/app.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/data/local/database_seeder.dart';
import 'package:work_nexus/features/board/presentation/board_providers.dart';

import 'support/di_test_harness.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestLocator();
  });

  tearDown(() => resetTestLocator(db));

  testWidgets('App boots into Chat; the board opens on its welcome screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: WorkNexusApp()));
    // Advance past the initial loading skeleton timer.
    await tester.pump(const Duration(milliseconds: 600));

    // Title bar shows the app name; the launch view is Chat, not a board.
    expect(find.text('Task Board'), findsOneWidget);
    expect(find.text('Select a conversation'), findsOneWidget);
    expect(find.text('In Progress'), findsNothing);

    // Opening the board shows the welcome screen — no source is selected yet.
    _container(tester).read(appNavProvider.notifier).show(MainView.board);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Welcome to WorkNexus'), findsOneWidget);
    // No board is opened by default: no columns and no seeded tickets render.
    expect(find.text('In Progress'), findsNothing);
    expect(find.text('Upgrade to React 19'), findsNothing);

    await disposeTree(tester);
  });

  testWidgets(
    'First launch without workspaces or providers opens Integrations',
    (tester) async {
      await purgeSeededDemoData(db);
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const ProviderScope(child: WorkNexusApp()));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Connected accounts'), findsOneWidget);
      expect(find.text('Welcome to WorkNexus'), findsNothing);

      await disposeTree(tester);
    },
  );

  testWidgets(
    'Sidebar nests workspace → ZenTao with Bugs/Tasks groups, no catch-alls',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // The tree lists the account's products and projects once ZenTao
            // has answered; there is no server here, so it answers at once.
            zentaoProductsProvider.overrideWith(
              (ref, accountId) => Stream.value(const <ProviderProduct>[]),
            ),
            zentaoProjectsProvider.overrideWith(
              (ref, accountId) => Stream.value(const <ProviderProject>[]),
            ),
          ],
          child: const WorkNexusApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      // The sources tree lives in the board view; the app launches in Chat.
      _container(tester).read(appNavProvider.notifier).show(MainView.board);
      await tester.pump(const Duration(milliseconds: 600));
      // The board's first frame starts the sources' streams; this one shows them.
      await tester.pump();
      // The ZenTao node renders beneath its workspace in the tree.
      expect(find.text('ZenTao'), findsOneWidget);
      // Its sources hang under the "Bugs" (products) and "Tasks" (executions)
      // group headers.
      expect(find.text('Bugs'), findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);
      // The old top-level entry points / "Products" wrapper are still gone, and
      // nothing is pinned by default so there is no "Pinned" area.
      expect(find.text('Products'), findsNothing);
      expect(find.text('Pinned'), findsNothing);
      // The workspace node is structural — no "all workspaces" catch-all.
      expect(find.text('All workspaces'), findsNothing);

      await disposeTree(tester);
    },
  );
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(WorkNexusApp)));
