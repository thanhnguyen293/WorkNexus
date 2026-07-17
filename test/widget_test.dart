import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/app/app.dart';

void main() {
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
  });

  testWidgets('ZenTao bug board is opened from Sources, not the toolbar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: WorkNexusApp()));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('◆ Bugs'), findsNothing);
    expect(find.text('ZenTao'), findsOneWidget);
    expect(find.text('Bugs'), findsOneWidget);
    expect(find.text('Tasks'), findsOneWidget);

    await tester.ensureVisible(find.text('Bugs'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bugs'));
    await tester.pumpAndSettle();

    expect(find.text('Resolved / Verify'), findsOneWidget);
    expect(find.text('Postponed'), findsOneWidget);
    expect(find.text('Non-Fix'), findsOneWidget);
  });

  testWidgets('ZenTao task board is opened from Sources', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: WorkNexusApp()));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Tasks'), findsOneWidget);

    await tester.ensureVisible(find.text('Tasks'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();

    expect(find.text('Not Started'), findsOneWidget);
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Done / Verify'), findsOneWidget);
    expect(find.text('Canceled'), findsOneWidget);
  });
}
