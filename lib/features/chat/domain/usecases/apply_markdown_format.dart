import '../value_objects/markdown_format.dart';

/// Applies a [MarkdownFormat] to the selection, the way a rich-text toolbar
/// would — but as the Markdown the message is sent in.
///
/// Inline styles wrap the selection (or drop markers at the caret) and
/// unwrap it when already wrapped. Line styles (heading, quote, lists)
/// apply to every line the selection touches, and come off when all of
/// them have it already. Underline is `<u>…</u>`: Markdown has none, but
/// the renderer here and the official client both show the tag.
class ApplyMarkdownFormat {
  const ApplyMarkdownFormat();

  static const _indent = '  ';

  /// A line's block prefix: indent, then a heading, quote or list marker.
  static final _prefix = RegExp(r'^( *)(#{1,6} |> |[-*] |\d+\. )?');

  MarkdownEdit call(MarkdownEdit edit, MarkdownFormat format) =>
      switch (format) {
        MarkdownFormat.bold => _inline(edit, '**', '**'),
        MarkdownFormat.italic => _inline(edit, '*', '*'),
        MarkdownFormat.underline => _inline(edit, '<u>', '</u>'),
        MarkdownFormat.strikethrough => _inline(edit, '~~', '~~'),
        MarkdownFormat.code => _inline(edit, '`', '`'),
        MarkdownFormat.heading => _block(edit, (_) => '# '),
        MarkdownFormat.quote => _block(edit, (_) => '> '),
        MarkdownFormat.bulletList => _block(edit, (_) => '- '),
        MarkdownFormat.numberedList => _block(edit, (i) => '${i + 1}. '),
        MarkdownFormat.indent => _lines(edit, (line, _) => '$_indent$line'),
        MarkdownFormat.outdent => _lines(
          edit,
          (line, _) => line.startsWith(_indent)
              ? line.substring(_indent.length)
              : line.trimLeft(),
        ),
        MarkdownFormat.clear => _clear(edit),
      };

  MarkdownEdit _inline(MarkdownEdit edit, String open, String close) {
    final (:text, :start, :end) = edit;
    final wrapped =
        start >= open.length &&
        text.substring(start - open.length, start) == open &&
        text.startsWith(close, end);
    if (wrapped) {
      return (
        text: text
            .replaceRange(end, end + close.length, '')
            .replaceRange(start - open.length, start, ''),
        start: start - open.length,
        end: end - open.length,
      );
    }
    return (
      text: text.replaceRange(
        start,
        end,
        '$open${text.substring(start, end)}$close',
      ),
      start: start + open.length,
      end: end + open.length,
    );
  }

  /// Gives each touched line the marker [marker] (by its index among them),
  /// replacing any other block marker; takes it off if all already have it.
  MarkdownEdit _block(MarkdownEdit edit, String Function(int) marker) {
    final (first, lines) = _touched(edit);
    final has = [
      for (final (i, line) in lines.indexed)
        _prefix.firstMatch(line)?.group(2) == marker(i),
    ];
    final remove = has.every((h) => h);
    return _lines(edit, (line, i) {
      final m = _prefix.firstMatch(line);
      final indent = m?.group(1) ?? '';
      final rest = line.substring(m?.end ?? 0);
      return remove ? '$indent$rest' : '$indent${marker(i)}$rest';
    }, touched: (first, lines));
  }

  /// Strips inline markers inside the selection and block markers off the
  /// touched lines.
  MarkdownEdit _clear(MarkdownEdit edit) {
    final (:text, :start, :end) = edit;
    final inner = text
        .substring(start, end)
        .replaceAll(RegExp(r'\*\*|~~|</?u>|`|\*'), '');
    final cleared = (
      text: text.replaceRange(start, end, inner),
      start: start,
      end: start + inner.length,
    );
    return _lines(cleared, (line, _) {
      final m = _prefix.firstMatch(line);
      return '${m?.group(1) ?? ''}${line.substring(m?.end ?? 0)}';
    });
  }

  /// The offset of the first line the selection touches, and those lines.
  (int, List<String>) _touched(MarkdownEdit edit) {
    final (:text, :start, :end) = edit;
    final first = start == 0 ? 0 : text.lastIndexOf('\n', start - 1) + 1;
    final stop = text.indexOf('\n', end);
    final last = stop < 0 ? text.length : stop;
    return (first, text.substring(first, last).split('\n'));
  }

  /// Rewrites each touched line with [map]; the selection then covers them.
  MarkdownEdit _lines(
    MarkdownEdit edit,
    String Function(String line, int index) map, {
    (int, List<String>)? touched,
  }) {
    final (first, lines) = touched ?? _touched(edit);
    final before = lines.join('\n');
    final after = [for (final (i, line) in lines.indexed) map(line, i)];
    final joined = after.join('\n');
    final text = edit.text.replaceRange(first, first + before.length, joined);
    // A caret on one line stays at its spot, shifted by the prefix change.
    if (edit.start == edit.end && lines.length == 1) {
      final at = (edit.start + joined.length - before.length).clamp(
        first,
        first + joined.length,
      );
      return (text: text, start: at, end: at);
    }
    return (text: text, start: first, end: first + joined.length);
  }
}
