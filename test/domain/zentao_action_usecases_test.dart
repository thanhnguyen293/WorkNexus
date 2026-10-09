import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/domain/value_objects/zentao_action.dart';
import 'package:work_nexus/core/domain/value_objects/zentao_task_action_input.dart';
import 'package:work_nexus/features/task_detail/domain/usecases/check_zentao_task_input.dart';
import 'package:work_nexus/features/task_detail/domain/usecases/list_zentao_bug_actions.dart';
import 'package:work_nexus/features/task_detail/domain/usecases/list_zentao_create_actions.dart';
import 'package:work_nexus/features/task_detail/domain/usecases/list_zentao_task_actions.dart';
import 'package:work_nexus/features/task_detail/domain/value_objects/zentao_bug_action.dart';
import 'package:work_nexus/features/task_detail/domain/value_objects/zentao_create_action.dart';

Ticket _ticket(
  String type,
  String raw, {
  UnifiedStatus status = UnifiedStatus.todo,
  TicketProviderEntity? entity,
}) => Ticket(
  id: 'zt:1',
  accountId: 'zt',
  projectId: 'zt:P',
  providerType: ProviderType.zentao,
  externalKey: '1',
  externalType: type,
  title: 't',
  body: '',
  priority: Priority.medium,
  status: status,
  providerStatus: raw,
  sourceHash: 'h',
  providerEntity: entity,
);

void main() {
  group('ListZenTaoBugActions', () {
    const list = ListZenTaoBugActions();

    test('a new bug is confirmed or resolved', () {
      final menu = list(_ticket('Bug', 'active', status: UnifiedStatus.inbox));
      expect(menu.canAssign, isTrue);
      expect(menu.actions, [ZenTaoBugAction.confirm, ZenTaoBugAction.resolve]);
    });

    test('a confirmed bug is only resolved', () {
      final menu = list(_ticket('Bug', 'active'));
      expect(menu.actions, [ZenTaoBugAction.resolve]);
    });

    test('a resolved bug is closed or reopened', () {
      final menu = list(
        _ticket('Bug', 'resolved', status: UnifiedStatus.review),
      );
      expect(menu.canAssign, isTrue);
      expect(menu.actions, [ZenTaoBugAction.close, ZenTaoBugAction.activate]);
    });

    test('a closed bug is only reopened, and not reassigned', () {
      final menu = list(_ticket('Bug', 'closed', status: UnifiedStatus.done));
      expect(menu.canAssign, isFalse);
      expect(menu.actions, [ZenTaoBugAction.activate]);
    });
  });

  group('ListZenTaoTaskActions', () {
    const list = ListZenTaoTaskActions();

    List<ZenTaoTaskAction> actions(String raw, {bool isParent = false}) => list(
      _ticket(
        'Task',
        raw,
        entity: TicketProviderEntity.zentaoTask(isParent: isParent),
      ),
    ).actions;

    test('each status offers what ZenTao allows', () {
      expect(actions('wait'), [
        ZenTaoTaskAction.start,
        ZenTaoTaskAction.finish,
        ZenTaoTaskAction.cancel,
      ]);
      expect(actions('doing'), [
        ZenTaoTaskAction.pause,
        ZenTaoTaskAction.finish,
        ZenTaoTaskAction.cancel,
      ]);
      expect(actions('pause'), [
        ZenTaoTaskAction.restart,
        ZenTaoTaskAction.finish,
        ZenTaoTaskAction.cancel,
      ]);
      expect(actions('done'), [
        ZenTaoTaskAction.activate,
        ZenTaoTaskAction.close,
      ]);
      expect(actions('cancel'), [
        ZenTaoTaskAction.activate,
        ZenTaoTaskAction.close,
      ]);
      expect(actions('closed'), [ZenTaoTaskAction.activate]);
    });

    test('a closed or cancelled task is not reassigned', () {
      for (final raw in ['closed', 'cancel']) {
        expect(list(_ticket('Task', raw)).canAssign, isFalse, reason: raw);
      }
      expect(list(_ticket('Task', 'doing')).canAssign, isTrue);
    });

    test('a parent task follows its subtasks', () {
      expect(actions('doing', isParent: true), [ZenTaoTaskAction.cancel]);
      expect(actions('pause', isParent: true), [
        ZenTaoTaskAction.restart,
        ZenTaoTaskAction.cancel,
      ]);
      expect(actions('done', isParent: true), isEmpty);
      final parent = _ticket(
        'Task',
        'doing',
        entity: const TicketProviderEntity.zentaoTask(isParent: true),
      );
      expect(list(parent).canAssign, isFalse);
    });
  });

  group('CheckZenTaoTaskInput', () {
    const check = CheckZenTaoTaskInput();

    ZenTaoTaskInputProblem? problem(
      ZenTaoTaskAction action, {
      double spent = 0,
      double left = 0,
      double logged = 0,
    }) => check((
      action: action,
      input: ZenTaoTaskActionInput(spent: spent, left: left),
      logged: logged,
    ));

    test('start, continue and reopen need hours left', () {
      for (final action in [
        ZenTaoTaskAction.start,
        ZenTaoTaskAction.restart,
        ZenTaoTaskAction.activate,
      ]) {
        expect(
          problem(action),
          ZenTaoTaskInputProblem.leftRequired,
          reason: action.name,
        );
        expect(problem(action, left: 2), isNull, reason: action.name);
      }
    });

    test('finishing needs hours worked unless some are logged', () {
      expect(
        problem(ZenTaoTaskAction.finish),
        ZenTaoTaskInputProblem.spentRequired,
      );
      expect(problem(ZenTaoTaskAction.finish, spent: 1), isNull);
      expect(problem(ZenTaoTaskAction.finish, logged: 3), isNull);
    });

    test('hours must be a number, 0 or more', () {
      expect(
        problem(ZenTaoTaskAction.start, spent: -1, left: 2),
        ZenTaoTaskInputProblem.invalidHours,
      );
      expect(
        problem(ZenTaoTaskAction.activate, left: double.nan),
        ZenTaoTaskInputProblem.invalidHours,
      );
    });

    test('pause, close and cancel ask for no hours', () {
      for (final action in [
        ZenTaoTaskAction.pause,
        ZenTaoTaskAction.close,
        ZenTaoTaskAction.cancel,
      ]) {
        expect(problem(action, spent: -1, left: -1), isNull, reason: '$action');
      }
    });
  });

  group('ListZenTaoCreateActions', () {
    const list = ListZenTaoCreateActions();

    test('a bug is copied', () {
      expect(list(_ticket('Bug', 'active')), [ZenTaoCreateAction.copyBug]);
    });

    test('an open task gets subtasks and bugs', () {
      final task = _ticket(
        'Task',
        'doing',
        entity: const TicketProviderEntity.zentaoTask(execution: '31'),
      );
      expect(list(task), [
        ZenTaoCreateAction.subtask,
        ZenTaoCreateAction.bugFromTask,
      ]);
    });

    test('no subtask under a subtask, a closed task, or an unknown sprint', () {
      for (final (raw, entity) in [
        (
          'doing',
          const TicketProviderEntity.zentaoTask(execution: '31', parentId: '7'),
        ),
        ('closed', const TicketProviderEntity.zentaoTask(execution: '31')),
        ('doing', const TicketProviderEntity.zentaoTask()),
      ]) {
        expect(list(_ticket('Task', raw, entity: entity)), [
          ZenTaoCreateAction.bugFromTask,
        ], reason: '$raw $entity');
      }
    });
  });
}
