/// Markdown helpers around the renderer (gpt_markdown), which covers the
/// common subset of CommonMark/GFM but not every spelling of it.
library;

final _fence = RegExp(r'^\s*(```|~~~)');

/// `[id]: https://… "optional title"` — a reference definition.
final _definition = RegExp(
  r'''^ {0,3}\[([^\]^][^\]]*)\]:\s*<?(\S+?)>?(?:\s+(?:"[^"]*"|'[^']*'|\([^)]*\)))?\s*$''',
);

/// `![alt][id]`, `[text][id]` and the collapsed `[text][]`.
final _reference = RegExp(r'(!?)\[([^\]]*)\]\[([^\]]*)\]');

/// `](url "title")` — a link or image with a title.
final _titled = RegExp(r'''\]\((\S+?)\s+(?:"[^"]*"|'[^']*')\)''');

/// `__bold__`, not touching snake_case words.
final _underscoreBold = RegExp(r'(?<![\w_])__(?=\S)(.+?)(?<=\S)__(?![\w_])');

/// `_italic_`, not touching snake_case words.
final _underscoreItalic = RegExp(
  r'(?<![\w_])_(?=[^\s_])(.+?)(?<=[^\s_])_(?![\w_])',
);

/// A `+` list marker (only `-` and `*` are understood).
final _plusBullet = RegExp(r'^(\s*)\+(\s+)');

/// A blockquote line with nothing after its markers (`>` or `> >`).
final _emptyQuote = RegExp(r'^(\s*(?:>\s*)+)$');

/// `[^id]: text` — a footnote's definition.
final _footnoteDef = RegExp(r'^ {0,3}\[\^([^\]]+)\]:\s*(.*)$');

/// `*[HTML]: Hyper Text Markup Language` — an abbreviation's definition.
final _abbreviation = RegExp(r'^ {0,3}\*\[[^\]]+\]:');

/// `::: warning` / `:::` — a custom container's fences.
final _container = RegExp(r'^ {0,3}:::\s*(\S*)');

/// `:   definition` or `  ~ definition` under a definition list's term.
final _definitionItem = RegExp(r'^ {0,3}(?::|\s~)\s+(\S.*)$');

/// `[^id]` (a footnote reference) or `^[text]` (an inline footnote).
final _footnoteRef = RegExp(r'\[\^([^\]]+)\]|\^\[([^\]]+)\]');

const _superscripts = '⁰¹²³⁴⁵⁶⁷⁸⁹';

/// Footnotes in the order they are first referenced.
class _Footnotes {
  _Footnotes(this.texts);

  /// Definitions by lower-cased id.
  final Map<String, String> texts;
  final List<String> order = [];
  final Map<String, int> numbers = {};

  /// The marker for footnote [id] (or for an inline one's [text]).
  String mark({String? id, String? text}) {
    final key = id?.toLowerCase() ?? '\u0000${order.length}';
    if (text != null) texts[key] = text;
    final n = numbers[key] ??= (order..add(key)).length;
    return [for (final d in '$n'.split('')) _superscripts[int.parse(d)]].join();
  }

  /// The footnotes, listed under a rule, to end the text with.
  String get section => [
    '---',
    for (final (i, key) in order.indexed)
      if (texts[key] case final text?) '${i + 1}. $text',
  ].join('\n');
}

/// Rewrites the Markdown spellings the renderer does not understand into
/// ones it does: reference-style links and images are inlined, link titles
/// dropped, `__bold__`/`_italic_` become `**bold**`/`*italic*`, `+` bullets
/// become `-`, and an empty blockquote line keeps its quote instead of
/// showing a stray `>`. Common markdown-it extensions degrade gracefully:
/// footnotes become superscript numbers listed at the end, definition-list
/// items become bullets, custom containers become quotes and abbreviation
/// definitions are dropped. Code (fenced or inline) is left alone.
String normalizeMarkdown(String text) {
  final refs = <String, String>{};
  final notes = <String, String>{};
  final kept = <String>[];
  var inFence = false;
  var inContainer = false;
  String? note;
  for (final line in text.split('\n')) {
    if (_fence.hasMatch(line)) inFence = !inFence;
    if (inFence) {
      kept.add(inContainer ? '> $line' : line);
      continue;
    }
    // A footnote runs on over indented (or blank) lines.
    if (note != null && (line.trim().isEmpty || line.startsWith('  '))) {
      if (line.trim().isNotEmpty) notes[note] = '${notes[note]} ${line.trim()}';
      continue;
    }
    // Keeps the next block apart from the one before the footnote.
    if (note != null && kept.lastOrNull?.trim().isNotEmpty == true) {
      kept.add('');
    }
    note = null;
    if (_definition.firstMatch(line) case final def?) {
      refs[def[1]!.toLowerCase()] = def[2]!;
    } else if (_footnoteDef.firstMatch(line) case final def?) {
      note = def[1]!.toLowerCase();
      notes[note] = def[2]!;
    } else if (_abbreviation.hasMatch(line)) {
      continue;
    } else if (_container.firstMatch(line) case final fence?) {
      inContainer = fence[1]!.isNotEmpty;
      if (inContainer) kept.add('> **${fence[1]}**');
    } else if (_definitionItem.firstMatch(line) case final item?) {
      kept.add('- ${item[1]}');
    } else {
      kept.add(inContainer ? '> $line' : line);
    }
  }
  final footnotes = _Footnotes(notes);
  inFence = false;
  final out = <String>[];
  for (final line in kept) {
    final fence = _fence.hasMatch(line);
    if (fence) inFence = !inFence;
    final code =
        fence || inFence || line.startsWith('    ') || line.startsWith('\t');
    out.add(code ? line : _normalizeLine(line, refs, footnotes));
  }
  if (footnotes.order.isNotEmpty) out.addAll(['', footnotes.section]);
  return out.join('\n');
}

String _normalizeLine(
  String line,
  Map<String, String> refs,
  _Footnotes footnotes,
) {
  final quote = _emptyQuote.firstMatch(line);
  // A no-break space gives the line content, so it stays a quoted blank.
  if (quote != null) return '${quote[1]}\u00A0';
  // Odd parts are inline code spans: left as they are.
  final parts = line
      .replaceFirstMapped(_plusBullet, (m) => '${m[1]}-${m[2]}')
      .split('`');
  for (var i = 0; i < parts.length; i += 2) {
    parts[i] = parts[i]
        .replaceAllMapped(_reference, (m) {
          final id = (m[3]!.isEmpty ? m[2]! : m[3]!).toLowerCase();
          final url = refs[id];
          return url == null ? m[0]! : '${m[1]}[${m[2]}]($url)';
        })
        .replaceAllMapped(
          _footnoteRef,
          (m) => footnotes.mark(id: m[1], text: m[2]),
        )
        .replaceAllMapped(_titled, (m) => '](${m[1]})')
        .replaceAllMapped(_underscoreBold, (m) => '**${m[1]}**')
        .replaceAllMapped(_underscoreItalic, (m) => '*${m[1]}*');
  }
  return parts.join('`');
}

final _markdownSyntax = RegExp(
  [
    r'^\s{0,3}#{1,6}\s', // heading
    r'^\s*(?:[-*+]|\d+[.)])\s+\S', // list item
    r'^\s{0,3}>', // blockquote
    r'^\s*(```|~~~)', // code fence
    r'^\s{0,3}(?:-{3,}|\*{3,}|_{3,})\s*$', // horizontal rule
    r'^\s*\|.*\|', // table row
    r'`[^`\n]+`', // inline code
    r'\*\*\S|\S\*\*|(?<![\w_])__\S', // bold
    r'(?:^|[\s(])[*_][^\s*_][^\n]*[*_](?=$|[\s.,!?)])', // italic
    r'~~\S', // strikethrough
    r'!?\[[^\]\n]*\]\((?!@#)[^)\s]+', // link or image (not a chat mention)
    r'!?\[[^\]\n]*\]\[[^\]\n]*\]', // reference link or image
  ].join('|'),
  multiLine: true,
);

/// Whether [text] uses any Markdown syntax — when not, it can be shown as
/// plain text, which is far cheaper to lay out than the Markdown renderer.
bool hasMarkdownSyntax(String text) => _markdownSyntax.hasMatch(text);
