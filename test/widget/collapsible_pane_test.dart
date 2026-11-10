import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/app/shell/collapsible_pane.dart';
import 'package:work_nexus/core/navigation/collapsed_panes.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

void main() {
  testWidgets('folds to a strip on collapse; the strip opens it again', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
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
                CollapsiblePane(
                  paneKey: 'a|docs',
                  icon: Icons.book,
                  label: 'Docs',
                  child: SizedBox(width: 240, child: Text('tree')),
                ),
                Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      ),
    );

    // Open by default: no hover or timer folds it.
    expect(find.text('tree'), findsOneWidget);
    expect(find.text('Docs'), findsNothing);

    container.read(collapsedPanesProvider.notifier).collapse('a|docs');
    await tester.pump();
    expect(find.text('tree'), findsNothing);
    expect(find.text('tree', skipOffstage: false), findsOneWidget);
    expect(tester.getSize(find.byType(CollapsiblePane)).width, 76);

    await tester.tap(find.text('Docs'));
    await tester.pumpAndSettle();
    expect(find.text('tree'), findsOneWidget);
    expect(container.read(collapsedPanesProvider), isEmpty);
  });
}
