import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/relative_time.dart';
import '../../../../core/util/zentao_labels.dart';
import '../../../../l10n/app_localizations.dart';
import 'detail_field_rows.dart';
import 'section_label.dart';

/// The ZenTao bug's typed metadata, shown as a bordered card split into two
/// groups: what the bug *is* (classification) and how it *moved* (lifecycle).
/// Empty classification fields collapse behind a "Show N empty fields" toggle;
/// empty lifecycle rows are always hidden.
class ZenTaoBugSections extends ConsumerStatefulWidget {
  const ZenTaoBugSections(this.bug, {super.key});

  final ZenTaoBugEntity bug;

  @override
  ConsumerState<ZenTaoBugSections> createState() => _ZenTaoBugSectionsState();
}

class _ZenTaoBugSectionsState extends ConsumerState<ZenTaoBugSections> {
  bool _showEmpty = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final bug = widget.bug;
    final dateFormat = ref.watch(
      appSettingsProvider.select((s) => s.dateFormat),
    );

    // Design order: filled rows surface first, the five id-only fields (Module,
    // Branch, Plan, Story, Task) fall to the empty group when unset (ZenTao
    // reports them as "0").
    final classification = <(String, String)>[
      (l.fieldProduct, _joined([bug.productName, bug.product])),
      (l.fieldExecution, _joined([bug.executionName, bug.execution])),
      (l.fieldModule, bug.module ?? ''),
      (l.fieldBranch, bug.branch ?? ''),
      (l.fieldType, zentaoBugTypeLabel(bug.bugType) ?? ''),
      (l.fieldSeverity, _severity(bug.severity)),
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

    return Container(
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(context.radii.lg),
        border: Border.all(color: c.border),
      ),
      padding: EdgeInsets.fromLTRB(
        context.spacing.lg,
        context.spacing.lg,
        context.spacing.lg,
        context.spacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(l.classification),
          SizedBox(height: context.spacing.xs),
          DetailFieldRows(rows: filled, labelWidth: 100, alignEnd: true),
          if (_showEmpty && empty.isNotEmpty)
            DetailFieldRows(rows: empty, labelWidth: 100, alignEnd: true),
          if (empty.isNotEmpty)
            _EmptyFieldsToggle(
              count: empty.length,
              expanded: _showEmpty,
              onTap: () => setState(() => _showEmpty = !_showEmpty),
            ),
          if (lifecycle.isNotEmpty) ...[
            SizedBox(height: context.spacing.lg),
            SectionLabel(l.lifecycle),
            SizedBox(height: context.spacing.xs),
            DetailFieldRows(rows: lifecycle, labelWidth: 100, alignEnd: true),
          ],
        ],
      ),
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
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: context.spacing.sm),
          child: Text(
            expanded
                ? AppL10n.of(context).hideEmptyFields
                : AppL10n.of(context).showEmptyFields(count),
            style: context.typography.caption.copyWith(color: c.accent),
          ),
        ),
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
