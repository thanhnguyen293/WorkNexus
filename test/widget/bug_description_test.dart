import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/task_detail/presentation/widgets/bug_description.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

void main() {
  testWidgets('section cards draw their own rounded border, unclipped', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(
          variant: AppThemeVariant.dark,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: BugDescription(
              body:
                  '<p>【步骤】</p><p>Open the app</p>'
                  '<p>Actual result:</p><p>Crash</p>',
              html: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // A rounded clip over a square border is what cut the corners off.
    expect(
      find.descendant(
        of: find.byType(BugDescription),
        matching: find.byType(ClipRRect),
      ),
      findsNothing,
    );
    final cards = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(BugDescription),
            matching: find.byType(Container),
          ),
        )
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.border != null)
        .toList();
    expect(cards, hasLength(2), reason: 'steps and actual-result cards');
    for (final d in cards) {
      expect(d.borderRadius, isNotNull);
      expect(d.border!.isUniform, isTrue);
    }
  });
}
