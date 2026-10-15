import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/ticket_sort.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/shared/board/domain/usecases/build_paged_table.dart';

Ticket _t(
  String key, {
  String title = '',
  Priority priority = Priority.medium,
}) => Ticket(
  id: 'zt:task:$key',
  accountId: 'zt',
  projectId: 'p',
  providerType: ProviderType.zentao,
  externalKey: key,
  externalType: 'Task',
  title: title.isEmpty ? key : title,
  body: '',
  priority: priority,
  status: UnifiedStatus.todo,
  providerStatus: 'wait',
  sourceHash: 'h',
);

List<String> _keys(PagedTable<String> table) => [
  for (final t in table.rows) t.externalKey,
];

PagedTable<String> _build(
  List<PagedTableSegment<String>> segments, [
  TicketSort sort = TicketSort.newest,
]) => const BuildPagedTable<String>()(
  PagedTableQuery(segments: segments, sort: sort),
);

void main() {
  test('lists view by view, newest first within each', () {
    final table = _build([
      PagedTableSegment(
        view: 'wait',
        tickets: [_t('9'), _t('120'), _t('31')],
        complete: true,
      ),
      PagedTableSegment(
        view: 'doing',
        tickets: [_t('200'), _t('7')],
        complete: true,
      ),
    ]);

    expect(_keys(table), ['120', '31', '9', '200', '7']);
    expect(table.pending, isNull);
  });

  test('stops at the first view that still has pages', () {
    final table = _build([
      PagedTableSegment(view: 'wait', tickets: [_t('5')], complete: true),
      PagedTableSegment(view: 'doing', tickets: [_t('4')], complete: false),
      PagedTableSegment(view: 'done', tickets: [_t('3')], complete: true),
    ]);

    // Done's rows wait until Doing is loaded, so rows only ever append.
    expect(_keys(table), ['5', '4']);
    expect(table.pending, 'doing');
  });

  test('an empty, unfinished first view still asks for more', () {
    final table = _build([
      const PagedTableSegment(view: 'wait', tickets: [], complete: false),
      PagedTableSegment(view: 'doing', tickets: [_t('1')], complete: true),
    ]);

    expect(table.rows, isEmpty);
    expect(table.pending, 'wait');
  });

  test('sorts within each view by the chosen column, ids breaking ties', () {
    final table = _build([
      PagedTableSegment(
        view: 'wait',
        tickets: [
          _t('1', priority: Priority.low),
          _t('2', priority: Priority.urgent),
          _t('3', priority: Priority.low),
        ],
        complete: true,
      ),
      PagedTableSegment(
        view: 'doing',
        tickets: [
          _t('8', title: 'beta'),
          _t('9', title: 'Alpha'),
        ],
        complete: true,
      ),
    ], const TicketSort(TicketSortField.priority));

    expect(_keys(table), ['2', '3', '1', '9', '8']);
  });

  test('sorting by status descending reverses the views', () {
    final table = _build([
      PagedTableSegment(view: 'wait', tickets: [_t('1')], complete: true),
      PagedTableSegment(view: 'doing', tickets: [_t('2')], complete: false),
    ], const TicketSort(TicketSortField.status, descending: true));

    expect(_keys(table), ['2']);
    expect(table.pending, 'doing');
  });

  test('a header click flips its column, another starts its own way', () {
    const byId = TicketSort.newest;
    expect(byId.toggled(TicketSortField.id).descending, isFalse);
    expect(byId.toggled(TicketSortField.title).descending, isFalse);
    expect(byId.toggled(TicketSortField.updated).descending, isTrue);
  });
}
