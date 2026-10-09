import 'dart:convert';

import '../../../../core/domain/entities/zentao_ticket_form.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/util/html_entities.dart';

/// The payload of a classic `.json` page: `{status, data}` where `data` is
/// usually itself a JSON string; a bare object passes through. Null when the
/// body is not JSON (an HTML login page, a PHP error).
Map<String, dynamic>? classicPayload(Object? body) {
  var data = _json(body);
  if (data is! Map) return null;
  if (data['data'] != null && data['status'] != null) {
    final inner = _json(data['data']);
    if (inner is Map) data = inner;
  }
  return Map<String, dynamic>.from(data);
}

Object? _json(Object? value) {
  if (value is! String) return value;
  final text = value.trim();
  if (!text.startsWith('{') && !text.startsWith('[')) return null;
  try {
    return jsonDecode(text);
  } catch (_) {
    return null;
  }
}

/// A ZenTao `{id: name}` map as options, in its order. PHP sends a map whose
/// keys happen to be 0…n-1 as a JSON list, so lists are read by index. The
/// "none" entries (`''`, `'0'`, a blank name) are left out: forms offer their
/// own "none".
List<FormOption> zentaoOptions(Object? raw) {
  final entries = switch (raw) {
    final Map<Object?, Object?> map => map.entries.map(
      (e) => (e.key.toString(), e.value),
    ),
    final List<Object?> list => list.indexed.map((e) => ('${e.$1}', e.$2)),
    _ => const <(String, Object?)>[],
  };
  return [
    for (final (key, value) in entries)
      if (key.isNotEmpty && key != '0' && key != 'closed')
        if (_label(value) case final label? when label.isNotEmpty)
          FormOption(value: key, label: label),
  ];
}

/// `[{value, text}]` (ZenTao's ajax pickers) as options.
List<FormOption> zentaoPickerOptions(Object? raw) => [
  if (raw is List)
    for (final item in raw)
      if (item is Map)
        if ('${item['value'] ?? ''}' case final value
            when value.isNotEmpty && value != '0')
          FormOption(value: value, label: _label(item['text']) ?? value),
];

String? _label(Object? value) => switch (value) {
  null => null,
  final Map<Object?, Object?> map => _label(map['name'] ?? map['title']),
  _ => decodeHtmlEntities(value.toString()).trim(),
};

/// A field ZenTao stores as comma-separated text (builds, OS, mailto…).
List<String> zentaoCsv(Object? raw) => switch (raw) {
  final List<Object?> list => [
    for (final v in list)
      if ('$v'.trim() case final s when s.isNotEmpty) s,
  ],
  null => const [],
  _ => [
    for (final v in raw.toString().split(','))
      if (v.trim() case final s when s.isNotEmpty) s,
  ],
};

/// A ZenTao id field as text, `'0'` when unset.
String zentaoId(Object? raw) {
  final text = raw?.toString().trim() ?? '';
  return text.isEmpty ? '0' : text;
}

/// A ZenTao date field (`Y-m-d`), empty when unset (`0000-00-00`).
String zentaoDate(Object? raw) {
  final text = raw?.toString().trim() ?? '';
  if (text.isEmpty || text.startsWith('0000')) return '';
  return text.length > 10 ? text.substring(0, 10) : text;
}

/// A text field, entities decoded (ZenTao stores plain text HTML-escaped).
String zentaoText(Object? raw) =>
    raw == null ? '' : decodeHtmlEntities(raw.toString());

int zentaoIntOr(Object? raw, int fallback) =>
    int.tryParse(raw?.toString() ?? '') ?? fallback;

double zentaoNumber(Object? raw) => double.tryParse(raw?.toString() ?? '') ?? 0;

/// The outcome of a classic create / edit POST: the new id on a create, or
/// null; throws [ValidationFailure] when ZenTao refused the form.
///
/// ZenTao 20+ answers bare JSON (`{result, message, id}`); 18.x wraps an edit's
/// answer like a page (`{status, data: "{\"locate\":…}"}`). An answer that is
/// not JSON (a PHP or SQL error page) is a refusal too.
String? zentaoSaveResult(Object? body) {
  final reply = classicPayload(body);
  if (reply == null) {
    throw const ValidationFailure('ZenTao did not accept the form');
  }
  if (reply['result']?.toString() == 'fail' ||
      reply['status']?.toString() == 'fail') {
    final fields = _fieldErrors(reply['message']);
    throw ValidationFailure(
      fields.isEmpty
          ? (reply['message']?.toString() ?? 'ZenTao refused the form')
          : fields.values.join('\n'),
      fields: fields,
    );
  }
  final id = reply['id']?.toString();
  if (id != null && id.isNotEmpty && id != '0') return id;
  // A duplicate on 18.x: the existing one's page.
  final locate = '${reply['locate'] ?? reply['load'] ?? ''}';
  return RegExp(r'-view-(\d+)').firstMatch(locate)?[1];
}

/// ZenTao's per-field errors (`{field: [msg…] | msg}`, or a list), keyed by
/// field name without its `[]`.
Map<String, String> _fieldErrors(Object? message) {
  String text(Object? v) => v is List ? v.join(' ') : '${v ?? ''}';
  return switch (message) {
    final Map<Object?, Object?> map => {
      for (final e in map.entries)
        e.key.toString().replaceAll('[]', ''): zentaoText(text(e.value)),
    },
    final List<Object?> list => {
      for (final (i, v) in list.indexed) '$i': zentaoText(text(v)),
    },
    _ => const {},
  };
}
