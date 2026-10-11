import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/domain/usecases/tidy_markdown_emphasis.dart';

void main() {
  const tidy = TidyMarkdownEmphasis();

  test('trailing space moves outside the markers', () {
    expect(tidy('**ssda **'), '**ssda** ');
    expect(tidy('a *b  * c'), 'a *b*   c');
    expect(tidy('~~x ~~ <u>y </u>'), '~~x~~  <u>y</u> ');
  });

  test('well-formed and plain text are left alone', () {
    expect(tidy('**bold** and *it*'), '**bold** and *it*');
    expect(tidy('2 * 3 * 4'), '2 * 3 * 4');
    expect(tidy('**'), '**');
  });
}
