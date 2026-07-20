import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/app/app.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/data/local/database_seeder.dart';

import 'support/di_test_harness.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestLocator();
  });

  tearDown(() async {
    await resetTestLocator(db);
  });

  testWidgets('App boots into the empty home/welcome screen (no board)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: WorkNexusApp()));
    // Advance past the initial loading skeleton timer.
    await tester.pump(const Duration(milliseconds: 600));

    // Title bar shows the app name.
    expect(find.text('Unified Task Board'), findsOneWidget);
    // The launch state is the welcome screen — no source is selected yet.
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

      await tester.pumpWidget(const ProviderScope(child: WorkNexusApp()));
      await tester.pump(const Duration(milliseconds: 600));

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
