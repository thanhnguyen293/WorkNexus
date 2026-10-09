import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// Which part of a bug's description a run of it belongs to.
enum BugSectionKind { intro, steps, actual, expected }

/// One run of a bug's description, in the description's own format.
class BugSection {
  const BugSection(this.kind, this.text);

  final BugSectionKind kind;
  final String text;
}

/// Splits a bug's description at its well-known headings ("Steps to
/// reproduce", "Actual result", "Expected result", in English, Vietnamese,
/// ZenTao's Chinese template, or as [labels] name them) into an intro and typed
/// runs. Nothing is dropped: every other line (Markdown) or top-level block
/// (HTML) lands in some run, and empty runs are left out. [html] says which
/// format [body] is in; each run keeps it.
List<BugSection> splitBugDescription(
  String body, {
  required bool html,
  Map<String, BugSectionKind> labels = const {},
}) {
  final headings = {
    ..._headings,
    for (final e in labels.entries) _key(e.key): e.value,
  };
  BugSectionKind? heading(String text) => headings[_key(text)];
  return html ? _splitHtml(body, heading) : _splitLines(body, heading);
}

List<BugSection> _splitLines(
  String body,
  BugSectionKind? Function(String) heading,
) {
  final out = <BugSection>[];
  final run = <String>[];
  var kind = BugSectionKind.intro;
  void flush() {
    final text = run.join('\n').trim();
    if (text.isNotEmpty) out.add(BugSection(kind, text));
    run.clear();
  }

  for (final line in body.split('\n')) {
    if (heading(line) case final next?) {
      flush();
      kind = next;
    } else {
      run.add(line);
    }
  }
  flush();
  return out;
}

List<BugSection> _splitHtml(
  String body,
  BugSectionKind? Function(String) heading,
) {
  var nodes = html_parser.parseFragment(body).nodes.toList();
  // An editor often wraps everything in one block: split inside it.
  while (true) {
    final blocks = [
      for (final n in nodes)
        if (n is dom.Element || n.text?.trim().isNotEmpty == true) n,
    ];
    final only = blocks.length == 1 ? blocks.single : null;
    if (only is dom.Element &&
        const {'div', 'section', 'article', 'body'}.contains(only.localName) &&
        only.children.length > 1) {
      nodes = only.nodes.toList();
    } else {
      break;
    }
  }
  final out = <BugSection>[];
  final run = StringBuffer();
  var kind = BugSectionKind.intro;
  void flush() {
    final text = run.toString().trim();
    if (_hasContent(text)) out.add(BugSection(kind, text));
    run.clear();
  }

  for (final node in nodes) {
    final next = node is dom.Element ? heading(node.text) : null;
    if (next != null) {
      flush();
      kind = next;
    } else {
      run.write(switch (node) {
        dom.Element() => node.outerHtml,
        dom.Text() => _escape(node.text),
        _ => '',
      });
    }
  }
  flush();
  return out;
}

/// Whether an HTML run shows anything: text, or an image / table / rule.
bool _hasContent(String html) {
  if (html.isEmpty) return false;
  final fragment = html_parser.parseFragment(html);
  return fragment.text?.trim().isNotEmpty == true ||
      fragment.querySelector('img, table, hr, video') != null;
}

String _escape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

/// A heading's text reduced for matching: no Markdown marks, brackets or
/// trailing colon, lower case.
String _key(String text) => text
    .replaceAll(RegExp(r'[*_#`>\[\]【】]'), '')
    .replaceAll(' ', ' ')
    .trim()
    .replaceAll(RegExp(r'[:：]\s*$'), '')
    .trim()
    .toLowerCase();

const _headings = {
  'steps': BugSectionKind.steps,
  'steps to reproduce': BugSectionKind.steps,
  'step to reproduce': BugSectionKind.steps,
  'các bước tái hiện': BugSectionKind.steps,
  '步骤': BugSectionKind.steps,
  '重现步骤': BugSectionKind.steps,
  'actual result': BugSectionKind.actual,
  'actual results': BugSectionKind.actual,
  'actual behavior': BugSectionKind.actual,
  'actual behaviour': BugSectionKind.actual,
  'kết quả thực tế': BugSectionKind.actual,
  '结果': BugSectionKind.actual,
  '实际结果': BugSectionKind.actual,
  'expected result': BugSectionKind.expected,
  'expected results': BugSectionKind.expected,
  'expected behavior': BugSectionKind.expected,
  'expected behaviour': BugSectionKind.expected,
  'kết quả mong đợi': BugSectionKind.expected,
  '期望': BugSectionKind.expected,
  '预期结果': BugSectionKind.expected,
  '期望结果': BugSectionKind.expected,
};
