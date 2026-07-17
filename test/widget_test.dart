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
}
