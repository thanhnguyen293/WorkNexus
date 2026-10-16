import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/shared/board/domain/entities/paged_view_state.dart';
import 'package:work_nexus/shared/board/domain/value_objects/paged_view_loads.dart';

void main() {
  test('projects a view to its loaded ids, or null before its first page', () {
    final loads = PagedViewLoads.of({
      'wait': const PagedViewState(page: 1, ids: {'1', '2'}),
      'pause': const PagedViewState(loading: true),
      'done': const PagedViewState(failure: NetworkFailure('offline')),
    });
    expect(loads.ids, {
      'wait': {'1', '2'},
      'pause': null,
      'done': null,
    });
  });

  test('equal while the loaded ids are the same, whatever else changed', () {
    const before = PagedViewState(page: 1, ids: {'1'});
    final a = PagedViewLoads.of({
      'wait': before,
      'pause': const PagedViewState(),
    });
    final b = PagedViewLoads.of({
      'wait': before.copyWith(loading: true, scanVisible: 3),
      'pause': const PagedViewState(failure: NetworkFailure('offline')),
    });
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('differs once a view loads or its ids change', () {
    final a = PagedViewLoads.of({'wait': const PagedViewState()});
    final started = PagedViewLoads.of({'wait': const PagedViewState(page: 1)});
    final more = PagedViewLoads.of({
      'wait': const PagedViewState(page: 1, ids: {'1'}),
    });
    expect(a, isNot(started));
    expect(started, isNot(more));
  });
}
