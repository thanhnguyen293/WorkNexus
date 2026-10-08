import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/features/board/domain/entities/filter_state.dart';
import 'package:work_nexus/features/board/domain/usecases/switch_board_filter.dart';

void main() {
  const useCase = SwitchBoardFilter();
  const mine = FilterState(assignees: {'thanh'});
  const blocked = FilterState(statuses: {UnifiedStatus.blocked});

  test('a board seen for the first time opens with the default filter', () {
    final result = useCase(
      memory: const {},
      fromKey: null,
      toKey: 'zentao:bugs:a:1',
      current: const FilterState(),
      initial: mine,
    );

    expect(result.filter, mine);
  });

  test('leaving a board files its filter under that board key', () {
    final result = useCase(
      memory: const {},
      fromKey: 'zentao:bugs:a:1',
      toKey: 'gitlab:a:9',
      current: blocked,
      initial: const FilterState(),
    );

    expect(result.memory['zentao:bugs:a:1'], blocked);
    expect(result.filter, const FilterState());
  });

  test('returning to a board restores the filter it was left with', () {
    final left = useCase(
      memory: const {},
      fromKey: 'zentao:bugs:a:1',
      toKey: 'gitlab:a:9',
      current: blocked,
      initial: const FilterState(),
    );

    final back = useCase(
      memory: left.memory,
      fromKey: 'gitlab:a:9',
      toKey: 'zentao:bugs:a:1',
      current: left.filter,
      // The default would be "my tickets" — the remembered filter wins.
      initial: mine,
    );

    expect(back.filter, blocked);
  });

  test('re-selecting the board you are on keeps the filter untouched', () {
    final result = useCase(
      memory: const {},
      fromKey: 'zentao:bugs:a:1',
      toKey: 'zentao:bugs:a:1',
      current: blocked,
      initial: mine,
    );

    expect(result.filter, blocked);
  });

  test('the caller-supplied memory is not mutated in place', () {
    final memory = <String, FilterState>{};
    useCase(
      memory: memory,
      fromKey: 'a',
      toKey: 'b',
      current: blocked,
      initial: const FilterState(),
    );

    expect(memory, isEmpty);
  });
}
