import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/util/markdown_normalize.dart';

void main() {
  group('normalizeMarkdown', () {
    test('__bold__ becomes **bold**, snake_case and code stay', () {
      expect(
        normalizeMarkdown('__Ad :)__ and some_var__x `__code__`'),
        '**Ad :)** and some_var__x `__code__`',
      );
    });

    test('reference links and images are inlined, definitions dropped', () {
      const text =
          '![Alt text][id] and [docs][]\n\n'
          '[id]: https://x.dev/cat.jpg  "The Dojocat"\n'
          '[docs]: <https://x.dev/docs>';
      expect(
        normalizeMarkdown(text),
        '![Alt text](https://x.dev/cat.jpg) and [docs](https://x.dev/docs)\n',
      );
    });

    test('link and image titles are dropped', () {
      expect(
        normalizeMarkdown('![Cat](https://x.dev/c.jpg "The Cat") [a](b \'t\')'),
        '![Cat](https://x.dev/c.jpg) [a](b)',
      );
    });

    test('_italic_ and + bullets are rewritten, snake_case stays', () {
      expect(
        normalizeMarkdown('+ _It_ is some_snake_case\n  + nested'),
        '- *It* is some_snake_case\n  - nested',
      );
    });

    test('an empty quote line keeps the quote', () {
      expect(normalizeMarkdown('> one\n>\n> two'), '> one\n>\u00A0\n> two');
    });

    test('footnotes become superscript numbers listed at the end', () {
      const text =
          'One[^first]. Two^[Inline note]. Again[^first].\n\n'
          '[^first]: Footnote **markup**\n\n    and more.\n\nAfter.';
      expect(
        normalizeMarkdown(text),
        'One¹. Two². Again¹.\n\nAfter.\n\n---\n'
        '1. Footnote **markup** and more.\n2. Inline note',
      );
    });

    test('definition lists, containers and abbreviations degrade', () {
      const text =
          'Term 1\n\n:   Definition 1\n  ~ Definition 2\n'
          '*[HTML]: Hyper Text\n::: warning\n*here*\n:::';
      expect(
        normalizeMarkdown(text),
        'Term 1\n\n- Definition 1\n- Definition 2\n> **warning**\n> *here*',
      );
    });

    test('fenced and indented code is left alone', () {
      const text = '```\n__x__\n[id]: https://a\n```\n    __y__';
      expect(normalizeMarkdown(text), text);
    });
  });

  group('hasMarkdownSyntax', () {
    test('plain chat text has none', () {
      for (final text in [
        'cái này trả chung kết quả API hay riêng vậy anh',
        'ok 2*3 = 6, see https://example.com/a_b_c',
        '[@Thanh](@#40) check this',
        'snake_case_name and 5 - 3',
      ]) {
        expect(hasMarkdownSyntax(text), isFalse, reason: text);
      }
    });

    test('Markdown is recognised', () {
      for (final text in [
        '# Title',
        '- item',
        '1. first',
        '> quoted',
        '```\ncode\n```',
        'run `make codegen`',
        '**bold** text',
        '__bold__ text',
        'an *italic* word',
        '~~gone~~',
        '[docs](https://x.dev)',
        '| a | b |',
        '---',
      ]) {
        expect(hasMarkdownSyntax(text), isTrue, reason: text);
      }
    });
  });
}
