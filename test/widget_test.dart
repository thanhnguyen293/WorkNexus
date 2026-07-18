import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/app/app.dart';
import 'package:work_nexus/core/database/database.dart';

import 'support/di_test_harness.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestLocator();
  });

  tearDown(() async {
    await resetTestLocator(db);
  });

  testWidgets('App boots into the board shell with seeded data', (
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
    // Board columns render (localized status labels).
    expect(find.text('In Progress'), findsWidgets);
    // A seeded ticket is visible.
    expect(find.text('Upgrade to React 19'), findsWidgets);

    await disposeTree(tester);
  });

  testWidgets(
    'Sidebar nests workspace → ZenTao and drops Bugs/Tasks/All-workspaces',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const ProviderScope(child: WorkNexusApp()));
      await tester.pump(const Duration(milliseconds: 600));

      // The ZenTao node renders beneath its workspace in the tree.
      expect(find.text('ZenTao'), findsOneWidget);
      // The old Bugs/Tasks entry points and "Products" wrapper are gone.
      expect(find.text('Bugs'), findsNothing);
      expect(find.text('Tasks'), findsNothing);
      expect(find.text('Products'), findsNothing);
      // The workspace node is structural — no "all workspaces" catch-all.
      expect(find.text('All workspaces'), findsNothing);

      await disposeTree(tester);
    },
  );
}
