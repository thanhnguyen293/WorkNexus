import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/l10n/app_localizations.dart';
import 'package:work_nexus/tools/zentao/presentation/widgets/zentao_task_manager_table_view.dart';

const _sampleTask = Ticket(
  id: 'zt:task:12824',
  accountId: 'acc1',
  projectId: 'p1',
  providerType: ProviderType.zentao,
  externalKey: '12824',
  externalType: 'task',
  title: '[Indexer][Tron] Sync relayer wallet balance and energy metrics',
  body: 'Background worker to poll energy resources and relayer balance.',
  priority: Priority.high,
  status: UnifiedStatus.inprogress,
  providerStatus: 'doing',
  sourceHash: 'hash_tron_indexer',
  assignee: 'Lucas_Montgomery',
  labels: ['module:Indexer', 'deadline:2026-10-30'],
);

const _sampleTask2 = Ticket(
  id: 'zt:task:12169',
  accountId: 'acc1',
  projectId: 'p1',
  providerType: ProviderType.zentao,
  externalKey: '12169',
  externalType: 'task',
  title:
      '[Report Metrics][Feed] Calculate previous_total and change_percent badge',
  body: 'Aggregate report metrics and format change percentage indicators.',
  priority: Priority.urgent,
  status: UnifiedStatus.todo,
  providerStatus: 'wait',
  sourceHash: 'hash_report_metrics',
  assignee: 'Sophia_Kensington',
  labels: ['module:Report Metrics', 'deadline:2026-09-15'],
);

void main() {
  Widget buildHarness({
    List<Ticket> tickets = const [_sampleTask, _sampleTask2],
  }) {
    return ProviderScope(
      overrides: [openTicketIdProvider.overrideWithValue(null)],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildAppTheme(
          variant: AppThemeVariant.light,
          surface: SurfaceStyle.outline,
          density: AppDensity.comfortable,
        ),
        home: Scaffold(body: ZenTaoTaskManagerTableView(tickets: tickets)),
      ),
    );
  }

  testWidgets('renders sticky header columns and task metrics', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildHarness());
    await tester.pumpAndSettle();

    // Check header columns
    expect(find.text('ID'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('P'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('AssignTo'), findsOneWidget);
    expect(find.text('Deadline'), findsOneWidget);
    expect(find.text('Action'), findsOneWidget);

    // Check module sidebar
    expect(find.text('Modules'), findsOneWidget);
    expect(find.text('All Modules'), findsOneWidget);

    // Check rows data
    expect(find.text('#12824'), findsOneWidget);
    expect(find.text('#12169'), findsOneWidget);
    expect(
      find.text('Sync relayer wallet balance and energy metrics'),
      findsOneWidget,
    );
    expect(
      find.text('Calculate previous_total and change_percent badge'),
      findsOneWidget,
    );

    // Check footer totals
    expect(find.text('Total: 2 tasks'), findsOneWidget);
  });
}
