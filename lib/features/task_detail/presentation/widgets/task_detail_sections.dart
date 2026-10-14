import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/zentao_ticket_id.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/semantic.dart';
import '../../../../core/util/hours_text.dart';
import '../../../../core/util/priority_labels.dart';
import '../../../../core/util/relative_time.dart';
import '../../../../core/util/zentao_labels.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/summarize_task_effort.dart';
import 'detail_fields_card.dart';
import 'task_bugs_card.dart';
import 'ticket_status_pill.dart';
import 'zentao_execution_link.dart';
import 'zentao_linked_ticket.dart';

/// A ZenTao task's metadata as region cards, like a bug's and ZenTao's own
/// task view: what the task is and where it sits (classification), the bugs
/// reported against it, its hours and dates (effort), and how it moved
/// (lifecycle). Empty rows are
/// left out.
class ZenTaoTaskSections extends ConsumerWidget {
  const ZenTaoTaskSections(this.task, {super.key, required this.ticket});

  final ZenTaoTaskEntity task;

  /// The task's ticket, for its status and priority (kept on the ticket).
  final Ticket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final dateFormat = ref.watch(
      appSettingsProvider.select((s) => s.dateFormat),
    );
    String when(DateTime? at) => formatWhen(context, at, format: dateFormat);
    String hours(double? h) => l.hoursValue(hoursText(h ?? 0));

    final effort = const SummarizeTaskEffort()(task);
    // A subtask's parent: its name as ZenTao gave it, else as synced here.
    final parentId = task.parentId;
    final parentName =
        task.parentName ??
        (parentId == null
            ? null
            : ref
                  .watch(
                    ticketByIdProvider(
                      zenTaoTicketId(ticket.accountId, 'task', parentId),
                    ),
                  )
                  ?.title);

    // Like ZenTao's Basic Info: what the task is, how far along, then where
    // it sits and what it comes from.
    final classification = _filled([
      (l.status, ticket.providerStatus),
      (
        l.priority,
        hasExplicitPriority(ticket)
            ? priorityLabel(ticket.providerType, ticket.priority)
            : '',
      ),
      (l.fieldType, zentaoTaskTypeLabel(task.taskType) ?? ''),
      if (effort != null)
        (
          l.fieldProgress,
          NumberFormat.percentPattern(
            Localizations.localeOf(context).toString(),
          ).format(effort.progress),
        ),
      (l.fieldExecution, task.executionName ?? task.execution ?? ''),
      (l.parentTask, parentId ?? ''),
      (l.fieldStory, task.story ?? ''),
      (l.fieldFromBug, task.fromBug ?? ''),
    ]);

    final effortRows = _filled([
      if (effort != null) ...[
        (l.estimate, hours(effort.estimate)),
        (l.fieldLogged, hours(effort.consumed)),
        (l.zentaoHoursLeft, hours(effort.left)),
      ],
      (l.fieldEstStarted, task.estStarted ?? ''),
      (l.fieldActualStart, when(task.realStarted)),
      (l.fieldDeadline, task.deadline ?? ''),
    ]);

    final lifecycle = _filled([
      (l.fieldOpenedBy, task.openedBy ?? ''),
      (l.fieldOpened, when(task.openedDate)),
      (l.fieldFinishedBy, task.finishedBy ?? ''),
      (l.fieldFinished, when(task.finishedDate)),
      (l.fieldClosedBy, task.closedBy ?? ''),
      (l.fieldClosed, when(task.closedDate)),
      (l.lastEdited, when(task.lastEditedDate)),
    ]);

    String linked(String? name, String id) =>
        [?name, '#$id'].where((s) => s.trim().isNotEmpty).join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DetailFieldsCard(
          title: l.classification,
          rows: classification,
          valueWidgets: {
            l.status: TicketStatusPill(ticket: ticket),
            l.priority: PriorityTag(ticket.providerType, ticket.priority),
            if (task.execution case final id?)
              l.fieldExecution: ZenTaoExecutionLink(
                execution: ProviderExecution(
                  id: id,
                  name: task.executionName ?? id,
                  projectId: task.project ?? '0',
                  accountId: ticket.accountId,
                ),
              ),
            if (parentId != null)
              l.parentTask: ZenTaoLinkedTicket(
                ticket: ticket,
                type: 'task',
                id: parentId,
                label: linked(parentName, parentId),
              ),
            if (task.story case final id?)
              l.fieldStory: ZenTaoLinkedTicket(
                ticket: ticket,
                type: 'story',
                id: id,
                label: linked(task.storyTitle, id),
              ),
            if (task.fromBug case final id?)
              l.fieldFromBug: ZenTaoLinkedTicket(
                ticket: ticket,
                type: 'bug',
                id: id,
                label: '#$id',
              ),
          },
        ),
        // Spaces itself; nothing while the task has no related bugs.
        TaskBugsCard(ticket: ticket),
        if (effortRows.isNotEmpty) ...[
          SizedBox(height: context.spacing.xl),
          DetailFieldsCard(title: l.taskEffort, rows: effortRows),
        ],
        if (lifecycle.isNotEmpty) ...[
          SizedBox(height: context.spacing.xl),
          DetailFieldsCard(title: l.lifecycle, rows: lifecycle),
        ],
      ],
    );
  }

  /// The rows with a value: ZenTao reports unset ids as "0".
  List<(String, String)> _filled(List<(String, String)> rows) => [
    for (final row in rows)
      if (row.$2.trim() case final v when v.isNotEmpty && v != '0' && v != '—')
        row,
  ];
}
