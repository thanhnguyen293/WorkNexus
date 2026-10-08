import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/features/board/domain/entities/filter_state.dart';
import 'package:work_nexus/features/board/domain/usecases/build_saved_filter.dart';
import 'package:work_nexus/features/board/domain/value_objects/saved_filter.dart';

void main() {
  const useCase = BuildSavedFilter();
  const filter = FilterState(priorities: {Priority.urgent});
  final now = DateTime(2026, 8, 26, 10);

  test('builds a preset with the trimmed name', () {
    final preset = useCase(
      name: '  Urgent only  ',
      filter: filter,
      existing: const [],
      now: now,
    );

    expect(preset?.name, 'Urgent only');
    expect(preset?.filter, filter);
    expect(preset?.createdAt, now);
  });

  test('a blank name yields nothing to save', () {
    expect(
      useCase(name: '   ', filter: filter, existing: const [], now: now),
      isNull,
    );
  });

  test(
    'reusing a name (any case) overwrites that preset instead of adding one',
    () {
      final existing = SavedFilter(
        id: 'sf-1',
        name: 'Urgent only',
        filter: const FilterState(),
        createdAt: DateTime(2026),
      );

      final preset = useCase(
        name: 'URGENT ONLY',
        filter: filter,
        existing: [existing],
        now: now,
      );

      expect(preset?.id, 'sf-1');
      expect(preset?.filter, filter);
    },
  );

  test('a new name gets its own id', () {
    final existing = SavedFilter(
      id: 'sf-1',
      name: 'Urgent only',
      filter: const FilterState(),
      createdAt: DateTime(2026),
    );

    final preset = useCase(
      name: 'Blocked',
      filter: filter,
      existing: [existing],
      now: now,
    );

    expect(preset?.id, isNot('sf-1'));
  });
}
