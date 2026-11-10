import 'package:html/dom.dart';
import 'package:html/parser.dart' show parseFragment;

import '../../domain/entities/zentao_doc_action.dart';
import '../../domain/entities/zentao_doc_change.dart';

/// `action-ajaxGetList-doc-{id}` → the document's history, oldest first.
/// An entry's `content` is ZenTao's sentence for it — "2026-09-30 12:56:37,
/// edited by <strong>ViPham-VN-go</strong> ." — and `historyChanges` what
/// changed.
List<ZenTaoDocAction> mapZenTaoDocHistory(Map<String, dynamic> json) {
  final raw = json['actions'];
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map && item['id'] != null) _action(item),
  ];
}

final _datePrefix = RegExp(r'^\s*(\d{4}-\d{2}-\d{2} \d{2}:\d{2}(?::\d{2})?),?');

ZenTaoDocAction _action(Map<dynamic, dynamic> item) {
  final content = '${item['content'] ?? ''}';
  final date = _datePrefix.firstMatch(content);
  final sentence = parseFragment(
    date == null ? content : content.substring(date.end),
  );
  final actor = sentence.querySelector('strong')?.text.trim();
  final summary = (sentence.text ?? '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'\s*\.\s*$'), '')
      .trim();
  final changes = parseZenTaoDocChanges('${item['historyChanges'] ?? ''}');
  return ZenTaoDocAction(
    id: '${item['id']}',
    action: '${item['action'] ?? ''}',
    summary: summary,
    date: date == null
        ? null
        : DateTime.tryParse(date.group(1)!.replaceFirst(' ', 'T')),
    actor: actor == null || actor.isEmpty ? null : actor,
    changes: changes,
  );
}

/// The fields ZenTao names as the document's body: their values are the
/// editor's raw page (JSON), not something to read.
const _bodyFields = {'rawcontent', 'content'};

final _wasIs = RegExp(r'It was "(.*)" and it is "(.*)"', dotAll: true);

/// ZenTao's change list (`historyChanges`) — per field, `<strong><i>Field
/// </i></strong> is changed. It was "a" and it is "b".`, or "The difference
/// is" and a `blockquote.textdiff` of `<del>` / `<ins>` lines (followed by a
/// copy, `blockquote.original`, that is skipped) — read field by field.
List<ZenTaoDocChange> parseZenTaoDocChanges(String html) {
  if (html.trim().isEmpty) return const [];
  final fragment = parseFragment(html);
  final out = <ZenTaoDocChange>[];
  String? field;
  final text = StringBuffer();
  Element? diff;

  void flush() {
    final name = field;
    if (name == null) return;
    if (_bodyFields.contains(name.toLowerCase())) {
      out.add(ZenTaoDocChange(field: name, isBody: true));
    } else if (diff case final d?) {
      out.add(
        ZenTaoDocChange(
          field: name,
          removed: [
            for (final e in d.querySelectorAll('del'))
              if (e.text.trim().isNotEmpty) e.text.trim(),
          ],
          added: [
            for (final e in d.querySelectorAll('ins'))
              if (e.text.trim().isNotEmpty) e.text.trim(),
          ],
        ),
      );
    } else {
      final m = _wasIs.firstMatch(text.toString());
      out.add(ZenTaoDocChange(field: name, from: m?.group(1), to: m?.group(2)));
    }
    field = null;
    diff = null;
    text.clear();
  }

  for (final node in fragment.nodes) {
    if (node is Element &&
        node.localName == 'strong' &&
        node.querySelector('i') != null) {
      flush();
      field = node.text.trim();
    } else if (node is Element && node.localName == 'blockquote') {
      if (node.classes.contains('textdiff')) diff ??= node;
    } else {
      text.write(node.text);
    }
  }
  flush();
  return out;
}
