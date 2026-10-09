import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';
import '../../../../core/util/html_entities.dart';
import '../../domain/entities/zentao_notification.dart';

/// Parses the view of ZenTao's `message-ajaxGetDropmenu-all` page into
/// notifications. `allMessages` is `{ "2026-10-09": [message, …], … }` (or a
/// plain list); each message's `data` is HTML such as
/// `JunNg assigned Bug <a data-url='…/bug-view-6492.html'>[#6492::Title]</a>`.
List<ZenTaoNotification> zenTaoNotificationsFromView(
  Map<String, dynamic> view, {
  required String accountId,
}) {
  final raw = view['allMessages'];
  final groups = switch (raw) {
    final Map<Object?, Object?> byDay => byDay.values,
    final List<Object?> list => [list],
    _ => const <Object?>[],
  };
  return [
    for (final group in groups)
      if (group is List)
        for (final m in group)
          if (m is Map) ?_notification(Map<String, dynamic>.from(m), accountId),
  ];
}

final _anchor = RegExp(
  r'''<a\b[^>]*?(?:data-url|href)\s*=\s*['"]([^'"#][^'"]*)['"][^>]*>(.*?)</a>''',
  caseSensitive: false,
  dotAll: true,
);
final _tag = RegExp('<[^>]+>');
final _ref = RegExp(r'^\[#(\d+)::(.*)\]$', dotAll: true);

/// `bug-view-6492`, `/bug-view-6492.html` or `?m=bug&f=view&id=6492`.
final _pathView = RegExp(
  r'(?:^|[/=])([a-z]+)-view-(\d+)',
  caseSensitive: false,
);
final _queryView = RegExp(
  r'[?&]m=([a-z]+)&f=view&\w*id=(\d+)',
  caseSensitive: false,
);

ZenTaoNotification? _notification(Map<String, dynamic> m, String accountId) {
  final id = m['id']?.toString().trim() ?? '';
  final html = m['data']?.toString() ?? '';
  if (id.isEmpty || html.isEmpty) return null;
  final anchor = _anchor.firstMatch(html);
  final summary = _text(
    anchor == null ? html : html.substring(0, anchor.start),
  );
  final href = anchor?.group(1);
  final url = href == null ? null : decodeHtmlEntities(href);
  final linkText = anchor == null ? null : _text(anchor.group(2) ?? '');
  final ref = linkText == null ? null : _ref.firstMatch(linkText);
  final view = url == null
      ? null
      : (_pathView.firstMatch(url) ?? _queryView.firstMatch(url));
  return ZenTaoNotification(
    accountId: accountId,
    id: id,
    summary: summary.isEmpty ? (linkText ?? '') : summary,
    objectType: view?.group(1)?.toLowerCase(),
    objectId: ref?.group(1) ?? view?.group(2),
    objectTitle: ref?.group(2)?.trim() ?? linkText,
    url: url,
    read: m['status']?.toString() == 'read',
    createdAt: DateTime.tryParse(m['createdDate']?.toString() ?? ''),
  );
}

String _text(String html) => decodeHtmlEntities(
  html.replaceAll(_tag, ' '),
).replaceAll(RegExp(r'\s+'), ' ').trim();

ZenTaoNotification zenTaoNotificationFromRow(ZenTaoNotificationRow r) =>
    ZenTaoNotification(
      accountId: r.accountId,
      id: r.id,
      summary: r.summary,
      objectType: r.objectType,
      objectId: r.objectId,
      objectTitle: r.objectTitle,
      url: r.url,
      read: r.read,
      createdAt: r.createdAt,
    );

ZenTaoNotificationsCompanion zenTaoNotificationToCompanion(
  ZenTaoNotification n,
) => ZenTaoNotificationsCompanion.insert(
  accountId: n.accountId,
  id: n.id,
  summary: n.summary,
  objectType: Value(n.objectType),
  objectId: Value(n.objectId),
  objectTitle: Value(n.objectTitle),
  url: Value(n.url),
  read: Value(n.read),
  createdAt: Value(n.createdAt),
);
