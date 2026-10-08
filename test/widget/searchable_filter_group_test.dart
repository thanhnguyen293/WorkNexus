import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/board/presentation/widgets/filter_option_group.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

/// [SearchableFilterGroup] only grows a search box once a group is long enough
/// to need one, narrows the chips as you type, and never hides a chip that is
/// already selected (which would strand an active filter).
void main() {
  List<String> names(int count) => [for (var i = 0; i < count; i++) 'user-$i'];

  Future<void> pumpGroup(
    WidgetTester tester, {
    required List<String> options,
    Set<String> active = const {},
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SearchableFilterGroup(
              label: 'Assignee',
              options: [
                for (final o in options)
                  FilterChipOption(
                    label: o,
                    active: active.contains(o),
                    onTap: () {},
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a short group stays a plain chip wrap', (tester) async {
    await pumpGroup(tester, options: names(3));

    expect(find.text('ASSIGNEE'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('a long group gets a search box', (tester) async {
    await pumpGroup(tester, options: names(20));

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('user-7'), findsOneWidget);
  });

  testWidgets('typing narrows the chips to the matches', (tester) async {
    await pumpGroup(tester, options: names(20));

    await tester.enterText(find.byType(TextField), '-13');
    await tester.pumpAndSettle();

    expect(find.text('user-13'), findsOneWidget);
    expect(find.text('user-7'), findsNothing);
  });

  testWidgets('a selected option stays visible through a search', (
    tester,
  ) async {
    await pumpGroup(tester, options: names(20), active: {'user-2'});

    await tester.enterText(find.byType(TextField), '-13');
    await tester.pumpAndSettle();

    expect(find.text('user-2'), findsOneWidget);
    expect(find.text('user-13'), findsOneWidget);
  });

  testWidgets('a query matching nothing says so', (tester) async {
    await pumpGroup(tester, options: names(20));

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();

    expect(find.text('No option matches'), findsOneWidget);
  });
}
