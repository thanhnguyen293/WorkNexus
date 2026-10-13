import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/semantic.dart';
import '../../../../core/util/priority_labels.dart';
import '../../../../core/util/relative_time.dart';
import '../../../../core/util/zentao_labels.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../core/widgets/tinted_pill.dart';
import '../../../../l10n/app_localizations.dart';
import 'detail_field_rows.dart';
import 'detail_region_card.dart';
import 'section_label.dart';
import 'ticket_status_pill.dart';

/// The ZenTao bug's typed metadata as two region cards: what the bug *is*
/// (classification) and how it *moved* (lifecycle).
/// Empty classification fields collapse behind a "Show N empty fields" toggle;
/// the lifecycle dates are looked up now and then, so they start folded, and
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
  bool _showLifecycle = false;

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

    // Design order: filled rows surface first, the five id-only fields (Module,
    // Branch, Plan, Story, Task) fall to the empty group when unset (ZenTao
    // reports them as "0").
    final classification = <(String, String)>[
      (l.status, widget.ticket.providerStatus),
      (l.fieldProduct, _joined([bug.productName, bug.product])),
      (l.fieldExecution, _joined([bug.executionName, bug.execution])),
      (l.fieldModule, bug.module ?? ''),
      (l.fieldBranch, bug.branch ?? ''),
      (l.fieldType, zentaoBugTypeLabel(bug.bugType) ?? ''),
      (l.fieldSeverity, _severity(bug.severity)),
      (
        l.priority,
        hasExplicitPriority(widget.ticket)
            ? priorityLabel(widget.ticket.providerType, widget.ticket.priority)
            : '',
      ),
      // The triage facts ZenTao keeps in Basic Info. Whether an open bug was
      // confirmed matters for triage; once it is resolved the flag is history.
      if (active)
        (
          l.fieldConfirmation,
          bug.confirmed == 1 ? l.confirmed : l.bugUnconfirmed,
        ),
      if (reopened > 0) (l.fieldReopened, '$reopened'),
      (l.fieldPlan, _joined([bug.planName, bug.plan])),
      (l.fieldStory, _joined([bug.storyTitle, bug.story])),
      (l.task, _joined([bug.taskName, bug.task])),
      (l.fieldOpenedBuild, bug.openedBuild ?? ''),
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
    final inset = EdgeInsets.fromLTRB(
      context.spacing.lg,
      context.spacing.lg,
      context.spacing.lg,
      context.spacing.md,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DetailRegionCard(
          padding: inset,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionLabel(l.classification),
              SizedBox(height: context.spacing.xs),
              DetailFieldRows(
                rows: filled,
                labelWidth: 100,
                alignEnd: true,
                // Severity and priority as the same chips as the header, the
                // way ZenTao marks them with an icon rather than words.
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
                },
              ),
              if (_showEmpty && empty.isNotEmpty)
                DetailFieldRows(rows: empty, labelWidth: 100, alignEnd: true),
              if (empty.isNotEmpty)
                _EmptyFieldsToggle(
                  count: empty.length,
                  expanded: _showEmpty,
                  onTap: () => setState(() => _showEmpty = !_showEmpty),
                ),
            ],
          ),
        ),
        if (lifecycle.isNotEmpty) ...[
          SizedBox(height: context.spacing.xl),
          DetailRegionCard(
            padding: inset,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LifecycleToggle(
                  expanded: _showLifecycle,
                  onTap: () => setState(() => _showLifecycle = !_showLifecycle),
                ),
                if (_showLifecycle)
                  DetailFieldRows(
                    rows: lifecycle,
                    labelWidth: 100,
                    alignEnd: true,
                  ),
              ],
            ),
          ),
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

  String _severity(int? severity) {
    final label = zentaoSeverityLabel(severity);
    return label == null ? '' : 'S$severity · $label';
  }

  String _joined(List<String?> values) => values
      .whereType<String>()
      .map((v) => v.trim())
      .where((v) => v.isNotEmpty && v != '0')
      .join(' · ');
}

/// The accent "Show N empty fields" / "Hide empty fields" link under the
/// classification rows.
class _EmptyFieldsToggle extends StatelessWidget {
  const _EmptyFieldsToggle({
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  final int count;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Align(
      alignment: Alignment.centerLeft,
      child: HoverRegion(
        // HoverSurface makes the link focusable and keyboard-activatable; the
        // underline stays the hover cue, so it paints no tint.
        builder: (context, hovered, _) => HoverSurface(
          onTap: onTap,
          tintOnHover: false,
          borderRadius: BorderRadius.circular(context.radii.sm),
          padding: EdgeInsets.symmetric(vertical: context.spacing.sm),
          child: Text(
            expanded
                ? AppL10n.of(context).hideEmptyFields
                : AppL10n.of(context).showEmptyFields(count),
            style: context.typography.caption.copyWith(
              color: c.accent,
              // A text link underlines on hover.
              decoration: hovered ? TextDecoration.underline : null,
              decorationColor: c.accent,
            ),
          ),
        ),
      ),
    );
  }
}

/// The "Lifecycle" heading as a fold toggle, a chevron showing which way it
/// goes.
class _LifecycleToggle extends StatelessWidget {
  const _LifecycleToggle({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverSurface(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.radii.sm),
      padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
      child: Row(
        children: [
          Expanded(child: SectionLabel(AppL10n.of(context).lifecycle)),
          Icon(
            expanded ? LucideIcons.chevronUp300 : LucideIcons.chevronDown300,
            size: context.typography.secondary.fontSize,
            color: context.colors.textTertiary,
          ),
        ],
      ),
    );
  }
}

/// A labeled group of key/value rows, kept for callers outside the bug sidebar.
class DetailSection extends StatelessWidget {
  const DetailSection({super.key, required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(title),
        SizedBox(height: context.spacing.xs),
        DetailFieldRows(rows: rows),
      ],
    );
  }
}
