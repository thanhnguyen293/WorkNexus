import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/task_detail/presentation/util/bug_description_sections.dart';

void main() {
  test('splits HTML at its heading blocks, keeping each run as HTML', () {
    final sections = splitBugDescription(
      '<div><p>Env: prod</p><p>【步骤】</p><p>Open <b>app</b></p>'
      '<p>Actual result:</p><p><img src="/file-read-1.png"></p></div>',
      html: true,
    );

    expect(sections.map((s) => s.kind), [
      BugSectionKind.intro,
      BugSectionKind.steps,
      BugSectionKind.actual,
    ]);
    expect(sections[1].text, '<p>Open <b>app</b></p>');
    // An image alone is content.
    expect(sections[2].text, contains('<img'));
  });

  test('a heading inside a paragraph of text is not split off', () {
    final sections = splitBugDescription(
      '<p>Steps: open the app</p>',
      html: true,
    );

    expect(sections.single.kind, BugSectionKind.intro);
  });

  test('splits Markdown at heading lines and honours localised labels', () {
    final sections = splitBugDescription(
      'Intro\n**Kết quả thực tế:**\nCrash\n## Mong muốn\nNo crash',
      html: false,
      labels: {'Mong muốn': BugSectionKind.expected},
    );

    expect(sections.map((s) => (s.kind, s.text)), [
      (BugSectionKind.intro, 'Intro'),
      (BugSectionKind.actual, 'Crash'),
      (BugSectionKind.expected, 'No crash'),
    ]);
  });
}
