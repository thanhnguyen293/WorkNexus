import 'package:html2md/html2md.dart' as html2md;

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/priority.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/util/content_hash.dart';
import '../../../../core/util/zentao_labels.dart';
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
      final r = zentaoResolutionLabel(extraStr) ?? extraStr;
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

/// Splits a ZenTao action comment into its attached-file names and the residual
/// note. Reopen/resolve comments often lead with `Added Files <name>\r\n<html>`;
/// we lift the file names onto the activity row as chips and strip that line
/// from the note so it isn't repeated as prose.
({List<String> files, String note}) zentaoActionAttachments(String comment) {
  final trimmed = comment.trimLeft();
  final match = RegExp(r'^Added Files\s+(.+?)(?:\r?\n|$)').firstMatch(trimmed);
  if (match == null) return (files: const [], note: stripHtml(comment));
  final names = match
      .group(1)!
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  final rest = trimmed.substring(match.end);
  return (files: names, note: stripHtml(rest));
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

/// The stable account handle (login) of a person reference — used for the
/// assignee so it doesn't flip between sync sources (the bug LIST returns
/// `assignedTo` as a bare account string, DETAIL as `{account, realname}`), which
/// keeps cards, detail, and the "assigned to me" filter in agreement.
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
  final title = (type == ZenTaoType.task ? e.name : e.title)?.toString() ?? '';
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
  final resolution = e.resolution?.toString().trim().toLowerCase() ?? '';
  if (type == ZenTaoType.bug && resolution.isNotEmpty) {
    labels.add('resolution:$resolution');
  }

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
    // Account handle (login), NOT realname: the bug LIST gives `assignedTo` as a
    // bare account string but DETAIL gives {account, realname}, so realname would
    // differ between the card (list) and the detail panel and break the default
    // "my tickets" filter, which matches against the account handle.
    assignee: accountHandle(e.assignedTo),
    url: '$normalizedBase/${type.pathSegment}-view-$id.html',
    severity: type == ZenTaoType.bug ? e.severity : null,
    createdAt: parseZenTaoDate(e.openedDate),
    updatedAt: parseZenTaoDate(e.lastEditedDate),
    providerEntity: switch (type) {
      ZenTaoType.bug => _zentaoBugEntity(e, resolution, normalizedBase),
      ZenTaoType.task || ZenTaoType.story => null,
    },
    sourceHash: contentHash(title, body),
  );
}

TicketProviderEntity _zentaoBugEntity(
  ZenTaoEntity e,
  String resolution,
  String baseUrl,
) => TicketProviderEntity.zentaoBug(
  product: _text(e.product),
  project: _text(e.project),
  execution: _text(e.execution),
  branch: _text(e.branch),
  module: _text(e.module),
  story: _text(e.story),
  task: _text(e.task),
  plan: _text(e.plan),
  productName: _text(e.productName),
  projectName: _text(e.projectName),
  executionName: _text(e.executionName),
  storyTitle: _text(e.storyTitle),
  taskName: _text(e.taskName),
  planName: _text(e.planName),
  bugType: _text(e.type),
  os: _text(e.os),
  browser: _text(e.browser),
  confirmed: e.confirmed,
  severity: e.severity,
  activatedCount: e.activatedCount,
  resolution: resolution.isEmpty ? null : resolution,
  openedBy: accountName(e.openedBy),
  openedDate: parseZenTaoDate(e.openedDate),
  openedBuild: formatZenTaoBuild(e.openedBuild),
  // Account handle, matching `Ticket.assignee` above (see note there).
  assignedTo: accountHandle(e.assignedTo),
  assignedDate: parseZenTaoDate(e.assignedDate),
  deadline: _text(e.deadline),
  resolvedBy: accountName(e.resolvedBy),
  resolvedDate: parseZenTaoDate(e.resolvedDate),
  resolvedBuild: formatZenTaoBuild(e.resolvedBuild),
  closedBy: accountName(e.closedBy),
  closedDate: parseZenTaoDate(e.closedDate),
  lastEditedBy: accountName(e.lastEditedBy),
  lastEditedDate: parseZenTaoDate(e.lastEditedDate),
  attachments: _attachments(e, baseUrl),
);

/// Maps ZenTao's id-keyed `files` map onto domain [TicketAttachment]s. Prefers
/// the payload's absolute `url`; falls back to the classic
/// `{base}/file-download-{id}.{ext}` when it's missing.
List<TicketAttachment> _attachments(ZenTaoEntity e, String baseUrl) {
  final base = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  final out = <TicketAttachment>[];
  for (final f in e.files) {
    final id = f.id?.toString() ?? '';
    if (id.isEmpty) continue;
    final ext = _text(f.extension)?.toLowerCase();
    final title =
        _text(f.title) ??
        _text(f.name) ??
        (ext == null ? 'file-$id' : 'file-$id.$ext');
    final url =
        _text(f.url) ?? '$base/file-download-$id${ext == null ? '' : '.$ext'}';
    out.add(
      TicketAttachment(
        id: id,
        title: title,
        url: url,
        extension: ext,
        size: f.size,
        addedBy: _text(f.addedBy),
        addedDate: parseZenTaoDate(f.addedDate),
      ),
    );
  }
  return out;
}

String? _text(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

/// Formats ZenTao's `openedBuild`/`resolvedBuild`, which arrives as a build
/// object (or list of them) like `[{id: trunk, title: 主干}]`. Renders each as
/// `Trunk · 主干` (capitalised id · localized title); falls back to plain text.
String? formatZenTaoBuild(Object? value) {
  if (value == null) return null;
  if (value is List) {
    final parts = value
        .map(_buildLabel)
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts.join(', ');
  }
  final single = _buildLabel(value);
  return (single == null || single.isEmpty) ? _text(value) : single;
}

String? _buildLabel(Object? v) {
  if (v is Map) {
    final id = (v['id']?.toString() ?? '').trim();
    final title = (v['title']?.toString() ?? '').trim();
    final idCap = id.isEmpty ? '' : id[0].toUpperCase() + id.substring(1);
    return [idCap, title].where((s) => s.isNotEmpty).join(' · ');
  }
  return v?.toString().trim();
}
