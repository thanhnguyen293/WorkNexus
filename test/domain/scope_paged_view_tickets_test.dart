import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/features/board/domain/entities/paged_view_state.dart';
import 'package:work_nexus/features/board/domain/usecases/scope_paged_view_tickets.dart';
import 'package:work_nexus/features/board/domain/value_objects/paged_view_loads.dart';

Ticket _t(String id, String status) => Ticket(
  id: id,
  accountId: 'zt',
  projectId: 'p',
  providerType: ProviderType.zentao,
  externalKey: id,
  title: id,
  body: '',
  priority: Priority.medium,
  status: UnifiedStatus.todo,
  providerStatus: status,
  sourceHash: 'h',
);

void main() {
  const scope = ScopePagedViewTickets<String>();
  final cached = [
    _t('1', 'wait'),
    _t('2', 'wait'), // no longer in the loaded wait view
    _t('3', 'pause'),
    _t('4', 'done'),
  ];

  List<String> ids(Map<String, PagedViewState> views) => [
    for (final t in scope(
      PagedViewScopeQuery(
        tickets: cached,
        loads: PagedViewLoads.of(views),
        viewOf: (t) => t.providerStatus,
      ),
    ))
      t.id,
  ];

  test('a loaded view shows only what it loaded', () {
    expect(
      ids({
        'wait': const PagedViewState(page: 1, ids: {'1'}),
        'pause': const PagedViewState(page: 1, ids: {'3'}),
        'done': const PagedViewState(page: 1, ids: {'4'}),
      }),
      ['1', '3', '4'],
    );
  });

  test('a view that failed or has not loaded keeps its cached tickets', () {
    expect(
      ids({
        'wait': const PagedViewState(page: 1, ids: {'1'}),
        'pause': const PagedViewState(failure: NetworkFailure('offline')),
        'done': const PagedViewState(),
      }),
      ['1', '3', '4'],
    );
  });

  test('a ticket loaded under one view still shows after its status moves', () {
    expect(
      ids({
        'wait': const PagedViewState(page: 1, ids: {'4'}),
        'pause': const PagedViewState(page: 1),
        'done': const PagedViewState(page: 1),
      }),
      ['4'],
    );
  });
}
