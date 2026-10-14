import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/semantic.dart';
import '../../../../core/util/priority_labels.dart';
import '../../../../core/util/relative_time.dart';
import '../../../../core/util/zentao_labels.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../core/widgets/tinted_pill.dart';
import '../../../../l10n/app_localizations.dart';
import 'zentao_execution_link.dart';
import 'zentao_linked_ticket.dart';
import 'bug_module_name.dart';
import 'detail_field_rows.dart';
import 'detail_fields_card.dart';
import 'empty_fields_toggle.dart';
import 'ticket_status_pill.dart';

/// The ZenTao bug's typed metadata as two region cards: what the bug *is*
/// (classification) and how it *moved* (lifecycle).
/// Empty classification fields collapse behind a "Show N empty fields" toggle;
/// empty lifecycle rows are always hidden.
class ZenTaoBugSections extends ConsumerStatefulWidget {
  const ZenTaoBugSections(this.bug, {super.key, required this.ticket});

  final ZenTaoBugEntity bug;

  /// The bug's ticket, for its priority (kept on the ticket, not the entity).
  final Ticket ticket;

  @override
  ConsumerState<ZenTaoBugSections> createState() => _ZenTaoBugSectionsState();
}

class _ZenTaoBugSectionsState extends ConsumerState<ZenTaoBugSections> {
  bool _showEmpty = false;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final bug = widget.bug;
    final dateFormat = ref.watch(
      appSettingsProvider.select((s) => s.dateFormat),
    );

    final active =
        widget.ticket.providerStatus.trim().toLowerCase() == 'active';
    final reopened = bug.activatedCount ?? 0;

    // Grouped by what a reader looks for: the triage facts first (state,
    // how bad, how urgent, what kind), then where the bug lives (product →
    // execution → module → plan → build), then what it links to. The id-only
    // fields (Module, Branch, Plan, Story, Task) fall to the empty group when
    // unset (ZenTao reports them as "0").
    final classification = <(String, String)>[
      (l.status, widget.ticket.providerStatus),
      (l.fieldSeverity, _severity(bug.severity)),
      (
        l.priority,
        hasExplicitPriority(widget.ticket)
            ? priorityLabel(widget.ticket.providerType, widget.ticket.priority)
            : '',
      ),
      // Whether an open bug was confirmed matters for triage; once it is
      // resolved the flag is history.
      if (active)
        (
          l.fieldConfirmation,
          bug.confirmed == 1 ? l.confirmed : l.bugUnconfirmed,
        ),
      if (reopened > 0) (l.fieldReopened, '$reopened'),
      (l.fieldType, zentaoBugTypeLabel(bug.bugType) ?? ''),
      (l.fieldProduct, _nameOr(bug.productName, bug.product)),
      (l.fieldExecution, _nameOr(bug.executionName, bug.execution)),
      (l.fieldModule, bug.module ?? ''),
      (l.fieldBranch, bug.branch ?? ''),
      (l.fieldPlan, _nameOr(bug.planName, bug.plan)),
      (l.fieldOpenedBuild, bug.openedBuild ?? ''),
      (l.fieldStory, _joined([bug.storyTitle, bug.story])),
      (l.task, _joined([bug.taskName, bug.task])),
    ];
    final filled = classification.where((r) => !_isEmpty(r.$2)).toList();
    final empty = classification
        .where((r) => _isEmpty(r.$2))
        .map((r) => (r.$1, '—'))
        .toList();

    final lifecycle = _filter([
      (l.fieldOpened, formatWhen(context, bug.openedDate, format: dateFormat)),
      (
        l.fieldAssigned,
        formatWhen(context, bug.assignedDate, format: dateFormat),
      ),
      (l.fieldResolvedBy, bug.resolvedBy ?? ''),
      (
        l.fieldResolved,
        formatWhen(context, bug.resolvedDate, format: dateFormat),
      ),
      (l.fieldClosedBy, bug.closedBy ?? ''),
      (l.fieldClosed, formatWhen(context, bug.closedDate, format: dateFormat)),
      (
        l.lastEdited,
        formatWhen(context, bug.lastEditedDate, format: dateFormat),
      ),
    ]);

    // Two regions, like ZenTao's Basic Info and Bug Life: what the bug is,
    // then how it moved.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DetailFieldsCard(
          title: l.classification,
          rows: filled,
          // Severity and priority as the same chips as the header, the way
          // ZenTao marks them with an icon rather than words.
          valueWidgets: {
            l.status: TicketStatusPill(ticket: widget.ticket),
            l.fieldSeverity: SeverityTag(bug.severity),
            l.priority: PriorityTag(
              widget.ticket.providerType,
              widget.ticket.priority,
            ),
            // A bug that keeps coming back is worth noticing.
            l.fieldReopened: Text(
              l.reopenedTimes(reopened),
              style: context.typography.secondary.copyWith(
                color: context.colors.warning,
              ),
            ),
            // The bug only knows its module's id; the name is looked up.
            if ((_linkId(bug.module), _linkId(bug.product)) case (
              final module?,
              final product?,
            ))
              l.fieldModule: BugModuleName(
                accountId: widget.ticket.accountId,
                productId: product,
                moduleId: module,
              ),
            if (_linkId(bug.execution) case final id?)
              l.fieldExecution: ZenTaoExecutionLink(
                execution: ProviderExecution(
                  id: id,
                  name: _nameOr(bug.executionName, id),
                  projectId: _linkId(bug.project) ?? '0',
                  accountId: widget.ticket.accountId,
                ),
              ),
            // Story and task open in the panel, like a parent task.
            if (_linkId(bug.story) case final id?)
              l.fieldStory: ZenTaoLinkedTicket(
                ticket: widget.ticket,
                type: 'story',
                id: id,
                label: _joined([bug.storyTitle, '#$id']),
              ),
            if (_linkId(bug.task) case final id?)
              l.task: ZenTaoLinkedTicket(
                ticket: widget.ticket,
                type: 'task',
                id: id,
                label: _joined([bug.taskName, '#$id']),
              ),
          },
          children: [
            if (_showEmpty && empty.isNotEmpty)
              DetailFieldRows(
                rows: empty,
                labelWidth: kSidebarLabelWidth,
                alignEnd: true,
              ),
            if (empty.isNotEmpty)
              EmptyFieldsToggle(
                count: empty.length,
                expanded: _showEmpty,
                onTap: () => setState(() => _showEmpty = !_showEmpty),
              ),
          ],
        ),
        if (lifecycle.isNotEmpty) ...[
          SizedBox(height: context.spacing.xl),
          DetailFieldsCard(title: l.lifecycle, rows: lifecycle),
        ],
      ],
    );
  }

  List<(String, String)> _filter(List<(String, String)> rows) =>
      rows.where((r) => !_isEmpty(r.$2)).toList();

  /// ZenTao reports unset id fields as "0" and unset text as empty; both read as
  /// "no value" in the UI.
  bool _isEmpty(String value) {
    final v = value.trim();
    return v.isEmpty || v == '0' || v == '—';
  }

  /// The linked ticket's id, or null when ZenTao reports it unset.
  String? _linkId(String? id) => id == null || _isEmpty(id) ? null : id.trim();

  String _severity(int? severity) {
    final label = zentaoSeverityLabel(severity);
    return label == null ? '' : 'S$severity · $label';
  }

  /// [name] when ZenTao gave one, else the bare [id] — an id means nothing to
  /// a reader next to a name.
  String _nameOr(String? name, String? id) {
    final n = name?.trim() ?? '';
    return n.isNotEmpty ? n : (id ?? '');
  }

  String _joined(List<String?> values) => values
      .whereType<String>()
      .map((v) => v.trim())
      .where((v) => v.isNotEmpty && v != '0')
      .join(' · ');
}
