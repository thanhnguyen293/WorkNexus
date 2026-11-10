import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/app/shell/auto_hide_pane.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

void main() {
  testWidgets('folded to a strip; hovering opens it, leaving closes it', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: const Scaffold(
          body: Row(
            children: [
              AutoHidePane(
                icon: Icons.book,
                label: 'Docs',
                child: SizedBox(width: 240, child: Text('tree')),
              ),
              Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    // Folded: the strip takes the room, the pane is mounted but hidden.
    // As wide as the rail.
    expect(tester.getSize(find.byType(AutoHidePane)).width, 76);
    expect(find.text('Docs'), findsOneWidget);
    expect(find.text('tree'), findsNothing);
    expect(find.text('tree', skipOffstage: false), findsOneWidget);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(AutoHidePane)));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('tree'), findsOneWidget, reason: 'opening on hover');
    await tester.pumpAndSettle();
    expect(find.text('tree'), findsOneWidget, reason: 'opened');

    await mouse.moveTo(const Offset(700, 300));
    // The close delay, then the pane's motion out.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('tree'), findsNothing, reason: 'closed on leave');
    expect(find.text('tree', skipOffstage: false), findsOneWidget);
  });
}
