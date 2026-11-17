import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/value_objects/ticket_sort.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/shared/board/presentation/providers/board_sort_provider.dart';
import 'package:work_nexus/shared/board/presentation/widgets/board_sort_button.dart';

void main() {
  testWidgets('picking a field sorts by it; picking it again flips it', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const Scaffold(body: Center(child: BoardSortButton())),
        ),
      ),
    );

    // Starts on the default order.
    expect(find.text('Priority'), findsOneWidget);

    Future<void> pick(String label) async {
      await tester.tap(find.byType(BoardSortButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    await pick('Updated');
    expect(
      container.read(boardSortProvider),
      const TicketSort(TicketSortField.updated, descending: true),
    );
    expect(find.text('Updated'), findsOneWidget);

    await pick('Updated');
    expect(
      container.read(boardSortProvider),
      const TicketSort(TicketSortField.updated),
    );
  });
}
