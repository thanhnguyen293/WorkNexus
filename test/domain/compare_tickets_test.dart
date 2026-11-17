import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/ticket_sort.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/shared/board/domain/entities/filter_state.dart';
import 'package:work_nexus/shared/board/domain/usecases/build_board.dart';
import 'package:work_nexus/shared/board/domain/usecases/compare_tickets.dart';
import 'package:work_nexus/shared/board/domain/usecases/filter_tickets.dart';

Ticket _t(
  String key, {
  Priority priority = Priority.medium,
  String title = 'Title',
  DateTime? updated,
  int? severity,
  String? assignee,
}) => Ticket(
  id: 't$key',
  accountId: 'a',
  projectId: 'p',
  providerType: ProviderType.github,
  externalKey: key,
  title: title,
  body: '',
  priority: priority,
  status: UnifiedStatus.todo,
  providerStatus: '',
  sourceHash: 'h',
  severity: severity,
  updatedAt: updated,
  assignee: assignee,
);

List<String> _keys(List<Ticket> tickets, TicketSort sort) => ([
  ...tickets,
]..sort(boardComparator(sort))).map((t) => t.externalKey).toList();

void main() {
  final day1 = DateTime(2026);
  final day2 = DateTime(2026, 1, 2);

  group('boardComparator', () {
    test('default: most urgent first, then most recently updated', () {
      final tickets = [
        _t('1', priority: Priority.low, updated: day2),
        _t('2', priority: Priority.urgent, updated: day1),
        _t('3', priority: Priority.urgent, updated: day2),
      ];
      expect(_keys(tickets, boardDefaultSort), ['3', '2', '1']);
    });

    test('created (id) descending puts the newest ticket first', () {
      final tickets = [_t('9'), _t('10'), _t('2')];
      expect(
        _keys(tickets, const TicketSort(TicketSortField.id, descending: true)),
        ['10', '9', '2'],
      );
    });

    test('updated descending puts the most recent first, missing last', () {
      final tickets = [_t('1', updated: day1), _t('2'), _t('3', updated: day2)];
      expect(
        _keys(
          tickets,
          const TicketSort(TicketSortField.updated, descending: true),
        ),
        ['3', '1', '2'],
      );
    });

    test('title ascending ignores case; ties fall back to updated', () {
      final tickets = [
        _t('1', title: 'beta'),
        _t('2', title: 'Alpha', updated: day1),
        _t('3', title: 'alpha', updated: day2),
      ];
      expect(_keys(tickets, const TicketSort(TicketSortField.title)), [
        '3',
        '2',
        '1',
      ]);
    });

    test('severity ascending puts unset severity first', () {
      final tickets = [_t('1', severity: 3), _t('2', severity: 1), _t('3')];
      expect(_keys(tickets, const TicketSort(TicketSortField.severity)), [
        '3',
        '2',
        '1',
      ]);
    });
  });

  test('BuildBoard orders each column by the query sort', () {
    final tickets = [
      _t('1', title: 'b', priority: Priority.urgent),
      _t('2', title: 'a', priority: Priority.low),
    ];
    BoardQuery q(TicketSort sort) => BoardQuery(
      tickets: tickets,
      filter: const FilterState(),
      accountWorkspace: const {},
      now: day1,
      sort: sort,
    );
    List<String> todo(TicketSort sort) => const BuildBoard()(q(sort)).columns
        .firstWhere((c) => c.status == UnifiedStatus.todo)
        .tickets
        .map((t) => t.externalKey)
        .toList();

    expect(todo(boardDefaultSort), ['1', '2']);
    expect(todo(const TicketSort(TicketSortField.title)), ['2', '1']);
  });

  test('a BoardQuery with another sort is not equal', () {
    BoardQuery q(TicketSort sort) => BoardQuery(
      tickets: const [],
      filter: const FilterState(),
      accountWorkspace: const {},
      now: day1,
      sort: sort,
    );
    expect(q(boardDefaultSort), q(boardDefaultSort));
    expect(q(boardDefaultSort) == q(TicketSort.newest), isFalse);
    expect(
      q(TicketSort.newest).withFilter(const FilterState()).sort,
      TicketSort.newest,
    );
  });
}
