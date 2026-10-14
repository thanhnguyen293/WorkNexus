import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/data/local/repositories/local_ticket_repository.dart';

Ticket _t(String id) => Ticket(
  id: 'zt:bug:$id',
  accountId: 'zt',
  projectId: 'zt:p',
  providerType: ProviderType.zentao,
  externalKey: id,
  title: id,
  body: '',
  priority: Priority.medium,
  status: UnifiedStatus.todo,
  providerStatus: 'active',
  sourceHash: 'h',
  labels: const ['a', 'b'],
);

void main() {
  late AppDatabase db;
  late LocalTicketRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LocalTicketRepository(db);
  });
  tearDown(() => db.close());

  test('an unchanged row keeps its decoded ticket across emissions', () async {
    await repo.upsertTickets([_t('1'), _t('2')]);
    final emissions = <List<Ticket>>[];
    final sub = repo.watchTickets().listen(emissions.add);
    addTearDown(sub.cancel);
    await pumpEventQueue();
    await repo.moveTicket('zt:bug:2', UnifiedStatus.done);
    await pumpEventQueue();

    expect(emissions, hasLength(2));
    Ticket byId(List<Ticket> list, String id) =>
        list.singleWhere((t) => t.id == id);
    expect(
      identical(byId(emissions[0], 'zt:bug:1'), byId(emissions[1], 'zt:bug:1')),
      isTrue,
      reason: 'the untouched row is not decoded again',
    );
    expect(byId(emissions[1], 'zt:bug:2').status, UnifiedStatus.done);
  });
}
