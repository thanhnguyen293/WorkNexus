import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/features/board/domain/entities/filter_state.dart';
import 'package:work_nexus/features/board/domain/usecases/build_board.dart';
import 'package:work_nexus/features/board/domain/usecases/filter_tickets.dart';
import 'package:work_nexus/features/board/domain/value_objects/saved_view.dart';

Ticket _t({
  required String id,
  String account = 'ghP',
  String project = 'p1',
  ProviderType provider = ProviderType.github,
  String key = '1',
  UnifiedStatus status = UnifiedStatus.todo,
  Priority priority = Priority.medium,
  String title = 'Title',
  List<String> labels = const [],
  DateTime? updated,
}) {
  return Ticket(
    id: id,
    accountId: account,
    projectId: project,
    providerType: provider,
    externalKey: key,
    title: title,
    body: '',
    priority: priority,
    status: status,
    providerStatus: '',
    sourceHash: 'h',
    labels: labels,
    updatedAt: updated,
  );
}

BoardQuery _q(
  List<Ticket> tickets,
  FilterState filter, {
  Map<String, String>? accountWorkspace,
  DateTime? now,
}) {
  return BoardQuery(
    tickets: tickets,
    filter: filter,
    accountWorkspace:
        accountWorkspace ?? {'ghP': 'personal', 'ghA': 'compA', 'ztB': 'compB'},
    now: now ?? DateTime(2026, 7, 17, 12),
  );
}

void main() {
  const filter = FilterTickets();

  group('FilterTickets', () {
    test('workspace scope excludes other workspaces', () {
      final tickets = [_t(id: 'a'), _t(id: 'b', account: 'ghA')];
      final out = filter(_q(tickets, const FilterState(workspaceId: 'compA')));
      expect(out.map((t) => t.id), ['b']);
    });

    test('provider filter', () {
      final tickets = [
        _t(id: 'a'),
        _t(id: 'b', provider: ProviderType.zentao, account: 'ztB'),
      ];
      final out = filter(
        _q(tickets, const FilterState(providers: {ProviderType.zentao})),
      );
      expect(out.map((t) => t.id), ['b']);
    });

    test('status + priority filters combine', () {
      final tickets = [
        _t(id: 'a', status: UnifiedStatus.done, priority: Priority.low),
        _t(id: 'b', status: UnifiedStatus.done, priority: Priority.urgent),
        _t(id: 'c', priority: Priority.urgent),
      ];
      final out = filter(
        _q(
          tickets,
          const FilterState(
            statuses: {UnifiedStatus.done},
            priorities: {Priority.urgent},
          ),
        ),
      );
      expect(out.map((t) => t.id), ['b']);
    });

    test('search matches title, key, and labels case-insensitively', () {
      final tickets = [
        _t(id: 'a', title: 'Fix websocket reconnect'),
        _t(id: 'b', title: 'Add shortcuts', labels: ['enhancement']),
        _t(id: 'c', key: 'SILVER-142', title: 'Payments'),
      ];
      expect(
        filter(
          _q(tickets, const FilterState(search: 'WEBSOCKET')),
        ).map((t) => t.id),
        ['a'],
      );
      expect(
        filter(
          _q(tickets, const FilterState(search: 'enhancement')),
        ).map((t) => t.id),
        ['b'],
      );
      expect(
        filter(
          _q(tickets, const FilterState(search: 'silver-142')),
        ).map((t) => t.id),
        ['c'],
      );
    });

    test('saved view: mine = todo + inprogress', () {
      final tickets = [
        _t(id: 'a'),
        _t(id: 'b', status: UnifiedStatus.inprogress),
        _t(id: 'c', status: UnifiedStatus.done),
      ];
      final out = filter(
        _q(tickets, const FilterState(savedView: SavedView.mine)),
      );
      expect(out.map((t) => t.id), ['a', 'b']);
    });

    test('saved view: today keeps only recently-updated', () {
      final now = DateTime(2026, 7, 17, 12);
      final tickets = [
        _t(id: 'fresh', updated: now.subtract(const Duration(hours: 2))),
        _t(id: 'stale', updated: now.subtract(const Duration(days: 3))),
        _t(id: 'never'),
      ];
      final out = filter(
        _q(tickets, const FilterState(savedView: SavedView.today), now: now),
      );
      expect(out.map((t) => t.id), ['fresh']);
    });
  });

  group('BuildBoard', () {
    test('groups into six ordered columns with correct counts', () {
      final tickets = [
        _t(id: 'a'),
        _t(id: 'b'),
        _t(id: 'c', status: UnifiedStatus.done),
      ];
      final board = const BuildBoard()(_q(tickets, const FilterState()));
      expect(board.columns.map((c) => c.status), UnifiedStatus.columns);
      expect(board.total, 3);
      final todo = board.columns.firstWhere(
        (c) => c.status == UnifiedStatus.todo,
      );
      expect(todo.count, 2);
    });

    test('sorts a column by priority (urgent first)', () {
      final tickets = [
        _t(id: 'low', priority: Priority.low),
        _t(id: 'urgent', priority: Priority.urgent),
        _t(id: 'med'),
      ];
      final board = const BuildBoard()(_q(tickets, const FilterState()));
      final todo = board.columns.firstWhere(
        (c) => c.status == UnifiedStatus.todo,
      );
      expect(todo.tickets.map((t) => t.id), ['urgent', 'med', 'low']);
    });
  });
}
