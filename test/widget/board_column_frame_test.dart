import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/widgets/app_count_badge.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/shared/board/presentation/widgets/board_column_empty_slot.dart';
import 'package:work_nexus/shared/board/presentation/widgets/board_column_frame.dart';

void main() {
  Widget buildFrame({
    required int itemCount,
    bool highlighted = false,
    String label = 'In Progress',
  }) {
    return MaterialApp(
      locale: const Locale('en'),
      theme: buildAppTheme(
        variant: AppThemeVariant.light,
        surface: SurfaceStyle.outline,
        density: AppDensity.comfortable,
      ),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            height: 600,
            child: BoardColumnFrame(
              dot: const BoardColumnDot(Colors.blue),
              label: label,
              badge: AppCountBadge(itemCount),
              itemCount: itemCount,
              highlighted: highlighted,
              itemBuilder: (context, i) => Text('Ticket $i'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders column header with label, dot, and badge', (
    tester,
  ) async {
    await tester.pumpWidget(buildFrame(itemCount: 3));
    await tester.pumpAndSettle();

    expect(find.text('In Progress'), findsOneWidget);
    expect(find.byType(BoardColumnDot), findsOneWidget);
    expect(find.byType(AppCountBadge), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Ticket 0'), findsOneWidget);
    expect(find.text('Ticket 1'), findsOneWidget);
    expect(find.text('Ticket 2'), findsOneWidget);
    expect(find.byType(BoardColumnEmptySlot), findsNothing);
  });

  testWidgets('renders BoardColumnEmptySlot when itemCount is 0', (
    tester,
  ) async {
    await tester.pumpWidget(buildFrame(itemCount: 0));
    await tester.pumpAndSettle();

    expect(find.text('In Progress'), findsOneWidget);
    expect(find.byType(BoardColumnEmptySlot), findsOneWidget);
    expect(find.text('No items'), findsOneWidget);
  });

  testWidgets('renders highlighted state on drag hover', (tester) async {
    await tester.pumpWidget(buildFrame(itemCount: 0, highlighted: true));
    await tester.pumpAndSettle();

    expect(find.byType(BoardColumnEmptySlot), findsOneWidget);
    final slot = tester.widget<BoardColumnEmptySlot>(
      find.byType(BoardColumnEmptySlot),
    );
    expect(slot.highlighted, isTrue);
  });
}
