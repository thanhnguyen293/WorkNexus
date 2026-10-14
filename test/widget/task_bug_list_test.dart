import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/di/providers.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/features/task_detail/domain/repositories/zentao_task_bugs.dart';
import 'package:work_nexus/features/task_detail/presentation/widgets/task_bug_list.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

class _MockTaskBugs extends Mock implements ZenTaoTaskBugs {}

Ticket _ticket(String id, String key, TicketProviderEntity entity) => Ticket(
  id: id,
  accountId: 'zt',
  projectId: 'zt:P',
  providerType: ProviderType.zentao,
  externalKey: key,
  title: 'Ticket $key',
  body: '',
  priority: Priority.medium,
  status: UnifiedStatus.todo,
  providerStatus: 'active',
  sourceHash: 'h',
  assignee: 'Ryan',
  providerEntity: entity,
);

final _task = _ticket(
  'zt:task:11548',
  '11548',
  const TicketProviderEntity.zentaoTask(execution: '31'),
);

Ticket _bug(String key, {String? task}) =>
    _ticket('zt:bug:$key', key, TicketProviderEntity.zentaoBug(task: task));

void main() {
  late _MockTaskBugs taskBugs;

  setUp(() => taskBugs = _MockTaskBugs());

  void answer(Result<void> result) => when(
    () => taskBugs.syncTaskBugs(
      accountId: any(named: 'accountId'),
      executionId: any(named: 'executionId'),
      taskId: any(named: 'taskId'),
    ),
  ).thenAnswer((_) async => result);

  Future<ProviderContainer> pump(
    WidgetTester tester,
    List<Ticket> tickets,
  ) async {
    final container = ProviderContainer(
      overrides: [
        ticketsProvider.overrideWith((ref) => Stream.value(tickets)),
        zentaoTaskBugsProvider.overrideWithValue(taskBugs),
      ],
    );
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
          home: Scaffold(body: TaskBugList(ticket: _task)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets("lists the task's bugs and opens one on a tap", (tester) async {
    answer(const Ok(null));
    final container = await pump(tester, [
      _task,
      _bug('6555', task: '11548'),
      _bug('6600', task: '11548'),
      _bug('6556', task: '9999'),
    ]);

    expect(find.text('RELATED BUGS (2)'), findsOneWidget);
    expect(find.text('#6600'), findsOneWidget);
    expect(find.text('#6555'), findsOneWidget);
    expect(find.text('#6556'), findsNothing);
    // The task's bugs were fetched from its execution.
    verify(
      () => taskBugs.syncTaskBugs(
        accountId: 'zt',
        executionId: '31',
        taskId: '11548',
      ),
    ).called(1);

    await tester.tap(find.text('Ticket 6555'));
    await tester.pump();
    expect(container.read(openTicketIdProvider), 'zt:bug:6555');
  });

  testWidgets('shows nothing while the task has no related bugs', (
    tester,
  ) async {
    answer(const Ok(null));
    await pump(tester, [_task, _bug('6556', task: '9999')]);

    expect(find.textContaining('RELATED BUGS'), findsNothing);
  });

  testWidgets('a failed fetch says so and retries', (tester) async {
    answer(const Err(NetworkFailure('offline')));
    await pump(tester, [_task]);

    expect(
      find.text("Couldn't load the related bugs from ZenTao."),
      findsOneWidget,
    );

    answer(const Ok(null));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    verify(
      () => taskBugs.syncTaskBugs(
        accountId: 'zt',
        executionId: '31',
        taskId: '11548',
      ),
    ).called(2);
    expect(find.text('Retry'), findsNothing);
  });
}
