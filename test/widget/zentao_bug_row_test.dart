import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/ticket_sort.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/tools/zentao/presentation/widgets/zentao_bug_row.dart';
import 'package:work_nexus/tools/zentao/presentation/widgets/zentao_sortable_header_cell.dart';

void main() {
  const testBug = Ticket(
    id: 'zt:bug:9920',
    accountId: 'acc-1',
    projectId: 'prod-1',
    providerType: ProviderType.zentao,
    externalKey: '9920',
    title: '[Search] Crash when keyword is empty',
    body: 'Bug body',
    priority: Priority.urgent,
    status: UnifiedStatus.review,
    providerStatus: 'resolved',
    sourceHash: 'hash-bug-1',
    assignee: 'Alice Nguyen',
    severity: 1,
    providerEntity: ZenTaoBugEntity(resolution: 'fixed'),
  );

  Widget wrapWidget(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        locale: const Locale('en'),
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('ZenTaoBugRow renders bug metadata matching Task list style', (
    tester,
  ) async {
    await tester.pumpWidget(wrapWidget(const ZenTaoBugRow(ticket: testBug)));
    await tester.pumpAndSettle();

    expect(find.text('#9920'), findsOneWidget);
    expect(find.text('[Search]'), findsOneWidget);
    expect(find.text('Crash when keyword is empty'), findsOneWidget);
    expect(find.text('Alice Nguyen'), findsOneWidget);
    expect(find.text('Fixed'), findsOneWidget);
  });

  testWidgets(
    'ZenTaoSortableHeaderCell displays label and arrow indicator when active',
    (tester) async {
      TicketSortField? sortedField;
      await tester.pumpWidget(
        wrapWidget(
          ZenTaoSortableHeaderCell(
            label: 'Assigned to',
            field: TicketSortField.assignee,
            currentSort: const TicketSort(
              TicketSortField.assignee,
              descending: true,
            ),
            onSort: (f) => sortedField = f,
            width: 150,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ASSIGNED TO'), findsOneWidget);
      expect(find.byIcon(LucideIcons.arrowDown300), findsOneWidget);

      await tester.tap(find.text('ASSIGNED TO'));
      expect(sortedField, TicketSortField.assignee);
    },
  );
}
