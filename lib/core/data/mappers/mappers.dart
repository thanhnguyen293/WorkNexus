import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:json_annotation/json_annotation.dart';

import '../../database/database.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/activity_event.dart';
import '../../domain/entities/comment.dart';
import '../../domain/entities/project.dart';
import '../../domain/entities/provider_entity.dart';
import '../../domain/entities/ticket.dart';
import '../../domain/entities/workspace.dart';
import '../../domain/value_objects/priority.dart';
import '../../domain/value_objects/provider_type.dart';
import '../../domain/value_objects/unified_status.dart';
import '../../settings/app_settings.dart';
import '../../settings/chat_appearance.dart';
import '../../settings/pinned_execution.dart';
import '../../theme/app_palette.dart';

Workspace workspaceFromRow(WorkspaceRow r) => Workspace(
  id: r.id,
  name: r.name,
  shortCode: r.shortCode,
  colorValue: r.colorValue,
  iconKey: r.iconKey,
  isPersonal: r.isPersonal,
);

WorkspacesCompanion workspaceToCompanion(Workspace w, int order) =>
    WorkspacesCompanion.insert(
      id: w.id,
      name: w.name,
      shortCode: w.shortCode,
      colorValue: w.colorValue,
      iconKey: Value(w.iconKey),
      isPersonal: Value(w.isPersonal),
      sortOrder: Value(order),
    );

Account accountFromRow(AccountRow r) => Account(
  id: r.id,
  workspaceId: r.workspaceId,
  providerType: ProviderType.byId(r.providerType),
  handle: r.handle,
  baseUrl: r.baseUrl,
  credentialsRef: r.credentialsRef,
);

AccountsCompanion accountToCompanion(Account a) => AccountsCompanion.insert(
  id: a.id,
  workspaceId: a.workspaceId,
  providerType: a.providerType.name,
  handle: a.handle,
  baseUrl: Value(a.baseUrl),
  credentialsRef: Value(a.credentialsRef),
);

Project projectFromRow(ProjectRow r) => Project(
  id: r.id,
  accountId: r.accountId,
  name: r.name,
  externalId: r.externalId,
);

ProjectsCompanion projectToCompanion(Project p) => ProjectsCompanion.insert(
  id: p.id,
  accountId: p.accountId,
  name: p.name,
  externalId: Value(p.externalId),
);

Ticket ticketFromRow(TicketRow r) => Ticket(
  id: r.id,
  accountId: r.accountId,
  projectId: r.projectId,
  providerType: ProviderType.byId(r.providerType),
  externalKey: r.externalKey,
  externalType: r.externalType,
  title: r.title,
  body: r.body,
  priority: Priority.fromLevel(r.priorityLevel),
  status: UnifiedStatus.byId(r.statusNorm),
  providerStatus: r.providerStatus,
  labels: decodeLabels(r.labelsJson),
  assignee: r.assignee,
  url: r.url,
  severity: r.severity,
  createdAt: r.createdAt?.toUtc(),
  updatedAt: r.updatedAt?.toUtc(),
  providerEntity: decodeProviderEntity(r.providerEntityJson),
  sourceHash: r.sourceHash,
);

TicketsCompanion ticketToCompanion(Ticket t) => TicketsCompanion.insert(
  id: t.id,
  accountId: t.accountId,
  projectId: t.projectId,
  providerType: t.providerType.name,
  externalKey: t.externalKey,
  externalType: Value(t.externalType),
  title: t.title,
  body: t.body,
  priorityLevel: t.priority.level,
  statusNorm: t.status.name,
  providerStatus: t.providerStatus,
  labelsJson: Value(encodeLabels(t.labels)),
  assignee: Value(t.assignee),
  url: Value(t.url),
  severity: Value(t.severity),
  createdAt: Value(t.createdAt),
  updatedAt: Value(t.updatedAt),
  providerEntityJson: Value(encodeProviderEntity(t.providerEntity)),
  sourceHash: t.sourceHash,
);

/// [value] as drift reads it back: drift keeps a `DateTime` as whole unix
/// seconds. Entities store timestamps normalized to UTC.
DateTime storedDateTime(DateTime value) => DateTime.fromMillisecondsSinceEpoch(
  (value.millisecondsSinceEpoch ~/ 1000) * 1000,
  isUtc: true,
);

DateTime? storedDateTimeOrNull(DateTime? value) =>
    value == null ? null : storedDateTime(value);

/// [t] as it will read back once written — what to compare a stored row
/// against before writing, so a sync that brings nothing new skips the write
/// (and the re-render every write causes).
Ticket ticketAsStored(Ticket t) => t.copyWith(
  createdAt: storedDateTimeOrNull(t.createdAt),
  updatedAt: storedDateTimeOrNull(t.updatedAt),
);

/// See [ticketAsStored].
Comment commentAsStored(Comment c) =>
    c.copyWith(createdAt: storedDateTime(c.createdAt));

/// See [ticketAsStored].
ActivityEvent activityAsStored(ActivityEvent e) =>
    e.copyWith(at: storedDateTime(e.at));

Comment commentFromRow(CommentRow r) => Comment(
  id: r.id,
  ticketId: r.ticketId,
  authorName: r.authorName,
  body: r.body,
  createdAt: r.createdAt.toUtc(),
  origin: CommentOrigin.values.firstWhere(
    (o) => o.name == r.origin,
    orElse: () => CommentOrigin.provider,
  ),
  synced: r.synced,
);

CommentsCompanion commentToCompanion(Comment c) => CommentsCompanion.insert(
  id: c.id,
  ticketId: c.ticketId,
  authorName: c.authorName,
  body: c.body,
  createdAt: c.createdAt,
  origin: Value(c.origin.name),
  synced: Value(c.synced),
);

ActivityEvent activityFromRow(ActivityRow r) => ActivityEvent(
  id: r.id,
  ticketId: r.ticketId,
  actor: r.actor,
  action: r.action,
  at: r.at.toUtc(),
  detail: r.detail,
  attachments: r.attachmentsJson == null
      ? const []
      : decodeLabels(r.attachmentsJson!),
);

ActivitiesCompanion activityToCompanion(ActivityEvent e) =>
    ActivitiesCompanion.insert(
      id: e.id,
      ticketId: e.ticketId,
      actor: e.actor,
      action: e.action,
      at: e.at,
      detail: Value(e.detail),
      attachmentsJson: Value(
        e.attachments.isEmpty ? null : encodeLabels(e.attachments),
      ),
    );

T _enumByName<T extends Enum>(List<T> values, String name, T fallback) =>
    values.firstWhere((e) => e.name == name, orElse: () => fallback);

AppSettings appSettingsFromRow(SettingRow r) => AppSettings(
  variant: _enumByName(
    AppThemeVariant.values,
    r.variant,
    AppThemeVariant.light,
  ),
  surface: _enumByName(SurfaceStyle.values, r.surface, SurfaceStyle.outline),
  density: _enumByName(AppDensity.values, r.density, AppDensity.comfortable),
  detailLayout: _enumByName(
    DetailLayout.values,
    r.detailLayout,
    DetailLayout.twoPane,
  ),
  boardLayout: _enumByName(
    BoardLayout.values,
    r.boardLayout,
    BoardLayout.board,
  ),
  dateFormat: _enumByName(
    DateDisplayFormat.values,
    r.dateFormat,
    DateDisplayFormat.iso,
  ),
  companyTint: r.companyTint,
  locale: Locale(r.localeCode),
  translationLang: r.translationLang,
  translationModel: r.translationModel,
  fontFamily: r.fontFamily,
  componentRadius: r.componentRadius,
  accentColorValue: r.accentColorValue,
  pinnedProjects: decodeLabels(r.pinnedProjectsJson).toSet(),
  pinnedExecutions: decodePinnedExecutions(r.pinnedExecutionsJson),
  sidebarWidth: r.sidebarWidth,
  tableColumnWidths: decodeColumnWidths(r.tableColumnWidthsJson),
  chatAppearance: _enumByName(
    ChatAppearance.values,
    r.chatAppearance,
    ChatAppearance.zalo,
  ),
  chatPrimaryBubbles: r.chatPrimaryBubbles,
  chatWallpaper: r.chatWallpaper,
  chatWallpaperDim: r.chatWallpaperDim,
  chatSendMarkdown: r.chatSendMarkdown,
  chatNotifications: r.chatNotifications,
  chatNotifyWhileViewing: r.chatNotifyWhileViewing,
  chatSendTypingStatus: r.chatSendTypingStatus,
  chatCacheLimitMb: r.chatCacheLimitMb,
  chatAutoDownloadVideos: r.chatAutoDownloadVideos,
  chatAutoDownloadVideoMb: r.chatAutoDownloadVideoMb,
  chatTextScale: r.chatTextScale,
  miniAppLiveLimit: r.miniAppLiveLimit,
  miniAppNotifyInBackground: r.miniAppNotifyInBackground,
  themeFollowsSystem: r.themeFollowsSystem,
);

SettingsCompanion appSettingsToCompanion(AppSettings s) => SettingsCompanion(
  id: const Value(0),
  variant: Value(s.variant.name),
  surface: Value(s.surface.name),
  density: Value(s.density.name),
  detailLayout: Value(s.detailLayout.name),
  boardLayout: Value(s.boardLayout.name),
  dateFormat: Value(s.dateFormat.name),
  companyTint: Value(s.companyTint),
  localeCode: Value(s.locale.languageCode),
  translationLang: Value(s.translationLang),
  translationModel: Value(s.translationModel),
  fontFamily: Value(s.fontFamily),
  componentRadius: Value(s.componentRadius),
  accentColorValue: Value(s.accentColorValue),
  pinnedProjectsJson: Value(encodeLabels(s.pinnedProjects.toList())),
  pinnedExecutionsJson: Value(encodePinnedExecutions(s.pinnedExecutions)),
  sidebarWidth: Value(s.sidebarWidth),
  tableColumnWidthsJson: Value(jsonEncode(s.tableColumnWidths)),
  chatAppearance: Value(s.chatAppearance.name),
  chatPrimaryBubbles: Value(s.chatPrimaryBubbles),
  chatWallpaper: Value(s.chatWallpaper),
  chatWallpaperDim: Value(s.chatWallpaperDim),
  chatSendMarkdown: Value(s.chatSendMarkdown),
  chatNotifications: Value(s.chatNotifications),
  chatNotifyWhileViewing: Value(s.chatNotifyWhileViewing),
  chatSendTypingStatus: Value(s.chatSendTypingStatus),
  chatCacheLimitMb: Value(s.chatCacheLimitMb),
  chatAutoDownloadVideos: Value(s.chatAutoDownloadVideos),
  chatAutoDownloadVideoMb: Value(s.chatAutoDownloadVideoMb),
  chatTextScale: Value(s.chatTextScale),
  miniAppLiveLimit: Value(s.miniAppLiveLimit),
  miniAppNotifyInBackground: Value(s.miniAppNotifyInBackground),
  themeFollowsSystem: Value(s.themeFollowsSystem),
);

/// Decodes the persisted pinned-executions column; tolerates malformed rows.
List<PinnedExecution> decodePinnedExecutions(String json) {
  try {
    final decoded = jsonDecode(json);
    if (decoded is! List) return const <PinnedExecution>[];
    return [
      for (final item in decoded)
        if (item is Map)
          PinnedExecution.fromJson(Map<String, dynamic>.from(item)),
    ];
  } on FormatException {
    return const <PinnedExecution>[];
  }
}

/// Decodes the persisted table column widths; tolerates malformed rows.
Map<String, double> decodeColumnWidths(String json) {
  try {
    final decoded = jsonDecode(json);
    if (decoded is! Map) return const <String, double>{};
    return {
      for (final MapEntry(:key, :value) in decoded.entries)
        if (key is String && value is num) key: value.toDouble(),
    };
  } on FormatException {
    return const <String, double>{};
  }
}

String encodePinnedExecutions(List<PinnedExecution> executions) =>
    jsonEncode([for (final e in executions) e.toJson()]);

TicketProviderEntity? decodeProviderEntity(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return TicketProviderEntity.fromJson(Map<String, dynamic>.from(decoded));
  } on FormatException {
    return null;
  } on CheckedFromJsonException {
    return null;
  }
}

String? encodeProviderEntity(TicketProviderEntity? entity) =>
    entity == null ? null : jsonEncode(entity.toJson());
