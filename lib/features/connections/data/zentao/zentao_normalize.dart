import 'package:html2md/html2md.dart' as html2md;

import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/priority.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/util/content_hash.dart';
import 'zentao_models.dart';

/// ZenTao object kinds we import.
enum ZenTaoType { bug, task, story }

extension ZenTaoTypeLabel on ZenTaoType {
  String get label => switch (this) {
    ZenTaoType.bug => 'Bug',
    ZenTaoType.task => 'Task',
    ZenTaoType.story => 'Story',
  };
  String get pathSegment => name; // bug|task|story
}

/// Maps a ZenTao raw status (+ confirmed for bugs) to the unified status,
/// per the researched DevLake-informed mapping.
UnifiedStatus mapZenTaoStatus(ZenTaoType type, String raw, {int? confirmed}) {
  switch (type) {
    case ZenTaoType.bug:
      switch (raw) {
        case 'active':
          return confirmed == 1 ? UnifiedStatus.todo : UnifiedStatus.inbox;
        case 'resolved':
          return UnifiedStatus.review;
        case 'closed':
          return UnifiedStatus.done;
        default:
          return UnifiedStatus.inbox;
      }
    case ZenTaoType.task:
      return switch (raw) {
        'wait' => UnifiedStatus.todo,
        'doing' => UnifiedStatus.inprogress,
        'pause' => UnifiedStatus.blocked,
        'done' => UnifiedStatus.review,
        'closed' => UnifiedStatus.done,
        'cancel' => UnifiedStatus.done,
        _ => UnifiedStatus.todo,
      };
    case ZenTaoType.story:
      return switch (raw) {
        'draft' => UnifiedStatus.inbox,
        'reviewing' => UnifiedStatus.review,
        'changing' => UnifiedStatus.inprogress,
        'active' => UnifiedStatus.todo,
        'closed' => UnifiedStatus.done,
        _ => UnifiedStatus.inbox,
      };
  }
}

/// ZenTao `pri` (1 highest … 4 low; 0/unset → medium) → unified priority.
Priority mapZenTaoPriority(int? pri) {
  if (pri == null || pri == 0) return Priority.medium;
  return Priority.fromLevel((pri - 1).clamp(0, 3));
}

/// Converts ZenTao's rich-text HTML (bug steps / task desc / story spec /
/// comments) into Markdown for the unified renderer. Falls back to a plain-text
/// strip if conversion throws. Plain/empty input passes through unchanged.
///
/// Note: we deliberately do NOT use html2md's `imageBaseUrl` — it prepends the
/// base even to already-absolute `src`s (producing `.../base/https://.../x.png`).
/// ZenTao emits absolute image URLs, and relative ones are resolved later by the
/// authenticated image loader.
String htmlToMarkdown(String html) {
  final s = html.trim();
  if (s.isEmpty) return '';
  if (!s.contains('<')) return s; // already plain text / markdown
  try {
    return html2md.convert(s).replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  } catch (_) {
    return stripHtml(s);
  }
}

/// Crudely strips HTML tags + decodes a few entities for a plaintext body.
String stripHtml(String html) {
  final noTags = html.replaceAll(RegExp(r'<[^>]*>'), '');
  return noTags
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

/// Parses ZenTao dates (ISO-8601 or `YYYY-MM-DD HH:MM:SS`); `0000-00-00` → null.
DateTime? parseZenTaoDate(Object? value) {
  if (value == null) return null;
  final s = value.toString().trim();
  if (s.isEmpty || s.startsWith('0000-00-00')) return null;
  return DateTime.tryParse(s.replaceFirst(' ', 'T'));
}

/// ZenTao bug resolution codes → readable labels.
const _bugResolutions = <String, String>{
  'bydesign': 'By design',
  'duplicate': 'Duplicate',
  'external': 'External',
  'fixed': 'Fixed',
  'notrepro': 'Irreproducible',
  'willnotfix': "Won't fix",
  'postponed': 'Postponed',
  'tostory': 'Converted to story',
};

/// Human-readable phrase for a ZenTao action/history record, rendered after the
/// actor's name (e.g. "assigned to Thanh", "resolved · resolution: Fixed").
/// Mirrors ZenTao's own history descriptions (assignee, resolution, …).
String zentaoActionText(ZenTaoAction action) {
  final a = action.actionType;
  final extra = action.extra;
  final extraStr = extra is String ? extra.trim() : '';
  switch (a) {
    case 'opened':
      return 'created';
    case 'assigned':
    case 'assignedto':
      final to = accountName(extra);
      return (to == null || to.isEmpty) ? 'assigned' : 'assigned to $to';
    case 'resolved':
      final r = _bugResolutions[extraStr.toLowerCase()] ?? extraStr;
      return r.isEmpty ? 'resolved' : 'resolved · resolution: $r';
    case 'closed':
      return extraStr.isEmpty ? 'closed' : 'closed ($extraStr)';
    case 'activated':
      return 'activated';
    case 'edited':
      return 'edited';
    case 'confirmed':
    case 'bugconfirmed':
      return 'confirmed the bug';
    case 'commented':
      return 'commented';
    default:
      return a.isEmpty ? 'updated' : a;
  }
}

/// `assignedTo` is an account object (REST v1) or a bare string (legacy).
String? accountName(Object? value) {
  if (value == null) return null;
  if (value is String) return value.isEmpty ? null : value;
  if (value is Map) {
    final realname = value['realname'];
    final account = value['account'];
    final name = (realname is String && realname.isNotEmpty)
        ? realname
        : (account is String ? account : null);
    return (name == null || name.isEmpty) ? null : name;
  }
  return null;
}

/// The account handle for matching "assigned to me".
String? accountHandle(Object? value) {
  if (value is String) return value.isEmpty ? null : value;
  if (value is Map) {
    final account = value['account'];
    if (account is String) return account;
  }
  return null;
}

/// Normalizes a typed ZenTao [ZenTaoEntity] into a unified [Ticket].
Ticket normalizeZenTao(
  ZenTaoEntity e, {
  required ZenTaoType type,
  required String accountId,
  required String baseUrl,
}) {
  final id = e.idString;
  final title =
      (type == ZenTaoType.task ? e.name : e.title)?.toString() ?? '';
  final rawBody =
      (switch (type) {
        ZenTaoType.bug => e.steps,
        ZenTaoType.task => e.desc ?? e.description,
        ZenTaoType.story => e.spec,
      })?.toString() ??
      '';
  final normalizedBase = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  final body = htmlToMarkdown(rawBody);
  final rawStatus = e.status?.toString() ?? '';
  final status = mapZenTaoStatus(type, rawStatus, confirmed: e.confirmed);

  // Labels: keywords (bug) + object type/category.
  final labels = <String>[];
  final keywords = e.keywords?.toString() ?? '';
  labels.addAll(keywords.split(RegExp(r'[,\s]+')).where((s) => s.isNotEmpty));

  final scopeName = e.scopeName;
  final projectId = '$accountId:${scopeName.isEmpty ? type.label : scopeName}';

  return Ticket(
    id: '$accountId:$id',
    accountId: accountId,
    projectId: projectId,
    providerType: ProviderType.zentao,
    externalKey: id,
    externalType: type.label,
    title: title,
    body: body,
    priority: mapZenTaoPriority(e.pri),
    status: status,
    providerStatus: rawStatus,
    labels: labels,
    assignee: accountName(e.assignedTo),
    url: '$normalizedBase/${type.pathSegment}-view-$id.html',
    severity: type == ZenTaoType.bug ? e.severity : null,
    createdAt: parseZenTaoDate(e.openedDate),
    updatedAt: parseZenTaoDate(e.lastEditedDate),
    sourceHash: contentHash(title, body),
  );
}
