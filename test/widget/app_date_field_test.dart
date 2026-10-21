import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/widgets/app_date_field.dart';
import 'package:work_nexus/core/widgets/app_date_time_columns.dart';
import 'package:work_nexus/core/widgets/app_time_input.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

void main() {
  /// The field, holding its value like a form would; [changes] logs every
  /// report.
  Future<List<DateTime?>> pump(
    WidgetTester tester, {
    DateTime? initial,
    bool withTime = false,
    bool clearable = false,
    bool enabled = true,
  }) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final changes = <DateTime?>[];
    var value = initial;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 360,
                child: StatefulBuilder(
                  builder: (context, setState) => AppDateField(
                    value: value,
                    withTime: withTime,
                    clearable: clearable,
                    enabled: enabled,
                    onChanged: (v) => setState(() {
                      changes.add(v);
                      value = v;
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return changes;
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byType(AppDateField));
    await tester.pumpAndSettle();
  }

  bool isOpen() => find.byType(CalendarDatePicker).evaluate().isNotEmpty;

  testWidgets('a date pick closes the drop-down', (tester) async {
    final changes = await pump(tester);
    await open(tester);

    await tester.tap(find.text('Tomorrow'));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    expect(changes, [DateTime(now.year, now.month, now.day + 1)]);
    expect(isOpen(), isFalse);
  });

  testWidgets('a clearable date clears to null', (tester) async {
    final changes = await pump(
      tester,
      initial: DateTime(2026, 10, 13),
      clearable: true,
    );

    await tester.tap(find.byTooltip('Clear date'));
    await tester.pumpAndSettle();
    expect(changes, [null]);
    expect(find.text('None'), findsOneWidget);
  });

  testWidgets('with a time, a day keeps the time and the drop-down stays', (
    tester,
  ) async {
    final changes = await pump(
      tester,
      initial: DateTime(2026, 10, 13, 9, 30),
      withTime: true,
    );
    await open(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(CalendarDatePicker),
        matching: find.text('20'),
      ),
    );
    await tester.pumpAndSettle();
    expect(changes.last, DateTime(2026, 10, 20, 9, 30));
    expect(isOpen(), isTrue, reason: 'the time may follow');

    await tester.enterText(find.byType(AppTimeInput), '14:05');
    await tester.pump();
    expect(changes.last, DateTime(2026, 10, 20, 14, 5));

    // ↑ steps a minute.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(changes.last, DateTime(2026, 10, 20, 14, 6));
  });

  testWidgets('tapping hour and minute columns updates the picked time', (
    tester,
  ) async {
    final changes = await pump(
      tester,
      initial: DateTime(2026, 10, 13, 9, 30),
      withTime: true,
    );
    await open(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(AppDateTimeColumns),
        matching: find.text('11'),
      ),
    );
    await tester.pumpAndSettle();
    expect(changes.last, DateTime(2026, 10, 13, 11, 30));

    await tester.tap(
      find.descendant(
        of: find.byType(AppDateTimeColumns),
        matching: find.text('35'),
      ),
    );
    await tester.pumpAndSettle();
    expect(changes.last, DateTime(2026, 10, 13, 11, 35));
  });

  testWidgets('a half-typed time is not reported', (tester) async {
    final changes = await pump(
      tester,
      initial: DateTime(2026, 10, 13, 9, 30),
      withTime: true,
    );
    await open(tester);

    await tester.enterText(find.byType(AppTimeInput), '14:');
    await tester.enterText(find.byType(AppTimeInput), '25:00');
    await tester.pump();
    expect(changes, isEmpty);
  });

  testWidgets('a disabled field does not open', (tester) async {
    await pump(tester, initial: DateTime(2026, 10, 13, 9), enabled: false);
    await tester.tap(find.byType(AppDateField));
    await tester.pumpAndSettle();
    expect(isOpen(), isFalse);
  });

  test('times parse as HH:mm, H:mm or HHmm, within a day', () {
    expect(parseTimeOfDay('09:30'), const TimeOfDay(hour: 9, minute: 30));
    expect(parseTimeOfDay('9:05'), const TimeOfDay(hour: 9, minute: 5));
    expect(parseTimeOfDay('1405'), const TimeOfDay(hour: 14, minute: 5));
    expect(parseTimeOfDay('24:00'), isNull);
    expect(parseTimeOfDay('12:60'), isNull);
    expect(parseTimeOfDay('12:'), isNull);
    expect(formatTimeOfDay(const TimeOfDay(hour: 7, minute: 3)), '07:03');
  });
}
