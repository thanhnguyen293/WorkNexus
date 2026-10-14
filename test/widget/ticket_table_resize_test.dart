import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/settings/app_settings.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/widgets/resize_handle.dart';
import 'package:work_nexus/features/board/presentation/widgets/ticket_table.dart';
import 'package:work_nexus/features/board/presentation/widgets/ticket_table_column.dart';

void main() {
  late List<AppSettings> saved;

  Future<void> pumpTable(WidgetTester tester, {AppSettings? initial}) async {
    saved = [];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialAppSettingsProvider.overrideWithValue(
            initial ?? const AppSettings(),
          ),
          settingsPersistProvider.overrideWithValue(saved.add),
        ],
        child: MaterialApp(
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          home: Scaffold(
            body: TicketTable(
              id: 't',
              rows: const [],
              columns: [
                TicketTableColumn(
                  id: 'id',
                  label: 'Id',
                  width: 80,
                  cell: (t) => Text(t.externalKey),
                ),
                TicketTableColumn(
                  id: 'title',
                  label: 'Title',
                  cell: (t) => Text(t.title),
                ),
                TicketTableColumn(
                  id: 'status',
                  label: 'Status',
                  width: 140,
                  cell: (t) => Text(t.providerStatus),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double idWidth(WidgetTester tester) => tester
      .getSize(
        find
            .ancestor(
              of: find.text('ID'),
              matching: find.byWidgetPredicate(
                (w) => w is SizedBox && (w.width ?? 0) >= 48,
              ),
            )
            .first,
      )
      .width;

  testWidgets('every line between two columns gets a resize handle', (
    tester,
  ) async {
    await pumpTable(tester);

    expect(find.byType(ResizeHandle), findsNWidgets(2));
  });

  // Regression: a column right of the title grew leftwards — the title took
  // up the slack — so the line under the pointer stayed put.
  for (final (line, side) in [(0, 'left'), (1, 'right')]) {
    testWidgets('a dragged line $side of the title follows the pointer', (
      tester,
    ) async {
      await pumpTable(tester);
      final handle = find.byType(ResizeHandle).at(line);
      final before = tester.getTopRight(handle).dx;

      await tester.drag(
        handle,
        const Offset(60, 0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      final moved = tester.getTopRight(handle).dx - before;
      expect(moved, greaterThan(0));
      // Left of the title the column before the line grows; right of it the
      // column after the line shrinks.
      expect(
        saved.single.tableColumnWidths,
        line == 0 ? {'t.id': 80 + moved} : {'t.status': 140 - moved},
      );
    });
  }

  testWidgets('dragging a header edge resizes the column and saves it once', (
    tester,
  ) async {
    await pumpTable(tester);

    await tester.drag(
      find.byType(ResizeHandle).first,
      const Offset(60, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();

    final width = saved.single.tableColumnWidths['t.id'];
    expect(width, greaterThan(80));
    expect(idWidth(tester), width);
  });

  testWidgets(
    'a saved width is used, and a double-click restores the default',
    (tester) async {
      await pumpTable(
        tester,
        initial: const AppSettings(tableColumnWidths: {'t.id': 150}),
      );
      expect(idWidth(tester), 150);

      final handle = find.byType(ResizeHandle).first;
      await tester.tap(handle, kind: PointerDeviceKind.mouse);
      await tester.pump(kDoubleTapMinTime);
      await tester.tap(handle, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();

      expect(saved.last.tableColumnWidths, isEmpty);
      expect(idWidth(tester), 80);
    },
  );
}
