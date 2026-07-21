import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/sync/data/sync_service.dart';

void main() {
  group('mergeDetailLabels', () {
    test('preserves synthetic product label the detail fetch omits', () {
      // Regression: opening a product-board bug's detail must not drop it from
      // the board. The detail endpoint returns no `zentao-product:` label.
      final merged = mergeDetailLabels(
        ['resolution:fixed'], // from the detail normalize
        ['resolution:open', 'zentao-product:4'], // stored (list sync)
      );

      expect(merged, contains('zentao-product:4'));
      expect(merged, contains('resolution:fixed'));
    });

    test('preserves synthetic execution label the detail fetch omits', () {
      // A task opened from an execution board must not drop off the board when
      // its detail (which carries no `zentao-execution:` label) is fetched.
      final merged = mergeDetailLabels(
        ['status:doing'],
        ['status:wait', 'zentao-execution:12'],
      );

      expect(merged, contains('zentao-execution:12'));
      expect(merged, contains('status:doing'));
    });

    test('does not duplicate a synthetic label already present', () {
      final merged = mergeDetailLabels(
        ['zentao-product:4', 'bug'],
        ['zentao-product:4'],
      );

      expect(merged.where((l) => l == 'zentao-product:4').length, 1);
    });

    test('does not carry over non-synthetic stored labels', () {
      final merged = mergeDetailLabels(
        ['fresh'],
        ['stale-keyword', 'zentao-product:9'],
      );

      expect(merged, ['fresh', 'zentao-product:9']);
    });

    test('empty stored labels leaves the detail labels untouched', () {
      expect(mergeDetailLabels(['a', 'b'], const []), ['a', 'b']);
    });

    test('unions membership markers from different sync paths', () {
      // Offline-first regression: an MR that is both in a viewed project and
      // assigned to me is written by two syncs; re-upserting one path's labels
      // must not drop the other path's marker (else it vanishes from one board
      // offline). Here the project sync re-writes a ticket already tagged mine.
      final merged = mergeDetailLabels(
        ['gitlab-project:42'], // this sync's fresh labels
        ['gitlab-mine:acc', 'gitlab-project:42'], // stored by both paths
      );

      expect(merged, containsAll(['gitlab-project:42', 'gitlab-mine:acc']));
    });
  });
}
