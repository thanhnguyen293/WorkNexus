import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/value_objects/repo_change.dart';

void main() {
  test('countDiffLines counts +/- lines, ignoring the +++/--- headers', () {
    const diff = '''
--- a/lib/foo.dart
+++ b/lib/foo.dart
@@ -1,3 +1,4 @@
 unchanged
-removed line
+added one
+added two
''';
    final counts = countDiffLines(diff);
    expect(counts.additions, 2);
    expect(counts.deletions, 1);
  });

  test('countDiffLines is zero for null/empty', () {
    expect(countDiffLines(null), (additions: 0, deletions: 0));
    expect(countDiffLines(''), (additions: 0, deletions: 0));
  });
}
