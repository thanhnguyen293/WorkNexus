import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/tools/zentao/domain/usecases/list_task_bugs.dart';

Ticket _ticket(
  String key, {
  String accountId = 'zt',
  ProviderType provider = ProviderType.zentao,
  TicketProviderEntity? entity,
}) => Ticket(
  id: '$accountId:$key',
  accountId: accountId,
  projectId: 'p',
  providerType: provider,
  externalKey: key,
  title: key,
  body: '',
  priority: Priority.medium,
  status: UnifiedStatus.todo,
  providerStatus: 'active',
  sourceHash: '',
  providerEntity: entity,
);

Ticket _bug(String key, {String? task, String accountId = 'zt'}) => _ticket(
  key,
  accountId: accountId,
  entity: TicketProviderEntity.zentaoBug(task: task),
);

void main() {
  const list = ListTaskBugs();
  final task = _ticket(
    '11548',
    entity: const TicketProviderEntity.zentaoTask(),
  );

  test("lists the account's bugs linked to the task, newest first", () {
    final bugs = list(
      task: task,
      tickets: [
        _bug('6555', task: '11548'),
        _bug('6600', task: '11548'),
        _bug('6556', task: '9999'),
        _bug('6557'),
        // Same task id, another account's ZenTao.
        _bug('6558', task: '11548', accountId: 'other'),
        // A task is not a bug, whatever it points at.
        _ticket('11549', entity: const TicketProviderEntity.zentaoTask()),
      ],
    );

    expect(bugs.map((b) => b.externalKey), ['6600', '6555']);
  });

  test('a task with no linked bugs has none', () {
    expect(
      list(
        task: task,
        tickets: [_bug('1', task: '2')],
      ),
      isEmpty,
    );
  });
}
