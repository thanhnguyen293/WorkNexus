import 'tidy_markdown_emphasis.dart';

/// How a stretch of Markdown source looks while it is being typed.
enum MarkdownSpanStyle {
  bold,
  italic,
  underline,
  strikethrough,
  code,
  heading,
  quote,

  /// A line's list or quote marker (`- `, `1. `, `> `), shown faint.
  marker,

  /// Inline and heading syntax (`**`, `*`, `~~`, `` ` ``, `<u>`, `# `),
  /// hidden so only its effect shows.
  syntax,
}

/// [style] applies to the text from [start] to [end].
typedef MarkdownSpan = ({int start, int end, MarkdownSpanStyle style});

/// Finds what each part of Markdown source shows as, so the composer can
/// draw it styled as it is typed. The patterns follow what the message
/// renderer understands; each stays within one line.
class FindMarkdownSpans {
  const FindMarkdownSpans();

  /// Inline styles: open marker, content, close marker. Content may end in
  /// whitespace — a word is being typed after it; [TidyMarkdownEmphasis]
  /// moves that space outside the markers when the message is sent.
  static final _inline = <(RegExp, MarkdownSpanStyle)>[
    (RegExp(r'(?<!`)(`)([^`\n]+)(`)(?!`)'), MarkdownSpanStyle.code),
    (RegExp(r'(\*\*)(?!\s)([^\n]+?)(\*\*)'), MarkdownSpanStyle.bold),
    (
      RegExp(r'(?<!\*)(\*)(?![\s*])([^\n]+?)(?<!\*)(\*)(?!\*)'),
      MarkdownSpanStyle.italic,
    ),
    (RegExp(r'(~~)(?!\s)([^\n]+?)(~~)'), MarkdownSpanStyle.strikethrough),
    (RegExp(r'(<u>)([^\n]+?)(</u>)'), MarkdownSpanStyle.underline),
  ];

  /// Line styles: marker, then the rest of the line (styled, if any).
  static final _block = <(RegExp, MarkdownSpanStyle?)>[
    (RegExp(r'^ *(#{1,6} )(.*)$', multiLine: true), MarkdownSpanStyle.heading),
    (RegExp(r'^ *(> )(.*)$', multiLine: true), MarkdownSpanStyle.quote),
    (RegExp(r'^ *([-*] |\d+\. )(.*)$', multiLine: true), null),
  ];

  /// Empty inline pairs, longest first so `****` reads as bold, not two
  /// italics.
  static const _pairs = [
    ('**', '**'),
    ('~~', '~~'),
    ('<u>', '</u>'),
    ('*', '*'),
    ('`', '`'),
  ];

  /// With [caret] in the middle of an empty pair (`**|**`, as the toolbar
  /// leaves it), that pair is syntax too: what is typed there shows styled
  /// right away.
  List<MarkdownSpan> call(String text, {int? caret}) {
    final spans = <MarkdownSpan>[];
    void add(int start, int end, MarkdownSpanStyle style) {
      if (end > start) spans.add((start: start, end: end, style: style));
    }

    for (final (pattern, style) in _block) {
      for (final m in pattern.allMatches(text)) {
        final markerEnd = m.start + m[0]!.indexOf(m[1]!) + m[1]!.length;
        add(
          markerEnd - m[1]!.length,
          markerEnd,
          style == MarkdownSpanStyle.heading
              ? MarkdownSpanStyle.syntax
              : MarkdownSpanStyle.marker,
        );
        if (style != null) add(markerEnd, m.end, style);
      }
    }
    for (final (pattern, style) in _inline) {
      for (final m in pattern.allMatches(text)) {
        final open = m[1]!.length;
        final close = m[3]!.length;
        add(m.start, m.start + open, MarkdownSpanStyle.syntax);
        add(m.start + open, m.end - close, style);
        add(m.end - close, m.end, MarkdownSpanStyle.syntax);
      }
    }
    if (caret != null) {
      for (final (open, close) in _pairs) {
        final from = caret - open.length;
        final to = caret + close.length;
        if (from >= 0 &&
            text.startsWith(open, from) &&
            text.startsWith(close, caret) &&
            // Not part of styled text already (`**|b**` is no empty `*|*`).
            !spans.any((s) => s.start < to && from < s.end)) {
          add(from, caret, MarkdownSpanStyle.syntax);
          add(caret, to, MarkdownSpanStyle.syntax);
          break;
        }
      }
    }
    return spans;
  }
}
