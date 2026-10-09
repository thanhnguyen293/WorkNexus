import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/di/providers.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter.dart';
import 'package:work_nexus/core/domain/adapters/zentao_workflow_service.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/domain/value_objects/zentao_action.dart';
import 'package:work_nexus/core/domain/value_objects/zentao_task_action_input.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/navigation/ticket_editor_route.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/task_detail/presentation/widgets/action_dialog_scaffold.dart';
import 'package:work_nexus/features/task_detail/presentation/widgets/zentao_ticket_actions.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

class _MockWorkflow extends Mock implements ZenTaoWorkflowService {}

Ticket _ticket(String type, String raw, {TicketProviderEntity? entity}) =>
    Ticket(
      id: 'zt:12',
      accountId: 'zt',
      projectId: 'zt:P',
      providerType: ProviderType.zentao,
      externalKey: '12',
      externalType: type,
      title: 't',
      body: '',
      priority: Priority.medium,
      status: UnifiedStatus.inprogress,
      providerStatus: raw,
      sourceHash: 'h',
      providerEntity: entity,
    );

void main() {
  late _MockWorkflow workflow;

  setUpAll(() {
    registerFallbackValue(_ticket('Task', 'doing'));
    registerFallbackValue(ZenTaoTaskAction.start);
    registerFallbackValue(const ZenTaoTaskActionInput());
  });

  setUp(() {
    workflow = _MockWorkflow();
    when(
      () => workflow.runTaskAction(any(), any(), any()),
    ).thenAnswer((_) async => const Ok(null));
  });

  Future<void> pump(WidgetTester tester, Ticket ticket) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          zenTaoWorkflowServiceProvider.overrideWithValue(workflow),
          providerUsersProvider.overrideWith(
            (ref, id) async => const <ProviderUser>[],
          ),
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
          home: Scaffold(body: ZenTaoActions(ticket: ticket)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a task in progress offers what ZenTao allows', (tester) async {
    await pump(
      tester,
      _ticket('Task', 'doing', entity: const TicketProviderEntity.zentaoTask()),
    );

    for (final label in ['Assign', 'Pause', 'Finish', 'Cancel task']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Start'), findsNothing);
    expect(find.text('Close'), findsNothing);
  });

  testWidgets('a closed bug can only be reopened', (tester) async {
    await pump(tester, _ticket('Bug', 'closed'));

    expect(find.text('Activate'), findsOneWidget);
    expect(find.text('Assign'), findsNothing);
    expect(find.text('Resolve'), findsNothing);
  });

  testWidgets('finishing asks for the hours worked, then sends them', (
    tester,
  ) async {
    final task = _ticket(
      'Task',
      'doing',
      entity: const TicketProviderEntity.zentaoTask(consumed: 0),
    );
    await pump(tester, task);

    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();
    expect(find.text('Finish #12'), findsOneWidget);
    expect(
      find.text('Enter the hours worked — none are logged yet'),
      findsOneWidget,
    );

    final hours = find.descendant(
      of: find.byType(ActionScaffold),
      matching: find.byType(TextField),
    );
    await tester.enterText(hours.first, '2,5');
    await tester.pump();
    expect(
      find.text('Enter the hours worked — none are logged yet'),
      findsNothing,
    );

    await tester.tap(find.text('Finish').last);
    await tester.pumpAndSettle();

    final input =
        verify(
              () => workflow.runTaskAction(
                task,
                ZenTaoTaskAction.finish,
                captureAny(),
              ),
            ).captured.single
            as ZenTaoTaskActionInput;
    expect(input.spent, 2.5);
    expect(find.text('Finish #12: done'), findsOneWidget);
  });

  testWidgets('a task starts a subtask of itself in the editor', (
    tester,
  ) async {
    await pump(
      tester,
      _ticket(
        'Task',
        'doing',
        entity: const TicketProviderEntity.zentaoTask(execution: '31'),
      ),
    );
    expect(find.text('Report bug'), findsOneWidget);

    await tester.tap(find.text('Add subtask'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ZenTaoActions)),
    );
    expect(
      container.read(ticketEditorProvider),
      const NewTaskRoute(accountId: 'zt', executionId: '31', parentId: '12'),
    );
  });

  testWidgets('a bug is copied in its product', (tester) async {
    await pump(
      tester,
      _ticket(
        'Bug',
        'active',
        entity: const TicketProviderEntity.zentaoBug(product: '4'),
      ),
    );

    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ZenTaoActions)),
    );
    expect(
      container.read(ticketEditorProvider),
      const NewBugRoute(accountId: 'zt', productId: '4', copyOf: '12'),
    );
    expect(container.read(openTicketIdProvider), isNull);
  });
}
