import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/features/board/domain/entities/filter_state.dart';
import 'package:work_nexus/features/board/presentation/board_providers.dart';

/// Switching boards used to wipe the filter(). [FilterController.openBoard] gives
/// every board its own remembered filter instead.
void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  FilterController controller() => container.read(filterStateProvider.notifier);
  FilterState filter() => container.read(filterStateProvider);

  test('a ZenTao board opens on "my tickets" the first time', () {
    controller().openBoard('zentao:bugs:a:1', selfHandle: 'thanh');

    expect(filter().assignees, {'thanh'});
  });

  test('an unknown self handle opens the board unfiltered', () {
    controller().openBoard('zentao:bugs:a:1');

    expect(filter().hasActiveFilters, isFalse);
  });

  test('switching boards does not carry the previous filter over', () {
    controller().openBoard('zentao:bugs:a:1', selfHandle: 'thanh');
    controller().toggleStatus(UnifiedStatus.blocked);

    controller().openBoard('gitlab:a:9');

    expect(filter().hasActiveFilters, isFalse);
  });

  test('coming back restores the filter that board was left with', () {
    controller().openBoard('zentao:bugs:a:1', selfHandle: 'thanh');
    controller().toggleStatus(UnifiedStatus.blocked);
    controller().openBoard('gitlab:a:9');

    controller().openBoard('zentao:bugs:a:1', selfHandle: 'thanh');

    expect(filter().assignees, {'thanh'});
    expect(filter().statuses, {UnifiedStatus.blocked});
  });

  test('re-selecting the open board keeps its filter', () {
    controller().openBoard('zentao:bugs:a:1', selfHandle: 'thanh');
    controller().clearAll();

    controller().openBoard('zentao:bugs:a:1', selfHandle: 'thanh');

    expect(filter().hasActiveFilters, isFalse);
  });

  test('applying a preset replaces the criteria but keeps the workspace', () {
    controller().setWorkspace('ws-1');
    controller().openBoard('zentao:bugs:a:1', selfHandle: 'thanh');

    controller().applyPreset(
      const FilterState(statuses: {UnifiedStatus.review}),
    );

    expect(filter().workspaceId, 'ws-1');
    expect(filter().statuses, {UnifiedStatus.review});
    expect(filter().assignees, isEmpty);
  });
}
