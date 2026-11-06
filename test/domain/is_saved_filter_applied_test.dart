import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/shared/board/domain/entities/filter_state.dart';
import 'package:work_nexus/shared/board/domain/usecases/is_saved_filter_applied.dart';
import 'package:work_nexus/shared/board/domain/value_objects/saved_filter.dart';
import 'package:work_nexus/shared/board/domain/value_objects/saved_view.dart';

/// Whether a saved filter's chip shows as the one in effect.
void main() {
  const applied = IsSavedFilterApplied();
  SavedFilter preset(FilterState filter) => SavedFilter(
    id: 'sf-1',
    name: 'MyTeam',
    filter: filter,
    createdAt: DateTime(2026),
  );
  final myTeam = preset(
    const FilterState(assignees: {'thanh', 'an'}, severities: {1}),
  );

  test('the filter it applied matches it', () {
    expect(
      applied(
        myTeam,
        const FilterState(assignees: {'an', 'thanh'}, severities: {1}),
      ),
      isTrue,
    );
  });

  test('a chip changed afterwards no longer matches', () {
    expect(
      applied(
        myTeam,
        const FilterState(assignees: {'thanh', 'an'}, severities: {1, 2}),
      ),
      isFalse,
    );
    expect(
      applied(myTeam, const FilterState(assignees: {'thanh'}, severities: {1})),
      isFalse,
    );
    expect(applied(myTeam, const FilterState()), isFalse);
  });

  test('a preset saved on All matches on any view tab', () {
    expect(
      applied(
        myTeam,
        const FilterState(
          assignees: {'thanh', 'an'},
          severities: {1},
          savedView: SavedView.related,
        ),
      ),
      isTrue,
    );
  });

  test('a preset saved on another view needs that view', () {
    final related = preset(const FilterState(savedView: SavedView.related));
    expect(
      applied(related, const FilterState(savedView: SavedView.related)),
      isTrue,
    );
    expect(applied(related, const FilterState()), isFalse);
  });

  test('the board workspace never counts', () {
    expect(
      applied(
        myTeam,
        const FilterState(
          workspaceId: 'ws-2',
          assignees: {'thanh', 'an'},
          severities: {1},
        ),
      ),
      isTrue,
    );
  });

  test('a search over a preset saved without one still matches', () {
    expect(
      applied(
        myTeam,
        const FilterState(
          assignees: {'thanh', 'an'},
          severities: {1},
          search: 'login',
        ),
      ),
      isTrue,
    );
  });

  test('a module picked over a preset saved without one still matches', () {
    expect(
      applied(
        myTeam,
        const FilterState(
          assignees: {'thanh', 'an'},
          severities: {1},
          modules: {'12'},
        ),
      ),
      isTrue,
    );
    final inFeed = preset(const FilterState(modules: {'12'}));
    expect(applied(inFeed, const FilterState(modules: {'13'})), isFalse);
  });

  test('a preset saved with a search needs that search', () {
    final withSearch = preset(const FilterState(search: 'login'));
    expect(applied(withSearch, const FilterState(search: 'login')), isTrue);
    expect(applied(withSearch, const FilterState()), isFalse);
  });
}
