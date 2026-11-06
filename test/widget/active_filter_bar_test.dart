import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/widgets/app_icon_button.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/shared/board/domain/usecases/derive_board_facets.dart';
import 'package:work_nexus/shared/board/presentation/providers/board_providers.dart';
import 'package:work_nexus/shared/board/presentation/providers/saved_filter_providers.dart';
import 'package:work_nexus/shared/board/presentation/widgets/active_filter_bar.dart';

import '../support/di_test_harness.dart';

Ticket _bug(String id, int severity, String module) => Ticket(
  id: id,
  accountId: 'zt',
  projectId: 'p',
  providerType: ProviderType.zentao,
  externalKey: id,
  externalType: 'Bug',
  title: 'Bug $id',
  body: '',
  priority: Priority.medium,
  status: UnifiedStatus.todo,
  providerStatus: 'active',
  sourceHash: 'h',
  severity: severity,
  providerEntity: TicketProviderEntity.zentaoBug(module: module),
);

/// The chips under a board's toolbar: one per picked filter group, the saved
/// filter in effect first, each removable.
void main() {
  late AppDatabase db;

  setUp(() async => db = await setUpTestLocator(seed: false));
  tearDown(() async => resetTestLocator(db));

  Future<ProviderContainer> pump(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        boardFacetScopeProvider.overrideWithValue(BoardFacetScope.bug),
        scopedTicketsProvider.overrideWithValue([
          _bug('1', 1, '12'),
          _bug('2', 2, '13'),
        ]),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildAppTheme(
            variant: AppThemeVariant.light,
            surface: SurfaceStyle.outline,
            density: AppDensity.comfortable,
          ),
          home: const Scaffold(
            body: ActiveFilterBar(
              catalog: BoardFacetCatalog({
                BoardFacetKind.module: [
                  BoardFacetChoice('12', label: 'Live stream'),
                  BoardFacetChoice('13', label: 'Share'),
                ],
              }),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('nothing shows while no filter is picked', (tester) async {
    await pump(tester);
    expect(find.byType(AppIconButton), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('a chip per picked group; its ✕ drops just that group', (
    tester,
  ) async {
    final container = await pump(tester);
    container.read(filterStateProvider.notifier)
      ..selectModule('12')
      ..toggleSeverity(1);
    await tester.pumpAndSettle();

    expect(find.text('Live stream'), findsOneWidget);
    expect(find.text('Critical'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove filter').first);
    await tester.pumpAndSettle();
    final f = container.read(filterStateProvider);
    expect(f.modules, isEmpty);
    expect(f.severities, {1});
    await disposeTree(tester);
  });

  testWidgets('the saved filter in effect leads, and Clear all clears', (
    tester,
  ) async {
    final container = await pump(tester);
    final filters = container.read(filterStateProvider.notifier)
      ..toggleSeverity(1);
    await container
        .read(savedFilterControllerProvider.notifier)
        .saveCurrent('MyTeam');
    await tester.pumpAndSettle();
    expect(find.text('MyTeam'), findsOneWidget);
    // Its severity is the saved filter's own: no chip of its own.
    expect(find.text('Critical'), findsNothing);

    // A module picked on top keeps the saved filter and adds its chip.
    filters.selectModule('12');
    await tester.pumpAndSettle();
    expect(find.text('MyTeam'), findsOneWidget);
    expect(find.text('Live stream'), findsOneWidget);
    filters.selectModule(null);

    filters.toggleSeverity(2);
    await tester.pumpAndSettle();
    expect(find.text('MyTeam'), findsNothing, reason: 'no longer matches');

    await tester.tap(find.text('Clear all filters'));
    await tester.pumpAndSettle();
    expect(container.read(filterStateProvider).activeTokenCount, 0);
    await disposeTree(tester);
  });
}
