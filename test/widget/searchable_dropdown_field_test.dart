import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/widgets/searchable_dropdown_field.dart';

/// [SearchableDropdownField] renders like an input when closed, opens an
/// anchored popover with a search box, filters the list as the user types, and
/// reports the chosen item through `onChanged`.
void main() {
  const users = ['Alice Nguyen', 'Bob Tran', 'Charlie Le', 'Dora Pham'];

  Future<String?> pumpField(WidgetTester tester, {String? initial}) async {
    String? picked = initial;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: StatefulBuilder(
                builder: (context, setState) => SearchableDropdownField<String>(
                  items: users,
                  value: picked,
                  hintText: 'Select a user',
                  labelOf: (u) => u,
                  onChanged: (u) => setState(() => picked = u),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return picked;
  }

  testWidgets('shows the hint when nothing is selected', (tester) async {
    await pumpField(tester);
    expect(find.text('Select a user'), findsOneWidget);
  });

  testWidgets('opens a searchable popover and filters as you type', (
    tester,
  ) async {
    await pumpField(tester);

    // Closed: options are not in the tree yet.
    expect(find.text('Bob Tran'), findsNothing);

    await tester.tap(find.text('Select a user'));
    await tester.pumpAndSettle();

    // Open: every option is listed.
    for (final u in users) {
      expect(find.text(u), findsOneWidget);
    }

    // Typing narrows the list to matches only.
    await tester.enterText(find.byType(TextField), 'tran');
    await tester.pumpAndSettle();
    expect(find.text('Bob Tran'), findsOneWidget);
    expect(find.text('Alice Nguyen'), findsNothing);
  });

  testWidgets('tapping an option selects it and closes the popover', (
    tester,
  ) async {
    await pumpField(tester);
    await tester.tap(find.text('Select a user'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Charlie Le'));
    await tester.pumpAndSettle();

    // Popover closed (search box gone), selection reflected in the field.
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Charlie Le'), findsOneWidget);
  });

  testWidgets('shows the empty label when no option matches', (tester) async {
    await pumpField(tester);
    await tester.tap(find.text('Select a user'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No matches'), findsOneWidget);
  });
}
