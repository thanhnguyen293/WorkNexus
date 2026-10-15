import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/shared/board/domain/usecases/search_local_tickets.dart';

Ticket _makeTicket({
  required String id,
  required String key,
  required String title,
  String accountId = 'acc-1',
}) {
  return Ticket(
    id: id,
    accountId: accountId,
    projectId: 'p-1',
    providerType: ProviderType.zentao,
    externalKey: key,
    title: title,
    body: '',
    priority: Priority.high,
    status: UnifiedStatus.inprogress,
    providerStatus: 'doing',
    sourceHash: 'h',
  );
}

void main() {
  group('SearchLocalTickets', () {
    const useCase = SearchLocalTickets();

    test('returns empty when query is empty or whitespace', () {
      final tickets = [_makeTicket(id: '1', key: 'BUG-1', title: 'First bug')];
      expect(
        useCase(SearchLocalTicketsInput(tickets: tickets, query: '')),
        isEmpty,
      );
      expect(
        useCase(SearchLocalTicketsInput(tickets: tickets, query: '   ')),
        isEmpty,
      );
    });

    test('ranks exact key match over prefix, word-prefix, and contains', () {
      final tContains = _makeTicket(
        id: '1',
        key: 'TASK-10',
        title:
            'Update product catalog', // "catalog" contains "log", but does not start with "log"
      );
      final tWordPrefix = _makeTicket(
        id: '2',
        key: 'TASK-20',
        title: 'Add logging infrastructure', // "logging" starts with "log"
      );
      final tKeyPrefix = _makeTicket(
        id: '3',
        key: 'LOG-45', // key starts with "log"
        title: 'Refactor parser',
      );
      final tExactKey = _makeTicket(
        id: '4',
        key: 'LOG', // exact key
        title: 'Logging epic',
      );

      final result = useCase(
        SearchLocalTicketsInput(
          tickets: [tContains, tWordPrefix, tKeyPrefix, tExactKey],
          query: 'log',
        ),
      );

      expect(result.map((t) => t.id).toList(), ['4', '3', '2', '1']);
    });

    test('caps matches at 8 items', () {
      final tickets = List.generate(
        15,
        (i) => _makeTicket(id: '$i', key: 'TASK-$i', title: 'Task item $i'),
      );

      final result = useCase(
        SearchLocalTicketsInput(tickets: tickets, query: 'TASK'),
      );

      expect(result.length, 8);
    });

    test('filters by accountId when specified', () {
      final tAcc1 = _makeTicket(id: '1', key: 'TASK-1', title: 'Auth task');
      final tAcc2 = _makeTicket(
        id: '2',
        key: 'TASK-2',
        title: 'Auth task',
        accountId: 'acc-2',
      );

      final result = useCase(
        SearchLocalTicketsInput(
          tickets: [tAcc1, tAcc2],
          query: 'Auth',
          accountId: 'acc-1',
        ),
      );

      expect(result.length, 1);
      expect(result.first.id, '1');
    });

    test('matches case-insensitively', () {
      final ticket = _makeTicket(
        id: '1',
        key: 'bug-2041',
        title: 'Crash on launch',
      );

      final result = useCase(
        SearchLocalTicketsInput(tickets: [ticket], query: 'BUG-2041'),
      );

      expect(result.length, 1);
      expect(result.first.id, '1');
    });
  });
}
