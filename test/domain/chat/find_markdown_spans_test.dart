import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/domain/usecases/find_markdown_spans.dart';

void main() {
  const find = FindMarkdownSpans();

  Set<(int, int, MarkdownSpanStyle)> spans(String text) => {
    for (final s in find(text)) (s.start, s.end, s.style),
  };

  test('bold: hidden syntax around bold content', () {
    expect(spans('ab**cd**'), {
      (2, 4, MarkdownSpanStyle.syntax),
      (4, 6, MarkdownSpanStyle.bold),
      (6, 8, MarkdownSpanStyle.syntax),
    });
  });

  test('italic is not mistaken inside bold markers', () {
    expect(spans('**b** *i*').where((s) => s.$3 == MarkdownSpanStyle.italic), {
      (7, 8, MarkdownSpanStyle.italic),
    });
  });

  test('strikethrough, underline and code', () {
    final found = spans('~~s~~ <u>u</u> `c`');
    expect(found, contains((2, 3, MarkdownSpanStyle.strikethrough)));
    expect(found, contains((9, 10, MarkdownSpanStyle.underline)));
    expect(found, contains((16, 17, MarkdownSpanStyle.code)));
  });

  test('an unclosed marker styles nothing', () {
    expect(spans('ab**cd'), isEmpty);
  });

  test('line markers: heading, quote and lists', () {
    final found = spans('# Title\n> said\n  - item\n2. two');
    expect(found, contains((0, 2, MarkdownSpanStyle.syntax)));
    expect(found, contains((2, 7, MarkdownSpanStyle.heading)));
    expect(found, contains((8, 10, MarkdownSpanStyle.marker)));
    expect(found, contains((10, 14, MarkdownSpanStyle.quote)));
    expect(found, contains((17, 19, MarkdownSpanStyle.marker)));
    expect(found, contains((24, 27, MarkdownSpanStyle.marker)));
  });

  test('an empty pair is hidden only with the caret in its middle', () {
    expect(find('a ****', caret: 4).map((s) => (s.start, s.end, s.style)), [
      (2, 4, MarkdownSpanStyle.syntax),
      (4, 6, MarkdownSpanStyle.syntax),
    ]);
    expect(find('<u></u>', caret: 3), hasLength(2));
    expect(find('a ****', caret: 6), isEmpty);
    expect(find('a **'), isEmpty);
  });

  test('emphasis being typed (ending in a space) is still styled', () {
    expect(spans('**ssda **'), contains((2, 7, MarkdownSpanStyle.bold)));
    expect(spans('a * b *'), isEmpty);
  });
}
