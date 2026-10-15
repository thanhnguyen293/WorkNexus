import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/tools/gitlab/presentation/util/template_runs.dart';

void main() {
  test('splits text around placeholders in message order', () {
    final runs = templateRuns(
      (m) => '${m[0]} requested to merge ${m[1]} into ${m[2]}',
      3,
    );
    expect(runs.map((r) => r.slot), [0, null, 1, null, 2]);
    expect(runs[1].text, ' requested to merge ');
    expect(runs[3].text, ' into ');
  });

  test('follows a translation that reorders the placeholders', () {
    final runs = templateRuns((m) => '${m[1]} đã merge ${m[0]}', 2);
    expect(runs.map((r) => r.slot), [1, null, 0]);
  });

  test('keeps a message with no placeholders whole', () {
    expect(templateRuns((_) => 'Merged', 0), [(text: 'Merged', slot: null)]);
  });
}
