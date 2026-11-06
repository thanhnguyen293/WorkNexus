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
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/shared/board/domain/usecases/derive_board_facets.dart';
import 'package:work_nexus/shared/board/presentation/providers/board_providers.dart';
import 'package:work_nexus/shared/board/presentation/widgets/filter_facet_groups.dart';

import '../support/di_test_harness.dart';

Ticket _bug(String id, String module) => Ticket(
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
  providerEntity: TicketProviderEntity.zentaoBug(module: module),
);

/// The bug board's Filters popover has no Module group: the module is picked
/// from the side panel's module tree.
void main() {
  late AppDatabase db;

  setUp(() async => db = await setUpTestLocator(seed: false));
  tearDown(() async => resetTestLocator(db));

  testWidgets('the popover leaves the module to the side panel', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        boardFacetScopeProvider.overrideWithValue(BoardFacetScope.bug),
        scopedTicketsProvider.overrideWithValue([
          _bug('1', '12'),
          _bug('2', '12'),
          _bug('3', '13'),
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
            body: SingleChildScrollView(
              child: FacetFilterGroups(
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
      ),
    );
    await tester.pumpAndSettle();

    // Modules are picked from the side panel's module tree, not here.
    expect(find.text('MODULE'), findsNothing);
    expect(find.text('Live stream'), findsNothing);
    await disposeTree(tester);
  });
}
