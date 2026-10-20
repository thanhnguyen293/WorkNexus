import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/shared/board/presentation/widgets/filter_option_group.dart';
import 'package:work_nexus/shared/board/presentation/widgets/filter_people_block.dart';

/// The people groups' box says they combine with OR, and puts an OR between
/// each of its dropdowns. Laid out with semantics on, as the desktop builds
/// it: a header row once left the box without a width there.
void main() {
  List<FilterChipOption> options(int n) => [
    for (var i = 0; i < n; i++)
      FilterChipOption(label: 'user-$i', active: false, onTap: () {}),
  ];

  Future<void> pumpBlock(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      theme: buildAppTheme(
        variant: AppThemeVariant.dark,
        surface: SurfaceStyle.outline,
        density: AppDensity.comfortable,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: FilterPeopleBlock(
            groups: [
              (label: 'Assignee', options: options(5)),
              (label: 'Resolved by', options: options(5)),
              (label: 'Opened by', options: options(5)),
            ],
          ),
        ),
      ),
    ),
  );

  testWidgets('marks the groups as OR, with one between each', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpBlock(tester);

    expect(find.text('PEOPLE'), findsOneWidget);
    // The header's tag and the two between the three dropdowns.
    expect(find.text('OR'), findsNWidgets(3));
    semantics.dispose();
  });

  testWidgets('opens a dropdown inside the box', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpBlock(tester);

    await tester.tap(find.byIcon(LucideIcons.chevronDown300).first);
    await tester.pumpAndSettle();

    expect(find.text('user-3'), findsOneWidget);
    semantics.dispose();
  });
}
