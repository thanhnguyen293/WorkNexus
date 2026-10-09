import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/di/providers.dart';
import 'package:work_nexus/core/domain/adapters/zentao_ticket_service.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/core/navigation/navigation_providers.dart';
import 'package:work_nexus/core/theme/app_palette.dart';
import 'package:work_nexus/core/theme/app_theme.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/features/task_detail/presentation/widgets/parent_task_link.dart';
import 'package:work_nexus/features/task_detail/presentation/widgets/subtask_list.dart';
import 'package:work_nexus/l10n/app_localizations.dart';

class _MockService extends Mock implements ZenTaoTicketService {}

Ticket _task(String id, String title) => Ticket(
  id: 'zt:$id',
  accountId: 'zt',
  projectId: 'zt:task',
  providerType: ProviderType.zentao,
  externalKey: id,
  externalType: 'Task',
  title: title,
  body: '',
  priority: Priority.medium,
  status: UnifiedStatus.todo,
  providerStatus: 'wait',
  sourceHash: '',
  url: 'https://zentao.example.com/zentao/task-view-$id.html',
);

void main() {
  late _MockService service;

  setUp(() => service = _MockService());

  Future<ProviderContainer> pump(
    WidgetTester tester,
    List<Ticket> tickets, {
    Widget? body,
  }) async {
    final container = ProviderContainer(
      overrides: [
        zenTaoTicketServiceProvider.overrideWithValue(service),
        ticketsProvider.overrideWith((ref) => Stream.value(tickets)),
      ],
    );
    addTearDown(container.dispose);
    container.listen(ticketsProvider, (_, _) {});
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
          home: Scaffold(
            body:
                body ??
                ParentTaskLink(
                  ticket: _task('12167', 'mobile'),
                  parentId: '12160',
                ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('a synced parent shows its title and opens on tap', (
    tester,
  ) async {
    final container = await pump(tester, [_task('12160', 'Chat feature')]);

    expect(find.text('Chat feature'), findsOneWidget);
    await tester.tap(find.text('#12160'));
    await tester.pump();

    expect(container.read(openTicketIdProvider), 'zt:12160');
    verifyNever(
      () => service.fetchZenTaoTicket(
        host: any(named: 'host'),
        type: any(named: 'type'),
        id: any(named: 'id'),
      ),
    );
  });

  testWidgets('an unsynced parent is fetched from ZenTao, then opened', (
    tester,
  ) async {
    when(
      () => service.fetchZenTaoTicket(
        host: 'zentao.example.com',
        type: 'task',
        id: '12160',
      ),
    ).thenAnswer((_) async => const Ok('zt:12160'));
    final container = await pump(tester, const []);

    await tester.tap(find.text('#12160'));
    await tester.pumpAndSettle();

    expect(container.read(openTicketIdProvider), 'zt:12160');
  });

  testWidgets('a parent lists its subtasks and opens one on tap', (
    tester,
  ) async {
    final container = await pump(
      tester,
      [_task('12167', 'mobile')],
      body: SubtaskList(
        ticket: _task('12165', 'Notification layer display'),
        subtasks: const [
          TicketSubtask(id: '12166', title: 'test', status: UnifiedStatus.todo),
          TicketSubtask(
            id: '12167',
            title: 'mobile',
            status: UnifiedStatus.todo,
            assignee: 'Thanh',
          ),
        ],
      ),
    );

    expect(find.text('SUBTASKS (2)'), findsOneWidget);
    expect(find.text('Thanh'), findsOneWidget);
    await tester.tap(find.text('mobile'));
    await tester.pump();

    expect(container.read(openTicketIdProvider), 'zt:12167');
  });
}
