import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/navigation/open_zentao_execution.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/task_detail/presentation/widgets/task_detail_sections.dart';
import 'package:work_nexus/features/task_detail/presentation/widgets/zentao_linked_ticket.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

Ticket _ticket(ZenTaoTaskEntity task) => Ticket(
  id: 'zt:task:12897',
  accountId: 'zt',
  projectId: 'zt:P',
  providerType: ProviderType.zentao,
  externalKey: '12897',
  title: 'Notification layer',
  body: '',
  priority: Priority.medium,
  status: UnifiedStatus.inprogress,
  providerStatus: 'doing',
  sourceHash: 'h',
  providerEntity: task,
);

/// A ZenTao task's sidebar reads like a bug's: classification, effort, then
/// a folded lifecycle.
void main() {
  Future<void> pump(
    WidgetTester tester,
    ZenTaoTaskEntity task, {
    OpenZenTaoExecution? openExecution,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          openZenTaoExecutionProvider.overrideWithValue(openExecution),
        ],
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
            body: SingleChildScrollView(
              child: ZenTaoTaskSections(task, ticket: _ticket(task)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const task = ZenTaoTaskEntity(
    taskType: 'test',
    execution: '31',
    project: '7',
    executionName: 'VN_Socialfi',
    parentId: '12165',
    parentName: 'Notification layer display',
    fromBug: '3218',
    estimate: 0,
    consumed: 16,
    left: 8,
    deadline: '2026-10-20',
    openedBy: 'KanDang',
  );

  testWidgets('classification, then effort, with ZenTao\'s values', (
    tester,
  ) async {
    await pump(tester, task);

    expect(find.text('Testing'), findsOneWidget);
    expect(find.text('67%'), findsOneWidget);
    expect(find.text('16 h'), findsOneWidget);
    expect(find.text('8 h'), findsOneWidget);
    expect(find.text('2026-10-20'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Type')).dy,
      lessThan(tester.getTopLeft(find.text('Logged')).dy),
    );
    // No story: no row for it.
    expect(find.text('Story'), findsNothing);
  });

  testWidgets('parent task and source bug are links', (tester) async {
    await pump(tester, task);

    expect(
      find.descendant(
        of: find.byType(ZenTaoLinkedTicket),
        matching: find.text('Notification layer display · #12165'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ZenTaoLinkedTicket),
        matching: find.text('#3218'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the execution opens its board', (tester) async {
    final opened = <ProviderExecution>[];
    await pump(
      tester,
      task,
      openExecution: (context, ref, execution) async => opened.add(execution),
    );

    await tester.tap(find.text('VN_Socialfi'));
    await tester.pumpAndSettle();

    expect(opened.single.id, '31');
    expect(opened.single.projectId, '7');
  });

  testWidgets('the lifecycle starts folded', (tester) async {
    await pump(tester, task);

    expect(find.text('KanDang'), findsNothing);
    await tester.tap(find.text('LIFECYCLE'));
    await tester.pumpAndSettle();
    expect(find.text('KanDang'), findsOneWidget);
  });
}
