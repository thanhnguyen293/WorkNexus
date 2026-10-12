import 'dart:convert';

import '../../../../core/database/database.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/zentao_ticket_form.dart';
import '../../domain/entities/saved_ticket_draft.dart';

/// [SavedTicketDraft] ↔ [TicketDraftRow]. The draft's added files are left
/// out: only their bytes exist, and a repro video would bloat the database.
abstract final class TicketDraftMapper {
  static const _bug = 'bug';
  static const _task = 'task';

  static TicketDraftsCompanion toRow(SavedTicketDraft draft) {
    final (kind, json) = switch (draft) {
      SavedBugDraft(:final draft) => (_bug, _bugJson(draft)),
      SavedTaskDraft(:final draft) => (_task, _taskJson(draft)),
    };
    return TicketDraftsCompanion.insert(
      id: draft.id,
      accountId: draft.accountId,
      kind: kind,
      uid: draft.uid,
      json: jsonEncode(json),
      updatedAt: draft.updatedAt,
    );
  }

  /// Null for a row this build cannot read (an unknown kind, broken JSON).
  static SavedTicketDraft? fromRow(TicketDraftRow row) {
    final Object? json;
    try {
      json = jsonDecode(row.json);
    } on FormatException {
      return null;
    }
    if (json is! Map<String, dynamic>) return null;
    return switch (row.kind) {
      _bug => SavedTicketDraft.bug(
        id: row.id,
        accountId: row.accountId,
        uid: row.uid,
        updatedAt: row.updatedAt,
        draft: _bugFrom(json),
      ),
      _task => SavedTicketDraft.task(
        id: row.id,
        accountId: row.accountId,
        uid: row.uid,
        updatedAt: row.updatedAt,
        draft: _taskFrom(json),
      ),
      _ => null,
    };
  }

  static Map<String, dynamic> _bugJson(BugDraft d) => {
    'product': d.product,
    'branch': d.branch,
    'module': d.module,
    'project': d.project,
    'execution': d.execution,
    'plan': d.plan,
    'openedBuilds': d.openedBuilds,
    'assignedTo': d.assignedTo,
    'deadline': d.deadline,
    'type': d.type,
    'os': d.os,
    'browser': d.browser,
    'title': d.title,
    'color': d.color,
    'severity': d.severity,
    'pri': d.pri,
    'steps': d.steps,
    'story': d.story,
    'task': d.task,
    'mailto': d.mailto,
    'keywords': d.keywords,
    'files': [for (final f in d.files) f.toJson()],
  };

  static BugDraft _bugFrom(Map<String, dynamic> j) {
    const d = BugDraft(product: '0');
    return BugDraft(
      product: _string(j['product']) ?? d.product,
      branch: _string(j['branch']) ?? d.branch,
      module: _string(j['module']) ?? d.module,
      project: _string(j['project']) ?? d.project,
      execution: _string(j['execution']) ?? d.execution,
      plan: _string(j['plan']) ?? d.plan,
      openedBuilds: _strings(j['openedBuilds']) ?? d.openedBuilds,
      assignedTo: _string(j['assignedTo']) ?? d.assignedTo,
      deadline: _string(j['deadline']) ?? d.deadline,
      type: _string(j['type']) ?? d.type,
      os: _strings(j['os']) ?? d.os,
      browser: _strings(j['browser']) ?? d.browser,
      title: _string(j['title']) ?? d.title,
      color: _string(j['color']) ?? d.color,
      severity: _int(j['severity']) ?? d.severity,
      pri: _int(j['pri']) ?? d.pri,
      steps: _string(j['steps']) ?? d.steps,
      story: _string(j['story']) ?? d.story,
      task: _string(j['task']) ?? d.task,
      mailto: _strings(j['mailto']) ?? d.mailto,
      keywords: _string(j['keywords']) ?? d.keywords,
      files: _files(j['files']),
    );
  }

  static Map<String, dynamic> _taskJson(TaskDraft d) => {
    'execution': d.execution,
    'module': d.module,
    'story': d.story,
    'parent': d.parent,
    'name': d.name,
    'type': d.type,
    'pri': d.pri,
    'estimate': d.estimate,
    'left': d.left,
    'consumed': d.consumed,
    'status': d.status,
    'assignedTo': d.assignedTo,
    'estStarted': d.estStarted,
    'deadline': d.deadline,
    'desc': d.desc,
    'color': d.color,
    'mailto': d.mailto,
    'keywords': d.keywords,
    'files': [for (final f in d.files) f.toJson()],
  };

  static TaskDraft _taskFrom(Map<String, dynamic> j) {
    const d = TaskDraft(execution: '0');
    return TaskDraft(
      execution: _string(j['execution']) ?? d.execution,
      module: _string(j['module']) ?? d.module,
      story: _string(j['story']) ?? d.story,
      parent: _string(j['parent']) ?? d.parent,
      name: _string(j['name']) ?? d.name,
      type: _string(j['type']) ?? d.type,
      pri: _int(j['pri']) ?? d.pri,
      estimate: _double(j['estimate']) ?? d.estimate,
      left: _double(j['left']) ?? d.left,
      consumed: _double(j['consumed']) ?? d.consumed,
      status: _string(j['status']) ?? d.status,
      assignedTo: _string(j['assignedTo']) ?? d.assignedTo,
      estStarted: _string(j['estStarted']) ?? d.estStarted,
      deadline: _string(j['deadline']) ?? d.deadline,
      desc: _string(j['desc']) ?? d.desc,
      color: _string(j['color']) ?? d.color,
      mailto: _strings(j['mailto']) ?? d.mailto,
      keywords: _string(j['keywords']) ?? d.keywords,
      files: _files(j['files']),
    );
  }

  static String? _string(Object? v) => v is String ? v : null;

  static int? _int(Object? v) => v is num ? v.toInt() : null;

  static double? _double(Object? v) => v is num ? v.toDouble() : null;

  static List<String>? _strings(Object? v) =>
      v is List ? v.whereType<String>().toList() : null;

  static List<TicketAttachment> _files(Object? v) => [
    if (v is List)
      for (final f in v.whereType<Map<String, dynamic>>())
        TicketAttachment.fromJson(f),
  ];
}
