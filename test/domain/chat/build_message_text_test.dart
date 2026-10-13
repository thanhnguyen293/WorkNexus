import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/domain/usecases/build_message_text.dart';

void main() {
  const build = BuildMessageText();

  Map<String, dynamic> text(String s, [Map<String, dynamic>? attrs]) => {
    'insert': s,
    'attributes': ?attrs,
  };
  Map<String, dynamic> mention(int id, String name) => {
    'insert': {
      'mention': {'id': id, 'name': name},
    },
  };
  String md(List<Map<String, dynamic>> ops) => build(ops, markdown: true);

  group('plain', () {
    test('writes text and mentions, drops formatting', () {
      final ops = [
        text('hi '),
        mention(41, 'Dyno'),
        text(' see ', {'bold': true}),
        text('\n'),
      ];
      expect(build(ops, markdown: false), 'hi [@Dyno](@#41) see ');
    });

    test('drops trailing blank lines', () {
      expect(build([text('a\n\n  \n')], markdown: false), 'a');
    });
  });

  group('markdown inline', () {
    test('wraps formatted text in its markers', () {
      expect(
        md([
          text('say '),
          text('hi', {'bold': true}),
          text(' and '),
          text('bye', {'italic': true}),
          text(' '),
          text('u', {'underline': true}),
          text(' '),
          text('s', {'strike': true}),
          text('\n'),
        ]),
        'say **hi** and *bye* <u>u</u> ~~s~~',
      );
    });

    test('nests overlapping formats without closing and reopening', () {
      expect(
        md([
          text('a', {'bold': true}),
          text('b', {'bold': true, 'italic': true}),
          text('c', {'bold': true}),
          text('\n'),
        ]),
        '**a*b*c**',
      );
    });

    test('moves edge whitespace out of emphasis', () {
      expect(
        md([
          text('word ', {'bold': true}),
          text('next\n'),
        ]),
        '**word** next',
      );
      expect(
        md([
          text('a', {'bold': true}),
          text(' ', {'bold': true}),
          text('b', {'bold': true}),
          text('\n'),
        ]),
        '**a b**',
      );
    });

    test('code gets a fence longer than its backticks', () {
      expect(
        md([
          text('x', {'code': true}),
          text('\n'),
        ]),
        '`x`',
      );
      expect(
        md([
          text('a`b', {'code': true}),
          text('\n'),
        ]),
        '``a`b``',
      );
      expect(
        md([
          text('`a', {'code': true}),
          text('\n'),
        ]),
        '`` `a ``',
      );
    });

    test('links and mentions', () {
      expect(
        md([
          text('docs', {'link': 'https://x.dev'}),
          text(' '),
          mention(7, 'An Nguyen'),
          text('\n'),
        ]),
        '[docs](https://x.dev) [@An Nguyen](@#7)',
      );
    });

    test('typed Markdown passes through', () {
      expect(md([text('**as typed**\n')]), '**as typed**');
    });
  });

  group('markdown blocks', () {
    test('headings and quotes', () {
      expect(
        md([
          text('Title'),
          text('\n', {'header': 2}),
          text('quoted'),
          text('\n', {'blockquote': true}),
          text('after\n'),
        ]),
        '## Title\n> quoted\n\nafter',
      );
    });

    test('numbers ordered lists and nests by the parent marker', () {
      expect(
        md([
          text('one'),
          text('\n', {'list': 'ordered'}),
          text('sub'),
          text('\n', {'list': 'bullet', 'indent': 1}),
          text('two'),
          text('\n', {'list': 'ordered'}),
          text('done'),
          text('\n', {'list': 'checked'}),
        ]),
        '1. one\n   - sub\n2. two\n- [x] done',
      );
    });

    test('a paragraph restarts list numbering', () {
      expect(
        md([
          text('a'),
          text('\n', {'list': 'ordered'}),
          text('mid\n'),
          text('b'),
          text('\n', {'list': 'ordered'}),
        ]),
        '1. a\n\nmid\n1. b',
      );
    });

    test('fences code blocks and keeps their text raw', () {
      expect(
        md([
          text('see\n'),
          text('a **b**'),
          text('\n', {'code-block': true}),
          text('c'),
          text('\n', {'code-block': true}),
        ]),
        'see\n```\na **b**\nc\n```',
      );
    });
  });
}
