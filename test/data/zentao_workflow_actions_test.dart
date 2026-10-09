import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/domain/value_objects/zentao_action.dart';
import 'package:work_nexus/core/domain/value_objects/zentao_task_action_input.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/sync/data/sync_service.dart';
import 'package:work_nexus/features/sync/data/zentao_workflow_actions.dart';

class _MockSync extends Mock implements SyncService {}

const _task = Ticket(
  id: 'zt:12',
  accountId: 'zt',
  projectId: 'zt:P',
  providerType: ProviderType.zentao,
  externalKey: '12',
  externalType: 'Task',
  title: 't',
  body: '',
  priority: Priority.medium,
  status: UnifiedStatus.todo,
  providerStatus: 'wait',
  sourceHash: 'h',
);

void main() {
  late _MockSync sync;
  late ZenTaoWorkflowActions actions;

  setUpAll(() {
    registerFallbackValue(_task);
    registerFallbackValue(() async => const Ok<void>(null));
  });

  setUp(() {
    sync = _MockSync();
    actions = ZenTaoWorkflowActions(sync);
    when(
      () => sync.runOptimisticAction(any(), any(), any()),
    ).thenAnswer((_) async => const Ok(null));
  });

  Ticket shown() =>
      verify(
            () => sync.runOptimisticAction(any(), captureAny(), any()),
          ).captured.single
          as Ticket;

  test('each task action shows its outcome at once', () async {
    final expected = {
      ZenTaoTaskAction.start: ('doing', UnifiedStatus.inprogress),
      ZenTaoTaskAction.restart: ('doing', UnifiedStatus.inprogress),
      ZenTaoTaskAction.activate: ('doing', UnifiedStatus.inprogress),
      ZenTaoTaskAction.pause: ('pause', UnifiedStatus.blocked),
      ZenTaoTaskAction.finish: ('done', UnifiedStatus.review),
      ZenTaoTaskAction.close: ('closed', UnifiedStatus.done),
      ZenTaoTaskAction.cancel: ('cancel', UnifiedStatus.done),
    };
    for (final MapEntry(key: action, value: (raw, status))
        in expected.entries) {
      await actions.runTaskAction(
        _task,
        action,
        const ZenTaoTaskActionInput(left: 1),
      );
      final ticket = shown();
      expect(ticket.providerStatus, raw, reason: action.name);
      expect(ticket.status, status, reason: action.name);
    }
  });

  test('closing a bug shows it closed at once', () async {
    final bug = _task.copyWith(externalType: 'Bug', providerStatus: 'resolved');
    await actions.closeBug(bug, comment: 'ok');

    final ticket =
        verify(
              () => sync.runOptimisticAction(any(), captureAny(), any()),
            ).captured.single
            as Ticket;
    expect(ticket.providerStatus, 'closed');
    expect(ticket.status, UnifiedStatus.done);
  });

  test(
    'confirm and reopen go through the bug flows sync already has',
    () async {
      when(
        () => sync.confirmBug(any(), assignee: 'an', comment: 'c'),
      ).thenAnswer((_) async => const Ok(null));
      when(
        () => sync.activateBug(any(), build: '7'),
      ).thenAnswer((_) async => const Ok(null));

      await actions.confirmBug(_task, assignee: 'an', comment: 'c');
      await actions.activateBug(_task, build: '7');

      verify(() => sync.confirmBug(_task, assignee: 'an', comment: 'c'));
      verify(() => sync.activateBug(_task, build: '7'));
    },
  );
}
