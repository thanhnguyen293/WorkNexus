import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/domain/usecases/apply_markdown_format.dart';
import 'package:work_nexus/features/chat/domain/value_objects/markdown_format.dart';

void main() {
  const apply = ApplyMarkdownFormat();

  MarkdownEdit sel(String text, int start, [int? end]) =>
      (text: text, start: start, end: end ?? start);

  group('inline styles', () {
    test('wrap the selection and keep it on the words', () {
      expect(apply(sel('say hi now', 4, 6), MarkdownFormat.bold), (
        text: 'say **hi** now',
        start: 6,
        end: 8,
      ));
      expect(
        apply(sel('hi', 0, 2), MarkdownFormat.underline).text,
        '<u>hi</u>',
      );
      expect(apply(sel('hi', 0, 2), MarkdownFormat.code).text, '`hi`');
    });

    test('drop an empty pair at the caret, the caret inside', () {
      expect(apply(sel('a ', 2), MarkdownFormat.strikethrough), (
        text: 'a ~~~~',
        start: 4,
        end: 4,
      ));
    });

    test('unwrap what is already wrapped', () {
      expect(apply(sel('say **hi** now', 6, 8), MarkdownFormat.bold), (
        text: 'say hi now',
        start: 4,
        end: 6,
      ));
    });
  });

  group('line styles', () {
    test('a bullet list marks every touched line', () {
      expect(apply(sel('one\ntwo\nthree', 1, 5), MarkdownFormat.bulletList), (
        text: '- one\n- two\nthree',
        start: 0,
        end: 11,
      ));
    });

    test('a numbered list counts, and comes off when all have it', () {
      final on = apply(sel('a\nb', 0, 3), MarkdownFormat.numberedList);
      expect(on.text, '1. a\n2. b');
      expect(apply(on, MarkdownFormat.numberedList).text, 'a\nb');
    });

    test('another marker is replaced, the indent kept', () {
      expect(
        apply(sel('  - item', 4), MarkdownFormat.numberedList).text,
        '  1. item',
      );
    });

    test('a caret on one line stays put as the prefix changes', () {
      expect(apply(sel('x\nhello', 4), MarkdownFormat.heading), (
        text: 'x\n# hello',
        start: 6,
        end: 6,
      ));
    });

    test('indent and outdent move lines by two spaces', () {
      final indented = apply(sel('a\nb', 0, 3), MarkdownFormat.indent);
      expect(indented.text, '  a\n  b');
      expect(apply(indented, MarkdownFormat.outdent).text, 'a\nb');
    });
  });

  test('clear strips inline and block markers', () {
    const text = '> **bold** and <u>u</u> ~~s~~ `c` *i*';
    expect(
      apply(sel(text, 0, text.length), MarkdownFormat.clear).text,
      'bold and u s c i',
    );
  });
}
