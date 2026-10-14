/// Writes what was typed in the composer — rich-text operations in Quill's
/// Delta JSON (`{insert, attributes}`) — as the text of a message.
///
/// A mention is an embed, `{insert: {mention: {id, name}}}`, written as xxd's
/// mention markup `[@Name](@#id)`, which every client renders as a mention
/// and uses to notify that user.
///
/// With `markdown` on, formatting is written as Markdown: bold `**`, italic
/// `*`, underline `<u>`, strikethrough `~~`, inline code, links, headings,
/// quotes, lists and code blocks. Text is written as typed, so Markdown
/// typed by hand still works. Off, only the text and mentions are written.
class BuildMessageText {
  const BuildMessageText();

  String call(List<Map<String, dynamic>> ops, {required bool markdown}) {
    final lines = _lines(ops);
    while (lines.isNotEmpty && lines.last.isBlank) {
      lines.removeLast();
    }
    if (!markdown) {
      return lines.map((l) => l.runs.map(_plainRun).join()).join('\n');
    }
    return _Markdown(lines).write();
  }

  static String _plainRun(_Run run) => switch (run.data) {
    final String text => text,
    final Map<String, dynamic> embed => _embedText(embed),
    _ => '',
  };
}

/// A mention embed as markup; other embeds have no text.
String _embedText(Map<String, dynamic> embed) {
  if (embed['mention'] case {
    'id': final Object id,
    'name': final Object name,
  }) {
    return '[@$name](@#$id)';
  }
  return '';
}

/// A piece of a line: text or an embed, with its inline attributes.
class _Run {
  _Run(this.data, this.attrs);

  final Object data;
  final Map<String, dynamic> attrs;
}

/// A line of the document with its block attributes (heading, list…).
class _Line {
  _Line(this.runs, this.attrs);

  final List<_Run> runs;
  final Map<String, dynamic> attrs;

  bool get isBlank =>
      runs.every((r) => r.data is String && (r.data as String).trim().isEmpty);

  String? get list => attrs['list'] as String?;
  int get indent => (attrs['indent'] as num?)?.toInt() ?? 0;
  bool get quote => attrs['blockquote'] == true;
  bool get code => attrs['code-block'] != null;
}

/// Splits the operations into lines; a line's attributes ride on the line
/// break that ends it.
List<_Line> _lines(List<Map<String, dynamic>> ops) {
  final lines = <_Line>[];
  var runs = <_Run>[];
  for (final op in ops) {
    final insert = op['insert'];
    final attrs = Map<String, dynamic>.from(
      (op['attributes'] as Map?) ?? const {},
    );
    if (insert is String) {
      final parts = insert.split('\n');
      for (var i = 0; i < parts.length; i++) {
        if (parts[i].isNotEmpty) runs.add(_Run(parts[i], attrs));
        if (i < parts.length - 1) {
          lines.add(_Line(runs, attrs));
          runs = [];
        }
      }
    } else if (insert is Map) {
      runs.add(_Run(Map<String, dynamic>.from(insert), attrs));
    }
  }
  if (runs.isNotEmpty) lines.add(_Line(runs, const {}));
  return lines;
}

/// Inline formatting, outermost first, with its Markdown markers.
const _inline = ['link', 'bold', 'italic', 'underline', 'strike', 'code'];

/// Formatting whose edge whitespace is moved out of its markers: Markdown
/// does not count `**word **` as bold. Code and links keep theirs.
const _emphasis = {'bold', 'italic', 'underline', 'strike'};

class _Markdown {
  _Markdown(this.lines);

  final List<_Line> lines;
  final _out = <String>[];

  /// Width of the list marker last written at each depth, which a nested
  /// item is indented by; and each depth's running number.
  final _markerWidths = <int, int>{};
  final _numbers = <int, int>{};

  String write() {
    _Line? previous;
    var inCode = false;
    for (final line in lines) {
      if (line.code != inCode) {
        _out.add('```');
        inCode = line.code;
      }
      if (inCode) {
        _out.add(line.runs.map(BuildMessageText._plainRun).join());
        previous = line;
        continue;
      }
      // A plain line straight after a list item or quote would be read as
      // part of it: a blank line ends the block.
      if (previous != null &&
          (previous.list != null || previous.quote) &&
          line.list == null &&
          !line.quote &&
          !line.isBlank) {
        _out.add('');
      }
      _out.add('${_prefix(line)}${_inlineText(line.runs)}');
      previous = line;
    }
    if (inCode) _out.add('```');
    return _out.join('\n');
  }

  String _prefix(_Line line) {
    final list = line.list;
    if (list == null) _numbers.clear();
    final buffer = StringBuffer();
    if (line.quote) buffer.write('> ');
    if (list != null) {
      final depth = line.indent;
      for (var d = 0; d < depth; d++) {
        buffer.write(' ' * (_markerWidths[d] ?? 2));
      }
      // A shallower item ends the deeper lists' numbering.
      _numbers.removeWhere((d, _) => d > depth);
      final marker = switch (list) {
        'ordered' => '${_numbers[depth] = (_numbers[depth] ?? 0) + 1}. ',
        'checked' => '- [x] ',
        'unchecked' => '- [ ] ',
        _ => '- ',
      };
      if (list != 'ordered') _numbers.remove(depth);
      _markerWidths[depth] = list == 'ordered' ? marker.length : 2;
      buffer.write(marker);
    } else if (line.indent > 0) {
      buffer.write('  ' * line.indent);
    }
    if (line.attrs['header'] case final num level) {
      buffer.write('${'#' * level.toInt()} ');
    }
    return buffer.toString();
  }

  String _inlineText(List<_Run> runs) {
    final pieces = _mergeRuns(_moveEdgeWhitespace(runs));
    final out = StringBuffer();
    final open = <MapEntry<String, Object?>>[];
    void closeFrom(int i) {
      for (var j = open.length - 1; j >= i; j--) {
        out.write(_closing(open[j]));
      }
      open.removeRange(i, open.length);
    }

    for (final piece in pieces) {
      final wanted = _formats(piece);
      // Keep the open markers this piece still has (in order); close the
      // first that it lacks and everything opened inside it.
      var keep = 0;
      while (keep < open.length &&
          keep < wanted.length &&
          open[keep].key == wanted[keep].key &&
          open[keep].value == wanted[keep].value) {
        keep++;
      }
      closeFrom(keep);
      for (final format in wanted.skip(keep)) {
        out.write(_opening(format));
        open.add(format);
      }
      final data = piece.data;
      if (data is String) {
        out.write(data);
      } else if (data is Map<String, dynamic>) {
        out.write(_embedText(data));
      }
    }
    closeFrom(0);
    return out.toString();
  }

  /// [piece]'s inline formatting, outermost first. Code's value is its
  /// opening fence (see [_codeFence]).
  static List<MapEntry<String, Object?>> _formats(_Run piece) => [
    for (final key in _inline)
      if (piece.attrs[key] case final Object value
          when value != false && value != '')
        MapEntry(key, key == 'code' ? _codeFence(piece.data) : value),
  ];

  static final _backticks = RegExp('`+');

  /// A fence longer than any backtick run in [data], padded with a space
  /// when the code starts or ends with a backtick.
  static String _codeFence(Object data) {
    if (data is! String) return '`';
    var longest = 0;
    for (final m in _backticks.allMatches(data)) {
      if (m[0]!.length > longest) longest = m[0]!.length;
    }
    final pad = data.startsWith('`') || data.endsWith('`') ? ' ' : '';
    return '${'`' * (longest + 1)}$pad';
  }

  static String _opening(MapEntry<String, Object?> format) =>
      switch (format.key) {
        'link' => '[',
        'bold' => '**',
        'italic' => '*',
        'underline' => '<u>',
        'strike' => '~~',
        _ => '${format.value}',
      };

  static String _closing(MapEntry<String, Object?> format) =>
      switch (format.key) {
        'link' => '](${format.value})',
        'bold' => '**',
        'italic' => '*',
        'underline' => '</u>',
        'strike' => '~~',
        _ => '${format.value}'.split('').reversed.join(),
      };
}

/// Splits leading and trailing whitespace off formatted text: the space
/// keeps a format only where the text beside it has it too, so
/// `**word** next` is written rather than `**word **next`.
List<_Run> _moveEdgeWhitespace(List<_Run> runs) {
  final out = <_Run>[];
  for (var i = 0; i < runs.length; i++) {
    final run = runs[i];
    final text = run.data;
    if (text is! String || !run.attrs.keys.any(_emphasis.contains)) {
      out.add(run);
      continue;
    }
    final core = text.trim();
    final at = text.indexOf(core);
    final lead = text.substring(0, at);
    final trail = text.substring(at + core.length);
    final before = i > 0 ? runs[i - 1] : null;
    final after = i + 1 < runs.length ? runs[i + 1] : null;
    Map<String, dynamic> sharedWith(List<_Run?> others) => {
      for (final e in run.attrs.entries)
        if (!_emphasis.contains(e.key) ||
            others.every((o) => o?.attrs[e.key] == e.value))
          e.key: e.value,
    };
    if (core.isEmpty) {
      // Only whitespace: formatted only between text formatted alike.
      out.add(_Run(text, sharedWith([before, after])));
      continue;
    }
    if (lead.isNotEmpty) out.add(_Run(lead, sharedWith([before])));
    if (core.isNotEmpty) out.add(_Run(core, run.attrs));
    if (trail.isNotEmpty) out.add(_Run(trail, sharedWith([after])));
  }
  return out;
}

/// Joins neighbouring text with the same formatting into one piece.
List<_Run> _mergeRuns(List<_Run> runs) {
  final out = <_Run>[];
  for (final run in runs) {
    final text = run.data;
    final last = out.isEmpty ? null : out.last;
    if (last != null &&
        text is String &&
        last.data is String &&
        _sameInline(last.attrs, run.attrs)) {
      out[out.length - 1] = _Run('${last.data}$text', last.attrs);
    } else {
      out.add(run);
    }
  }
  return out;
}

bool _sameInline(Map<String, dynamic> a, Map<String, dynamic> b) =>
    _inline.every((k) => a[k] == b[k]);
