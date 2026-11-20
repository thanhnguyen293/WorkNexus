import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/features/chat/domain/usecases/list_person_tickets.dart';

Ticket _ticket(
  String id, {
  String accountId = 'a',
  String? assignee,
  String? openedBy,
  UnifiedStatus status = UnifiedStatus.todo,
  int day = 1,
}) => Ticket(
  id: id,
  accountId: accountId,
  projectId: 'p',
  providerType: ProviderType.zentao,
  externalKey: id,
  externalType: 'bug',
  title: id,
  body: '',
  priority: Priority.medium,
  status: status,
  providerStatus: '',
  sourceHash: '',
  assignee: assignee,
  updatedAt: DateTime(2026, 1, day),
  providerEntity: TicketProviderEntity.zentaoBug(openedByHandle: openedBy),
);

void main() {
  const list = ListPersonTickets();

  test('splits open tickets into assigned and reported, newest first', () {
    final result = list(
      [
        _ticket('a1', assignee: 'tran'),
        _ticket('a2', assignee: 'Tran', day: 5),
        _ticket('r1', assignee: 'qa', openedBy: 'tran'),
        _ticket('done', assignee: 'tran', status: UnifiedStatus.done),
        _ticket('other', assignee: 'tran', accountId: 'b'),
        _ticket('none', assignee: 'qa', openedBy: 'qa'),
      ],
      accountId: 'a',
      handle: 'tran',
    );

    expect(result.assigned.map((t) => t.id), ['a2', 'a1']);
    expect(result.reported.map((t) => t.id), ['r1']);
  });

  test('a ticket they both reported and hold counts once, as assigned', () {
    final result = list(
      [_ticket('x', assignee: 'tran', openedBy: 'tran')],
      accountId: 'a',
      handle: 'tran',
    );

    expect(result.assigned.map((t) => t.id), ['x']);
    expect(result.reported, isEmpty);
  });

  test('a blank handle matches nothing', () {
    final result = list([_ticket('x')], accountId: 'a', handle: ' ');

    expect(result.assigned, isEmpty);
    expect(result.reported, isEmpty);
  });
}
