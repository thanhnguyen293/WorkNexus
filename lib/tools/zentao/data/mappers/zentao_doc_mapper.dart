import 'package:html/parser.dart' show parseFragment;

import '../../domain/entities/zentao_doc.dart';
import '../../domain/entities/zentao_doc_lib.dart';
import '../../domain/entities/zentao_doc_person.dart';
import '../../domain/entities/zentao_doc_pins.dart';
import '../../domain/entities/zentao_doc_summary.dart';
import '../models/zentao_models.dart';
import 'zentao_doc_html.dart';
import 'zentao_normalize.dart';

/// `GET /doclibs` → `{libs: [{id, name}]}`.
List<ZenTaoDocLib> mapZenTaoDocLibs(Map<String, dynamic> json) => [
  for (final item in _items(json['libs']))
    if (_id(item['id']) case final id?)
      ZenTaoDocLib(id: id, name: _label(item['name']) ?? id),
];

/// `GET /docs?lib={libId}` → `{docs: [...]}` (a list, or an id-keyed map).
List<ZenTaoDocSummary> mapZenTaoDocSummaries(
  Map<String, dynamic> json,
  String libId,
) => [
  for (final item in _items(json['docs']))
    if (_id(item['id']) case final id?)
      ZenTaoDocSummary(
        id: id,
        title: _label(item['title']) ?? id,
        libId: libId,
        acl: _text(item['acl']),
      ),
];

/// `GET /docs/{id}` → the document. Null when the reply has no document —
/// ZenTao answers a document the user may not read (or a deleted one) with
/// an object that lacks its fields.
ZenTaoDoc? mapZenTaoDoc(Map<String, dynamic> json, {required String baseUrl}) {
  final id = _id(json['id']);
  if (id == null) return null;
  return ZenTaoDoc(
    id: id,
    title: _label(json['title']) ?? id,
    libId: _id(json['lib']) ?? '',
    html: tidyZenTaoDocHtml(
      json['content'] is String ? json['content'] as String : '',
    ),
    isAttachment: json['type'] == 'attachment',
    version: int.tryParse('${json['version']}'),
    author: _person(json['addedBy']),
    editors: _editors(json),
    views: int.tryParse('${json['views']}'),
    addedDate: parseZenTaoDate(json['addedDate']),
    editedDate: parseZenTaoDate(json['editedDate']),
    // `/docs/{id}` sends `files` as a list, where bugs and tasks send an
    // id-keyed map — the shape the shared attachment mapper reads.
    files: zentaoAttachments(
      ZenTaoEntity.fromJson({
        'files': {
          for (final (i, file) in _items(json['files']).indexed)
            '${file['id'] ?? i}': file,
        },
      }),
      baseUrl,
    ),
  );
}

Iterable<Map<String, dynamic>> _items(Object? raw) sync* {
  final values = raw is Map ? raw.values : (raw is List ? raw : const []);
  for (final item in values) {
    if (item is Map) yield Map<String, dynamic>.from(item);
  }
}

String? _id(Object? raw) {
  final s = raw?.toString().trim() ?? '';
  return s.isEmpty || s == '0' ? null : s;
}

/// A name or title as ZenTao stores it, HTML-escaped (`Post &amp; Restriction`),
/// read back as plain text.
String? _label(Object? raw) {
  final s = _text(raw);
  return s == null ? null : _text(parseFragment(s).text);
}

String? _text(Object? raw) {
  final s = raw?.toString().trim() ?? '';
  return s.isEmpty ? null : s;
}

/// A person is sent bare (`"thanh"`) or as `{account, realname, …}`.
ZenTaoDocPerson? _person(Object? raw) {
  if (raw is Map) {
    final account = _text(raw['account']);
    return account == null
        ? null
        : ZenTaoDocPerson(account: account, name: _text(raw['realname']));
  }
  final account = _text(raw);
  return account == null ? null : ZenTaoDocPerson(account: account);
}

/// `editedList` (`,Tompham,Tom,Tommy`) names every editor by login; the last
/// editor (`editedBy`) also comes with a display name.
List<ZenTaoDocPerson> _editors(Map<String, dynamic> json) {
  final last = _person(json['editedBy']);
  final accounts = <String>[
    for (final a in '${json['editedList'] ?? ''}'.split(','))
      if (a.trim().isNotEmpty) a.trim(),
    ?last?.account,
  ];
  final seen = <String>{};
  return [
    for (final a in accounts)
      if (seen.add(a.toLowerCase()))
        a == last?.account ? last! : ZenTaoDocPerson(account: a),
  ];
}

/// The locally stored pins (written by [zenTaoDocPinsToJson]).
/// Names are stored already decoded, so they are read back as they are.
ZenTaoDocPins mapZenTaoDocPins(Map<String, dynamic> json) => ZenTaoDocPins(
  libs: [
    for (final item in _items(json['libs']))
      if (_id(item['id']) case final id?)
        ZenTaoDocLib(id: id, name: _text(item['name']) ?? id),
  ],
  docs: [
    for (final item in _items(json['docs']))
      if (_id(item['id']) case final id?)
        ZenTaoDocSummary(
          id: id,
          title: _text(item['title']) ?? id,
          libId: _text(item['libId']) ?? '',
          acl: _text(item['acl']),
        ),
  ],
);

Map<String, dynamic> zenTaoDocPinsToJson(ZenTaoDocPins pins) => {
  'libs': [
    for (final l in pins.libs) {'id': l.id, 'name': l.name},
  ],
  'docs': [
    for (final d in pins.docs)
      {'id': d.id, 'title': d.title, 'libId': d.libId, 'acl': ?d.acl},
  ],
};
