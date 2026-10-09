import '../../../../core/domain/entities/zentao_ticket_form.dart';
import 'zentao_form_parsing.dart';
import 'zentao_workflow.dart';

/// Where a new subtask of [draft]'s parent is posted: ZenTao's batch task form,
/// the only one that takes a parent task in 18.x to 21.x.
String subtaskPath(TaskDraft draft) =>
    'task-batchCreate-${draft.execution}-${draft.story}-${draft.module}-'
    '${draft.parent}';

/// [draft] as the one row of ZenTao's batch task form. 18.x reads every
/// column of a row, so all of them are sent.
Map<String, Object> subtaskRow(TaskDraft draft, String uid) => {
  'uid': uid,
  'parent[1]': draft.parent,
  'name[1]': draft.name,
  'type[1]': draft.type,
  'pri[1]': '${draft.pri}',
  'estimate[1]': zentaoHours(draft.estimate),
  'assignedTo[1]': draft.assignedTo,
  'module[1]': draft.module,
  'story[1]': draft.story,
  'color[1]': draft.color,
  // 18.x turns a row's line breaks into <br>.
  'desc[1]': draft.desc.replaceAll('\n', ''),
  if (draft.estStarted.isNotEmpty) 'estStarted[1]': draft.estStarted,
  if (draft.deadline.isNotEmpty) 'deadline[1]': draft.deadline,
};

/// The id ZenTao gave the first task of a batch (its `idList`), if it says.
String? batchCreatedId(Object? body) {
  final ids = switch (classicPayload(body)?['idList']) {
    final List<Object?> list => list,
    final Map<Object?, Object?> map => map.values.toList(),
    _ => const <Object?>[],
  };
  for (final raw in ids) {
    final id = '${raw is Map ? raw['id'] ?? raw['taskID'] : raw}'.trim();
    if (id.isNotEmpty && id != '0' && id != 'null') return id;
  }
  return null;
}
