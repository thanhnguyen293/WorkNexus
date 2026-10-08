import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/database/database.dart';
import 'package:work_nexus/core/di/service_locator.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/features/board/data/mappers/saved_filter_mapper.dart';
import 'package:work_nexus/features/board/domain/entities/filter_state.dart';
import 'package:work_nexus/features/board/domain/repositories/saved_filter_repository.dart';
import 'package:work_nexus/features/board/domain/value_objects/saved_filter.dart';
import 'package:work_nexus/features/board/domain/value_objects/saved_view.dart';

import '../support/di_test_harness.dart';

void main() {
  group('filter state codec', () {
    test('round-trips every criterion', () {
      const filter = FilterState(
        savedView: SavedView.review,
        providers: {ProviderType.zentao, ProviderType.gitlab},
        accountIds: {'acc-1'},
        projectIds: {'proj-1', 'proj-2'},
        statuses: {UnifiedStatus.blocked, UnifiedStatus.review},
        priorities: {Priority.urgent},
        severities: {1, 3},
        assignees: {'thanh', ''},
        reviewers: {'lan'},
        bugTypes: {'codeerror'},
        resolutions: {'fixed'},
        search: 'login',
      );

      expect(decodeFilterState(encodeFilterState(filter)), filter);
    });

    test('workspace scope is not part of a preset', () {
      const filter = FilterState(workspaceId: 'ws-9', search: 'x');

      expect(decodeFilterState(encodeFilterState(filter)).workspaceId, 'all');
    });

    test(
      'malformed or unknown values decode to an empty filter, not a crash',
      () {
        expect(decodeFilterState('not json'), const FilterState());
        expect(
          decodeFilterState('{"statuses":["from-the-future"],"providers":42}'),
          const FilterState(),
        );
      },
    );
  });

  group('LocalSavedFilterRepository', () {
    late AppDatabase db;
    late SavedFilterRepository repo;

    setUp(() async {
      db = await setUpTestLocator(seed: false);
      repo = getIt<SavedFilterRepository>();
    });

    tearDown(() async => resetTestLocator(db));

    SavedFilter preset(String id, String name, {int minute = 0}) => SavedFilter(
      id: id,
      name: name,
      filter: FilterState(assignees: {name}),
      createdAt: DateTime(2026, 8, 26, 10, minute),
    );

    test('saves and reads a preset back', () async {
      await repo.upsert(preset('sf-1', 'thanh'));

      final stored = await repo.watchSavedFilters().first;
      expect(stored.single.name, 'thanh');
      expect(stored.single.filter.assignees, {'thanh'});
    });

    test('newest preset comes first', () async {
      await repo.upsert(preset('sf-1', 'older'));
      await repo.upsert(preset('sf-2', 'newer', minute: 5));

      final stored = await repo.watchSavedFilters().first;
      expect(stored.map((f) => f.name), ['newer', 'older']);
    });

    test('re-saving the same id replaces it', () async {
      await repo.upsert(preset('sf-1', 'first'));
      await repo.upsert(preset('sf-1', 'second'));

      final stored = await repo.watchSavedFilters().first;
      expect(stored.single.name, 'second');
    });

    test('delete removes just that preset', () async {
      await repo.upsert(preset('sf-1', 'keep'));
      await repo.upsert(preset('sf-2', 'drop', minute: 5));

      await repo.delete('sf-2');

      final stored = await repo.watchSavedFilters().first;
      expect(stored.map((f) => f.name), ['keep']);
    });
  });
}
